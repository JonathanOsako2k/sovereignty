extends "res://tests/test_case.gd"

const TOTAL_PROVINCES := 5000
## Who held these places on 1 January 1590.
const HISTORICAL_OWNERS := [
	["London", 51.51, -0.13, "ENG"], ["Edinburgh", 55.95, -3.19, "SCO"], ["Paris", 48.86, 2.35, "FRA"],
	["Madrid", 40.42, -3.70, "SPA"], ["Lisbon", 38.72, -9.14, "POR"], ["Amsterdam", 52.37, 4.90, "NED"],
	["Brussels", 50.85, 4.35, "SPA"], ["Vienna", 48.21, 16.37, "AUS"], ["Prague", 50.08, 14.44, "AUS"],
	["Venice", 45.44, 12.33, "VEN"], ["Rome", 41.90, 12.50, "PAP"], ["Naples", 40.85, 14.27, "SPA"],
	["Copenhagen", 55.68, 12.57, "DEN"], ["Stockholm", 59.33, 18.07, "SWE"], ["Kraków", 50.06, 19.94, "PLC"],
	["Moscow", 55.75, 37.62, "RUS"], ["Constantinople", 41.01, 28.98, "TUR"], ["Buda", 47.50, 19.04, "TUR"],
	["Cairo", 30.04, 31.24, "TUR"], ["Tabriz", 38.08, 46.29, "TUR"], ["Qazvin", 36.27, 50.00, "SAF"],
	["Bukhara", 39.77, 64.42, "BUK"], ["Lahore", 31.55, 74.34, "MUG"], ["Agra", 27.18, 78.01, "MUG"],
	["Goa", 15.50, 73.91, "POR"], ["Beijing", 39.90, 116.40, "MNG"], ["Seoul", 37.57, 126.98, "JOS"],
	["Kyoto", 35.01, 135.77, "JAP"], ["Gao", 16.27, -0.04, "SON"], ["Marrakesh", 31.63, -8.00, "SAD"],
	["Mexico City", 19.43, -99.13, "SPA"], ["Lima", -12.05, -77.04, "SPA"], ["Salvador", -12.97, -38.50, "POR"],
	["Manila", 14.60, 120.98, "SPA"],
	["Sydney", -33.87, 151.21, ""], ["Chicago", 41.88, -87.63, ""], ["Yakutsk", 62.03, 129.73, ""],
	# Settled lands that once fell into gaps between claims:
	["tip of Shandong (Weihai)", 37.51, 122.12, "MNG"], ["Wuhan", 30.59, 114.30, "MNG"],
	["Crimea (Aqmescit)", 44.95, 34.10, "CRI"], ["Ratanpur", 22.28, 82.17, "RTN"], ["Olonets", 61.00, 32.97, "RUS"],
	["Shantou", 23.35, 116.68, "MNG"], ["Macau", 22.19, 113.54, "POR"],
]
## Towns probed on the map itself (the province drawn under the town), for
## borders where nearest-centre lookups are too coarse.
const TOWN_OWNERS := [
	# France against Franche-Comté and the Spanish Netherlands:
	["Dijon", 47.32, 5.04, "FRA"], ["Chaumont", 48.11, 5.14, "FRA"], ["Troyes", 48.30, 4.08, "FRA"],
	["Saint-Quentin", 49.85, 3.29, "FRA"], ["Laon", 49.56, 3.62, "FRA"], ["Amiens", 49.89, 2.30, "FRA"],
	["Besançon", 47.24, 6.02, "SPA"], ["Vesoul", 47.62, 6.15, "SPA"], ["Lons-le-Saunier", 46.67, 5.55, "SPA"],
	["Arras", 50.29, 2.78, "SPA"], ["Lille", 50.63, 3.06, "SPA"],
	["Abondance", 46.28, 6.72, "SAV"], ["Bonneville", 46.08, 6.40, "SAV"], ["Annecy", 45.90, 6.13, "SAV"],
	["Chambéry", 45.57, 5.92, "SAV"], ["Bourg-en-Bresse", 46.21, 5.23, "SAV"],
	["Grenoble", 45.19, 5.72, "FRA"], ["Vienne", 45.52, 4.87, "FRA"], ["Gap", 44.56, 6.08, "FRA"],
	["Lyon", 45.76, 4.84, "FRA"], ["Nancy", 48.69, 6.18, "LOR"], ["Luxembourg", 49.61, 6.13, "SPA"],
	["Colmar", 48.08, 7.36, "AUS"], ["Belfort", 47.64, 6.86, "AUS"], ["Saint-Dié", 48.28, 6.95, "LOR"],
	["Épinal", 48.17, 6.45, "LOR"],
	# Scandinavia: Norway's north, Jämtland, Bohuslän and Gotland were
	# Danish-Norwegian; Lapland, Norrbotten, Småland and Finland Swedish.
	["Mo i Rana", 66.31, 14.14, "DEN"], ["Mosjøen", 65.84, 13.19, "DEN"], ["Fauske", 67.26, 15.39, "DEN"],
	["Bardufoss", 69.06, 18.52, "DEN"], ["Alta", 69.97, 23.27, "DEN"], ["Östersund", 63.18, 14.64, "DEN"],
	["Uddevalla", 58.35, 11.94, "DEN"], ["Visby", 57.64, 18.30, "DEN"], ["Halmstad", 56.67, 12.86, "DEN"],
	["Kiruna", 67.86, 20.23, "SWE"], ["Gällivare", 67.13, 20.66, "SWE"], ["Tornio", 65.85, 24.15, "SWE"],
	["Växjö", 56.88, 14.81, "SWE"], ["Vimmerby", 57.67, 15.86, "SWE"], ["Gothenburg", 57.71, 11.97, "SWE"],
	["Alingsås", 57.93, 12.53, "SWE"], ["Munkedal", 58.47, 11.68, "DEN"],
	# Japan in January 1590: Toyotomi centre and west, vassal daimyō, and the
	# Kantō and Tōhoku not yet his.
	["Kyoto", 35.01, 135.77, "JAP"], ["Osaka", 34.69, 135.50, "JAP"], ["Nagoya", 35.18, 136.91, "JAP"],
	["Kanazawa", 36.56, 136.66, "JAP"], ["Kumamoto", 32.80, 130.71, "JAP"],
	["Sunpu", 34.98, 138.38, "TKG"], ["Kōfu", 35.66, 138.57, "TKG"], ["Iida", 35.51, 137.82, "TKG"], ["Yoshida-Kōriyama", 34.67, 132.71, "MRI"],
	["Kasugayama", 37.15, 138.24, "UES"], ["Kagoshima", 31.60, 130.56, "SMZ"], ["Kōchi", 33.56, 133.53, "CHO"],
	["Kawagoe", 35.92, 139.49, "HOJ"], ["Maebashi", 36.39, 139.06, "HOJ"], ["Hitachiōta", 36.54, 140.53, "STK"],
	["Aizu", 37.49, 139.93, "DTE"], ["Yamagata", 38.25, 140.33, "MGM"], ["Morioka", 39.70, 141.15, "NNB"],
	["Akita", 39.72, 140.10, "AKT"], ["Hirosaki", 40.60, 140.46, "TSG"],
	["Okayama", 34.67, 133.93, "UKT"], ["Ueda", 36.40, 138.25, "SAN"], ["Ichinoseki", 38.93, 141.13, "KSI"],
	["Utsunomiya", 36.56, 139.88, "HOJ"], ["Okazaki", 34.95, 137.17, "TKG"], ["Nagano", 36.65, 138.18, "UES"],
	["Sakura", 35.72, 140.22, "HOJ"], ["Tateyama", 34.99, 139.87, "SMI"], ["Iwaki", 37.05, 140.89, "IWK"],
]


