class_name EconomySystem
extends RefCounted
## The economy (structure.md §6), monthly through the scheduler.
##
## Production: commoners and tribesmen work the land; each province turns out
## its good — workers × the good's yield × development × land × extraction
## buildings × calm (unrest costs output) — and a manufactory makes half of it
## into a finished good. Prices are fixed for now (Goods); a market comes later.
##
## Incomes: every estate draws a share of the province's output, more per head
## the higher it stands (merchants more where there are markets and
## manufactories), and pays tax at the level the government sets for it,
## collected as far as the capital's reach and the estate's goodwill allow.
## Occupied provinces pay half their tax to the occupier, none to the owner.
##
## The state also takes customs (customs houses), tribute from subjects and
## coin from minting (which feeds inflation), and pays for provincial
## administration, its court, fort upkeep and interest. Army and navy upkeep
## arrive with armies. A treasury that would go negative borrows; when no
## lender will, the country goes bankrupt.
##
## Every change to a treasury is written to the country's ledger under a name.
##
## Each province's figures (output, estate incomes within reach, tariffs,
## upkeep) are kept until that province changes (`touch()`: its owner, unrest,
## buildings, a discovery); budgets add them up again whenever anything a
## budget depends on changes (`changed()`: policies, loans, goodwill,
## inflation, subjects, colonies). Recomputing 5000 provinces every month
## made months slower and slower on phones. `invalidate()` recomputes
## everything (a restored campaign, tests editing fields by hand).

signal discovered(province_id: int, good: String)
signal construction_finished(province_id: int, building: String)
signal went_bankrupt(tag: String)

# --- Production ---
const LAND_FACTOR_KINDS := ["farm", "cash"]
const VEGETATION_YIELD := {"farmland": 1.25, "grasslands": 1.0, "woods": 0.9, "forest": 0.8, "sparse": 0.6,
	"jungle": 0.6, "desert": 0.4}
const TOPOGRAPHY_YIELD := {"flatland": 1.0, "hills": 0.9, "plateau": 0.85, "mountains": 0.7, "wetlands": 0.8}
## Turns raw output value into ducats a month (calibration of the money scale:
## about 140 of 238 countries start in surplus, with room for armies later).
const VALUE_SCALE := 0.5
# --- Collection ---
const REACH_KM := 4000.0
const REACH_MIN := 0.3
const OCCUPATION_SHARE := 0.5
# --- Policies (see Policies for court, minting and upkeep) ---
const INFLATION_EASING := 0.02
# --- Costs ---
## Administering a province costs ADMIN_PER_PROVINCE a month at development
## ADMIN_FULL_DEVELOPMENT or more, less for thinly settled land (down to
## ADMIN_MIN_SHARE of it): a frontier province costs little to run.
const ADMIN_PER_PROVINCE := 0.25
const ADMIN_FULL_DEVELOPMENT := 5.0
const ADMIN_MIN_SHARE := 0.2
const FORT_MIN_SHARE := 0.4
## The court's cost comes with the realm's rank (Ranks.court): a base and a
## share of its taxes, less for tribal realms and colonies.
## The crown's fifth of gold and silver mined (the quinto real), from every
## gold or silver province a country holds — as far as its reach allows.
const ROYAL_FIFTH := 0.2
const ROYAL_FIFTH_GOODS := ["gold", "silver"]
## The crown pays this share of its colonies' forts' upkeep, and more —
## whatever a colony needs to keep SITUADO_MARGIN and SITUADO_MARGIN_SHARE of
## its revenue in hand, up to all its costs (the situado, sent from Mexico to
## the Caribbean, Florida and Manila to keep them going).
const SITUADO_SHARE := 0.5
const SITUADO_MARGIN := 0.25
const SITUADO_MARGIN_SHARE := 0.1
## A colony sends home at most this share of what it has left over (and at
## most its TRIBUTE_SHARE of its revenue): the rest pays its own affairs.
const COLONY_REMIT := 0.5
## Colonies send home a quarter (the crown's fifth of the silver, the customs).
const TRIBUTE_SHARE := {"vassal": 0.10, "personal_union": 0.05, "tributary": 0.05, "colony": 0.25}
# --- Estates' goodwill ---
const SATISFACTION_BASE := 60.0
const SATISFACTION_PER_TAX_POINT := 2.5  # per percent above (or below) custom
const SATISFACTION_INFLATION := 1.5  # merchants, per percent of inflation
const SATISFACTION_PULL := 0.1  # share of the gap closed each month
const UNREST_PULL := 0.1
# --- Loans ---
const LOAN_SIZE := 100.0
const BASE_RATE := 0.05
const RATE_PER_DEBT_YEAR := 0.04  # per year of income owed
const RATE_AFTER_BANKRUPTCY := 0.05  # for ten years
const MAX_RATE := 0.25
const CREDIT_YEARS := 2.0  # lenders go up to this many years of income
const MIN_CREDIT := 200.0
const BANKRUPTCY_EXCLUSION_DAYS := 5 * 365
const BANKRUPTCY_MEMORY_DAYS := 10 * 365

