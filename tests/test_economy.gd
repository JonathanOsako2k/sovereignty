extends "res://tests/test_case.gd"
## Economy (M5): people by estate, goods and production, buildings and
## manufactories, estate taxes and policies, minting and inflation, budgets and
## the ledger, loans and bankruptcy, discoveries, tribute, occupation, saving.


func _campaign() -> Campaign:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	return Campaign.new(world)


var _ids: Image


## The province under a point on the map (what a tap there would pick).
func _at(c: Campaign, lat: float, lon: float) -> Province:
	if _ids == null:
		_ids = MapView._load_image(c.world.id_texture_path)
	return c.world.get_province(MapView.decode_id(_ids.get_pixelv(Vector2i(c.world.latlon_to_map(lat, lon)))))


func _line(lines: Array, label: String) -> float:
	for l: Array in lines:
		if l[0] == label:
			return l[1]
	return 0.0


func _commoner_taxes(lines: Array) -> float:
	return _line(lines, EconomySystem.TAXES % Estates.display("commoners"))


# --- People and goods -------------------------------------------------------------------

func test_people_divide_into_estates() -> void:
	var c := _campaign()
	for p: Province in c.world.ownable_provinces():
		var sum := 0
		for r: String in p.pops:
			check(r in Estates.ROLES, "%s: known role %s" % [p.name, r])
			sum += p.pops[r]
		if sum != p.population:
			failures.append("%s: estates add up to %d, not %d" % [p.name, sum, p.population])
			return
	var paris := _at(c, 48.86, 2.35)
	for r: String in ["nobility", "clergy", "merchants", "commoners"]:
		check(paris.pops.get(r, 0) > 0, "Paris has %s" % r)
	check(paris.pops.commoners > paris.pops.nobility * 10, "commoners far outnumber nobles")
	var unowned := 0
	var tribal := 0
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "" and p.population > 1000:
			unowned += 1
			if p.pops.get("tribesmen", 0) > p.population * 0.9:
				tribal += 1
	check(unowned > 0 and tribal == unowned, "uncolonised land is tribal (%d of %d)" % [tribal, unowned])


func test_every_province_produces_a_good() -> void:
	var c := _campaign()
	var goods := {}
	for p: Province in c.world.ownable_provinces():
		if not Goods.is_raw(p.resource):
			failures.append("%s produces %s" % [p.name, p.resource])
			return
		goods[p.resource] = goods.get(p.resource, 0) + 1
	for g: String in ["grain", "livestock", "wine", "wool", "fish", "timber", "silver", "gold", "spices", "sugar", "iron", "salt"]:
		check(goods.has(g), "someone produces %s" % g)
	check(not goods.has("petroleum") and not goods.has("uranium"), "nothing modern in 1590")
	check_eq(_at(c, -19.58, -65.75).resource, "silver", "Potosí")
	check_eq(_at(c, 29.27, 117.18).resource, "kaolin", "Jingdezhen")
	check_eq(_at(c, -6.10, 106.10).resource, "spices", "Banten")


func test_hidden_deposits_wait_for_their_age() -> void:
	var c := _campaign()
	var found := {}
	for p: Province in c.world.provinces.values():
		for d: Array in p.deposits:
			found[d[0]] = mini(found.get(d[0], 9999), d[1])
	for g: String in ["gold", "silver", "coal", "petroleum", "rare_earths", "uranium"]:
		check(found.has(g), "%s waits to be found" % g)
	check(found.get("petroleum", 0) >= 1840, "no oil age before the 1840s")
	check(found.get("uranium", 0) >= 1890, "no uranium before the 1890s")


func test_production_follows_workers_land_and_buildings() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var potosi := _at(c, -19.58, -65.75)
	check("mine" in potosi.buildings, "Potosí's mines are worked in 1590")
	var out := e.production(potosi)
	var product := 1.0
	for f: Array in out.factors:
		product *= f[1]
	check(is_equal_approx(out.raw_units, product), "output is the product of its named factors")
	check(is_equal_approx(out.value, out.raw_units * Goods.price_of("silver") * EconomySystem.VALUE_SCALE), "valued at the silver price")
	potosi.buildings.erase("mine")
	e.invalidate()  # changed by hand, not through the economy
	var without: float = e.production(potosi).raw_units
	check(is_equal_approx(out.raw_units, without * 1.5), "the mine adds half again")
	potosi.unrest = 50.0
	e.invalidate()  # changed by hand, not through the economy
	check(e.production(potosi).raw_units < without, "unrest costs output")
	var farm := _at(c, 48.86, 2.35)
	check(EconomySystem.VEGETATION_YIELD.farmland > EconomySystem.VEGETATION_YIELD.desert, "farmland out-yields desert")
	check(e.production(farm).value > 0.0, "Paris produces")


