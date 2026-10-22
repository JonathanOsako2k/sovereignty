class_name Claims
extends RefCounted
## Cores and claims (world.claims): which countries count a province as
## rightfully theirs. A core is a province a country holds as its own — every
## province's owner has one there once it has held the land CORE_YEARS, and a
## country keeps its cores on land it has lost. A claim is a lesser right (a
## throne, an old conquest, an ambition). Taking a core or a claim in a peace
## costs less war score; the AI goes to war over them.

signal changed

## Years a country must hold a province before it is a core of its own.
const CORE_YEARS := 25

## Historical rights in 1590, beyond every owner's cores on its own land:
## [kind, claimant, "at", lat, lon] (the province there),
## [kind, claimant, "owner", tag] (all of that country's land) or
## [kind, claimant, "box", owner, lat_min, lat_max, lon_min, lon_max].
## Only land another country owns is claimed.
const RIGHTS_1590 := [
	["core", "ENG", "at", 50.95, 1.86],  # Calais, lost in 1558
	["core", "SPA", "owner", "NED"],  # the rebel provinces of the Low Countries
	["claim", "FRA", "at", 42.82, -1.64],  # Upper Navarre: Henry IV is King of Navarre
	["core", "RUS", "at", 59.37, 28.19],  # Narva and Ivangorod, lost to Sweden in 1581
	["core", "RUS", "at", 59.75, 29.08],  # Koporye
	["claim", "SWE", "at", 56.95, 24.1],  # Riga
	["claim", "RUS", "at", 58.38, 26.72],  # Dorpat
	["core", "PLC", "at", 54.78, 32.05],  # Smolensk, Russian since 1514
	["core", "AUS", "box", "TUR", 45.5, 48.6, 16.0, 22.9],  # Ottoman Hungary
	["claim", "TUR", "box", "AUS", 45.5, 48.6, 16.6, 22.9],  # Royal Hungary
	["core", "SAF", "box", "TUR", 37.0, 42.0, 44.0, 50.5],  # ceded to the Ottomans in 1590
	["claim", "SAD", "at", 16.77, -3.0],  # Timbuktu
	["claim", "SAD", "at", 16.27, -0.04],  # Gao
	["claim", "MUG", "at", 31.61, 65.71],  # Kandahar
	["claim", "JAP", "at", 35.18, 129.08],  # Busan: Hideyoshi's ambitions in Korea
	["claim", "JAP", "at", 37.57, 126.98],  # Hanseong
	["core", "FRA", "owner", "LEA"],  # the League's France is the crown's
	["claim", "LEA", "owner", "FRA"],  # and the League claims the crown for "Charles X"
	["core", "NED", "box", "SPA", 51.4, 53.6, 3.3, 7.3],  # the Netherlands Spain still holds
	["claim", "NED", "box", "SPA", 49.4, 51.4, 2.3, 6.5],  # the Spanish Netherlands
	["claim", "JIA", "owner", "HAI"],  # the Jurchens, each after the others' land
	["claim", "HAI", "owner", "JIA"],
]

var cores := {}  # province id -> Array of tags
var claims := {}  # province id -> Array of tags
## Province id -> [owner, day it was first seen holding it], for owners that
## have no core there yet.
var held := {}


func is_core(tag: String, id: int) -> bool:
	return tag in cores.get(id, [])


func has_claim(tag: String, id: int) -> bool:
	return tag in claims.get(id, [])


func cores_on(id: int) -> Array:
	return cores.get(id, [])


func claims_on(id: int) -> Array:
	return claims.get(id, [])


func add_core(tag: String, id: int) -> void:
	if not cores.has(id):
		cores[id] = []
	if not tag in cores[id]:
		cores[id].append(tag)
		remove_claim(tag, id)  # a core supersedes a claim
		changed.emit()


## A country gives up its core on a province (it sold or traded it away).
func remove_core(tag: String, id: int) -> void:
	if cores.has(id) and tag in cores[id]:
		cores[id].erase(tag)
		if cores[id].is_empty():
			cores.erase(id)
		changed.emit()


func add_claim(tag: String, id: int) -> void:
	if is_core(tag, id):
		return
	if not claims.has(id):
		claims[id] = []
	if not tag in claims[id]:
		claims[id].append(tag)
		changed.emit()


func remove_claim(tag: String, id: int) -> void:
	if claims.has(id) and tag in claims[id]:
		claims[id].erase(tag)
		if claims[id].is_empty():
			claims.erase(id)
		changed.emit()


