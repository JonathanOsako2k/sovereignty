class_name ArmyPanel
extends DrawerPanel
## The selected army or fleet (or several): men, spirit, where it stands and
## what it is doing — marching (to where, how long), besieging (how far along),
## standing — its upkeep and its regiments by type. For our own forces: split,
## stop, disband; with several selected, merge them; and a hint that a tap on
## the map sends them there.

signal province_requested(province_id: int)
signal country_requested(tag: String)
signal army_requested(id: int)
signal merge_requested(ids: Array)
signal split_requested(id: int)
signal stop_requested(ids: Array)
signal disband_requested(id: int)
signal board_requested(id: int)
## Select troops aboard a fleet (their own panel, to land them).
signal troops_requested(ids: Array)

var world: WorldState
var military: MilitarySystem
var player_tag := ""
var ids: Array[int] = []

var _actions: HBoxContainer
var _merge: Button
var _split: Button
var _stop: Button
var _disband: Button
var _board: Button


func _init() -> void:
	super()
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	_footer.add_child(_actions)
	_merge = _footer_button("Merge", func(): merge_requested.emit(Array(ids)))
	_split = _footer_button("Split", func(): split_requested.emit(ids[0]))
	_stop = _footer_button("Halt", func(): stop_requested.emit(Array(ids)))
	_disband = _footer_button("Disband", func(): disband_requested.emit(ids[0]))
	_disband.add_theme_color_override("font_color", UITheme.DANGER)
	_board = _footer_button("Board ship", func(): board_requested.emit(ids[0]))


