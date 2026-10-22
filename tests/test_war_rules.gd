extends "res://tests/test_case.gd"
## The rules of war from 21 Oct 2026: forts barring the roads before 1800;
## sieges as monthly tries (numbers, guns, siege equipment, time) and storming
## at a heavy cost; handing occupied land to an ally; declaring war without
## calling allies; manpower and sailors as pools trained by barracks and
## docks; ideas (press gangs) and what they let a realm do; saving it all.


func _setup() -> Array:  # [campaign, economy, military system]
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	var c := Campaign.new(world)
	var economy := EconomySystem.new(c)
	var actions := DiplomacyActions.new(c)
	return [c, economy, MilitarySystem.new(c, economy, actions)]


func _days(mil: MilitarySystem, n: int) -> void:
	for i in n:
		mil.clock.step_day()
		mil.daily()


func _regiments(foot: int, guns := 0) -> Array:
	var out := []
	for i in foot:
		out.append(["pike_and_shot", 1000, 0])
	for i in guns:
		out.append(["field_artillery", 1000, 0])
	return out


## A Spanish province in Spain (not the capital) with Spanish land on at least
## two sides, fortified for the test (in 1590 only Madrid is).
func _spanish_fort(c: Campaign) -> Array:  # [fort, [neighbours]]
	var w := c.world
	for p: Province in w.ownable_provinces():
		if p.owner_id != "SPA" or w.get_country("SPA").capital_province_id == p.id or w.overseas.has(p.id):
			continue
		var around: Array[Province] = []
		for n: int in p.neighbour_ids:
			var q := w.get_province(n)
			if q != null and not q.is_sea and not q.is_wasteland and q.controller_id == "SPA":
				around.append(q)
		if around.size() >= 2:
			if not "fort" in p.buildings:
				p.buildings.append("fort")
			return [p, around]
	return [null, []]


func test_siege_odds_need_men_and_guns() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	var found := _spanish_fort(c)
	var fort: Province = found[0]
	check(fort != null, "a Spanish fort")
	if fort == null:
		return
	var small := m.add_army("FRA", fort.id, _regiments(2), false, "Small")
	var big := m.add_army("FRA", fort.id, _regiments(10), false, "Big")
	var guns := m.add_army("FRA", fort.id, _regiments(8, 2), false, "Guns")
	var odds := func(a: Army, phases := 0) -> Dictionary: return mil.siege_odds(fort, [a], phases)
	var shortage := func(o: Dictionary) -> float:
		for r: Array in o.reasons:
			if r[0] == "Short of siege equipment":
				return r[1]
		return 0.0
	check(shortage.call(odds.call(small)) < -30.0, "a small host without guns is short of siege equipment (%.0f)" %
		shortage.call(odds.call(small)))
	check(shortage.call(odds.call(big)) > shortage.call(odds.call(small)), "a great host makes do with ladders and saps")
	check_eq(shortage.call(odds.call(guns)), 0.0, "guns are siege equipment enough")
	check(odds.call(small).chance < odds.call(big).chance and odds.call(big).chance < odds.call(guns).chance,
		"more men, better odds; guns best of all (%.0f, %.0f, %.0f)" % [odds.call(small).chance, odds.call(big).chance,
		odds.call(guns).chance])
	check(odds.call(big, 4).chance > odds.call(big).chance, "the odds grow the longer the siege lasts")
	check(odds.call(guns, 100).chance <= MilitarySystem.SIEGE_MAX_CHANCE, "never certain")
	# A capital is stronger; neglected forts weaker.
	var madrid := c.world.get_province(c.world.get_country("SPA").capital_province_id)
	check(mil.garrison(madrid) > mil.garrison(fort), "a capital's garrison is larger")
	check(mil.siege_odds(madrid, [guns]).chance < odds.call(guns).chance, "and harder to take")
	var before: float = odds.call(guns).chance
	c.world.get_country("SPA").spending.forts = 50
	check(odds.call(guns).chance > before, "neglected forts fall sooner")
	check(MilitarySystem.assault_chance(30.0) > 30.0, "storming beats waiting for the next try")