# --- Ledger names ---
const TAXES := "Taxes: %s"
const CUSTOMS := "Customs"
const FIFTH := "Royal fifth of the mines"
const SITUADO := "Situado: colonial garrisons"
const SITUADO_IN := "Situado from the crown"
const SUBSIDIES_OUT := "Subsidies paid"
const SUBSIDIES_IN := "Subsidies received"
const OCCUPIED := "Taxes from occupied lands"
const TRIBUTE_IN := "Tribute from subjects"
const MINTING := "Minting"
const ADMIN := "Provincial administration"
const COURT := "Court maintenance"
const FORTS := "Fort maintenance"
const COLONIES := "Colonial upkeep"
const MISSIONS := "Missionaries"
## A missionary's upkeep a month (see ReligionSystem).
const MISSION_UPKEEP := 1.0
const ARMY := "Army maintenance"
const NAVY := "Navy maintenance"
const INTEREST := "Interest on loans"
const TRIBUTE_OUT := "Tribute to overlord"
const LOAN := "Loan taken"
const REPAYMENT := "Loan repaid"
const CONSTRUCTION := "Construction: %s"
const BANKRUPTCY := "Bankruptcy: %d ducats of debt repudiated"
const UNPAID := "Unpaid bills written off"

var world: WorldState
var clock: GameClock
var rng: GameRandom
var _capitals := {}  # tag -> Vector2(lat, lon) or null
var _capital_ids := {}  # tag -> the capital province _capitals was taken from
var _production := {}  # province id -> production(p), until the province changes
var _entries := {}  # province id -> its figures for budgets (see _entry)
var _built_out := {}  # province id -> true: no extraction building or manufactory left to add
var _budgets := {}  # tag -> budget, until something changes
var _governed := {}  # tag -> development held, as the budgets were added up


func _init(p_campaign: Campaign) -> void:
	world = p_campaign.world
	clock = p_campaign.clock
	rng = p_campaign.rng
	world.province_owner_changed.connect(_on_owner_changed)
	world.province_controller_changed.connect(func(_id, _a, _b): changed())
	world.campaign_restored.connect(func():
		_capitals.clear()
		_capital_ids.clear()
		invalidate())
	world.diplomacy.subjects_changed.connect(changed)
	world.diplomacy.reset.connect(changed)


## Anything may have changed: every province and budget is computed afresh.
## New dictionaries, never cleared ones: a caller may still be walking the
## old budgets (the month's accounts borrow mid-loop).
func invalidate() -> void:
	_production = {}
	_entries = {}
	_built_out = {}
	_budgets = {}


## A province's output, people or owner changed: its figures are recomputed.
func touch(p: Province) -> void:
	_production.erase(p.id)
	_entries.erase(p.id)
	_built_out.erase(p.id)
	_budgets = {}


## Something about a country changed (policies, loans, goodwill, inflation,
## subjects, colonies): budgets are added up again; provinces are not.
func changed() -> void:
	_budgets = {}


## A province changed hands: its figures change, and if a capital moved
## (taking a capital clears it), so does the reach of that country's land.
func _on_owner_changed(province_id: int, old_owner: String, new_owner: String) -> void:
	touch(world.get_province(province_id))
	for tag: String in [old_owner, new_owner]:
		var c := world.get_country(tag)
		if c != null and _capital_ids.has(tag) and _capital_ids[tag] != c.capital_province_id:
			_capitals.erase(tag)
			_capital_ids.erase(tag)
			for p: Province in world.ownable_provinces():
				if p.owner_id == tag:
					touch(p)


# --- A province ------------------------------------------------------------------

## People who work the land (not those away with the levies).
static func workforce(p: Province) -> float:
	var total := 0.0
	for r: String in Estates.ROLES:
		total += p.pops.get(r, 0) * Estates.LABOUR[r]
	return maxf(total - p.levied, 0.0)


## What a province turns out this month, with every factor named:
## {raw_good, raw_units, made_good, made_units, value, factors: [[label, x]]}.
## Kept until the province changes; callers must not change it.
func production(p: Province) -> Dictionary:
	if _production.has(p.id):
		return _production[p.id]
	var out := _compute_production(p)
	_production[p.id] = out
	return out


