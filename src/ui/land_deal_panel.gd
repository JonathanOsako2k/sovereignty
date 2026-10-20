class_name LandDealPanel
extends DrawerPanel
## A land deal we put to another country (from its panel): buying land of
## theirs, selling land of ours to them, or exchanging land — ours for theirs,
## with money either way to even it out. While it is open a tap on the map
## picks the land: theirs to ask for (bright green), ours to give (bright red).
## The panel shows what each province is worth, every reason they weigh, and
## whether they would accept. Propose it.

signal proposed(to: String, deal: Dictionary)
## Province id -> colour for the map while the deal is open ({} clears it).
signal highlights_changed(highlights: Dictionary)

enum Kind { BUY, SELL, EXCHANGE }

const GAIN := Color(0.15, 0.95, 0.25)
const LOSS := Color(1.0, 0.15, 0.15)
const GUTTER := 44
const MONEY_STEP := 10

var world: WorldState
var deals: LandDeals
var player_tag := ""
var to := ""
## What kind of deal: buying their land, selling ours, or exchanging.
var kind := Kind.BUY

var _take := {}  # province id -> true
var _give := {}
var _money := 0
var _propose: Button


func _init() -> void:
	super()
	wide = true
	set_scroll_gutter(GUTTER)
	_propose = UITheme.primary_button("Propose")
	_propose.pressed.connect(func(): proposed.emit(to, deal()))
	_footer.add_child(_propose)
	visibility_changed.connect(func():
		if not visible:
			highlights_changed.emit({}))


func show_deal(p_world: WorldState, p_deals: LandDeals, p_player: String, p_to: String, p_kind: int) -> void:
	world = p_world
	deals = p_deals
	player_tag = p_player
	to = p_to
	kind = p_kind as Kind
	_take.clear()
	_give.clear()
	_money = 0
	refresh()


func deal() -> Dictionary:
	return {"take": _ids(_take), "give": _ids(_give), "money": _money}


