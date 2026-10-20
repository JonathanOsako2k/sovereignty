extends Node
## Composition root: loads the world, owns the campaign (world, clock, random
## stream) and the save service, and wires the map layers, HUD and menus
## together. Game rules live in src/core and src/domain, not here.
##
## Flow: title menu → choose a country on the map → play. The in-game menu
## (☰, Esc or Android back) saves, loads or returns to the title. Time moves
## only through the SimulationScheduler; the campaign autosaves every
## 1 January and whenever the app is sent to the background or closed.
##
## Debug command-line options (after `--`). Any of them except --menu skips the
## title menu and starts playing straight away:
##   --screenshot=<path>   save a screenshot after startup and quit
##   --select=<id>         select a province on startup
##   --country=<tag>       open a country's panel on startup
##   --budget=<tag>        open a country's budget on startup
##   --zoom=<factor>       initial zoom (focused on the selection if any)
##   --mode=<name>         initial map mode (political/control/topography/vegetation/
##                         climate/population)
##   --at=<lat>,<lon>      centre the view on a latitude/longitude
##   --play=<tag>          play as this country (default: the scenario's)
##   --occupy=<id>,<id>…   hand control of provinces to the player (debug)
##   --load=<slot>         load a save from user://saves
##   --menu[=page]         show a menu: title (default), choose (country choice),
##                         pause (in-game menu) or saves (saved-games list)

enum Phase { TITLE, CHOOSING, PLAYING }

@onready var map_view: MapView = $MapView
@onready var map_camera: MapCamera = $MapCamera
@onready var overlay: MapOverlay3D = $OverlayLayer/MapOverlay3D
@onready var hud: HUD = $HUD

