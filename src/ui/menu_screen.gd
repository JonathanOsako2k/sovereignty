class_name MenuScreen
extends Control
## Full-screen menus over the dimmed map: the title menu, the in-game menu, the
## list of saved games, confirmations and messages. Shows what the Game gives
## it and reports choices through signals; it never touches save files or the
## campaign itself.

signal continue_requested(slot: String)
signal new_campaign_requested
signal load_page_requested
signal load_requested(slot: String, from_backup: bool)
signal delete_requested(slot: String)
signal save_requested
signal resume_requested
signal main_menu_requested
signal quit_requested
signal music_toggled(on: bool)

enum Page { NONE, TITLE, PAUSE, SAVES, CONFIRM, MESSAGE }

const CARD_WIDTH := 560.0
## Painting behind the title menu (any of these, whichever exists); the dimmed
## map shows instead when there is none.
const BACKGROUND_PATHS := ["res://assets/menu_background.jpg", "res://assets/menu_background.png",
	"res://assets/menu_background.webp"]

var page := Page.NONE
## True when opened from a running campaign (loading then needs confirmation).
var in_game := false
## Whether music plays, and whether there is any (the game sets both; the
## title and in-game menus then offer a Music: On / Off toggle).
var music_on := true
var music_available := false

var _card: PanelContainer
var _background: TextureRect
var _dim: ColorRect
var _center: CenterContainer
var _box: VBoxContainer
var _latest: Dictionary = {}
var _saves: Array = []
var _save_folder := ""
## Page to return to from a confirmation or message.
var _return_page := Page.NONE


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_background = TextureRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path: String in BACKGROUND_PATHS:
		if ResourceLoader.exists(path):
			_background.texture = load(path)
			break
	add_child(_background)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_card = PanelContainer.new()
	_center.add_child(_card)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_card.add_child(_box)
	resized.connect(_fit)


func _fit() -> void:
	# Over the painting in landscape, the card keeps to the right half so the
	# figures in the middle of the picture stay in view.
	var side := _background.visible and size.x >= size.y * 1.4
	_center.anchor_left = 0.5 if side else 0.0
	_center.offset_left = 0.0
	_center.offset_right = -24.0 if side else 0.0
	var room := size.x * 0.5 - 24.0 if side else size.x - 32.0
	_card.custom_minimum_size.x = minf(CARD_WIDTH, room)


# --- Pages -----------------------------------------------------------------------

## `latest` is the newest loadable save (SaveService.latest_save) or {}.
func show_title(latest: Dictionary) -> void:
	in_game = false
	_latest = latest
	_open(Page.TITLE)


func show_pause() -> void:
	in_game = true
	_open(Page.PAUSE)


## `saves` as listed by SaveService.list_saves; `folder` is where they are
## stored on this device, shown so the player can find the files.
func show_saves(saves: Array, folder := "") -> void:
	_saves = saves
	_save_folder = folder
	_open(Page.SAVES)


func show_message(title: String, text: String) -> void:
	if page == Page.NONE:
		in_game = true  # a notice during play: over the dimmed map, not the title painting
	_return_page = page if page != Page.MESSAGE and page != Page.CONFIRM else _return_page
	_clear()
	page = Page.MESSAGE
	visible = true
	_update_backdrop()
	_add_title(title, 26)
	_add_text(text)
	var ok := UITheme.primary_button("OK")
	ok.pressed.connect(func(): _open(_return_page))
	_box.add_child(ok)


## A yes/no question outside the other pages (a diplomatic decision, say).
## Confirming closes the menu, then calls `on_confirm`.
func ask(title: String, text: String, action: String, on_confirm: Callable, destructive := false) -> void:
	_return_page = Page.NONE
	in_game = true
	_confirm(text, action, func():
		close()
		on_confirm.call(), destructive)
	visible = true
	_update_backdrop()
	var heading := _add_title(title, 24)
	_box.move_child(heading, 0)


func close() -> void:
	visible = false
	page = Page.NONE


## Goes one step back (Android back button, Esc). Returns false on the title
## page, where there is nothing to go back to.
func back() -> bool:
	match page:
		Page.TITLE:
			return false
		Page.PAUSE:
			resume_requested.emit()
		Page.SAVES:
			_open(Page.PAUSE if in_game else Page.TITLE)
		Page.CONFIRM, Page.MESSAGE:
			_open(_return_page)
	return true


## The painting backs the menus outside a campaign (title, its load list and
## messages); in-game menus dim the map instead.
func _update_backdrop() -> void:
	_background.visible = _background.texture != null and not in_game
	_dim.color = Color(0.05, 0.04, 0.03, 0.3 if _background.visible else 0.55)
	_fit()


func _open(p: Page) -> void:
	_clear()
	page = p
	visible = p != Page.NONE
	_update_backdrop()
	match p:
		Page.TITLE:
			_build_title()
		Page.PAUSE:
			_build_pause()
		Page.SAVES:
			_build_saves()


func _clear() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()