func test_manufactories_make_goods() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var jingdezhen := _at(c, 29.27, 117.18)
	check("kilns" in jingdezhen.buildings, "Jingdezhen's kilns")
	var out := e.production(jingdezhen)
	check_eq(out.made_good, "porcelain", "kilns make porcelain")
	check(out.made_units > 0.0, "and some each month")
	var ghent := _at(c, 51.05, 3.72)
	check_eq(e.production(ghent).made_good, "cloth", "Flemish weaveries make cloth")
	# Taking the kilns away leaves twice the raw kaolin but less value.
	var merchants: float = e.estate_incomes(jingdezhen, out.value).merchants
	jingdezhen.buildings.erase("kilns")
	e.invalidate()  # changed by hand, not through the economy
	var raw := e.production(jingdezhen)
	check(is_equal_approx(raw.raw_units, out.raw_units * 2.0), "half the kaolin goes to the kilns")
	check(raw.value < out.value, "porcelain is worth more than its kaolin")
	check(e.estate_incomes(jingdezhen, out.value).merchants < merchants, "manufactories enrich merchants")


func test_buildings_are_paid_for_and_built() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var eng := c.world.get_country("ENG")
	var london := _at(c, 51.51, -0.13)
	var paris := _at(c, 48.86, 2.35)
	check(e.build_blocked("ENG", "marketplace", paris) != "", "not in someone else's province")
	check(e.build_blocked("ENG", "marketplace", london) != "", "not twice")
	var inland: Province = null
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "ENG" and not p.is_coastal:
			inland = p
			break
	check(inland != null and e.build_blocked("ENG", "fishing_harbour", inland) != "", "no harbour inland")
	check_eq(e.build_blocked("ENG", "fort", london), "Already built", "London has its walls from 1590")
	# A fort for an English town without one.
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "ENG" and not "fort" in p.buildings and p.construction.is_empty():
			london = p
			break
	eng.treasury = 1000.0
	check_eq(e.build_blocked("ENG", "fort", london), "", "a fort can be built")
	check(e.start_building("ENG", "fort", london), "started")
	check(is_equal_approx(eng.treasury, 1000.0 - Buildings.CATALOGUE.fort.cost), "paid up front")
	check(_line(eng.ledger, EconomySystem.CONSTRUCTION % "Fort") < 0.0, "named in the ledger")
	check(e.build_blocked("ENG", "farm_estates", london) != "", "one at a time")
	var fort_upkeep := _line(e.budget("ENG").expenses, EconomySystem.FORTS)
	for i in Buildings.CATALOGUE.fort.months:
		e.monthly()
	check("fort" in london.buildings, "the fort stands after %d months" % Buildings.CATALOGUE.fort.months)
	check(london.construction.is_empty(), "work done")
	check(_line(e.budget("ENG").expenses, EconomySystem.FORTS) > fort_upkeep, "and costs upkeep")


func test_ai_builds_with_spare_money() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var fra := c.world.get_country("FRA")
	fra.treasury = 5000.0
	e.ai_construction("ENG")
	var building := 0
	for p: Province in c.world.ownable_provinces():
		if p.owner_id == "FRA" and not p.construction.is_empty():
			building += 1
	check_eq(building, 1, "France puts its money into one building")


# --- Budget and policies ---------------------------------------------------------------------