func _footer_button(text: String, action: Callable) -> Button:
	var b := UITheme.button(text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	_actions.add_child(b)
	return b


func show_armies(p_world: WorldState, p_military: MilitarySystem, p_ids: Array[int]) -> void:
	world = p_world
	military = p_military
	ids = p_ids
	refresh()


func refresh() -> void:
	if world == null:
		return
	ids = ids.filter(func(id: int) -> bool: return world.military.armies.has(id))
	if ids.is_empty():
		_set_header("No army", "", MapModes.UNCOLONISED)
		_set_rows([])
		_clear_extra()
		_actions.visible = false
		return
	var armies: Array = ids.map(func(id: int) -> Army: return world.military.get_army(id))
	var first: Army = armies[0]
	var own := first.owner == player_tag
	var owner := world.get_country(first.owner)
	_clear_extra()
	if armies.size() == 1:
		_single(first, owner)
	else:
		_several(armies, owner)
	_actions.visible = own
	_merge.visible = armies.size() > 1
	_merge.disabled = military.merge_blocked(armies) != ""
	_split.visible = armies.size() == 1
	_split.disabled = military.split_blocked(first) != ""
	_stop.disabled = not armies.any(func(a: Army) -> bool: return a.is_moving() and not a.retreating)
	_disband.visible = armies.size() == 1
	_disband.disabled = military.disband_blocked(first) != ""
	_board.visible = armies.size() == 1 and not first.navy and first.aboard == 0
	_board.disabled = military.board_blocked(first) != ""
	if own:
		if first.retreating:
			_note("Falling back after a lost battle: no orders, and no battle, until it gets there.")
		elif first.aboard != 0:
			_note("Aboard ship: tap a coast of the fleet's sea to land.")
		elif first.navy:
			_note("Tap a sea zone or one of our docks to sail there; with troops aboard, tap a coast of its sea to land them.")
		else:
			_note("Tap a province to send %s there; tap a fleet of ours offshore to board it." % ("it" if armies.size() == 1 else "them"))
			if armies.size() == 1 and _board.disabled:
				_note("Board ship: " + military.board_blocked(first))
		if armies.size() > 1 and _merge.disabled:
			_note(military.merge_blocked(armies), UITheme.DANGER)


func _single(a: Army, owner: Country) -> void:
	_set_header(a.name, ("Fleet of " if a.navy else "Army of ") + owner.name, MapModes.country_color(world, a.owner))
	var here := world.get_province(a.location)
	var rows := [
		["Owner", _country_link(a.owner)],
		["Men", "%s of %s" % [DrawerPanel.thousands(a.men()), DrawerPanel.thousands(a.full_men())]],
		["Spirit", "%d %%" % int(a.morale * 100.0)],
		["At", _province_link(here) if not here.is_sea else here.name],
		["Doing", _status(a)],
		["Upkeep", "%.1f a month" % (a.upkeep() * Policies.upkeep_cost(owner.spending.navy if a.navy else owner.spending.army)
			* (Military.DOCKED_UPKEEP if Military.is_berthed(world, a) else 1.0))],
	]
	if a.navy and a.capacity() > 0:
		rows.append(["Carrying", "%s of %s men" % [DrawerPanel.thousands(military.cargo_men(a)), DrawerPanel.thousands(a.capacity())]])
	_set_rows(rows)
	var cargo := world.military.cargo_of(a.id) if a.navy else ([] as Array[Army])
	if not cargo.is_empty():
		_section_title("Aboard")
		var all_ids := []
		for c: Army in cargo:
			all_ids.append(c.id)
			var b := UITheme.link_button("%s — %s" % [c.name, DrawerPanel.thousands(c.men())])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var id := c.id
			b.pressed.connect(func(): troops_requested.emit([id]))
			_extra.add_child(b)
		if a.owner == player_tag:
			var select := UITheme.button("Select the troops aboard")
			select.pressed.connect(func(): troops_requested.emit(all_ids))
			_extra.add_child(select)
	_section_title("Ships" if a.navy else "Regiments")
	var types := a.by_type()
	var keys: Array = types.keys()
	keys.sort()
	for t: String in keys:
		var row := HBoxContainer.new()
		var name_label := UITheme.label("%s × %d" % [UnitTypes.name_of(t), types[t][0]], 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UITheme.label(DrawerPanel.thousands(types[t][1]), 15, UITheme.TEXT_DIM))
		_extra.add_child(row)
	if a.has_levies():
		_note("Levies: their men are missing from their provinces' fields until sent home.")


func _status(a: Army) -> String:
	var m := world.military
	if a.retreating and a.is_moving():
		return "Falling back to %s, %d days" % [world.get_province(a.path[a.path.size() - 1]).name,
			ceili(military.path_days(a, a.path) - (a.leg_total - a.leg_days))]
	if a.aboard != 0:
		var fleet := m.get_army(a.aboard)
		if a.is_moving():
			return "Landing at %s, %d days" % [world.get_province(a.path[0]).name, ceili(a.leg_days)]
		return "Aboard %s" % (fleet.name if fleet else "ship")
	if a.is_moving():
		var goal := world.get_province(a.path[a.path.size() - 1])
		return "Marching to %s, %d days" % [goal.name, ceili(military.path_days(a, a.path) - (a.leg_total - a.leg_days))]
	if m.sieges.has(a.location) and m.sieges[a.location].by == a.owner:
		var p := world.get_province(a.location)
		return "Besieging %s: %d of %d days" % [p.name, int(m.sieges[a.location].progress), int(military.siege_days(p))]
	if a.navy:
		return "In port: repairs, half upkeep" if Military.is_berthed(world, a) else "At sea (repairs only in port)"
	return "Standing"


func _several(armies: Array, owner: Country) -> void:
	var men := 0
	for a: Army in armies:
		men += a.men()
	_set_header("%d %s" % [armies.size(), "fleets" if armies[0].navy else "armies"], owner.name,
		MapModes.country_color(world, owner.id))
	_set_rows([["Men", DrawerPanel.thousands(men)]])
	_section_title("Selected")
	for a: Army in armies:
		var b := UITheme.link_button("%s — %s, %s" % [a.name, DrawerPanel.thousands(a.men()), world.get_province(a.location).name])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id := a.id
		b.pressed.connect(func(): army_requested.emit(id))
		_extra.add_child(b)


func _note(text: String, color := UITheme.TEXT_DIM) -> void:
	var l := UITheme.label(text, 13, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	_extra.add_child(l)


func _country_link(tag: String) -> Button:
	var b := UITheme.link_button(world.get_country(tag).name)
	b.pressed.connect(func(): country_requested.emit(tag))
	return b


func _province_link(p: Province) -> Button:
	var b := UITheme.link_button(p.name)
	b.pressed.connect(func(): province_requested.emit(p.id))
	return b
