extends "res://tests/test_case.gd"
## The world as it stood on 1 January 1590: Henry IV against the Catholic
## League (a civil war, with Spanish volunteers and Spanish money for the
## League), the Dutch against Spain, the Jurchens' rivalry and the forming of
## Manchuria; peoples and their map; volunteers and subsidies as anyone may
## use them; the Zuiderzee open water.


func _setup() -> Array:  # [campaign, economy, military system, nation system]
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	var c := Campaign.new(world)
	var economy := EconomySystem.new(c)
	var mil := MilitarySystem.new(c, economy, DiplomacyActions.new(c))
	return [c, economy, mil, NationSystem.new(c, economy)]


func _days(mil: MilitarySystem, n: int) -> void:
	for i in n:
		mil.clock.step_day()
		mil.daily()


func test_the_wars_of_1590() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var w := c.world
	var m := w.military
	var paris := w.province_near(48.86, 2.35)
	var tours := w.province_near(47.39, 0.69)
	check_eq(paris.owner_id, "LEA", "the League holds Paris")
	check_eq(w.get_country("LEA").capital_province_id, paris.id, "its capital")
	check_eq(w.get_country("FRA").capital_province_id, tours.id, "the king's government sits at Tours")
	check(w.claims.is_core("FRA", paris.id) and w.claims.has_claim("LEA", tours.id), "each claims the other's France")
	var civil := m.war_between("FRA", "LEA")
	check(not civil.is_empty() and civil.get("civil", false), "a civil war between them")
	check(m.at_war("NED", "SPA") and not m.war_between("NED", "SPA").get("civil", false), "the Dutch revolt, no civil war")
	check(not m.at_war("SPA", "FRA"), "Spain is not at war with France")
	var groningen := w.province_near(53.22, 6.57)
	if groningen.owner_id == "SPA":
		check(w.claims.is_core("NED", groningen.id), "the Dutch hold a core on Spanish Groningen")
	check(w.claims.has_claim("NED", w.province_near(51.22, 4.40).id), "and a claim on Antwerp")
	var jia := w.get_country("JIA")
	if jia != null and w.get_country("HAI") != null:
		var hai_land: Province = null
		for p: Province in w.ownable_provinces():
			if p.owner_id == "HAI":
				hai_land = p
				break
		check(hai_land != null and w.claims.has_claim("JIA", hai_land.id), "Jianzhou claims Haixi's land")
	var volunteers := m.armies_of("SPA").filter(func(a: Army) -> bool: return a.volunteer_for == "LEA")
	check(not volunteers.is_empty(), "Spanish volunteers fight for the League")
	check_eq(w.diplomacy.subsidy("SPA", "LEA"), 12, "and Spain pays it")
	var got := false
	for line: Array in economy.budget("LEA").income:
		if line[0] == EconomySystem.SUBSIDIES_IN:
			got = true
	check(got, "the League's budget shows the money")
	check(w.diplomacy.opinion("LEA", "SPA") >= Diplomacy.OPINION_SUBSIDISED, "and it thinks well of Spain")


func test_a_civil_war_annexes_what_it_takes() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var m := w.military
	var target: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id == "LEA" and not "fort" in p.buildings and m.armies_at(p.id).is_empty() \
				and w.get_country("LEA").capital_province_id != p.id:
			target = p
			break
	check(target != null, "an open League province")
	if target == null:
		return
	var army := m.add_army("FRA", target.id, [["pike_and_shot", 1000, 0], ["pike_and_shot", 1000, 0]], false, "Royal army")
	_days(mil, int(MilitarySystem.OCCUPY_DAYS) + 1)
	check_eq(target.owner_id, "FRA", "taken in a civil war, it is annexed")
	check_eq(target.controller_id, "FRA", "and held")
	m.remove_army(army.id)
	# Not so against a foreign enemy: the Dutch only occupy.
	var spanish: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id == "SPA" and not "fort" in p.buildings and m.armies_at(p.id).is_empty() and p.lat > 50.5 and p.lon < 7.0:
			spanish = p
			break
	if spanish != null:
		m.add_army("NED", spanish.id, [["pike_and_shot", 1000, 0], ["pike_and_shot", 1000, 0]], false, "Dutch army")
		_days(mil, int(MilitarySystem.OCCUPY_DAYS) + 1)
		check(spanish.owner_id == "SPA" and spanish.controller_id == "NED", "the Dutch occupy, Spain still owns")


