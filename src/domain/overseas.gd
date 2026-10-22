class_name Overseas
extends RefCounted
## Overseas territory, colonial regions and colonial nations.
##
## The world beyond Europe and the Middle East is drawn up into colonial
## regions (New Spain, Peru, Brazil, the Caribbean, India, the East Indies…).
## A province is **overseas** for its owner when it lies in a colonial region,
## in another world region than the capital, with no route to the capital over
## the owner's own land (Spain's Mexico is; Russia's Siberia is not).
## Overseas land is not governed as the realm's own: it raises no levies, and
## once a country holds NATION_MIN overseas provinces in one colonial region
## they become a **colonial nation** — a new country, the owner's "colony"
## subject (it follows its mother country to war and pays it tribute), with
## every overseas province of the mother country in that region; later ones
## join it as they are colonised. 1590 opens with Spain's viceroyalties and
## Portugal's State of Brazil, Estado da Índia and Mozambique.

const NATION_MIN := 3

## [id, name, adjective, world regions, boxes [lat_min, lat_max, lon_min, lon_max]];
## a province belongs to the first that holds it.
const REGIONS := [
	["florida", "Florida", "Floridian", ["NAM"], [[24.0, 31.5, -88.0, -79.5]]],
	["caribbean", "the Caribbean", "Antillean", ["NAM", "SAM"], [[17.5, 27.5, -85.0, -59.0], [10.9, 18.5, -65.0, -59.0]]],
	["new_spain", "New Spain", "Novohispanic", ["NAM"], [[7.0, 33.0, -118.0, -77.0]]],
	["eastern_america", "Eastern America", "American", ["NAM"], [[31.5, 46.0, -88.0, -66.0]]],
	["louisiana", "Louisiana", "Louisianan", ["NAM"], [[28.0, 49.0, -105.0, -88.0]]],
	["california", "California", "Californian", ["NAM"], [[22.0, 42.0, -125.0, -105.0]]],
	["cascadia", "Cascadia", "Cascadian", ["NAM"], [[42.0, 60.0, -140.0, -105.0]]],
	["canada", "Canada", "Canadian", ["NAM"], [[43.0, 62.0, -105.0, -52.0]]],
	["arctic_america", "Arctic America", "Arctic", ["NAM"], [[55.0, 84.0, -170.0, -10.0]]],
	["new_granada", "New Granada", "Granadine", ["SAM", "NAM"], [[-1.0, 13.0, -80.0, -59.0]]],
	["guiana", "Guiana", "Guianese", ["SAM"], [[1.0, 9.0, -60.0, -50.0]]],
	["peru", "Peru", "Peruvian", ["SAM"], [[-27.0, -1.0, -82.0, -62.0], [-40.0, -27.0, -76.0, -68.0]]],
	["brazil", "Brazil", "Brazilian", ["SAM"], [[-34.0, 5.5, -53.5, -34.0], [-20.0, 5.5, -74.0, -53.5]]],
	["la_plata", "La Plata", "Platine", ["SAM"], [[-56.0, -20.0, -76.0, -48.0]]],
	["maghreb", "the Maghreb", "Maghrebi", ["AFR"], [[27.0, 38.0, -18.0, 12.0]]],
	["west_africa", "West Africa", "West African", ["AFR"], [[0.0, 27.0, -26.0, 12.0]]],
	["congo", "the Congo", "Congolese", ["AFR"], [[-18.0, 0.0, 8.0, 30.0]]],
	["southern_africa", "Southern Africa", "South African", ["AFR"], [[-36.0, -18.0, 10.0, 36.0]]],
	["east_africa", "East Africa", "East African", ["AFR"], [[-27.0, 18.0, 25.0, 60.0]]],
	["india", "India", "Indian", ["IND"], [[5.0, 37.0, 60.0, 98.0]]],
	["philippines", "the Philippines", "Philippine", ["SEA"], [[4.0, 21.5, 116.0, 127.5]]],
	["east_indies", "the East Indies", "East Indies", ["SEA"], [[-11.0, 8.0, 94.0, 141.0]]],
	["indochina", "Indochina", "Indochinese", ["SEA"], [[8.0, 30.0, 92.0, 110.0]]],
	["east_asia", "East Asia", "East Asian", ["CJK"], [[18.0, 55.0, 100.0, 150.0]]],
	["australia", "Australia", "Australian", ["OCE"], [[-45.0, -10.0, 112.0, 155.0]]],
	["pacific", "the Pacific", "Pacific", ["OCE", "SEA"], [[-50.0, 30.0, 130.0, 250.0]]],
]

