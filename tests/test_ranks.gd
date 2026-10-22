extends "res://tests/test_case.gd"
## Ranks — county, duchy, minor kingdom, major kingdom, empire: what each
## realm is in 1590, the court each is expected to keep (less for tribes and
## colonies), the land it governs in full and the ties and envoys it keeps,
## and rising a rank.


func _setup() -> Array:  # [campaign, economy, diplomacy actions, nation system]
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	var c := Campaign.new(world)
	var economy := EconomySystem.new(c)
	return [c, economy, DiplomacyActions.new(c), NationSystem.new(c, economy)]


func _line(lines: Array, label: String) -> float:
	for l: Array in lines:
		if l[0] == label:
			return l[1]
	return 0.0


func test_the_ranks_of_1590() -> void:
	var w: WorldState = _setup()[0].world
	for tag: String in ["MNG", "MUG", "TUR", "SPA", "AUS", "SAF"]:
		check_eq(w.get_country(tag).rank, Ranks.EMPIRE, "%s an empire" % tag)
	for tag: String in ["FRA", "ENG", "PLC", "RUS", "JAP"]:
		check_eq(w.get_country(tag).rank, Ranks.MAJOR_KINGDOM, "%s a major kingdom" % tag)
	check_eq(w.get_country("BRA").rank, Ranks.MINOR_KINGDOM, "an elector of its size: a minor kingdom")
	check_eq(w.get_country("BAV").rank, Ranks.DUCHY, "Bavaria, however large, a duchy by title")
	check_eq(w.get_country("MRI").rank, Ranks.DUCHY, "a daimyo no more than a duchy")
	check_eq(w.get_country("EFR").rank, Ranks.COUNTY, "East Frisia a county")
	check_eq(w.get_country("KED").rank, Ranks.COUNTY, "Kedah, one province, a county")
	for tag: String in w.created:
		check(w.get_country(tag).rank <= Ranks.COLONY_MAX, "%s no higher than a colony may be" % w.get_country(tag).name)


func test_the_court_follows_rank_and_taxes() -> void:
	var s := _setup()
	var w: WorldState = s[0].world
	var e: EconomySystem = s[1]
	for tag: String in ["ENG", "KED", "KZH", "SPA"]:
		var c := w.get_country(tag)
		var b := e.budget(tag)
		var want := Ranks.court(c.rank, b.tax_income, c.government_type, false) * Policies.court_cost(c.spending.court) \
			* (1.0 + c.inflation / 100.0)
		check(is_equal_approx(_line(b.expenses, EconomySystem.COURT), want), "%s keeps the court of its rank" % tag)
	check(_line(e.budget("KED").expenses, EconomySystem.COURT) < e.budget("KED").tax_income * 0.5,
		"a petty sultan's household costs less than half his taxes")
	check(e.budget("KED").net > 0.0, "and Kedah pays its way")
	check(is_equal_approx(Ranks.court(Ranks.MINOR_KINGDOM, 10.0, "tribal", false),
		Ranks.court(Ranks.MINOR_KINGDOM, 10.0, "monarchy", false) * Ranks.TRIBAL_COURT), "tribes keep a cheaper court")
	check(Ranks.court(Ranks.EMPIRE, 100.0, "monarchy", false) > Ranks.court(Ranks.MAJOR_KINGDOM, 100.0, "monarchy", false),
		"an empire is expected to spend more than a kingdom on the same taxes")
	var colony: String = w.created[0]
	var cb := e.budget(colony)
	var cc := w.get_country(colony)
	check(is_equal_approx(_line(cb.expenses, EconomySystem.COURT), Ranks.court(cc.rank, cb.tax_income, cc.government_type,
		true) * Policies.court_cost(cc.spending.court) * (1.0 + cc.inflation / 100.0)), "a colony keeps a viceroy's household")


func test_governance_beyond_rank_costs_taxes() -> void:
	var s := _setup()
	var w: WorldState = s[0].world
	var e: EconomySystem = s[1]
	check(e.development_of("MNG") > Ranks.governance(Ranks.EMPIRE, 1590), "the Ming hold more than an empire governs in full")
	check(e.governance_efficiency("MNG") < 1.0 and e.governance_efficiency("MNG") >= Ranks.OVERSTRETCH_MIN,
		"and collect less of their taxes")
	check_eq(e.governance_efficiency("ENG"), 1.0, "England governs all its land")
	# A province's taxes and the budget agree.
	var sum := 0.0
	for p: Province in w.ownable_provinces():
		if p.owner_id == "MNG" and p.controller_id == "MNG":
			for r: String in Estates.ROLES:
				sum += e.province_taxes(p).get(r, 0.0)
	check(absf(sum - e.budget("MNG").tax_income) < 0.01, "province taxes add up to the budget's (%.2f, %.2f)" % [sum,
		e.budget("MNG").tax_income])
	# Governance grows with the ages.
	check(Ranks.governance(Ranks.DUCHY, 1800) > Ranks.governance(Ranks.DUCHY, 1590), "the age governs more")
	# The rank sets the land governed in full: Bavaria as a mere county would be overstretched.
	var before: float = e.budget("MNG").tax_income
	w.get_country("MNG").rank = Ranks.EMPIRE
	w.get_country("BAV").rank = Ranks.COUNTY
	e.changed()
	check(e.governance_efficiency("BAV") < 1.0, "a duchy's land is too much for a county")
	check(is_equal_approx(e.budget("MNG").tax_income, before), "unchanged at the same rank")


