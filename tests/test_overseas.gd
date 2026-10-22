extends "res://tests/test_case.gd"
## Overseas territory and colonial nations: colonial regions; what is overseas
## (another world region, no route home over one's own land); the colonial
## nations of 1590; a new one when three provinces are settled in a region,
## and later ones joining it; their tribute, levies and saving.


func _campaign() -> Campaign:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	return Campaign.new(world)


func _nation_named(world: WorldState, name: String) -> String:
	for tag: String in world.created:
		if world.get_country(tag).name == name:
			return tag
	return ""


func test_colonial_regions() -> void:
	var w := _campaign().world
	check_eq(Overseas.region_of(w.province_near(19.43, -99.13)), "new_spain", "Mexico City in New Spain")
	check_eq(Overseas.region_of(w.province_near(-12.05, -77.04)), "peru", "Lima in Peru")
	check_eq(Overseas.region_of(w.province_near(-19.58, -65.75)), "peru", "Potosí in Peru")
	check_eq(Overseas.region_of(w.province_near(-12.97, -38.5)), "brazil", "Salvador in Brazil")
	check_eq(Overseas.region_of(w.province_near(23.13, -82.38)), "caribbean", "Havana in the Caribbean")
	check_eq(Overseas.region_of(w.province_near(9.93, -84.08)), "new_spain", "Costa Rica in New Spain, not the Caribbean")
	check_eq(Overseas.region_of(w.province_near(15.5, 73.83)), "india", "Goa in India")
	check_eq(Overseas.region_of(w.province_near(48.86, 2.35)), "", "Europe has no colonial region")


func test_the_colonial_nations_of_1590() -> void:
	var w := _campaign().world
	var mexico := w.province_near(19.43, -99.13)
	var new_spain := _nation_named(w, "Viceroyalty of New Spain")
	check(new_spain != "", "the Viceroyalty of New Spain")
	check_eq(mexico.owner_id, new_spain, "holds Mexico City")
	check_eq(w.get_country(new_spain).capital_province_id, mexico.id, "its capital")
	check_eq(w.diplomacy.overlord_of(new_spain), "SPA", "Spain's colony")
	check_eq(w.diplomacy.subject_type(new_spain), "colony", "a colony")
	check(w.claims.is_core(new_spain, mexico.id), "its cores")
	for name in ["Viceroyalty of Peru", "State of Brazil", "Estado da Índia", "Captaincy General of the Philippines"]:
		check(_nation_named(w, name) != "", name)
	var direct := 0
	for p: Province in w.ownable_provinces():
		if p.owner_id == "SPA" and Overseas.region_of(p) == "new_spain":
			direct += 1
	check_eq(direct, 0, "Spain holds nothing in New Spain directly")
	# Russia's Siberia is not overseas: it is joined to Moscow by Russian land.
	var siberia := 0
	for id: int in w.overseas:
		if w.get_province(id).owner_id == "RUS":
			siberia += 1
	check_eq(siberia, 0, "nothing of Russia's is overseas")


func test_three_settled_provinces_make_a_colonial_nation() -> void:
	var c := _campaign()
	var w := c.world
	var picked: Array[int] = []
	for p: Province in w.ownable_provinces():
		if p.owner_id == "" and Overseas.region_of(p) == "eastern_america" and picked.size() < 4:
			picked.append(p.id)
	check_eq(picked.size(), 4, "unsettled land in Eastern America")
	for id: int in picked.slice(0, 2):
		w.transfer_province(id, "ENG")
	check(Overseas.update(w).is_empty(), "two provinces: no colonial nation yet")
	check(w.overseas.has(picked[0]), "but overseas")
	w.transfer_province(picked[2], "ENG")
	var events := Overseas.update(w)
	check_eq(events.size(), 1, "three: a colonial nation")
	if events.is_empty():
		return
	var nation: String = events[0][1]
	check_eq(w.get_country(nation).name, "Thirteen Colonies", "named")
	check_eq(w.get_province(picked[0]).owner_id, nation, "the land is the colony's")
	check_eq(w.diplomacy.overlord_of(nation), "ENG", "England's colony")
	w.transfer_province(picked[3], "ENG")
	events = Overseas.update(w)
	check(events.size() == 1 and events[0][0] == "joined", "a fourth province joins it")
	check_eq(w.get_province(picked[3]).owner_id, nation, "the colony's")
	# Tribute, and no levies overseas.
	var eco := EconomySystem.new(c)
	var tribute := 0.0
	for line: Array in eco.budget("ENG").income:
		if line[0].begins_with("Tribute"):
			tribute += line[1]
	check(tribute > 0.0, "the colony pays tribute (%.2f)" % tribute)
	# Saved and restored: the colonial nation comes back; a new campaign has none of it.
	var data := c.to_dict()
	var c2 := _campaign()
	var errors := c2.restore(data)
	check(errors.is_empty(), "restores: %s" % ", ".join(errors))
	check(c2.world.countries.has(nation) and c2.world.get_province(picked[0]).owner_id == nation, "the colony is back")
	c2.start_new("ENG")
	check(not c2.world.countries.has(nation), "a new campaign starts without it")