func test_sieges_roll_monthly_and_forts_can_be_stormed() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	c.world.set_player_country("FRA")  # no AI storming on France's behalf
	var found := _spanish_fort(c)
	var fort: Province = found[0]
	if fort == null:
		failures.append("no Spanish fort")
		return
	mil.declare_war("FRA", "SPA", "FRA")
	for a: Army in m.armies_at(fort.id):
		m.remove_army(a.id)
	# Too few men to shut the garrison in: no siege.
	var few := m.add_army("FRA", fort.id, [["pike_and_shot", 900, 0]], false, "Few")
	_days(mil, 2)
	check(not m.sieges.has(fort.id), "too few to besiege a fort")
	m.remove_army(few.id)
	var army := m.add_army("FRA", fort.id, _regiments(6, 2), false, "Besiegers")
	_days(mil, 1)
	check(m.sieges.has(fort.id), "a siege begins")
	if not m.sieges.has(fort.id):
		return
	check(float(m.sieges[fort.id].get("chance", 0.0)) > 0.0, "with odds for the next try")
	check_eq(mil.days_to_try(fort.id), MilitarySystem.SIEGE_PHASE_DAYS - 1, "a try a month")
	check(mil.assault_blocked("FRA", fort.id).begins_with("The siege works"), "no storming at once")
	check(mil.assault_blocked("SWI", fort.id) != "", "only the besiegers storm it")
	_days(mil, MilitarySystem.ASSAULT_MIN_DAYS)
	check_eq(mil.assault_blocked("FRA", fort.id), "", "storming once the works are dug")
	var men := army.men()
	var result := mil.assault("FRA", fort.id)
	check(not result.is_empty() and result.lost > 0, "storming costs men (%d)" % result.get("lost", 0))
	check(army.men() < men, "the stormers are fewer")
	if result.get("taken", false):
		check_eq(fort.controller_id, "FRA", "taken by storm")
		return
	check(army.men() <= int(men * (1.0 - MilitarySystem.ASSAULT_FAIL_LOSS)) + 50, "a failed assault is bloody")
	check(mil.assault_blocked("FRA", fort.id).begins_with("Our men need"), "and not at once again")
	# Waiting it out: the tries come monthly, and the odds grow.
	for i in 12:
		_days(mil, MilitarySystem.SIEGE_PHASE_DAYS)
		if fort.controller_id == "FRA" or not m.sieges.has(fort.id):
			break
	check_eq(fort.controller_id, "FRA", "the fort falls within a year")


func test_forts_bar_the_roads_before_1800() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	var found := _spanish_fort(c)
	var fort: Province = found[0]
	if fort == null:
		failures.append("no Spanish fort")
		return
	var a: Province = found[1][0]
	var b: Province = found[1][1]
	_peace(c)
	check(mil.fort_zones("FRA").is_empty(), "no zones at peace")
	mil.declare_war("FRA", "SPA", "FRA")
	var zones := mil.fort_zones("FRA")
	check(zones.has(fort.id) and zones.has(a.id) and zones.has(b.id), "the fort and the land beside it")
	check(MilitarySystem.zoc_blocks(zones, a.id, b.id), "no marching on past it")
	check(not MilitarySystem.zoc_blocks(zones, a.id, fort.id), "but into the fort, to besiege it")
	check(MilitarySystem.zoc_blocks(zones, fort.id, b.id), "nor through it")
	check(mil.fort_zones("SWI").is_empty(), "only for its enemies")
	# Roads keep out of the zone, or go into the fort.
	var army := m.add_army("FRA", a.id, _regiments(5), false, "Raiders")
	var path := mil.find_path(army, b.id)
	var at := a.id
	var ok := true
	for id: int in path:
		if MilitarySystem.zoc_blocks(zones, at, id):
			ok = false
		at = id
	check(ok, "the road found keeps to the rules (%s)" % str(path))
	if path.is_empty():
		check(mil.order_move(army, b.id).contains("forts"), "and says why there is none")
	# Taken, it bars nothing.
	c.world.set_controller(fort.id, "FRA")
	check(not mil.fort_zones("FRA").has(fort.id), "a fort taken bars no more")
	c.world.set_controller(fort.id, "SPA")
	# From 1800 armies march past forts.
	mil.clock.set_date(1800, 1, 1)
	check(mil.fort_zones("FRA").is_empty(), "no zones from 1800")


