extends "res://tests/test_case.gd"
## Armies and war (M7): units by era and region, the forces of 1590, marching,
## battles, sieges and occupation, levies, regiments, merging and splitting,
## the stack limit, war and peace, upkeep, saving, and AI wars that end.


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


func test_units_belong_to_their_age_and_region() -> void:
	var c: Campaign = _setup()[0]
	var w := c.world
	var europe := UnitTypes.recruitable(w, "FRA", 1590, "land")
	check("pike_and_shot" in europe, "pike and shot in 1590s Europe")
	check(not "line_infantry" in europe and not "armoured_division" in europe, "nothing before its time")
	check(not "samurai" in europe and not "war_elephants" in europe, "nor from other lands")
	check("samurai" in UnitTypes.recruitable(w, "JAP", 1590, "land"), "samurai in Japan")
	check("janissaries" in UnitTypes.recruitable(w, "TUR", 1590, "land"), "janissaries for the Ottomans")
	check("war_elephants" in UnitTypes.recruitable(w, "MUG", 1590, "land"), "elephants in India")
	check("turtle_ship" in UnitTypes.recruitable(w, "JOS", 1590, "sea"), "turtle ships in Korea")
	var later := UnitTypes.recruitable(w, "FRA", 1940, "land")
	check("armoured_division" in later and not "pike_and_shot" in later, "tanks in 1940, no pikes")
	check("monoplane_fighter" in UnitTypes.recruitable(w, "FRA", 1940, "air"), "aircraft in their age")
	check(UnitTypes.recruitable(w, "FRA", 1590, "air").is_empty(), "no aircraft in 1590")


func test_the_forces_of_1590() -> void:
	var c: Campaign = _setup()[0]
	var m := c.world.military
	var fra := m.armies_of("FRA")
	check(fra.size() == 1 and fra[0].location == c.world.get_country("FRA").capital_province_id, "France's army at Paris")
	check(fra[0].men() > 5000 and fra[0].men() <= Military.STANDING_MAX, "a small standing army (%d)" % fra[0].men())
	check(m.armies_of("FRA", true).size() == 1, "and a navy")
	check(m.armies_of("ENG", true)[0].men() > 0, "England's navy")
	for a: Army in m.armies.values():
		check(a.men() <= UnitTypes.MAX_STACK, "%s within the stack limit" % a.name)
		check(not a.has_levies(), "no levies in peace")
	var paris := c.world.get_province(c.world.get_country("FRA").capital_province_id)
	check("fort" in paris.buildings, "Paris is fortified")
	var forts := 0
	for p: Province in c.world.ownable_provinces():
		if "fort" in p.buildings:
			forts += 1
	check(forts > 50 and forts < 500, "forts at capitals and great cities (%d)" % forts)


static func _navy_line(economy: EconomySystem, tag: String) -> float:
	for l: Array in economy.budget(tag).expenses:
		if l[0] == EconomySystem.NAVY:
			return l[1]
	return 0.0


func test_docks_berth_fleets_and_build_ships() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	var w := c.world
	# 1590: navies lie in port at a dock of their own.
	var navy: Army = m.armies_of("ENG", true)[0]
	var port := w.get_province(navy.location)
	check(not port.is_sea and "dock" in port.buildings and port.owner_id == "ENG", "England's navy in port at %s" % port.name)
	check(Military.is_berthed(w, navy), "berthed")
	var docks := 0
	for p: Province in w.ownable_provinces():
		if "dock" in p.buildings:
			docks += 1
			check(p.is_coastal, "%s's dock is on a coast" % p.name)
	check(docks > 20 and docks < 400, "docks at home ports and great harbours (%d)" % docks)
	check_eq(Buildings.unsuitable("dock", w.province_near(40.4, -3.7)), "Needs a coast", "no dock at Madrid")
	# Out to sea (full upkeep) and back into port (half).
	var in_port := _navy_line(economy, "ENG")
	var sea := mil.port_of(port)
	check_eq(mil.order_move(navy, sea), "", "it puts to sea")
	_days(mil, int(ceil(mil.path_days(navy, navy.path))) + 1)
	check_eq(navy.location, sea, "at sea")
	check(_navy_line(economy, "ENG") > in_port, "full upkeep at sea (%.2f against %.2f in port)" % [_navy_line(economy, "ENG"), in_port])
	check_eq(mil.order_move(navy, port.id), "", "back into port")
	_days(mil, int(ceil(mil.path_days(navy, navy.path))) + 1)
	check_eq(navy.location, port.id, "berthed again")
	# Only our docks (and friends'), and only as the end of a course: no canals.
	var spain_dock: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id == "SPA" and "dock" in p.buildings:
			spain_dock = p
			break
	check(spain_dock != null and mil.order_move(navy, spain_dock.id) == "That dock is not open to us", "Spain's docks are closed to us")
	var far := w.get_province(Military.home_sea(w, "SPA"))
	var path := mil.find_path(navy, far.id)
	check(not path.is_empty(), "a course to Spanish waters")
	for id: int in path:
		check(w.get_province(id).is_sea, "every leg at sea (%s)" % w.get_province(id).name)
	# Repairs in port only.
	var full: int = navy.regiments[0][1]
	navy.regiments[0][1] = full / 2
	navy.location = sea
	mil.monthly()
	check_eq(navy.regiments[0][1], full / 2, "no repairs at sea")
	navy.location = port.id
	mil.monthly()
	check(navy.regiments[0][1] > full / 2, "repaired in port")
	# Ships are built at docks, and launched there.
	var ship := Military.preferred_unit(w, "ENG", 1590, "ship")
	w.get_country("ENG").treasury = 5000.0
	for p: Province in w.ownable_provinces():
		if p.owner_id == "ENG" and p.is_coastal and not "dock" in p.buildings:
			check_eq(mil.recruit_blocked("ENG", p, ship), "Ships are built at a dock", "no shipyard at %s" % p.name)
			break
	var ships := navy.regiments.size()
	check_eq(mil.recruit_blocked("ENG", port, ship), "", "a ship can be laid down at %s" % port.name)
	mil.recruit("ENG", port, ship)
	_days(mil, int(UnitTypes.get_type(ship).months) * 30 + 1)
	check_eq(navy.regiments.size(), ships + 1, "launched into the fleet in port")
	# A dock lost: the fleet puts to sea.
	w.set_controller(port.id, "SPA")
	mil.daily()
	check_eq(navy.location, sea, "driven out to sea when the port falls")
	check_eq(mil.order_move(navy, port.id), "That dock is not open to us", "and cannot return")


