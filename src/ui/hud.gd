class_name HUD
extends CanvasLayer
## Screen-space interface: top status bar, map-mode bar, zoom controls, the
## context drawer (province or country panel), the menus and short notices.
## Emits intent signals; the Game node applies them.
## Layout adapts to orientation: side panel in landscape, bottom sheet in portrait.

signal pause_toggled
signal speed_step(delta: int)
signal map_mode_selected(mode: MapModes.Mode)
signal zoom_step(factor: float)
signal recenter_requested
signal panel_closed
signal menu_requested
signal choose_back_requested
signal country_requested(tag: String)
## Our name in the top bar: our panel, and the map fitted to our home.
signal country_focus_requested(tag: String)
signal province_requested(province_id: int)
signal play_requested(tag: String)
signal locate_requested(tag: String)
signal debug_transfer_requested(province_id: int)
signal debug_occupy_requested(province_id: int)
signal diplomacy_requested(action: int, tag: String)
signal gift_requested(tag: String, amount: int)
signal land_deal_requested(tag: String, kind: int)
signal land_deal_proposed(to: String, deal: Dictionary)
## The land deal's provinces to colour on the map ({}: none).
signal land_deal_highlights(colours: Dictionary)
signal war_requested(tag: String)
signal treaty_requested(war_id: int, with: String)
## One of our wars (its icon under the top bar, or the Military tab).
signal war_panel_requested(war_id: int)
## The war pop-up closed (`resume`: dismissed, rather than leading on).
signal war_closed(resume: bool)
signal treaty_proposed(war_id: int, treaty: Dictionary)
signal surrender_requested(war_id: int, with: String)
## The peace table's land to colour on the map ({}: none).
signal treaty_highlights(colours: Dictionary)
signal board_requested(id: int)
signal troops_requested(ids: Array)
signal levies_requested(raise: bool)
signal district_requested(muster_id: int, raise: bool)
signal recruit_requested(province_id: int, unit: String)
signal army_requested(id: int)
signal merge_requested(ids: Array)
signal split_requested(id: int)
signal stop_requested(ids: Array)
signal disband_requested(id: int)
## The "select armies" button: while on, dragging on the map draws a box.
signal select_mode_toggled(on: bool)
## The ✕ under it: let go of every selected army.
signal clear_selection_requested
## The Military tab (the ⚔ button, or links from the budget and our country).
signal military_requested
signal budget_requested(tag: String)
signal loans_requested
signal loan_requested
signal repay_requested(index: int)
signal bankruptcy_requested
signal policy_changed(policy: String, index: int, step: int)
signal build_requested(province_id: int, building: String)
signal colony_requested(province_id: int)
signal abandon_colony_requested(province_id: int)

## What the HUD is framing: the title menu, choosing a country, or a campaign.
enum Screen { TITLE, CHOOSING, PLAYING }

const TOP_BAR_HEIGHT := 80.0
const BOTTOM_BAR_HEIGHT := 64.0
const SIDE_PANEL_WIDTH := 330.0
## Budget and loans: room for policy sliders a thumb can work.
const WIDE_PANEL_WIDTH := 540.0
const MARGIN := 8.0
const TOAST_SECONDS := 2.5
## Our wars' badges under the top bar.
const WAR_RED := Color(0.62, 0.1, 0.08)

var screen := Screen.PLAYING
var menu: MenuScreen

var _root: Control
var _top_bar: PanelContainer
var _country_swatch: ColorRect
var _country_button: Button
var _date_label: Label
var _pause_button: Button
var _speed_label: Label
var _choose_bar: PanelContainer
var _mode_bar: PanelContainer
## Bottom bar: one button per map-mode group (MapModes.GROUPS); a group with
## several modes slides out a small bar of them above it.
var _group_buttons: Array[Button] = []
var _group_mode: Array = []  # per group: the mode last shown from it
var _mode_slide: PanelContainer
var _mode_slide_row: HBoxContainer
var _mode_slide_tween: Tween
var _open_group := -1
var _mode := MapModes.Mode.POLITICAL
var _zoom_box: VBoxContainer
var _province_panel: ProvincePanel
var _country_panel: CountryPanel
var _budget_panel: BudgetPanel
var _loans_panel: LoansPanel
var _army_panel: ArmyPanel
var _military_panel: MilitaryPanel
var _treaty_panel: PeaceTreatyPanel
var _land_panel: LandDealPanel
var _war_panel: WarPanel
## Our wars, one icon each, under the top bar.
var _war_bar: HBoxContainer
var _military_button: Button
var _select_button: Button
var _clear_button: Button
var _selected_count := 0
var _box: Panel
var _treasury_button: Button
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _safe := Rect2()
var _refresh_pending := false


