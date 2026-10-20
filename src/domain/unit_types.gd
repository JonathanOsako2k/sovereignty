class_name UnitTypes
extends RefCounted
## Every kind of regiment, ship and squadron from 1590 to 1949. Each is in use
## from one year to another and, for regional troops, only in some parts of
## the world (`groups`) or by some countries (`tags`): a player sees what their
## realm could field in their era — pike and shot in 1590s Europe, samurai in
## Japan, war elephants in India — and never tanks before their time.
##
## `men`: soldiers in a regiment (crew for ships, airmen for squadrons).
## `attack`, `defence`, `morale`: per man, relative to a 1590 pikeman.
## `speed`: km a day on good ground. `cost`: ducats to raise one,
## `upkeep`: ducats a month, `months`: to raise. `siege`: helps take forts.
## `capacity` (ships): soldiers it carries over the sea; transports carry the
## most and fight the least.

const CATALOGUE := {
	# --- 1590: the pike-and-shot age, and the world's own ways of war ---
	"levy": {"name": "Levies", "domain": "land", "kind": "levy", "from": 1590, "to": 1870, "men": 1000,
		"attack": 0.5, "defence": 0.6, "morale": 0.5, "speed": 20.0, "cost": 0.0, "upkeep": 0.25, "months": 0},
	"pike_and_shot": {"name": "Pike and shot", "domain": "land", "kind": "infantry", "from": 1590, "to": 1700,
		"groups": ["europe"], "men": 1000, "attack": 1.0, "defence": 1.2, "morale": 1.0, "speed": 20.0,
		"cost": 12.0, "upkeep": 1.0, "months": 3},
	"arquebusiers": {"name": "Arquebusiers", "domain": "land", "kind": "infantry", "from": 1590, "to": 1660,
		"groups": ["islamic", "india", "east_asia", "southeast_asia"], "men": 1000, "attack": 1.0, "defence": 0.9,
		"morale": 0.9, "speed": 20.0, "cost": 10.0, "upkeep": 0.9, "months": 3},
	"cuirassiers": {"name": "Cuirassiers", "domain": "land", "kind": "cavalry", "from": 1590, "to": 1700,
		"groups": ["europe"], "men": 1000, "attack": 1.5, "defence": 0.8, "morale": 1.0, "speed": 30.0,
		"cost": 25.0, "upkeep": 2.0, "months": 4},
	"horse_archers": {"name": "Horse archers", "domain": "land", "kind": "cavalry", "from": 1590, "to": 1760,
		"groups": ["steppe", "islamic", "east_asia"], "men": 1000, "attack": 1.3, "defence": 0.7, "morale": 1.0,
		"speed": 38.0, "cost": 18.0, "upkeep": 1.5, "months": 3},
	"janissaries": {"name": "Janissaries", "domain": "land", "kind": "infantry", "from": 1590, "to": 1826,
		"tags": ["TUR"], "men": 1000, "attack": 1.35, "defence": 1.25, "morale": 1.25, "speed": 20.0,
		"cost": 20.0, "upkeep": 1.8, "months": 4},
	"sipahi": {"name": "Sipahi", "domain": "land", "kind": "cavalry", "from": 1590, "to": 1830,
		"tags": ["TUR"], "men": 1000, "attack": 1.4, "defence": 0.8, "morale": 1.1, "speed": 34.0,
		"cost": 20.0, "upkeep": 1.6, "months": 3},
	"samurai": {"name": "Samurai", "domain": "land", "kind": "infantry", "from": 1590, "to": 1870,
		"groups": ["japan"], "men": 1000, "attack": 1.4, "defence": 1.1, "morale": 1.3, "speed": 22.0,
		"cost": 22.0, "upkeep": 1.8, "months": 4},
	"ashigaru": {"name": "Ashigaru", "domain": "land", "kind": "infantry", "from": 1590, "to": 1870,
		"groups": ["japan"], "men": 1000, "attack": 1.0, "defence": 1.0, "morale": 0.9, "speed": 20.0,
		"cost": 9.0, "upkeep": 0.8, "months": 2},
	"firelock_infantry": {"name": "Firelock infantry", "domain": "land", "kind": "infantry", "from": 1590,
		"to": 1720, "groups": ["east_asia"], "men": 1000, "attack": 1.0, "defence": 1.1, "morale": 0.9,
		"speed": 20.0, "cost": 10.0, "upkeep": 0.9, "months": 3},
	"war_elephants": {"name": "War elephants", "domain": "land", "kind": "cavalry", "from": 1590, "to": 1760,
		"groups": ["india", "southeast_asia"], "men": 1000, "attack": 1.7, "defence": 1.1, "morale": 1.0,
		"speed": 16.0, "cost": 30.0, "upkeep": 2.5, "months": 5},
	"camel_cavalry": {"name": "Camel cavalry", "domain": "land", "kind": "cavalry", "from": 1590, "to": 1920,
		"groups": ["islamic", "africa"], "men": 1000, "attack": 1.2, "defence": 0.8, "morale": 1.0, "speed": 30.0,
		"cost": 15.0, "upkeep": 1.3, "months": 3},
	"cossacks": {"name": "Cossacks", "domain": "land", "kind": "cavalry", "from": 1590, "to": 1918,
		"tags": ["RUS"], "men": 1000, "attack": 1.3, "defence": 0.8, "morale": 1.1, "speed": 36.0,
		"cost": 14.0, "upkeep": 1.2, "months": 2},
	"streltsy": {"name": "Streltsy", "domain": "land", "kind": "infantry", "from": 1590, "to": 1700,
		"tags": ["RUS"], "men": 1000, "attack": 1.0, "defence": 1.1, "morale": 1.0, "speed": 20.0,
		"cost": 11.0, "upkeep": 1.0, "months": 3},
	"warriors": {"name": "Warriors", "domain": "land", "kind": "infantry", "from": 1590, "to": 1900,
		"groups": ["africa", "americas", "oceania"], "men": 1000, "attack": 0.9, "defence": 0.8, "morale": 1.0,
		"speed": 22.0, "cost": 6.0, "upkeep": 0.6, "months": 2},
	"field_artillery": {"name": "Field artillery", "domain": "land", "kind": "artillery", "from": 1590,
		"to": 1949, "groups": ["europe", "islamic", "india", "east_asia", "japan", "southeast_asia"], "men": 1000,
		"attack": 1.6, "defence": 0.6, "morale": 0.9, "speed": 15.0, "cost": 30.0, "upkeep": 2.0, "months": 5,
		"siege": 1.0},
	# --- Later centuries (hidden until their time) ---
	"musketeers": {"name": "Musketeers", "domain": "land", "kind": "infantry", "from": 1650, "to": 1730,
		"men": 1000, "attack": 1.3, "defence": 1.2, "morale": 1.0, "speed": 20.0, "cost": 14.0, "upkeep": 1.1,
		"months": 3},
	"dragoons": {"name": "Dragoons", "domain": "land", "kind": "cavalry", "from": 1650, "to": 1860, "men": 1000,
		"attack": 1.5, "defence": 1.0, "morale": 1.0, "speed": 32.0, "cost": 26.0, "upkeep": 2.0, "months": 4},
	"line_infantry": {"name": "Line infantry", "domain": "land", "kind": "infantry", "from": 1700, "to": 1860,
		"men": 1000, "attack": 1.7, "defence": 1.5, "morale": 1.1, "speed": 22.0, "cost": 16.0, "upkeep": 1.2,
		"months": 3},
	"hussars": {"name": "Hussars", "domain": "land", "kind": "cavalry", "from": 1690, "to": 1860,
		"groups": ["europe"], "men": 1000, "attack": 1.9, "defence": 0.9, "morale": 1.2, "speed": 38.0,
		"cost": 28.0, "upkeep": 2.2, "months": 4},
	"grenadiers": {"name": "Grenadiers", "domain": "land", "kind": "infantry", "from": 1700, "to": 1860,
		"men": 1000, "attack": 2.0, "defence": 1.6, "morale": 1.3, "speed": 22.0, "cost": 22.0, "upkeep": 1.6,
		"months": 4},
	"horse_artillery": {"name": "Horse artillery", "domain": "land", "kind": "artillery", "from": 1760,
		"to": 1900, "men": 1000, "attack": 2.4, "defence": 0.8, "morale": 1.0, "speed": 30.0, "cost": 40.0,
		"upkeep": 2.6, "months": 5, "siege": 1.0},
	"rifle_infantry": {"name": "Rifle infantry", "domain": "land", "kind": "infantry", "from": 1850, "to": 1918,
		"men": 1000, "attack": 2.6, "defence": 2.4, "morale": 1.2, "speed": 24.0, "cost": 20.0, "upkeep": 1.5,
		"months": 3},
	"cavalry": {"name": "Cavalry", "domain": "land", "kind": "cavalry", "from": 1860, "to": 1940, "men": 1000,
		"attack": 2.4, "defence": 1.4, "morale": 1.2, "speed": 40.0, "cost": 30.0, "upkeep": 2.4, "months": 4},
	"heavy_artillery": {"name": "Heavy artillery", "domain": "land", "kind": "artillery", "from": 1870,
		"to": 1949, "men": 1000, "attack": 4.0, "defence": 1.0, "morale": 1.0, "speed": 18.0, "cost": 50.0,
		"upkeep": 3.2, "months": 5, "siege": 2.0},
	"machine_gun_company": {"name": "Machine-gun company", "domain": "land", "kind": "infantry", "from": 1890,
		"to": 1949, "men": 1000, "attack": 3.6, "defence": 4.6, "morale": 1.2, "speed": 20.0, "cost": 40.0,
		"upkeep": 2.6, "months": 4},
	"infantry_division": {"name": "Infantry division", "domain": "land", "kind": "infantry", "from": 1914,
		"to": 1949, "men": 10000, "attack": 3.6, "defence": 4.0, "morale": 1.3, "speed": 24.0, "cost": 300.0,
		"upkeep": 18.0, "months": 6},
	"mountain_division": {"name": "Mountain division", "domain": "land", "kind": "infantry", "from": 1915,
		"to": 1949, "men": 10000, "attack": 3.4, "defence": 4.4, "morale": 1.4, "speed": 22.0, "cost": 360.0,
		"upkeep": 21.0, "months": 7},
	"tank_battalion": {"name": "Tank battalion", "domain": "land", "kind": "armour", "from": 1916, "to": 1936,
		"men": 1000, "attack": 6.0, "defence": 4.0, "morale": 1.3, "speed": 25.0, "cost": 120.0, "upkeep": 8.0,
		"months": 8},
	"armoured_division": {"name": "Armoured division", "domain": "land", "kind": "armour", "from": 1935,
		"to": 1949, "men": 10000, "attack": 7.5, "defence": 5.5, "morale": 1.4, "speed": 45.0, "cost": 900.0,
		"upkeep": 50.0, "months": 10},
	"motorised_division": {"name": "Motorised division", "domain": "land", "kind": "infantry", "from": 1936,
		"to": 1949, "men": 10000, "attack": 4.4, "defence": 4.6, "morale": 1.3, "speed": 50.0, "cost": 600.0,
		"upkeep": 34.0, "months": 8},
	"paratroopers": {"name": "Paratroopers", "domain": "land", "kind": "infantry", "from": 1938, "to": 1949,
		"men": 5000, "attack": 4.6, "defence": 3.8, "morale": 1.6, "speed": 26.0, "cost": 400.0, "upkeep": 26.0,
		"months": 9},
	# --- Ships ---
	"galley": {"name": "Galley", "domain": "sea", "kind": "ship", "capacity": 150, "from": 1590, "to": 1720,
		"groups": ["europe", "islamic"], "men": 300, "attack": 0.8, "defence": 0.7, "morale": 1.0, "speed": 120.0,
		"cost": 15.0, "upkeep": 0.8, "months": 4},
	"carrack": {"name": "Carrack", "domain": "sea", "kind": "ship", "capacity": 250, "from": 1590, "to": 1650,
		"groups": ["europe"], "men": 300, "attack": 1.0, "defence": 1.1, "morale": 1.0, "speed": 110.0,
		"cost": 20.0, "upkeep": 1.0, "months": 6},
	"galleon": {"name": "Galleon", "domain": "sea", "kind": "ship", "capacity": 300, "from": 1590, "to": 1720,
		"groups": ["europe"], "men": 400, "attack": 1.4, "defence": 1.4, "morale": 1.0, "speed": 120.0,
		"cost": 30.0, "upkeep": 1.4, "months": 8},
	"junk": {"name": "War junk", "domain": "sea", "kind": "ship", "capacity": 200, "from": 1590, "to": 1860,
		"groups": ["east_asia", "southeast_asia"], "men": 300, "attack": 1.0, "defence": 1.1, "morale": 1.0,
		"speed": 110.0, "cost": 16.0, "upkeep": 0.9, "months": 5},
	"atakebune": {"name": "Atakebune", "domain": "sea", "kind": "ship", "capacity": 200, "from": 1590, "to": 1650,
		"groups": ["japan"], "men": 300, "attack": 1.1, "defence": 1.3, "morale": 1.1, "speed": 90.0,
		"cost": 18.0, "upkeep": 1.0, "months": 5},
	"turtle_ship": {"name": "Turtle ship", "domain": "sea", "kind": "ship", "capacity": 50, "from": 1590, "to": 1650,
		"tags": ["JOS"], "men": 150, "attack": 1.6, "defence": 2.0, "morale": 1.2, "speed": 90.0, "cost": 25.0,
		"upkeep": 1.2, "months": 6},
	"dhow": {"name": "War dhow", "domain": "sea", "kind": "ship", "capacity": 150, "from": 1590, "to": 1860,
		"groups": ["islamic", "india", "africa"], "men": 200, "attack": 0.8, "defence": 0.8, "morale": 1.0,
		"speed": 130.0, "cost": 10.0, "upkeep": 0.6, "months": 4},
	"war_canoe": {"name": "War canoes", "domain": "sea", "kind": "ship", "capacity": 50, "from": 1590, "to": 1900,
		"groups": ["oceania", "americas", "southeast_asia", "africa"], "men": 100, "attack": 0.4, "defence": 0.3,
		"morale": 1.0, "speed": 80.0, "cost": 3.0, "upkeep": 0.2, "months": 2},
	"ship_of_the_line": {"name": "Ship of the line", "domain": "sea", "kind": "ship", "capacity": 300, "from": 1650, "to": 1860,
		"men": 700, "attack": 2.6, "defence": 2.8, "morale": 1.1, "speed": 120.0, "cost": 60.0, "upkeep": 3.0,
		"months": 12},
	"frigate": {"name": "Frigate", "domain": "sea", "kind": "ship", "capacity": 150, "from": 1650, "to": 1880, "men": 300,
		"attack": 1.6, "defence": 1.4, "morale": 1.1, "speed": 160.0, "cost": 30.0, "upkeep": 1.5, "months": 8},
	"ironclad": {"name": "Ironclad", "domain": "sea", "kind": "ship", "capacity": 200, "from": 1860, "to": 1900, "men": 400,
		"attack": 4.5, "defence": 6.0, "morale": 1.2, "speed": 200.0, "cost": 120.0, "upkeep": 6.0, "months": 14},
	"cruiser": {"name": "Cruiser", "domain": "sea", "kind": "ship", "capacity": 400, "from": 1880, "to": 1949, "men": 600,
		"attack": 6.0, "defence": 6.0, "morale": 1.2, "speed": 320.0, "cost": 160.0, "upkeep": 8.0, "months": 16},
	"pre_dreadnought": {"name": "Pre-dreadnought", "domain": "sea", "kind": "ship", "capacity": 300, "from": 1890, "to": 1910,
		"men": 700, "attack": 9.0, "defence": 9.0, "morale": 1.2, "speed": 280.0, "cost": 260.0, "upkeep": 12.0,
		"months": 20},
	"destroyer": {"name": "Destroyer", "domain": "sea", "kind": "ship", "capacity": 100, "from": 1895, "to": 1949, "men": 200,
		"attack": 4.0, "defence": 3.0, "morale": 1.2, "speed": 520.0, "cost": 90.0, "upkeep": 4.0, "months": 10},
	"submarine": {"name": "Submarine", "domain": "sea", "kind": "ship", "capacity": 0, "from": 1900, "to": 1949, "men": 50,
		"attack": 6.0, "defence": 2.0, "morale": 1.3, "speed": 300.0, "cost": 110.0, "upkeep": 4.5, "months": 12},
	"battleship": {"name": "Battleship", "domain": "sea", "kind": "ship", "capacity": 500, "from": 1906, "to": 1949, "men": 1400,
		"attack": 16.0, "defence": 16.0, "morale": 1.3, "speed": 340.0, "cost": 500.0, "upkeep": 22.0,
		"months": 30},
	"aircraft_carrier": {"name": "Aircraft carrier", "domain": "sea", "kind": "ship", "capacity": 1000, "from": 1922, "to": 1949,
		"men": 2000, "attack": 18.0, "defence": 10.0, "morale": 1.3, "speed": 360.0, "cost": 650.0, "upkeep": 28.0,
		"months": 32},
	# --- Transports: armies carried over the sea ---
	"cargo_ship": {"name": "Merchant transports", "domain": "sea", "kind": "transport", "capacity": 400,
		"from": 1590, "to": 1700, "men": 60, "attack": 0.1, "defence": 0.3, "morale": 0.6, "speed": 100.0,
		"cost": 8.0, "upkeep": 0.3, "months": 3},
	"fluyt": {"name": "Fluyt transport", "domain": "sea", "kind": "transport", "capacity": 600, "from": 1590,
		"to": 1750, "groups": ["europe"], "men": 60, "attack": 0.1, "defence": 0.4, "morale": 0.6, "speed": 110.0,
		"cost": 10.0, "upkeep": 0.4, "months": 4},
	"transport_junk": {"name": "Transport junk", "domain": "sea", "kind": "transport", "capacity": 500,
		"from": 1590, "to": 1860, "groups": ["east_asia", "southeast_asia", "japan"], "men": 60, "attack": 0.1,
		"defence": 0.4, "morale": 0.6, "speed": 100.0, "cost": 9.0, "upkeep": 0.35, "months": 4},
	"transport_dhow": {"name": "Transport dhow", "domain": "sea", "kind": "transport", "capacity": 400,
		"from": 1590, "to": 1860, "groups": ["islamic", "india", "africa"], "men": 50, "attack": 0.1, "defence": 0.3,
		"morale": 0.6, "speed": 120.0, "cost": 7.0, "upkeep": 0.3, "months": 3},
	"east_indiaman": {"name": "East Indiaman", "domain": "sea", "kind": "transport", "capacity": 800, "from": 1700,
		"to": 1860, "men": 120, "attack": 0.6, "defence": 0.8, "morale": 0.8, "speed": 120.0, "cost": 20.0,
		"upkeep": 0.8, "months": 8},
	"steam_transport": {"name": "Steam transport", "domain": "sea", "kind": "transport", "capacity": 1500,
		"from": 1840, "to": 1910, "men": 150, "attack": 0.3, "defence": 1.0, "morale": 0.8, "speed": 220.0,
		"cost": 40.0, "upkeep": 1.5, "months": 8},
	"troopship": {"name": "Troopship", "domain": "sea", "kind": "transport", "capacity": 3000, "from": 1900,
		"to": 1949, "men": 200, "attack": 0.4, "defence": 1.5, "morale": 0.9, "speed": 300.0, "cost": 80.0,
		"upkeep": 3.0, "months": 10},
	# --- Aircraft (squadrons; flown from home bases once air war arrives) ---
	"fighter_squadron": {"name": "Fighter squadron (biplanes)", "domain": "air", "kind": "air", "from": 1914,
		"to": 1936, "men": 200, "attack": 3.0, "defence": 2.0, "morale": 1.3, "speed": 1500.0, "cost": 80.0,
		"upkeep": 5.0, "months": 6},
	"bomber_squadron": {"name": "Bomber squadron", "domain": "air", "kind": "air", "from": 1915, "to": 1949,
		"men": 300, "attack": 5.0, "defence": 1.5, "morale": 1.2, "speed": 1600.0, "cost": 140.0, "upkeep": 8.0,
		"months": 8},
	"monoplane_fighter": {"name": "Fighter squadron", "domain": "air", "kind": "air", "from": 1935, "to": 1949,
		"men": 200, "attack": 6.0, "defence": 4.0, "morale": 1.4, "speed": 3000.0, "cost": 160.0, "upkeep": 9.0,
		"months": 6},
	"strategic_bomber": {"name": "Strategic bomber wing", "domain": "air", "kind": "air", "from": 1940,
		"to": 1949, "men": 500, "attack": 10.0, "defence": 3.0, "morale": 1.3, "speed": 3200.0, "cost": 400.0,
		"upkeep": 20.0, "months": 12},
	"jet_fighter": {"name": "Jet fighter squadron", "domain": "air", "kind": "air", "from": 1944, "to": 1949,
		"men": 200, "attack": 11.0, "defence": 7.0, "morale": 1.5, "speed": 6000.0, "cost": 380.0, "upkeep": 18.0,
		"months": 10},
}

