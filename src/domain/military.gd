class_name Military
extends RefCounted
## The world's armed forces and wars (world.military): every army and fleet,
## wars with their sides and battle score, truces after peace, sieges under way
## and regiments being raised. This class is the single place these facts are
## kept; the rules (marching, battles, sieges, war and peace, the AI) live in
## MilitarySystem.

## Armies or fleets were raised, disbanded, merged, split, moved or fought.
signal changed
## Wars began or ended.
signal wars_changed
## Everything was replaced (new campaign, loaded save).
signal reset

## Years after a peace before the same countries may fight again.
const TRUCE_DAYS := 5 * 365
## Standing armies in 1590: men per person in countries of at least
## STANDING_MIN_PROVINCES provinces, up to STANDING_MAX.
const STANDING_SHARE := 0.0012
const STANDING_MIN_PROVINCES := 4
const STANDING_MAX := 60000
## Permanent navies: countries with at least NAVY_MIN_COASTS provinces on the
## open sea (lakes do not count), a ship for every NAVY_COASTS_PER_SHIP of
## them, up to NAVY_MAX ships.
const NAVY_MIN_COASTS := 4
const NAVY_COASTS_PER_SHIP := 2
const NAVY_MAX := 30
## Forts standing in 1590: every capital of a country of FORT_CAPITAL_PROVINCES
## or more, and great cities (development FORT_CITY_DEVELOPMENT+) of larger realms.
const FORT_CAPITAL_PROVINCES := 3
const FORT_CITY_DEVELOPMENT := 9
const FORT_CITY_REALM := 10
## Seafaring realms keep docks at their home port and at coastal cities of at
## least this development; their navies start berthed at home.
const DOCK_CITY_DEVELOPMENT := 9
## Share of a fleet's upkeep paid while it lies in port.
const DOCKED_UPKEEP := 0.5

var armies := {}  # id -> Army
var next_id := 1
## Wars: {id, name, attackers: [tags], defenders: [tags], start: day number,
## battle_score: float (for the attackers, -40..40)}. The first tag of each
## side leads it.
var wars: Array = []  # change only through add_war / remove_war (or populate / load_dict)
var next_war := 1
var truces := {}  # "A|B" (sorted) -> day number until which they may not fight
## Sieges and occupations under way: province id -> {by: tag, progress: days}.
var sieges := {}
## Regiments being raised: [tag, province id, unit type, days left].
var recruiting: Array = []
## Countries whose levies are under arms.
var levies_raised := {}
## Manpower for regular regiments: tag -> men available.
var manpower := {}

# Who fights whom, rebuilt after wars change: war id -> {tag: side}, tag ->
# [war ids] (in the order of `wars`), war id -> war.
var _war_sides := {}
var _tag_wars := {}
var _war_by_id := {}
var _refusing := {}  # subject -> [ids of wars it stayed out of (its land open to the enemy)]
var _index_dirty := true