func _ready() -> void:
	layer = 2
	_root = Control.new()
	_root.theme = UITheme.build()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_top_bar()
	_build_choose_bar()
	_build_mode_bar()
	_build_zoom_controls()

	_province_panel = ProvincePanel.new()
	_province_panel.visible = false
	_province_panel.close_requested.connect(func(): panel_closed.emit())
	_province_panel.country_requested.connect(func(tag): country_requested.emit(tag))
	_province_panel.debug_transfer_requested.connect(func(id): debug_transfer_requested.emit(id))
	_province_panel.debug_occupy_requested.connect(func(id): debug_occupy_requested.emit(id))
	_province_panel.build_requested.connect(func(id, b): build_requested.emit(id, b))
	_province_panel.colony_requested.connect(func(id): colony_requested.emit(id))
	_province_panel.abandon_colony_requested.connect(func(id): abandon_colony_requested.emit(id))
	_province_panel.recruit_requested.connect(func(id, unit): recruit_requested.emit(id, unit))
	_province_panel.army_requested.connect(func(id): army_requested.emit(id))
	_root.add_child(_province_panel)

	_country_panel = CountryPanel.new()
	_country_panel.visible = false
	_country_panel.close_requested.connect(func(): panel_closed.emit())
	_country_panel.province_requested.connect(func(id): province_requested.emit(id))
	_country_panel.play_requested.connect(func(tag): play_requested.emit(tag))
	_country_panel.locate_requested.connect(func(tag): locate_requested.emit(tag))
	_country_panel.country_requested.connect(func(tag): country_requested.emit(tag))
	_country_panel.diplomacy_requested.connect(func(action, tag): diplomacy_requested.emit(action, tag))
	_country_panel.gift_requested.connect(func(tag, amount): gift_requested.emit(tag, amount))
	_country_panel.land_deal_requested.connect(func(tag, kind): land_deal_requested.emit(tag, kind))
	_country_panel.budget_requested.connect(func(tag): budget_requested.emit(tag))
	_country_panel.war_requested.connect(func(tag): war_requested.emit(tag))
	_country_panel.treaty_requested.connect(func(id, with): treaty_requested.emit(id, with))
	_country_panel.levies_requested.connect(func(raise): levies_requested.emit(raise))
	_country_panel.military_requested.connect(func(): military_requested.emit())
	_root.add_child(_country_panel)

	_budget_panel = BudgetPanel.new()
	_budget_panel.visible = false
	_budget_panel.close_requested.connect(func(): panel_closed.emit())
	_budget_panel.country_requested.connect(func(tag): country_requested.emit(tag))
	_budget_panel.loans_requested.connect(func(): loans_requested.emit())
	_budget_panel.policy_changed.connect(func(policy, index, step): policy_changed.emit(policy, index, step))
	_budget_panel.military_requested.connect(func(): military_requested.emit())
	_root.add_child(_budget_panel)

	_loans_panel = LoansPanel.new()
	_loans_panel.visible = false
	_loans_panel.close_requested.connect(func(): panel_closed.emit())
	_loans_panel.budget_requested.connect(func(): budget_requested.emit(_loans_panel.tag))
	_loans_panel.loan_requested.connect(func(): loan_requested.emit())
	_loans_panel.repay_requested.connect(func(index): repay_requested.emit(index))
	_loans_panel.bankruptcy_requested.connect(func(): bankruptcy_requested.emit())
	_root.add_child(_loans_panel)

	_army_panel = ArmyPanel.new()
	_army_panel.visible = false
	_army_panel.close_requested.connect(func(): panel_closed.emit())
	_army_panel.province_requested.connect(func(id): province_requested.emit(id))
	_army_panel.country_requested.connect(func(tag): country_requested.emit(tag))
	_army_panel.army_requested.connect(func(id): army_requested.emit(id))
	_army_panel.merge_requested.connect(func(ids): merge_requested.emit(ids))
	_army_panel.split_requested.connect(func(id): split_requested.emit(id))
	_army_panel.stop_requested.connect(func(ids): stop_requested.emit(ids))
	_army_panel.disband_requested.connect(func(id): disband_requested.emit(id))
	_army_panel.board_requested.connect(func(id): board_requested.emit(id))
	_army_panel.troops_requested.connect(func(ids): troops_requested.emit(ids))
	_root.add_child(_army_panel)

	_military_panel = MilitaryPanel.new()
	_military_panel.visible = false
	_military_panel.close_requested.connect(func(): panel_closed.emit())
	_military_panel.army_requested.connect(func(id): army_requested.emit(id))
	_military_panel.country_requested.connect(func(tag): country_requested.emit(tag))
	_military_panel.levies_requested.connect(func(raise): levies_requested.emit(raise))
	_military_panel.district_requested.connect(func(id, raise): district_requested.emit(id, raise))
	_military_panel.policy_changed.connect(func(policy, index, step): policy_changed.emit(policy, index, step))
	_military_panel.budget_requested.connect(func(tag): budget_requested.emit(tag))
	_military_panel.war_requested.connect(func(id): war_panel_requested.emit(id))
	_root.add_child(_military_panel)

	_treaty_panel = PeaceTreatyPanel.new()
	_treaty_panel.visible = false
	_treaty_panel.close_requested.connect(func(): panel_closed.emit())
	_treaty_panel.treaty_proposed.connect(func(id, t): treaty_proposed.emit(id, t))
	_treaty_panel.surrender_requested.connect(func(id, with): surrender_requested.emit(id, with))
	_treaty_panel.highlights_changed.connect(func(colours): treaty_highlights.emit(colours))
	_root.add_child(_treaty_panel)

	_land_panel = LandDealPanel.new()
	_land_panel.visible = false
	_land_panel.close_requested.connect(func(): panel_closed.emit())
	_land_panel.proposed.connect(func(to, deal): land_deal_proposed.emit(to, deal))
	_land_panel.highlights_changed.connect(func(colours): land_deal_highlights.emit(colours))
	_root.add_child(_land_panel)

	_war_bar = HBoxContainer.new()
	_war_bar.add_theme_constant_override("separation", 6)
	_root.add_child(_war_bar)

	_box = Panel.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(1.0, 0.84, 0.35, 0.12)
	box_style.border_color = Color(1.0, 0.84, 0.35, 0.9)
	box_style.set_border_width_all(2)
	_box.add_theme_stylebox_override("panel", box_style)
	_box.visible = false
	_root.add_child(_box)

	# The war pop-up, over the map and the drawers (under notices and menus).
	_war_panel = WarPanel.new()
	_war_panel.closed.connect(func(resume): war_closed.emit(resume))
	_war_panel.country_requested.connect(func(tag): country_requested.emit(tag))
	_war_panel.treaty_requested.connect(func(id, with): treaty_requested.emit(id, with))
	_root.add_child(_war_panel)

	_build_toast()
	menu = MenuScreen.new()
	_root.add_child(menu)
	get_viewport().size_changed.connect(_layout)
	_layout()