func test_saves_from_before_docks_get_them() -> void:
	var c: Campaign = _setup()[0]
	var w := c.world
	var m := w.military
	var navy: Army = m.armies_of("ENG", true)[0]
	var port_id := navy.location
	for p: Province in w.ownable_provinces():
		p.buildings.erase("dock")
	navy.location = Military.port_sea(w, w.get_province(port_id))
	m.add_missing_docks(w)
	check("dock" in w.get_province(port_id).buildings, "the home port's dock is back")
	check_eq(navy.location, port_id, "and the fleet off it berths there")


func test_marching_follows_the_roads_open_to_us() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var army: Army = c.world.military.armies_of("FRA")[0]
	var lyon := c.world.province_near(45.76, 4.84)
	var path := mil.find_path(army, lyon.id)
	check(not path.is_empty(), "a road to Lyon")
	var at := c.world.get_province(army.location)
	for id: int in path:
		check(id in at.neighbour_ids, "each step to a neighbour")
		at = c.world.get_province(id)
	var madrid := c.world.province_near(40.4, -3.7)
	check(mil.order_move(army, madrid.id).contains("closed"), "Spain is closed in peace")
	check_eq(mil.order_move(army, lyon.id), "", "ordered to Lyon")
	var days := int(ceil(mil.path_days(army, army.path)))
	_days(mil, days + 1)
	check_eq(army.location, lyon.id, "arrived in %d days" % days)
	check(not army.is_moving(), "and halted")


func test_the_caspian_is_navigable() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var caspian: Array[Province] = []
	for sea: Province in c.world.sea_tiles():
		if sea.name.contains("Caspian") or sea.name.contains("Atyrau") or sea.name.contains("Celeken"):
			caspian.append(sea)
	check(caspian.size() >= 2, "Caspian sea zones")
	if caspian.size() < 2:
		return
	var fleet := c.world.military.add_army("SAF", caspian[0].id, [["galley", 300, 0]], true, "Caspian flotilla")
	check_eq(mil.order_move(fleet, caspian[1].id), "", "a fleet sails the Caspian")