func test_budget_lines_are_named_and_add_up() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var b := e.budget("ENG")
	var sum := 0.0
	for l: Array in b.income:
		sum += l[1]
	for l: Array in b.expenses:
		sum -= l[1]
	check(is_equal_approx(b.net, sum), "net is income minus expenses")
	check(_commoner_taxes(b.income) > 0.0, "England taxes its commoners")
	check(_line(b.income, EconomySystem.TAXES % Estates.display("nobility")) > 0.0, "and its nobles")
	check_eq(_line(b.income, EconomySystem.TAXES % Estates.display("clergy")), 0.0, "but not the clergy")
	check(_line(b.expenses, EconomySystem.ADMIN) > 0.0, "and pays to run its provinces")
	check(_line(b.expenses, EconomySystem.COURT) > 0.0, "and its court")
	check(_line(b.expenses, EconomySystem.ARMY) > 0.0, "and its army")
	check(_line(b.expenses, EconomySystem.NAVY) > 0.0, "and its navy")


func test_surplus_and_deficit_both_happen() -> void:
	var c := _campaign()
	var all := EconomySystem.new(c).budgets()
	var surplus := 0
	var deficit := 0
	for tag: String in all:
		if c.world.country_stats(tag).provinces == 0:
			continue
		if all[tag].net >= 0.0:
			surplus += 1
		else:
			deficit += 1
	check(surplus > 20 and deficit > 5, "surpluses (%d) and deficits (%d)" % [surplus, deficit])


func test_tax_rates_trade_money_for_goodwill() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var eng := c.world.get_country("ENG")
	var normal := _commoner_taxes(e.budget("ENG").income)
	var calm := e.satisfaction_target(eng, 3)
	check_eq(eng.tax_rates, [20, 0, 20, 20, 8], "taxed at custom")
	eng.tax_rates[3] = 30
	e.invalidate()  # changed by hand, not through the economy
	check(is_equal_approx(_commoner_taxes(e.budget("ENG").income), normal * 1.5), "30 % brings half again what 20 % did")
	check(e.satisfaction_target(eng, 3) < calm, "and the commoners mind")
	var before: float = eng.satisfaction[3]
	e.monthly()
	check(eng.satisfaction[3] < before, "goodwill slips month by month")
	eng.tax_rates[3] = 0
	e.invalidate()  # changed by hand, not through the economy
	check_eq(_commoner_taxes(e.budget("ENG").income), 0.0, "no tax, no income")
	# Taxes are proportional: every taxed estate gives the same share of its income.
	var london := _at(c, 51.51, -0.13)
	var incomes := e.estate_incomes(london, e.production(london).value)
	var taxes := e.province_taxes(london)
	check(is_equal_approx(taxes.nobility / incomes.nobility, taxes.merchants / incomes.merchants), "nobles pay as merchants do")
	check(taxes.nobility > 0.0 and incomes.nobility > 0.0, "and more where they earn more")
	eng.tax_rates[1] = 40
	e.invalidate()  # changed by hand, not through the economy
	check_eq(taxes.clergy, 0.0, "the clergy are exempt")
	check_eq(e.satisfaction_target(eng, 1), EconomySystem.SATISFACTION_BASE, "and untroubled by tax levels")
	# Unhappy commoners stir unrest, which costs output.
	eng.tax_rates[3] = Estates.TAX_MAX.commoners
	eng.satisfaction[3] = 0.0
	e.invalidate()  # changed by hand, not through the economy
	e.monthly()
	check(london.unrest > 0.0, "unrest rises (%f)" % london.unrest)


func test_minting_brings_coin_and_inflation() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var eng := c.world.get_country("ENG")
	var admin := _line(e.budget("ENG").expenses, EconomySystem.ADMIN)
	eng.spending.mint = 10
	e.invalidate()  # changed by hand, not through the economy
	var b := e.budget("ENG")
	check(is_equal_approx(_line(b.income, EconomySystem.MINTING), b.tax_income * 0.10), "minting 10 %% adds a tenth of tax income")
	for i in 10:
		e.monthly()
	check(is_equal_approx(eng.inflation, 10 * Policies.mint_inflation(10)), "and inflation (%f)" % eng.inflation)
	check(is_equal_approx(_line(e.budget("ENG").expenses, EconomySystem.ADMIN), admin * (1.0 + eng.inflation / 100.0)), "costs rise with prices")
	check(e.satisfaction_target(eng, 2) < EconomySystem.SATISFACTION_BASE, "merchants dislike inflation")
	eng.spending.mint = 0
	e.invalidate()  # changed by hand, not through the economy
	var high := eng.inflation
	e.monthly()
	check(eng.inflation < high, "inflation eases without minting")