var world: WorldState
var clock := GameClock.new()
var campaign: Campaign
var scheduler: SimulationScheduler
var diplomacy_actions: DiplomacyActions
var diplomacy_system: DiplomacySystem
var economy: EconomySystem
var colonisation: ColonisationSystem
var military: MilitarySystem
## Armies, fleets and forts on the map; the armies the player has selected.
var forces: MapForces
var selected_armies: Array[int] = []
var music: MusicPlayer
var _treasury_ui_pending := false
## This month's balance for the top bar (worked out monthly and after changes).
var _player_net := 0.0
var saves := SaveService.new()
var phase := Phase.TITLE
var _autosave_due := false
## The scenario's suggested country (England in 1590), used for debug starts.
var _default_player := ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.13, 0.22, 0.31))
	var loader := WorldLoader.new()
	world = loader.load_world()
	saves.compatible_fingerprints = world.compatible_fingerprints  # the same map, redrawn
	for e in loader.errors:
		push_error("World data: " + e)
	if world == null:
		push_error("World failed to load; see errors above.")
		return
	_default_player = world.player_country_id
	if saves.save_dir == SaveService.DEFAULT_DIR:  # tests may point it elsewhere
		saves.save_dir = SaveService.device_save_dir()
	campaign = Campaign.new(world, clock)
	scheduler = SimulationScheduler.new(clock)
	diplomacy_actions = DiplomacyActions.new(campaign)
	diplomacy_system = DiplomacySystem.new(campaign, diplomacy_actions)
	economy = EconomySystem.new(campaign)
	colonisation = ColonisationSystem.new(campaign, economy)
	# Monthly, in order, one system a day over the first days of the month (a
	# frame each instead of one long frame; nothing runs in between, so the
	# outcome is the same): the economy's accounts; colonies (colonial powers
	# get first call on the money); the AI's building and the screens; then
	# (below) diplomacy. Yearly systems follow on 1–3 January.
	scheduler.register("economy", SimulationScheduler.Cadence.MONTHLY, func():
		economy.monthly()
		economy.ai_repayments(world.player_country_id)
		_update_treasury_ui_later(), 1)
	scheduler.register("colonisation", SimulationScheduler.Cadence.MONTHLY, func():
		colonisation.monthly()
		colonisation.ai_monthly(world.player_country_id)
		map_view.colony_progress_changed(), 2)
	scheduler.register("construction", SimulationScheduler.Cadence.MONTHLY, func():
		economy.ai_construction(world.player_country_id)
		map_view.economy_changed()
		_update_treasury_ui(), 3)
	# Overseas: colonial nations founded (three provinces in a colonial region),
	# newly settled land handed to the colony already there.
	scheduler.register("overseas", SimulationScheduler.Cadence.MONTHLY, _on_overseas_month, 3)
	scheduler.register("discoveries", SimulationScheduler.Cadence.YEARLY, economy.yearly, 3)
	scheduler.register("colonial policies", SimulationScheduler.Cadence.YEARLY,
		func(): colonisation.ai_yearly(world.player_country_id), 3)
	colonisation.colony_completed.connect(_on_colony_completed)
	colonisation.uprising.connect(_on_uprising)
	colonisation.colony_founded.connect(func(_id, _tag): map_view.colonies_changed())
	economy.discovered.connect(_on_discovered)
	economy.construction_finished.connect(_on_construction_finished)
	economy.went_bankrupt.connect(_on_bankrupt)
	scheduler.register("diplomacy", SimulationScheduler.Cadence.MONTHLY, diplomacy_system.monthly, 4)
	# War: marching, battles and sieges daily; the AI's campaigns weekly;
	# supply, reinforcements and peace monthly; new wars yearly.
	military = MilitarySystem.new(campaign, economy, diplomacy_actions)
	scheduler.register("military", SimulationScheduler.Cadence.DAILY, military.daily)
	scheduler.register("war plans", SimulationScheduler.Cadence.DAILY,
		func(): military.ai_daily(world.player_country_id))
	scheduler.register("armies", SimulationScheduler.Cadence.MONTHLY, func():
		military.monthly()
		military.ai_monthly_peace(world.player_country_id), 5)
	scheduler.register("wars", SimulationScheduler.Cadence.YEARLY,
		func(): military.ai_yearly_wars(world.player_country_id), 4)
	scheduler.register("cores", SimulationScheduler.Cadence.YEARLY,
		func(): world.claims.yearly(world, clock.day_number()), 4)
	military.battle_fought.connect(_on_battle)
	military.province_occupied.connect(_on_occupied)
	military.war_declared.connect(_on_war_declared)
	military.peace_made.connect(_on_peace_made)
	military.peace_offered.connect(_on_peace_offered)
	military.war_joined.connect(_on_war_joined)
	military.regiment_raised.connect(_on_regiment_raised)
	world.military.wars_changed.connect(func():
		hud.refresh_drawer_later()
		_update_wars_ui())
	world.military.reset.connect(_update_wars_ui)
	world.claims.changed.connect(func(): map_view._refresh_later(MapModes.Mode.DIPLOMACY))
	world.countries_changed.connect(func():
		economy.invalidate()
		map_view.refresh_colors())
	diplomacy_actions.performed.connect(_on_diplomacy_performed)

	clock.day_passed.connect(_on_day_passed)
	clock.year_passed.connect(func(): _autosave_due = true)
	# The soundtrack follows the date and the player's part of the world
	# (none in headless runs).
	if DisplayServer.get_name() != "headless":
		music = MusicPlayer.new()
		add_child(music)
		hud.menu.music_available = music.has_music()
		hud.menu.music_on = music.enabled
		hud.menu.music_toggled.connect(music.set_enabled)
		clock.year_passed.connect(func(): music.set_year(clock.year))
		world.player_changed.connect(func(_tag): _retune_music())
		world.campaign_restored.connect(_retune_music)
	clock.paused_changed.connect(func(_p): _update_time_ui())
	clock.speed_changed.connect(func(_s): _update_time_ui())

	map_view.economy = economy
	map_view.colonisation = colonisation
	map_view.setup(world)
	map_camera.setup(Vector2(world.map_size))
	overlay.setup(world, map_view, map_camera)
	forces = MapForces.new()
	forces.province_at = map_view.province_at  # docks stand on the real shore
	overlay.get_parent().add_child(forces)
	forces.setup(world, overlay, map_camera)
	clock.day_passed.connect(forces.update_positions_later)
	world.military.changed.connect(func():
		if not selected_armies.is_empty():
			hud.refresh_drawer_later())
	map_camera.box_dragged.connect(func(from, to): hud.show_box(from, to))
	map_camera.box_selected.connect(_on_box_selected)

	map_camera.view_changed.connect(func(): map_view.update_view(map_camera))
	map_camera.tapped.connect(_on_map_tapped)
	map_view.province_selected.connect(func(id): hud.show_province(world, id))
	map_view.country_selected.connect(func(tag): hud.show_country(world, tag))
	world.province_owner_changed.connect(func(_id, _a, _b): hud.refresh_drawer_later())
	world.province_controller_changed.connect(func(_id, _a, _b): hud.refresh_drawer_later())
	world.player_changed.connect(func(_tag): _update_player_ui())

	hud.pause_toggled.connect(clock.toggle_pause)
	hud.speed_step.connect(func(d): clock.set_speed(clock.speed + d))
	hud.map_mode_selected.connect(_set_map_mode)
	hud.zoom_step.connect(func(f): map_camera.zoom_by(f))
	hud.recenter_requested.connect(map_camera.recenter)
	hud.panel_closed.connect(_clear_selection)
	hud.menu_requested.connect(_open_game_menu)
	hud.choose_back_requested.connect(_show_title)
	hud.country_requested.connect(_show_country)
	hud.country_focus_requested.connect(func(tag: String):
		_show_country(tag)
		_focus_country(tag))
	hud.province_requested.connect(func(id): _show_province(id, true))
	hud.play_requested.connect(_play_as)
	hud.locate_requested.connect(_locate_country)
	hud.debug_transfer_requested.connect(func(id): world.transfer_province(id, world.player_country_id))
	hud.debug_occupy_requested.connect(func(id): world.set_controller(id, world.player_country_id))
	hud.diplomacy_requested.connect(_on_diplomacy_requested)
	hud.gift_requested.connect(_on_gift_requested)
	hud.budget_requested.connect(func(tag): _show_budget(tag))
	hud.loans_requested.connect(func(): hud.show_loans(world, economy, world.player_country_id))
	hud.loan_requested.connect(func():
		var rate := economy.interest_rate(world.player_country_id)
		if economy.take_loan(world.player_country_id):
			hud.show_toast("Borrowed %d ducats at %.1f%% a year" % [int(EconomySystem.LOAN_SIZE), rate * 100.0])
		_update_treasury_ui())
	hud.repay_requested.connect(func(index: int):
		economy.repay_loan(world.player_country_id, index)
		_update_treasury_ui())
	hud.bankruptcy_requested.connect(func():
		clock.set_paused(true)
		hud.menu.ask("Declare bankruptcy", "Repudiate all %d ducats of our debts?
No lender will deal with us for five years, and loans will cost more for ten. Legitimacy -20, stability -1; the merchants and nobility will not forget." % int(world.get_country(world.player_country_id).debt),
			"Declare bankruptcy", func():
				economy.declare_bankruptcy(world.player_country_id)
				_update_treasury_ui(), true))
	hud.policy_changed.connect(_on_policy_changed)
	hud.build_requested.connect(_on_build_requested)
	world.province_owner_changed.connect(func(_id, _a, _b): _update_treasury_ui_later())
	world.province_controller_changed.connect(func(_id, _a, _b): _update_treasury_ui_later())
	world.campaign_restored.connect(_update_treasury_ui_later)
	world.campaign_restored.connect(_update_wars_ui)
	hud.treaty_highlights.connect(map_view.set_highlights)
	hud.war_panel_requested.connect(_show_war)
	hud.war_closed.connect(_on_war_closed)
	hud.troops_requested.connect(func(ids: Array):
		var chosen: Array[int] = []
		chosen.assign(ids)
		_select_armies(chosen))
	military.province_occupied.connect(func(_id, _by): _update_wars_ui_later())
	military.battle_fought.connect(func(_r): _update_wars_ui_later())
	clock.month_passed.connect(_update_wars_ui_later)
	hud.board_requested.connect(_on_board_requested)
	hud.set_diplomacy(diplomacy_actions)
	hud.set_economy(economy)
	hud.set_colonisation(colonisation)
	hud.set_military(military)
	hud.select_mode_toggled.connect(func(on: bool):
		map_camera.select_mode = on
		if not on:
			hud.hide_box())
	hud.clear_selection_requested.connect(func(): _select_armies([] as Array[int]))
	hud.war_requested.connect(_on_war_requested)
	hud.treaty_requested.connect(_show_treaty)
	hud.treaty_proposed.connect(_on_treaty_proposed)
	hud.surrender_requested.connect(_on_surrender_requested)
	military.forts_changed.connect(forces.refresh_forts)
	hud.levies_requested.connect(_on_levies_requested)
	hud.district_requested.connect(_on_district_requested)
	hud.recruit_requested.connect(_on_recruit_requested)
	hud.army_requested.connect(_on_army_requested)
	hud.merge_requested.connect(_on_merge_requested)
	hud.split_requested.connect(_on_split_requested)
	hud.stop_requested.connect(func(ids: Array):
		for id: int in ids:
			var a := world.military.get_army(id)
			if a != null and a.owner == world.player_country_id:
				military.stop(a))
	hud.disband_requested.connect(_on_disband_requested)
	hud.military_requested.connect(_show_military)
	hud.colony_requested.connect(_on_colony_requested)
	hud.abandon_colony_requested.connect(_on_abandon_colony_requested)
	world.diplomacy.changed.connect(func(_a, _b): hud.refresh_drawer_later())
	world.diplomacy.reset.connect(func(): hud.refresh_drawer_later())
	world.diplomacy.opinions_updated.connect(func(): hud.refresh_drawer_later())
	world.diplomacy.subjects_changed.connect(_update_player_ui)

	var menu := hud.menu
	menu.continue_requested.connect(func(slot): _load_save(slot, false))
	menu.new_campaign_requested.connect(_choose_country)
	menu.load_page_requested.connect(_show_saves)
	menu.load_requested.connect(_load_save)
	menu.delete_requested.connect(_delete_save)
	menu.save_requested.connect(_save_game)
	menu.resume_requested.connect(menu.close)
	menu.main_menu_requested.connect(_show_title)
	menu.quit_requested.connect(func(): get_tree().quit())

	_update_player_ui()
	var home := world.get_province(world.get_country(_default_player).capital_province_id) if world.get_country(_default_player) else null
	if home:
		map_camera.focus_on(home.label_position, 1.2)
	_set_map_mode(MapModes.Mode.POLITICAL)
	_update_time_ui()
	hud.set_date_text(clock.format_date())

	var args := _debug_args()
	if args.has("menu"):
		match args.menu:
			"choose":
				_choose_country()
			"pause", "saves":
				_enter_playing()
				_open_game_menu()
				if args.menu == "saves":
					_show_saves()
			_:
				_show_title()
	elif args.is_empty():
		_show_title()
	else:
		_enter_playing()
	_apply_debug_args(args)