func test_war_battle_siege_and_peace() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	_peace(c)
	var war := mil.declare_war("FRA", "SPA", "FRA")  # France plays: it calls its own levies
	check(not war.is_empty(), "war declared")
	check("SPA" in war.defenders and "POR" in war.defenders, "Spain's personal union fights with it")
	check(m.at_war("FRA", "SPA") and not m.levies_raised.has("SPA") and not m.levies_raised.has("FRA"),
		"declaring war calls nobody's levies")
	mil.clock.set_date(1590, 1, 8)  # a planning day (day 7)
	mil.ai_daily("FRA")
	check(m.levies_raised.has("SPA") and not m.levies_raised.has("FRA"), "the AI mobilises itself, never the player")
	check(mil.war_blocked("FRA", "SPA") != "", "no second declaration")
	# Levies leave the fields.
	var fra_levies := mil.raise_levies("FRA")
	check(fra_levies > 10000, "France calls %d levies" % fra_levies)
	var levied := 0
	for p: Province in c.world.ownable_provinces():
		levied += p.levied
	check(levied > 0, "levies are missing from their provinces' work")
	# A siege of an open province: occupied in days, ownership unchanged.
	var army: Army = m.armies_of("FRA")[0]
	var target: Province = null
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "SPA" and not "fort" in p.buildings and m.armies_at(p.id).is_empty() and p.lat > 41.0 and p.lon < 3.0:
			target = p
			break
	check(target != null, "an open Spanish province")
	if target == null:
		return
	army.location = target.id
	army.path.clear()
	_days(mil, int(MilitarySystem.OCCUPY_DAYS) + 1)
	check_eq(target.controller_id, "FRA", "occupied by France")
	check_eq(target.owner_id, "SPA", "still Spain's")
	check(mil.war_score(war) > 0.0, "France gains war score (%f)" % mil.war_score(war))
	# A battle where the armies meet.
	var spa: Army = m.armies_of("SPA")[0]
	spa.location = target.id
	spa.path.clear()
	var reports := []
	mil.battle_fought.connect(func(r): reports.append(r))
	_days(mil, 1)
	check_eq(reports.size(), 1, "they fight")
	if not reports.is_empty():
		check(reports[0].attacker_losses > 0 and reports[0].defender_losses > 0, "with losses on both sides")
	# Peace: France demands what it holds, if the score allows; else white peace.
	var terms := "demand" if mil.peace_accepted(war, "FRA", "demand") else "white"
	mil.make_peace(war, "FRA", terms)
	check(not m.at_war("FRA", "SPA"), "peace")
	check(mil.war_blocked("FRA", "SPA").begins_with("Truce"), "a truce follows")
	check(not m.levies_raised.has("FRA") and not m.levies_raised.has("SPA"), "levies go home")
	levied = 0
	for p: Province in c.world.ownable_provinces():
		levied += p.levied
	check_eq(levied, 0, "back to the fields")
	if terms == "white":
		check_eq(target.controller_id, "SPA", "control returns after a white peace")
	else:
		check_eq(target.owner_id, "FRA", "ceded to France")


## Spanish provinces near France: `n` open ones (not the capital), and a fort.
func _spanish_land(c: Campaign, n: int) -> Array:  # [Array[Province], fort province]
	var open: Array[Province] = []
	var fort: Province = null
	for p: Province in c.world.ownable_provinces():
		if p.owner_id != "SPA":
			continue
		if "fort" in p.buildings:
			if fort == null:
				fort = p
		elif open.size() < n and c.world.get_country("SPA").capital_province_id != p.id:
			open.append(p)
	return [open, fort]


func test_peace_treaties_take_land_money_and_forts() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	var actions := DiplomacyActions.new(c)
	var war := mil.declare_war("FRA", "SPA", "FRA")
	check(actions.blocked(DiplomacyActions.Action.SEND_GIFT, "FRA", "SPA", 10).begins_with("We are at war"), "no gifts to an enemy")
	check(actions.blocked(DiplomacyActions.Action.PROPOSE_MARRIAGE, "SPA", "FRA").begins_with("We are at war"), "nor marriages")
	var land := _spanish_land(c, 3)
	var held: Array[Province] = land[0]
	var fort: Province = land[1]
	check(held.size() == 3 and fort != null, "Spanish land and a fort")
	if held.size() < 3 or fort == null:
		return
	for p in held:
		c.world.set_controller(p.id, "FRA")
	var spa := c.world.get_country("SPA")
	var fra := c.world.get_country("FRA")
	spa.treasury = 500.0
	var white := {"provinces": [], "money": 0, "forts": []}
	var one := {"provinces": [held[0].id], "money": 0, "forts": []}
	var two := {"provinces": [held[0].id, held[1].id], "money": 0, "forts": []}
	var paid := {"provinces": [held[0].id, held[1].id], "money": 200, "forts": []}
	var razed := {"provinces": [held[0].id, held[1].id], "money": 200, "forts": [fort.id]}
	var costs := []
	for t: Dictionary in [one, two, paid, razed]:
		costs.append(mil.treaty_cost(war, "FRA", t))
	check(costs[0] > 0.0 and costs[0] < costs[1] and costs[1] < costs[2] and costs[2] < costs[3],
		"land, money and forts each cost war score %s" % str(costs))
	check_eq(mil.treaty_cost(war, "FRA", white), 0.0, "a white peace costs nothing")
	var english := c.world.province_near(51.51, -0.13)
	check(mil.treaty_blocked(war, "FRA", {"provinces": [english.id]}) != "", "only their side's land")
	var their_dev := mil.scope_development(war, "SPA", true, {})
	var unheld := mil.province_cost(war, "FRA", fort, their_dev)
	c.world.set_controller(fort.id, "FRA")
	check(absf(unheld - 2.0 * mil.province_cost(war, "FRA", fort, their_dev)) < 0.01, "land we do not hold costs double")
	c.world.set_controller(fort.id, "SPA")
	check(mil.treaty_blocked(war, "FRA", {"provinces": [], "money": 501, "forts": []}) != "", "no more money than they have")
	check(mil.treaty_blocked(war, "FRA", razed) == "", "a fair treaty can be put")
	check(not mil.treaty_accepted(war, "FRA", razed), "refused while our score is small (%.1f)" % mil.score_for(war, "FRA"))
	# The panel starts with the land we hold.
	var panel := PeaceTreatyPanel.new()
	panel.show_treaty(c.world, mil, war.id, "FRA")
	check_eq(panel.treaty().provinces.size(), 3, "the treaty screen asks for the land we hold")
	panel.free()
	# Victories in the field pay for the rest.
	war.battle_score = MilitarySystem.BATTLE_SCORE_CAP
	check(mil.treaty_accepted(war, "FRA", razed), "accepted once we are winning (%.1f of %.1f)" % [
		mil.score_for(war, "FRA"), costs[3]])
	var fra_before := fra.treasury
	var razed_signal := [false]
	mil.forts_changed.connect(func(): razed_signal[0] = true)
	mil.conclude(war, "FRA", razed)
	check(not m.at_war("FRA", "SPA"), "peace")
	check(held[0].owner_id == "FRA" and held[1].owner_id == "FRA", "the land is ceded")
	check(held[2].owner_id == "SPA" and held[2].controller_id == "SPA", "land not asked for goes back")
	check_eq(spa.treasury, 300.0, "Spain pays reparations")
	check_eq(fra.treasury, fra_before + 200.0, "to France")
	check(not "fort" in fort.buildings and razed_signal[0], "the fort is pulled down")
	check(not actions.blocked(DiplomacyActions.Action.SEND_GIFT, "FRA", "SPA", 10).begins_with("We are at war"),
		"diplomacy again after the peace")


