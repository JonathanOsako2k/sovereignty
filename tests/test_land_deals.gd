extends "res://tests/test_case.gd"
## Buying and trading land: what land is worth; what makes a country part with
## it (money, land hard for it to govern, its finances) or keep it (land that
## matters to it, rivalry); what cannot be offered; deals carried out.


func _setup() -> Array:  # [campaign, land deals]
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	var c := Campaign.new(world)
	var economy := EconomySystem.new(c)
	return [c, LandDeals.new(c, economy, DiplomacyActions.new(c))]


func test_buying_land() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var deals: LandDeals = s[1]
	var w := c.world
	var oran := w.province_near(35.7, -0.63)
	var toledo := w.province_near(39.86, -4.02)
	check(oran.owner_id == "SPA" and toledo.owner_id == "SPA", "Oran and Toledo are Spain's")
	check(w.overseas.has(oran.id), "Oran is overseas")
	check(deals.access(oran, "SPA") < deals.access(toledo, "SPA"), "Madrid reaches Oran, an exclave over the sea, worse than Toledo")
	var hard := func(p: Province) -> int:
		for r: Array in deals.evaluate("AUS", "SPA", {"take": [p.id], "money": 0}).reasons:
			if r[0] == "Hard for them to govern":
				return r[1]
		return 0
	check(hard.call(oran) > hard.call(toledo) + 20, "so it is far harder for them to govern (%d vs %d)" % [
		hard.call(oran), hard.call(toledo)])
	w.get_country("AUS").treasury = 5000.0
	var at_worth := func(p: Province, factor := 1.0) -> Dictionary:
		return {"take": [p.id], "money": int(deals.worth(p) * factor)}
	check(deals.worth(oran) > 0.0 and deals.worth(toledo) > 0.0, "land has a worth")
	var oran_v := deals.evaluate("AUS", "SPA", at_worth.call(oran))
	var toledo_v := deals.evaluate("AUS", "SPA", at_worth.call(toledo))
	check(oran_v.total > toledo_v.total, "a far outpost goes more easily than a core by the capital (%d vs %d)" % [
		oran_v.total, toledo_v.total])
	check(deals.evaluate("AUS", "SPA", at_worth.call(oran, 2.0)).total > oran_v.total, "more money, more willing")
	# Spain short of money is keener.
	var spain := w.get_country("SPA")
	var rich: int = deals.evaluate("AUS", "SPA", at_worth.call(oran)).total
	spain.treasury = -100.0
	check(deals.evaluate("AUS", "SPA", at_worth.call(oran)).total > rich, "in want of money, keener to sell")
	spain.treasury = 500.0
	# What cannot be offered.
	check(deals.blocked("AUS", "SPA", {"take": [spain.capital_province_id], "money": 10}).contains("capital"), "never their capital")
	check(deals.blocked("AUS", "SPA", {"take": [w.province_near(48.86, 2.35).id], "money": 10}) != "", "only their land")
	check(deals.blocked("AUS", "SPA", {"take": [oran.id], "money": 999999}).begins_with("We have only"), "only money we have")
	# A sale.
	# A rival is refused whatever it pays.
	w.get_country("FRA").treasury = 5000.0
	var rival := deals.evaluate("FRA", "SPA", at_worth.call(oran, 2.0))
	check(rival.reasons.any(func(r: Array) -> bool: return r[0] == "We are their rival") and not rival.accept,
		"France, Spain's rival, is refused (%+d)" % rival.total)
	# Toledo, by Madrid, from an ally: not at its worth, but at twice.
	check(not deals.evaluate("AUS", "SPA", at_worth.call(toledo)).accept, "the heartland not at its worth")
	var deal: Dictionary = at_worth.call(oran, 2.0)
	var v := deals.evaluate("AUS", "SPA", deal)
	check(v.accept, "Oran at twice its worth: accepted (%+d)" % v.total)
	var before := spain.treasury
	var result := deals.propose("AUS", "SPA", deal)
	check(result.accepted, result.message)
	check_eq(oran.owner_id, "AUS", "Oran is Austria's")
	check_eq(spain.treasury, before + deal.money, "Spain is paid")
	check(not w.claims.is_core("SPA", oran.id), "Spain renounces its core")


