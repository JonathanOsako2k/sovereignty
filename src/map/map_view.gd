class_name MapView
extends Node2D
## The 2D base map. Draws the province-ID raster through map.gdshader and answers
## "which province is at this point?". Reads WorldState; never modifies it.
## Map space: one unit per ID-texture pixel, origin at the top-left corner.
##
## The world wraps east-west: the map is drawn three times side by side
## (x - width, x, x + width) and the camera keeps its x within [0, width), so
## whatever the camera sees is always covered.

signal province_selected(province_id: int)
signal country_selected(tag: String)
## The palette was rewritten (mode change, ownership, a month's economy):
## anything showing the mode's values should refresh.
signal palette_refreshed

const MapShader := preload("res://src/map/map.gdshader")

var world: WorldState
var mode: MapModes.Mode = MapModes.Mode.POLITICAL
var selected_id := 0
var selected_country := ""
## Provides province taxes for the Economy map mode.
var economy: EconomySystem
var colonisation: ColonisationSystem
## Colonisation map: province id -> months to settle for the perspective
## country (-1 out of reach, -2 closed), from the last palette refresh.
var _outlook := {}
## Province id -> colour drawn over the mode's (the peace table's land).
var highlights := {}

var _material: ShaderMaterial
var _id_image: Image
var _palette_image: Image
var _palette_texture: ImageTexture
var _stripe_image: Image
var _stripe_texture: ImageTexture
var _rivers: MapRivers
var _lod := MapLod.new()
## Provinces of at most TINY_AREA pixels in the world data (islands; the map
## draws them a little bigger): a tap in the sea near one picks it.
const TINY_AREA := 8
const TINY_TAP_PX := 20.0
var _tiny: Array[Province] = []


func setup(p_world: WorldState) -> void:
	world = p_world
	_id_image = _load_image(world.id_texture_path)
	var id_texture := ImageTexture.create_from_image(_id_image)
	var height_texture := ImageTexture.create_from_image(_load_image(world.height_texture_path))

	_palette_image = Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	_palette_texture = ImageTexture.create_from_image(_palette_image)
	_stripe_image = Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	_stripe_texture = ImageTexture.create_from_image(_stripe_image)

	_material = ShaderMaterial.new()
	_material.shader = MapShader
	_material.set_shader_parameter("id_map", id_texture)
	_material.set_shader_parameter("height_map", height_texture)
	_material.set_shader_parameter("palette", _palette_texture)
	_material.set_shader_parameter("stripes", _stripe_texture)
	_material.set_shader_parameter("map_size", Vector2(world.map_size))

	for copy in [-1, 0, 1]:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = id_texture
		sprite.material = _material
		sprite.position.x = copy * world.map_size.x
		add_child(sprite)

	_rivers = MapRivers.new()
	add_child(_rivers)
	for p: Province in world.ownable_provinces():
		if p.area <= TINY_AREA:
			_tiny.append(p)
	_rivers.setup(Vector2(world.map_size))

	# A month can move many provinces: repaint once, at the end of the frame.
	world.province_owner_changed.connect(func(_id, _a, _b): _refresh_later())
	world.province_controller_changed.connect(func(_id, _a, _b): _refresh_later())
	world.campaign_restored.connect(refresh_colors)
	world.player_changed.connect(func(_t): _refresh_later())
	world.diplomacy.changed.connect(func(_a, _b): _refresh_later(MapModes.Mode.DIPLOMACY))
	world.diplomacy.opinions_updated.connect(func(): _refresh_later(MapModes.Mode.DIPLOMACY))
	world.diplomacy.subjects_changed.connect(func(): _refresh_later())
	world.diplomacy.reset.connect(func(): _refresh_later())
	refresh_colors()


