extends "res://tests/test_case.gd"
## Colonisation: policies, access (frontier, strait, overseas), the land,
## climate, natives and disease, founding, progress, completion, upkeep,
## uprisings, saving, and what the AI does (and must not do) over decades.


func _setup() -> Array:  # [campaign, economy, colonisation]
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	var c := Campaign.new(world)
	var economy := EconomySystem.new(c)
	return [c, economy, ColonisationSystem.new(c, economy)]


## Free land beside `tag`'s provinces (optionally only inland or in the disease zone).
func _frontier(c: Campaign, tag: String, filter := Callable()) -> Province:
	for p: Province in c.world.ownable_provinces():
		if p.owner_id != "" or (filter.is_valid() and not filter.call(p)):
			continue
		for n: int in p.neighbour_ids:
			if c.world.get_province(n).owner_id == tag:
				return p
	return null


func test_1590_colonial_policies() -> void:
	var c: Campaign = _setup()[0]
	check_eq(c.world.get_country("SPA").colonial_policy, 3, "Spain: a colonial empire")
	check_eq(c.world.get_country("POR").colonial_policy, 3, "Portugal: a colonial empire")
	check_eq(c.world.get_country("ENG").colonial_policy, 2, "England: overseas ventures")
	check_eq(c.world.get_country("RUS").colonial_policy, 1, "Russia: the frontier")
	check_eq(c.world.get_country("KON").colonial_policy, 0, "Kongo: none yet")


func test_russia_settles_siberia_readily() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var col: ColonisationSystem = s[2]
	# The best of the free land east of Russia's border.
	var p: Province = null
	for q: Province in c.world.ownable_provinces():
		if q.owner_id != "" or q.lon <= 55.0 or col.access("RUS", q).kind != "frontier":
			continue
		if p == null or col.months_to_settle("RUS", q) < col.months_to_settle("RUS", p):
			p = q
	check(p != null, "free land east of Russia")
	if p == null:
		return
	check_eq(col.blocked("RUS", p), "", "Russia may settle %s" % p.name)
	var r := col.rate("RUS", p)
	check_eq(r.access.kind, "frontier", "on the frontier")
	check(r.factors.any(func(f: Array) -> bool: return f[0] == "Cossack frontier" and f[1] > 1.0), "the Cossack frontier speeds it")
	check(Colonisation.familiarity(p, col.home_climates("RUS")) >= 0.85, "a climate Russians know")
	check(col.months_to_settle("RUS", p) <= 72, "within six years (%d months)" % col.months_to_settle("RUS", p))


func test_disease_closes_the_african_interior_until_quinine() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var col: ColonisationSystem = s[2]
	var african_interior := func(q: Province) -> bool:
		return Colonisation.in_disease_zone(q) and not q.is_coastal and q.lon > -18.0 and q.lon < 52.0
	var inland := _frontier(c, "", african_interior)
	check(inland != null, "free land in tropical Africa's interior")
	if inland == null:
		return
	var europe := col.home_climates("POR")
	var kongo := col.home_climates("KON")
	check(not Colonisation.seasoned(europe), "the Portuguese are not at home in the tropics")
	check(Colonisation.seasoned(kongo), "the Kongolese are")
	check_eq(Colonisation.disease_factor(inland, false, 1600), 0.0, "closed in 1600")
	check_eq(Colonisation.disease_factor(inland, false, 1860), 0.4, "quinine opens it a little")
	check_eq(Colonisation.disease_factor(inland, false, 1890), 0.8, "railways and medicine more")
	check_eq(Colonisation.disease_factor(inland, true, 1600), 1.0, "no barrier for Africans")
	# Even beside a Portuguese province, the interior stays closed.
	c.world.transfer_province(inland.neighbour_ids[0], "POR")
	check(col.blocked("POR", inland).begins_with("Disease"), "blocked by disease: %s" % col.blocked("POR", inland))
	var coast := _frontier(c, "", func(q: Province) -> bool: return Colonisation.in_disease_zone(q) and q.is_coastal)
	check(coast != null and Colonisation.disease_factor(coast, false, 1600) == 0.3, "coasts only slowly")


func test_an_african_kingdom_expands_once_it_has_the_idea() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var col: ColonisationSystem = s[2]
	var kongo := c.world.get_country("KON")
	var p := _frontier(c, "KON")
	check(p != null, "free land beside Kongo")
	if p == null:
		return
	check(col.blocked("KON", p).begins_with("Needs a colonial policy"), "no policy, no settlers")
	kongo.colonial_policy = 1
	kongo.treasury = 200.0
	check_eq(col.blocked("KON", p), "", "with frontier settlement Kongo may settle %s" % p.name)
	check(Colonisation.disease_factor(p, Colonisation.seasoned(col.home_climates("KON")), c.clock.year) == 1.0, "no disease for Kongo")
	check(col.found_colony("KON", p), "founded")
	var natives := p.population
	var done := []
	col.colony_completed.connect(func(id, tag): done.append([id, tag]))
	for i in 600:
		col.monthly()
		if not done.is_empty():
			break
	check_eq(done, [[p.id, "KON"]], "the colony stands")
	check_eq(p.owner_id, "KON", "Kongo owns %s" % p.name)
	check_eq(p.colonist, "", "no longer a colony")
	check_eq(p.pops.tribesmen, natives, "the natives stay, as tribesmen")
	var settlers := 0
	for role: String in Colonisation.SETTLERS:
		settlers += Colonisation.SETTLERS[role]
	check_eq(p.population, natives + settlers, "and settlers arrive")