func _load() -> WorldState:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	return world


func _id_image(world: WorldState) -> Image:
	return MapView._load_image(world.id_texture_path)


func test_world_data_loads_without_errors() -> void:
	var world := _load()
	check(world != null, "world should load")
	if world == null:
		return
	check_eq(world.ownable_provinces().size(), TOTAL_PROVINCES, "ownable province count")
	check(world.countries.has(world.player_country_id), "player country exists")


func test_regions_meet_their_quotas() -> void:
	var world := _load()
	var counts := {}
	for p: Province in world.ownable_provinces():
		counts[p.region] = counts.get(p.region, 0) + 1
	var total := 0
	for region: String in world.regions:
		var quota := int(world.regions[region].quota)
		total += quota
		check_eq(counts.get(region, 0), quota, "provinces in %s" % region)
	check_eq(total, TOTAL_PROVINCES, "quotas add up")
	check_eq(world.regions.size(), 10, "region count")


func test_historical_owners_in_1590() -> void:
	var world := _load()
	for row: Array in HISTORICAL_OWNERS:
		var p := world.province_near(row[1], row[2])
		# Overseas, the owner holds it through its colonial nation (Mexico: New Spain).
		var holder := world.diplomacy.overlord_of(p.owner_id) if world.diplomacy.subject_type(p.owner_id) == "colony" 			else p.owner_id
		check_eq(holder, row[3], "%s (province %d %s) owner" % [row[0], p.id, p.name])


