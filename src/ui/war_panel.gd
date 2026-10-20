class_name WarPanel
extends Control
## One of our wars, as a pop-up in the middle of the screen (its badge under
## the top bar opens it; the game pauses): how it stands and how long it has
## lasted; our side on the left and theirs on the right — each belligerent
## (leaders first, marked) with an estimate of the men it has under arms, each
## side's total — and who stayed out. Peace is sued for with a country of
## theirs: between the two leaders it ends the war; between a leader and
## anyone else on the other side, that one leaves the war. A tap outside, or
## ✕, closes it.

signal country_requested(tag: String)
signal treaty_requested(war_id: int, with: String)
## Closed: `resume` when simply dismissed (✕ or a tap outside), false when
## it led on to a country or the peace table.
signal closed(resume: bool)

const CARD_MAX := Vector2(980, 600)
const DIM := Color(0.04, 0.03, 0.02, 0.55)

var world: WorldState
var military: MilitarySystem
var player_tag := ""
var war_id := 0

var _card: PanelContainer
var _title: Label
var _subtitle: Label
var _facts: Label
var _ours: VBoxContainer
var _theirs: VBoxContainer
var _ours_head: Label
var _theirs_head: Label
var _footer: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close())
	add_child(dim)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	_title = UITheme.label("", 26, UITheme.ACCENT)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(_title)
	_subtitle = UITheme.label("", 15, UITheme.TEXT_DIM)
	titles.add_child(_subtitle)
	var x := UITheme.button("✕")
	x.pressed.connect(close)
	head.add_child(x)
	_facts = UITheme.label("", 17)
	box.add_child(_facts)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	var left := _column(columns)
	_ours_head = left[0]
	_ours = left[1]
	columns.add_child(VSeparator.new())
	var right := _column(columns)
	_theirs_head = right[0]
	_theirs = right[1]

	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 4)
	box.add_child(_footer)


## A side's column: its heading, then a scrolling list.
func _column(parent: Control) -> Array:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	var heading := UITheme.label("", 19, UITheme.ACCENT)
	col.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	return [heading, list]


func show_war(p_world: WorldState, p_military: MilitarySystem, p_war_id: int, p_player: String) -> void:
	world = p_world
	military = p_military
	war_id = p_war_id
	player_tag = p_player
	visible = true
	refresh()


func close(resume := true) -> void:
	if visible:
		visible = false
		closed.emit(resume)


## Centres the card in the screen below `top` (the top bar's bottom edge).
func layout(top := 0.0) -> void:
	var vs := get_viewport_rect().size
	var room := Vector2(vs.x - 32.0, vs.y - top - 24.0)
	_card.size = Vector2(minf(CARD_MAX.x, room.x), minf(CARD_MAX.y, room.y))
	_card.position = Vector2((vs.x - _card.size.x) * 0.5, top + 8.0 + (room.y - _card.size.y) * 0.5)


func refresh() -> void:
	if world == null or not visible:
		return
	var war := world.military.get_war(war_id)
	var side := Military.side_of(war, player_tag) if not war.is_empty() else -1
	for list: VBoxContainer in [_ours, _theirs]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	for child in _footer.get_children():
		_footer.remove_child(child)
		child.queue_free()
	if side < 0:
		_title.text = "War"
		_subtitle.text = "Over for us"
		_facts.text = ""
		_ours_head.text = ""
		_theirs_head.text = ""
		return
	var ours: Array = war.attackers if side == 0 else war.defenders
	var theirs: Array = war.defenders if side == 0 else war.attackers
	var men := _men_under_arms()
	_title.text = war.name
	_subtitle.text = "We %s · the game is paused" % ("attacked" if side == 0 else "were attacked")
	var months := (military.clock.day_number() - int(war.start)) / 30
	_facts.text = "Our war score %+d  ·  lasted %s" % [int(military.score_for(war, player_tag)),
		("%d month%s" % [months, "" if months == 1 else "s"]) if months < 24 else "%d years" % (months / 12)]
	_ours_head.text = "Our side  ·  ≈ %s men" % _short(_total(ours, men))
	_theirs_head.text = "Their side  ·  ≈ %s men" % _short(_total(theirs, men))
	for tag: String in ours:
		_ours.add_child(_row(war, tag, men, false))
	for tag: String in theirs:
		_theirs.add_child(_row(war, tag, men, true))
	if not war.get("refused", []).is_empty():
		var names: Array = war.refused.map(func(t: String) -> String: return MilitarySystem.short_name(world, t))
		_note("Stayed out (disloyal vassals): " + ", ".join(names))
	_note("Peace with their leader ends the war; with anyone else on their side, that one leaves it." if military.is_war_leader(war, player_tag)
		else "We do not lead our side: peace with their leader takes us out of the war on our own.")


func _row(war: Dictionary, tag: String, men: Dictionary, enemy: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lead := military.is_war_leader(war, tag)
	var link := UITheme.link_button(MilitarySystem.short_name(world, tag) + (" (us)" if tag == player_tag else "")
		+ (" — leader" if lead else ""))
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	link.add_theme_font_size_override("font_size", 16)
	link.pressed.connect(func():
		close(false)
		country_requested.emit(tag))
	row.add_child(link)
	row.add_child(UITheme.label(("" if tag == player_tag else "≈ ") + _short(men.get(tag, 0)), 15, UITheme.TEXT_DIM))
	if enemy:
		var sue := UITheme.button("Sue for peace")
		sue.add_theme_font_size_override("font_size", 14)
		var why := military.treaty_blocked(war, player_tag, {"with": tag})
		sue.disabled = why != ""
		sue.tooltip_text = why if why != "" else ("Ends the war" if military.is_full_peace(war, player_tag, tag)
			else "A separate peace: they leave the war")
		sue.pressed.connect(func():
			close(false)
			treaty_requested.emit(war_id, tag))
		row.add_child(sue)
	return row


func _note(text: String) -> void:
	var l := UITheme.label(text, 13, UITheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	_footer.add_child(l)


## Men each country has in its armies (aboard ship too): tag -> men.
func _men_under_arms() -> Dictionary:
	var out := {}
	for a: Army in world.military.armies.values():
		if not a.navy:
			out[a.owner] = out.get(a.owner, 0) + a.men()
	return out


static func _total(tags: Array, men: Dictionary) -> int:
	var total := 0
	for t: String in tags:
		total += men.get(t, 0)
	return total


## An estimate: to the nearest thousand ("12k"), or hundreds below that.
static func _short(n: int) -> String:
	if n >= 1000:
		return "%dk" % roundi(n / 1000.0)
	return "%d" % (roundi(n / 100.0) * 100)