# --- Public API used by Game -------------------------------------------------

func set_screen(s: Screen) -> void:
	screen = s
	_country_panel.choosing = s == Screen.CHOOSING
	_top_bar.visible = s == Screen.PLAYING
	if _war_bar != null:
		_war_bar.visible = s == Screen.PLAYING and _war_bar.get_child_count() > 0
	_choose_bar.visible = s == Screen.CHOOSING
	_mode_bar.visible = s != Screen.TITLE
	if s == Screen.TITLE:
		_close_mode_slide()
	_zoom_box.visible = s != Screen.TITLE
	if s == Screen.TITLE:
		close_drawer()
	_layout()


func set_diplomacy(actions: DiplomacyActions) -> void:
	_country_panel.actions = actions


func set_economy(economy: EconomySystem) -> void:
	_province_panel.economy = economy


func set_colonisation(colonisation: ColonisationSystem) -> void:
	_province_panel.colonisation = colonisation


func set_military(military: MilitarySystem) -> void:
	_province_panel.military = military
	_country_panel.military = military


## The selected armies or fleets in the drawer.
func show_armies(world: WorldState, military: MilitarySystem, ids: Array[int]) -> void:
	_army_panel.player_tag = _country_panel.player_tag
	_army_panel.show_armies(world, military, ids)
	_show_only(_army_panel)


