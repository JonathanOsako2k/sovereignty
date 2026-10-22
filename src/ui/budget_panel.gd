class_name BudgetPanel
extends DrawerPanel
## A country's finances: treasury, debt and inflation; next month's budget
## line by line (taxes by estate, customs, tribute, minting; administration,
## court, forts, interest); what actually moved last month (the ledger: every
## change has a name); and, for our own country, the policies that set them —
## tax levels per estate, court maintenance, minting, fort maintenance — with
## each estate's goodwill.

signal country_requested(tag: String)
signal loans_requested
signal policy_changed(policy: String, index: int, step: int)
signal military_requested

var world: WorldState
var economy: EconomySystem
var tag := ""
var player_tag := ""

var _back_button: Button
var _loans_button: Button


func _init() -> void:
	super()
	wide = true
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_footer.add_child(row)
	_back_button = UITheme.button("‹  Country")
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button.pressed.connect(func(): country_requested.emit(tag))
	row.add_child(_back_button)
	_loans_button = UITheme.button("Loans  ›")
	_loans_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loans_button.pressed.connect(func(): loans_requested.emit())
	row.add_child(_loans_button)


func show_budget(p_world: WorldState, p_economy: EconomySystem, p_tag: String) -> void:
	world = p_world
	economy = p_economy
	tag = p_tag
	refresh()


func refresh() -> void:
	if _dragging:
		_refresh_held = true
		return
	var c := world.get_country(tag) if world else null
	if c == null:
		return
	var own := tag == player_tag
	_set_header(c.name, "Budget", MapModes.country_color(world, tag))
	var b := economy.budget(tag)
	_set_rows([
		["Treasury", "%s ducats" % _money(c.treasury)],
		["Debt", "%s ducats" % _money(c.debt) if c.debt > 0.0 else "None"],
		["Monthly balance", _signed_label(b.net, 18)],
		["Inflation", "%.1f %%" % c.inflation],
	])
	_clear_extra()
	if own:
		_policies(c)  # what the player came to change, first
	_section_title("Next month")
	_lines(b.income, 1.0)
	_lines(b.expenses, -1.0)
	_total(b.net)
	if not own:
		_estates_view(c)
	_section_title("Last month")
	if c.ledger.is_empty():
		_note("No accounts yet: the first month is still under way.")
	else:
		var sum := 0.0
		for e: Array in c.ledger:
			sum += e[1]
		_lines(c.ledger, 1.0)
		_total(sum)
	_loans_button.visible = own


# --- Policies ----------------------------------------------------------------------