func test_ai_offers_the_player_a_treaty() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var war := mil.declare_war("SPA", "FRA", "FRA")  # Spain (AI) attacks the player
	var fra_land: Array[Province] = []
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "FRA" and c.world.get_country("FRA").capital_province_id != p.id and fra_land.size() < 3:
			fra_land.append(p)
			c.world.set_controller(p.id, "SPA")
	war.battle_score = 55.0
	var offers := []
	mil.peace_offered.connect(func(w, t, from): offers.append([t, from]))
	mil.ai_monthly_peace("FRA")
	check_eq(offers.size(), 1, "Spain offers terms")
	if offers.is_empty():
		return
	var treaty: Dictionary = offers[0][0]
	check_eq(offers[0][1], "SPA", "from Spain")
	check_eq(treaty.provinces.size(), 3, "for the land it holds")
	check(int(treaty.money) >= 0 and int(treaty.money) % 10 == 0, "and reparations it can afford (%d)" % int(treaty.money))
	check(mil.describe_treaty(war, "SPA", treaty).begins_with(c.world.get_country("SPA").name + " takes"), mil.describe_treaty(war, "SPA", treaty))
	mil.conclude(war, "SPA", treaty)
	check_eq(fra_land[0].owner_id, "SPA", "accepting cedes it")


func test_fleets_carry_armies_over_the_sea() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	var w := c.world
	var navy: Army = m.armies_of("ENG", true)[0]
	var army: Army = m.armies_of("ENG")[0]
	check(navy.regiments.any(func(r: Array) -> bool: return UnitTypes.get_type(r[0]).kind == "transport"), "1590 navies have transports")
	check(navy.capacity() >= army.men(), "room for England's army (%d for %d)" % [navy.capacity(), army.men()])
	check_eq(army.location, navy.location, "army and navy both at London")
	# Too big an army stays ashore.
	var host := m.add_army("ENG", army.location, [["pike_and_shot", 1000, 0]], false, "Host")
	for i in 60:
		host.regiments.append(["pike_and_shot", 1000, 0])
	check(mil.board_blocked(host).contains("room"), "a host too big for the ships: " + mil.board_blocked(host))
	m.remove_army(host.id)
	# Aboard, out to the Channel, ashore on another coast.
	check_eq(mil.board(army), "", "boards at London")
	check_eq(army.aboard, navy.id, "aboard the navy")
	check(mil.disband_blocked(navy) != "" and mil.split_blocked(navy) != "", "a laden fleet is neither split nor disbanded")
	var channel: Province = null
	for sea: Province in w.sea_tiles():
		if sea.name == "English Channel":
			channel = sea
	check(channel != null, "the English Channel")
	if channel == null:
		return
	check_eq(mil.order_move(navy, channel.id), "", "the fleet sails")
	_days(mil, int(ceil(mil.path_days(navy, navy.path))) + 1)
	check_eq(army.location, channel.id, "the army sails with it")
	var coast: Province = null
	for id: int in channel.coast_ids:
		var p := w.get_province(id)
		if p.owner_id == "ENG" and id != w.get_country("ENG").capital_province_id:
			coast = p
			break
	check(coast != null, "an English coast on the Channel")
	if coast == null:
		return
	check(mil.order_move(army, w.province_near(48.86, 2.35).id) != "", "no landing far inland")
	check_eq(mil.order_move(army, coast.id), "", "ordered ashore at " + coast.name)
	_days(mil, int(MilitarySystem.LANDING_DAYS) + 1)
	check(army.location == coast.id and army.aboard == 0, "landed")
	# Troops aboard a lost fleet are lost with it.
	check_eq(mil.order_move(army, channel.id), "", "boards the fleet offshore by tapping it")
	check_eq(army.aboard, navy.id, "aboard again")
	m.remove_army(navy.id)
	mil.daily()
	check(not m.armies.has(army.id), "lost with the fleet")