func test_town_owners_in_1590() -> void:
	var world := _load()
	var image := _id_image(world)
	for row: Array in TOWN_OWNERS:
		var pos := world.latlon_to_map(row[1], row[2])
		var p := world.get_province(MapView.decode_id(image.get_pixelv(Vector2i(pos))))
		check(p != null, "%s is on land" % row[0])
		if p:
			check_eq(p.owner_id, row[3], "%s (province %d %s) owner" % [row[0], p.id, p.name])


func test_uncolonised_land_exists_and_owners_resolve() -> void:
	var world := _load()
	var uncolonised := 0
	for p: Province in world.ownable_provinces():
		if p.owner_id == "":
			uncolonised += 1
		else:
			check(world.countries.has(p.owner_id), "province %d owner %s" % [p.id, p.owner_id])
	check(uncolonised > 500, "expected wide uncolonised lands, got %d" % uncolonised)


func test_every_country_holds_its_capital() -> void:
	var world := _load()
	for c: Country in world.countries.values():
		var cap := world.get_province(c.capital_province_id)
		check(cap != null and cap.owner_id == c.id, "%s holds its capital" % c.id)


func test_every_province_is_reachable() -> void:
	# Every province must be reachable over land from a coastal province (and
	# so from anywhere by land or sea): none may be walled in by wasteland.
	var world := _load()
	var reached := {}
	var queue: Array[int] = []
	for p: Province in world.ownable_provinces():
		if p.is_coastal:
			reached[p.id] = true
			queue.append(p.id)
	while not queue.is_empty():
		for n in world.get_province(queue.pop_back()).neighbour_ids:
			if not reached.has(n):
				reached[n] = true
				queue.append(n)
	for p: Province in world.ownable_provinces():
		check(reached.has(p.id), "province %d %s is cut off" % [p.id, p.name])


func test_every_province_has_neighbours_or_coast() -> void:
	var world := _load()
	for p: Province in world.ownable_provinces():
		check(p.neighbour_ids.size() > 0 or p.is_coastal, "province %d is isolated and landlocked" % p.id)


func test_label_points_are_inside_their_province() -> void:
	var world := _load()
	var image := _id_image(world)
	for p: Province in world.provinces.values():
		var id := MapView.decode_id(image.get_pixelv(Vector2i(p.label_position)))
		check_eq(id, p.id, "label point of province %d" % p.id)


func test_id_texture_matches_province_list() -> void:
	var world := _load()
	var image := _id_image(world)
	check_eq(image.get_size(), world.map_size, "texture size")
	var seen := {}
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			seen[MapView.decode_id(image.get_pixel(x, y))] = true
	for id in seen:
		check(id == 0 or world.provinces.has(id), "texture contains unknown id %d" % id)


