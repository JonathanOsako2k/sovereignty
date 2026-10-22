extends "res://tests/test_case.gd"
## Faith and the 1590 scenario: every province's religion and every realm's
## state religion as they stood; the fortresses of 1590; unrest in land of
## another faith; missionaries (sending, cost and upkeep, slots, conversion,
## recall, an end when the land is lost); the AI's missionaries, ideas and
## barracks; the religion and buildings map modes; saving and older saves.


func _setup() -> Array:  # [campaign, economy, religion system, military system]
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	var c := Campaign.new(world)
	var economy := EconomySystem.new(c)
	var mil := MilitarySystem.new(c, economy, DiplomacyActions.new(c))
	return [c, economy, ReligionSystem.new(c, economy), mil]


func _faith_at(w: WorldState, lat: float, lon: float) -> String:
	return w.province_near(lat, lon).religion


func test_the_faiths_of_1590() -> void:
	var w: WorldState = _setup()[0].world
	for p: Province in w.ownable_provinces():
		if not Religions.has(p.religion):
			failures.append("%s has no known faith (%s)" % [p.name, p.religion])
			break
	for c: Country in w.countries.values():
		if not Religions.has(c.religion):
			failures.append("%s has no state religion" % c.name)
			break
	var states := {"ENG": "anglican", "SCO": "reformed", "NED": "reformed", "FRA": "catholic", "SPA": "catholic",
		"SAX": "protestant", "SWE": "protestant", "RUS": "orthodox", "TUR": "sunni", "SAF": "shia", "MUG": "sunni",
		"VIJ": "hindu", "MNG": "confucian", "JAP": "shinto", "ABY": "oriental", "OMA": "ibadi", "KON": "catholic"}
	for tag: String in states:
		check_eq(w.get_country(tag).religion, states[tag], "%s's state religion" % tag)
	var places := [
		["London", 51.51, -0.13, "anglican"], ["Edinburgh", 55.95, -3.19, "reformed"],
		["Paris", 48.86, 2.35, "catholic"], ["La Rochelle", 46.16, -1.15, "reformed"],
		["Amsterdam", 52.37, 4.90, "reformed"], ["Antwerp", 51.22, 4.40, "catholic"],
		["Dresden", 51.05, 13.74, "protestant"], ["Munich", 48.14, 11.58, "catholic"],
		["Cologne", 50.94, 6.96, "catholic"], ["Prague", 50.09, 14.42, "protestant"],
		["Kraków", 50.06, 19.94, "catholic"], ["Kyiv", 50.45, 30.52, "orthodox"],
		["Moscow", 55.75, 37.62, "orthodox"], ["Kazan", 55.80, 49.11, "sunni"],
		["Athens", 37.98, 23.73, "orthodox"], ["Sarajevo", 43.86, 18.41, "sunni"],
		["Istanbul", 41.01, 28.98, "sunni"], ["Isfahan", 32.65, 51.67, "shia"],
		["Najaf", 32.0, 44.33, "shia"], ["Agra", 27.18, 78.01, "hindu"], ["Lahore", 31.59, 74.31, "sunni"],
		["Goa", 15.50, 73.83, "catholic"], ["Lhasa", 29.65, 91.10, "vajrayana"],
		["Beijing", 39.90, 116.40, "confucian"], ["Kyoto", 35.01, 135.77, "shinto"],
		["Ayutthaya", 14.35, 100.57, "theravada"], ["Manila", 14.59, 120.97, "catholic"],
		["Mexico City", 19.43, -99.13, "catholic"], ["Cairo", 30.04, 31.24, "sunni"],
		["Gondar", 12.6, 37.47, "oriental"], ["Kano", 12.0, 8.52, "sunni"],
	]
	for row: Array in places:
		check_eq(_faith_at(w, row[1], row[2]), row[3], row[0])
	# England rules Catholic Ireland: its people are not of the state's faith.
	check_eq(_faith_at(w, 53.35, -6.26), "catholic", "Dublin")
	# Beyond the realms of 1590: the Pacific shore, Chukotka across the date
	# line, the Wild Jurchens; Tatar land under the sultan and the tsar.
	for row: Array in [["Provideniya", 64.42, -173.23, "animist"], ["Primorye", 43.59, 132.55, "animist"],
			["Dalnegorsk", 44.55, 135.57, "animist"], ["Qiqihar", 47.35, 123.92, "animist"],
			["Hacıbey", 46.48, 30.73, "sunni"], ["Tobolsk", 58.2, 68.25, "sunni"],
			["Zhangye (Ming)", 38.93, 100.45, "confucian"], ["the Mekong delta", 10.03, 105.78, "theravada"]]:
		check_eq(_faith_at(w, row[1], row[2]), row[3], row[0])
	check_eq(w.get_country("POM").religion, "protestant", "Lutheran Pomerania")