func test_beaten_armies_fall_back() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	mil.declare_war("FRA", "SPA", "FRA")
	var target: Province = null
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "SPA" and not "fort" in p.buildings and p.topography == "flatland" and p.lat > 41.0 and p.lon < 3.0:
			target = p
			break
	check(target != null, "an open Spanish plain")
	if target == null:
		return
	var regiments := func(n: int) -> Array:
		var out := []
		for i in n:
			out.append(["pike_and_shot", 1000, 0])
		return out
	var french := m.add_army("FRA", target.id, regiments.call(20), false, "French")
	var spanish := m.add_army("SPA", target.id, regiments.call(6), false, "Spanish")
	mil._fight()
	check(m.armies.has(spanish.id), "the beaten army survives")
	check(spanish.retreating and not spanish.path.is_empty(), "and falls back")
	check_eq(mil.retreat_steps(spanish), 5, "pike and shot fall back up to five provinces")
	check(spanish.path.size() <= 5, "no further (%d)" % spanish.path.size())
	check(mil.order_move(spanish, target.id).begins_with("Retreating"), "no orders while falling back")
	mil._fight()
	check(m.armies.has(spanish.id), "not caught again while falling back")
	_days(mil, int(ceil(mil.path_days(spanish, spanish.path))) + 2)
	check(not spanish.retreating, "safe at the end of its retreat")
	# The distance shrinks as the army's technology (the age of its units) develops.
	var later := func(unit: String) -> Army:
		return m.add_army("SPA", target.id, [[unit, 1000, 0]], false, unit)
	check_eq(mil.retreat_steps(later.call("cuirassiers")), 6, "all on horseback: one further")
	check_eq(mil.retreat_steps(later.call("line_infantry")), 5, "line infantry (c. 1700): still five")
	check_eq(mil.retreat_steps(later.call("horse_artillery")), 5, "horse artillery (1760s, mounted): four, and one more")
	check_eq(mil.retreat_steps(later.call("rifle_infantry")), 3, "rifles (1850s): three")
	check_eq(mil.retreat_steps(later.call("infantry_division")), 2, "divisions (1910s): two")
	for a: Army in m.armies_of("SPA"):
		if a.regiments.size() == 1 and a.name == a.regiments[0][0]:
			m.remove_army(a.id)
	m.remove_army(spanish.id)
	# Overwhelmed: destroyed.
	m.remove_army(spanish.id)
	var few := m.add_army("SPA", target.id, regiments.call(1), false, "Few")
	var many := m.add_army("FRA", target.id, regiments.call(30), false, "Many")
	m.remove_army(french.id)
	mil._fight()
	check(not m.armies.has(few.id) and m.armies.has(many.id), "a host ten times over destroys what it beats")


func test_disloyal_vassals_stay_out_until_attacked() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var d := w.diplomacy
	check_eq(d.overlord_of("PRU"), "PLC", "Ducal Prussia is Poland's vassal")
	var loyal := mil.war_sides("RUS", "PLC")
	check("PRU" in loyal.defenders, "a loyal vassal is called to war")
	d.add_modifier("PRU", "PLC", "insult", -100.0, 200.0)
	check(not mil.actions.is_loyal("PRU"), "insulted, Prussia is disloyal (%d)" % mil.actions.loyalty("PRU"))
	var war := mil.declare_war("RUS", "PLC", "RUS")
	check(not war.is_empty(), "Russia attacks Poland")
	if war.is_empty():
		return
	check(not "PRU" in war.defenders and "PRU" in war.refused, "the disloyal vassal stays out")
	# Russia marches into Prussia: Prussia fights after all.
	var prussian: Province = null
	var beside: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id != "PRU":
			continue
		for n: int in p.neighbour_ids:
			var q := w.get_province(n)
			if q.owner_id == "PLC":
				prussian = p
				beside = q
		if prussian != null:
			break
	check(prussian != null, "Prussian land beside Poland's")
	if prussian == null:
		return
	check(mil.can_enter("RUS", prussian), "its land is open to Poland's enemy")
	var army := w.military.add_army("RUS", beside.id, [["streltsy", 1000, 0]], false, "Raiders")
	army.path = [prussian.id] as Array[int]
	army.leg_days = 0.5
	army.leg_total = 1.0
	mil._march()
	check("PRU" in war.defenders and not "PRU" in war.refused, "attacked, Prussia joins the war")
	check(w.military.at_war("RUS", "PRU"), "at war with Russia")