## Our forces in the drawer (the Military tab).
func show_military(world: WorldState, military: MilitarySystem, economy: EconomySystem, tag: String) -> void:
	_military_panel.show_military(world, military, economy, tag)
	_show_only(_military_panel)


## A peace treaty of our making for a war (with `with`, else their leader).
func show_treaty(world: WorldState, military: MilitarySystem, war_id: int, with := "") -> void:
	_treaty_panel.show_treaty(world, military, war_id, _country_panel.player_tag, with)
	_show_only(_treaty_panel)


## Whether the peace table is open (map taps then pick its land).
func treaty_open() -> bool:
	return _treaty_panel.visible


## A tap on the map for the peace table: "" or why it is not part of the peace.
func treaty_toggle(province_id: int) -> String:
	return _treaty_panel.toggle_province(province_id)


## A land deal with a country (LandDealPanel.Kind: buy, sell, exchange).
func show_land_deal(world: WorldState, deals: LandDeals, tag: String, kind: int) -> void:
	_land_panel.show_deal(world, deals, _country_panel.player_tag, tag, kind)
	_show_only(_land_panel)


## Whether a screen that picks land on the map is open (the peace table, a
## land deal): map taps go to it.
func map_pick_open() -> bool:
	return _treaty_panel.visible or _land_panel.visible


## A tap on the map for that screen: "" or why it is not part of it.
func map_pick(province_id: int) -> String:
	if _treaty_panel.visible:
		return _treaty_panel.toggle_province(province_id)
	if _land_panel.visible:
		return _land_panel.toggle_province(province_id)
	return ""


## One of our wars, as a pop-up in the middle of the screen.
func show_war(world: WorldState, military: MilitarySystem, war_id: int) -> void:
	_war_panel.show_war(world, military, war_id, _country_panel.player_tag)
	_war_panel.layout(_safe.position.y + TOP_BAR_HEIGHT)
	if _toast_tween:
		_toast_tween.kill()
	_toast.visible = false  # no notice over the pop-up


func war_open() -> bool:
	return _war_panel.visible


## Our wars as icons centred under the top bar: [[war id, name, our score]].
## Each is a red badge with crossed swords and our war score.
func set_wars(wars: Array) -> void:
	for child in _war_bar.get_children():
		_war_bar.remove_child(child)
		child.queue_free()
	for entry: Array in wars:
		var score: int = entry[2]
		var b := Button.new()
		b.text = "⚔ %+d" % score
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(96, 56)
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = WAR_RED.lightened(0.15) if state in ["hover", "pressed"] else WAR_RED
			box.border_color = WAR_RED.lightened(0.4)
			box.set_border_width_all(2)
			box.set_corner_radius_all(8)
			box.shadow_color = Color(0, 0, 0, 0.45)
			box.shadow_size = 4
			b.add_theme_stylebox_override(state, box)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color.WHITE)
		b.tooltip_text = "%s (our score %+d)" % [entry[1], score]
		var id: int = entry[0]
		b.pressed.connect(func(): war_panel_requested.emit(id))
		_war_bar.add_child(b)
	_war_bar.visible = not wars.is_empty() and screen == Screen.PLAYING
	_layout()


