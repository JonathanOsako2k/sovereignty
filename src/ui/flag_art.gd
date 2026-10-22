class_name FlagArt
extends Control
## A country's flag: its historical flag from assets/flags/<TAG>.png when
## there is one (see assets/flags/CREDITS.md), else one drawn from its own
## colour — a design picked from its tag, so each country keeps its own. A
## colony without a flag of its own flies its mother country's.

const DIR := "res://assets/flags/"
## Second colours for the drawn flags: white, gold, black, crimson, azure.
const TINCTURES := [Color(0.96, 0.95, 0.9), Color(0.93, 0.76, 0.2), Color(0.1, 0.1, 0.12),
	Color(0.72, 0.1, 0.12), Color(0.12, 0.3, 0.68)]

var tag := ""
var color := Color.GRAY
var _texture: Texture2D

static var _cache := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(54, 36)


## The flag's image for a country, if the game has one.
static func texture_for(p_tag: String) -> Texture2D:
	if not _cache.has(p_tag):
		var path := DIR + p_tag + ".png"
		_cache[p_tag] = load(path) if ResourceLoader.exists(path) else null
	return _cache[p_tag]


func show_flag(world: WorldState, p_tag: String) -> void:
	tag = p_tag
	var c := world.get_country(p_tag) if world else null
	color = c.color if c else Color.GRAY
	_texture = texture_for(p_tag)
	if _texture == null and world and world.diplomacy.subject_type(p_tag) == "colony":
		_texture = texture_for(world.diplomacy.overlord_of(p_tag))
	queue_redraw()


## Where the flag is drawn: a historical flag keeps its own proportions
## (banners are squarer than 3:2), centred in the space.
func flag_rect() -> Rect2:
	var r := Rect2(Vector2.ZERO, size)
	if _texture == null or _texture.get_height() == 0:
		return r
	var aspect := float(_texture.get_width()) / _texture.get_height()
	var w := minf(size.x, size.y * aspect)
	var h := w / aspect
	return Rect2((size - Vector2(w, h)) / 2.0, Vector2(w, h))


func _draw() -> void:
	var r := flag_rect()
	if _texture != null:
		draw_texture_rect(_texture, r, false)
	else:
		_draw_design(r)


## A design from the tag: bands, a cross, a saltire or a canton, in the
## country's colour and a second tincture that stands out against it.
func _draw_design(r: Rect2) -> void:
	var h := absi(hash(tag))
	var second: Color = TINCTURES[h % TINCTURES.size()]
	if absf(second.get_luminance() - color.get_luminance()) < 0.2:
		second = TINCTURES[(h + 2) % TINCTURES.size()]
	var w := r.size.x
	var ht := r.size.y
	draw_rect(r, color)
	match (h / TINCTURES.size()) % 7:
		0:  # two bands
			draw_rect(Rect2(0, ht * 0.5, w, ht * 0.5), second)
		1:  # two pales
			draw_rect(Rect2(w * 0.5, 0, w * 0.5, ht), second)
		2:  # three bands
			draw_rect(Rect2(0, ht / 3.0, w, ht / 3.0), second)
		3:  # three pales
			draw_rect(Rect2(w / 3.0, 0, w / 3.0, ht), second)
		4:  # a Nordic cross
			draw_rect(Rect2(w * 0.3, 0, w * 0.12, ht), second)
			draw_rect(Rect2(0, ht * 0.42, w, ht * 0.16), second)
		5:  # a saltire
			var t := ht * 0.14
			draw_line(Vector2.ZERO, Vector2(w, ht), second, t)
			draw_line(Vector2(0, ht), Vector2(w, 0), second, t)
		6:  # a canton
			draw_rect(Rect2(0, 0, w * 0.42, ht * 0.5), second)