func _policies(c: Country) -> void:
	_section_title("Taxes by estate")
	for i in Estates.ROLES.size():
		var role: String = Estates.ROLES[i]
		if not Estates.taxable(role):
			var head := HBoxContainer.new()
			var name_label := UITheme.label(Estates.display(role), 17)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(name_label)
			head.add_child(UITheme.label("Exempt", 17, UITheme.TEXT_DIM))
			_extra.add_child(head)
			_note("The Church cannot be taxed (for now) · %s" % _goodwill_text(c, i))
			continue
		var tax := _line_amount(economy.budget(tag).income, EconomySystem.TAXES % Estates.display(role))
		var top: int = Estates.TAX_MAX[role]
		var percents := []
		for x in top + 1:
			percents.append("%d %%" % x)
		_policy(Estates.display(role), percents, "tax", i, c.tax_rates[i],
			"%+.1f a month · custom %d %%, at most %d %% · %s" % [tax, Estates.CUSTOMARY_TAX[role], top, _goodwill_text(c, i)],
			top / 5 + 1)
	_section_title("Spending and coin")
	var s: Dictionary = c.spending
	_spending("court", s.court, "A %s's court: %s + %d %% of taxes%s · costs ×%.2f · legitimacy %+.2f a month · nobles' goodwill %+d" % [
		Ranks.name_of(c.rank).to_lower(), str(snappedf(Ranks.COURT_BASE[c.rank], 0.01)),
		roundi(Ranks.COURT_SHARE[c.rank] * 100.0), " (half: tribal)" if c.government_type == "tribal" else "",
		Policies.court_cost(s.court), Policies.court_legitimacy(s.court), int(round(Policies.court_nobles(s.court)))])
	_spending("mint", s.mint, "+%d %% of tax income · inflation %+.2f a month" % [s.mint, Policies.mint_inflation(s.mint)]
		if s.mint > 0 else "No coin minted · inflation eases %.2f a month" % EconomySystem.INFLATION_EASING)
	_spending("forts", s.forts, "Upkeep ×%.2f · a fort of ours holds out about %d days" % [
		Policies.upkeep_cost(s.forts), int(Policies.fort_days(s.forts))])
	var military := UITheme.link_button("Army and navy maintenance: Military tab")
	military.alignment = HORIZONTAL_ALIGNMENT_LEFT
	military.pressed.connect(func(): military_requested.emit())
	_extra.add_child(military)
	var colonies := 0
	for p: Province in world.ownable_provinces():
		if p.colonist == tag:
			colonies += 1
	var level := c.colonial_policy
	_policy("Colonial policy", Colonisation.POLICIES, "colonial", 0, level,
		"%d of %d colonies · %s · office %.0f ducats a month" % [colonies, Colonisation.POLICY_COLONIES[level],
			"overseas too" if Colonisation.POLICY_OVERSEAS[level] else ("frontier and straits only" if level > 0 else "no settlers sent"),
			Colonisation.POLICY_UPKEEP[level]])


func _goodwill_text(c: Country, i: int) -> String:
	var now := int(round(c.satisfaction[i]))
	var target := int(round(economy.satisfaction_target(c, i)))
	return "Goodwill %d → %d" % [now, target] if target != now else "Goodwill %d" % now


## A policy slider (levels named by `levels`).
func _policy(title: String, levels: Array, policy: String, index: int, level: int, about: String, ticks := -1) -> void:
	_slider_row(title, levels, level, about, func(step: int): policy_changed.emit(policy, index, step), ticks)


func _spending(policy: String, value: int, about: String) -> void:
	_spending_slider(policy, value, about, func(step: int): policy_changed.emit(policy, 0, step))


static func _line_amount(lines: Array, label: String) -> float:
	for l: Array in lines:
		if l[0] == label:
			return l[1]
	return 0.0


func _estates_view(c: Country) -> void:
	_section_title("Estates")
	for i in Estates.ROLES.size():
		var row := HBoxContainer.new()
		var name_label := UITheme.label(Estates.display(Estates.ROLES[i]), 15, UITheme.TEXT_DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var level: String = "taxed %d %%" % c.tax_rates[i] if Estates.taxable(Estates.ROLES[i]) else "exempt"
		row.add_child(UITheme.label("%s · goodwill %d" % [level, int(c.satisfaction[i])], 15))
		_extra.add_child(row)


# --- Lines -----------------------------------------------------------------------------

func _lines(lines: Array, sign: float) -> void:
	for l: Array in lines:
		var row := HBoxContainer.new()
		var name_label := UITheme.label(l[0], 15, UITheme.TEXT_DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)
		if float(l[1]) != 0.0 or sign > 0.0:
			row.add_child(_signed_label(sign * float(l[1]), 15))
		_extra.add_child(row)


func _total(amount: float) -> void:
	var row := HBoxContainer.new()
	var name_label := UITheme.label("Balance", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_signed_label(amount, 16))
	_extra.add_child(row)


func _note(text: String) -> void:
	var l := UITheme.label(text, 13, UITheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	_extra.add_child(l)


static func _signed_label(amount: float, size: int) -> Label:
	var color := UITheme.TEXT
	if amount > 0.05:
		color = Color(0.55, 0.82, 0.48)
	elif amount < -0.05:
		color = UITheme.DANGER
	return UITheme.label("%+.1f" % amount, size, color)


static func _money(amount: float) -> String:
	return DrawerPanel.thousands(roundi(amount))