static func _pair(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


# --- Armies --------------------------------------------------------------------------

func add_army(owner: String, location: int, regiments: Array, navy: bool, name: String) -> Army:
	var army := Army.new()
	army.id = next_id
	next_id += 1
	army.owner = owner
	army.location = location
	army.regiments = regiments
	army.navy = navy
	army.name = name
	armies[army.id] = army
	return army


func remove_army(id: int) -> void:
	armies.erase(id)


func get_army(id: int) -> Army:
	return armies.get(id)


func armies_of(tag: String, navy := false) -> Array[Army]:
	var out: Array[Army] = []
	for a: Army in armies.values():
		if a.owner == tag and a.navy == navy:
			out.append(a)
	return out


func armies_at(location: int, navy := false) -> Array[Army]:
	var out: Array[Army] = []
	for a: Army in armies.values():
		if a.location == location and a.navy == navy:
			out.append(a)
	return out


# --- Wars ----------------------------------------------------------------------------

## 0 for the attacking side, 1 for the defending side, -1 if not in the war.
static func side_of(war: Dictionary, tag: String) -> int:
	if tag in war.attackers:
		return 0
	if tag in war.defenders:
		return 1
	return -1


func add_war(war: Dictionary) -> void:
	wars.append(war)
	_index_dirty = true


func remove_war(war: Dictionary) -> void:
	wars.erase(war)
	_index_dirty = true


func _ensure_index() -> void:
	if not _index_dirty:
		return
	_war_sides = {}
	_tag_wars = {}
	_war_by_id = {}
	_refusing = {}
	for w: Dictionary in wars:
		for tag: String in w.get("refused", []):
			if not _refusing.has(tag):
				_refusing[tag] = []
			_refusing[tag].append(w.id)
		var sides := {}
		for tag: String in w.attackers:
			sides[tag] = 0
		for tag: String in w.defenders:
			sides[tag] = 1
		_war_sides[w.id] = sides
		_war_by_id[w.id] = w
		for tag: String in sides:
			if not _tag_wars.has(tag):
				_tag_wars[tag] = []
			_tag_wars[tag].append(w.id)
	_index_dirty = false


## The index for tight loops: [war id -> {tag: side}, tag -> [war ids]]
## (read only; valid until wars change).
func war_index() -> Array:
	_ensure_index()
	return [_war_sides, _tag_wars]


## Ids of the wars `tag` (a subject) stayed out of, though its overlord fights.
func refusing_wars(tag: String) -> Array:
	_ensure_index()
	return _refusing.get(tag, [])


## `tag` joins a war on `side` (a subject whose land was attacked, say).
func join_war(war: Dictionary, tag: String, side: int) -> void:
	war.get("refused", []).erase(tag)
	if not tag in war.attackers and not tag in war.defenders:
		(war.attackers if side == 0 else war.defenders).append(tag)
	_index_dirty = true


## `tag` leaves a war (a separate peace).
func leave_war(war: Dictionary, tag: String) -> void:
	war.attackers.erase(tag)
	war.defenders.erase(tag)
	_index_dirty = true


## The armies a fleet carries.
func cargo_of(fleet_id: int) -> Array[Army]:
	var out: Array[Army] = []
	for a: Army in armies.values():
		if a.aboard == fleet_id:
			out.append(a)
	return out


## Ids of the wars `tag` fights in (in the order of `wars`).
func war_ids_of(tag: String) -> Array:
	_ensure_index()
	return _tag_wars.get(tag, [])


## `tag`'s side in the war with this id: 0 attacking, 1 defending, -1 not in it.
func side_in(war_id: int, tag: String) -> int:
	_ensure_index()
	return _war_sides.get(war_id, {}).get(tag, -1)


func war_between(a: String, b: String) -> Dictionary:
	_ensure_index()
	for id: int in _tag_wars.get(a, []):
		var sides: Dictionary = _war_sides[id]
		if sides.has(b) and sides[b] != sides[a]:
			return _war_by_id[id]
	return {}


func at_war(a: String, b: String) -> bool:
	return not war_between(a, b).is_empty()


func wars_of(tag: String) -> Array:
	var out := []
	for id: int in war_ids_of(tag):
		out.append(_war_by_id[id])
	return out


func in_any_war(tag: String) -> bool:
	_ensure_index()
	return _tag_wars.has(tag)


func get_war(id: int) -> Dictionary:
	_ensure_index()
	return _war_by_id.get(id, {})


func in_truce(a: String, b: String, today: int) -> bool:
	return truces.get(_pair(a, b), -1) > today


func set_truce(a: String, b: String, until: int) -> void:
	truces[_pair(a, b)] = until


## Days of truce left between two countries (0 if none).
func truce_left(a: String, b: String, today: int) -> int:
	return maxi(truces.get(_pair(a, b), -1) - today, 0)


# --- Levies ---------------------------------------------------------------------------

## Men each province has under arms as levies (Province.levied), recounted
## from the regiments.
func recount_levies(world: WorldState) -> Array[int]:
	var counts := {}
	for a: Army in armies.values():
		for r: Array in a.regiments:
			if r[0] == "levy" and r[2] != 0:
				counts[r[2]] = counts.get(r[2], 0) + r[1]
	var changed_ids: Array[int] = []
	for p: Province in world.ownable_provinces():
		var n: int = counts.get(p.id, 0)
		if p.levied != n:
			p.levied = n
			changed_ids.append(p.id)
	return changed_ids


# --- The world of 1590 ----------------------------------------------------------------

## Forts, docks, standing armies and navies at the start: realms of some size
## keep a small standing army at their capital (levies are raised in war);
## coastal powers keep permanent navies, berthed at a dock in their home port
## (great coastal cities have docks too); capitals and great cities are
## fortified.
func populate(world: WorldState, year: int) -> void:
	armies.clear()
	wars.clear()
	_index_dirty = true
	truces.clear()
	sieges.clear()
	recruiting.clear()
	levies_raised.clear()
	manpower.clear()
	next_id = 1
	next_war = 1
	var counts := {}
	var people := {}
	var coasts := {}
	for p: Province in world.ownable_provinces():
		if p.owner_id != "":
			counts[p.owner_id] = counts.get(p.owner_id, 0) + 1
			people[p.owner_id] = people.get(p.owner_id, 0) + p.population
			for s: int in p.sea_ids:
				if world.get_province(s).terrain != "lake":
					coasts[p.owner_id] = coasts.get(p.owner_id, 0) + 1
					break
	for p: Province in world.ownable_provinces():
		var size: int = counts.get(p.owner_id, 0)
		var c := world.get_country(p.owner_id)
		if c == null:
			continue
		var fortified := (c.capital_province_id == p.id and size >= FORT_CAPITAL_PROVINCES) \
			or (p.development >= FORT_CITY_DEVELOPMENT and size >= FORT_CITY_REALM)
		if fortified and not "fort" in p.buildings:
			p.buildings.append("fort")
	var tags: Array = counts.keys()
	tags.sort()
	var seafaring := {}
	for tag: String in tags:
		manpower[tag] = float(int(people[tag] * MilitarySystem.MANPOWER_SHARE))  # full at the start
		var c := world.get_country(tag)
		var cap := world.get_province(c.capital_province_id)
		if cap == null or counts[tag] < STANDING_MIN_PROVINCES:
			continue
		var men := clampi(int(people[tag] * STANDING_SHARE / 1000.0) * 1000, 1000, STANDING_MAX)
		var regiments := standing_regiments(world, tag, year, men / 1000)
		if not regiments.is_empty():
			add_army(tag, cap.id, regiments, false, "Army of %s" % cap.name)
		if coasts.get(tag, 0) >= NAVY_MIN_COASTS:
			var port := home_port(world, tag)
			var ship := preferred_unit(world, tag, year, "ship")
			if port != 0 and ship != "":
				seafaring[tag] = true
				var ships: Array = []
				var count := clampi(coasts[tag] / NAVY_COASTS_PER_SHIP, 2, NAVY_MAX)
				for i in count:
					ships.append([ship, UnitTypes.get_type(ship).men, 0])
				var transport := preferred_unit(world, tag, year, "transport")
				if transport != "":
					for i in maxi(1, count / 4):  # a few transports to carry troops over the sea
						ships.append([transport, UnitTypes.get_type(transport).men, 0])
				add_army(tag, port, ships, true, "Navy of %s" % MilitarySystem.short_name(world, tag))
	_place_docks(world, seafaring)
	reset.emit()


## Docks at the home port and great coastal cities of these realms.
func _place_docks(world: WorldState, seafaring: Dictionary) -> void:
	for tag: String in seafaring:
		var port := world.get_province(home_port(world, tag))
		if port != null and not "dock" in port.buildings:
			port.buildings.append("dock")
	for p: Province in world.ownable_provinces():
		if seafaring.has(p.owner_id) and p.is_coastal and not p.sea_ids.is_empty() \
				and p.development >= DOCK_CITY_DEVELOPMENT and not "dock" in p.buildings:
			p.buildings.append("dock")


## A save from before docks: the docks of the start, for every realm with a
## fleet, and fleets lying idle off a dock of theirs berth in it.
func add_missing_docks(world: WorldState) -> void:
	for p: Province in world.ownable_provinces():
		if "dock" in p.buildings:
			return
	var seafaring := {}
	for a: Army in armies.values():
		if a.navy and world.get_country(a.owner) != null:
			seafaring[a.owner] = true
	_place_docks(world, seafaring)
	var docks := {}  # "owner:port sea" -> dock province id
	for p: Province in world.ownable_provinces():
		if "dock" in p.buildings and p.owner_id != "":
			docks["%s:%d" % [p.owner_id, port_sea(world, p)]] = p.id
	for a: Army in armies.values():
		var key := "%s:%d" % [a.owner, a.location]
		if a.navy and a.path.is_empty() and docks.has(key):
			a.location = docks[key]


## Whether a fleet lies in port (at a dock) rather than at sea.
static func is_berthed(world: WorldState, a: Army) -> bool:
	return a.navy and not world.get_province(a.location).is_sea


## The sea a port opens on (fleets enter and leave its dock only by it, so a
## dock is never a canal): of the province's open seas the nearest, a lake
## only if it has no sea; 0 inland.
static func port_sea(world: WorldState, p: Province) -> int:
	var best := 0
	var best_score := INF
	for s: int in p.sea_ids:
		var sea := world.get_province(s)
		var score := DiplomacyActions._haversine(p.lat, p.lon, sea.lat, sea.lon) + (1e6 if sea.terrain == "lake" else 0.0)
		if score < best_score:
			best_score = score
			best = s
	return best


## A realm's home port: its coastal province nearest the capital (on the
## open sea before a lake); 0 if it has no coast.
static func home_port(world: WorldState, tag: String) -> int:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id) if c else null
	if cap == null:
		return 0
	var best := 0
	var best_score := INF
	for p: Province in world.ownable_provinces():
		if p.owner_id != tag or p.sea_ids.is_empty():
			continue
		var lake := world.get_province(port_sea(world, p)).terrain == "lake"
		var score := DiplomacyActions._haversine(p.lat, p.lon, cap.lat, cap.lon) + (1e6 if lake else 0.0)
		if score < best_score:
			best_score = score
			best = p.id
	return best