func test_volunteers_fight_for_their_host() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var m := w.military
	var eng: Army = m.armies_of("ENG")[0]
	check("FRA" in mil.volunteer_hosts("ENG"), "England may send volunteers to the king")
	check(not "SPA" in mil.volunteer_hosts("SPA"), "never to itself")
	check_eq(mil.volunteer_blocked(eng, "FRA"), "", "England's army may go")
	check(mil.send_volunteers(eng, "FRA"), "sent")
	check_eq(eng.side(), "FRA", "it fights France's wars")
	var league := w.get_province(w.get_country("LEA").capital_province_id)
	check(mil.can_enter(eng.side(), league), "into League land")
	check(not m.at_war("ENG", "LEA"), "England stays at peace with the League")
	# What it takes is the king's.
	var target: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id == "LEA" and not "fort" in p.buildings and m.armies_at(p.id).is_empty() \
				and w.get_country("LEA").capital_province_id != p.id:
			target = p
			break
	if target != null:
		eng.location = target.id
		eng.path.clear()
		_days(mil, int(MilitarySystem.OCCUPY_DAYS) + 1)
		check_eq(target.owner_id, "FRA", "taken for the king (and, in his civil war, his)")
	# The war ends: the volunteers come home.
	mil.conclude(m.war_between("FRA", "LEA"), "FRA", {})
	check_eq(eng.volunteer_for, "", "home when the war is over")
	check(mil.can_enter("ENG", w.get_province(eng.location)), "and somewhere they may be")
	# Levies and fleets do not go.
	var fleet: Army = m.armies_of("ENG", true)[0]
	check(mil.volunteer_blocked(fleet, "SPA") != "", "no fleets as volunteers")


func test_subsidies_are_paid_and_saved() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var w := c.world
	var d := w.diplomacy
	var before := d.opinion("SCO", "ENG")
	d.set_subsidy("ENG", "SCO", 10)
	check_eq(d.opinion("SCO", "ENG"), before + Diplomacy.OPINION_SUBSIDISED, "a subsidy is welcome")
	var paid := 0.0
	for line: Array in economy.budget("ENG").expenses:
		if line[0] == EconomySystem.SUBSIDIES_OUT:
			paid = line[1]
	check_eq(paid, 10.0, "and in the budget")
	var copy: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict(), "", false, true))
	var b: Campaign = _setup()[0]
	check(b.restore(copy).is_empty(), "restore")
	check_eq(b.world.diplomacy.subsidy("ENG", "SCO"), 10, "saved")
	w.get_country("ENG").treasury = -50.0
	DiplomacySystem.new(c, DiplomacyActions.new(c)).monthly()
	check_eq(d.subsidy("ENG", "SCO"), 0, "it stops when the money runs out")