## Colonial nations history named: "mother:region" -> [name, adjective,
## seat's latitude, longitude] (their capital: the province nearest it).
const NATION_NAMES := {
	"SPA:new_spain": ["Viceroyalty of New Spain", "Novohispanic", 19.43, -99.13],  # Mexico City
	"SPA:peru": ["Viceroyalty of Peru", "Peruvian", -12.05, -77.04],  # Lima
	"SPA:new_granada": ["New Kingdom of Granada", "Granadine", 4.71, -74.07],  # Santa Fe de Bogotá
	"SPA:philippines": ["Captaincy General of the Philippines", "Philippine", 14.6, 120.98],  # Manila
	"SPA:la_plata": ["Governorate of the Río de la Plata", "Platine", -25.26, -57.58],  # Asunción
	"SPA:caribbean": ["Audiencia of Santo Domingo", "Antillean", 18.47, -69.89],  # Santo Domingo
	"SPA:florida": ["Spanish Florida", "Floridian", 29.9, -81.31],  # St. Augustine
	"POR:brazil": ["State of Brazil", "Brazilian", -12.97, -38.5],  # Salvador da Bahia
	"POR:india": ["Estado da Índia", "Indo-Portuguese", 15.5, 73.83],  # Goa
	"POR:east_africa": ["Captaincy of Mozambique", "Mozambican", -15.03, 40.73],  # Mozambique Island
	"POR:congo": ["Kingdom of Angola", "Angolan", -8.84, 13.23],  # Luanda
	"ENG:eastern_america": ["Thirteen Colonies", "Colonial", 999.0, 0.0],
	"ENG:canada": ["British North America", "Canadian", 999.0, 0.0],
	"ENG:india": ["Company India", "Anglo-Indian", 999.0, 0.0],
	"ENG:australia": ["New South Wales", "Australian", -33.87, 151.21],  # Sydney
	"FRA:canada": ["New France", "Canadian", 46.81, -71.21],  # Québec
	"FRA:louisiana": ["Louisiane", "Louisianan", 29.95, -90.07],  # New Orleans
	"NED:east_indies": ["Dutch East Indies", "East Indies", -6.2, 106.85],  # Batavia
	"NED:southern_africa": ["Cape Colony", "Cape", -33.92, 18.42],  # Cape Town
	"NED:eastern_america": ["New Netherland", "New Netherlandish", 40.71, -74.01],  # New Amsterdam
	"NED:brazil": ["Dutch Brazil", "Brazilian", -8.05, -34.9],  # Recife
}

static var _region_cache := {}  # province id -> region id ("" for none)


## The colonial region a province lies in ("" if none: Europe, the Middle
## East and land outside every region).
static func region_of(p: Province) -> String:
	if _region_cache.has(p.id):
		return _region_cache[p.id]
	var found := ""
	for r: Array in REGIONS:
		if not p.region in r[3]:
			continue
		for box: Array in r[4]:
			if p.lat >= box[0] and p.lat <= box[1] and ((p.lon >= box[2] and p.lon <= box[3])
					or (p.lon + 360.0 >= box[2] and p.lon + 360.0 <= box[3])):
				found = r[0]
				break
		if found != "":
			break
	_region_cache[p.id] = found
	return found


static func region_name(id: String) -> String:
	for r: Array in REGIONS:
		if r[0] == id:
			return r[1]
	return id


## The name without a leading "the" ("Caribbean"), for "Dutch Caribbean".
static func region_short(id: String) -> String:
	return region_name(id).trim_prefix("the ")


static func _region_adjective(id: String) -> String:
	for r: Array in REGIONS:
		if r[0] == id:
			return r[2]
	return id


## Province id -> true for every overseas province in the world (see the top).
static func overseas_ids(world: WorldState) -> Dictionary:
	var out := {}
	var candidates := {}  # tag -> [provinces outside the capital's world region, in a colonial region]
	for p: Province in world.ownable_provinces():
		if p.owner_id == "":
			continue
		var c := world.get_country(p.owner_id)
		var cap := world.get_province(c.capital_province_id) if c else null
		if cap == null or p.region == cap.region or region_of(p) == "":
			continue
		if not candidates.has(p.owner_id):
			candidates[p.owner_id] = []
		candidates[p.owner_id].append(p)
	for tag: String in candidates:
		var home := _joined_to_capital(world, tag)
		for p: Province in candidates[tag]:
			if not home.has(p.id):
				out[p.id] = true
	return out