func test_paying_over_the_worth_tempts_less_and_less() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var deals: LandDeals = s[1]
	var w := c.world
	var toledo := w.province_near(39.86, -4.02)
	w.get_country("AUS").treasury = 10000000.0
	var worth := deals.worth(toledo)
	var points := func(money: float) -> int:
		for r: Array in deals.evaluate("AUS", "SPA", {"take": [toledo.id], "money": int(ceil(money))}).reasons:
			if r[0] == "Our price against what it is worth to them":
				return r[1]
		return 0
	check_eq(points.call(worth), 0, "at its worth, nothing either way")
	check(points.call(worth * 0.5) < -20, "well short of its worth: a poor offer (%d)" % points.call(worth * 0.5))
	check(points.call(worth + 10.0) <= 1, "ten ducats more barely count (%d)" % points.call(worth + 10.0))
	var once: int = points.call(worth * 2.0)
	var twice: int = points.call(worth * 3.0)
	check(once > 0 and twice - once < once, "each ducat more tempts them less (%d, %d)" % [once, twice])
	check(points.call(worth * 100.0) <= int(LandDeals.PREMIUM_CAP), "and never past the cap")
	# In want of money, a token sum does not buy their need.
	var spain := w.get_country("SPA")
	spain.treasury = -100.0
	var need := func(money: int) -> int:
		for r: Array in deals.evaluate("AUS", "SPA", {"take": [toledo.id], "money": money}).reasons:
			if r[0] == "Their finances":
				return r[1]
		return 0
	check(need.call(10) < need.call(int(worth * 3.0)), "a token sum relieves their want less (%d vs %d)" % [
		need.call(10), need.call(int(worth * 3.0))])


func test_exchanging_land() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var deals: LandDeals = s[1]
	var w := c.world
	# Land is worth more to a country with a core there.
	var calais := w.province_near(50.95, 1.86)
	check(deals.worth_to(calais, "ENG") > deals.worth_to(calais, "SCO"), "Calais is worth more to England (its core)")
	# Austria gives a province of its own for one of Spain's; money evens it out.
	var oran := w.province_near(35.7, -0.63)
	var graz := w.province_near(47.07, 15.44)
	check_eq(graz.owner_id, "AUS", "Graz is Austria's")
	w.get_country("AUS").treasury = 5000.0
	var deal := {"take": [oran.id], "give": [graz.id], "money": 0}
	check_eq(deals.blocked("AUS", "SPA", deal), "", "an exchange can be offered")
	check(deals.evaluate("AUS", "SPA", deal).offered > 0.0, "Graz is worth something to Spain")
	var gap: float = deals.evaluate("AUS", "SPA", deal).worth - deals.worth_to(graz, "SPA")
	deal.money = maxi(0, int(gap * 2.0) + 50)
	var v := deals.evaluate("AUS", "SPA", deal)
	check(v.accept, "with money to spare: accepted (%+d)" % v.total)
	check(deals.propose("AUS", "SPA", deal).accepted, "done")
	check(oran.owner_id == "AUS" and graz.owner_id == "SPA", "the land changes hands")
	# They may pay us too, within their treasury.
	var asks := {"take": [], "give": [w.province_near(48.2, 16.37).id], "money": -999999}
	check(deals.blocked("AUS", "SPA", asks).begins_with("They have only") or deals.blocked("AUS", "SPA", asks).contains("capital"),
		"only money they have")
	# No deals with an enemy.
	c.world.military.add_war({"id": 99, "name": "Test", "attackers": ["AUS"], "defenders": ["SPA"], "start": 0,
		"battle_score": 0.0, "refused": []})
	check(deals.blocked("AUS", "SPA", deal).contains("war"), "not at war")


func test_selling_land() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var deals: LandDeals = s[1]
	var w := c.world
	var border := w.province_near(55.2, -1.9)  # Northumberland
	var cornwall := w.province_near(50.3, -4.9)
	check(border.owner_id == "ENG" and cornwall.owner_id == "ENG", "English land")
	w.get_country("SCO").treasury = 2000.0
	var value := deals.worth_to(border, "SCO")
	var cheap := {"give": [border.id], "money": -int(value * 0.5)}
	var dear := {"give": [border.id], "money": -int(value * 1.5)}
	check_eq(deals.blocked("ENG", "SCO", cheap), "", "a sale can be offered")
	check(deals.evaluate("ENG", "SCO", cheap).total > deals.evaluate("ENG", "SCO", dear).total, "cheaper, more willing")
	var fit := func(deal: Dictionary) -> int:
		for r: Array in deals.evaluate("ENG", "SCO", deal).reasons:
			if r[0] == "How our land fits their realm":
				return r[1]
		return 0
	check(fit.call(cheap) > fit.call({"give": [cornwall.id], "money": -10}), "land beside theirs fits better than land far off")
	check(deals.blocked("ENG", "SCO", {"give": [border.id], "money": -999999}).begins_with("They have only"),
		"no more than they have")
	# A bargain is taken.
	var bargain := {"give": [border.id], "money": -10}
	var v := deals.evaluate("ENG", "SCO", bargain)
	check(v.accept, "a bargain is taken (%+d: %s)" % [v.total, str(v.reasons)])
	var before := w.get_country("ENG").treasury
	check(deals.propose("ENG", "SCO", bargain).accepted, "sold")
	check_eq(border.owner_id, "SCO", "Scotland's now")
	check_eq(w.get_country("ENG").treasury, before + 10.0, "England is paid")
