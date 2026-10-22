class_name Diplomacy
extends RefCounted
## Relations between countries: subjects (vassals, personal unions,
## tributaries), alliances, royal marriages, declared rivalries, envoys
## improving relations, and opinion — how one country regards another, always
## a sum of named reasons the player can inspect (no hidden bonuses).
##
## This class is the single place these facts change. The rules for when an
## action is allowed or accepted live in DiplomacyActions; the monthly tick
## (decay, envoys, AI) in DiplomacySystem.

signal changed(a: String, b: String)
## Someone became or stopped being a subject (map colours follow overlords).
signal subjects_changed
## Opinions moved in the monthly update.
signal opinions_updated
## The whole diplomatic state was replaced (new campaign or loaded save).
signal reset

const SUBJECT_TYPES := ["vassal", "personal_union", "tributary", "colony"]
const MAX_RIVALS := 3

## Opinion from standing relations (worked out on demand, never stored).
const OPINION_ALLIED := 40
const OPINION_MARRIED := 25
const OPINION_RIVAL_OF_US := -60  # they declared us their rival
const OPINION_OUR_RIVAL := -30  # we declared them our rival
const OPINION_COMMON_RIVAL := 20
const OPINION_OF_OVERLORD := {"vassal": 10, "personal_union": 25, "tributary": 5, "colony": 20}
const OPINION_OF_SUBJECT := 30
## A country paying another a subsidy is regarded this much better by it.
const OPINION_SUBSIDISED := 25

## Lasting effects of actions, by kind: label shown to the player, and how
## much they fade each month.
const MODIFIERS := {
	"gift": {"label": "Sent us gifts", "decay": 1.0},
	"insult": {"label": "Insulted us", "decay": 1.0},
	"improved": {"label": "Improved relations", "decay": 1.0},
	"broke_alliance": {"label": "Broke our alliance", "decay": 1.0},
	"broke_marriage": {"label": "Broke a royal marriage", "decay": 1.0},
	"released": {"label": "Released us", "decay": 0.5},
	"war": {"label": "Made war on us", "decay": 0.5},
}
const IMPROVE_PER_MONTH := 3.0
const IMPROVE_CAP := 50.0
const OPINION_LIMIT := 200

var _subjects := {}  # subject -> {overlord, type}
var _alliances := {}  # pair key -> true
var _marriages := {}  # pair key -> true
## The same, by country: tag -> {partner: true} (asked for constantly by the AI).
var _allies := {}
var _spouses := {}
var _rivals := {}  # country -> Array[String] it has declared rivals
## "from>to" (from's opinion of to) -> {kind: value}
var _modifiers := {}
var _envoys := {}  # country -> Array[String] whose relations it is improving
var _cooldowns := {}  # "kind:from>to" -> day number of the last use
var _subsidies := {}  # "from>to" -> ducats a month


