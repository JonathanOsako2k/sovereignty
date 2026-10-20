class_name PeaceTreatyPanel
extends DrawerPanel
## A peace treaty of our making with a country we fight (opened from its own
## panel): between the two sides' leaders it ends the war; between a leader
## and anyone else on the other side, that one leaves the war. On the map, while this is open, a tap picks land: theirs to
## demand (bright green), ours to give (bright red); paler, what each side
## holds of the other's. Here: reparations, their forts to pull down, their
## vassalage, their subjects set free or made ours, their alliances broken.
## Each demand costs war score and what we give is worth some; the panel shows
## the sums and whether they would sign. Propose it, or surrender to them.

signal treaty_proposed(war_id: int, treaty: Dictionary)
signal surrender_requested(war_id: int, with: String)
## Province id -> colour for the map while the treaty is open ({} clears it).
signal highlights_changed(highlights: Dictionary)

const GAIN := Color(0.15, 0.95, 0.25)
const LOSS := Color(1.0, 0.15, 0.15)
const MAY_GAIN := Color(0.55, 0.78, 0.55)
const MAY_LOSE := Color(0.85, 0.55, 0.55)
## Room right of the list to scroll it with a thumb without touching a toggle.
const GUTTER := 44

var world: WorldState
var military: MilitarySystem
var player_tag := ""
var war_id := 0
var with_tag := ""

var _demand := {}  # province id -> true
var _give := {}
var _forts := {}
var _money := 0
var _subjugate := false
var _release := {}  # tag -> true
var _transfer := {}
var _break := {}
var _propose: Button
var _surrender: Button


func _init() -> void:
	super()
	wide = true
	set_scroll_gutter(GUTTER)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_footer.add_child(row)
	_surrender = UITheme.button("Surrender")
	_surrender.add_theme_color_override("font_color", UITheme.DANGER)
	_surrender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surrender.pressed.connect(func(): surrender_requested.emit(war_id, with_tag))
	row.add_child(_surrender)
	_propose = UITheme.primary_button("Propose peace")
	_propose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_propose.pressed.connect(func(): treaty_proposed.emit(war_id, treaty()))
	row.add_child(_propose)
	visibility_changed.connect(func():
		if not visible:
			highlights_changed.emit({}))


## Opens a fresh treaty (with `with`, else their leader): the land of theirs
## our side holds asked for, nothing else.
func show_treaty(p_world: WorldState, p_military: MilitarySystem, p_war_id: int, p_player: String, p_with := "") -> void:
	world = p_world
	military = p_military
	war_id = p_war_id
	player_tag = p_player
	var war := world.military.get_war(war_id)
	with_tag = p_with if p_with != "" or war.is_empty() else military.treaty_with(war, player_tag, {})
	_reset_terms(war)
	refresh()


func _reset_terms(war: Dictionary) -> void:
	_demand.clear()
	_give.clear()
	_forts.clear()
	_money = 0
	_subjugate = false
	_release.clear()
	_transfer.clear()
	_break.clear()
	if war.is_empty() or with_tag == "":
		return
	for p: Province in military.held_by(war, Military.side_of(war, player_tag)):
		if _theirs(war, p.owner_id):
			_demand[p.id] = true


func _full(war: Dictionary) -> bool:
	return military.is_full_peace(war, player_tag, with_tag)


## Whether land of `owner` is theirs to give up (their side's, between leaders).
func _theirs(war: Dictionary, owner: String) -> bool:
	if _full(war):
		return owner != "" and Military.side_of(war, owner) == 1 - Military.side_of(war, player_tag)
	return owner == with_tag


func _ours(war: Dictionary, owner: String) -> bool:
	if _full(war):
		return owner != "" and Military.side_of(war, owner) == Military.side_of(war, player_tag)
	return owner == player_tag