func _compute_production(p: Province) -> Dictionary:
	var out := {"raw_good": p.resource, "raw_units": 0.0, "made_good": "", "made_units": 0.0, "value": 0.0, "factors": []}
	if p.is_sea or p.is_wasteland or not Goods.has(p.resource):
		return out
	var kind := Goods.kind_of(p.resource)
	var base := workforce(p) / 10000.0 * Goods.yield_of(p.resource)
	var dev := 0.6 + 0.1 * p.development
	var land := 1.0
	if kind in LAND_FACTOR_KINDS:
		land = VEGETATION_YIELD.get(p.vegetation, 1.0) * TOPOGRAPHY_YIELD.get(p.topography, 1.0)
	elif kind == "wild":
		land = TOPOGRAPHY_YIELD.get(p.topography, 1.0)
	var extraction := Buildings.extraction_bonus(p)
	var calm := 1.0 - clampf(p.unrest, 0.0, 100.0) / 200.0
	var raw := base * dev * land * extraction * calm
	out.factors = [["Workers (%d)" % int(workforce(p)), base], ["Development", dev],
		["Land", land], ["Extraction buildings", extraction], ["Unrest", calm]]
	var made_units := 0.0
	var recipe := Buildings.recipe(p)
	if not recipe.is_empty():
		made_units = raw * Buildings.MANUFACTURE_SHARE * recipe[1]
		raw *= 1.0 - Buildings.MANUFACTURE_SHARE
		out.made_good = recipe[0]
	out.raw_units = raw
	out.made_units = made_units
	out.value = (raw * Goods.price_of(p.resource) + made_units * Goods.price_of(out.made_good)) * VALUE_SCALE
	return out


## Each estate's income from a province (ducats a month), by role.
func estate_incomes(p: Province, value: float) -> Dictionary:
	var weights := {}
	var total := 0.0
	var merchant_bonus := Buildings.merchant_bonus(p)
	for r: String in Estates.ROLES:
		var w: float = p.pops.get(r, 0) * Estates.INCOME_WEIGHT[r] * (merchant_bonus if r == "merchants" else 1.0)
		weights[r] = w
		total += w
	var out := {}
	for r: String in Estates.ROLES:
		out[r] = value * weights[r] / total if total > 0.0 else 0.0
	return out


## Share of a province's tax its owner's administration can reach.
func reach_of(p: Province) -> float:
	var cap: Variant = _capital(p.owner_id)
	if cap == null:
		return REACH_MIN
	var km := DiplomacyActions._haversine(p.lat, p.lon, cap.x, cap.y)
	return clampf(1.0 - km / REACH_KM * (1.0 - REACH_MIN), REACH_MIN, 1.0)


func _capital(tag: String) -> Variant:
	if not _capitals.has(tag):
		var c := world.get_country(tag)
		var cap := world.get_province(c.capital_province_id) if c else null
		_capitals[tag] = Vector2(cap.lat, cap.lon) if cap else null
		_capital_ids[tag] = c.capital_province_id if c else 0
	return _capitals[tag]


## A province's figures for budgets, kept until it changes: output value,
## each estate's income within its owner's reach (Estates.ROLES order),
## tariffs and fort upkeep.
func _entry(p: Province) -> Dictionary:
	if _entries.has(p.id):
		return _entries[p.id]
	var value: float = production(p).value
	var incomes := estate_incomes(p, value)
	var reach := reach_of(p) if p.owner_id != "" else 0.0
	var reached := PackedFloat64Array()
	for r: String in Estates.ROLES:
		reached.append(incomes[r] * reach)
	var e := {"value": value, "reached": reached, "customs": value * Buildings.customs_share(p),
		"fifth": value * ROYAL_FIFTH * reach if p.resource in ROYAL_FIFTH_GOODS else 0.0,
		"upkeep": Buildings.upkeep(p) - (_fort_saving(p) if "fort" in p.buildings else 0.0),
		"forts": Buildings.CATALOGUE.fort.upkeep - _fort_saving(p) if "fort" in p.buildings else 0.0,
		"admin": ADMIN_PER_PROVINCE * clampf(p.development / ADMIN_FULL_DEVELOPMENT, ADMIN_MIN_SHARE, 1.0)}
	_entries[p.id] = e
	return e


## A fort in thinly settled land is an outpost with a small garrison: its
## upkeep scales with development like administration (down to FORT_MIN_SHARE).
## What that saves on the full upkeep.
static func _fort_saving(p: Province) -> float:
	var share := clampf(p.development / ADMIN_FULL_DEVELOPMENT, FORT_MIN_SHARE, 1.0)
	return Buildings.CATALOGUE.fort.upkeep * (1.0 - share)