func test_overseas_needs_the_policy() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var col: ColonisationSystem = s[2]
	var virginia: Province = null
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "" and p.is_coastal and p.lat > 36.0 and p.lat < 39.0 and p.lon > -78.0 and p.lon < -74.0:
			virginia = p
	check(virginia != null, "free coast in Virginia")
	if virginia == null:
		return
	var a := col.access("ENG", virginia)
	check_eq(a.kind, "overseas", "across the Atlantic")
	check(a.seas > 3, "several seas away (%d)" % a.seas)
	check_eq(col.blocked("ENG", virginia), "", "England may send settlers")
	c.world.get_country("ENG").colonial_policy = 1
	check(col.blocked("ENG", virginia).begins_with("Across the sea"), "not with frontier settlement only")


func test_colonies_cost_money_and_colonists() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var economy: EconomySystem = s[1]
	var col: ColonisationSystem = s[2]
	var eng := c.world.get_country("ENG")
	eng.treasury = 1000.0
	var free: Array[Province] = []
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "" and col.blocked("ENG", p) == "":
			free.append(p)
		if free.size() == 3:
			break
	check_eq(free.size(), 3, "three places England could settle")
	if free.size() < 3:
		return
	var cost := col.founding_cost("ENG", free[0])
	check(col.found_colony("ENG", free[0]), "first colony")
	check(is_equal_approx(eng.treasury, 1000.0 - cost), "paid for")
	check(eng.ledger.any(func(e: Array) -> bool: return e[0] == ColonisationSystem.FOUNDED % free[0].name), "named in the ledger")
	check(col.found_colony("ENG", free[1]), "second colony")
	check(col.blocked("ENG", free[2]).begins_with("All our colonists are busy"), "two at once with overseas ventures")
	var upkeep := 0.0
	for l: Array in economy.budget("ENG").expenses:
		if l[0] == EconomySystem.COLONIES:
			upkeep = l[1]
	check(is_equal_approx(upkeep, Colonisation.POLICY_UPKEEP[2] + 2 * Colonisation.COLONY_UPKEEP), "upkeep %f" % upkeep)
	check(col.abandon("ENG", free[1]), "abandon one")
	check_eq(col.blocked("ENG", free[2]), "", "a colonist free again")


func test_natives_rise_against_settlers() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var col: ColonisationSystem = s[2]
	var p := _frontier(c, "RUS")
	p.add_people("tribesmen", 500000)
	p.colonist = "RUS"
	p.colony_progress = 50.0
	var risings := []
	col.uprising.connect(func(id, _tag): risings.append(id))
	for i in 200:
		if p.colonist == "":
			break
		col.monthly()
	check(not risings.is_empty(), "many natives rise now and then")
	check(Colonisation.native_factor(500000) < Colonisation.native_factor(5000), "and slow the settlers")


func test_colonies_survive_save_and_load() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var col: ColonisationSystem = s[2]
	var p := _frontier(c, "RUS")
	check(col.found_colony("RUS", p), "founded")
	col.monthly()
	c.world.get_country("KON").colonial_policy = 1
	var copy: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict(), "", false, true))
	var b: Campaign = _setup()[0]
	check(b.restore(copy).is_empty(), "restore")
	var q := b.world.get_province(p.id)
	check_eq(q.colonist, "RUS", "colonist")
	check_eq(q.colony_progress, p.colony_progress, "progress")
	check_eq(b.world.get_country("KON").colonial_policy, 1, "policy")
	# A format 5 save gets the scenario's policies and no colonies.
	var old: Dictionary = copy.duplicate(true)
	var data := {"campaign": old}
	for tag: String in old.world.countries:
		old.world.countries[tag].policies.erase("colonial")
	old.world.province_fields = old.world.province_fields.slice(0, 10)
	for row: Array in old.world.provinces:
		row.resize(11)
	SaveService._upgrade_5_to_6(data)
	check(b.restore(old).is_empty(), "upgraded format 5 restores")
	check_eq(b.world.get_country("KON").colonial_policy, 0, "scenario policy for Kongo")
	check_eq(b.world.get_country("SPA").colonial_policy, 3, "and Spain")
	check_eq(b.world.get_province(p.id).colonist, "", "no colonies")


## Two decades of AI colonisation: land gets settled, but no country from
## cooler lands takes tropical Africa's interior.
func test_ai_settles_but_leaves_the_african_interior() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var col: ColonisationSystem = s[2]
	var free_at_start := {}
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "":
			free_at_start[p.id] = true
	for year in 20:
		for country: Country in c.world.countries.values():
			country.treasury = maxf(country.treasury, 300.0)
		col.ai_yearly("")
		for month in 12:
			col.monthly()
			col.ai_monthly("")
	var settled := 0
	for id: int in free_at_start:
		var p := c.world.get_province(id)
		if p.owner_id == "":
			continue
		settled += 1
		if Colonisation.in_disease_zone(p) and not p.is_coastal and p.lon > -18.0 and p.lon < 52.0:
			check(Colonisation.seasoned(col.home_climates(p.owner_id)),
				"%s took %s in Africa's interior" % [p.owner_id, p.name])
	check(settled >= 20, "%d provinces settled in 20 years" % settled)
	check(settled < 400, "but not the whole world (%d)" % settled)