func test_ties_and_envoys_by_rank() -> void:
	var s := _setup()
	var w: WorldState = s[0].world
	var acts: DiplomacyActions = s[2]
	var A := DiplomacyActions.Action
	var d := w.diplomacy
	check_eq(acts.envoys_max("KED"), 1, "a county sends one envoy")
	check_eq(acts.envoys_max("TUR"), 4, "an empire four")
	check_eq(acts.ties_max("SPA"), Ranks.TIES[Ranks.EMPIRE], "an empire keeps many ties")
	# Spain: allies, marriages, Portugal in union, the League's subsidy; not its colonies.
	var kinds := Ranks.ties_of(d, "SPA").map(func(t: Array) -> String: return t[0])
	check("subsidy" in kinds and "subject" in kinds and "ally" in kinds, "Spain's ties: %s" % [kinds])
	for t: Array in Ranks.ties_of(d, "SPA"):
		check(d.subject_type(t[1]) != "colony", "colonies are not courted")
	# A county with all the ties it can keep takes on no more.
	acts.perform(A.IMPROVE_RELATIONS, "KED", "ACE")
	check(acts.blocked(A.IMPROVE_RELATIONS, "KED", "JOH").contains("one envoy"), "one envoy, busy")
	d.set_allied("KED", "PAT", true)
	d.set_allied("KED", "PRK", true)
	check(acts.blocked(A.PROPOSE_ALLIANCE, "KED", "JOH").contains("stretched"), "a county keeps two ties")
	check(acts.blocked(A.PROPOSE_ALLIANCE, "JOH", "KED").contains("Kedah"), "nor can others bind it")
	check(acts.subsidy_blocked("KED", "JOH", 5).contains("stretched"), "nor pay a new subsidy")
	check_eq(acts.subsidy_blocked("SPA", "LEA", 20), "", "changing a subsidy is no new tie")
	# Beyond its limit, its subjects grow less loyal.
	var japan := acts.ties("JAP")
	check(japan > acts.ties_max("JAP"), "Hideyoshi's daimyo are more than a kingdom's ties (%d)" % japan)
	var reasons: Array = acts.loyalty_reasons(d.subjects_of("JAP")[0])
	check(reasons.any(func(r: Array) -> bool: return String(r[0]).contains("beyond its rank")), "the daimyo feel it")


func test_rising_a_rank() -> void:
	var s := _setup()
	var c: Campaign = s[0]
	var w := c.world
	var e: EconomySystem = s[1]
	var nations: NationSystem = s[3]
	var bav := w.get_country("BAV")
	bav.treasury = 50.0
	check(nations.rank_blocked("BAV").begins_with("Needs"), "a crown costs money")
	bav.treasury = 1000.0
	bav.legitimacy = 60.0
	check_eq(nations.rank_blocked("BAV"), "", "Bavaria has the land for a kingdom")
	var court := _line(e.budget("BAV").expenses, EconomySystem.COURT)
	var cost := nations.raise_cost("BAV")
	check(nations.raise_rank("BAV"), "crowned")
	check_eq(bav.rank, Ranks.MINOR_KINGDOM, "a kingdom now")
	check(is_equal_approx(bav.treasury, 1000.0 - cost), "the coronation paid")
	check(is_equal_approx(bav.legitimacy, 60.0 + Ranks.RAISE_LEGITIMACY_GAIN), "and its legitimacy the higher")
	check(_line(e.budget("BAV").expenses, EconomySystem.COURT) > court, "a dearer court")
	check(bav.ledger.any(func(l: Array) -> bool: return String(l[0]).begins_with("Coronation")), "in the ledger")
	check(nations.rank_blocked("BAV").contains("development"), "a major kingdom needs more land")
	# Subjects never reach their overlord's rank; colonies stop at a minor kingdom.
	w.get_country("CRL").treasury = 1000.0
	w.get_country("CRL").rank = Ranks.MINOR_KINGDOM
	w.get_country("PLC").rank = Ranks.MAJOR_KINGDOM
	check(nations.rank_blocked("CRL").contains("overlord"), "not to its overlord's rank")
	var colony := w.get_country(w.created[0])
	colony.rank = Ranks.COLONY_MAX
	check(nations.rank_blocked(colony.id).contains("colony"), "a colony rises no higher")
	check(nations.rank_blocked("MNG").contains("no higher"), "nor does an empire")
	# The AI rises when it can pay twice over and stay in surplus.
	var sav := w.get_country("SAV")
	sav.treasury = 2000.0
	sav.legitimacy = 75.0
	w.get_country("BAV").treasury = 0.0
	if e.development_of("SAV") >= Ranks.DEVELOPMENT[Ranks.MINOR_KINGDOM]:
		nations.ai_yearly("ENG")
		check_eq(sav.rank, Ranks.MINOR_KINGDOM, "Savoy is crowned")
	# The rank is saved; an older save without one gets the start's.
	var state := w.campaign_state()
	check_eq(int(state.countries.BAV.rank), Ranks.MINOR_KINGDOM, "saved")
	var copy: Dictionary = JSON.parse_string(JSON.stringify(state, "", false, true))
	copy.countries.BAV.erase("rank")
	check(w.restore_campaign_state(copy).is_empty(), "an older save loads")
	check_eq(w.get_country("BAV").rank, Ranks.DUCHY, "with the start's rank")
	copy.countries.BAV.rank = 7
	check(not w.restore_campaign_state(copy).is_empty(), "no such rank")