## No army or fleet may hold more men than this: wars of the far future are
## fought along fronts, not by one great host.
const MAX_STACK := 100000


static func name_of(id: String) -> String:
	return CATALOGUE[id].name if CATALOGUE.has(id) else id


static func get_type(id: String) -> Dictionary:
	return CATALOGUE.get(id, {})


## The military traditions a country belongs to, from where its capital lies:
## europe, islamic, steppe, india, east_asia, japan, southeast_asia, africa,
## americas, oceania.
static func groups_of(world: WorldState, tag: String) -> Dictionary:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id) if c else null
	var out := {}
	if cap == null:
		return out
	match cap.region:
		"EUR":
			out["europe"] = true
			if cap.lon > 40.0:
				out["steppe"] = true
		"MECA":
			if cap.climate == "cold_arid" and cap.lat > 36.0:
				out["steppe"] = true
			else:
				out["islamic"] = true
		"IND":
			out["india"] = true
		"CJK":
			if cap.lon > 129.0 and cap.lat > 30.0:
				out["japan"] = true
			else:
				out["east_asia"] = true
		"SEA":
			out["southeast_asia"] = true
		"AFR":
			if cap.lat > 15.0:
				out["islamic"] = true
			else:
				out["africa"] = true
		"NAM", "SAM":
			out["americas"] = true
		"OCE":
			out["oceania"] = true
		_:
			out["steppe"] = true
	return out


