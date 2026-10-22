class_name WorldLoader
extends RefCounted
## Builds a WorldState from static world data plus a scenario file.

const PROVINCES_PATH := "res://data/world/provinces.json"
const COUNTRIES_PATH := "res://data/world/countries.json"
const DEFAULT_SCENARIO_PATH := "res://data/scenarios/1590.json"

## Problems found while loading (parse errors and validation failures).
var errors := PackedStringArray()


func load_world(scenario_path := DEFAULT_SCENARIO_PATH,
		provinces_path := PROVINCES_PATH, countries_path := COUNTRIES_PATH) -> WorldState:
	errors.clear()
	var province_data := _read_json(provinces_path)
	var country_data := _read_json(countries_path)
	var scenario := _read_json(scenario_path)
	if not errors.is_empty():
		return null

	var world := WorldState.new()
	world.data_version = int(province_data.get("version", 0))
	var map: Dictionary = province_data.get("map", {})
	world.map_size = Vector2i(int(map.get("width", 0)), int(map.get("height", 0)))
	world.id_texture_path = map.get("id_texture", "")
	world.height_texture_path = map.get("height_texture", "")
	# Saves hold province ids, so what must match is the id map itself.
	world.data_fingerprint = FileAccess.get_md5(world.id_texture_path)
	world.compatible_fingerprints = map.get("compatible_id_textures", [])
	world.regions = province_data.get("regions", {})
	world.projection = map.get("projection", {})

	var entries: Array = province_data.get("provinces", [])
	for entry: Dictionary in province_data.get("wastelands", []):
		entry["wasteland"] = true
		entries.append(entry)
	for entry: Dictionary in province_data.get("seas", []):
		entry["sea"] = true
		entries.append(entry)
	for entry: Dictionary in entries:
		var p := Province.new()
		p.is_wasteland = entry.get("wasteland", false)
		p.is_sea = entry.get("sea", false)
		for n in entry.get("seas", []):
			p.sea_ids.append(int(n))
		for n in entry.get("coasts", []):
			p.coast_ids.append(int(n))
		p.division = entry.get("division", "")
		p.id = int(entry.id)
		p.name = entry.get("name", "Province %d" % p.id)
		p.region = entry.get("region", "")
		p.terrain = entry.get("terrain", "plains")
		p.topography = entry.get("topography", "")
		p.vegetation = entry.get("vegetation", "")
		p.climate = entry.get("climate", "")
		p.elevation = int(entry.get("elevation", 0))
		p.start_resource = entry.get("resource", "")
		p.resource = p.start_resource
		for d: Array in entry.get("deposits", []):
			p.deposits.append([d[0], int(d[1]), float(d[2])])
		p.is_coastal = bool(entry.get("coastal", false))
		p.area = int(entry.get("area", 0))
		p.area_km2 = int(entry.get("area_km2", 0))
		p.lat = float(entry.get("lat", 0.0))
		p.lon = float(entry.get("lon", 0.0))
		var label: Array = entry.get("label", [0, 0])
		p.label_position = Vector2(label[0], label[1])
		var b: Array = entry.get("bounds", [0, 0, 0, 0])
		p.bounds = Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
		for n in entry.get("neighbours", []):
			p.neighbour_ids.append(int(n))
		if world.provinces.has(p.id):
			errors.append("duplicate province id %d" % p.id)
		world.provinces[p.id] = p

	for entry: Dictionary in country_data.get("countries", []):
		var c := Country.new()
		c.id = entry.id
		c.name = entry.get("name", c.id)
		c.adjective = entry.get("adjective", c.name)
		c.color = Color.from_string(entry.get("color", "#888888"), Color.GRAY)
		if world.countries.has(c.id):
			errors.append("duplicate country id %s" % c.id)
		world.countries[c.id] = c
	world.country_order.assign(world.countries.keys())
	world.country_order.sort()

	_apply_scenario(world, scenario)
	for p: Province in world.ownable_provinces():
		p.pops = world.initial_pops(p)
	world.claims.populate(world, GameClock.days_since_epoch(int(world.start_date.year), int(world.start_date.month),
		int(world.start_date.day)))
	Overseas.update(world)  # Spain's viceroyalties, Portugal's Brazil, India and Mozambique
	# Forces after the colonial nations: realms' armies and fleets match the
	# land they govern (a colonial nation of some size keeps its own).
	world.military.populate(world, int(world.start_date.year))
	errors.append_array(world.validate())
	return world