func shown_armies() -> Array[int]:
	return _army_panel.ids if _army_panel.visible else ([] as Array[int])


## The screen area the map shows between the bars and beside an open drawer.
func free_map_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var top := _safe.position.y + TOP_BAR_HEIGHT
	var bottom := vs.y - (vs.y - _safe.end.y) - BOTTOM_BAR_HEIGHT
	var right := vs.x
	if _is_landscape():
		right -= SIDE_PANEL_WIDTH + MARGIN * 2  # the drawer opening beside it
	return Rect2(Vector2(_safe.position.x, top), Vector2(right - _safe.position.x, bottom - top))


## The "select armies" button's state.
func set_select_mode(on: bool) -> void:
	_select_button.set_pressed_no_signal(on)
	if not on:
		hide_box()
	_update_clear_button()


## How many armies are selected: the ✕ shows while there are any (and in
## select mode, greyed when there are none).
func set_army_selection(count: int) -> void:
	_selected_count = count
	_update_clear_button()


func _update_clear_button() -> void:
	if _clear_button == null:
		return
	_clear_button.visible = _selected_count > 0 or _select_button.button_pressed
	_clear_button.disabled = _selected_count == 0
	_clear_button.text = "✕" if _selected_count < 2 else "✕%d" % _selected_count


## The selection box being dragged, in screen points.
func show_box(from: Vector2, to: Vector2) -> void:
	var r := Rect2(from, Vector2.ZERO).expand(to)
	_box.position = r.position
	_box.size = r.size
	_box.visible = true


func hide_box() -> void:
	_box.visible = false


## Treasury and this month's balance in the top bar.
func set_treasury(treasury: float, net: float) -> void:
	_treasury_button.text = "%s ducats  %+.1f" % [DrawerPanel.thousands(roundi(treasury)), net]


## A country's budget in the drawer.
func show_budget(world: WorldState, economy: EconomySystem, tag: String) -> void:
	_budget_panel.player_tag = _country_panel.player_tag
	_budget_panel.show_budget(world, economy, tag)
	_show_only(_budget_panel)


## Our loans in the drawer.
func show_loans(world: WorldState, economy: EconomySystem, tag: String) -> void:
	_loans_panel.show_loans(world, economy, tag)
	_show_only(_loans_panel)


func _drawer_panels() -> Array[DrawerPanel]:
	return [_province_panel, _country_panel, _budget_panel, _loans_panel, _army_panel, _military_panel, _treaty_panel,
		_land_panel]


func _show_only(panel: DrawerPanel) -> void:
	for p in _drawer_panels():
		p.visible = p == panel
	_layout()


func set_player_country(c: Country, color := MapModes.UNCOLONISED) -> void:
	_country_button.text = c.name if c else "Observer"
	_country_swatch.color = color
	var tag := c.id if c else ""
	_province_panel.player_tag = tag
	_country_panel.player_tag = tag
	_army_panel.player_tag = tag


func set_date_text(text: String) -> void:
	_date_label.text = text


func set_time_state(paused: bool, speed: int) -> void:
	_pause_button.text = "▶  Play" if paused else "❚❚  Pause"
	_pause_button.button_pressed = not paused
	_speed_label.text = "●".repeat(speed) + "○".repeat(GameClock.MAX_SPEED - speed)


func set_map_mode(mode: MapModes.Mode) -> void:
	_mode = mode
	var g := MapModes.group_of(mode)
	_group_mode[g] = mode
	for i in _group_buttons.size():
		var b := _group_buttons[i]
		b.set_pressed_no_signal(i == g)
		var modes: Array = MapModes.GROUPS[i][1]
		var name: String = MapModes.GROUPS[i][0]
		b.text = name if modes.size() == 1 or MapModes.NAMES[_group_mode[i]] == name \
			else "%s · %s" % [name, MapModes.NAMES[_group_mode[i]]]
	for b: Button in _mode_slide_row.get_children():
		b.set_pressed_no_signal(b.get_meta("mode") == mode)