## Map images are stored as Image resources (exact, uncompressed province IDs);
## imported textures are accepted too.
static func _load_image(path: String) -> Image:
	var res: Resource = load(path)
	var image: Image = res if res is Image else (res as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	return image


## Called when the camera moves or zooms: updates view-dependent 2D layers.
func update_view(camera: MapCamera) -> void:
	var zoom := camera.zoom.x
	_lod.update(zoom)
	_rivers.update_view(camera.position, camera.view_size() / zoom, zoom, _lod.level)


func set_mode(new_mode: MapModes.Mode) -> void:
	mode = new_mode
	refresh_colors()


## Colours some provinces over the map mode ({} clears them).
func set_highlights(colours: Dictionary) -> void:
	if colours.is_empty() and highlights.is_empty():
		return
	highlights = colours
	_refresh_later()


func select(province_id: int) -> void:
	if world.get_province(province_id) == null:
		province_id = 0
	selected_id = province_id
	_material.set_shader_parameter("selected_id", selected_id)
	province_selected.emit(selected_id)


## Highlights and outlines a country's territory ("" clears it).
func select_country(tag: String) -> void:
	if world.get_country(tag) == null:
		tag = ""
	selected_country = tag
	_material.set_shader_parameter("selected_country", world.country_marker(tag) if tag != "" else 0)
	country_selected.emit(tag)
	_refresh_later(MapModes.Mode.DIPLOMACY)  # the diplomacy map follows the selection
	_refresh_later(MapModes.Mode.COLONISATION)


var _refresh_pending := false


## One palette rewrite at the end of the frame, however many changes arrive
## (only when the current mode shows them, if `only_mode` is given).
## What the map writes on a province in the current mode (see MapModes.info_text).
func info_text(p: Province) -> String:
	if mode != MapModes.Mode.COLONISATION:
		return MapModes.info_text(p, mode, economy)
	if p.is_sea or p.is_wasteland or p.owner_id != "":
		return ""
	if p.colonist != "":
		return "%d %%" % int(p.colony_progress)
	var months: int = _outlook.get(p.id, -1)
	if months == -2:
		return "Closed"
	if months < 0:
		return ""
	return "%d months" % months if months < 24 else "%d years" % roundi(months / 12.0)


## Colonies founded or abandoned: the political and colonisation maps
## redraw if shown.
func colonies_changed() -> void:
	_refresh_later(MapModes.Mode.POLITICAL)
	_refresh_later(MapModes.Mode.COLONISATION)


## A month of colonial progress: only the colonisation map shows it.
func colony_progress_changed() -> void:
	_refresh_later(MapModes.Mode.COLONISATION)


## Output, goods or buildings changed (a month passed, a discovery): the
## economy and goods maps redraw if shown.
func economy_changed() -> void:
	_refresh_later(MapModes.Mode.ECONOMY)
	_refresh_later(MapModes.Mode.GOODS)
	_refresh_later(MapModes.Mode.BUILDINGS)


## A province converted: the religion map redraws if shown.
func religion_changed() -> void:
	_refresh_later(MapModes.Mode.RELIGION)


func _refresh_later(only_mode := -1) -> void:
	if (only_mode >= 0 and mode != only_mode) or _refresh_pending:
		return
	_refresh_pending = true
	(func():
		_refresh_pending = false
		refresh_colors()).call_deferred()


## Rewrites the palette for the current mode: one small texture upload, no
## geometry work, so map modes and ownership changes are cheap.
func refresh_colors() -> void:
	var scale := MapModes.population_density_scale(world)
	var perspective := selected_country if selected_country != "" else world.player_country_id
	var cache := {}
	_outlook.clear()
	if mode == MapModes.Mode.COLONISATION and colonisation != null and perspective != "":
		for p: Province in world.ownable_provinces():
			if p.owner_id == "" and p.colonist == "":
				_outlook[p.id] = colonisation.outlook(perspective, p)
				cache["outlook:%d" % p.id] = _outlook[p.id]
	if mode == MapModes.Mode.ECONOMY and economy != null:
		var values := PackedFloat32Array()
		for p: Province in world.ownable_provinces():
			var value: float = economy.production(p).value
			cache["value:%d" % p.id] = value
			values.append(value)
		values.sort()
		cache["value_scale"] = values[int((values.size() - 1) * 0.98)] if not values.is_empty() else 1.0
	for p: Province in world.provinces.values():
		var c := MapModes.province_color(world, p, mode, scale, perspective, cache)
		if highlights.has(p.id):
			c = highlights[p.id]
		if p.is_wasteland:
			c.a8 = MapModes.WASTE_MARKER
		elif p.is_sea:
			c.a8 = MapModes.SEA_MARKER
		else:
			c.a8 = world.country_marker(MapModes.border_country(p, mode))
		_palette_image.set_pixel(p.id % 256, p.id / 256, c)
		_stripe_image.set_pixel(p.id % 256, p.id / 256, MapModes.stripe_color(world, p, mode, perspective))
	_palette_texture.update(_palette_image)
	_stripe_texture.update(_stripe_image)
	palette_refreshed.emit()


## What a tap picks: the province under it, unless that is sea (or nothing)
## and a tiny province lies within a finger's reach — then that one.
func pick(map_pos: Vector2, zoom: float) -> int:
	var id := province_at(map_pos)
	var p := world.get_province(id)
	if p != null and not p.is_sea and not p.is_wasteland:
		return id
	var reach := TINY_TAP_PX / maxf(zoom, 0.01)
	var best := id
	var best_d := reach
	var w := float(world.map_size.x)
	for t: Province in _tiny:
		var dx := absf(t.label_position.x - map_pos.x)
		dx = minf(dx, w - dx)
		var d := Vector2(dx, t.label_position.y - map_pos.y).length()
		if d < best_d:
			best_d = d
			best = t.id
	return best


## Province id under a map-space point (x wraps); 0 for sea or off the map.
func province_at(map_pos: Vector2) -> int:
	var w := _id_image.get_width()
	var y := int(floor(map_pos.y))
	if y < 0 or y >= _id_image.get_height():
		return 0
	return decode_id(_id_image.get_pixel(posmod(int(floor(map_pos.x)), w), y))


static func decode_id(c: Color) -> int:
	return c.r8 + (c.g8 << 8)


static func encode_id(id: int) -> Color:
	return Color8(id & 0xFF, (id >> 8) & 0xFF, 0)