## Whether `tag` (of these traditions) can raise unit `id` in `year`.
static func available(id: String, year: int, groups: Dictionary, tag: String) -> bool:
	var u: Dictionary = CATALOGUE.get(id, {})
	if u.is_empty() or year < u.from or year >= u.to or id == "levy":
		return false
	if u.has("tags"):
		return tag in u.tags
	if u.has("groups"):
		for g: String in u.groups:
			if groups.has(g):
				return true
		return false
	return true


## The units `tag` can raise now, by domain ("land", "sea", "air"): only its
## era's and its region's.
static func recruitable(world: WorldState, tag: String, year: int, domain: String) -> Array[String]:
	var groups := groups_of(world, tag)
	var out: Array[String] = []
	for id: String in CATALOGUE:
		if CATALOGUE[id].domain == domain and available(id, year, groups, tag):
			out.append(id)
	return out


## The best unit of a kind `tag` can raise (most attack and defence).
static func best_of_kind(world: WorldState, tag: String, year: int, kind: String) -> String:
	var groups := groups_of(world, tag)
	var best := ""
	var best_power := -1.0
	for id: String in CATALOGUE:
		var u: Dictionary = CATALOGUE[id]
		if u.kind == kind and available(id, year, groups, tag):
			var power: float = (u.attack + u.defence) * u.men
			if power > best_power:
				best_power = power
				best = id
	return best