func test_court_spending_buys_legitimacy() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var eng := c.world.get_country("ENG")
	var court := _line(e.budget("ENG").expenses, EconomySystem.COURT)
	eng.spending.court = 240
	e.invalidate()  # changed by hand, not through the economy
	check(is_equal_approx(_line(e.budget("ENG").expenses, EconomySystem.COURT), court * 2.4), "a lavish court (240 %%) costs 2.4 times as much")
	eng.legitimacy = 50.0
	e.monthly()
	check(eng.legitimacy > 50.0, "and raises legitimacy")
	check(e.satisfaction_target(eng, 0) > EconomySystem.SATISFACTION_BASE, "and pleases the nobles")


## A country borrowing mid-month (which invalidates the budgets) must not cut
## the month short for the countries after it.
func test_every_country_keeps_its_accounts_when_one_borrows() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var first: String = c.world.country_order[0]
	c.world.get_country(first).treasury = -500.0
	e.monthly()
	for tag: String in c.world.country_order:
		if c.world.country_stats(tag).provinces > 0:
			check(not c.world.get_country(tag).ledger.is_empty(), "%s kept its month" % tag)
			if c.world.get_country(tag).ledger.is_empty():
				return


func test_month_moves_treasury_by_the_ledger() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var eng := c.world.get_country("ENG")
	var before := eng.treasury
	var net: float = e.budget("ENG").net
	e.monthly()
	check(absf(eng.treasury - (before + net)) < 0.05, "treasury moved by the budget")
	var sum := 0.0
	for entry: Array in eng.ledger:
		check(entry[0] is String and entry[0] != "", "every entry has a source")
		sum += entry[1]
	check(absf(eng.treasury - (before + sum)) < 0.01, "and every ducat is in the ledger")


# --- Loans and bankruptcy ----------------------------------------------------------------------

func test_loans_carry_interest_and_can_be_repaid() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var eng := c.world.get_country("ENG")
	var treasury := eng.treasury
	var rate := e.interest_rate("ENG")
	check(rate >= EconomySystem.BASE_RATE, "credit costs at least the base rate")
	check(e.take_loan("ENG"), "borrow")
	check_eq(eng.loans.size(), 1, "one loan")
	check_eq(eng.debt, EconomySystem.LOAN_SIZE, "debt recorded")
	check_eq(eng.loans[0][1], rate, "at the quoted rate")
	check_eq(eng.treasury, treasury + EconomySystem.LOAN_SIZE, "money received")
	check(e.interest_rate("ENG") > rate, "more debt, dearer credit")
	e.take_loan("ENG")
	var interest := _line(e.budget("ENG").expenses, EconomySystem.INTEREST)
	check(is_equal_approx(interest, (eng.loans[0][0] * eng.loans[0][1] + eng.loans[1][0] * eng.loans[1][1]) / 12.0), "monthly interest %f" % interest)
	check(e.repay_loan("ENG", 1), "repay the second")
	check_eq(eng.loans.size(), 1, "one left")
	eng.treasury = 10.0
	check(e.repay_blocked("ENG", 0) != "", "repaying needs the money")
	check(e.repay_blocked("ENG", 5) != "", "no such loan")
	# Running dry borrows instead of going negative.
	eng.treasury = -30.0 - maxf(e.budget("ENG").net, 0.0) - 50.0
	e.monthly()
	check(eng.treasury >= 0.0, "a deficit is covered by a loan (treasury %f)" % eng.treasury)
	check(eng.loans.size() > 1, "and the loans show it")
	check(eng.ledger.any(func(x: Array) -> bool: return x[0] == EconomySystem.LOAN), "named in the ledger")


func test_lenders_have_limits() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var limit := e.credit_limit("ENG")
	check(limit >= EconomySystem.MIN_CREDIT, "some credit for everyone")
	var n := 0
	while e.take_loan("ENG"):
		n += 1
		if n > 1000:
			break
	var eng := c.world.get_country("ENG")
	check(eng.debt <= limit and eng.debt + EconomySystem.LOAN_SIZE > limit, "borrowed up to the limit (%f of %f)" % [eng.debt, limit])
	check(e.loan_blocked("ENG") != "", "then no more")
	check(e.interest_rate("ENG") <= EconomySystem.MAX_RATE, "rates have a ceiling")