static func _pair(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


# --- Queries --------------------------------------------------------------------

func overlord_of(tag: String) -> String:
	return _subjects[tag].overlord if _subjects.has(tag) else ""


func subject_type(tag: String) -> String:
	return _subjects[tag].type if _subjects.has(tag) else ""


func subjects_of(tag: String) -> Array[String]:
	var out: Array[String] = []
	for s: String in _subjects:
		if _subjects[s].overlord == tag:
			out.append(s)
	out.sort()
	return out


func is_allied(a: String, b: String) -> bool:
	return _alliances.has(_pair(a, b))


func allies_of(tag: String) -> Array[String]:
	return _partners(_allies, tag)


func are_married(a: String, b: String) -> bool:
	return _marriages.has(_pair(a, b))


func marriages_of(tag: String) -> Array[String]:
	return _partners(_spouses, tag)


func _partners(index: Dictionary, tag: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(index.get(tag, {}).keys())
	out.sort()
	return out


func _index_pair(index: Dictionary, a: String, b: String, on: bool) -> void:
	for pair: Array in [[a, b], [b, a]]:
		if on:
			if not index.has(pair[0]):
				index[pair[0]] = {}
			index[pair[0]][pair[1]] = true
		elif index.has(pair[0]):
			index[pair[0]].erase(pair[1])


## Countries `tag` has declared its rivals.
func rivals_of(tag: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(_rivals.get(tag, []))
	return out


func has_rival(tag: String, other: String) -> bool:
	return other in _rivals.get(tag, [])


## Rivalry either way.
func are_rivals(a: String, b: String) -> bool:
	return has_rival(a, b) or has_rival(b, a)


func envoys_of(tag: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(_envoys.get(tag, []))
	return out


func is_improving(from: String, to: String) -> bool:
	return to in _envoys.get(from, [])


func last_used(kind: String, from: String, to: String) -> int:
	return _cooldowns.get("%s:%s>%s" % [kind, from, to], -1000000)


## How `a` regards `b`, as [label, value] reasons (largest first).
func opinion_reasons(a: String, b: String) -> Array:
	var reasons := []
	if a == b:
		return reasons
	if is_allied(a, b):
		reasons.append(["Allies", OPINION_ALLIED])
	if are_married(a, b):
		reasons.append(["Royal marriage", OPINION_MARRIED])
	if has_rival(b, a):
		reasons.append(["Declared us their rival", OPINION_RIVAL_OF_US])
	if has_rival(a, b):
		reasons.append(["Our rival", OPINION_OUR_RIVAL])
	for r in rivals_of(a):
		if has_rival(b, r):
			reasons.append(["Common rival", OPINION_COMMON_RIVAL])
			break
	if overlord_of(a) == b:
		var kind := subject_type(a)
		reasons.append([{"vassal": "Our overlord", "personal_union": "Our sovereign",
			"tributary": "Our suzerain", "colony": "Our mother country"}[kind], OPINION_OF_OVERLORD[kind]])
	if overlord_of(b) == a:
		reasons.append(["Our subject", OPINION_OF_SUBJECT])
	if subsidy(b, a) > 0:
		reasons.append(["Pays us subsidies", OPINION_SUBSIDISED])
	var mods: Dictionary = _modifiers.get(a + ">" + b, {})
	for kind: String in mods:
		reasons.append([MODIFIERS[kind].label, int(round(mods[kind]))])
	reasons.sort_custom(func(x: Array, y: Array) -> bool: return absi(x[1]) > absi(y[1]))
	return reasons


## The sum of opinion_reasons(a, b) (kept in step with it; tested), without
## building the reasons: the AI asks for thousands of opinions a month.
func opinion(a: String, b: String) -> int:
	if a == b:
		return 0
	var total := 0
	if is_allied(a, b):
		total += OPINION_ALLIED
	if are_married(a, b):
		total += OPINION_MARRIED
	if has_rival(b, a):
		total += OPINION_RIVAL_OF_US
	if has_rival(a, b):
		total += OPINION_OUR_RIVAL
	for r in _rivals.get(a, []):
		if has_rival(b, r):
			total += OPINION_COMMON_RIVAL
			break
	if overlord_of(a) == b:
		total += OPINION_OF_OVERLORD[subject_type(a)]
	if overlord_of(b) == a:
		total += OPINION_OF_SUBJECT
	if _subsidies.has(b + ">" + a):
		total += OPINION_SUBSIDISED
	var mods: Dictionary = _modifiers.get(a + ">" + b, {})
	for kind: String in mods:
		total += int(round(mods[kind]))
	return clampi(total, -OPINION_LIMIT, OPINION_LIMIT)


func modifier(a: String, b: String, kind: String) -> float:
	return _modifiers.get(a + ">" + b, {}).get(kind, 0.0)


# --- Changes (rules are checked by DiplomacyActions) ------------------------------------

## Ducats a month `from` pays `to` (0: none).
func subsidy(from: String, to: String) -> int:
	return _subsidies.get(from + ">" + to, 0)


## Every subsidy: [from, to, ducats a month].
func subsidies() -> Array:
	var out := []
	for key: String in _sorted(_subsidies):
		var parts := key.split(">")
		out.append([parts[0], parts[1], _subsidies[key]])
	return out


func set_subsidy(from: String, to: String, amount: int) -> void:
	if amount <= 0:
		_subsidies.erase(from + ">" + to)
	else:
		_subsidies[from + ">" + to] = amount
	changed.emit(from, to)


func set_subject(overlord: String, subject: String, type: String) -> void:
	assert(type in SUBJECT_TYPES)
	_subjects[subject] = {"overlord": overlord, "type": type}
	changed.emit(overlord, subject)
	subjects_changed.emit()


func release_subject(subject: String) -> void:
	var overlord := overlord_of(subject)
	if _subjects.erase(subject):
		changed.emit(overlord, subject)
		subjects_changed.emit()


func set_allied(a: String, b: String, on: bool) -> void:
	_set_pair(_alliances, _allies, a, b, on)


func set_married(a: String, b: String, on: bool) -> void:
	_set_pair(_marriages, _spouses, a, b, on)


func _set_pair(table: Dictionary, index: Dictionary, a: String, b: String, on: bool) -> void:
	var key := _pair(a, b)
	if on == table.has(key):
		return
	if on:
		table[key] = true
	else:
		table.erase(key)
	_index_pair(index, a, b, on)
	changed.emit(a, b)


func set_rival(tag: String, other: String, on: bool) -> void:
	var list: Array = _rivals.get(tag, [])
	if on == (other in list):
		return
	if on:
		list.append(other)
		list.sort()
	else:
		list.erase(other)
	if list.is_empty():
		_rivals.erase(tag)
	else:
		_rivals[tag] = list
	changed.emit(tag, other)


## Adds to `from`'s opinion of `to` (a named, fading modifier), within ±cap.
func add_modifier(from: String, to: String, kind: String, value: float, cap := 100.0) -> void:
	assert(MODIFIERS.has(kind))
	var key := from + ">" + to
	var mods: Dictionary = _modifiers.get(key, {})
	mods[kind] = clampf(mods.get(kind, 0.0) + value, -cap, cap)
	_modifiers[key] = mods
	changed.emit(from, to)


func set_envoy(from: String, to: String, on: bool) -> void:
	var list: Array = _envoys.get(from, [])
	if on == (to in list):
		return
	if on:
		list.append(to)
	else:
		list.erase(to)
	if list.is_empty():
		_envoys.erase(from)
	else:
		_envoys[from] = list
	changed.emit(from, to)


func mark_used(kind: String, from: String, to: String, day: int) -> void:
	_cooldowns["%s:%s>%s" % [kind, from, to]] = day


## Monthly: envoys build relations; other effects fade.
func monthly_update() -> void:
	for from: String in _envoys:
		for to: String in _envoys[from]:
			var key := to + ">" + from
			var mods: Dictionary = _modifiers.get(key, {})
			mods["improved"] = minf(mods.get("improved", 0.0) + IMPROVE_PER_MONTH, IMPROVE_CAP)
			_modifiers[key] = mods
	for key: String in _modifiers.keys():
		var mods: Dictionary = _modifiers[key]
		var parts := key.split(">")
		for kind: String in mods.keys():
			if kind == "improved" and is_improving(parts[1], parts[0]):
				continue  # held while the envoy is at work
			var v: float = mods[kind]
			var decay: float = MODIFIERS[kind].decay
			v = maxf(v - decay, 0.0) if v > 0.0 else minf(v + decay, 0.0)
			if absf(v) < 0.5:
				mods.erase(kind)
			else:
				mods[kind] = v
		if mods.is_empty():
			_modifiers.erase(key)
	opinions_updated.emit()


# --- Scenario and saves ---------------------------------------------------------------

func clear() -> void:
	_subjects.clear()
	_alliances.clear()
	_marriages.clear()
	_allies.clear()
	_spouses.clear()
	_rivals.clear()
	_modifiers.clear()
	_envoys.clear()
	_cooldowns.clear()
	_subsidies.clear()


func to_dict() -> Dictionary:
	var subjects := []
	for s: String in _sorted(_subjects):
		subjects.append([_subjects[s].overlord, s, _subjects[s].type])
	var rivals := []
	for tag: String in _sorted(_rivals):
		for r: String in _rivals[tag]:
			rivals.append([tag, r])
	var modifiers := []
	for key: String in _sorted(_modifiers):
		var parts := key.split(">")
		for kind: String in _sorted(_modifiers[key]):
			modifiers.append([parts[0], parts[1], kind, _modifiers[key][kind]])
	var envoys := []
	for tag: String in _sorted(_envoys):
		for to: String in _envoys[tag]:
			envoys.append([tag, to])
	var cooldowns := []
	for key: String in _sorted(_cooldowns):
		var kind := key.get_slice(":", 0)
		var pair := key.get_slice(":", 1).split(">")
		cooldowns.append([kind, pair[0], pair[1], _cooldowns[key]])
	return {
		"subjects": subjects,
		"alliances": _pairs_list(_alliances), "marriages": _pairs_list(_marriages),
		"rivals": rivals, "modifiers": modifiers, "envoys": envoys, "cooldowns": cooldowns,
		"subsidies": subsidies(),
	}


static func _sorted(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


static func _pairs_list(table: Dictionary) -> Array:
	var out := []
	for key: String in _sorted(table):
		out.append(Array(key.split("|")))
	return out


## Problems with saved or scenario diplomacy; empty when `load_dict` will
## accept it. `countries` maps tag -> anything (only keys are used).
static func check_dict(data: Variant, countries: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("diplomacy must be an object")
		return errors
	var known := func(tag: Variant) -> bool: return tag is String and countries.has(tag)
	var subjects_seen := {}
	for row: Variant in data.get("subjects", []):
		if not (row is Array and row.size() == 3 and known.call(row[0]) and known.call(row[1])
				and row[2] in SUBJECT_TYPES and row[0] != row[1]):
			errors.append("bad subject relation %s" % var_to_str(row))
		elif subjects_seen.has(row[1]):
			errors.append("%s has two overlords" % row[1])
		else:
			subjects_seen[row[1]] = row[0]
	for key in ["alliances", "marriages", "rivals", "envoys"]:
		for row: Variant in data.get(key, []):
			if not (row is Array and row.size() == 2 and known.call(row[0]) and known.call(row[1]) and row[0] != row[1]):
				errors.append("bad %s entry %s" % [key, var_to_str(row)])
	for row: Variant in data.get("modifiers", []):
		if not (row is Array and row.size() == 4 and known.call(row[0]) and known.call(row[1])
				and MODIFIERS.has(row[2]) and (row[3] is float or row[3] is int)):
			errors.append("bad opinion modifier %s" % var_to_str(row))
	for row: Variant in data.get("cooldowns", []):
		if not (row is Array and row.size() == 4 and row[0] is String and known.call(row[1])
				and known.call(row[2]) and (row[3] is float or row[3] is int)):
			errors.append("bad cooldown %s" % var_to_str(row))
	for row: Variant in data.get("subsidies", []):
		if not (row is Array and row.size() == 3 and known.call(row[0]) and known.call(row[1]) and row[0] != row[1]
				and (row[2] is float or row[2] is int) and row[2] > 0):
			errors.append("bad subsidy %s" % var_to_str(row))
	# A subject's overlord may not itself be that subject's subject (no loops).
	for s: String in subjects_seen:
		var seen := {s: true}
		var o: String = subjects_seen[s]
		while subjects_seen.has(o):
			if seen.has(o):
				errors.append("subject loop through %s" % s)
				break
			seen[o] = true
			o = subjects_seen[o]
	return errors


## Replaces everything (call check_dict first).
func load_dict(data: Dictionary) -> void:
	clear()
	for row: Array in data.get("subjects", []):
		_subjects[row[1]] = {"overlord": row[0], "type": row[2]}
	for row: Array in data.get("alliances", []):
		_alliances[_pair(row[0], row[1])] = true
		_index_pair(_allies, row[0], row[1], true)
	for row: Array in data.get("marriages", []):
		_marriages[_pair(row[0], row[1])] = true
		_index_pair(_spouses, row[0], row[1], true)
	for row: Array in data.get("rivals", []):
		var list: Array = _rivals.get(row[0], [])
		if not row[1] in list:
			list.append(row[1])
			list.sort()
		_rivals[row[0]] = list
	for row: Array in data.get("modifiers", []):
		var key: String = row[0] + ">" + row[1]
		var mods: Dictionary = _modifiers.get(key, {})
		mods[row[2]] = float(row[3])
		_modifiers[key] = mods
	for row: Array in data.get("envoys", []):
		var list: Array = _envoys.get(row[0], [])
		list.append(row[1])
		_envoys[row[0]] = list
	for row: Array in data.get("cooldowns", []):
		_cooldowns["%s:%s>%s" % [row[0], row[1], row[2]]] = int(row[3])
	for row: Array in data.get("subsidies", []):
		_subsidies[row[0] + ">" + row[1]] = int(row[2])
	reset.emit()