## The share of an estate's (reached) income a country collects: its tax
## rate, as far as the estate's goodwill allows.
static func _tax_factor(c: Country, role_index: int) -> float:
	if not Estates.taxable(Estates.ROLES[role_index]):
		return 0.0
	var goodwill := 0.6 + 0.4 * clampf(c.satisfaction[role_index], 0.0, 100.0) / 100.0
	return c.tax_rates[role_index] / 100.0 * goodwill


## Tax from each estate of a province at its owner's levels (before occupation).
func province_taxes(p: Province) -> Dictionary:
	var c := world.get_country(p.owner_id)
	var out := {}
	if c == null:
		return out
	var reached: PackedFloat64Array = _entry(p).reached
	var governed := governance_efficiency(c.id)
	for i in Estates.ROLES.size():
		out[Estates.ROLES[i]] = reached[i] * _tax_factor(c, i) * governed
	return out


## Development a country holds (its rank governs so much in full).
func development_of(tag: String) -> int:
	if _budgets.is_empty():
		budgets()
	return _governed.get(tag, 0)


## The share of its taxes a country's administration collects: all of them
## while it holds no more development than its rank governs (Ranks).
func governance_efficiency(tag: String) -> float:
	var c := world.get_country(tag)
	if c == null:
		return 1.0
	return Ranks.efficiency(c.rank, clock.year, development_of(tag))


# --- Budgets ---------------------------------------------------------------------

## Next month's budget for every country: tag -> {income: [[label, amount]],
## expenses: [[label, amount]] (amounts positive), net, tax_income}. Kept
## until something changes; callers must not change it.
func budgets() -> Dictionary:
	if not _budgets.is_empty():
		return _budgets
	_budgets = _compute_budgets()
	return _budgets


## Adds up the provinces' kept figures: each country's estate incomes within
## reach (taxed below at its rates), tariffs, occupied land, upkeep.
func _compute_budgets() -> Dictionary:
	var reached := {}  # tag -> [income within reach by role] from the land it controls
	var customs := {}
	var occupied := {}
	var provinces := {}
	var development := {}
	var fort_upkeep := {}
	var fort_only := {}  # tag -> the forts' part of fort_upkeep (the situado shares it)
	var admin := {}
	var fifth := {}
	var colonies := {}
	var roles := Estates.ROLES.size()
	for p: Province in world.ownable_provinces():
		if p.colonist != "":
			colonies[p.colonist] = colonies.get(p.colonist, 0) + 1
		if p.owner_id == "":
			continue
		var owner := p.owner_id
		var e := _entry(p)
		provinces[owner] = provinces.get(owner, 0) + 1
		development[owner] = development.get(owner, 0) + p.development
		fort_upkeep[owner] = fort_upkeep.get(owner, 0.0) + e.upkeep
		fort_only[owner] = fort_only.get(owner, 0.0) + e.forts
		admin[owner] = admin.get(owner, 0.0) + e.admin
		var incomes: PackedFloat64Array = e.reached
		if p.controller_id == owner:
			var sums: Array = reached.get(owner, [])
			if sums.is_empty():
				sums.resize(roles)
				sums.fill(0.0)
				reached[owner] = sums
			for i in roles:
				sums[i] += incomes[i]
			customs[owner] = customs.get(owner, 0.0) + e.customs
			fifth[owner] = fifth.get(owner, 0.0) + e.fifth
		elif p.controller_id != "":
			var c: Country = world.countries[owner]
			var sum: float = e.customs
			for i in roles:
				sum += incomes[i] * _tax_factor(c, i)
			occupied[p.controller_id] = occupied.get(p.controller_id, 0.0) + sum * OCCUPATION_SHARE
	var missions := {}
	for id: int in world.missions:
		var by: String = world.missions[id][0]
		missions[by] = missions.get(by, 0) + 1
	var army := {}
	var navy := {}
	for a: Army in world.military.armies.values():
		var table := navy if a.navy else army
		table[a.owner] = table.get(a.owner, 0.0) + a.upkeep() * (Military.DOCKED_UPKEEP if Military.is_berthed(world, a) else 1.0)
	_governed = development
	var taxes := {}  # tag -> {role: amount}
	for tag: String in reached:
		var c: Country = world.countries[tag]
		var sums: Array = reached[tag]
		var governed := Ranks.efficiency(c.rank, clock.year, development.get(tag, 0))
		var t := {}
		for i in roles:
			t[Estates.ROLES[i]] = sums[i] * _tax_factor(c, i) * governed
		taxes[tag] = t
	var d := world.diplomacy
	var ctx := {"taxes": taxes, "customs": customs, "fifth": fifth, "occupied": occupied, "admin": admin,
		"development": development, "fort_upkeep": fort_upkeep, "colonies": colonies, "missions": missions,
		"army": army, "navy": navy, "tribute_in": {}, "tribute_out": {}, "situado_in": {}, "situado_out": {},
		"subsidy_in": {}, "subsidy_out": {}}
	for row: Array in d.subsidies():  # [from, to, ducats a month]
		ctx.subsidy_out[row[0]] = ctx.subsidy_out.get(row[0], 0.0) + float(row[2])
		ctx.subsidy_in[row[1]] = ctx.subsidy_in.get(row[1], 0.0) + float(row[2])
	# Tribute from vassals and unions: a share of their taxes. Colonies: the
	# crown pays half their forts' upkeep, and whatever more a poor colony
	# needs to keep a little in hand (the situado); they send home a quarter
	# of their revenue, but never more than half of what they have left over.
	for tag: String in world.countries:
		var overlord := d.overlord_of(tag)
		if overlord == "" or not world.countries.has(overlord):
			continue
		var revenue: float = _sum(taxes.get(tag, {})) + fifth.get(tag, 0.0)
		var amount: float = revenue * TRIBUTE_SHARE[d.subject_type(tag)]
		if d.subject_type(tag) == "colony":
			var c: Country = world.countries[tag]
			var prices := 1.0 + c.inflation / 100.0
			var forts: float = fort_only.get(tag, 0.0) * Policies.upkeep_cost(c.spending.forts) * prices
			var own_budget := _country_budget(tag, ctx)  # before the situado and tribute
			var own: float = own_budget.net
			var spent := 0.0
			for l: Array in own_budget.expenses:
				spent += l[1]
			var margin := SITUADO_MARGIN + SITUADO_MARGIN_SHARE * revenue
			var situado := clampf(maxf(forts * SITUADO_SHARE, margin - own), 0.0, spent)
			if situado > 0.0:
				ctx.situado_in[tag] = situado
				ctx.situado_out[overlord] = ctx.situado_out.get(overlord, 0.0) + situado
			amount = minf(amount, maxf(own + situado, 0.0) * COLONY_REMIT)
		ctx.tribute_out[tag] = amount
		ctx.tribute_in[overlord] = ctx.tribute_in.get(overlord, 0.0) + amount
	var out := {}
	for tag: String in world.countries:
		out[tag] = _country_budget(tag, ctx)
	return out