func test_separate_peace_with_one_of_their_side() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var war := mil.declare_war("FRA", "SPA", "FRA")
	check("SAV" in war.defenders, "Savoy fights for Spain")
	if not "SAV" in war.defenders:
		return
	var savoyard: Province = null
	for p: Province in w.ownable_provinces():
		if p.owner_id == "SAV" and w.get_country("SAV").capital_province_id != p.id:
			savoyard = p
			break
	w.set_controller(savoyard.id, "FRA")
	war.battle_score = MilitarySystem.BATTLE_SCORE_CAP
	var treaty := {"with": "SAV", "provinces": [savoyard.id]}
	check_eq(mil.treaty_blocked(war, "FRA", treaty), "", "our leader may make a separate peace with Savoy")
	check(not mil.is_full_peace(war, "FRA", "SAV"), "a separate peace")
	check(mil.treaty_accepted(war, "FRA", treaty), "accepted (score %.0f against %.0f)" % [
		mil.peace_score(war, "FRA", "SAV"), mil.treaty_cost(war, "FRA", treaty)])
	check(mil.describe_treaty(war, "FRA", treaty).ends_with("leaves the war"), mil.describe_treaty(war, "FRA", treaty))
	mil.conclude(war, "FRA", treaty)
	check(not "SAV" in war.defenders and w.military.at_war("FRA", "SPA"), "Savoy is out; the war goes on")
	check_eq(savoyard.owner_id, "FRA", "ceded to France")
	check(mil.war_blocked("FRA", "SAV").begins_with("Truce"), "a truce with Savoy")
	# Not two who do not lead: an ally of Spain may only treat with France.
	var other := ""
	for t: String in war.defenders:
		if t != "SPA":
			other = t
	if other != "":
		check(mil.treaty_blocked(war, other, {"with": "FRA"}) == "", "%s may make its own peace with France" % other)


func test_vassals_alliances_and_offers_in_peace() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var d := w.diplomacy
	var war := mil.declare_war("RUS", "PLC", "RUS")
	check(not war.is_empty(), "Russia attacks Poland")
	if war.is_empty():
		return
	d.set_allied("PLC", "ENG", true)  # a friend far away, not in the war
	war.battle_score = MilitarySystem.BATTLE_SCORE_CAP
	var terms := {"transfer": ["PRU"], "release": ["CRL"], "break": ["ENG"]}
	check_eq(mil.treaty_blocked(war, "RUS", terms), "", "their vassals and alliances can be asked for")
	check(mil.treaty_cost(war, "RUS", terms) > 0.0, "at a cost (%.0f)" % mil.treaty_cost(war, "RUS", terms))
	check(mil.treaty_blocked(war, "RUS", {"subjugate": true}).contains("too strong") or
		mil.treaty_blocked(war, "RUS", {"subjugate": true}) == "", "subjugation weighs their might")
	mil.conclude(war, "RUS", terms)
	check_eq(d.overlord_of("PRU"), "RUS", "Prussia passes to Russia")
	check_eq(d.overlord_of("CRL"), "", "Courland is set free")
	check(not d.is_allied("PLC", "ENG"), "Poland breaks its alliance with England")
	# A small country made a vassal.
	var war2 := mil.declare_war("FRA", "SAV", "FRA")
	check(not war2.is_empty(), "France attacks Savoy")
	if war2.is_empty():
		return
	war2.battle_score = MilitarySystem.BATTLE_SCORE_CAP
	for p: Province in w.ownable_provinces():
		if p.owner_id == "SAV":
			w.set_controller(p.id, "FRA")
	check(mil.treaty_blocked(war2, "SAV", {"subjugate": true}).contains("too strong"), "Savoy cannot make France its vassal")
	check(mil.treaty_accepted(war2, "FRA", {"subjugate": true}), "Savoy, beaten, accepts vassalage")
	mil.conclude(war2, "FRA", {"subjugate": true})
	check_eq(d.overlord_of("SAV"), "FRA", "Savoy is France's vassal")
	# Losing, we can buy peace with land.
	var war3 := mil.declare_war("TUR", "AUS", "TUR")
	check(not war3.is_empty(), "the Ottomans attack Austria")
	if war3.is_empty():
		return
	war3.battle_score = -12.0
	check(not mil.treaty_accepted(war3, "TUR", {}), "no white peace while losing")
	var give: Array[int] = []
	var offer := {"give": give}
	for p: Province in w.ownable_provinces():
		if p.owner_id == "TUR" and w.get_country("TUR").capital_province_id != p.id:
			give.append(p.id)
			if mil.treaty_value(war3, "TUR", offer) >= 15.0:
				break
	check(mil.treaty_accepted(war3, "TUR", offer), "but land given buys it (worth %.0f)" % mil.treaty_value(war3, "TUR", offer))
	# Or money paid to them, weighed by their year of taxes.
	var turks := w.get_country("TUR")
	turks.treasury = 1000000.0
	var paid := {"money": -int(mil._year_of_taxes("AUS"))}
	check(mil.treaty_value(war3, "TUR", paid) >= 20.0, "a year of Austria's taxes is worth much to it")
	check(mil.treaty_accepted(war3, "TUR", paid), "money buys peace too (worth %.0f)" % mil.treaty_value(war3, "TUR", paid))
	check(mil.treaty_blocked(war3, "TUR", {"money": -2000000}).begins_with("We have only"), "no more than we have")
	check(mil.describe_treaty(war3, "TUR", paid).contains("Ottoman"), "the treaty says who pays")
	var austria := w.get_country("AUS")
	var before := austria.treasury
	offer["money"] = -100
	mil.conclude(war3, "TUR", offer)
	check_eq(w.get_province(give[0]).owner_id, "AUS", "the land given is Austria's")
	check_eq(austria.treasury, before + 100.0, "and the money paid")


