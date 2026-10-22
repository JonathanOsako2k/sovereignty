class_name UITheme
extends RefCounted
## Touch-sized theme shared by all HUD controls.

const PANEL_BG := Color(0.11, 0.10, 0.09, 0.97)
const PANEL_BORDER := Color(0.62, 0.50, 0.30)
const TEXT := Color(0.93, 0.89, 0.80)
const TEXT_DIM := Color(0.70, 0.65, 0.56)
const ACCENT := Color(0.86, 0.70, 0.38)
const BUTTON := Color(0.20, 0.18, 0.15)
const BUTTON_PRESSED := Color(0.42, 0.33, 0.18)
const PRIMARY := Color(0.52, 0.38, 0.16)
const DANGER := Color(0.85, 0.42, 0.35)
## Minimum touch target in canvas units (base canvas is 720 px on the short side).
const TOUCH_SIZE := Vector2(52, 48)
## Slider grabber diameter: big enough to drag with a thumb.
const GRABBER_SIZE := 34

## Vertical scroll bars' width (px): wide enough to drag on a phone.
const SCROLL_WIDTH := 24.0
static var _grabber: Texture2D
static var _grabber_highlight: Texture2D
static var _tick: Texture2D


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18

	t.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, PANEL_BORDER, 1, 10, 10))
	t.set_color("font_color", "Label", TEXT)

	var normal := _box(BUTTON, PANEL_BORDER.darkened(0.35), 1, 8, 12)
	var pressed := _box(BUTTON_PRESSED, ACCENT, 1, 8, 12)
	for state in ["normal", "hover", "focus"]:
		t.set_stylebox(state, "Button", normal)
	t.set_stylebox("hover", "Button", _box(BUTTON.lightened(0.08), PANEL_BORDER, 1, 8, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", _box(BUTTON.darkened(0.3), BUTTON, 1, 8, 12))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))

	var track := _box(BUTTON.darkened(0.2), PANEL_BORDER.darkened(0.35), 1, 4, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var filled := _box(PRIMARY, ACCENT.darkened(0.2), 1, 4, 0)
	filled.content_margin_top = 5
	filled.content_margin_bottom = 5
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_icon("grabber", "HSlider", _grabber_icon(false))
	t.set_icon("grabber_highlight", "HSlider", _grabber_icon(true))
	t.set_icon("grabber_disabled", "HSlider", _grabber_icon(false))
	t.set_icon("tick", "HSlider", _tick_icon())
	t.set_constant("center_grabber", "HSlider", 1)

	# Scroll bars a thumb can catch: a wide track, a solid grabber.
	var scroll_track := _box(BUTTON.darkened(0.25), PANEL_BORDER.darkened(0.5), 1, 8, 0)
	scroll_track.content_margin_left = SCROLL_WIDTH * 0.5
	scroll_track.content_margin_right = SCROLL_WIDTH * 0.5
	t.set_stylebox("scroll", "VScrollBar", scroll_track)
	t.set_stylebox("scroll_focus", "VScrollBar", scroll_track)
	for state: Array in [["grabber", ACCENT.darkened(0.35)], ["grabber_highlight", ACCENT.darkened(0.15)],
			["grabber_pressed", ACCENT]]:
		var g := _box(state[1], ACCENT.darkened(0.5), 1, 8, 0)
		g.content_margin_left = SCROLL_WIDTH * 0.5
		g.content_margin_right = SCROLL_WIDTH * 0.5
		t.set_stylebox(state[0], "VScrollBar", g)
	return t


## A round grabber for sliders, drawn once.
static func _grabber_icon(highlight: bool) -> Texture2D:
	if highlight and _grabber_highlight:
		return _grabber_highlight
	if not highlight and _grabber:
		return _grabber
	var n := GRABBER_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var fill := ACCENT.lightened(0.15) if highlight else ACCENT
	var rim := PANEL_BG
	var r := n * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var c := fill if d < r - 3.0 else rim
			c.a = clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	if highlight:
		_grabber_highlight = tex
	else:
		_grabber = tex
	return tex


static func _tick_icon() -> Texture2D:
	if _tick == null:
		var img := Image.create(2, 14, false, Image.FORMAT_RGBA8)
		img.fill(TEXT_DIM)
		_tick = ImageTexture.create_from_image(img)
	return _tick


## A stepped slider (levels 0 .. count - 1) sized for touch, with `ticks`
## marks spread along it (default: one per level).
static func level_slider(count: int, value: int, ticks := -1) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = count - 1
	s.step = 1
	s.value = value
	s.tick_count = count if ticks < 0 else ticks
	s.ticks_on_borders = true
	s.scrollable = false  # a scrolling panel must not change policy by accident
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(120, TOUCH_SIZE.y)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s


static func _box(bg: Color, border: Color, border_width: int, radius: int, padding: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(padding)
	sb.content_margin_top = padding * 0.6
	sb.content_margin_bottom = padding * 0.6
	return sb


static func button(text: String, toggle := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.custom_minimum_size = TOUCH_SIZE
	b.focus_mode = Control.FOCUS_NONE
	return b


## The main action of a screen: filled with the accent colour.
static func primary_button(text: String) -> Button:
	var b := button(text)
	var box := _box(PRIMARY, ACCENT, 1, 8, 12)
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, box)
	b.add_theme_stylebox_override("pressed", _box(PRIMARY.lightened(0.15), ACCENT, 1, 8, 12))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


## A value that opens something (a country, a province): accent text, no box,
## still a full-height touch target.
static func link_button(text: String) -> Button:
	var b := Button.new()
	b.text = text + "  ›"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.custom_minimum_size.y = 40
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_size_override("font_size", 17)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, ACCENT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 4
	pad.content_margin_right = 0
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, pad)
	return b


## Serif lettering for titles, matching the map's names.
static func serif_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Noto Serif", "serif"])
	return font


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