func test_the_fortresses_of_1590() -> void:
	var w: WorldState = _setup()[0].world
	var image := MapView._load_image(w.id_texture_path)  # the province under the town itself
	for row: Array in [["Antwerp", 51.22, 4.40], ["Calais", 50.95, 1.86], ["Győr", 47.69, 17.63],
			["Belgrade", 44.82, 20.46], ["Valletta", 35.90, 14.51], ["Smolensk", 54.78, 32.05],
			["Malacca", 2.19, 102.25], ["Havana", 23.14, -82.36], ["Osaka", 34.69, 135.53]]:
		var p := w.get_province(MapView.decode_id(image.get_pixelv(Vector2i(w.latlon_to_map(row[1], row[2])))))
		# (a harbour town's point may fall in the water: then the land province nearest)
		var land := p if p != null and not p.is_sea else w.province_near(row[1], row[2])
		check("fort" in land.buildings, "%s is fortified" % row[0])
	var forts := 0
	for p: Province in w.ownable_provinces():
		if "fort" in p.buildings:
			forts += 1
	check(forts > 200, "many fortresses (%d)" % forts)


func test_another_faith_breeds_unrest() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var w := c.world
	var paris := w.province_near(48.86, 2.35)
	var rochelle := w.province_near(46.16, -1.15)
	check(Religions.unrest("reformed", "catholic") > 0.0, "heresy is restless")
	check(Religions.unrest("sunni", "catholic") > Religions.unrest("reformed", "catholic"), "heathens more so")
	paris.unrest = 0.0
	rochelle.unrest = 0.0
	for i in 12:
		economy.monthly()
	check(rochelle.unrest > paris.unrest + 2.0, "Huguenot La Rochelle is restless (%.1f vs %.1f)" % [rochelle.unrest, paris.unrest])


func test_missionaries_convert_our_land() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var faith: ReligionSystem = s[2]
	var w := c.world
	var france := w.get_country("FRA")
	france.treasury = 5000.0
	var rochelle := w.province_near(46.16, -1.15)
	var paris := w.province_near(47.39, 0.69)  # Tours
	check_eq(faith.blocked("FRA", paris), "Already of our faith", "not where they share our faith")
	check(faith.blocked("FRA", w.province_near(51.51, -0.13)).begins_with("Only"), "only our own land")
	check_eq(faith.blocked("FRA", rochelle), "", "La Rochelle may be sent one")
	var cost := faith.send_cost("FRA", rochelle)
	check(faith.send("FRA", rochelle), "sent")
	check(is_equal_approx(france.treasury, 5000.0 - cost), "paid for")
	var upkeep := 0.0
	for line: Array in economy.budget("FRA").expenses:
		if line[0] == EconomySystem.MISSIONS:
			upkeep = line[1]
	check(upkeep > 0.0, "the budget pays its upkeep")
	var other: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id == "FRA" and p.religion != "catholic" and p != rochelle:
			other = p
			break
	if other != null:
		check(faith.blocked("FRA", other).begins_with("All our missionaries"), "one missionary in 1590")
	# Slower in richer land, across families; quicker among animists.
	var months := faith.months_to_convert("FRA", rochelle)
	var was := rochelle.religion
	rochelle.religion = "sunni"
	check(faith.months_to_convert("FRA", rochelle) > months, "other families take longer")
	rochelle.religion = "animist"
	check(faith.months_to_convert("FRA", rochelle) < months, "animists convert sooner")
	rochelle.religion = was
	var converted := []
	faith.converted.connect(func(id: int, r: String): converted.append([id, r]))
	for i in months:
		faith.monthly()
	check_eq(rochelle.religion, "catholic", "converted after %d months" % months)
	check(not w.missions.has(rochelle.id) and converted.size() == 1, "the mission ends, announced")
	# A recall, and a mission ended by losing the land.
	if other != null:
		check(faith.send("FRA", other), "another sent")
		check(faith.recall("FRA", other) and not w.missions.has(other.id), "and called back")
		check(faith.send("FRA", other), "sent again")
		w.transfer_province(other.id, "SPA")
		faith.monthly()
		check(not w.missions.has(other.id), "land lost, the mission ends")