## Shows a province in the drawer (0 hides the province panel).
func show_province(world: WorldState, province_id: int) -> void:
	if province_id != 0:
		_province_panel.show_province(world, province_id)
		_show_only(_province_panel)
	else:
		_province_panel.visible = false
		_layout()


## Shows a country in the drawer ("" hides the country panel).
func show_country(world: WorldState, tag: String) -> void:
	if tag != "":
		_country_panel.show_country(world, tag)
		_show_only(_country_panel)
	else:
		_country_panel.visible = false
		_layout()


func shown_country() -> String:
	return _country_panel.tag if _country_panel.visible else ""


func drawer_open() -> bool:
	return _drawer_panels().any(func(p: DrawerPanel) -> bool: return p.visible)


func close_drawer() -> void:
	_show_only(null)


func refresh_drawer() -> void:
	_refresh_pending = false
	for p in _drawer_panels():
		if p.visible:
			p.refresh()


## Refreshes once at the end of the frame, however many changes arrive (a
## month of AI diplomacy can bring hundreds).
func refresh_drawer_later() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		refresh_drawer.call_deferred()


## A short notice that fades out by itself ("Game saved").
func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast.reset_size()
	_layout()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func(): _toast.visible = false)


# --- Construction ------------------------------------------------------------

func _build_top_bar() -> void:
	_top_bar = PanelContainer.new()
	_top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_top_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_top_bar.add_child(row)

	var menu_button := UITheme.button("☰")
	menu_button.add_theme_font_size_override("font_size", 30)
	menu_button.custom_minimum_size = Vector2(64, 60)
	menu_button.pressed.connect(func(): menu_requested.emit())
	row.add_child(menu_button)
	_country_swatch = ColorRect.new()
	_country_swatch.custom_minimum_size = Vector2(14, 44)
	_country_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_country_swatch)
	_country_button = UITheme.link_button("")
	_country_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_country_button.add_theme_font_size_override("font_size", 24)
	_country_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_country_button.custom_minimum_size = Vector2(40, 60)
	_country_button.pressed.connect(func(): country_focus_requested.emit(_country_panel.player_tag))
	row.add_child(_country_button)

	_treasury_button = UITheme.link_button("")
	_treasury_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_treasury_button.custom_minimum_size = Vector2(220, 60)
	_treasury_button.add_theme_font_size_override("font_size", 21)
	_treasury_button.pressed.connect(func(): budget_requested.emit(_country_panel.player_tag))
	row.add_child(_treasury_button)

	_military_button = UITheme.button("⚔")
	_military_button.add_theme_font_size_override("font_size", 30)
	_military_button.custom_minimum_size = Vector2(64, 60)
	_military_button.tooltip_text = "Military"
	_military_button.pressed.connect(func(): military_requested.emit())
	row.add_child(_military_button)


	_date_label = UITheme.label("", 25)
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_label.custom_minimum_size.x = 210
	row.add_child(_date_label)

	_pause_button = UITheme.button("", true)
	_pause_button.custom_minimum_size = Vector2(130, 60)
	_pause_button.add_theme_font_size_override("font_size", 22)
	_pause_button.pressed.connect(func(): pause_toggled.emit())
	row.add_child(_pause_button)

	var slower := UITheme.button("−")
	slower.add_theme_font_size_override("font_size", 28)
	slower.custom_minimum_size = Vector2(60, 60)
	slower.pressed.connect(func(): speed_step.emit(-1))
	row.add_child(slower)
	_speed_label = UITheme.label("", 18, UITheme.ACCENT)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.custom_minimum_size.x = 72
	row.add_child(_speed_label)
	var faster := UITheme.button("+")
	faster.add_theme_font_size_override("font_size", 28)
	faster.custom_minimum_size = Vector2(60, 60)
	faster.pressed.connect(func(): speed_step.emit(1))
	row.add_child(faster)


