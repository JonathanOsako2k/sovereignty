class_name LoansPanel
extends DrawerPanel
## Our loans: what we owe and at what interest, how far lenders will go, the
## rate a new loan would carry; borrowing, repaying a loan, and — as a last
## resort — declaring bankruptcy.

signal budget_requested
signal loan_requested
signal repay_requested(index: int)
signal bankruptcy_requested

var world: WorldState
var economy: EconomySystem
var clock: GameClock
var tag := ""

var _borrow_button: Button
var _bankrupt_button: Button


func _init() -> void:
	super()
	wide = true
	var back := UITheme.button("‹  Budget")
	back.pressed.connect(func(): budget_requested.emit())
	_footer.add_child(back)
	_borrow_button = UITheme.primary_button("")
	_borrow_button.clip_text = true
	_borrow_button.pressed.connect(func(): loan_requested.emit())
	_footer.add_child(_borrow_button)
	_bankrupt_button = UITheme.button("Declare bankruptcy")
	_bankrupt_button.add_theme_color_override("font_color", UITheme.DANGER)
	_bankrupt_button.pressed.connect(func(): bankruptcy_requested.emit())
	_footer.add_child(_bankrupt_button)


func show_loans(p_world: WorldState, p_economy: EconomySystem, p_tag: String) -> void:
	world = p_world
	economy = p_economy
	clock = economy.clock
	tag = p_tag
	refresh()


func refresh() -> void:
	var c := world.get_country(tag) if world else null
	if c == null:
		return
	_set_header(c.name, "Loans", MapModes.country_color(world, tag))
	var interest := 0.0
	for l: Array in c.loans:
		interest += l[0] * l[1] / 12.0
	var rows := [
		["Debt", "%s ducats" % DrawerPanel.thousands(roundi(c.debt))],
		["Interest", "%.1f a month" % interest],
		["Lenders' limit", "%s ducats" % DrawerPanel.thousands(roundi(economy.credit_limit(tag)))],
		["A new loan", "%.1f %% a year" % (economy.interest_rate(tag) * 100.0)],
	]
	if c.bankrupt_until > clock.day_number():
		rows.append(["Credit", "None until %s" % _date(c.bankrupt_until)])
	_set_rows(rows)
	_clear_extra()
	_section_title("Our loans")
	if c.loans.is_empty():
		_extra.add_child(UITheme.label("We owe nothing.", 15, UITheme.TEXT_DIM))
	for i in c.loans.size():
		var l: Array = c.loans[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var what := UITheme.label("%d ducats at %.1f %%\ntaken %s" % [int(l[0]), l[1] * 100.0, _date(int(l[2]))], 14)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		var repay := UITheme.button("Repay")
		var why := economy.repay_blocked(tag, i)
		repay.disabled = why != ""
		repay.tooltip_text = why
		var index := i
		repay.pressed.connect(func(): repay_requested.emit(index))
		row.add_child(repay)
		_extra.add_child(row)
	var blocked := economy.loan_blocked(tag)
	_borrow_button.text = "Borrow %d at %.1f %%" % [int(EconomySystem.LOAN_SIZE), economy.interest_rate(tag) * 100.0] if blocked == "" else blocked
	_borrow_button.disabled = blocked != ""
	_bankrupt_button.disabled = c.loans.is_empty()


## A day number as a date ("12 March 1593").
static func _date(day_number: int) -> String:
	var y := GameClock.EPOCH_YEAR
	var d := maxi(day_number, 0)
	while d >= (366 if GameClock.is_leap_year(y) else 365):
		d -= 366 if GameClock.is_leap_year(y) else 365
		y += 1
	var m := 1
	while d >= GameClock.days_in_month(y, m):
		d -= GameClock.days_in_month(y, m)
		m += 1
	return "%d %s %d" % [d + 1, GameClock.MONTH_NAMES[m - 1], y]