## A standing army of `regiments` regiments in the era's and the realm's way:
## three in five infantry, a quarter horse, the rest guns (where it has them).
static func standing_regiments(world: WorldState, tag: String, year: int, count: int) -> Array:
	var infantry := preferred_unit(world, tag, year, "infantry")
	var horse := preferred_unit(world, tag, year, "cavalry")
	var guns := preferred_unit(world, tag, year, "artillery")
	var out: Array = []
	var n_horse := int(round(count * 0.25)) if horse != "" else 0
	var n_guns := int(round(count * 0.15)) if guns != "" else 0
	var n_foot := maxi(count - n_horse - n_guns, 0)
	if infantry == "":
		n_foot = 0
		n_horse = count if horse != "" else 0
	for spec: Array in [[infantry, n_foot], [horse, n_horse], [guns, n_guns]]:
		for i in spec[1]:
			out.append([spec[0], UnitTypes.get_type(spec[0]).men, 0])
	return out


## The unit of a kind a realm would field: its own (Janissaries, Cossacks,
## turtle ships) before its region's, before everyone's; the strongest of those.
static func preferred_unit(world: WorldState, tag: String, year: int, kind: String) -> String:
	var groups := UnitTypes.groups_of(world, tag)
	var best := ""
	var best_rank := -1.0
	for id: String in UnitTypes.CATALOGUE:
		var u: Dictionary = UnitTypes.CATALOGUE[id]
		if u.kind != kind or not UnitTypes.available(id, year, groups, tag):
			continue
		var tier := 2.0 if u.has("tags") else (1.0 if u.has("groups") else 0.0)
		var rank: float = tier * 1e6 + (u.attack + u.defence) * u.men
		if rank > best_rank:
			best_rank = rank
			best = id
	return best