func _build_title() -> void:
	_add_title("SOVEREIGNTY", 46)
	var tagline := _add_text("A grand strategy of the world, 1590 – 1949")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_spacer(6))
	if not _latest.is_empty():
		var cont := UITheme.primary_button("Continue")
		cont.pressed.connect(func(): continue_requested.emit(_latest.slot))
		_box.add_child(cont)
		var kind := "Autosave: " if _latest.slot == SaveService.AUTOSAVE_SLOT else ""
		var info := UITheme.label("%s%s  ·  saved %s" % [kind, _latest.title, SaveService.format_timestamp(_latest.saved_at)],
			14, UITheme.TEXT_DIM)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.clip_text = true
		info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_box.add_child(info)
	var new_game := UITheme.primary_button("New campaign") if _latest.is_empty() else UITheme.button("New campaign")
	new_game.pressed.connect(func(): new_campaign_requested.emit())
	_box.add_child(new_game)
	var load_button := UITheme.button("Load game")
	load_button.pressed.connect(func(): load_page_requested.emit())
	_box.add_child(load_button)
	_add_music_toggle()
	if not OS.has_feature("mobile"):
		var quit := UITheme.button("Quit")
		quit.pressed.connect(func(): quit_requested.emit())
		_box.add_child(quit)


func _build_pause() -> void:
	_add_title("Paused", 32)
	var resume := UITheme.primary_button("Resume")
	resume.pressed.connect(func(): resume_requested.emit())
	_box.add_child(resume)
	var save := UITheme.button("Save game")
	save.pressed.connect(func(): save_requested.emit())
	_box.add_child(save)
	var load_button := UITheme.button("Load game")
	load_button.pressed.connect(func(): load_page_requested.emit())
	_box.add_child(load_button)
	_add_music_toggle()
	var main_menu := UITheme.button("Main menu")
	main_menu.pressed.connect(func(): _confirm(
		"Return to the main menu? Progress since your last save will be lost.", "Main menu",
		func(): main_menu_requested.emit()))
	_box.add_child(main_menu)


func _add_music_toggle() -> void:
	if not music_available:
		return
	var toggle := UITheme.button("Music: On" if music_on else "Music: Off")
	toggle.pressed.connect(func():
		music_on = not music_on
		toggle.text = "Music: On" if music_on else "Music: Off"
		music_toggled.emit(music_on))
	_box.add_child(toggle)


func _build_saves() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_box.add_child(header)
	var title := _add_title("Saved games", 26, header)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back_button := UITheme.button("Back")
	back_button.pressed.connect(func(): back())
	header.add_child(back_button)

	if _save_folder != "":
		var where := UITheme.label("Save files: " + _save_folder, 13, UITheme.TEXT_DIM)
		where.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		where.custom_minimum_size.x = 200
		_box.add_child(where)
	if _saves.is_empty():
		_add_text("No saved games yet.")
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for info: Dictionary in _saves:
		list.add_child(_save_row(info))
	# As tall as the list, scrolling only when it would not fit on screen. The
	# list's real height is known once it has its width (wrapped error texts).
	var fit := func() -> void:
		scroll.custom_minimum_size.y = minf(list.size.y, maxf(size.y - 200.0, 160.0))
	list.resized.connect(fit)
	scroll.custom_minimum_size.y = 160.0


func _save_row(info: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var name_label := UITheme.label(("Autosave — " if info.slot == SaveService.AUTOSAVE_SLOT else "") + info.country, 18)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(name_label)
	var when := UITheme.label(info.date_text, 15, UITheme.ACCENT)
	if info.saved_at > 0:
		when.text += ("  ·  saved " if info.date_text != "" else "Saved ") + SaveService.format_timestamp(info.saved_at)
	when.clip_text = true
	when.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(when)
	if not info.ok:
		var problem := UITheme.label("Damaged — its backup copy can be loaded" if info.backup_ok else "Cannot load: " + info.error,
			14, UITheme.DANGER)
		problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(problem)

	var from_backup: bool = not info.ok and info.backup_ok
	var load_button := UITheme.primary_button("Load backup" if from_backup else "Load")
	load_button.disabled = not info.ok and not info.backup_ok
	load_button.pressed.connect(func():
		if in_game:
			_confirm("Load “%s”? Progress since your last save will be lost." % info.title, "Load",
				func(): load_requested.emit(info.slot, from_backup))
		else:
			load_requested.emit(info.slot, from_backup))
	row.add_child(load_button)
	var delete := UITheme.button("Delete")
	delete.add_theme_color_override("font_color", UITheme.DANGER)
	delete.pressed.connect(func(): _confirm(
		"Delete “%s”? This cannot be undone." % info.title, "Delete",
		func(): delete_requested.emit(info.slot), true))
	row.add_child(delete)
	return row


func _confirm(text: String, action: String, on_confirm: Callable, destructive := false) -> void:
	_return_page = page
	_clear()
	page = Page.CONFIRM
	_add_text(text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	_box.add_child(buttons)
	var cancel := UITheme.button("Cancel")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): _open(_return_page))
	buttons.add_child(cancel)
	var ok := UITheme.primary_button(action)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if destructive:
		ok.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8))
		var box := ok.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		box.bg_color = UITheme.DANGER.darkened(0.45)
		box.border_color = UITheme.DANGER
		for state in ["normal", "hover", "focus"]:
			ok.add_theme_stylebox_override(state, box)
	ok.pressed.connect(on_confirm)
	buttons.add_child(ok)


# --- Helpers -----------------------------------------------------------------------

func _add_title(text: String, font_size: int, parent: Control = null) -> Label:
	var l := UITheme.label(text, font_size, UITheme.ACCENT)
	l.add_theme_font_override("font", UITheme.serif_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(parent if parent else _box).add_child(l)
	return l


func _add_text(text: String) -> Label:
	var l := UITheme.label(text, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	_box.add_child(l)
	return l


static func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c