## Replaces the top bar while the player picks a country.
func _build_choose_bar() -> void:
	_choose_bar = PanelContainer.new()
	_choose_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_choose_bar.visible = false
	_root.add_child(_choose_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_choose_bar.add_child(row)
	var back := UITheme.button("‹  Back")
	back.pressed.connect(func(): choose_back_requested.emit())
	row.add_child(back)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -2)
	row.add_child(texts)
	var title := UITheme.label("Choose your country", 20, UITheme.ACCENT)
	title.add_theme_font_override("font", UITheme.serif_font())
	texts.add_child(title)
	var hint := UITheme.label("Tap it on the map — 1 January 1590", 14, UITheme.TEXT_DIM)
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(hint)


func _build_mode_bar() -> void:
	_mode_slide = PanelContainer.new()
	_mode_slide.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_slide.visible = false
	_root.add_child(_mode_slide)
	_mode_slide_row = HBoxContainer.new()
	_mode_slide_row.add_theme_constant_override("separation", 8)
	_mode_slide.add_child(_mode_slide_row)

	_mode_bar = PanelContainer.new()
	_mode_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_mode_bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_mode_bar.add_child(row)
	for g in MapModes.GROUPS.size():
		var modes: Array = MapModes.GROUPS[g][1]
		_group_mode.append(modes[0])
		var b := UITheme.button(MapModes.GROUPS[g][0], true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(func(): _on_group_pressed(g))
		row.add_child(b)
		_group_buttons.append(b)


## Slides out a map-mode group's modes, as if its button were tapped (debug
## starts and screenshots).
func show_mode_group(g: int) -> void:
	if g >= 0 and g < _group_buttons.size():
		_on_group_pressed(g)


## A group button: show the group's last mode, and slide its modes out (or,
## when they are already out, back in).
func _on_group_pressed(g: int) -> void:
	_group_buttons[g].set_pressed_no_signal(MapModes.group_of(_mode) == g)
	if _open_group == g:
		_close_mode_slide()
		return
	if MapModes.group_of(_mode) != g:
		map_mode_selected.emit(_group_mode[g])
	if MapModes.GROUPS[g][1].size() > 1:
		_open_mode_slide(g)
	else:
		_close_mode_slide()


func _open_mode_slide(g: int) -> void:
	_open_group = g
	for child in _mode_slide_row.get_children():
		_mode_slide_row.remove_child(child)
		child.queue_free()
	for mode: MapModes.Mode in MapModes.GROUPS[g][1]:
		var b := UITheme.button(MapModes.NAMES[mode], true)
		b.custom_minimum_size.x = 150
		b.set_meta("mode", mode)
		b.set_pressed_no_signal(mode == _mode)
		b.pressed.connect(func(): map_mode_selected.emit(mode))
		_mode_slide_row.add_child(b)
	_mode_slide.visible = true
	_mode_slide.reset_size()
	_layout()
	# Slide up from behind the bottom bar.
	var rest := _mode_slide.position.y
	_mode_slide.position.y = rest + BOTTOM_BAR_HEIGHT * 0.6
	_mode_slide.modulate.a = 0.0
	if _mode_slide_tween:
		_mode_slide_tween.kill()
	_mode_slide_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_mode_slide_tween.tween_property(_mode_slide, "position:y", rest, 0.18)
	_mode_slide_tween.tween_property(_mode_slide, "modulate:a", 1.0, 0.18)


func _close_mode_slide() -> void:
	_open_group = -1
	if _mode_slide_tween:
		_mode_slide_tween.kill()
	_mode_slide.visible = false


func _build_zoom_controls() -> void:
	_zoom_box = VBoxContainer.new()
	_zoom_box.add_theme_constant_override("separation", 8)
	_root.add_child(_zoom_box)
	# Select several armies: while on, a drag on the map draws a box.
	_select_button = UITheme.button("⬚", true)
	_select_button.custom_minimum_size = Vector2(52, 52)
	_select_button.add_theme_font_size_override("font_size", 22)
	_select_button.tooltip_text = "Select armies: drag a box round them (it adds to the selection; armies before fleets)"
	_select_button.toggled.connect(func(on: bool):
		_update_clear_button()
		select_mode_toggled.emit(on))
	_zoom_box.add_child(_select_button)
	_clear_button = UITheme.button("✕")
	_clear_button.custom_minimum_size = Vector2(52, 52)
	_clear_button.add_theme_font_size_override("font_size", 20)
	_clear_button.tooltip_text = "Clear the army selection"
	_clear_button.visible = false
	_clear_button.pressed.connect(func(): clear_selection_requested.emit())
	_zoom_box.add_child(_clear_button)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_root.add_child(_toast)
	_toast_label = UITheme.label("", 17)
	_toast.add_child(_toast_label)


# --- Layout ------------------------------------------------------------------

func _is_landscape() -> bool:
	var vs := get_viewport().get_visible_rect().size
	return vs.x >= vs.y


## Safe area (display cutouts, rounded corners) converted to canvas units.
func _compute_safe_area() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0 or not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, vs)
	var k := vs / window
	return Rect2(safe.position * k, safe.size * k)