func _process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return
	scheduler.process_frame(delta)
	if _autosave_due and not scheduler.is_busy():
		_autosave(true)


func _on_day_passed() -> void:
	hud.set_date_text(clock.format_date())


func _set_map_mode(mode: MapModes.Mode) -> void:
	map_view.set_mode(mode)
	hud.set_map_mode(mode)


func _update_time_ui() -> void:
	hud.set_time_state(clock.paused, clock.speed)


## Top bar money: treasury now, and next month's balance (a full budget pass,
## so only after changes, never per frame).
## The top bar once at the end of the frame, however many changes arrive.
func _update_treasury_ui_later() -> void:
	if not _treasury_ui_pending:
		_treasury_ui_pending = true
		(func():
			_treasury_ui_pending = false
			_update_treasury_ui()).call_deferred()


func _update_treasury_ui() -> void:
	var c := world.get_country(world.player_country_id)
	if c == null:
		return
	_player_net = economy.budget(c.id).net
	hud.set_treasury(c.treasury, _player_net)
	hud.refresh_drawer_later()


func _on_policy_changed(policy: String, index: int, step: int) -> void:
	var c := world.get_country(world.player_country_id)
	match policy:
		"tax":
			if not Estates.taxable(Estates.ROLES[index]):
				return
			c.tax_rates[index] = clampi(c.tax_rates[index] + step, 0, Estates.TAX_MAX[Estates.ROLES[index]])
		"court", "mint", "forts", "army", "navy":
			c.spending[policy] = Policies.clamp_value(policy, c.spending[policy] + step * int(Policies.RANGES[policy][2]))
		"colonial":
			c.colonial_policy = clampi(c.colonial_policy + step, 0, Colonisation.POLICIES.size() - 1)
			map_view.colonies_changed()
	economy.changed()
	_update_treasury_ui()


func _on_build_requested(province_id: int, building: String) -> void:
	var p := world.get_province(province_id)
	var player := world.player_country_id
	var why := economy.build_blocked(player, building, p)
	if why != "":
		hud.show_toast(why)
		return
	var b: Dictionary = Buildings.CATALOGUE[building]
	clock.set_paused(true)
	hud.menu.ask("Build %s" % b.name, "Build a %s in %s for %d ducats? It takes %d months.
%s" % [
		b.name.to_lower(), p.name, int(ceil(economy.building_cost(player, building))), b.months, b.about],
		"Build", func():
			economy.start_building(player, building, p)
			hud.show_toast("Work has begun on a %s in %s" % [b.name.to_lower(), p.name])
			_update_treasury_ui())


func _on_colony_requested(province_id: int) -> void:
	var p := world.get_province(province_id)
	var player := world.player_country_id
	var why := colonisation.blocked(player, p)
	if why != "":
		hud.show_toast(why)
		return
	var cost := colonisation.founding_cost(player, p)
	var months := colonisation.months_to_settle(player, p)
	clock.set_paused(true)
	hud.menu.ask("Found a colony", "Send settlers to %s for %d ducats? At today's pace the colony stands in %s; until then it costs %d ducat a month." % [
		p.name, int(ceil(cost)), ProvincePanel._duration(months), int(Colonisation.COLONY_UPKEEP)],
		"Send settlers", func():
			if colonisation.found_colony(player, p):
				hud.show_toast("Settlers are on their way to %s" % p.name)
			_update_treasury_ui())


func _on_abandon_colony_requested(province_id: int) -> void:
	var p := world.get_province(province_id)
	clock.set_paused(true)
	hud.menu.ask("Abandon the colony", "Call the settlers home from %s? Its %d %% progress is lost." % [p.name, int(p.colony_progress)],
		"Abandon", func():
			colonisation.abandon(world.player_country_id, p)
			map_view.colonies_changed()
			_update_treasury_ui(), true)


## The month's overseas step (see Overseas.update): a colonial nation of ours
## founded, or our new colony handed to it, is told; the screens redraw.
func _on_overseas_month() -> void:
	var events := Overseas.update(world)
	if events.is_empty():
		return
	var player := world.player_country_id
	for e: Array in events:
		var nation := world.get_country(e[1])
		if e[2] != player or phase != Phase.PLAYING:
			continue
		if e[0] == "founded":
			clock.set_paused(true)
			hud.menu.show_message("A colonial nation", "Our %d provinces in %s are now the %s: our colony, which follows us to war and sends us a quarter of its taxes." % [
				e[4], Overseas.region_name(e[3]), nation.name])
		else:
			hud.show_toast("Our new land in %s joins the %s" % [Overseas.region_name(e[3]), nation.name])
	economy.invalidate()
	map_view.colonies_changed()
	hud.refresh_drawer_later()
	_update_treasury_ui_later()


func _on_colony_completed(province_id: int, tag: String) -> void:
	if tag == world.player_country_id and phase == Phase.PLAYING:
		hud.show_toast("%s is ours: the colony stands" % world.get_province(province_id).name)
	hud.refresh_drawer_later()


func _on_uprising(province_id: int, tag: String) -> void:
	if tag == world.player_country_id and phase == Phase.PLAYING:
		hud.show_toast("The natives of %s rise against our settlers" % world.get_province(province_id).name)
	hud.refresh_drawer_later()