func test_ai_makes_separate_peace_when_beaten() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var w := c.world
	var war := mil.declare_war("FRA", "SPA", "FRA")
	if not "SAV" in war.defenders:
		check(false, "Savoy fights for Spain")
		return
	var taken := 0
	for p: Province in w.ownable_provinces():
		if p.owner_id == "SAV":
			w.set_controller(p.id, "FRA")
			taken = p.id
	mil.ai_monthly_peace("")
	check(not "SAV" in war.defenders, "beaten, Savoy makes its own peace")
	check_eq(w.get_province(taken).owner_id, "FRA", "ceding what France holds")
	check(w.military.at_war("FRA", "SPA"), "Spain fights on")


func test_levies_by_region() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	_peace(c)
	var regions := mil.levy_districts("FRA")
	check(regions.size() >= 3, "France has several levy regions (%d)" % regions.size())
	check(mil.district_blocked("FRA", regions[0].muster).contains("war"), "levies only in war")
	mil.declare_war("FRA", "SPA", "FRA")
	var first: Dictionary = regions[0]
	var men := mil.raise_district("FRA", first.muster)
	check(men > 0 and men <= first.ready, "one region's levies muster (%d)" % men)
	var after := mil.levy_districts("FRA")
	check_eq(after[0].out, men, "that region's men are under arms")
	check(after[1].out == 0 and after[1].ready > 0, "the next region's are still at home")
	check_eq(mil.district_blocked("FRA", first.muster), "Already under arms", "not called twice")
	check(m.armies_of("FRA").any(func(a: Army) -> bool: return a.name == "Levies of %s" % first.name), "mustered as its own army")
	var rest := mil.raise_levies("FRA")
	check(rest > 0, "mobilise all calls the rest (%d)" % rest)
	check(mil.mobilise_blocked("FRA") != "", "nothing left to call")
	mil.disband_district("FRA", first.muster)
	check_eq(mil.levy_districts("FRA")[0].out, 0, "one region sent home")
	check(m.levies_raised.has("FRA"), "the others still serve")


func test_forts_hold_out_longer() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var paris := c.world.get_province(c.world.get_country("FRA").capital_province_id)
	var open: Province = null
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "FRA" and not "fort" in p.buildings:
			open = p
			break
	check(mil.garrison(paris) > MilitarySystem.FORT_GARRISON and mil.garrison(open) == 0,
		"a fortified capital holds a large garrison, open land none")
	var france := c.world.get_country("FRA")
	var full := mil.garrison(paris)
	france.spending.forts = 50
	check(mil.garrison(paris) < full, "neglected forts hold fewer men")


func test_merge_split_and_the_stack_limit() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var m := c.world.military
	var a: Army = m.armies_of("FRA")[0]
	var b := mil.split(a)
	check(b != null and b.location == a.location, "split in place")
	var total := a.men() + b.men()
	check_eq(mil.merge_blocked([a, b]), "", "may merge")
	var id := mil.merge([a, b])
	check(m.armies.has(id) and not m.armies.has(b.id), "merged into one")
	check_eq(m.get_army(id).men(), total, "no men lost")
	var big: Array = []
	for i in 101:
		big.append(["pike_and_shot", 1000, 0])
	var huge := m.add_army("FRA", a.location, big, false, "Too big")
	check(mil.merge_blocked([m.get_army(id), huge]).begins_with("At most"), "no army over %d men" % UnitTypes.MAX_STACK)


