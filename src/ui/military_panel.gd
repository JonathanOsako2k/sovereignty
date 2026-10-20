class_name MilitaryPanel
extends DrawerPanel
## The Military tab: our armed forces in one place — the standing army, levies
## and fleets, manpower (for regular regiments only; levies draw on the
## people, not on it), mobilisation (calling the levies, never automatic),
## army and navy maintenance, every army and fleet (tap to select) and our
## wars with their scores.

signal army_requested(id: int)
signal country_requested(tag: String)
signal levies_requested(raise: bool)
## One region's levies called (or sent home): its muster province.
signal district_requested(muster_id: int, raise: bool)
signal policy_changed(policy: String, index: int, step: int)
signal budget_requested(tag: String)
signal war_requested(war_id: int)

var world: WorldState
var military: MilitarySystem
var economy: EconomySystem
var tag := ""


func _init() -> void:
	super()
	wide = true
	var back := UITheme.button("Budget  ›")
	back.pressed.connect(func(): budget_requested.emit(tag))
	_footer.add_child(back)


func show_military(p_world: WorldState, p_military: MilitarySystem, p_economy: EconomySystem, p_tag: String) -> void:
	world = p_world
	military = p_military
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
	var m := world.military
	_set_header(c.name, "Military", MapModes.country_color(world, tag))
	var standing := 0
	var regiments := 0
	var levies := 0
	var ships := 0
	for a: Army in m.armies.values():
		if a.owner != tag:
			continue
		if a.navy:
			ships += a.regiments.size()
			continue
		for r: Array in a.regiments:
			if r[0] == "levy":
				levies += r[1]
			else:
				standing += r[1]
				regiments += 1
	var potential := 0
	for p: Province in world.ownable_provinces():
		if p.owner_id == tag and p.controller_id == tag and not world.overseas.has(p.id):
			potential += MilitarySystem.levy_men(p)
	var limit := military.manpower_limit(tag)
	var budget := economy.budget(tag)
	_set_rows([
		["Standing army", "%s men, %d regiments" % [DrawerPanel.thousands(standing), regiments]],
		["Levies", "Under arms: %s" % DrawerPanel.thousands(levies) if m.levies_raised.has(tag)
			else "At home (about %s)" % DrawerPanel.thousands(potential)],
		["Ships", str(ships)],
		["Manpower", ("%s of %s" if military.manpower(tag) <= limit else "%s (over the ceiling of %s)") % [
			DrawerPanel.thousands(int(military.manpower(tag))), DrawerPanel.thousands(int(limit))]],
		["Upkeep", "%.1f a month" % (_line(budget.expenses, EconomySystem.ARMY) + _line(budget.expenses, EconomySystem.NAVY))],
	])
	_clear_extra()
	_hint("Manpower raises and refills regular regiments (+%s a month); levies come from the people instead." %
		DrawerPanel.thousands(int(military.manpower_growth(tag, limit))))

	_section_title("Mobilisation")
	var all_row := HBoxContainer.new()
	all_row.add_theme_constant_override("separation", 8)
	var all_why := military.mobilise_blocked(tag)
	var call_all := UITheme.button("Mobilise all")
	call_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_all.disabled = all_why != ""
	call_all.pressed.connect(func(): levies_requested.emit(true))
	all_row.add_child(call_all)
	var home_all := UITheme.button("Send all home")
	home_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_all.disabled = levies == 0
	home_all.pressed.connect(func(): levies_requested.emit(false))
	all_row.add_child(home_all)
	_extra.add_child(all_row)
	if all_why != "" and levies == 0:
		_hint(all_why)
	_hint("Or region by region: each region's men muster at its town, leaving their fields while they serve.")
	for d: Dictionary in military.levy_districts(tag):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := UITheme.label("%s — %s" % [d.name, ("%s under arms" % DrawerPanel.thousands(d.out)) if d.out > 0
			else ("%s ready" % DrawerPanel.thousands(d.ready))], 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		var muster: int = d.muster
		var why := military.district_blocked(tag, muster)
		if why == "":
			var call := UITheme.button("Mobilise")
			call.pressed.connect(func(): district_requested.emit(muster, true))
			row.add_child(call)
		if d.out > 0:
			var home := UITheme.button("Send home")
			home.pressed.connect(func(): district_requested.emit(muster, false))
			row.add_child(home)
		elif why != "":
			var none := UITheme.button("Mobilise")
			none.disabled = true
			none.tooltip_text = why
			row.add_child(none)
		_extra.add_child(row)

	_section_title("Maintenance")
	var s: Dictionary = c.spending
	_spending_slider("army", s.army, "Upkeep %.1f a month · spirit recovers to %d %%" % [
		_line(budget.expenses, EconomySystem.ARMY), int(Policies.max_morale(s.army) * 100)],
		func(step: int): policy_changed.emit("army", 0, step))
	_spending_slider("navy", s.navy, "Upkeep %.1f a month · spirit recovers to %d %%" % [
		_line(budget.expenses, EconomySystem.NAVY), int(Policies.max_morale(s.navy) * 100)],
		func(step: int): policy_changed.emit("navy", 0, step))

	for navy in [false, true]:
		var list := m.armies_of(tag, navy)
		if list.is_empty():
			continue
		_section_title("Fleets" if navy else "Armies")
		list.sort_custom(func(x: Army, y: Army) -> bool: return x.men() > y.men())
		for a: Army in list:
			var place := world.get_province(a.location).name
			var what := "%d ships" % a.regiments.size() if navy else DrawerPanel.thousands(a.men())
			var link := UITheme.link_button("%s — %s, %s%s" % [a.name, what, place, " (marching)" if a.is_moving() else ""])
			link.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var id := a.id
			link.pressed.connect(func(): army_requested.emit(id))
			_extra.add_child(link)

	var wars := m.wars_of(tag)
	if not wars.is_empty():
		_section_title("Wars")
	for w: Dictionary in wars:
		var side := Military.side_of(w, tag)
		var score := military.war_score(w) * (1.0 if side == 0 else -1.0)
		var link := UITheme.link_button("%s: %+d" % [w.name, int(score)])
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id: int = w.id
		link.pressed.connect(func(): war_requested.emit(id))
		_extra.add_child(link)


static func _line(lines: Array, label: String) -> float:
	for l: Array in lines:
		if l[0] == label:
			return l[1]
	return 0.0


func _hint(text: String) -> void:
	var l := UITheme.label(text, 13, UITheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	_extra.add_child(l)


func _two_line_button(title: String, detail: String, disabled: bool) -> Button:
	var b := UITheme.button(title + ("\n" + detail if detail != "" else ""))
	b.add_theme_font_size_override("font_size", 15)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = disabled
	b.custom_minimum_size.y = 52
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return b