## The provinces a country can reach from its capital over its own land.
static func _joined_to_capital(world: WorldState, tag: String) -> Dictionary:
	var cap := world.get_country(tag).capital_province_id
	var seen := {cap: true}
	var frontier: Array[int] = [cap]
	while not frontier.is_empty():
		var next: Array[int] = []
		for id: int in frontier:
			for n: int in world.get_province(id).neighbour_ids:
				if not seen.has(n) and world.get_province(n).owner_id == tag:
					seen[n] = true
					next.append(n)
		frontier = next
	return seen


## A province passes to a colonial nation; held by its old owner, control goes
## with it (occupied by an enemy, it stays occupied).
static func _hand_over(world: WorldState, id: int, to: String) -> void:
	var p := world.get_province(id)
	world.transfer_province(id, to, p.controller_id != p.owner_id)


## The colonial nation a mother country has in a region ("" if none).
static func nation_in(world: WorldState, mother: String, region: String) -> String:
	for tag: String in world.diplomacy.subjects_of(mother):
		var c := world.get_country(tag)
		if c != null and c.colonial_region == region and world.diplomacy.subject_type(tag) == "colony":
			return tag
	return ""


## Brings the overseas world up to date: the overseas map is worked out
## afresh; overseas provinces in a region where their owner has a colonial
## nation pass to it; NATION_MIN or more in a region without one found it.
## Returns what happened: [["founded" | "joined", nation tag, mother, region,
## provinces handed over]].
static func update(world: WorldState) -> Array:
	world.overseas = overseas_ids(world)
	var by_mother := {}  # mother -> region -> [province ids]
	for id: int in world.overseas:
		var p := world.get_province(id)
		var mother := p.owner_id
		if world.diplomacy.subject_type(mother) == "colony":
			continue  # a colonial nation's own overseas land stays its own
		var region := region_of(p)
		if not by_mother.has(mother):
			by_mother[mother] = {}
		if not by_mother[mother].has(region):
			by_mother[mother][region] = []
		by_mother[mother][region].append(id)
	var events := []
	var mothers: Array = by_mother.keys()
	mothers.sort()
	for mother: String in mothers:
		var regions: Array = by_mother[mother].keys()
		regions.sort()
		for region: String in regions:
			var ids: Array = by_mother[mother][region]
			var nation := nation_in(world, mother, region)
			if nation != "":
				for id: int in ids:
					_hand_over(world, id, nation)
				events.append(["joined", nation, mother, region, ids.size()])
			elif ids.size() >= NATION_MIN:
				nation = found_nation(world, mother, region, ids)
				events.append(["founded", nation, mother, region, ids.size()])
	if not events.is_empty():
		world.overseas = overseas_ids(world)
	return events


## Founds a colonial nation of `mother` in `region` from these provinces: a new
## country in a shade of its mother's colour, its capital the most developed of
## them, its government colonial, with cores on its land, settling the
## frontier beyond it; the mother's "colony" subject. Returns its tag.
static func found_nation(world: WorldState, mother: String, region: String, ids: Array) -> String:
	var m := world.get_country(mother)
	var named: Array = NATION_NAMES.get("%s:%s" % [mother, region], [])
	var name: String = named[0] if not named.is_empty() else "%s %s" % [m.adjective, region_short(region)]
	var adjective: String = named[1] if not named.is_empty() else _region_adjective(region)
	var color := m.color.lightened(0.18) if m.color.get_luminance() < 0.6 else m.color.darkened(0.18)
	var c := world.create_country(name, adjective, color, "Colonial government")
	c.colonial_region = region
	c.religion = m.religion  # its settlers' faith
	c.start_religion = c.religion
	c.culture = m.culture  # and people
	c.start_culture = c.culture
	c.treasury = minf(500.0, 30.0 + 2.0 * ids.size())  # founding money, as every realm of 1590 has
	c.colonial_policy = 1  # settle the frontier beside its land
	c.start_colonial_policy = 1
	var development := 0
	for id: int in ids:
		development += world.get_province(id).development
	c.rank = Ranks.for_colony(name, development)  # a viceroyalty, a captaincy …
	c.start_rank = c.rank
	# Its seat: the province nearest the historical one, else the most populous.
	var capital := -1
	var best := -INF
	for id: int in ids:
		var p := world.get_province(id)
		var score: float = float(p.population)
		if named.size() == 4 and float(named[2]) < 900.0:
			score = -DiplomacyActions._haversine(p.lat, p.lon, named[2], named[3])
		if score > best or (score == best and id < capital):
			best = score
			capital = id
	c.capital_province_id = capital
	for id: int in ids:
		_hand_over(world, id, c.id)
		world.claims.add_core(c.id, id)
	world.diplomacy.set_subject(mother, c.id, "colony")
	return c.id