func test_the_ai_sends_missionaries_takes_up_ideas_and_builds_barracks() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var faith: ReligionSystem = s[2]
	var mil: MilitarySystem = s[3]
	var w := c.world
	for tag: String in w.countries:
		w.get_country(tag).treasury = 100000.0
	faith.ai_monthly("ENG")
	check(w.missions.size() > 10, "AI realms send missionaries (%d)" % w.missions.size())
	check(w.missions.values().all(func(m: Array) -> bool: return m[0] != "ENG"), "never the player's")
	mil.ai_yearly_ideas("ENG")
	check(Ideas.has(w.get_country("FRA"), "press_gangs"), "seafaring France takes up press gangs")
	check(Ideas.has(w.get_country("SAX"), "drill_grounds"), "landlocked Saxony drill grounds")
	check_eq(w.get_country("ENG").ideas, ["press_gangs"], "the player chooses for itself")
	economy.ai_construction("ENG")
	var building := 0
	for p: Province in w.ownable_provinces():
		if p.owner_id == "TUR" and not p.construction.is_empty() and p.construction[0] == "barracks":
			building += 1
	check_eq(building, 1, "the Ottomans build more barracks for their size")


func test_map_modes_for_faith_and_buildings() -> void:
	var w: WorldState = _setup()[0].world
	var paris := w.province_near(48.86, 2.35)
	check_eq(MapModes.province_color(w, paris, MapModes.Mode.RELIGION, 1.0), Religions.color_of("catholic"),
		"the religion map colours by faith")
	check_eq(MapModes.info_text(paris, MapModes.Mode.RELIGION), "Catholic", "and names it")
	check(MapModes.info_text(paris, MapModes.Mode.BUILDINGS).contains("Fort"), "the buildings map lists them")
	var bare: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id != "" and p.buildings.is_empty() and p.construction.is_empty():
			bare = p
			break
	check(MapModes.province_color(w, bare, MapModes.Mode.BUILDINGS, 1.0) != MapModes.province_color(w, paris,
		MapModes.Mode.BUILDINGS, 1.0), "a bare province looks different from a built-up one")
	check(MapModes.Mode.BUILDINGS in MapModes.GROUPS[1][1] and MapModes.Mode.RELIGION in MapModes.GROUPS[3][1],
		"in the Economy and People groups")


func test_faith_is_saved() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var faith: ReligionSystem = s[2]
	var w := c.world
	w.get_country("FRA").treasury = 5000.0
	var rochelle := w.province_near(46.16, -1.15)
	faith.send("FRA", rochelle)
	w.province_near(48.86, 2.35).religion = "reformed"
	w.get_country("SCO").religion = "catholic"
	var copy: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict(), "", false, true))
	var b: Campaign = _setup()[0]
	check(b.restore(copy).is_empty(), "restore")
	check_eq(b.world.province_near(48.86, 2.35).religion, "reformed", "a province's faith")
	check_eq(b.world.get_country("SCO").religion, "catholic", "a state religion")
	check(b.world.missions.has(rochelle.id), "a mission under way")
	# A save from before faith (format 8): the faiths of the start.
	var old: Dictionary = copy.duplicate(true)
	for row: Array in old.world.provinces:
		row.resize(13)
	for tag: String in old.world.countries:
		old.world.countries[tag].erase("religion")
	old.world.erase("missions")
	SaveService._upgrade_8_to_9({"campaign": old})
	check(b.restore(old).is_empty(), "format 8 restores")
	check_eq(b.world.province_near(48.86, 2.35).religion, "catholic", "with the start's faiths")
	check_eq(b.world.get_country("SCO").religion, "reformed", "and state religions")
	# A new campaign starts from the scenario without checks, and is sound.
	check(c.start_new("FRA").is_empty(), "a new campaign")
	check(c.check(c.to_dict()).is_empty(), "its state checks clean")
	check_eq(c.world.province_near(48.86, 2.35).religion, "catholic", "faiths back as at the start")