func test_the_jurchens_unite_as_manchuria() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var nations: NationSystem = s[3]
	var w := c.world
	if w.get_country("JIA") == null or w.get_country("HAI") == null:
		failures.append("no Jurchen realms")
		return
	check_eq(w.get_country("JIA").culture, "jurchen", "Jianzhou is Jurchen")
	check(nations.formation_blocked("JIA", "manchuria").contains("stands apart"), "not while Haixi stands apart")
	check(nations.formation_blocked("MNG", "manchuria").begins_with("Only"), "nor by the Ming")
	for p: Province in w.ownable_provinces():
		if p.owner_id == "HAI":
			w.transfer_province(p.id, "JIA")
	var held := 0
	for p: Province in w.ownable_provinces():
		if p.owner_id == "JIA" and p.culture == "jurchen":
			held += 1
	if held < Formations.CATALOGUE.manchuria.min_provinces:
		check(nations.formation_blocked("JIA", "manchuria").begins_with("Needs"), "too little land")
		return
	check_eq(nations.formation_blocked("JIA", "manchuria"), "", "united, it may form Manchuria")
	nations.ai_yearly("ENG")
	var jia := w.get_country("JIA")
	check_eq(jia.name, "Manchuria", "the AI forms it")
	check_eq(jia.adjective, "Manchu", "the Manchus")
	check(jia.rank >= Ranks.MINOR_KINGDOM, "crowned a kingdom as it forms")
	# Wild Jurchen land: integrated with an army there and a fee.
	var wild: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id == "" and p.culture == "jurchen":
			wild = p
			break
	check(wild != null, "uncolonised Jurchen land")
	if wild != null:
		jia.treasury = 1000.0
		check(nations.integrate_blocked("JIA", wild, w.military.armies_of("JIA")[0]).contains("army"), "an army must stand there")
		var army := w.military.add_army("JIA", wild.id, [["levy", 1000, 0]], false, "Banner")
		var cost := nations.integrate_cost("JIA", wild)
		check(nations.integrate("JIA", wild, army), "integrated")
		check_eq(wild.owner_id, "JIA", "Manchu land now")
		check(w.claims.is_core("JIA", wild.id), "a core at once")
		check(is_equal_approx(jia.treasury, 1000.0 - cost), "for a small fee")
		check(nations.integrate_blocked("ENG", wild).begins_with("Only a formed nation"), "only a formed nation integrates")
	# The name is saved, and a new campaign brings back Jianzhou.
	var copy: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict(), "", false, true))
	var b: Campaign = _setup()[0]
	check(b.restore(copy).is_empty(), "restore")
	check_eq(b.world.get_country("JIA").name, "Manchuria", "Manchuria after loading")
	c.start_new("ENG")
	check_eq(w.get_country("JIA").name, "Jianzhou Jurchens", "Jianzhou again in a new campaign")
	check_eq(w.get_country("JIA").rank, Ranks.DUCHY, "and a duchy again")


func test_peoples_and_their_map() -> void:
	var w: WorldState = _setup()[0].world
	for row: Array in [["Tours", 47.39, 0.69, "french"], ["Toulouse", 43.60, 1.44, "occitan"],
			["Barcelona", 41.39, 2.17, "catalan"], ["Amsterdam", 52.37, 4.90, "dutch"],
			["Hamburg", 53.55, 9.99, "low_german"], ["Kazan", 55.80, 49.11, "volga_tatar"],
			["Mexico City", 19.43, -99.13, "nahua"], ["Cusco", -13.53, -71.97, "quechua"],
			["Guangzhou", 23.13, 113.26, "cantonese"], ["Kyoto", 35.01, 135.77, "japanese"]]:
		check_eq(w.province_near(row[1], row[2]).culture, row[3], row[0])
	for p: Province in w.ownable_provinces():
		if not Cultures.has(p.culture):
			failures.append("%s has no known culture (%s)" % [p.name, p.culture])
			break
	check_eq(w.get_country("FRA").culture, w.get_country("LEA").culture, "the king and the League are one people")
	for tag: String in w.created:
		check(w.get_country(tag).culture in ["castilian", "portuguese"], "%s: its settlers' people" % w.get_country(tag).name)
	var tours := w.province_near(47.39, 0.69)
	check_eq(MapModes.province_color(w, tours, MapModes.Mode.CULTURE, 1.0), Cultures.color_of("french"), "the culture map")
	check_eq(MapModes.info_text(tours, MapModes.Mode.CULTURE), "French", "names the people")
	check(Cultures.color_of("french") != Cultures.color_of("occitan"), "kin peoples apart on the map")


func test_the_zuiderzee_is_open_water() -> void:
	var w: WorldState = _setup()[0].world
	var image := MapView._load_image(w.id_texture_path)
	for ll: Array in [[52.50, 5.45], [52.75, 5.80], [52.65, 5.25]]:
		var p := w.get_province(MapView.decode_id(image.get_pixelv(Vector2i(w.latlon_to_map(ll[0], ll[1])))))
		check(p != null and p.is_sea, "the Zuiderzee at %s is water (%s)" % [str(ll), p.name if p else "?"])


