class_name LoadingScreen
extends CanvasLayer
## The screen shown while the game loads — at start (the world, the map, its
## lettering), when a new campaign begins and when a save is loaded: the title
## menu's painting, the game's name, what is being done and how far along.
## The work runs on the main thread between frames: the Game shows a step,
## lets a frame draw (see Game._loading_step), then does it; finish() lets the
## first frames of the game draw behind the screen, then fades it away.

const BAR_WIDTH := 520.0
const BAR_HEIGHT := 10.0
const FADE_SECONDS := 0.3

var _root: Control
var _title: Label
var _subtitle: Label
var _stage: Label
var _track: ColorRect
var _fill: ColorRect
var _generation := 0  # a newer begin() outlives an older finish()


func _init() -> void:
	layer = 100
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # no taps reach the game while it loads
	add_child(_root)
	var back := ColorRect.new()
	back.color = Color(0.07, 0.06, 0.05)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	var painting := TextureRect.new()
	painting.set_anchors_preset(Control.PRESET_FULL_RECT)
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path: String in MenuScreen.BACKGROUND_PATHS:
		if ResourceLoader.exists(path):
			painting.texture = load(path)
			break
	_root.add_child(painting)
	var gradient := Gradient.new()  # darker towards the bottom, where the words are
	gradient.set_color(0, Color(0.03, 0.025, 0.02, 0.0))
	gradient.set_color(1, Color(0.03, 0.025, 0.02, 0.8))
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0, 0)
	fade.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = fade
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_top = 0.4
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	_title = _centred_label("Sovereignty", 64, UITheme.ACCENT)
	_title.add_theme_font_override("font", UITheme.serif_font())
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("outline_size", 8)
	_subtitle = _centred_label("1590 – 1949", 22, UITheme.TEXT)
	_subtitle.add_theme_font_override("font", UITheme.serif_font())
	_stage = _centred_label("", 20, UITheme.TEXT)
	_track = ColorRect.new()
	_track.color = Color(1, 1, 1, 0.15)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_track)
	_fill = ColorRect.new()
	_fill.color = UITheme.ACCENT
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_fill)
	_root.resized.connect(_layout)


func _centred_label(text: String, size: int, color: Color) -> Label:
	var l := UITheme.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


## Places the words and the bar in the lower part of the screen (anchored, no
## containers: they must be in place for a frame drawn at once).
func _layout() -> void:
	var s := _root.get_viewport_rect().size if _root.is_inside_tree() else _root.size
	var bottom := s.y - maxf(48.0, s.y * 0.1)
	var bar_w := minf(BAR_WIDTH, s.x - 64.0)
	_track.position = Vector2((s.x - bar_w) * 0.5, bottom - BAR_HEIGHT)
	_track.size = Vector2(bar_w, BAR_HEIGHT)
	_fill.size.y = BAR_HEIGHT
	_stage.position = Vector2(0, _track.position.y - 40.0)
	_stage.size = Vector2(s.x, 30)
	_subtitle.position = Vector2(0, _stage.position.y - 56.0)
	_subtitle.size = Vector2(s.x, 30)
	_title.position = Vector2(0, _subtitle.position.y - 86.0)
	_title.size = Vector2(s.x, 80)


## Shows the screen (at no progress yet).
func begin(stage := "") -> void:
	_generation += 1
	visible = true
	_root.modulate.a = 1.0
	step(stage, 0.0)


## What is being done now and how far along (0-1), from the next frame.
func step(stage: String, fraction: float) -> void:
	if not visible:
		return
	_layout()
	_stage.text = stage + ("…" if stage != "" else "")
	_fill.size.x = _track.size.x * clampf(fraction, 0.0, 1.0)


## Done: the game's first frames draw behind the screen, then it fades away.
func finish() -> void:
	if not visible:
		return
	var generation := _generation
	step(_stage.text.trim_suffix("…"), 1.0)
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		visible = false  # nothing to see (tests and tools)
		return
	for i in 2:
		await get_tree().process_frame
	if generation != _generation:
		return  # loading again
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, FADE_SECONDS)
	await fade.finished
	if generation == _generation:
		visible = false