func test_bankruptcy_wipes_debt_at_a_price() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var eng := c.world.get_country("ENG")
	var rate := e.interest_rate("ENG")
	for i in 3:
		e.take_loan("ENG")
	eng.legitimacy = 80.0
	var merchants: float = eng.satisfaction[2]
	var bankrupt := []
	e.went_bankrupt.connect(func(tag): bankrupt.append(tag))
	e.declare_bankruptcy("ENG")
	check_eq(eng.loans, [], "debts repudiated")
	check_eq(bankrupt, ["ENG"], "announced")
	check(eng.legitimacy < 80.0, "the crown loses face")
	check(eng.satisfaction[2] < merchants, "and the merchants their faith")
	check(e.loan_blocked("ENG") != "", "no credit for years")
	check(eng.ledger.any(func(x: Array) -> bool: return x[0].begins_with("Bankruptcy")), "in the ledger")
	c.clock.set_date(1596, 1, 2)
	check_eq(e.loan_blocked("ENG"), "", "lenders return after five years")
	check(e.interest_rate("ENG") > rate, "but charge more")


func test_deficit_without_credit_ends_in_bankruptcy() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var eng := c.world.get_country("ENG")
	while e.take_loan("ENG"):
		pass
	eng.treasury = -500.0
	e.monthly()
	check_eq(eng.loans, [], "bankrupt: no loans left")
	check(eng.treasury >= 0.0, "unpaid bills written off")
	check(eng.bankrupt_until > c.clock.day_number(), "shut out of credit")


func test_ai_repays_when_rich() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var fra := c.world.get_country("FRA")
	e.take_loan("FRA")
	fra.treasury = 1000.0
	e.ai_repayments("ENG")
	check_eq(fra.loans, [], "France pays its loan back")


# --- Discoveries --------------------------------------------------------------------------

func test_deposits_are_discovered_in_their_time() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var site: Province = null
	var deposit: Array
	for p: Province in c.world.ownable_provinces():
		for d: Array in p.deposits:
			if d[0] == "petroleum":
				site = p
				deposit = d
				break
		if site != null:
			break
	check(site != null, "an oil field waits")
	if site == null:
		return
	deposit[2] = 1.0  # certain once its time has come
	var heard := []
	e.discovered.connect(func(id, good): heard.append([id, good]))
	c.clock.set_date(deposit[1] - 1, 1, 1)
	e.yearly()
	check(site.found.is_empty() or not "petroleum" in site.found, "not before its year")
	c.clock.set_date(deposit[1], 1, 1)
	e.yearly()
	check("petroleum" in site.found, "found in %d" % deposit[1])
	check_eq(site.resource, "petroleum", "and worked from then on")
	check(heard.has([site.id, "petroleum"]), "announced")
	e.yearly()
	check_eq(heard.count([site.id, "petroleum"]), 1, "found once")


# --- Subjects and occupation ----------------------------------------------------------------

func test_tribute_flows_from_subject_to_overlord() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var all := e.budgets()
	var paid := _line(all["TKG"].expenses, EconomySystem.TRIBUTE_OUT)
	check(paid > 0.0, "Tokugawa pays tribute")
	var received := _line(all["JAP"].income, EconomySystem.TRIBUTE_IN)
	var total_paid := 0.0
	for s in c.world.diplomacy.subjects_of("JAP"):
		total_paid += _line(all[s].expenses, EconomySystem.TRIBUTE_OUT)
	check(is_equal_approx(received, total_paid), "Toyotomi receives what its vassals pay")


func test_occupied_provinces_pay_the_occupier() -> void:
	var c := _campaign()
	var e := EconomySystem.new(c)
	var paris := _at(c, 47.39, 0.69)  # Tours, Henry IV's seat (Paris held for the League)
	var paris_tax := 0.0
	var taxes := e.province_taxes(paris)
	for r: String in taxes:
		paris_tax += taxes[r]
	paris_tax += e.production(paris).value * Buildings.customs_share(paris)
	var before: float = e.budget("FRA").tax_income
	c.world.set_controller(paris.id, "SPA")
	var after: float = e.budget("FRA").tax_income
	check(after < before, "France loses Paris's taxes")
	check(is_equal_approx(_line(e.budget("SPA").income, EconomySystem.OCCUPIED), paris_tax * EconomySystem.OCCUPATION_SHARE),
		"Spain takes half as occupier")