static func _ids(table: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for id: int in table:
		out.append(id)
	out.sort()
	return out


## A tap on the map: their province to ask for (again: let it go), ours to
## give. A message when the tap is not part of the deal.
func toggle_province(id: int) -> String:
	var p := world.get_province(id) if world else null
	if p == null or p.is_sea or p.is_wasteland:
		return "Not land"
	if p.owner_id == to:
		if kind == Kind.SELL:
			return "Selling: tap our land (to get theirs too, exchange territory instead)"
		if not _take.erase(id):
			_take[id] = true
	elif p.owner_id == player_tag:
		if kind == Kind.BUY:
			return "Buying: tap their land (to trade ours too, exchange territory instead)"
		if not _give.erase(id):
			_give[id] = true
	else:
		return "%s is neither theirs nor ours" % p.name
	refresh()
	return ""


func refresh() -> void:
	if _dragging:
		_refresh_held = true
		return
	if world == null:
		return
	var them := world.get_country(to)
	var us := world.get_country(player_tag)
	_clear_extra()
	if them == null or us == null:
		_set_header("Land", "", MapModes.UNCOLONISED)
		_set_rows([])
		_propose.disabled = true
		return
	# Land that has changed hands since is dropped.
	for id: int in _take.keys():
		if world.get_province(id).owner_id != to:
			_take.erase(id)
	for id: int in _give.keys():
		if world.get_province(id).owner_id != player_tag:
			_give.erase(id)
	var titles := {Kind.BUY: "Buy land from %s", Kind.SELL: "Sell land to %s", Kind.EXCHANGE: "Exchange land with %s"}
	var taps := {Kind.BUY: "their land green", Kind.SELL: "our land red", Kind.EXCHANGE: "their land green, ours red"}
	_set_header(titles[kind] % them.name, "Tap the map: " + taps[kind], MapModes.country_color(world, to))
	var d := deal()
	var why := deals.blocked(player_tag, to, d)
	var v := deals.evaluate(player_tag, to, d)
	var rows := []
	if kind != Kind.SELL:
		rows.append(["Their land asked", "worth ≈ %d" % int(v.worth) if not _take.is_empty() else "none yet"])
	if kind != Kind.BUY:
		var land := 0.0
		for id: int in _give:
			land += deals.worth_to(world.get_province(id), to)
		rows.append(["Our land, to them", "worth ≈ %d" % int(land) if not _give.is_empty() else "none yet"])
	rows.append(["Money", "we pay %s" % DrawerPanel.thousands(_money) if _money > 0 else ("they pay %s" % DrawerPanel.thousands(-_money)
		if _money < 0 else "none")])
	rows.append(["They would", why if why != "" else ("accept (%+d)" % v.total if v.accept else "refuse (%+d)" % v.total)])
	_set_rows(rows)
	if kind != Kind.SELL:
		_section_title("Their land we ask for")
		if _take.is_empty():
			_hint("Tap provinces of theirs on the map.")
		for id: int in _ids(_take):
			_province_row(world.get_province(id), "worth ≈ %d" % int(deals.worth(world.get_province(id))), _take)
	if kind != Kind.BUY:
		_section_title("Our land we give")
		if _give.is_empty():
			_hint("Tap provinces of ours on the map.")
		for id: int in _ids(_give):
			var p := world.get_province(id)
			_province_row(p, "worth ≈ %d to them" % int(deals.worth_to(p, to)), _give)

	_section_title("Money")
	var low := -int(maxf(them.treasury, 0.0)) / MONEY_STEP * MONEY_STEP if kind != Kind.BUY else 0
	var high := int(maxf(us.treasury, 0.0)) / MONEY_STEP * MONEY_STEP if kind != Kind.SELL else 0
	_money = clampi(_money, low, high)
	# The slider's steps in reading order: selling, from nothing to all they
	# have; otherwise from what they would pay us to what we would pay.
	var steps: Array[int] = []
	if kind == Kind.SELL:
		for m in range(0, low - 1, -MONEY_STEP):
			steps.append(m)
	else:
		for m in range(low, high + 1, MONEY_STEP):
			steps.append(m)
	var names := []
	for m: int in steps:
		names.append("We pay %s" % DrawerPanel.thousands(m) if m > 0 else ("They pay us %s" % DrawerPanel.thousands(-m) if m < 0
			else "No money"))
	var limits := {Kind.BUY: "Up to our treasury (%s)" % DrawerPanel.thousands(high),
		Kind.SELL: "Up to their treasury (%s)" % DrawerPanel.thousands(-low),
		Kind.EXCHANGE: "Up to our treasury (%s), or theirs (%s) to us" % [DrawerPanel.thousands(high), DrawerPanel.thousands(-low)]}
	_slider_row("Ducats", names, maxi(steps.find(_money), 0), limits[kind],
		func(step: int):
			_money = steps[clampi(maxi(steps.find(_money), 0) + step, 0, steps.size() - 1)]
			refresh(), mini(names.size(), 11))
	if not _take.is_empty() or not _give.is_empty():
		var even := UITheme.button("Even it out")
		even.tooltip_text = "The money that makes what we offer equal to what it is worth to them"
		even.pressed.connect(func():
			var land := 0.0
			for id: int in _give:
				land += deals.worth_to(world.get_province(id), to)
			_money = clampi(int(round((v.worth - land) / MONEY_STEP)) * MONEY_STEP, low, high)
			refresh())
		_extra.add_child(even)

	_section_title("Their reasons")
	for r: Array in v.reasons:
		var row := HBoxContainer.new()
		var label := UITheme.label(r[0], 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 120
		row.add_child(label)
		row.add_child(UITheme.label("%+d" % r[1], 15, UITheme.ACCENT if r[1] >= 0 else UITheme.DANGER))
		_extra.add_child(row)

	var colours := {}
	for id: int in _take:
		colours[id] = GAIN
	for id: int in _give:
		colours[id] = LOSS
	highlights_changed.emit(colours)
	_propose.disabled = why != ""
	_propose.text = "Propose" if v.accept else "Propose (they would refuse)"


func _province_row(p: Province, detail: String, table: Dictionary) -> void:
	var b := UITheme.button("☑  %s  —  %s" % [p.name, detail], true)
	b.set_pressed_no_signal(true)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.toggled.connect(func(_on: bool):
		table.erase(p.id)
		refresh())
	_extra.add_child(b)


func _hint(text: String) -> void:
	var l := UITheme.label(text, 13, UITheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	_extra.add_child(l)