func test_occupation_handed_to_an_ally_and_allies_not_called() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var d := c.world.diplomacy
	d.set_allied("FRA", "SCO", true)
	d.set_married("FRA", "SCO", true)
	# Declaring war without calling allies.
	var called := mil.war_sides("FRA", "SPA", true)
	var alone := mil.war_sides("FRA", "SPA", false)
	check(not "SCO" in alone.attackers, "allies not called stay out")
	if d.opinion("SCO", "FRA") >= 50:
		check("SCO" in called.attackers, "called, a friendly ally comes")
	var war := mil.declare_war("FRA", "SPA", "FRA", false)
	check(not war.is_empty() and not "SCO" in war.attackers, "a war fought without allies")
	mil.make_peace(war, "FRA", "white")
	# Spain attacks France: Scotland defends it.
	c.world.military.truces.clear()
	war = mil.declare_war("SPA", "FRA")
	check("SCO" in war.defenders, "Scotland comes to France's aid")
	var found := _spanish_fort(c)
	var p: Province = found[1][0]
	c.world.set_controller(p.id, "FRA")
	check("SCO" in mil.occupation_partners("FRA", p), "Scotland may hold it")
	check(mil.transfer_occupation_blocked("FRA", "SWI", p) != "", "not a country outside the war")
	check(mil.transfer_occupation_blocked("FRA", "SCO", c.world.get_province(c.world.get_country("FRA").capital_province_id))
		!= "", "not our own land")
	check(mil.transfer_occupation("FRA", "SCO", p.id), "handed over")
	check_eq(p.controller_id, "SCO", "Scotland holds it")
	check_eq(p.owner_id, "SPA", "still Spain's")
	check(mil.transfer_occupation_blocked("FRA", "SCO", p) != "", "no longer ours to hand on")


func test_manpower_and_sailors_come_from_barracks_and_docks() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var paris := w.get_province(w.get_country("FRA").capital_province_id)
	check("barracks" in paris.buildings, "France keeps barracks at Paris")
	check_eq(mil.manpower("FRA"), floorf(mil.manpower_limit("FRA")), "manpower starts full")
	check_eq(mil.sailors("ENG"), floorf(mil.sailor_limit("ENG")), "so do sailors")
	check(mil.pool("FRA").trained > 0.0 and mil.pool("ENG").crews > 0.0, "barracks train soldiers, docks sailors")
	# A new barracks raises the growth and the ceiling.
	var lyon := w.province_near(44.84, -0.58)
	check(not "barracks" in lyon.buildings, "none at Bordeaux")
	var before := mil.pool("FRA")
	lyon.buildings.append("barracks")
	var after := mil.pool("FRA")
	check(after.manpower_growth > before.manpower_growth and after.manpower > before.manpower, "barracks at Bordeaux add to both")
	# Without barracks or docks, the pools fill slowly.
	check(mil.pool("FRA").manpower_growth > mil.pool("FRA").manpower / MilitarySystem.POOL_GROWTH_MONTHS,
		"training is most of the growth")
	# Ships draw on sailors, regiments on manpower.
	var dock: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id == "ENG" and "dock" in p.buildings:
			dock = p
			break
	w.get_country("ENG").treasury = 5000.0
	var ship := Military.preferred_unit(w, "ENG", 1590, "ship")
	var men := mil.manpower("ENG")
	var crews := mil.sailors("ENG")
	check(mil.recruit("ENG", dock, ship), "a ship laid down")
	check_eq(mil.sailors("ENG"), crews - UnitTypes.get_type(ship).men, "its crew from the sailors")
	check_eq(mil.manpower("ENG"), men, "not from manpower")
	w.military.sailors["ENG"] = 0.0
	check(mil.recruit_blocked("ENG", dock, ship).contains("sailors"), "no sailors, no ship")
	mil.monthly()
	check(mil.sailors("ENG") > 0.0, "the docks train more")
	check_eq(mil.sailor_limit("SWI"), 0.0, "Switzerland, landlocked, has no sailors")