func _on_discovered(province_id: int, good: String) -> void:
	var p := world.get_province(province_id)
	if p.owner_id == world.player_country_id and phase == Phase.PLAYING:
		hud.show_toast("%s discovered in %s!" % [Goods.name_of(good), p.name])
	map_view.economy_changed()
	hud.refresh_drawer_later()


func _on_construction_finished(province_id: int, building: String) -> void:
	var p := world.get_province(province_id)
	if p.owner_id == world.player_country_id and phase == Phase.PLAYING:
		hud.show_toast("The %s in %s is finished" % [Buildings.name_of(building).to_lower(), p.name])
	if building in ["fort", "dock"]:
		forces.refresh_forts()
	hud.refresh_drawer_later()


func _on_bankrupt(tag: String) -> void:
	if tag != world.player_country_id:
		return  # another country's affair: our accounts are untouched
	if phase == Phase.PLAYING:
		clock.set_paused(true)
		hud.menu.show_message("Bankruptcy", "We could not pay our way and no lender would help: our debts are repudiated. No credit for five years.")
	_update_treasury_ui()


func _show_budget(tag: String) -> void:
	if world.get_country(tag) == null:
		return
	map_view.select(0)
	map_view.select_country(tag)
	hud.show_budget(world, economy, tag)


# --- Armies and war ----------------------------------------------------------------

func _select_armies(ids: Array[int]) -> void:
	selected_armies = ids.filter(func(id: int) -> bool: return world.military.armies.has(id))
	forces.selected = selected_armies
	forces.queue_redraw()
	hud.set_army_selection(selected_armies.size())
	if selected_armies.is_empty():
		if not hud.shown_armies().is_empty():
			hud.close_drawer()
		return
	map_view.select(0)
	map_view.select_country("")
	hud.show_armies(world, military, selected_armies)


## Our armies (or, with `navy`, fleets) among the selected: what a box or a
## tap in select mode adds to.
func _own_selected(navy := false) -> Array[int]:
	var out: Array[int] = []
	for id: int in selected_armies:
		var a := world.military.get_army(id)
		if a != null and a.owner == world.player_country_id and a.navy == navy:
			out.append(id)
	return out


func _own_selection() -> bool:
	return not selected_armies.is_empty() and selected_armies.all(func(id: int) -> bool:
		var a := world.military.get_army(id)
		return a != null and a.owner == world.player_country_id)


## Sends the selected armies (or fleets) to the province or sea zone tapped:
## how long it takes, and the odds if enemies stand there; then lets them go.
func _order_selected(map_pos: Vector2) -> void:
	var target := map_view.pick(map_pos, map_camera.zoom.x)
	var p := world.get_province(target)
	if p == null:
		return
	var moved: Array = []
	var reason := ""
	var days := 0.0
	var landing := 0
	for id: int in selected_armies:
		var a := world.military.get_army(id)
		var why := ""
		# A laden fleet and a coast that is no port of ours: its troops land there.
		if a.navy and not p.is_sea and not military.can_berth(a.owner, p) and not world.military.cargo_of(a.id).is_empty():
			why = military.land_cargo(a, target)
			if why == "":
				landing += military.cargo_men(a)
				moved.append(a)
				days = maxf(days, MilitarySystem.LANDING_DAYS)
		else:
			why = military.order_move(a, target)
			if why == "":
				moved.append(a)
				days = maxf(days, military.path_days(a, a.path))
		if why != "":
			reason = why
	if moved.is_empty():
		hud.show_toast(reason)
		return
	var verb := "Sailing" if moved[0].navy else ("Landing" if moved[0].aboard != 0 else "Marching")
	if landing > 0:
		verb = "Landing %s men" % DrawerPanel.thousands(landing)
	var text := "%s to %s: %d days" % [verb, p.name, ceili(days)]
	var enemies: Array = world.military.armies_at(target, moved[0].navy).filter(func(x: Army) -> bool:
		return world.military.at_war(world.player_country_id, x.owner))
	if not enemies.is_empty():
		text += " · %d %% odds against %s men" % [int(military.estimate(moved, enemies, target).chance * 100.0),
			DrawerPanel.thousands(enemies.reduce(func(n, x): return n + x.men(), 0))]
	hud.show_toast(text)
	# The order given, the armies are let go (and box selection ends).
	if map_camera.select_mode:
		map_camera.select_mode = false
		hud.set_select_mode(false)
	_select_armies([] as Array[int])
	forces.update_positions()
	hud.refresh_drawer_later()


func _on_box_selected(from: Vector2, to: Vector2) -> void:
	hud.hide_box()
	var a := map_camera.screen_to_map(from)
	var b := map_camera.screen_to_map(to)
	var ids := forces.armies_in(Rect2(a, Vector2.ZERO).expand(b))
	if ids.is_empty():
		hud.show_toast("No armies of ours there")
		return  # select mode stays on for another try
	# Armies or fleets, never both: armies when the box holds both.
	var navy := true
	for id: int in ids:
		if not world.military.get_army(id).navy:
			navy = false
			break
	# The box adds to what is selected (of its kind; the other kind is let go);
	# select mode stays on for more boxes until an order is given, which lets
	# them go and ends it (or ⬚ again). ✕ clears.
	var chosen := _own_selected(navy)
	var added := 0
	for id: int in ids:
		if world.military.get_army(id).navy == navy and not chosen.has(id):
			chosen.append(id)
			added += 1
	_select_armies(chosen)
	var kind := "fleets" if navy else "armies"
	hud.show_toast("%d %s added · %d selected" % [added, kind, chosen.size()] if added > 0 else "Already selected")


func _show_military() -> void:
	if world.get_country(world.player_country_id) == null:
		return
	map_view.select(0)
	map_view.select_country("")
	hud.show_military(world, military, economy, world.player_country_id)


func _on_merge_requested(ids: Array) -> void:
	var armies: Array = ids.map(func(id: int) -> Army: return world.military.get_army(id))
	var why := military.merge_blocked(armies)
	if why != "":
		hud.show_toast(why)
		return
	_select_armies([military.merge(armies)] as Array[int])


## Our wars as icons under the top bar, each with our score.
func _update_wars_ui() -> void:
	_wars_ui_pending = false
	var entries := []
	for w: Dictionary in world.military.wars_of(world.player_country_id):
		entries.append([w.id, w.name, int(military.score_for(w, world.player_country_id))])
	hud.set_wars(entries)


var _wars_ui_pending := false


## Once at the end of the frame, however many battles and sieges call for it.
func _update_wars_ui_later() -> void:
	if not _wars_ui_pending:
		_wars_ui_pending = true
		_update_wars_ui.call_deferred()