## One country's budget from the summed figures (`ctx`, see _compute_budgets).
func _country_budget(tag: String, ctx: Dictionary) -> Dictionary:
	var c: Country = world.countries[tag]
	var d := world.diplomacy
	var prices := 1.0 + c.inflation / 100.0
	var income := []
	var expenses := []
	var t: Dictionary = ctx.taxes.get(tag, {})
	var tax_income := _sum(t)
	for r: String in Estates.ROLES:
		_line(income, TAXES % Estates.display(r), t.get(r, 0.0))
	_line(income, CUSTOMS, ctx.customs.get(tag, 0.0))
	_line(income, FIFTH, ctx.fifth.get(tag, 0.0))
	_line(income, OCCUPIED, ctx.occupied.get(tag, 0.0))
	_line(income, TRIBUTE_IN, ctx.tribute_in.get(tag, 0.0))
	_line(income, SITUADO_IN, ctx.situado_in.get(tag, 0.0))
	_line(income, SUBSIDIES_IN, ctx.subsidy_in.get(tag, 0.0))
	_line(income, MINTING, tax_income * Policies.mint_share(c.spending.mint))
	_line(expenses, ADMIN, ctx.admin.get(tag, 0.0) * prices)
	_line(expenses, COURT, Ranks.court(c.rank, tax_income, c.government_type, d.subject_type(tag) == "colony")
		* Policies.court_cost(c.spending.court) * prices)
	_line(expenses, FORTS, ctx.fort_upkeep.get(tag, 0.0) * Policies.upkeep_cost(c.spending.forts) * prices)
	_line(expenses, SITUADO, ctx.situado_out.get(tag, 0.0))
	_line(expenses, SUBSIDIES_OUT, ctx.subsidy_out.get(tag, 0.0))
	_line(expenses, COLONIES, (Colonisation.POLICY_UPKEEP[c.colonial_policy]
		+ Colonisation.COLONY_UPKEEP * ctx.colonies.get(tag, 0)) * prices)
	_line(expenses, MISSIONS, MISSION_UPKEEP * ctx.missions.get(tag, 0) * prices)
	_line(expenses, ARMY, ctx.army.get(tag, 0.0) * Policies.upkeep_cost(c.spending.army) * prices)
	_line(expenses, NAVY, ctx.navy.get(tag, 0.0) * Policies.upkeep_cost(c.spending.navy) * prices)
	var interest := 0.0
	for l: Array in c.loans:
		interest += l[0] * l[1] / 12.0
	_line(expenses, INTEREST, interest)
	_line(expenses, TRIBUTE_OUT, ctx.tribute_out.get(tag, 0.0))
	var net := 0.0
	for l: Array in income:
		net += l[1]
	for l: Array in expenses:
		net -= l[1]
	return {"income": income, "expenses": expenses, "net": net, "tax_income": tax_income}