func test_ideas_and_press_gangs() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	check(Ideas.has(w.get_country("ENG"), "press_gangs"), "England presses men in 1590")
	check(not Ideas.has(w.get_country("FRA"), "press_gangs"), "France does not")
	# France takes up the idea.
	var france := w.get_country("FRA")
	france.treasury = 10000.0
	check_eq(mil.idea_blocked("FRA", "press_gangs"), "", "France may take it up")
	var cost := mil.idea_cost("FRA")
	check(mil.adopt_idea("FRA", "press_gangs"), "taken up")
	check(Ideas.has(france, "press_gangs") and is_equal_approx(france.treasury, 10000.0 - cost), "paid for")
	check(mil.idea_blocked("FRA", "drill_grounds").begins_with("No room"), "one idea in this age")
	check(mil.idea_blocked("FRA", "conscription") != "", "conscription waits for its age")
	check(mil.idea_blocked("SWI", "press_gangs").contains("dock"), "landlocked Switzerland cannot take it up")
	# Pressing: an English army at home.
	var eng: Army = w.military.armies_of("ENG")[0]
	var p := w.get_province(eng.location)
	check_eq(mil.press_blocked(eng), "", "England's army may press men at home")
	var commoners: int = p.pops.get("commoners", 0)
	var men := mil.manpower("ENG")
	var unrest := p.unrest
	var n := mil.press_men(eng)
	check(n > 0 and is_equal_approx(mil.manpower("ENG"), men + n), "pressed into the army (%d)" % n)
	check_eq(p.pops.get("commoners", 0), commoners - n, "out of the common people")
	check(p.unrest > unrest, "and they resent it")
	check(mil.press_blocked(eng).contains("pressed lately"), "once a year a province")
	# A fleet in its dock presses sailors.
	var fleet: Army = null
	for a: Army in w.military.armies_of("ENG", true):
		if Military.is_berthed(w, a) and a.location != p.id:
			fleet = a
			break
	if fleet != null:
		var crews := mil.sailors("ENG")
		var k := mil.press_men(fleet)
		check(k > 0 and is_equal_approx(mil.sailors("ENG"), crews + k), "a fleet presses sailors (%d)" % k)
	# Not abroad, not without the idea.
	eng.location = w.get_province(w.get_country("FRA").capital_province_id).id
	check(mil.press_blocked(eng).contains("own provinces"), "only at home")
	var spa: Army = w.military.armies_of("SCO")[0] if not w.military.armies_of("SCO").is_empty() else null
	if spa != null:
		check(mil.press_blocked(spa).contains("Press gangs"), "Scotland has not the idea")
	# Saved and restored: ideas, sailors, pressed provinces.
	var copy: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict(), "", false, true))
	var b: Campaign = _setup()[0]
	check(b.restore(copy).is_empty(), "restore")
	check(Ideas.has(b.world.get_country("FRA"), "press_gangs"), "France keeps the idea")
	check_eq(b.world.military.sailors.get("ENG", -1.0), w.military.sailors["ENG"], "sailors kept")
	check(b.world.military.pressed.has(p.id), "the pressed province remembered")
	# An older save (no ideas, no sailors) gets the start's.
	var old: Dictionary = copy.duplicate(true)
	for tag: String in old.world.countries:
		old.world.countries[tag].erase("ideas")
	old.military.erase("sailors")
	var o: Array = _setup()
	var oc: Campaign = o[0]
	var omil: MilitarySystem = o[2]
	check(oc.restore(old).is_empty(), "an older save restores")
	check(Ideas.has(oc.world.get_country("ENG"), "press_gangs") and not Ideas.has(oc.world.get_country("FRA"), "press_gangs"),
		"with the ideas of 1590")
	check(omil.sailors("ENG") > 0.0, "and full sailors")