## A war's pop-up: the game pauses while it is open (and runs on again when it
## is simply dismissed, if it was running).
func _show_war(war_id: int) -> void:
	if not hud.war_open():
		_resume_after_war = not clock.paused
	clock.set_paused(true)
	hud.show_war(world, military, war_id)


var _resume_after_war := false


func _on_war_closed(resume: bool) -> void:
	if resume and _resume_after_war:
		clock.set_paused(false)
	_resume_after_war = false


## An army chosen from a list: one aboard ship shows its fleet (whose panel
## selects the troops aboard).
func _on_army_requested(id: int) -> void:
	var a := world.military.get_army(id)
	if a != null and a.aboard != 0 and world.military.armies.has(a.aboard):
		id = a.aboard
	_select_armies([id] as Array[int])


func _board_selected(fleet: Army) -> void:
	var boarded := 0
	var reason := ""
	for id: int in selected_armies.duplicate():
		var a := world.military.get_army(id)
		var why := military.board(a, fleet)
		if why == "":
			boarded += a.men()
		else:
			reason = why
	if boarded == 0:
		hud.show_toast(reason)
		return
	hud.show_toast("%s men board the %s%s: sail the fleet, then tap a coast to land" % [
		DrawerPanel.thousands(boarded), fleet.name, (" (" + reason + " for some)") if reason != "" else ""])
	if map_camera.select_mode:
		map_camera.select_mode = false
		hud.set_select_mode(false)
	_select_armies([fleet.id] as Array[int])


func _on_board_requested(id: int) -> void:
	var a := world.military.get_army(id)
	if a == null:
		return
	var why := military.board(a)
	if why != "":
		hud.show_toast(why)
		return
	var fleet := world.military.get_army(a.aboard)
	hud.show_toast("%s boards the %s: sail the fleet, then tap a coast to land" % [a.name, fleet.name])
	_select_armies([fleet.id] as Array[int])


func _on_split_requested(id: int) -> void:
	var a := world.military.get_army(id)
	var other := military.split(a) if a else null
	if other != null:
		_select_armies([a.id, other.id] as Array[int])


func _on_disband_requested(id: int) -> void:
	var a := world.military.get_army(id)
	if a == null:
		return
	clock.set_paused(true)
	hud.menu.ask("Disband", "Disband %s (%s men)? They go home and cost nothing more." % [a.name, DrawerPanel.thousands(a.men())],
		"Disband", func():
			military.disband(a)
			_select_armies([] as Array[int])
			_update_treasury_ui(), true)


func _on_war_requested(tag: String) -> void:
	var player := world.player_country_id
	var why := military.war_blocked(player, tag)
	if why != "":
		hud.show_toast(why)
		return
	var sides := military.war_sides(player, tag)
	var names := func(tags: Array) -> String:
		var out: Array[String] = []
		for t: String in tags:
			out.append(world.get_country(t).name)
		return ", ".join(out)
	clock.set_paused(true)
	hud.menu.ask("Declare war", "Declare war on %s?\nWith us: %s\nAgainst us: %s\nOur levies stay at home until we mobilise (Military tab)." % [
		world.get_country(tag).name, names.call(sides.attackers), names.call(sides.defenders)], "Declare war", func():
			var war := military.declare_war(player, tag, player)
			if not war.is_empty():
				hud.show_toast("War: " + war.name)
			hud.refresh_drawer()
			_update_treasury_ui(), true)


func _show_treaty(war_id: int, with := "") -> void:
	map_view.select(0)
	map_view.select_country("")
	hud.show_treaty(world, military, war_id, with)


## Our treaty: refused if they would not sign; otherwise confirmed and signed.
func _on_treaty_proposed(war_id: int, treaty: Dictionary) -> void:
	var war := world.military.get_war(war_id)
	var player := world.player_country_id
	var why := military.treaty_blocked(war, player, treaty)
	if why != "":
		hud.show_toast(why)
		return
	if not military.treaty_accepted(war, player, treaty):
		var to := military.treaty_with(war, player, treaty)
		hud.show_toast("They refuse: our war score (%+d) and what we give (%d) do not cover what we ask (%d)" % [
			int(military.peace_score(war, player, to)), int(military.treaty_value(war, player, treaty)),
			int(ceil(military.treaty_cost(war, player, treaty)))])
		return
	clock.set_paused(true)
	hud.menu.ask("Peace", military.describe_treaty(war, player, treaty) + ".\nSign the treaty?", "Sign", func():
		hud.show_toast("Peace: " + military.conclude(war, player, treaty))
		hud.close_drawer()
		_update_treasury_ui())


## Surrender to `with`: we cede what their side holds of ours (always accepted).
func _on_surrender_requested(war_id: int, with: String) -> void:
	var war := world.military.get_war(war_id)
	var player := world.player_country_id
	var treaty := military.surrender_treaty(war, player, with)
	var why := military.treaty_blocked(war, player, treaty)
	if why != "":
		hud.show_toast(why)
		return
	clock.set_paused(true)
	hud.menu.ask("Surrender", military.describe_treaty(war, player, treaty) + ".\nSurrender?", "Surrender", func():
		hud.show_toast("Peace: " + military.conclude(war, player, treaty))
		hud.close_drawer()
		_update_treasury_ui(), true)


func _on_levies_requested(raise: bool) -> void:
	var player := world.player_country_id
	if raise:
		var why := military.mobilise_blocked(player)
		if why != "":
			hud.show_toast(why)
			return
		hud.show_toast("%s levies answer the call" % DrawerPanel.thousands(military.raise_levies(player)))
	else:
		military.disband_levies(player)
		hud.show_toast("The levies go home to their fields")
	hud.refresh_drawer()
	_update_treasury_ui()


## One region's levies called, or sent home.
func _on_district_requested(muster_id: int, raise: bool) -> void:
	var player := world.player_country_id
	var region := world.get_province(muster_id).name
	if raise:
		var why := military.district_blocked(player, muster_id)
		if why != "":
			hud.show_toast(why)
			return
		hud.show_toast("%s levies muster at %s" % [DrawerPanel.thousands(military.raise_district(player, muster_id)), region])
	else:
		military.disband_district(player, muster_id)
		hud.show_toast("The levies of %s go home to their fields" % region)
	hud.refresh_drawer()
	_update_treasury_ui()


func _on_recruit_requested(province_id: int, unit: String) -> void:
	var p := world.get_province(province_id)
	var player := world.player_country_id
	var why := military.recruit_blocked(player, p, unit)
	if why != "":
		hud.show_toast(why)
		return
	military.recruit(player, p, unit)
	hud.show_toast("Raising %s in %s: ready in %d months" % [UnitTypes.name_of(unit), p.name, UnitTypes.get_type(unit).months])
	hud.refresh_drawer()
	_update_treasury_ui()