# --- Saving --------------------------------------------------------------------------------

func test_economy_survives_save_and_load() -> void:
	var a := _campaign()
	var e := EconomySystem.new(a)
	var eng := a.world.get_country("ENG")
	e.take_loan("ENG")
	eng.tax_rates[0] = 35
	eng.spending.court = 165
	eng.spending.mint = 7
	eng.spending.army = 120
	var london := _at(a, 51.51, -0.13)
	eng.treasury = 500.0
	e.start_building("ENG", "fort", london)
	var potosi := _at(a, -19.58, -65.75)
	potosi.found.append("gold")
	potosi.resource = "gold"
	e.invalidate()  # changed by hand, not through the economy
	e.monthly()
	var copy: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict(), "", false, true))
	var b := _campaign()
	check(b.restore(copy).is_empty(), "restore")
	var eng2 := b.world.get_country("ENG")
	for field in ["loans", "treasury", "ledger", "tax_rates", "spending", "inflation", "satisfaction", "bankrupt_until"]:
		check_eq(eng2.get(field), eng.get(field), field)
	var london2 := _at(b, 51.51, -0.13)
	check_eq(london2.construction, london.construction, "construction")
	check_eq(london2.pops, london.pops, "pops")
	check_eq(london2.buildings, london.buildings, "buildings")
	var potosi2 := _at(b, -19.58, -65.75)
	check_eq(potosi2.resource, "gold", "discovered good")
	check_eq(potosi2.found, ["gold"], "discoveries")


func test_format_3_saves_upgrade() -> void:
	var dir := "user://test_econ_saves"
	var service := SaveService.new(dir)
	var c := _campaign()
	check(service.save(c, "old"), "save")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(service.path_of("old")))
	data.schema_version = 3
	var world: Dictionary = data.campaign.world
	for tag: String in world.countries:
		var country: Dictionary = world.countries[tag]
		for key in ["loans", "policies", "inflation", "satisfaction", "bankrupt_until", "last_bankruptcy"]:
			country.erase(key)
		country["debt"] = 250.0 if tag == "ENG" else 0.0
	world.province_fields = ["owner", "controller", "population", "development", "unrest"]
	for row: Array in world.provinces:
		row.resize(6)
	var f := FileAccess.open(service.path_of("old"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	check(service.load_into(c, "old"), "format 3 loads: %s" % [service.errors])
	var eng := c.world.get_country("ENG")
	check_eq(eng.loans, [[250.0, 0.08, 0]], "the old debt is one loan at 8 %")
	check_eq(eng.tax_rates, [20, 0, 20, 20, 8], "customary taxes")
	var potosi := _at(c, -19.58, -65.75)
	check_eq(potosi.resource, "silver", "goods as in 1590")
	var sum := 0
	for r: String in potosi.pops:
		sum += potosi.pops[r]
	check(sum == potosi.population and sum > 0, "people divided into estates")
	service.delete("old")
	DirAccess.remove_absolute(dir)


func test_tax_rates_have_a_ceiling() -> void:
	var c := _campaign()
	var state := c.to_dict()
	state.world.countries["ENG"].policies.taxes[3] = Estates.TAX_MAX.commoners + 1
	check(c.restore(state).size() > 0, "a rate above the maximum is refused")
	state.world.countries["ENG"].policies.taxes[3] = Estates.TAX_MAX.commoners
	state.world.countries["ENG"].policies.taxes[1] = 5
	check(c.restore(state).size() > 0, "the clergy cannot be taxed")


func test_format_4_tax_levels_become_rates() -> void:
	var data := {"campaign": {"world": {"countries": {"ENG": {"policies": {"taxes": [3, 2, 4, 0, 2]}}}}}}
	SaveService._upgrade_4_to_5(data)
	check_eq(data.campaign.world.countries.ENG.policies.taxes, [30, 0, 40, 0, 8], "levels × custom")