func test_map_wraps_east_west() -> void:
	var world := _load()
	var image := _id_image(world)
	var w := image.get_width()
	# Land crosses the seam (Chukotka): the provinces on either side must be the
	# same or neighbours, because province growth and adjacency wrap.
	var crossings := 0
	for y in image.get_height():
		var east := world.get_province(MapView.decode_id(image.get_pixel(w - 1, y)))
		var west := world.get_province(MapView.decode_id(image.get_pixel(0, y)))
		if east == null or west == null or east.is_wasteland or west.is_wasteland:
			continue
		crossings += 1
		var linked := east == west or world.are_neighbours(east.id, west.id) \
			or (east.is_sea and west.id in east.coast_ids) or (west.is_sea and east.id in west.coast_ids)
		check(linked, "seam at y=%d splits %d / %d" % [y, east.id, west.id])
	check(crossings > 0, "expected land across the seam")
	# Picking wraps: one map width to the left is the same place.
	var view := MapView.new()
	view._id_image = image
	var p := world.province_near(51.51, -0.13)
	check_eq(view.province_at(p.label_position - Vector2(w, 0)), p.id, "wrapped pick")
	view.free()


func test_wastelands_are_impassable_and_unownable() -> void:
	var world := _load()
	var wastes := world.provinces.values().filter(func(p): return p.is_wasteland)
	check(wastes.size() >= 20, "expected many wastelands, got %d" % wastes.size())
	var names := wastes.map(func(p): return p.name)
	for expected in ["Sahara", "Rub' al Khali", "Changtang", "Himalayas", "Taklimakan Desert"]:
		check(expected in names, "%s is a wasteland" % expected)
	for p: Province in wastes:
		check(p.owner_id == "" and p.neighbour_ids.is_empty(), "wasteland %s is unowned and impassable" % p.name)
		check(not world.transfer_province(p.id, "ENG"), "cannot annex wasteland %s" % p.name)
	for p: Province in world.ownable_provinces():
		for n in p.neighbour_ids:
			check(not world.get_province(n).is_wasteland, "province %d borders wasteland %d" % [p.id, n])


func test_wasteland_geography() -> void:
	var world := _load()
	var view := MapView.new()
	view._id_image = _id_image(world)
	var at := func(lat: float, lon: float) -> Province:
		return world.get_province(view.province_at(world.latlon_to_map(lat, lon)))
	for spot: Array in [["central Sahara", 23.0, 8.0], ["Rub' al Khali", 20.0, 50.0], ["Everest", 27.99, 86.93],
			["Changtang", 34.5, 86.0], ["Greenland ice", 70.0, -40.0]]:
		var p: Province = at.call(spot[1], spot[2])
		check(p != null and p.is_wasteland, "%s should be wasteland, got %s" % [spot[0], p.name if p else "sea"])
	for spot: Array in [["Nile at Luxor", 25.70, 32.64, "TUR"], ["Fezzan oasis", 25.92, 13.92, "FEZ"],
			["Timbuktu", 16.77, -3.00, "SON"], ["Lhasa", 29.65, 91.10, "TIB"], ["Kashgar", 39.47, 75.99, "YRK"]]:
		var p: Province = at.call(spot[1], spot[2])
		check(p != null and not p.is_wasteland and p.owner_id == spot[3],
			"%s should be ownable land of %s, got %s" % [spot[0], spot[3], [p.name, p.owner_id] if p else "sea"])
	view.free()


## True if `to` can be reached from `from` through provinces whose position
## lies inside the lat/lon box [south, west, north, east].
func _reachable_within(world: WorldState, from: Province, to: Province, box: Array) -> bool:
	var seen := {from.id: true}
	var queue: Array[int] = [from.id]
	while not queue.is_empty():
		var p := world.get_province(queue.pop_back())
		if p.id == to.id:
			return true
		for n in p.neighbour_ids:
			var q := world.get_province(n)
			if not seen.has(n) and q.lat >= box[0] and q.lon >= box[1] and q.lat <= box[2] and q.lon <= box[3]:
				seen[n] = true
				queue.append(n)
	return false