func _on_battle(report: Dictionary) -> void:
	var player := world.player_country_id
	if not player in report.tags or phase != Phase.PLAYING:
		return
	var p := world.get_province(report.province)
	var war := world.military.get_war(report.war)
	var my_side := Military.side_of(war, player) if not war.is_empty() else -1
	var we_attacked: bool = report.attacker == player or (my_side >= 0 and Military.side_of(war, report.attacker) == my_side)
	var ours: int = report.attacker_losses if we_attacked else report.defender_losses
	var theirs: int = report.defender_losses if we_attacked else report.attacker_losses
	var won: bool = report.winner == player or (my_side >= 0 and Military.side_of(war, report.winner) == my_side)
	hud.show_toast("%s at %s: we lost %s, they lost %s" % ["Victory" if won else "Defeat", p.name,
		DrawerPanel.thousands(ours), DrawerPanel.thousands(theirs)])


func _on_occupied(province_id: int, by: String) -> void:
	var p := world.get_province(province_id)
	var player := world.player_country_id
	if phase == Phase.PLAYING and (by == player or p.owner_id == player):
		hud.show_toast(("We hold %s" if by == player else "%s has fallen") % p.name)


func _on_war_declared(war: Dictionary) -> void:
	var player := world.player_country_id
	if phase != Phase.PLAYING or Military.side_of(war, player) < 0 or war.attackers[0] == player:
		return
	clock.set_paused(true)
	var side := Military.side_of(war, player)
	var enemy_lead: String = war.attackers[0] if side == 1 else war.defenders[0]
	hud.menu.show_message("War", "%s: %s is at war with us.\nOur levies can be called from the Military tab (⚔)." % [
		war.name, world.get_country(enemy_lead).name])


func _on_peace_made(war: Dictionary, summary: String) -> void:
	var player := world.player_country_id
	if phase == Phase.PLAYING and (Military.side_of(war, player) >= 0 or player in war.get("signed", [])):
		hud.show_toast("Peace in the %s — %s" % [war.name, summary])
	_select_armies(selected_armies)


func _on_peace_offered(war: Dictionary, treaty: Dictionary, from: String) -> void:
	if phase != Phase.PLAYING:
		return
	var text := "%s offers peace. %s." % [world.get_country(from).name, military.describe_treaty(war, from, treaty)]
	clock.set_paused(true)
	hud.menu.ask("Peace offered", text + "\nAccept?", "Accept", func():
		hud.show_toast("Peace: " + military.conclude(war, from, treaty))
		hud.refresh_drawer()
		_update_treasury_ui())


## A subject that had stayed out is drawn in (its land was attacked).
func _on_war_joined(war: Dictionary, tag: String) -> void:
	if phase == Phase.PLAYING and Military.side_of(war, world.player_country_id) >= 0:
		hud.show_toast("%s joins the %s: its land was attacked" % [world.get_country(tag).name, war.name])


func _on_regiment_raised(province_id: int, tag: String, unit: String) -> void:
	if tag == world.player_country_id and phase == Phase.PLAYING:
		hud.show_toast("%s ready in %s" % [UnitTypes.name_of(unit), world.get_province(province_id).name])


func _update_player_ui() -> void:
	hud.set_player_country(world.get_country(world.player_country_id),
		MapModes.country_color(world, world.player_country_id))
	if forces:
		forces.player_tag = world.player_country_id
		forces.refresh()
	if economy != null:
		_update_treasury_ui()


# --- Phases ---------------------------------------------------------------------

func _show_title() -> void:
	phase = Phase.TITLE
	clock.set_paused(true)
	_clear_selection()
	hud.set_screen(HUD.Screen.TITLE)
	hud.menu.show_title(saves.latest_save(world.data_version, world.data_fingerprint))
	if music:
		music.jump_to(GameClock.EPOCH_YEAR)


## New campaign: back to 1 January 1590, then the player taps a country.
func _choose_country() -> void:
	campaign.start_new(_default_player)
	phase = Phase.CHOOSING
	_clear_selection()
	hud.menu.close()
	hud.set_screen(HUD.Screen.CHOOSING)
	hud.set_date_text(clock.format_date())
	map_camera.recenter()


func _play_as(tag: String) -> void:
	var errors := campaign.start_new(tag, _new_seed())
	if not errors.is_empty():
		push_error("Cannot start as %s: %s" % [tag, errors])
		return
	_enter_playing()
	_focus_capital(tag, 1.2)


## Music for the campaign's year and the player's region.
func _retune_music() -> void:
	if music == null:
		return
	var c := world.get_country(world.player_country_id)
	var capital := world.get_province(c.capital_province_id) if c else null
	music.jump_to(clock.year, capital.region if capital else "")


func _enter_playing() -> void:
	_retune_music()
	phase = Phase.PLAYING
	_clear_selection()
	hud.menu.close()
	hud.set_screen(HUD.Screen.PLAYING)
	_update_player_ui()
	_update_time_ui()
	hud.set_date_text(clock.format_date())


func _open_game_menu() -> void:
	clock.set_paused(true)
	hud.menu.show_pause()


static func _new_seed() -> int:
	return hash([Time.get_unix_time_from_system(), Time.get_ticks_usec(), OS.get_process_id()])


# --- Saving and loading -----------------------------------------------------------

## Saves at a safe point: any unfinished simulation work for the day completes
## first, so a save never holds half a day.
func _save_game(slot := "") -> void:
	if slot == "":
		slot = saves.new_slot_name(campaign)
	scheduler.finish_pending()
	if saves.save(campaign, slot):
		hud.menu.close()
		hud.show_toast("Game saved — " + campaign.title())
	else:
		hud.menu.show_message("Could not save", "\n".join(saves.errors.slice(0, 6)))


func _autosave(notify := false) -> void:
	_autosave_due = false
	if phase != Phase.PLAYING:
		return
	scheduler.finish_pending()
	if saves.save(campaign, SaveService.AUTOSAVE_SLOT):
		if notify:
			hud.show_toast("Autosaved — " + clock.format_date())
	else:
		push_error("Autosave failed: %s" % [saves.errors])
		if notify:
			hud.show_toast("Autosave failed: " + (saves.errors[0] if not saves.errors.is_empty() else "unknown error"))


func _show_saves() -> void:
	hud.menu.show_saves(saves.list_saves(world.data_version, world.data_fingerprint), saves.folder_path())


func _load_save(slot: String, from_backup: bool) -> void:
	if not saves.load_into(campaign, slot, from_backup):
		var text := "\n".join(saves.errors.slice(0, 6))
		if saves.errors.size() > 6:
			text += "\n… and %d more problems." % (saves.errors.size() - 6)
		hud.menu.show_message("Could not load this save", text)
		return
	_autosave_due = false
	_enter_playing()
	_focus_capital(world.player_country_id)
	hud.show_toast("Loaded — " + campaign.title())