func treaty() -> Dictionary:
	var forts: Array[int] = []
	for id: int in _forts:
		if not _demand.has(id):
			forts.append(id)
	return {"with": with_tag, "provinces": _ids(_demand), "give": _ids(_give), "money": _money, "forts": forts,
		"subjugate": _subjugate, "release": _release.keys(), "transfer": _transfer.keys(), "break": _break.keys()}


static func _ids(table: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for id: int in table:
		out.append(id)
	out.sort()
	return out


## A tap on the map while the treaty is open: their province to demand
## (again: let it go), ours to give. A message when the tap is not part of it.
func toggle_province(id: int) -> String:
	var war := world.military.get_war(war_id) if world else {}
	if war.is_empty():
		return ""
	var p := world.get_province(id)
	if p == null or p.is_sea or p.is_wasteland or p.owner_id == "":
		return "Not part of this peace"
	if _theirs(war, p.owner_id):
		if _demand.erase(id):
			pass
		else:
			_demand[id] = true
			_give.erase(id)
	elif _ours(war, p.owner_id):
		if not _give.erase(id):
			_give[id] = true
	else:
		return "%s is not party to this peace" % world.get_country(p.owner_id).name
	refresh()
	return ""


func refresh() -> void:
	if _dragging:
		_refresh_held = true
		return
	if world == null:
		return
	var war := world.military.get_war(war_id)
	_clear_extra()
	if war.is_empty() or Military.side_of(war, player_tag) < 0:
		_set_header("Peace", "The war is over for us", MapModes.UNCOLONISED)
		_set_rows([])
		_propose.disabled = true
		_surrender.disabled = true
		highlights_changed.emit({})
		return
	if Military.side_of(war, with_tag) != 1 - Military.side_of(war, player_tag):
		with_tag = military.treaty_with(war, player_tag, {})  # they left the war
		_reset_terms(war)
	var full := _full(war)
	var them := world.get_country(with_tag)
	_set_header(war.name, "Peace with %s%s" % [them.name, "" if full else " — a separate peace"],
		MapModes.country_color(world, with_tag))
	var t := treaty()
	var score := military.peace_score(war, player_tag, with_tag)
	var cost := military.treaty_cost(war, player_tag, t)
	var value := military.treaty_value(war, player_tag, t)
	var why := military.treaty_blocked(war, player_tag, t)
	var accept := military.treaty_accepted(war, player_tag, t)
	var rows := [["Our war score", "%+d" % int(score)], ["What we ask costs", "%d" % int(ceil(cost))]]
	if value > 0.0:
		rows.append(["What we give is worth", "%d" % int(value)])
	rows.append(["They would", why if why != "" else ("sign" if accept else "refuse")])
	_set_rows(rows)

	if not full:
		_hint("A separate peace: %s leaves the war; the rest fight on." % world.get_country(
			with_tag if military.is_war_leader(war, player_tag) else player_tag).name)
	_hint("Tap the map: their land to demand (green), ours to give (red). Paler: what each side holds of the other's.")

	_section_title("We demand")
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 8)
	var all_held := UITheme.button("All of theirs we hold")
	all_held.pressed.connect(func():
		_reset_terms(war)
		refresh())
	quick.add_child(all_held)
	var none := UITheme.button("None")
	none.pressed.connect(func():
		_demand.clear()
		refresh())
	quick.add_child(none)
	_extra.add_child(quick)
	var their_dev := military.scope_development(war, with_tag, full, {})
	if _demand.is_empty():
		_hint("No land.")
	for id: int in _ids(_demand):
		var p := world.get_province(id)
		var held := Military.side_of(war, p.controller_id) == Military.side_of(war, player_tag)
		_province_row(p, "%d%s" % [int(ceil(military.province_cost(war, player_tag, p, their_dev))),
			"" if held else " (not held)"], _demand)
	if not _give.is_empty():
		_section_title("We give")
		for id: int in _ids(_give):
			_province_row(world.get_province(id), "", _give)

	_section_title("Reparations")
	var top := int(maxf(them.treasury, 0.0)) / 10 * 10
	if top <= 0:
		_hint("%s has no money to pay." % them.name)
	else:
		var names := []
		for v in range(0, top + 1, 10):
			names.append("%s ducats" % DrawerPanel.thousands(v))
		_money = mini(_money, top)
		_slider_row("They pay us", names, _money / 10, "Up to what they hold (%s ducats)" % DrawerPanel.thousands(top),
			func(step: int):
				_money = clampi(_money + step * 10, 0, top)
				refresh(), mini(names.size(), 11))

	_section_title("Pull down their forts")
	var any_fort := false
	for p: Province in world.ownable_provinces():
		if "fort" in p.buildings and _theirs(war, p.owner_id) and not _demand.has(p.id):
			any_fort = true
			_toggle_into(p.name, _forts, p.id)
	if not any_fort:
		_hint("No forts of theirs left standing outside the land we take.")

	var d := world.diplomacy
	_section_title("Vassals and alliances")
	var sub := _toggle("%s becomes our vassal" % them.name, _subjugate)
	sub.toggled.connect(func(on: bool):
		_subjugate = on
		refresh())
	_extra.add_child(sub)
	var sub_why := military.treaty_blocked(war, player_tag, {"with": with_tag, "subjugate": true})
	if sub_why != "":
		sub.disabled = not _subjugate
		_hint(sub_why)
	for s: String in d.subjects_of(with_tag):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := UITheme.label(MilitarySystem.short_name(world, s), 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		row.add_child(label)
		for spec: Array in [["Set free", _release, _transfer], ["Ours", _transfer, _release]]:
			var table: Dictionary = spec[1]
			var other: Dictionary = spec[2]
			var b := UITheme.button(spec[0], true)
			b.set_pressed_no_signal(table.has(s))
			b.toggled.connect(func(on: bool):
				if on:
					table[s] = true
					other.erase(s)
				else:
					table.erase(s)
				refresh())
			row.add_child(b)
		_extra.add_child(row)
	for ally: String in d.allies_of(with_tag):
		if ally != player_tag:
			_toggle_into("Break their alliance with %s" % MilitarySystem.short_name(world, ally), _break, ally)

	_emit_highlights(war)
	_propose.disabled = why != ""
	_propose.text = "Propose peace" if accept else "Propose (they would refuse)"
	_surrender.disabled = military.treaty_blocked(war, player_tag,
		military.surrender_treaty(war, player_tag, with_tag)) != ""


func _emit_highlights(war: Dictionary) -> void:
	var colours := {}
	var side := Military.side_of(war, player_tag)
	for p: Province in military.held_by(war, side):
		if _theirs(war, p.owner_id):
			colours[p.id] = MAY_GAIN
	for p: Province in military.held_by(war, 1 - side):
		if _ours(war, p.owner_id):
			colours[p.id] = MAY_LOSE
	for id: int in _demand:
		colours[id] = GAIN
	for id: int in _give:
		colours[id] = LOSS
	highlights_changed.emit(colours)


func _province_row(p: Province, detail: String, table: Dictionary) -> void:
	var b := _toggle("%s%s" % [p.name, "  —  " + detail if detail != "" else ""], true)
	b.toggled.connect(func(_on: bool):
		table.erase(p.id)
		refresh())
	_extra.add_child(b)


func _toggle_into(text: String, table: Dictionary, key: Variant) -> void:
	var b := _toggle(text, table.has(key))
	b.toggled.connect(func(on: bool):
		if on:
			table[key] = true
		else:
			table.erase(key)
		refresh())
	_extra.add_child(b)


func _toggle(text: String, on: bool) -> Button:
	var b := UITheme.button(("☑  " if on else "☐  ") + text, true)
	b.set_pressed_no_signal(on)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return b


func _hint(text: String) -> void:
	var l := UITheme.label(text, 13, UITheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	_extra.add_child(l)