## The start: every owner's cores on its land (held long since), and the
## historical rights of 1590.
func populate(world: WorldState, day: int) -> void:
	cores.clear()
	claims.clear()
	held.clear()
	for p: Province in world.ownable_provinces():
		if p.owner_id != "":
			cores[p.id] = [p.owner_id]
	for right: Array in RIGHTS_1590:
		var kind: String = right[0]
		var tag: String = right[1]
		if world.get_country(tag) == null:
			continue
		var ids: Array[int] = []
		match right[2]:
			"at":
				var p := world.province_near(right[3], right[4])
				if p != null:
					ids.append(p.id)
			"owner":
				for p: Province in world.ownable_provinces():
					if p.owner_id == right[3]:
						ids.append(p.id)
			"box":
				for p: Province in world.ownable_provinces():
					if p.owner_id == right[3] and p.lat >= right[4] and p.lat <= right[5] \
							and p.lon >= right[6] and p.lon <= right[7]:
						ids.append(p.id)
		for id: int in ids:
			var owner := world.get_province(id).owner_id
			if owner == "" or owner == tag:
				continue
			if kind == "core":
				add_core(tag, id)
			else:
				add_claim(tag, id)
	changed.emit()


## Yearly: provinces held CORE_YEARS become their owners' cores.
func yearly(world: WorldState, day: int) -> void:
	for p: Province in world.ownable_provinces():
		if p.owner_id == "" or is_core(p.owner_id, p.id):
			held.erase(p.id)
			continue
		var rec: Array = held.get(p.id, [])
		if rec.is_empty() or rec[0] != p.owner_id:
			held[p.id] = [p.owner_id, day]
		elif day - int(rec[1]) >= CORE_YEARS * 365:
			add_core(p.owner_id, p.id)
			held.erase(p.id)


## The countries each country holds a grudge against: for each tag with a core
## or claim on another's land, {owner: true}.
static func grudges(world: WorldState, claims_obj: Claims) -> Dictionary:
	var out := {}
	for table: Dictionary in [claims_obj.cores, claims_obj.claims]:
		for id: int in table:
			var owner := world.get_province(id).owner_id
			for tag: String in table[id]:
				if owner != "" and owner != tag:
					if not out.has(tag):
						out[tag] = {}
					out[tag][owner] = true
	return out


# --- Saves -----------------------------------------------------------------------------

## Cores and claims by country ([tag, [province ids]]: small), the record of
## who holds what by province.
func to_dict() -> Dictionary:
	var held_rows := []
	var ids: Array = held.keys()
	ids.sort()
	for id: int in ids:
		held_rows.append([id, held[id][0], held[id][1]])
	return {"cores": _by_tag(cores), "claims": _by_tag(claims), "held": held_rows}


static func _by_tag(table: Dictionary) -> Array:
	var tags := {}
	for id: int in table:
		for tag: String in table[id]:
			if not tags.has(tag):
				tags[tag] = []
			tags[tag].append(id)
	var keys: Array = tags.keys()
	keys.sort()
	var out := []
	for tag: String in keys:
		tags[tag].sort()
		out.append([tag, tags[tag]])
	return out


static func check_dict(data: Variant, world: WorldState, known: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	var countries: Dictionary = known if not known.is_empty() else world.countries
	if data == null:
		return errors  # an older save: rights as at the start
	if not data is Dictionary:
		errors.append("claims must be an object")
		return errors
	for key in ["cores", "claims", "held"]:
		if not data.get(key) is Array:
			errors.append("claims: '%s' must be a list" % key)
	if not errors.is_empty():
		return errors
	for key in ["cores", "claims"]:
		for row: Variant in data[key]:
			if not (row is Array and row.size() == 2 and row[0] is String and countries.has(row[0])
					and row[1] is Array and row[1].all(func(id: Variant) -> bool:
						return (id is float or id is int) and world.get_province(int(id)) != null)):
				errors.append("claims: malformed %s row %s" % [key, var_to_str(row).left(60)])
				break
	for row: Variant in data.held:
		if not (row is Array and row.size() == 3 and (row[0] is float or row[0] is int)
				and world.get_province(int(row[0])) != null and row[1] is String and (row[2] is float or row[2] is int)):
			errors.append("claims: malformed held row %s" % var_to_str(row).left(60))
			break
	return errors


func load_dict(data: Dictionary) -> void:
	cores.clear()
	claims.clear()
	held.clear()
	for pair: Array in [[data.cores, cores], [data.claims, claims]]:
		var table: Dictionary = pair[1]
		for row: Array in pair[0]:
			for id: Variant in row[1]:
				if not table.has(int(id)):
					table[int(id)] = []
				table[int(id)].append(str(row[0]))
	for row: Array in data.held:
		held[int(row[0])] = [str(row[1]), int(row[2])]
	changed.emit()