static func _sum(d: Dictionary) -> float:
	var total := 0.0
	for k in d:
		total += d[k]
	return total


static func _line(lines: Array, label: String, amount: float) -> void:
	if amount > 0.0005:
		lines.append([label, amount])


func budget(tag: String) -> Dictionary:
	return budgets().get(tag, {"income": [], "expenses": [], "net": 0.0, "tax_income": 0.0})


# --- The month -------------------------------------------------------------------------

func monthly() -> void:
	var all := budgets()
	for tag: String in all:
		var c: Country = world.countries[tag]
		var b: Dictionary = all[tag]
		c.ledger = []
		for l: Array in b.income:
			_post(c, l[0], l[1])
		for l: Array in b.expenses:
			_post(c, l[0], -l[1])
		_policy_effects(c)
		if c.treasury < 0.0:
			_cover_deficit(c, b.tax_income)
	_provinces_month()
	changed()  # goodwill, inflation and legitimacy moved


## Court, minting and taxes move legitimacy, inflation and the estates.
func _policy_effects(c: Country) -> void:
	c.legitimacy = clampf(c.legitimacy + Policies.court_legitimacy(c.spending.court), 0.0, 100.0)
	if c.spending.mint > 0:
		c.inflation = decimal(c.inflation + Policies.mint_inflation(c.spending.mint), 1000.0)
	else:
		c.inflation = decimal(maxf(c.inflation - INFLATION_EASING, 0.0), 1000.0)
	for i in Estates.ROLES.size():
		var target := satisfaction_target(c, i)
		c.satisfaction[i] = decimal(c.satisfaction[i] + (target - c.satisfaction[i]) * SATISFACTION_PULL)


## Where an estate's goodwill is heading under the current policies.
func satisfaction_target(c: Country, role_index: int) -> float:
	var role: String = Estates.ROLES[role_index]
	var custom: int = Estates.CUSTOMARY_TAX[role]
	var rate: int = c.tax_rates[role_index] if Estates.taxable(role) else custom
	var target: float = SATISFACTION_BASE - SATISFACTION_PER_TAX_POINT * (rate - custom)
	if role == "nobility":
		target += Policies.court_nobles(c.spending.court)
	if role == "merchants":
		target -= c.inflation * SATISFACTION_INFLATION
	return clampf(target, 0.0, 100.0)


## Unrest follows the working estates' goodwill, and the people's faith if it
## is not their ruler's; buildings rise.
func _provinces_month() -> void:
	for p: Province in world.provinces.values():
		if p.is_sea or p.is_wasteland:
			continue
		var c := world.get_country(p.owner_id)
		if c != null:
			var workers: float = minf(c.satisfaction[3], c.satisfaction[4])
			var target := clampf((50.0 - workers) * 0.4, 0.0, 30.0) + Religions.unrest(p.religion, c.religion)
			var unrest := decimal(p.unrest + (target - p.unrest) * UNREST_PULL)
			if unrest != p.unrest:
				p.unrest = unrest
				touch(p)  # unrest costs output
		if not p.construction.is_empty():
			p.construction[1] -= 1
			if p.construction[1] <= 0:
				var id: String = p.construction[0]
				p.construction = []
				if Buildings.unsuitable(id, p) == "":
					p.buildings.append(id)
					touch(p)
				construction_finished.emit(p.id, id)


## Yearly: deposits whose time has come may be found.
func yearly() -> void:
	var year := clock.year
	for p: Province in world.provinces.values():
		for d: Array in p.deposits:
			var good: String = d[0]
			if good in p.found or year < d[1]:
				continue
			if rng.chance(d[2]):
				p.found.append(good)
				p.resource = good
				touch(p)
				discovered.emit(p.id, good)


# --- Money ------------------------------------------------------------------------------

## `x` rounded to 1/`per` (hundredths by default) as the double nearest that
## decimal — which JSON writes and reads back exactly (snappedf can land a
## hair off, e.g. 3.2600000000000002, and change in a save round trip).
static func decimal(x: float, per := 100.0) -> float:
	return roundf(x * per) / per