func _layout() -> void:
	if _top_bar == null:
		return
	var vs := get_viewport().get_visible_rect().size
	_safe = _compute_safe_area()
	var left := _safe.position.x
	var right := vs.x - _safe.end.x
	var top := _safe.position.y
	var bottom := vs.y - _safe.end.y

	for bar: Control in [_top_bar, _choose_bar]:
		bar.position = Vector2(left, top)
		bar.size = Vector2(vs.x - left - right, TOP_BAR_HEIGHT)
	_country_button.visible = vs.x >= 600  # too narrow on a folded phone in portrait
	_treasury_button.visible = vs.x >= 900

	if _war_bar != null:
		_war_bar.size = _war_bar.get_combined_minimum_size()
		_war_bar.position = Vector2((vs.x - _war_bar.size.x) * 0.5, top + TOP_BAR_HEIGHT + MARGIN)
	_mode_bar.position = Vector2(left, vs.y - bottom - BOTTOM_BAR_HEIGHT)
	_mode_bar.size = Vector2(vs.x - left - right, BOTTOM_BAR_HEIGHT)
	if _open_group >= 0:
		# Above its group button (the buttons share the bar equally), kept on screen.
		var w := _mode_slide.get_combined_minimum_size().x
		var cx := _mode_bar.position.x + _mode_bar.size.x * (_open_group + 0.5) / _group_buttons.size()
		_mode_slide.size = Vector2(w, BOTTOM_BAR_HEIGHT)
		_mode_slide.position = Vector2(clampf(cx - w * 0.5, left + MARGIN, vs.x - right - MARGIN - w),
			_mode_bar.position.y - BOTTOM_BAR_HEIGHT - 4)

	var panel_top := top + TOP_BAR_HEIGHT + MARGIN
	var panel_bottom := vs.y - bottom - BOTTOM_BAR_HEIGHT - MARGIN
	var zoom_x := vs.x - right - 52 - MARGIN
	var open_width := 0.0
	for panel in _drawer_panels():
		if _is_landscape():
			var w := minf(WIDE_PANEL_WIDTH, (vs.x - left - right) * 0.5) if panel.wide else SIDE_PANEL_WIDTH
			# A province, army or fleet opens on the left; the rest on the right.
			var on_left := panel == _province_panel or panel == _army_panel
			panel.position = Vector2(left + MARGIN if on_left else vs.x - right - w - MARGIN, panel_top)
			panel.size = Vector2(w, panel_bottom - panel_top)
			if panel.visible and not on_left:
				open_width = w
		else:
			var h := clampf((panel_bottom - panel_top) * (0.6 if panel.wide else 0.45), 260, 560)
			panel.position = Vector2(left + MARGIN, panel_bottom - h)
			panel.size = Vector2(vs.x - left - right - MARGIN * 2, h)
	if _is_landscape() and drawer_open():
		zoom_x -= open_width + MARGIN
	_zoom_box.position = Vector2(zoom_x, panel_top)

	if _war_panel != null and _war_panel.visible:
		_war_panel.layout(top + TOP_BAR_HEIGHT)
	_toast.reset_size()
	var below_wars := _war_bar.size.y + MARGIN if _war_bar != null and _war_bar.visible else 0.0
	_toast.position = Vector2((vs.x - _toast.size.x) * 0.5, panel_top + 4 + below_wars)