func test_peace_with_rebels_is_their_demands() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var m := w.military
	var war := m.war_between("FRA", "LEA")
	check_eq(war.get("rebels", ""), "LEA", "the League are the rebels")
	check_eq(mil.civil_parties(war), ["FRA", "LEA"], "the crown and the rebels")
	check(not "faith" in mil.rebel_demands(war), "no demand for a faith they share")
	check(mil.treaty_blocked(war, "FRA", {"with": "LEA", "provinces": [w.province_near(48.86, 2.35).id]}).contains("no land"),
		"no land to demand of rebels")
	# Annexing their land earns war score; they ask less the better we fare.
	var price := mil.rebel_price(war)
	check(price > 0.0, "at first they want something (%.0f)" % price)
	var before := mil.state_score(war)
	var taken := 0
	for p: Province in w.ownable_provinces():
		if p.owner_id == "LEA" and w.get_country("LEA").capital_province_id != p.id and taken < 10:
			war.annexed[Military.side_of(war, "FRA")] += p.development
			w.transfer_province(p.id, "FRA")
			taken += 1
	check(mil.state_score(war) > before, "annexing rebel land raises the crown's score")
	check(mil.rebel_price(war) < price, "and lowers their price")
	# While they hold little of the realm, time is on the crown's side.
	var tick := float(war.get("tick", 0.0))
	if mil.rebel_share(war) < MilitarySystem.REBELS_FEW:
		mil.monthly()
		check(float(war.tick) != tick, "a month ticks the score")
	# Too little granted is refused; the cheapest fair settlement accepted.
	var cheap := mil.cheapest_settlement(war)
	check(mil.treaty_accepted(war, "FRA", {"with": "LEA", "granted": cheap}), "the cheapest fair settlement (%s)" % str(cheap))
	if mil.rebel_price(war) > 0.0:
		check(not mil.treaty_accepted(war, "FRA", {"with": "LEA", "granted": []}), "nothing granted, they fight on")
	var league := w.get_province(w.get_country("LEA").capital_province_id)
	mil.conclude(war, "FRA", {"with": "LEA", "granted": cheap})
	check(not m.at_war("FRA", "LEA"), "peace")
	check_eq(league.owner_id, "FRA", "Paris returns to the crown")
	check(m.armies_of("LEA").is_empty(), "the League's armies disband")


func test_rebels_beaten_submit_and_governorships_keep_them_as_vassals() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var m := w.military
	var war := m.war_between("FRA", "LEA")
	war.battle_score = 40.0 * (1.0 if war.attackers[0] == "FRA" else -1.0)
	check_eq(mil.rebel_price(war), 0.0, "clearly beaten, they ask nothing")
	var paris := w.province_near(48.86, 2.35)
	c.world.set_player_country("ENG")
	mil.ai_monthly_peace("ENG")
	check(not m.at_war("FRA", "LEA"), "the AI rebels submit")
	check_eq(paris.owner_id, "FRA", "their land the crown's")
	# Another start: governorships granted, the League stays, as a vassal.
	var t: Array = _setup()
	var c2: Campaign = t[0]
	var mil2: MilitarySystem = t[2]
	var war2 := c2.world.military.war_between("FRA", "LEA")
	var grant := ["governorships", "amnesty"]
	check(mil2.treaty_accepted(war2, "FRA", {"with": "LEA", "granted": grant}), "governorships buy peace at the start")
	mil2.conclude(war2, "FRA", {"with": "LEA", "granted": grant})
	check_eq(c2.world.diplomacy.overlord_of("LEA"), "FRA", "the League's lords keep their lands as vassals")
	check(c2.world.country_stats("LEA").provinces > 0, "with their land")
	check(mil2.describe_treaty(war2, "FRA", {"with": "LEA", "granted": grant}).contains("lays down arms"), "described")


func test_flags_are_credited_and_colonies_fly_their_mothers() -> void:
	var w: WorldState = _setup()[0].world
	var credits := FileAccess.get_file_as_string(FlagArt.DIR + "CREDITS.md")
	for f in DirAccess.get_files_at(FlagArt.DIR):
		if not f.ends_with(".png"):
			continue
		var tag := f.get_basename()
		check(w.get_country(tag) != null, "%s is a realm of 1590" % f)
		check(credits.contains("| %s |" % tag), "%s is credited" % f)
	var flag := FlagArt.new()
	flag.size = Vector2(150, 100)
	for tag: String in w.created:
		var mother := w.diplomacy.overlord_of(tag)
		if FlagArt.texture_for(tag) == null and FlagArt.texture_for(mother) != null:
			flag.show_flag(w, tag)
			var r := flag.flag_rect()
			check(r.size.x <= 150.0 and r.size.y <= 100.0 and r.size.x > 0.0, "%s's flag fits" % tag)
			check(flag._texture == FlagArt.texture_for(mother), "%s flies %s's flag" % [tag, mother])
	flag.free()
