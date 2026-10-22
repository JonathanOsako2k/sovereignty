extends "res://tests/test_case.gd"
## End-to-end smoke test of the app flow with the real scene (headless):
## title menu → new campaign → choose a country on the map → play → save →
## main menu → continue.

const DIR := "user://test_flow_saves"


func _clean() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR.path_join(file))
		DirAccess.remove_absolute(DIR)


func test_title_choose_play_save_continue() -> void:
	_clean()
	var tree := Engine.get_main_loop() as SceneTree
	var game: Node = load("res://game.tscn").instantiate()
	game.saves.save_dir = DIR
	tree.root.add_child(game)
	var menu: MenuScreen = game.hud.menu
	var world: WorldState = game.world

	check_eq(game.phase, game.Phase.TITLE, "starts on the title menu")
	check(menu.visible and menu.page == MenuScreen.Page.TITLE, "title menu shown")
	menu.new_campaign_requested.emit()
	check_eq(game.phase, game.Phase.CHOOSING, "choosing a country")
	check(not menu.visible, "menu closed while choosing")

	game._on_map_tapped(world.latlon_to_map(47.39, 0.69))
	check_eq(game.hud.shown_country(), "FRA", "tapping Tours offers France")
	check_eq(game.map_view.selected_country, "FRA", "France is highlighted")
	game.hud.play_requested.emit("FRA")
	check_eq(game.phase, game.Phase.PLAYING, "playing")
	check_eq(world.player_country_id, "FRA", "player is France")
	check(game.clock.paused, "a new campaign starts paused")
	check(not game.hud.drawer_open(), "drawer closed when play starts")

	game._on_map_tapped(world.latlon_to_map(53.96, -1.08))
	check_eq(game.map_view.selected_id, world.province_near(53.96, -1.08).id, "tapping York selects it")
	# An army stands at London: a tap on its banner selects it, a second lets it go.
	var london := world.province_near(51.51, -0.13)
	var english: Army = world.military.armies_of("ENG")[0]
	check_eq(english.location, london.id, "England's army is at London")
	game.map_camera.focus_on(london.label_position, 4.5)  # small foreign armies show close in
	game._on_map_tapped(game.forces.army_position(english.id))
	check_eq(game.selected_armies, [english.id] as Array[int], "tapping the banner selects the army")
	check_eq(game.hud.shown_armies(), [english.id] as Array[int], "and shows it")
	game._on_map_tapped(game.forces.army_position(english.id))
	check(game.selected_armies.is_empty(), "a second tap lets it go")
	# Box selection: boxes add our armies up while select mode stays on; an
	# order ends it; armies or fleets, never both (armies first); ✕ clears.
	var paris := world.get_province(world.get_country("FRA").capital_province_id)
	var french: Army = world.military.armies_of("FRA")[0]
	var fleet: Army = world.military.armies_of("FRA", true)[0]
	var second := world.military.add_army("FRA", paris.neighbour_ids[0], [["pike_and_shot", 1000, 0]], false, "Second army")
	game.forces.refresh()
	game.map_camera.focus_on(paris.label_position, 4.5)
	game.hud._select_button.button_pressed = true
	check(game.map_camera.select_mode, "select mode on")
	var at: Vector2 = game.map_camera.map_to_screen(game.forces.army_position(french.id))
	game._on_box_selected(at - Vector2(6, 6), at + Vector2(6, 6))
	check_eq(game.selected_armies, [french.id] as Array[int], "a box selects the army")
	check(game.map_camera.select_mode and game.hud._select_button.button_pressed, "select mode stays on")
	check(game.hud._clear_button.visible, "the clear button shows")
	# Over armies and the fleet at once: the armies join, the fleet does not.
	game.map_camera.focus_on(paris.label_position.lerp(game.forces.army_position(fleet.id), 0.5), 2.0)
	var view := Rect2(game.map_camera.screen_to_map(Vector2.ZERO), Vector2.ZERO).expand(game.map_camera.screen_to_map(game.map_camera.view_size()))
	check(game.forces.armies_in(view).has(fleet.id), "the box covers the fleet too")
	game._on_box_selected(Vector2.ZERO, game.map_camera.view_size())
	check_eq(game.selected_armies, [french.id, second.id] as Array[int], "boxes add up, armies before fleets")
	# An order sends them off, lets them go and ends select mode.
	game._on_map_tapped(world.province_near(44.84, -0.58).label_position)  # Bordeaux
	check(second.is_moving() and french.is_moving(), "both ordered to march")
	check(not game.map_camera.select_mode and not game.hud._select_button.button_pressed, "the order ends select mode")
	check(game.selected_armies.is_empty(), "and lets the armies go")
	for a: Army in [french, second]:
		a.path.clear()
	# The fleet alone: a selection of fleets instead.
	game.map_camera.focus_on(game.forces.army_position(fleet.id), 4.5)
	game.hud._select_button.button_pressed = true
	at = game.map_camera.map_to_screen(game.forces.army_position(fleet.id))
	game._on_box_selected(at - Vector2(4, 4), at + Vector2(4, 4))
	check_eq(game.selected_armies, [fleet.id] as Array[int], "never armies and fleets together")
	game.hud._clear_button.pressed.emit()
	check(game.selected_armies.is_empty(), "the clear button lets them all go")
	check(game.map_camera.select_mode and game.hud._clear_button.disabled, "select mode stays on, nothing to clear")
	game.hud._select_button.button_pressed = false
	check(not game.map_camera.select_mode and not game.hud._clear_button.visible, "⬚ again ends it")
	world.military.remove_army(second.id)
	# A tap in the sea beside a one-pixel island picks the island.
	var male := world.province_near(4.18, 73.49)
	check(male.area <= MapView.TINY_AREA, "Malé is a tiny province (%d px)" % male.area)
	check_eq(game.map_view.pick(male.label_position + Vector2(2.5, 0), 3.0), male.id, "a tap beside Malé picks it")
	# Our name in the top bar frames our home.
	game.hud.country_focus_requested.emit("FRA")
	var paris_at: Vector2 = game.map_camera.map_to_screen(world.get_province(world.get_country("FRA").capital_province_id).label_position)
	check(game.hud.free_map_rect().has_point(paris_at), "Paris in view after tapping our name")
	check(game.map_camera.zoom.x > game.map_camera.min_zoom, "zoomed in on France")
	game._on_map_tapped(world.latlon_to_map(53.96, -1.08))
	game.hud.country_requested.emit("ENG")
	check_eq(game.hud.shown_country(), "ENG", "owner link opens England")
	check_eq(game.map_view.selected_id, 0, "province selection cleared")

	# Diplomacy through the panel: a gift needs confirming, and pauses the game.
	var swiss_before := world.diplomacy.opinion("SWI", "FRA")
	var treasury := world.get_country("FRA").treasury
	game.clock.set_paused(false)
	game.hud.diplomacy_requested.emit(DiplomacyActions.Action.SEND_GIFT, "SWI")
	check(game.clock.paused, "a decision pauses the game")
	check_eq(menu.page, MenuScreen.Page.CONFIRM, "gift asks for confirmation")
	var confirm := _button(menu, "Send gift")
	check(confirm != null, "confirm button present")
	if confirm:
		confirm.pressed.emit()
	check(not menu.visible, "confirmation closes")
	check(world.diplomacy.opinion("SWI", "FRA") > swiss_before, "the Swiss think better of us")
	check(world.get_country("FRA").treasury < treasury, "and it cost us")

	for i in 40:
		game.clock.step_day()
	var date: String = game.clock.format_date()
	world.set_controller(world.province_near(48.86, 2.35).id, "SPA")
	game.hud.menu_requested.emit()
	check(game.clock.paused, "the menu pauses the game")
	check_eq(menu.page, MenuScreen.Page.PAUSE, "in-game menu")
	menu.save_requested.emit()
	check(not menu.visible, "menu closes after saving")
	check_eq(game.saves.list_saves(world.data_version).size(), 1, "one save on disk")

	menu.main_menu_requested.emit()
	check_eq(game.phase, game.Phase.TITLE, "back on the title menu")
	menu.new_campaign_requested.emit()
	check_eq(game.clock.format_date(), "1 January 1590", "a new campaign starts in 1590")
	check(not world.province_near(48.86, 2.35).is_occupied(), "and with the 1590 map")
	game._show_title()
	check(not menu._latest.is_empty(), "title offers Continue")
	menu.continue_requested.emit(menu._latest.get("slot", ""))
	check_eq(game.phase, game.Phase.PLAYING, "continued")
	check_eq(world.player_country_id, "FRA", "as France")
	check_eq(game.clock.format_date(), date, "on the saved date")
	check_eq(world.province_near(48.86, 2.35).controller_id, "SPA", "with Paris still occupied")

	game._go_back(false)
	check_eq(menu.page, MenuScreen.Page.PAUSE, "back opens the in-game menu")
	game._go_back(false)
	check(not menu.visible, "back again resumes")

	# New Year's Day autosaves once the day's work is done.
	game.clock.set_date(1590, 12, 31)
	game.clock.step_day()
	game._process(1.0 / 60.0)
	var autosave: Array = game.saves.list_saves(world.data_version).filter(
		func(i: Dictionary) -> bool: return i.slot == SaveService.AUTOSAVE_SLOT)
	check(autosave.size() == 1 and autosave[0].ok, "autosaved on 1 January")
	if autosave.size() == 1:
		check_eq(autosave[0].date_text, "1 January 1591", "autosave date")

	# A war's badge opens it as a pop-up: the game pauses, our side on the
	# left, theirs on the right; dismissed, the game runs on.
	var war: Dictionary = game.military.declare_war(world.player_country_id, "SAV", world.player_country_id)
	if not war.is_empty():
		game.clock.set_paused(false)
		game.hud.war_panel_requested.emit(war.id)
		check(game.hud.war_open() and game.clock.paused, "the war pops up and the game pauses")
		var popup: WarPanel = game.hud._war_panel
		check(popup._ours.get_child_count() >= 1 and popup._theirs.get_child_count() >= 1, "both sides listed")
		check(_button(popup._theirs, "Sue for peace") != null, "peace sued for from their side")
		popup.close()
		check(not game.hud.war_open() and not game.clock.paused, "dismissed, the game runs on")
	game.free()
	_clean()


func _button(root: Node, text: String) -> Button:
	for child in root.find_children("*", "Button", true, false):
		if (child as Button).text == text:
			return child
	return null