## The sea a country's home port opens on; 0 if it has no coast.
static func home_sea(world: WorldState, tag: String) -> int:
	var port := world.get_province(home_port(world, tag))
	return port_sea(world, port) if port != null else 0


# --- Saves -----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var rows := []
	var ids: Array = armies.keys()
	ids.sort()
	for id: int in ids:
		rows.append(armies[id].to_array())
	var truce_rows := []
	var keys: Array = truces.keys()
	keys.sort()
	for k: String in keys:
		truce_rows.append([k, truces[k]])
	var siege_rows := []
	var sieged: Array = sieges.keys()
	sieged.sort()
	for id: int in sieged:
		siege_rows.append([id, sieges[id].by, sieges[id].progress])
	var raised: Array = levies_raised.keys()
	raised.sort()
	var pools := []
	var pool_tags: Array = manpower.keys()
	pool_tags.sort()
	for t: String in pool_tags:
		pools.append([t, manpower[t]])
	return {"armies": rows, "next_id": next_id, "wars": wars.duplicate(true), "next_war": next_war,
		"truces": truce_rows, "sieges": siege_rows, "recruiting": recruiting.duplicate(true), "levies": raised,
		"manpower": pools}


static func check_dict(data: Variant, world: WorldState, known: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	var countries: Dictionary = known if not known.is_empty() else world.countries
	if data == null:
		return errors  # an older save: forces as at the start
	if not data is Dictionary:
		errors.append("military must be an object")
		return errors
	for key in ["armies", "wars", "truces", "sieges", "recruiting", "levies"]:
		if not data.get(key) is Array:
			errors.append("military: '%s' must be a list" % key)
	if not errors.is_empty():
		return errors
	for row: Variant in data.armies:
		if not (row is Array and row.size() in [10, 12] and row[1] is String and countries.has(row[1])
				and (row[4] is float or row[4] is int) and world.get_province(int(row[4])) != null and row[5] is Array):
			errors.append("military: malformed army %s" % var_to_str(row).left(80))
			continue
		for r: Variant in row[5]:
			if not (r is Array and r.size() == 3 and UnitTypes.CATALOGUE.has(r[0])):
				errors.append("military: army %s has a bad regiment %s" % [row[0], var_to_str(r)])
	for w: Variant in data.wars:
		if not (w is Dictionary and w.get("attackers") is Array and w.get("defenders") is Array
				and not w.attackers.is_empty() and not w.defenders.is_empty()):
			errors.append("military: malformed war %s" % var_to_str(w).left(80))
			continue
		for tag: Variant in w.attackers + w.defenders:
			if not countries.has(tag):
				errors.append("military: war with unknown country '%s'" % tag)
	for t: Variant in data.levies:
		if not countries.has(t):
			errors.append("military: levies of unknown country '%s'" % t)
	return errors


func load_dict(data: Dictionary) -> void:
	armies.clear()
	for row: Array in data.armies:
		var a := Army.from_array(row)
		armies[a.id] = a
	next_id = int(data.get("next_id", armies.size() + 1))
	wars = []
	for w: Dictionary in data.wars:
		wars.append({"id": int(w.id), "name": w.name, "attackers": Array(w.attackers), "defenders": Array(w.defenders),
			"start": int(w.start), "battle_score": float(w.battle_score), "refused": Array(w.get("refused", []))})
	next_war = int(data.get("next_war", wars.size() + 1))
	_index_dirty = true  # (saves from 20 Oct 2026 may hold a "retreat_steps" rule: no longer used)
	truces = {}
	for row: Array in data.truces:
		truces[row[0]] = int(row[1])
	sieges = {}
	for row: Array in data.sieges:
		sieges[int(row[0])] = {"by": row[1], "progress": float(row[2])}
	recruiting = []
	for row: Array in data.recruiting:
		recruiting.append([row[0], int(row[1]), row[2], int(row[3])])
	levies_raised = {}
	for t: String in data.levies:
		levies_raised[t] = true
	manpower = {}
	for row: Array in data.get("manpower", []):
		manpower[row[0]] = float(row[1])
	reset.emit()