func test_nile_and_sahara_can_be_crossed() -> void:
	var world := _load()
	var cairo := world.province_near(30.04, 31.24)
	var khartoum := world.province_near(15.60, 32.53)
	check(_reachable_within(world, cairo, khartoum, [12.0, 28.0, 32.0, 36.0]), "follow the Nile from Cairo to Sudan")
	var tripoli := world.province_near(32.90, 13.18)
	var bornu := world.province_near(13.00, 13.30)
	check(_reachable_within(world, tripoli, bornu, [11.0, 8.0, 34.0, 19.0]), "cross the Sahara by the Fezzan road")
	var sijilmasa := world.province_near(31.28, -4.27)
	var timbuktu := world.province_near(16.77, -3.00)
	check(_reachable_within(world, sijilmasa, timbuktu, [15.0, -9.0, 35.0, 1.0]), "cross the Sahara to Timbuktu")
	var asyut := world.province_near(27.18, 31.18)
	var darfur := world.province_near(13.63, 25.35)
	check(_reachable_within(world, asyut, darfur, [12.0, 23.0, 28.5, 33.0]), "the Forty Days Road to Darfur")


func test_biskra_reaches_arak() -> void:
	# The Oued Righ and central Saharan roads link Biskra to the Arak oasis.
	var world := _load()
	var biskra := world.province_near(34.85, 5.73)
	var arak := world.province_near(25.30, 3.75)
	check(_reachable_within(world, biskra, arak, [21.0, 0.0, 36.0, 8.5]), "Biskra to Arak (%s -> %s)" % [biskra.name, arak.name])


func test_egypt_has_a_populous_nile() -> void:
	var world := _load()
	var egypt := 0
	var delta := 0
	for p: Province in world.ownable_provinces():
		if p.lon > 24.5 and p.lon < 35.0 and p.lat > 22.0 and p.lat < 31.7:
			egypt += 1
			if p.lat > 29.9 and p.lon > 29.5 and p.lon < 32.4:
				delta += 1
	check(egypt >= 15, "Egypt should have at least 15 provinces, has %d" % egypt)
	check(delta >= 6, "the Nile delta should have at least 6 provinces, has %d" % delta)


func test_provinces_follow_real_divisions() -> void:
	var world := _load()
	var with_division := 0
	for p: Province in world.ownable_provinces():
		if p.division != "":
			with_division += 1
	check_eq(with_division, TOTAL_PROVINCES, "every province records its real division")
	check_eq(world.province_near(48.86, 2.35).name, "Paris")
	check_eq(world.province_near(41.01, 28.98).name, "Constantinople")


func test_sea_tiles() -> void:
	var world := _load()
	var seas := world.sea_tiles()
	check(seas.size() >= 400 and seas.size() <= 1500, "sea tile count %d" % seas.size())
	var names := {}
	for s: Province in seas:
		names[s.name] = true
		check(s.owner_id == "", "sea %s is unowned" % s.name)
		for n in s.neighbour_ids:
			check(world.get_province(n).is_sea, "sea %d neighbours only seas" % s.id)
	for expected in ["North Sea", "Baltic Sea", "Bay of Biscay", "English Channel", "Caspian Sea", "Lake Superior"]:
		check(names.has(expected), "a sea tile is named %s" % expected)
	check(not world.transfer_province(seas[0].id, "ENG"), "cannot annex the sea")


func _nearest_sea(world: WorldState, lat: float, lon: float) -> Province:
	var best: Province = null
	var best_d := INF
	for s: Province in world.sea_tiles():
		var dlon := absf(s.lon - lon)
		dlon = minf(dlon, 360.0 - dlon) * cos(deg_to_rad(lat))
		var d := (s.lat - lat) * (s.lat - lat) + dlon * dlon
		if d < best_d:
			best_d = d
			best = s
	return best