func _apply_scenario(world: WorldState, scenario: Dictionary) -> void:
	world.player_country_id = scenario.get("player_country", "")
	var diplomacy: Variant = scenario.get("diplomacy", {})
	var problems := Diplomacy.check_dict(diplomacy, world.countries)
	if problems.is_empty():
		world.diplomacy.load_dict(diplomacy)
	else:
		for e in problems:
			errors.append("scenario diplomacy: " + e)
	var date: Dictionary = scenario.get("start_date", {})
	world.start_date = {
		"year": int(date.get("year", 1590)), "month": int(date.get("month", 1)), "day": int(date.get("day", 1)),
	}
	var country_states: Dictionary = scenario.get("countries", {})
	for tag: String in country_states:
		var c := world.get_country(tag)
		if c == null:
			errors.append("scenario references unknown country '%s'" % tag)
			continue
		var s: Dictionary = country_states[tag]
		c.capital_province_id = int(s.get("capital", 0))
		c.government_type = s.get("government", "")
		c.colonial_policy = clampi(int(s.get("colonial", 0)), 0, Colonisation.POLICIES.size() - 1)
		c.start_colonial_policy = c.colonial_policy
		c.ideas = Ideas.START.get(tag, []).duplicate()
		c.start_ideas = c.ideas.duplicate()
		c.religion = s.get("religion", "") if Religions.has(s.get("religion", "")) else ""
		c.start_religion = c.religion
		c.culture = s.get("culture", "") if Cultures.has(s.get("culture", "")) else ""
		c.start_culture = c.culture
		c.treasury = float(s.get("treasury", 0))
		c.legitimacy = float(s.get("legitimacy", 50))
		c.stability = int(s.get("stability", 0))
	var province_states: Dictionary = scenario.get("provinces", {})
	for key: String in province_states:
		var p := world.get_province(int(key))
		if p == null:
			errors.append("scenario references unknown province '%s'" % key)
			continue
		var s: Dictionary = province_states[key]
		p.owner_id = s.get("owner", "")
		p.controller_id = s.get("controller", p.owner_id)
		p.population = int(s.get("population", 0))
		p.development = int(s.get("development", 1))
		p.buildings = Array(s.get("buildings", []))
		p.religion = s.get("religion", "") if Religions.has(s.get("religion", "")) else ""
		p.start_religion = p.religion
		p.culture = s.get("culture", "") if Cultures.has(s.get("culture", "")) else ""
	# Ranks: the 1590 emperors and great kings, every other realm by its size and title.
	var development := {}
	for p: Province in world.ownable_provinces():
		if p.owner_id != "":
			development[p.owner_id] = development.get(p.owner_id, 0) + p.development
	for c: Country in world.countries.values():
		c.rank = Ranks.start_rank(c.id, c.name, development.get(c.id, 0))
		c.start_rank = c.rank
	# A realm the scenario gives no state religion keeps its capital's faith.
	for c: Country in world.countries.values():
		if c.religion == "" and world.get_province(c.capital_province_id) != null:
			c.religion = world.get_province(c.capital_province_id).religion
			c.start_religion = c.religion
		if c.culture == "" and world.get_province(c.capital_province_id) != null:
			c.culture = world.get_province(c.capital_province_id).culture
			c.start_culture = c.culture


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("cannot read %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		errors.append("%s: top level must be an object" % path)
		return {}
	return json.data
