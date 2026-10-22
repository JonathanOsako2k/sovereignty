class_name DrawerPanel
extends PanelContainer
## The context drawer's frame (structure.md §3.1): a header with colour swatch,
## title, subtitle and close button; a scrolling two-column list of facts; and
## a footer for actions. Province and country panels fill it in.

signal close_requested

## Drawn wider in landscape (panels with sliders and long lines: the budget).
var wide := false
## A slider is being dragged: refreshes wait (they would rebuild it under the
## thumb) until it is let go.
var _dragging := false
var _refresh_held := false

var _swatch: ColorRect
var _title: Label
var _subtitle: Label
var _rows: GridContainer
## Below the facts, inside the scrolling area: extra sections (diplomacy).
var _extra: VBoxContainer
var _footer: VBoxContainer
var _gutter: MarginContainer
var _header: HBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	_header = header
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(14, 40)
	header.add_child(_swatch)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	_title = UITheme.label("", 24, UITheme.ACCENT)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(_title)
	_subtitle = UITheme.label("", 15, UITheme.TEXT_DIM)
	_subtitle.clip_text = true
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(_subtitle)
	var close := UITheme.button("✕")
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_gutter = MarginContainer.new()
	_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_gutter)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_gutter.add_child(content)
	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("h_separation", 16)
	_rows.add_theme_constant_override("v_separation", 6)
	content.add_child(_rows)
	_extra = VBoxContainer.new()
	_extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_extra.add_theme_constant_override("separation", 6)
	content.add_child(_extra)

	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	box.add_child(_footer)
	set_scroll_gutter(DEFAULT_GUTTER)


## Every list keeps this much room beside its (wide) scroll bar.
const DEFAULT_GUTTER := 14

## Empty room right of the scrolling list (px): a thumb can scroll a long list
## of toggles there without pressing one.
func set_scroll_gutter(px: int) -> void:
	_gutter.add_theme_constant_override("margin_right", px)


## Redraws from the current world state (each panel fills this in).
func refresh() -> void:
	pass


func _set_header(title: String, subtitle: String, color: Color) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_swatch.color = color


## Rows of [label, value]; a value is text or a ready-made Control (e.g. a link).
func _set_rows(rows: Array) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row in rows:
		var name_label := UITheme.label(row[0], 16, UITheme.TEXT_DIM)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_rows.add_child(name_label)
		var value: Control = row[1] if row[1] is Control else UITheme.label(str(row[1]), 17)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if value is Label:
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_rows.add_child(value)


func _clear_extra() -> void:
	for child in _extra.get_children():
		_extra.remove_child(child)
		child.queue_free()


## A slider row: name and level, then − [slider] + (drag, or tap a step at a
## time), and a line about its effects. `on_step(step)` is called with the
## change in levels (±1 for a button, more for a drag).
func _slider_row(title: String, levels: Array, level: int, about: String, on_step: Callable, ticks := -1) -> void:
	var head := HBoxContainer.new()
	var name_label := UITheme.label(title, 17)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var value := UITheme.label(levels[level], 17, UITheme.ACCENT)
	head.add_child(value)
	_extra.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var minus := UITheme.button("−")
	minus.add_theme_font_size_override("font_size", 22)
	minus.disabled = level <= 0
	minus.pressed.connect(func(): on_step.call(-1))
	row.add_child(minus)
	var slider := UITheme.level_slider(levels.size(), level, ticks)
	slider.value_changed.connect(func(v: float):
		value.text = levels[int(v)]
		if not _dragging and int(v) != level:  # keyboard or gamepad
			on_step.call(int(v) - level))
	slider.drag_started.connect(func(): _dragging = true)
	slider.drag_ended.connect(func(_changed: bool):
		_dragging = false
		if int(slider.value) != level:
			on_step.call(int(slider.value) - level)
		elif _refresh_held:
			_refresh_held = false
			refresh.call_deferred())
	row.add_child(slider)
	var plus := UITheme.button("+")
	plus.add_theme_font_size_override("font_size", 22)
	plus.disabled = level >= levels.size() - 1
	plus.pressed.connect(func(): on_step.call(1))
	row.add_child(plus)
	_extra.add_child(row)
	var note := UITheme.label(about, 13, UITheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 120
	_extra.add_child(note)


## A spending policy as a percent slider (Policies.RANGES): `on_step` gets the
## change in slider steps.
func _spending_slider(policy: String, value: int, about: String, on_step: Callable) -> void:
	var r: Array = Policies.RANGES[policy]
	var names := []
	for v in range(r[0], r[1] + 1, r[2]):
		names.append("%d %%" % v)
	_slider_row(Policies.NAMES[policy], names, (value - r[0]) / r[2], about, on_step,
		(r[1] - r[0]) / maxi(r[2] * (5 if r[2] == 1 else 2), 1) + 1)


func _section_title(text: String) -> Label:
	var l := UITheme.label(text, 17, UITheme.ACCENT)
	l.add_theme_font_override("font", UITheme.serif_font())
	_extra.add_child(l)
	return l


static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