func _delete_save(slot: String) -> void:
	if not saves.delete(slot):
		hud.menu.show_message("Could not delete", "\n".join(saves.errors))
		return
	_show_saves()


# --- Diplomacy ---------------------------------------------------------------------------

func _on_diplomacy_requested(action: int, tag: String) -> void:
	var player := world.player_country_id
	var why := diplomacy_actions.blocked(action, player, tag)
	if why != "":
		hud.show_toast(why)
		return
	var A := DiplomacyActions
	if action in A.PROPOSALS or action in A.HOSTILE or action == A.Action.SEND_GIFT:
		clock.set_paused(true)  # never let time run under a decision
		hud.menu.ask(A.LABELS[action], _describe_action(action, tag), A.LABELS[action],
			func(): _do_diplomacy(action, tag), action in A.HOSTILE)
	else:
		_do_diplomacy(action, tag)


## A gift of the player's chosen size, confirmed first.
func _on_gift_requested(tag: String, amount: int) -> void:
	var player := world.player_country_id
	var A := DiplomacyActions.Action
	var why := diplomacy_actions.blocked(A.SEND_GIFT, player, tag, amount)
	if why != "":
		hud.show_toast(why)
		return
	clock.set_paused(true)
	var name := world.get_country(tag).name
	hud.menu.ask("Send gift", "Send %s a gift of %d ducats (we have %d)?\nTheir opinion of us: +%d, fading by 1 a month." % [
		name, amount, roundi(world.get_country(player).treasury), int(diplomacy_actions.gift_opinion(tag, amount))],
		"Send gift", func():
			var result := diplomacy_actions.perform(A.SEND_GIFT, player, tag, amount)
			hud.show_toast(result.message)
			hud.refresh_drawer()
			_update_treasury_ui())


func _do_diplomacy(action: int, tag: String) -> void:
	var result := diplomacy_actions.perform(action, world.player_country_id, tag)
	hud.show_toast(result.message)
	hud.refresh_drawer()
	_update_treasury_ui()


## What the player is told before confirming: costs, consequences, and for
## proposals the other side's reasoning, line by line.
func _describe_action(action: int, tag: String) -> String:
	var A := DiplomacyActions.Action
	var player := world.player_country_id
	var name := world.get_country(tag).name
	match action:
		A.SEND_GIFT:
			return "Send %s a gift of %d ducats (we have %d).\nTheir opinion of us: +%d, fading by 1 a month." % [
				name, diplomacy_actions.gift_cost(tag), roundi(world.get_country(player).treasury),
				int(DiplomacyActions.GIFT_OPINION)]
		A.SEND_INSULT:
			return "Insult %s?\nTheir opinion of us: %d, fading by 1 a month." % [name, int(DiplomacyActions.INSULT_OPINION)]
		A.DECLARE_RIVAL:
			return "Declare %s our rival?\nThey will regard us at %d, and we them at %d. We may keep %d rivals." % [
				name, Diplomacy.OPINION_RIVAL_OF_US, Diplomacy.OPINION_OUR_RIVAL, Diplomacy.MAX_RIVALS]
		A.BREAK_ALLIANCE:
			return "Break our alliance with %s?\nTheir opinion of us: %d, fading by 1 a month." % [
				name, int(DiplomacyActions.BROKE_ALLIANCE_OPINION)]
		A.BREAK_MARRIAGE:
			return "End our royal marriage with %s?\nTheir opinion of us: %d, fading by 1 a month." % [
				name, int(DiplomacyActions.BROKE_MARRIAGE_OPINION)]
		A.RELEASE_SUBJECT:
			return "Release %s from our rule? They become independent and will think better of us (+%d)." % [
				name, int(DiplomacyActions.RELEASED_OPINION)]
	var verdict := diplomacy_actions.evaluate(action, player, tag)
	var lines := PackedStringArray(["How %s weighs it:" % name])
	for r: Array in verdict.reasons:
		lines.append("   %s   %+d" % [r[0], r[1]])
	lines.append("Total %+d — %s" % [verdict.total, "they would accept" if verdict.accept else "they would refuse"])
	return "\n".join(lines)


## Notices when another country does something to us.
func _on_diplomacy_performed(action: int, from: String, to: String, accepted: bool) -> void:
	var player := world.player_country_id
	if to != player or from == player or phase != Phase.PLAYING:
		return
	var A := DiplomacyActions.Action
	var who := world.get_country(from).name
	var text := ""
	match action:
		A.SEND_GIFT:
			text = "%s sent us a gift" % who
		A.SEND_INSULT:
			text = "%s has insulted us!" % who
		A.DECLARE_RIVAL:
			text = "%s has declared us their rival" % who
		A.REMOVE_RIVAL:
			text = "%s no longer counts us a rival" % who
		A.BREAK_ALLIANCE:
			text = "%s has broken our alliance" % who
		A.BREAK_MARRIAGE:
			text = "%s has ended our royal marriage" % who
	if text != "":
		hud.show_toast(text)


# --- Selection ------------------------------------------------------------------------

func _on_map_tapped(map_pos: Vector2) -> void:
	if phase == Phase.TITLE:
		return
	if phase == Phase.PLAYING:
		# The peace table open: a tap picks the land to demand or give.
		if hud.treaty_open():
			var message := hud.treaty_toggle(map_view.pick(map_pos, map_camera.zoom.x))
			if message != "":
				hud.show_toast(message)
			return
		# Armies first: a tap on one selects it (again: lets it go); with our
		# armies selected, a tap elsewhere sends them there.
		var hit := forces.army_at(map_pos)
		if hit != 0:
			var ids: Array[int] = []
			var hit_army := world.military.get_army(hit)
			# Our armies selected and a tap on a fleet of ours: they board it.
			if hit_army.navy and hit_army.owner == world.player_country_id and _own_selection() \
					and selected_armies.all(func(sid: int) -> bool:
						var s := world.military.get_army(sid)
						return s != null and not s.navy and s.aboard == 0):
				_board_selected(hit_army)
				return
			if map_camera.select_mode and hit_army.owner == world.player_country_id:
				ids = _own_selected(hit_army.navy)  # select mode: a tap adds it (of its kind), or lets it go
				if ids.has(hit):
					ids.erase(hit)
				else:
					ids.append(hit)
			elif not (selected_armies.size() == 1 and selected_armies[0] == hit):
				ids.append(hit)
			_select_armies(ids)
			return
		if _own_selection():
			_order_selected(map_pos)
			return
		if not selected_armies.is_empty():
			_select_armies([] as Array[int])
	var id := map_view.pick(map_pos, map_camera.zoom.x)
	var tag := overlay.country_label_at(map_pos)
	if phase == Phase.CHOOSING:
		var p := world.get_province(id)
		if tag == "" and p and p.owner_id != "":
			tag = p.owner_id
	elif tag != "" and tag == hud.shown_country():
		tag = ""  # a second tap on a country's name picks the province under it
	if tag != "":
		_show_country(tag)
	else:
		_show_province(id)