## Money is kept to hundredths of a ducat: exact in the ledger, and it
## survives saving to JSON unchanged. Other systems (colonisation) pay through
## here so every ducat is in the ledger.
func post(c: Country, label: String, amount: float) -> void:
	_post(c, label, amount)


func _post(c: Country, label: String, amount: float) -> void:
	amount = decimal(amount)
	c.treasury = decimal(c.treasury + amount)
	c.ledger.append([label, amount])


## Borrow to cover a deficit, or go bankrupt if no one will lend. A country
## still shut out of credit after a bankruptcy leaves its bills unpaid (it
## does not go bankrupt again every month).
func _cover_deficit(c: Country, tax_income: float) -> void:
	while c.treasury < 0.0:
		if c.bankrupt_until > clock.day_number():
			_post(c, UNPAID, -c.treasury)
			return
		if loan_blocked(c.id, tax_income) != "":
			declare_bankruptcy(c.id)
			return
		_borrow(c, tax_income)


func annual_income(tag: String, tax_income := -1.0) -> float:
	if tax_income < 0.0:
		tax_income = budget(tag).tax_income
	return tax_income * 12.0


## The interest a new loan would carry now.
func interest_rate(tag: String, tax_income := -1.0) -> float:
	var c := world.get_country(tag)
	var years_owed := c.debt / maxf(annual_income(tag, tax_income), 1.0)
	var rate := BASE_RATE + RATE_PER_DEBT_YEAR * years_owed
	if c.last_bankruptcy >= 0 and clock.day_number() - c.last_bankruptcy < BANKRUPTCY_MEMORY_DAYS:
		rate += RATE_AFTER_BANKRUPTCY
	return decimal(minf(rate, MAX_RATE), 1000.0)


## How much lenders will let us owe.
func credit_limit(tag: String, tax_income := -1.0) -> float:
	return maxf(MIN_CREDIT, annual_income(tag, tax_income) * CREDIT_YEARS)


## Why no loan can be had now ("" if one can).
func loan_blocked(tag: String, tax_income := -1.0) -> String:
	var c := world.get_country(tag)
	if c.bankrupt_until > clock.day_number():
		return "No lender will deal with us since our bankruptcy"
	if c.debt + LOAN_SIZE > credit_limit(tag, tax_income):
		return "Lenders will not go beyond %d ducats" % int(credit_limit(tag, tax_income))
	return ""


func take_loan(tag: String) -> bool:
	if loan_blocked(tag) != "":
		return false
	_borrow(world.get_country(tag), -1.0)
	return true


func _borrow(c: Country, tax_income: float) -> void:
	var rate := interest_rate(c.id, tax_income)
	c.loans.append([LOAN_SIZE, rate, clock.day_number()])
	_post(c, LOAN, LOAN_SIZE)
	changed()


## Why loan `index` cannot be repaid now ("" if it can).
func repay_blocked(tag: String, index: int) -> String:
	var c := world.get_country(tag)
	if index < 0 or index >= c.loans.size():
		return "No such loan"
	if c.treasury < c.loans[index][0]:
		return "Needs %d ducats" % int(c.loans[index][0])
	return ""


func repay_loan(tag: String, index: int) -> bool:
	if repay_blocked(tag, index) != "":
		return false
	var c := world.get_country(tag)
	var amount: float = c.loans[index][0]
	c.loans.remove_at(index)
	_post(c, REPAYMENT, -amount)
	changed()
	return true


## Repudiate all debts: lenders shut their doors for five years and charge
## more for ten, the realm loses face, and the estates who lent lose faith.
func declare_bankruptcy(tag: String) -> void:
	var c := world.get_country(tag)
	var debt := c.debt
	c.loans = []
	if c.treasury < 0.0:
		_post(c, UNPAID, -c.treasury)
	c.ledger.append([BANKRUPTCY % int(debt), 0.0])
	var today := clock.day_number()
	c.bankrupt_until = today + BANKRUPTCY_EXCLUSION_DAYS
	c.last_bankruptcy = today
	c.legitimacy = clampf(c.legitimacy - 20.0, 0.0, 100.0)
	c.stability = maxi(c.stability - 1, -3)
	c.satisfaction[2] = maxf(c.satisfaction[2] - 40.0, 0.0)  # merchants
	c.satisfaction[0] = maxf(c.satisfaction[0] - 15.0, 0.0)  # nobility
	changed()
	went_bankrupt.emit(tag)