func test_overseas_land_raises_no_levies() -> void:
	var c := _campaign()
	var w := c.world
	var mil := MilitarySystem.new(c, EconomySystem.new(c), DiplomacyActions.new(c))
	var goa_region := 0
	for d: Dictionary in mil.levy_districts("POR"):
		for id: int in d.ids:
			if w.overseas.has(id):
				goa_region += 1
	check_eq(goa_region, 0, "Portugal's levy regions are all at home")
	check(w.overseas.size() > 0, "some land is still overseas (outposts of under three)")


## Colonies pay their way and their mother: founding money, cheap frontier
## administration, a viceroy's court, the royal fifth, the situado for their
## forts (and their shortfall), and tribute that leaves them half their surplus.
func test_colonies_pay_their_way() -> void:
	var world := _campaign().world
	var c := Campaign.new(world)
	var economy := EconomySystem.new(c)
	MilitarySystem.new(c, economy, DiplomacyActions.new(c))
	var line := func(b: Dictionary, which: String, label: String) -> float:
		for l: Array in b[which]:
			if l[0] == label:
				return l[1]
		return 0.0
	for tag: String in world.created:
		var k := world.get_country(tag)
		var b: Dictionary = economy.budget(tag)
		check(k.treasury > 0.0, "%s starts with money" % k.name)
		check(b.net > 0.0, "%s starts in surplus (%+.1f)" % [k.name, b.net])
		var spare: float = b.net + line.call(b, "expenses", EconomySystem.TRIBUTE_OUT)
		check(line.call(b, "expenses", EconomySystem.TRIBUTE_OUT) <= spare * EconomySystem.COLONY_REMIT + 0.01,
			"%s keeps at least half its surplus" % k.name)
		var ships := 0
		for a: Army in world.military.armies_of(tag, true):
			ships += a.regiments.size()
		check(ships <= Military.COLONIAL_NAVY_MAX + 2, "%s keeps a coast-guard squadron (%d)" % [k.name, ships])
	var new_spain := _nation_named(world, "Viceroyalty of New Spain")
	check(line.call(economy.budget(new_spain), "income", EconomySystem.FIFTH) > 1.0, "New Spain's silver pays the royal fifth")
	check(line.call(economy.budget(new_spain), "expenses", EconomySystem.TRIBUTE_OUT) > 1.0, "and its tribute goes home")
	check(line.call(economy.budget("SPA"), "expenses", EconomySystem.SITUADO) > 0.0, "Spain pays the situado")
	check(economy.budget("SPA").net > 0.0, "and is still in surplus")
	# Frontier land costs little to run; an outpost's fort little to keep.
	var lima := world.province_near(-12.05, -77.04)
	var rich := world.province_near(48.86, 2.35)
	check(economy._entry(lima).admin < economy._entry(rich).admin or lima.development >= 5, "a frontier province is cheaper to run")
	var outpost := world.province_near(23.61, 58.59)  # Muscat
	if "fort" in outpost.buildings and outpost.development < 5:
		check(economy._entry(outpost).forts < Buildings.CATALOGUE.fort.upkeep, "an outpost's fort costs less")