func _show_province(id: int, focus := false) -> void:
	map_view.select_country("")
	map_view.select(id)
	var p := world.get_province(id)
	if focus and p:
		map_camera.focus_on(p.label_position, maxf(map_camera.zoom.x, 1.6))


## Fits the camera to a country's home: the land joined to its capital, and
## any of its land within HOME_KM of it (not its far-flung colonies), framed in
## the map left beside the drawer.
const HOME_KM := 700.0


func _focus_country(tag: String) -> void:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id) if c else null
	if cap == null:
		return
	var home := {cap.id: true}
	var frontier: Array[int] = [cap.id]
	while not frontier.is_empty():
		var next: Array[int] = []
		for id: int in frontier:
			for n: int in world.get_province(id).neighbour_ids:
				if not home.has(n) and world.get_province(n).owner_id == tag:
					home[n] = true
					next.append(n)
		frontier = next
	var rect := Rect2(cap.label_position, Vector2.ZERO)
	for p: Province in world.ownable_provinces():
		if p.owner_id == tag and (home.has(p.id) or DiplomacyActions._haversine(p.lat, p.lon, cap.lat, cap.lon) <= HOME_KM):
			rect = rect.merge(Rect2(p.bounds))
	var view := map_camera.view_size()
	var free := hud.free_map_rect()  # screen area left for the map (beside the drawer, between the bars)
	var z := minf(free.size.x / maxf(rect.size.x, 1.0), free.size.y / maxf(rect.size.y, 1.0)) * 0.85
	z = clampf(z, map_camera.min_zoom, 5.0)
	# Put the country's middle at the middle of the free area.
	var center := rect.get_center() - (free.get_center() - view * 0.5) / z
	map_camera.focus_on(center, z)


func _show_country(tag: String) -> void:
	map_view.select(0)
	map_view.select_country(tag)


func _clear_selection() -> void:
	map_view.select(0)
	map_view.select_country("")
	selected_armies = []
	if forces:
		forces.selected = selected_armies
		forces.queue_redraw()
	hud.set_army_selection(0)
	hud.close_drawer()


func _locate_country(tag: String) -> void:
	_focus_capital(tag, maxf(map_camera.zoom.x, 1.0))


func _focus_capital(tag: String, zoom := -1.0) -> void:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id) if c else null
	if cap:
		map_camera.focus_on(cap.label_position, zoom)


# --- Input and app lifecycle ------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			if phase == Phase.PLAYING and not hud.menu.visible:
				clock.toggle_pause()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			clock.set_speed(event.keycode - KEY_0)
		KEY_ESCAPE:
			_go_back(false)


## Android back button / Esc: close the innermost thing that is open.
func _go_back(may_quit: bool) -> void:
	if hud.menu.visible:
		if not hud.menu.back() and may_quit:
			get_tree().quit()
	elif hud.drawer_open():
		_clear_selection()
	elif phase == Phase.CHOOSING:
		_show_title()
	elif phase == Phase.PLAYING:
		_open_game_menu()


func _notification(what: int) -> void:
	match what:
		# Never let the campaign run unattended: pause when backgrounded or
		# unfocused. The app may be killed in the background, so save too.
		NOTIFICATION_APPLICATION_PAUSED:
			clock.set_paused(true)
			_autosave()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			clock.set_paused(true)
		NOTIFICATION_WM_CLOSE_REQUEST:
			_autosave()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_go_back(true)


# --- Debug options ---------------------------------------------------------------------------

static func _debug_args() -> Dictionary:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	return args


func _apply_debug_args(args: Dictionary) -> void:
	if args.has("load"):
		_load_save(args.load, false)
	if args.has("play") and world.countries.has(args.play):
		_play_as(args.play)
	if args.has("occupy"):
		for id in args.occupy.split(","):
			world.set_controller(int(id), world.player_country_id)
	if args.has("mode"):
		var wanted: String = "topography" if args.mode == "terrain" else args.mode  # old name
		for m in MapModes.NAMES:
			if MapModes.NAMES[m].to_lower() == wanted:
				_set_map_mode(m)
	if args.has("modes"):
		hud.show_mode_group(int(args.modes))
	if args.has("war"):  # --war=TAG: we declare war on TAG (debug)
		military.declare_war(world.player_country_id, args.war, world.player_country_id)
	if args.has("levies"):
		military.raise_levies(world.player_country_id)
	if args.has("days"):  # --days=N: let N days pass at once (debug)
		for i in int(args.days):
			clock.step_day()
		forces.update_positions()
	if args.has("army"):  # --army: select our first army (--army=fleet: our first fleet)
		var ours := world.military.armies_of(world.player_country_id, args.army == "fleet")
		if not ours.is_empty():
			_select_armies([ours[0].id] as Array[int])
	if args.has("march") and not selected_armies.is_empty():  # --march=lat,lon
		var ll: PackedStringArray = args.march.split(",")
		_order_selected(world.latlon_to_map(float(ll[0]), float(ll[1])))
	if args.has("select"):
		_show_province(int(args.select))
	if args.has("country"):
		_show_country(args.country)
	if args.has("budget"):
		_show_budget(args.budget)
	if args.has("military"):
		_show_military()
	if args.has("board"):  # --board: our first army boards ship (debug)
		var ours := world.military.armies_of(world.player_country_id)
		if not ours.is_empty() and military.board(ours[0]) == "":
			_select_armies([ours[0].aboard] as Array[int])
	if args.has("wars"):  # --wars: the panel of our first war
		var ours := world.military.wars_of(world.player_country_id)
		if not ours.is_empty():
			_show_war(ours[0].id)
	if args.has("treaty"):  # --treaty: the peace table of our first war
		var wars := world.military.wars_of(world.player_country_id)
		if not wars.is_empty():
			_show_treaty(wars[0].id)
	if args.has("at"):
		var ll: PackedStringArray = args.at.split(",")
		map_camera.focus_on(world.province_near(float(ll[0]), float(ll[1])).label_position)
	if args.has("zoom"):
		var p := world.get_province(map_view.selected_id)
		map_camera.focus_on(p.label_position if p and not args.has("at") else map_camera.position, float(args.zoom))
	if args.has("screenshot"):
		for i in 40:  # let view-dependent tiles stream in
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.screenshot)
		get_tree().quit()