## AI countries pay back their dearest loan once they hold three loans' worth.
func ai_repayments(player: String) -> void:
	for c: Country in world.countries.values():
		if c.id == player or c.loans.is_empty() or c.treasury < LOAN_SIZE * 3.0:
			continue
		var dearest := 0
		for i in c.loans.size():
			if c.loans[i][1] > c.loans[dearest][1]:
				dearest = i
		repay_loan(c.id, dearest)


# --- Buildings ----------------------------------------------------------------------------

func building_cost(tag: String, id: String) -> float:
	var c := world.get_country(tag)
	return decimal(Buildings.CATALOGUE[id].cost * (1.0 + c.inflation / 100.0))


## Why `tag` cannot build `id` in the province now ("" if it can).
func build_blocked(tag: String, id: String, p: Province) -> String:
	if p.owner_id != tag:
		return "Not our province"
	if p.controller_id != tag:
		return "The province is occupied"
	var why := Buildings.unsuitable(id, p)
	if why != "":
		return why
	var cost := building_cost(tag, id)
	if world.get_country(tag).treasury < cost:
		return "Needs %d ducats" % int(ceil(cost))
	return ""


func start_building(tag: String, id: String, p: Province) -> bool:
	if build_blocked(tag, id, p) != "":
		return false
	var c := world.get_country(tag)
	_post(c, CONSTRUCTION % Buildings.name_of(id), -building_cost(tag, id))
	p.construction = [id, int(Buildings.CATALOGUE[id].months)]
	return true


## AI countries put spare money into the most productive province that can
## use an extraction building or a manufactory (one a month each).
##
## Only countries that could afford the cheapest such building are looked at;
## their provinces are tried richest first (ties: lowest id) until one can use
## a building — the same choice as weighing every province, far fewer checks.
func ai_construction(player: String) -> void:
	var cheapest := INF
	for id: String in Buildings.CATALOGUE:
		if Buildings.type_of(id) in ["extraction", "manufacture"]:
			cheapest = minf(cheapest, Buildings.CATALOGUE[id].cost)
	var land := {}  # tag -> [[value, id, province]] for countries that might build
	for c: Country in world.countries.values():
		if c.id != player and c.treasury >= cheapest * (1.0 + c.inflation / 100.0) + LOAN_SIZE * 2.0:
			land[c.id] = []
	if land.is_empty():
		return
	var counts := {}  # tag -> provinces
	var barracks := {}  # tag -> barracks standing or being built
	var drill := {}  # tag -> its most populous province that could take barracks
	for p: Province in world.ownable_provinces():
		if not land.has(p.owner_id):
			continue
		var tag := p.owner_id
		counts[tag] = counts.get(tag, 0) + 1
		if "barracks" in p.buildings or (not p.construction.is_empty() and p.construction[0] == "barracks"):
			barracks[tag] = barracks.get(tag, 0) + 1
		elif p.construction.is_empty() and p.controller_id == tag and Buildings.unsuitable("barracks", p) == "" \
				and (not drill.has(tag) or p.population > drill[tag].population):
			drill[tag] = p
		if p.construction.is_empty():
			land[tag].append([production(p).value, p.id, p])
	for tag: String in land:
		# Barracks first, as the realm grows: one for a realm that keeps a
		# standing army, one more for every AI_PROVINCES_PER_BARRACKS provinces.
		var wanted := 0 if counts.get(tag, 0) < Military.STANDING_MIN_PROVINCES \
			else mini(1 + counts[tag] / AI_PROVINCES_PER_BARRACKS, AI_MAX_BARRACKS)
		if barracks.get(tag, 0) < wanted and drill.has(tag) \
				and world.get_country(tag).treasury >= building_cost(tag, "barracks") + LOAN_SIZE * 2.0:
			start_building(tag, "barracks", drill[tag])
			continue
		var provinces: Array = land[tag]
		provinces.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
		for entry: Array in provinces:
			var p: Province = entry[2]
			if _built_out.has(p.id):
				continue
			var id := _ai_building_for(p)
			if id == "":
				_built_out[p.id] = true  # until the province changes (touch)
				continue
			if world.get_country(tag).treasury >= building_cost(tag, id) + LOAN_SIZE * 2.0:
				start_building(tag, id, p)
			break


## AI realms build barracks: one when they keep a standing army, one more for
## every this many provinces, up to AI_MAX_BARRACKS.
const AI_PROVINCES_PER_BARRACKS := 25
const AI_MAX_BARRACKS := 4


## The first extraction building or manufactory a province could take ("" if none).
static func _ai_building_for(p: Province) -> String:
	for id: String in Buildings.CATALOGUE:
		var type := Buildings.type_of(id)
		if (type == "extraction" or type == "manufacture") and Buildings.unsuitable(id, p) == "":
			return id
	return ""
