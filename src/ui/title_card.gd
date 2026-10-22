class_name TitleCard
extends CanvasLayer
## Shown when a campaign starts or a save is loaded: the country's flag, its
## name and the year in the middle of the screen over a soft white glow,
## fading in and away by itself. Taps go through to the game.

const FADE_IN := 0.5
const HOLD := 2.2
const FADE_OUT := 1.0

var _root: Control
var _glow: TextureRect
var _flag: FlagArt
var _name: Label
var _year: Label
var _tween: Tween


func _init() -> void:
	layer = 90
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.92))
	gradient.add_point(0.55, Color(1, 1, 1, 0.55))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0.0)
	glow.width = 256
	glow.height = 256
	_glow = TextureRect.new()
	_glow.texture = glow
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_glow)
	_flag = FlagArt.new()
	_root.add_child(_flag)
	_name = _label(44)
	_year = _label(30)
	_root.resized.connect(_layout)


func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UITheme.serif_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.12, 0.09, 0.06))
	_root.add_child(l)
	return l


func _layout() -> void:
	var s := _root.get_viewport_rect().size if _root.is_inside_tree() else _root.size
	var c := s * 0.5
	var glow := Vector2(minf(s.x * 0.9, 900.0), minf(s.y * 0.85, 520.0))
	_glow.position = c - glow * 0.5
	_glow.size = glow
	_flag.size = Vector2(150, 100)
	_flag.position = c + Vector2(-75, -150)
	_name.position = Vector2(0, c.y - 30)
	_name.size = Vector2(s.x, 60)
	_year.position = Vector2(0, c.y + 34)
	_year.size = Vector2(s.x, 44)


## Shows the country and the year, then fades away.
func show_card(world: WorldState, tag: String, year: int) -> void:
	var c := world.get_country(tag)
	if c == null or DisplayServer.get_name() == "headless":
		return
	_flag.show_flag(world, tag)
	_name.text = c.name
	_year.text = str(year)
	_layout()
	visible = true
	_root.modulate.a = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func(): visible = false)