func test_polar_sea_routes_are_sailable() -> void:
	# Round Cape Horn from the South Atlantic into the Pacific, and round the
	# North Cape from the Norwegian Sea into the White Sea, by sea tiles only.
	var world := _load()
	var atlantic := _nearest_sea(world, -45.0, -55.0)
	var pacific := _nearest_sea(world, -45.0, -80.0)
	check(_reachable_within(world, atlantic, pacific, [-70.0, -90.0, -40.0, -50.0]), "sail round Cape Horn")
	var view := MapView.new()
	view._id_image = _id_image(world)
	var drake := world.get_province(view.province_at(world.latlon_to_map(-59.0, -65.0)))
	check(drake != null and drake.is_sea, "the Drake Passage is open sea on the map")
	var norwegian := _nearest_sea(world, 68.0, 8.0)
	var white := _nearest_sea(world, 65.5, 38.0)
	check(_reachable_within(world, norwegian, white, [64.0, 0.0, 80.0, 50.0]), "sail round the North Cape")
	var barents := world.get_province(view.province_at(world.latlon_to_map(74.0, 35.0)))
	check(barents != null and barents.is_sea, "the Barents Sea is open sea on the map")
	view.free()


func test_coasts_match_sea_tiles() -> void:
	var world := _load()
	for p: Province in world.ownable_provinces():
		check(p.is_coastal == not p.sea_ids.is_empty(), "province %d coastal flag matches its sea tiles" % p.id)
		for n in p.neighbour_ids:
			check(not world.get_province(n).is_sea, "province %d lists sea %d as a land neighbour" % [p.id, n])
	check(world.province_near(38.72, -9.14).is_coastal, "Lisbon is on the sea")
	check(world.province_near(41.01, 28.98).is_coastal, "Constantinople is on the sea")
	check(not world.province_near(40.42, -3.70).is_coastal, "Madrid is inland")


func test_id_codec_round_trip() -> void:
	for id in [0, 1, 255, 256, 1234, 4999, 65535]:
		check_eq(MapView.decode_id(MapView.encode_id(id)), id, "id %d" % id)


func test_transfer_updates_owner_controller_and_derived_lists() -> void:
	var world := _load()
	var p := world.province_near(48.86, 2.35)
	var old_owner := p.owner_id
	var events := []
	world.province_owner_changed.connect(func(id, a, b): events.append([id, a, b]))
	check(world.transfer_province(p.id, "ENG"), "transfer succeeds")
	check_eq(p.owner_id, "ENG")
	check_eq(p.controller_id, "ENG", "control follows ownership by default")
	check(p.id in world.owned_province_ids("ENG"), "new owner lists the province")
	check(not (p.id in world.owned_province_ids(old_owner)), "old owner no longer lists it")
	check_eq(events, [[p.id, old_owner, "ENG"]])
	check(world.validate().is_empty(), "world stays valid: %s" % [world.validate()])


func test_transfer_can_keep_occupier_in_control() -> void:
	var world := _load()
	var p := world.province_near(50.85, 4.35)
	world.set_controller(p.id, "NED")
	check(p.is_occupied(), "occupied after set_controller")
	world.transfer_province(p.id, "NED", true)
	check(not p.is_occupied(), "ceded to its occupier")


func test_colonising_uncolonised_land() -> void:
	var world := _load()
	var p := world.province_near(37.0, -76.5)  # Chesapeake
	check_eq(p.owner_id, "", "Virginia is uncolonised in 1590")
	check(world.transfer_province(p.id, "ENG"), "colonise")
	check_eq(p.owner_id, "ENG")


func test_transfer_rejects_unknown_ids() -> void:
	var world := _load()
	check(not world.transfer_province(999999, "ENG"), "unknown province")
	check(not world.transfer_province(world.province_near(51.51, -0.13).id, "NOPE"), "unknown country")


func test_losing_capital_clears_it() -> void:
	var world := _load()
	var c: Country = world.get_country("FRA")
	world.transfer_province(c.capital_province_id, "SPA")
	check_eq(c.capital_province_id, 0)
	check(world.validate().is_empty(), "still valid")


func test_validation_reports_broken_adjacency() -> void:
	var world := _load()
	var p: Province = world.provinces.values()[0]
	p.neighbour_ids.append(424242)
	var errors := world.validate()
	check(errors.size() > 0 and "424242" in errors[0], "unknown neighbour is reported: %s" % [errors])