func test_manpower_limits_regular_regiments() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var france := c.world.get_country("FRA")
	france.treasury = 5000.0
	var paris := c.world.get_province(france.capital_province_id)
	var full := mil.manpower("FRA")
	check(full > 10000.0 and is_equal_approx(full, floorf(mil.manpower_limit("FRA"))), "France starts with full manpower (%d)" % full)
	check(mil.recruit("FRA", paris, "pike_and_shot"), "a regiment raised")
	check(is_equal_approx(mil.manpower("FRA"), full - 1000.0), "from manpower")
	c.world.military.manpower["FRA"] = 500.0
	check(mil.recruit_blocked("FRA", paris, "pike_and_shot").contains("manpower"), "none left, none raised")
	mil.monthly()
	check(mil.manpower("FRA") > 500.0, "it refills month by month")
	# Levies take nothing from it.
	mil.declare_war("FRA", "SPA", "FRA")
	var before := mil.manpower("FRA")
	mil.raise_levies("FRA")
	check(is_equal_approx(mil.manpower("FRA"), before), "levies are not manpower")


func test_regiments_are_raised_and_paid_for() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var france := c.world.get_country("FRA")
	france.treasury = 500.0
	var paris := c.world.get_province(france.capital_province_id)
	check(mil.recruit_blocked("FRA", paris, "samurai") != "", "no samurai for France")
	check(mil.recruit_blocked("FRA", paris, "armoured_division") != "", "no tanks in 1590")
	check_eq(mil.recruit_blocked("FRA", paris, "pike_and_shot"), "", "pike and shot can be raised")
	var men: int = c.world.military.armies_of("FRA")[0].men()
	check(mil.recruit("FRA", paris, "pike_and_shot"), "paid for")
	check(france.treasury < 500.0, "it costs ducats")
	_days(mil, int(UnitTypes.get_type("pike_and_shot").months) * 30 + 1)
	check_eq(c.world.military.armies_of("FRA")[0].men(), men + 1000, "and joins the army at Paris")


func test_upkeep_follows_maintenance() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var france := c.world.get_country("FRA")
	var line := func() -> float:
		for l: Array in economy.budget("FRA").expenses:
			if l[0] == EconomySystem.ARMY:
				return l[1]
		return 0.0
	var full: float = line.call()
	check(full > 0.0, "France pays for its army (%f)" % full)
	france.spending.army = 50
	economy.changed()
	check(is_equal_approx(line.call(), full * 0.5), "half maintenance, half the cost")
	check(Policies.max_morale(50) < Policies.max_morale(100), "and less spirit")


func test_military_survives_save_and_load() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var war := mil.declare_war("FRA", "SPA")
	mil.raise_levies("FRA")
	var army: Army = c.world.military.armies_of("FRA")[0]
	mil.order_move(army, c.world.province_near(45.76, 4.84).id)
	_days(mil, 3)
	c.world.get_country("FRA").spending.navy = 75
	var copy: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict(), "", false, true))
	var b: Campaign = _setup()[0]
	check(b.restore(copy).is_empty(), "restore")
	var m2 := b.world.military
	check_eq(m2.armies.size(), c.world.military.armies.size(), "armies")
	var again := m2.get_army(army.id)
	check(again != null and again.location == army.location and again.path == army.path, "on the march")
	check(m2.at_war("FRA", "SPA"), "the war")
	check_eq(b.world.get_country("FRA").spending.navy, 75, "maintenance")
	var levied := 0
	for p: Province in b.world.ownable_provinces():
		levied += p.levied
	check(levied > 0, "levies counted from the regiments")
	# An older save (format 6) gets the forces of the start and percentages.
	var old: Dictionary = copy.duplicate(true)
	old.erase("military")
	var data := {"campaign": old}
	for tag: String in old.world.countries:
		var pol: Dictionary = old.world.countries[tag].policies
		pol.court = 2
		pol.mint = 1
		pol.forts = 0
		pol.erase("army")
		pol.erase("navy")
	SaveService._upgrade_6_to_7(data)
	check(b.restore(old).is_empty(), "format 6 restores")
	check_eq(b.world.get_country("FRA").spending, {"court": 160, "mint": 5, "forts": 50, "army": 100, "navy": 100},
		"levels become percentages")
	check(not b.world.military.armies.is_empty(), "with the forces of the start")


## AI wars must end: a decade of an AI war ends in peace one way or another.
func test_ai_wars_end() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var mil: MilitarySystem = s[2]
	var war := mil.declare_war("FRA", "SPA")
	for month in 120:
		for d in 30:
			mil.clock.step_day()
			mil.daily()
			mil.ai_daily("")
		mil.monthly()
		mil.ai_monthly_peace("")
		if not c.world.military.at_war("FRA", "SPA"):
			break
	check(not c.world.military.at_war("FRA", "SPA"), "the war ended within ten years")

## The wars of 1590 ended (for tests that start from peace).
func _peace(c: Campaign) -> void:
	for w: Dictionary in c.world.military.wars.duplicate():
		c.world.military.remove_war(w)
	for a: Army in c.world.military.armies.values():
		a.volunteer_for = ""