func test_colonial_nations_are_not_seasoned_to_africa() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var colonies := ColonisationSystem.new(c, economy)
	var moz := ""
	for tag: String in c.world.created:
		if c.world.get_country(tag).name == "Captaincy of Mozambique":
			moz = tag
	check(moz != "", "the Captaincy of Mozambique")
	if moz == "":
		return
	check(not Colonisation.seasoned(colonies.home_climates(moz)), "its settlers come from Portugal, unseasoned")
	var inland := c.world.province_near(-13.5, 33.8)  # the African interior, west of Lake Malawi
	if Colonisation.in_disease_zone(inland) and not inland.is_coastal:
		check_eq(Colonisation.disease_factor(inland, Colonisation.seasoned(colonies.home_climates(moz)), 1590), 0.0,
			"the interior is closed to it until quinine")

## The wars of 1590 ended (for tests that start from peace).
func _peace(c: Campaign) -> void:
	for w: Dictionary in c.world.military.wars.duplicate():
		c.world.military.remove_war(w)
	for a: Army in c.world.military.armies.values():
		a.volunteer_for = ""


func test_capitals_are_besieged_and_only_kingdoms_fortify_theirs() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var m := w.military
	# 1590: the seats of kings and emperors are fortified; a duke's or a count's
	# only where history fortified it.
	var open_seats: Array[Province] = []
	for tag: String in w.countries:
		var co := w.get_country(tag)
		var cap := w.get_province(co.capital_province_id)
		if cap == null or cap.owner_id != tag:
			continue
		if co.rank >= Military.FORT_CAPITAL_RANK:
			check("fort" in cap.buildings, "%s's capital is fortified" % co.name)
		elif not "fort" in cap.buildings:
			open_seats.append(cap)
	check(open_seats.size() > 20, "many lesser seats have no fort (%d)" % open_seats.size())
	# A capital without a fort: walls and a watch, besieged, never simply occupied.
	var cap: Province = null
	for p: Province in open_seats:
		if p.owner_id == "KED":
			cap = p
	if cap == null:
		cap = open_seats[0]
	var target := cap.owner_id
	c.world.set_player_country("AYU")
	w.diplomacy.release_subject(target)
	check_eq(mil.war_blocked("AYU", target), "", "Ayutthaya may make war on %s" % w.get_country(target).name)
	mil.declare_war("AYU", target, "AYU", false)
	for a: Army in m.armies_at(cap.id):
		m.remove_army(a.id)
	check(MilitarySystem.walled(w, cap), "a capital is walled")
	check_eq(mil.garrison(cap), int(MilitarySystem.FORT_GARRISON * MilitarySystem.CITY_WALLS), "its watch")
	m.add_army("AYU", cap.id, _regiments(6), false, "Besiegers")
	_days(mil, int(MilitarySystem.OCCUPY_DAYS) + 1)
	check_eq(cap.controller_id, target, "not taken in the days open land falls in")
	check(m.sieges.has(cap.id), "but besieged")
	var odds := mil.siege_odds(cap)
	check(odds.reasons.any(func(r: Array) -> bool: return r[0] == "The city walls"), "its city walls count")
	check(odds.chance > 0.0, "with odds for the next try (%d %%)" % int(odds.chance))
	check_eq(mil.assault_blocked("AYU", cap.id), "", "it may be stormed")
	for i in 12:
		_days(mil, MilitarySystem.SIEGE_PHASE_DAYS)
		if cap.controller_id == "AYU":
			break
	check_eq(cap.controller_id, "AYU", "it falls within a year")

	# A fortified capital holds half again as long as a fort elsewhere.
	var found := _spanish_fort(c)
	var madrid := w.get_province(w.get_country("SPA").capital_province_id)
	if found[0] != null and "fort" in madrid.buildings:
		check(is_equal_approx(mil.fort_strength(madrid), mil.fort_strength(found[0]) * MilitarySystem.CAPITAL_SIEGE),
			"a capital's fort is the stronger")
