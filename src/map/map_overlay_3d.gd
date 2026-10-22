class_name MapOverlay3D
extends SubViewportContainer
## The transparent 3D layer drawn over the 2D map.
##
## A SubViewport with a transparent background renders its own 3D world through an
## orthographic camera that looks straight down. The camera is driven by the
## MapCamera, so map pixel (x, y) always projects onto 3D point
## (x * UNITS_PER_PIXEL, 0, y * UNITS_PER_PIXEL). Screen-up is -Z, screen-right +X.
##
## A camera looking straight down would show only the footprint of each object, so
## props hang under a root with an oblique shear: height (+Y) is also pushed
## toward screen-up (-Z). An object's base stays exactly on its map pixel while
## its height becomes visible, like a figure standing on a paper map.
##
## Detail follows the view: forests and peaks are bucketed into map tiles, and
## only tiles covering the screen plus a margin are instanced (each tile's batch
## is built the first time it comes into range, then cached). The world wraps
## east-west: tiles, markers and labels are placed at whichever copy of their
## position is nearest the camera.
##
## Contents are decoration and markers only: capitals, labels, forest and
## mountain props with blob shadows, and the selection pin. Picking stays in the
## 2D MapView.

const UNITS_PER_PIXEL := 0.01
const CAMERA_HEIGHT := 10.0
## Screen-up offset per unit of height (1.0 ≈ viewed from 45°).
const OBLIQUE_SHEAR := 0.85
## Light direction in 3D; matches the hillshade light in map.gdshader (from the
## top-left of the screen) so 3D shading and terrain relief agree.
const LIGHT_DIRECTION := Vector3(0.6, -0.8, 0.7)
## Zoom thresholds.
## Polities with at least this many provinces show their capital at any zoom.
const MAJOR_POLITY_PROVINCES := 25
## A country label shows once its territory spans this many screen pixels, and
## hides again only below the smaller value (hysteresis).
const COUNTRY_LABEL_SHOW_SCREEN := 70.0
const COUNTRY_LABEL_HIDE_SCREEN := 55.0
## A block of territory this much longer than wide gets its name along its
## length (unless that would be steeper than LABEL_MAX_TILT_DEG).
const LABEL_ROTATE_ELONGATION := 1.6
const LABEL_MAX_TILT_DEG := 62.0
## Tilts smaller than this are levelled: a slightly crooked name looks like a mistake.
const LABEL_MIN_TILT_DEG := 8.0
## Grid cell (map px) for finding names that overlap.
const LABEL_OVERLAP_CELL := 256.0
## Province names: on-screen text height, and padding between labels.
const PROVINCE_LABEL_PX := 14.0
const LABEL_PADDING_PX := 4.0
const PROVINCE_LABEL_COLOR := Color(0.12, 0.10, 0.08)
const SEA_LABEL_COLOR := Color(0.16, 0.30, 0.42)
const SEA_LABEL_OUTLINE := Color(0.80, 0.88, 0.92, 0.6)
## Roughly the open-water colour under big sea names (between the shader's
## sea_shallow and sea_deep).
const SEA_BACKDROP := Color(0.17, 0.29, 0.39)
const PROVINCE_LABEL_OUTLINE := Color(1, 0.97, 0.9, 0.85)
const PROVINCE_LABEL_POOL := 220
## Map-mode values under province names (info modes): ink colour and sizes.
const INFO_LABEL_COLOR := Color(0.36, 0.10, 0.04)
const INFO_LABEL_PX := 15.0
const INFO_NAME_PX := 12.0
## Region names (REGION_LABEL_MODES): screen font sizes they snap to (a few
## sizes keep the glyph cache small), the smallest worth drawing, and how much
## of the region's length the name may take.
const REGION_LABEL_SIZES := [12, 14, 16, 19, 22, 26, 31, 37, 44, 52, 62]
const REGION_LABEL_WIDTH := 0.9
const REGION_LABEL_POOL := 160
const LABEL_GRID := 128
const TREES_PER_AREA := 1.0 / 500.0
## Share of the full tree count each vegetation gets.
const TREE_SHARE := {"forest": 1.0, "jungle": 1.0, "woods": 0.5}
const PEAKS_PER_AREA := 1.0 / 1600.0
const MAX_PROPS_PER_PROVINCE := 40
const MAX_PROPS_PER_WASTELAND := 400
## Scenery tile size in map pixels, and the extra area kept around the screen.
const PROP_TILE := 512
const PROP_MARGIN := 0.5
## Scenery tiles instanced per frame, nearest the view centre first.
const NEW_PROP_TILES_PER_FRAME := 3

var world: WorldState
var map_view: MapView
var map_camera: MapCamera

var _viewport: SubViewport
var _props: Node3D
var _camera: Camera3D
var _map_width := 0.0
var _capitals: Dictionary = {}  # tag -> {node, pos, major}
## Country, wasteland and sea names: {tag ("" for wastes and seas), label,
## pos, span, half (extent/2 in map px), angle (radians, map space), blockers
## (higher-priority names it overlaps)}. Kept in priority order.
var _country_labels: Array[Dictionary] = []
var _province_label_grid: Dictionary = {}  # cell -> PackedInt32Array of province ids
## Province names are drawn in 2D, in screen space, on a canvas above the 3D
## layer: one redraw per view change instead of a 3D text mesh per name.
var _name_canvas: Node2D
var _shown_names: Dictionary = {}  # province id -> true, for stable placement
var _placed_names: Array = []  # [screen top-left, [[text, size, colour, outline], ...]]
## The map mode writes values on provinces (MapModes.INFO_MODES).
var _info_mode := false
var _info_cache: Dictionary = {}  # province id -> text, until the palette changes
var _labels_dirty := {}  # country tag -> true: its names need rebuilding
var _labels_pending := false
## Category modes: connected provinces sharing a value, each named once:
## {key, text, pos, span, angle, max_letter}. Rebuilt when the palette changes.
var _region_mode := false
var _regions: Array[Dictionary] = []
var _shown_regions: Dictionary = {}  # region key -> true, for stable placement
var _placed_regions: Array = []  # [screen centre, angle, text, font size, width]
## Screen-space names are drawn at their final pixel size, so a plain
## (oversampled) font is sharp and batches into far fewer draw calls than MSDF.
var _name_font: Font
var _selection_pin: Node3D
var _selection_pos := Vector2.ZERO
## Wrapped tile key -> {shadows, trees, tree_colors, peaks, peak_colors} (transforms).
var _prop_buckets: Dictionary = {}
## Wrapped tile key -> [MultiMesh, MultiMesh, MultiMesh], built on first use.
var _prop_meshes: Dictionary = {}
## Unwrapped tile (Vector2i) -> Node3D holding that tile's batches.
var _prop_tiles: Dictionary = {}
var _prop_cols := 1
var _scenery_pending := false
var _tree_mesh: CylinderMesh
var _peak_mesh: CylinderMesh
var _marker_scale := 1.0
var _blob_shadow_mesh: PlaneMesh
var _lod := MapLod.new()
var _font: Font


func _init() -> void:
	# The SubViewport is sized to physical screen pixels (see _fit_to_screen),
	# not stretched from canvas units, so 3D text and edges stay sharp on
	# high-density phone screens.
	stretch = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_world: WorldState, p_map_view: MapView, p_camera: MapCamera) -> void:
	world = p_world
	map_view = p_map_view
	map_camera = p_camera
	_map_width = world.map_size.x

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.gui_disable_input = true
	add_child(_viewport)
	_font = _load_map_font()
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.4

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.rotation_degrees = Vector3(-90, 0, 0)
	_camera.near = 0.5
	_camera.far = CAMERA_HEIGHT + 5.0
	_camera.environment = env
	_viewport.add_child(_camera)

	var light := DirectionalLight3D.new()
	light.basis = Basis.looking_at(LIGHT_DIRECTION.normalized(), Vector3.UP)
	light.light_energy = 0.85
	_viewport.add_child(light)

	_props = Node3D.new()
	_props.basis = Basis(Vector3.RIGHT, Vector3(0, 1, -OBLIQUE_SHEAR), Vector3.BACK)
	_viewport.add_child(_props)

	_prewarm_glyphs()  # before any name is laid out (see there)
	_build_terrain_props()
	_build_capitals()
	_build_province_label_pool()
	_rebuild_all_country_labels()
	_build_wasteland_labels()
	_build_sea_labels()
	_update_label_blockers()
	_build_selection_pin()

	map_camera.view_changed.connect(_sync_camera)
	map_view.province_selected.connect(_on_province_selected)
	map_view.palette_refreshed.connect(_on_palette_refreshed)
	world.province_owner_changed.connect(_on_owner_changed)
	world.campaign_restored.connect(_on_campaign_restored)
	world.countries_changed.connect(_on_countries_changed)
	_sync_camera()


## Renders the 3D layer at the window's physical resolution and scales the
## container back down to canvas units.
func _fit_to_screen() -> void:
	var canvas := get_viewport().get_visible_rect().size
	var k := maxf(float(DisplayServer.window_get_size().y) / maxf(canvas.y, 1.0), 1.0)
	_viewport.size = Vector2i((canvas * k).round())
	position = Vector2.ZERO
	size = canvas * k
	scale = Vector2.ONE / k


## Serif map lettering rendered as a multi-channel signed distance field, so it
## stays crisp at any label scale.
const MAP_FONT_NAMES := ["Georgia", "Palatino Linotype", "Book Antiqua", "Noto Serif", "serif"]
const MSDF_PIXEL_RANGE := 32  # outlines up to half this width render cleanly
const MSDF_SIZE := 64
## The map font with its distance-field glyphs, kept on the device: making the
## glyphs takes seconds on a phone, loading them milliseconds. Remade when the
## system font, the engine or these settings change (GLYPH_CACHE_KEY).
const GLYPH_CACHE := "user://cache/map_font.res"
const GLYPH_CACHE_KEY := "user://cache/map_font.key"
var _glyph_cache_key := ""


## The system serif as a font file (its glyphs can then be saved), from the
## glyph cache when it is still good; a SystemFont if the file cannot be read.
func _load_map_font() -> Font:
	var path := ""
	for n: String in MAP_FONT_NAMES:
		path = OS.get_system_font_path(n)
		if path != "" and not path.to_lower().ends_with(".ttc"):  # a collection: no face index to give
			break
		path = ""
	if path == "":
		return _system_map_font()
	_glyph_cache_key = "%s|%d|%d|%s|%d|%d" % [path, FileAccess.get_size(path), FileAccess.get_modified_time(path),
		Engine.get_version_info().string, MSDF_SIZE, MSDF_PIXEL_RANGE]
	if FileAccess.file_exists(GLYPH_CACHE) and FileAccess.file_exists(GLYPH_CACHE_KEY) \
			and FileAccess.get_file_as_string(GLYPH_CACHE_KEY) == _glyph_cache_key:
		var cached := ResourceLoader.load(GLYPH_CACHE, "FontFile", ResourceLoader.CACHE_MODE_IGNORE) as FontFile
		if cached != null and cached.multichannel_signed_distance_field:
			return cached
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return _system_map_font()
	var font := FontFile.new()
	font.data = bytes
	font.multichannel_signed_distance_field = true
	font.msdf_pixel_range = MSDF_PIXEL_RANGE
	font.msdf_size = MSDF_SIZE
	return font


static func _system_map_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(MAP_FONT_NAMES)
	font.multichannel_signed_distance_field = true
	font.msdf_pixel_range = MSDF_PIXEL_RANGE
	font.msdf_size = MSDF_SIZE
	return font


## Keeps the glyphs made so far for the next start.
func _save_glyph_cache() -> void:
	if not _font is FontFile or _glyph_cache_key == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GLYPH_CACHE.get_base_dir()))
	if ResourceSaver.save(_font, GLYPH_CACHE, ResourceSaver.FLAG_COMPRESS) == OK:
		var f := FileAccess.open(GLYPH_CACHE_KEY, FileAccess.WRITE)
		if f != null:
			f.store_string(_glyph_cache_key)


static func to_3d(map_pos: Vector2, height := 0.0) -> Vector3:
	return Vector3(map_pos.x * UNITS_PER_PIXEL, height, map_pos.y * UNITS_PER_PIXEL)


## For other map layers (armies, forts): the 3D props root, the nearest copy of
## a position, the level of detail and the marker scale.
func props() -> Node3D:
	return _props


func near(pos: Vector2) -> Vector2:
	return _near(pos)


func lod_level() -> int:
	return _lod.level


func marker_scale() -> float:
	return _marker_scale


func map_font() -> Font:
	return _name_font


## The copy of a map position (x shifted by whole map widths) nearest the camera.
func _near(pos: Vector2) -> Vector2:
	return Vector2(pos.x + _map_width * round((map_camera.position.x - pos.x) / _map_width), pos.y)


## Matches the 3D orthographic view to the 2D camera exactly and refreshes
## everything that depends on position or zoom.
func _sync_camera() -> void:
	var z := map_camera.zoom.x
	_camera.position = to_3d(map_camera.position, CAMERA_HEIGHT)
	_camera.size = map_camera.view_size().y / z * UNITS_PER_PIXEL
	_lod.update(z)
	var level := _lod.level

	# Markers grow a little when zoomed out so they stay readable.
	var s := clampf(0.9 / sqrt(z), 0.4, 1.6)
	var rescale := not is_equal_approx(s, _marker_scale)
	_marker_scale = s
	var show_minor := level >= MapLod.Level.REGION
	for tag: String in _capitals:
		var cap: Dictionary = _capitals[tag]
		var node: Node3D = cap.node
		node.visible = cap.major or show_minor
		var x := _near(cap.pos).x
		if x != cap.get("x", INF):
			cap.x = x
			node.position = to_3d(Vector2(x, cap.pos.y))
		if rescale:
			node.scale = Vector3.ONE * s
	_selection_pin.scale = Vector3.ONE * s
	_selection_pin.position = to_3d(_near(_selection_pos))

	# Country (and wasteland) names belong to the world and region levels.
	var country_level := level <= (MapLod.Level.WORLD if _info_mode else MapLod.Level.REGION)
	for entry in _country_labels:  # priority order: blockers are decided first
		var label: Label3D = entry.label
		# In category modes the regions' names take the countries' place.
		var show: bool = country_level and not (_region_mode and entry.tag != "") \
			and MapLod.keep_shown(label.visible, entry.span * z, COUNTRY_LABEL_SHOW_SCREEN, COUNTRY_LABEL_HIDE_SCREEN)
		if show:
			for blocker: Dictionary in entry.blockers:
				if blocker.label.visible:
					show = false
					break
		label.visible = show
		if label.visible:
			var x := _near(entry.pos).x
			if x != entry.get("x", INF):
				entry.x = x
				label.position = to_3d(Vector2(x, entry.pos.y), 0.35)

	_update_scenery(z, level)
	_update_province_labels(z)


# --- Scenery ------------------------------------------------------------------

## Soft blob shadows instead of shadow maps: cheap on phones, and the Mobile
## renderer cannot project real shadows onto a transparent layer anyway.
func _blob_shadow() -> PlaneMesh:
	if _blob_shadow_mesh:
		return _blob_shadow_mesh
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.45))
	gradient.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_blob_shadow_mesh = PlaneMesh.new()
	_blob_shadow_mesh.size = Vector2(1, 1)
	_blob_shadow_mesh.material = mat
	return _blob_shadow_mesh


## Ground transform for a blob shadow under an object of the given footprint
## radius and height, pushed away from the light.
func _blob_transform(ground: Vector3, radius: float, height: float) -> Transform3D:
	var away := Vector3(LIGHT_DIRECTION.x, 0, LIGHT_DIRECTION.z).normalized()
	var size := Vector3(radius * 2.0 + height * 0.6, 1, radius * 1.6 + height * 0.4)
	return Transform3D(Basis.from_scale(size), ground + away * height * 0.35 + Vector3(0, 0.002, 0))


func _add_blob_shadow(parent: Node3D, radius: float, height: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _blob_shadow()
	mi.transform = _blob_transform(Vector3.ZERO, radius, height)
	parent.add_child(mi)


## Scatters trees over forests and jungles and peaks over mountains,
## deterministically per province so the map looks the same every launch, and
## buckets them by map tile. Nothing is instanced until a tile comes into view.
func _build_terrain_props() -> void:
	_prop_cols = int(ceil(_map_width / PROP_TILE))
	_tree_mesh = CylinderMesh.new()
	_tree_mesh.top_radius = 0.0
	_tree_mesh.bottom_radius = 0.04
	_tree_mesh.height = 0.1
	_tree_mesh.radial_segments = 6
	_tree_mesh.rings = 1
	_tree_mesh.material = _vertex_color_material(0.9)

	_peak_mesh = CylinderMesh.new()
	_peak_mesh.top_radius = 0.0
	_peak_mesh.bottom_radius = 0.12
	_peak_mesh.height = 0.11
	_peak_mesh.radial_segments = 5
	_peak_mesh.rings = 1
	_peak_mesh.material = _vertex_color_material(0.95)

	for p: Province in world.provinces.values():
		var rng := RandomNumberGenerator.new()
		rng.seed = p.id * 7919
		var mountainous := p.topography == "mountains" or (p.is_wasteland and p.terrain == "mountains")
		var tree_share: float = TREE_SHARE.get(p.vegetation, 0.0) * (0.5 if mountainous else 1.0)
		if tree_share > 0.0 and not p.is_wasteland:
			var jungle := p.vegetation == "jungle"
			var dark := Color(0.08, 0.26, 0.10) if jungle else Color(0.16, 0.30, 0.14)
			var light := Color(0.16, 0.38, 0.14) if jungle else Color(0.25, 0.40, 0.18)
			var count := mini(int(p.area * TREES_PER_AREA * tree_share), int(MAX_PROPS_PER_PROVINCE * tree_share))
			for pos in _scatter(p, count, rng):
				var s := rng.randf_range(0.75, 1.3)
				var h := _tree_mesh.height * s * rng.randf_range(0.9, 1.4)
				var b := _bucket(pos)
				b.trees.append(Transform3D(Basis.from_scale(Vector3(s, h / _tree_mesh.height, s)), to_3d(pos, h * 0.5)))
				b.tree_colors.append(dark.lerp(light, rng.randf()))
				b.shadows.append(_blob_transform(to_3d(pos), _tree_mesh.bottom_radius * s, h))
		if mountainous:
			var cap := MAX_PROPS_PER_WASTELAND if p.is_wasteland else MAX_PROPS_PER_PROVINCE
			for pos in _scatter(p, mini(int(p.area * PEAKS_PER_AREA), cap), rng):
				var s := rng.randf_range(0.7, 1.4)
				var h := _peak_mesh.height * s * rng.randf_range(0.8, 1.3)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, h / _peak_mesh.height, s))
				var b := _bucket(pos)
				b.peaks.append(Transform3D(basis, to_3d(pos, h * 0.5)))
				b.peak_colors.append(Color(0.27, 0.25, 0.23).lerp(Color(0.38, 0.35, 0.31), rng.randf()))
				b.shadows.append(_blob_transform(to_3d(pos), _peak_mesh.bottom_radius * s, h))


func _bucket(pos: Vector2) -> Dictionary:
	var key := int(pos.y / PROP_TILE) * _prop_cols + int(fposmod(pos.x, _map_width) / PROP_TILE)
	if not _prop_buckets.has(key):
		_prop_buckets[key] = {"shadows": [] as Array[Transform3D], "trees": [] as Array[Transform3D],
			"tree_colors": [] as Array[Color], "peaks": [] as Array[Transform3D], "peak_colors": [] as Array[Color]}
	return _prop_buckets[key]


## Instances scenery only for tiles on or near the screen (region level and
## closer); tiles that drift out of range are freed.
func _update_scenery(z: float, level: MapLod.Level) -> void:
	var wanted := {}
	if level >= MapLod.Level.REGION:
		var center := map_camera.position
		var half := map_camera.view_size() / z * (0.5 + PROP_MARGIN)
		var rows := int(ceil(world.map_size.y / PROP_TILE))
		for ty in range(maxi(int(floor((center.y - half.y) / PROP_TILE)), 0), mini(int(floor((center.y + half.y) / PROP_TILE)), rows - 1) + 1):
			for tx in range(int(floor((center.x - half.x) / PROP_TILE)), int(floor((center.x + half.x) / PROP_TILE)) + 1):
				wanted[Vector2i(tx, ty)] = true
	for tile: Vector2i in _prop_tiles.keys():
		if not wanted.has(tile):
			_prop_tiles[tile].queue_free()
			_prop_tiles.erase(tile)
	var order: Array = wanted.keys()
	var centre_tile := map_camera.position / PROP_TILE
	order.sort_custom(func(a, b): return Vector2(a).distance_squared_to(centre_tile) < Vector2(b).distance_squared_to(centre_tile))
	var built := 0
	_scenery_pending = false
	for tile: Vector2i in order:
		if _prop_tiles.has(tile):
			continue
		var key := tile.y * _prop_cols + posmod(tile.x, _prop_cols)
		if not _prop_buckets.has(key):
			continue
		if built >= NEW_PROP_TILES_PER_FRAME:
			_scenery_pending = true
			continue
		built += 1
		if not _prop_meshes.has(key):
			var b: Dictionary = _prop_buckets[key]
			var white: Array[Color] = []
			white.resize(b.shadows.size())
			white.fill(Color.WHITE)
			_prop_meshes[key] = [_multimesh(_blob_shadow(), b.shadows, white),
				_multimesh(_tree_mesh, b.trees, b.tree_colors), _multimesh(_peak_mesh, b.peaks, b.peak_colors)]
		var node := Node3D.new()
		node.position.x = floor(float(tile.x) / _prop_cols) * _map_width * UNITS_PER_PIXEL
		for mm: MultiMesh in _prop_meshes[key]:
			if mm.instance_count > 0:
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				node.add_child(mmi)
		_props.add_child(node)
		_prop_tiles[tile] = node


## Random points inside a province, kept away from its label point (where the
## capital and the name sit) and from its borders.
func _scatter(p: Province, count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var attempts := 0
	while points.size() < count and attempts < count * 20:
		attempts += 1
		var pos := Vector2(rng.randf_range(p.bounds.position.x, p.bounds.end.x), rng.randf_range(p.bounds.position.y, p.bounds.end.y))
		if map_view.province_at(pos) != p.id or pos.distance_to(p.label_position) < 12.0:
			continue
		if map_view.province_at(pos + Vector2(4, 0)) != p.id or map_view.province_at(pos - Vector2(4, 0)) != p.id \
				or map_view.province_at(pos + Vector2(0, 4)) != p.id or map_view.province_at(pos - Vector2(0, 4)) != p.id:
			continue
		points.append(pos)
	return points


func _multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
		mm.set_instance_color(k, colors[k])
	return mm


func _vertex_color_material(roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	return mat


# --- Capitals -----------------------------------------------------------------

func _build_capitals() -> void:
	var sizes := {}
	for p: Province in world.provinces.values():
		sizes[p.owner_id] = sizes.get(p.owner_id, 0) + 1
	for c: Country in world.countries.values():
		var cap := world.get_province(c.capital_province_id)
		if cap == null:
			continue
		var node := _make_keep(c.color)
		_props.add_child(node)
		_capitals[c.id] = {"node": node, "pos": cap.label_position, "major": sizes.get(c.id, 0) >= MAJOR_POLITY_PROVINCES}


## A small castle keep: stone tower, country-coloured roof and banner.
func _make_keep(color: Color) -> Node3D:
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.82, 0.78, 0.70)
	stone.roughness = 0.9
	var roof := StandardMaterial3D.new()
	roof.albedo_color = color
	roof.roughness = 0.6

	var tower := CylinderMesh.new()
	tower.top_radius = 0.045
	tower.bottom_radius = 0.05
	tower.height = 0.12
	tower.radial_segments = 8
	tower.material = stone
	_add_mesh(root, tower, Vector3(0, 0.06, 0))

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.065
	cone.height = 0.08
	cone.radial_segments = 8
	cone.material = roof
	_add_mesh(root, cone, Vector3(0, 0.16, 0))

	for side in [-1.0, 1.0]:
		var wall := BoxMesh.new()
		wall.size = Vector3(0.06, 0.06, 0.07)
		wall.material = stone
		_add_mesh(root, wall, Vector3(side * 0.075, 0.03, 0.0))
	_add_blob_shadow(root, 0.11, 0.22)
	return root


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)


# --- Labels -------------------------------------------------------------------

## A translucent colour as it looks over `backdrop`, made opaque. Big names
## are drawn glyph by glyph, and translucent halos of neighbouring letters
## overlap and stack into blotches; opaque colours mixed against the ground
## the name sits on look the same without the overlaps showing.
static func _flatten(color: Color, backdrop: Color) -> Color:
	var c := backdrop.lerp(color, color.a)
	c.a = 1.0
	return c


## Opaque text and halo colours for a name over `backdrop` (see _flatten).
static func _label_colors(text_color: Color, halo: Color, backdrop: Color) -> Array[Color]:
	var flat_halo := _flatten(halo, backdrop)
	return [_flatten(text_color, flat_halo), flat_halo]


func _make_label(text: String, font_size: int, color: Color, outline: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = maxi(4, font_size / 6)
	label.modulate = color
	label.outline_modulate = outline
	label.pixel_size = 0.0012
	label.no_depth_test = true
	label.font = _font
	label.double_sided = false
	label.rotation_degrees = Vector3(-90, 0, 0)  # lie flat, readable from above
	return label


## Country names: one label per connected block of territory (so Spain's
## American and Philippine holdings are labelled where they are), sized to the
## block. Small blocks only show when zoomed in far enough to fit.
##
## `owned` (the country's provinces) can be passed in when rebuilding many
## countries at once, to avoid scanning every province per country.
func _rebuild_country_labels(tag: String, owned: Variant = null) -> void:
	for k in range(_country_labels.size() - 1, -1, -1):
		if _country_labels[k].tag == tag:
			_country_labels[k].label.queue_free()
			_country_labels.remove_at(k)
	var country := world.get_country(tag)
	if country == null:
		return
	var candidates: Array = owned if owned != null else world.provinces.values()
	var seen := {}
	for p: Province in candidates:
		if p.owner_id != tag or seen.has(p.id):
			continue
		var area := 0.0
		var sum := Vector2.ZERO
		var sxx := 0.0
		var syy := 0.0
		var sxy := 0.0
		var anchor := p.label_position
		var queue: Array[int] = [p.id]
		seen[p.id] = true
		while not queue.is_empty():
			var q := world.get_province(queue.pop_back())
			# Relative to the first province, so blocks across the seam average correctly.
			var rel := q.label_position - anchor
			rel.x -= _map_width * round(rel.x / _map_width)
			sum += rel * q.area
			area += q.area
			# Second moments, counting each province as a disc of its own area.
			var spread := q.area / (4.0 * PI)
			sxx += q.area * (rel.x * rel.x + spread)
			syy += q.area * (rel.y * rel.y + spread)
			sxy += q.area * rel.x * rel.y
			for n in q.neighbour_ids:
				var np := world.get_province(n)
				if np.owner_id == tag and not seen.has(n):
					seen[n] = true
					queue.append(n)
		var span := sqrt(area) * 1.3
		if span < 20.0:
			continue
		# Principal axis of the block: long, thin countries (Norway, Chile,
		# Italy) are named along their length, as on a paper map.
		var mean := sum / area
		var cxx := sxx / area - mean.x * mean.x
		var cyy := syy / area - mean.y * mean.y
		var cxy := sxy / area - mean.x * mean.y
		var half_diff := sqrt(0.25 * (cxx - cyy) * (cxx - cyy) + cxy * cxy)
		var major := 0.5 * (cxx + cyy) + half_diff
		var minor := maxf(0.5 * (cxx + cyy) - half_diff, 1e-6)
		var angle := 0.0
		var max_letter := INF  # letter height limit in map px (rotated names)
		if sqrt(major / minor) >= LABEL_ROTATE_ELONGATION:
			var axis := 0.5 * atan2(2.0 * cxy, cxx - cyy)
			if absf(axis) <= deg_to_rad(LABEL_MAX_TILT_DEG):
				angle = axis if absf(axis) >= deg_to_rad(LABEL_MIN_TILT_DEG) else 0.0
				# About 60 % of the block's length; letters no taller than half
				# its width (a uniform strip of variance v is sqrt(12 v) across).
				span = maxf(span, 2.1 * sqrt(major))
				max_letter = 0.5 * sqrt(12.0 * minor)
		var text := country.name.to_upper()
		var colors := _label_colors(Color(0.08, 0.06, 0.05, 0.9), Color(1, 0.96, 0.88, 0.6), country.color)
		var label := _make_label(text, 48, colors[0], colors[1])
		label.outline_size = 10
		var width_units := span * 1.0 * UNITS_PER_PIXEL
		label.pixel_size = clampf(minf(width_units / (text.length() * 48 * 0.62), max_letter * UNITS_PER_PIXEL / 48.0),
			0.0004, 0.03)
		_orient(label, angle)
		_viewport.add_child(label)
		var center := anchor + mean
		center.x = fposmod(center.x, _map_width)
		_country_labels.append({"tag": tag, "label": label, "pos": center, "span": span,
			"half": _label_half(text, label.pixel_size), "angle": angle, "blockers": []})


## Half a name's extent in map pixels.
func _label_half(text: String, pixel_size: float) -> Vector2:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48) * pixel_size / UNITS_PER_PIXEL * 0.5


## Lays a label flat on the map, its text running at `angle` (map space,
## radians, positive = clockwise on screen).
static func _orient(label: Label3D, angle: float) -> void:
	label.basis = Basis(Vector3.UP, -angle) * Basis(Vector3.RIGHT, -PI * 0.5)


## The country whose name is shown at a map position, or "". Overlapping names
## resolve to the smaller country (its name is the harder one to hit).
func country_label_at(map_pos: Vector2) -> String:
	var slop := 8.0 / map_camera.zoom.x  # a little extra room for fingers
	var best := ""
	var best_span := INF
	for entry in _country_labels:
		if entry.tag == "" or not entry.label.visible:
			continue
		var d: Vector2 = map_pos - entry.pos
		d.x -= _map_width * round(d.x / _map_width)
		d = d.rotated(-entry.angle)  # into the name's own frame
		if absf(d.x) <= entry.half.x + slop and absf(d.y) <= entry.half.y + slop and entry.span < best_span:
			best = entry.tag
			best_span = entry.span
	return best


func _rebuild_all_country_labels() -> void:
	var by_owner := {}
	for p: Province in world.provinces.values():
		if p.owner_id != "":
			if not by_owner.has(p.owner_id):
				by_owner[p.owner_id] = []
			by_owner[p.owner_id].append(p)
	for tag: String in world.countries:
		_rebuild_country_labels(tag, by_owner.get(tag, []))


## Names that would overlap: the less important one gives way (countries
## before seas and wastelands, larger before smaller). Names live in map
## space, so overlaps do not depend on zoom and are found once per rebuild.
func _update_label_blockers() -> void:
	_country_labels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := 0 if a.tag != "" else 1
		var kb := 0 if b.tag != "" else 1
		return ka < kb if ka != kb else a.span > b.span)
	var cols := int(ceil(_map_width / LABEL_OVERLAP_CELL))
	var grid := {}
	for i in _country_labels.size():
		var entry: Dictionary = _country_labels[i]
		entry.poly = _label_polygon(entry)
		entry.blockers = _overlapping(entry.poly, grid, cols)
		if not entry.blockers.is_empty() and entry.tag != "":
			_find_free_spot(entry, grid, cols)
		entry.box = _box(entry.poly)
		for key in _cells(entry.poly, cols):
			if not grid.has(key):
				grid[key] = PackedInt32Array()
			grid[key].append(i)


## Already placed names (in `grid`) that a polygon overlaps.
func _overlapping(poly: PackedVector2Array, grid: Dictionary, cols: int) -> Array:
	var found := []
	var checked := {}
	var box := _box(poly)
	for key in _cells(poly, cols):
		for j in grid.get(key, PackedInt32Array()):
			if checked.has(j):
				continue
			checked[j] = true
			var other: Dictionary = _country_labels[j]
			# Cheap box test first (on the copy of the world nearest this name).
			var other_box: Rect2 = other.box
			other_box.position.x += _map_width * round((box.position.x - other_box.position.x) / _map_width)
			if other_box.intersects(box) and _polygons_overlap(other.poly, poly):
				found.append(other)
	return found


static func _box(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for v in poly:
		box = box.expand(v)
	return box


## Grid cells a polygon's bounding box touches (x wraps).
func _cells(poly: PackedVector2Array, cols: int) -> Array[int]:
	var box := _box(poly)
	var keys: Array[int] = []
	for cy in range(floori(box.position.y / LABEL_OVERLAP_CELL), floori(box.end.y / LABEL_OVERLAP_CELL) + 1):
		for cx in range(floori(box.position.x / LABEL_OVERLAP_CELL), floori(box.end.x / LABEL_OVERLAP_CELL) + 1):
			keys.append(cy * 4096 + posmod(cx, cols))
	return keys


## A blocked country name tries nearby spots across and along itself, then
## smaller sizes, and takes the first that overlaps no name already placed and
## has its middle on the country's own land. If none fits it keeps its
## blockers and gives way to them.
func _find_free_spot(entry: Dictionary, grid: Dictionary, cols: int) -> void:
	var half: Vector2 = entry.half
	var offsets := [Vector2(0, -1.4), Vector2(0, 1.4), Vector2(-0.5, 0), Vector2(0.5, 0),
		Vector2(-0.5, -1.4), Vector2(0.5, -1.4), Vector2(-0.5, 1.4), Vector2(0.5, 1.4),
		Vector2(0, -2.8), Vector2(0, 2.8), Vector2(0, 0)]
	for scale in [1.0, 0.8, 0.62]:
		for o: Vector2 in offsets:
			var trial := entry.duplicate()
			trial.half = half * scale
			trial.pos = entry.pos + (Vector2(o.x * half.x, o.y * half.y)).rotated(entry.angle)
			if not _on_own_land(entry.tag, trial.pos):
				continue
			var poly := _label_polygon(trial)
			if _overlapping(poly, grid, cols).is_empty():
				entry.pos = Vector2(fposmod(trial.pos.x, _map_width), trial.pos.y)
				entry.half = trial.half
				entry.poly = poly
				entry.blockers = []
				entry.erase("x")  # re-place on the next camera sync
				var label: Label3D = entry.label
				label.pixel_size *= scale
				return


func _on_own_land(tag: String, pos: Vector2) -> bool:
	var p := world.get_province(map_view.province_at(pos))
	return p != null and p.owner_id == tag


## A name's outline in map space (slightly padded), for overlap tests.
func _label_polygon(entry: Dictionary) -> PackedVector2Array:
	var half: Vector2 = entry.half * 1.06 + Vector2(2, 2)
	var poly := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		poly.append(entry.pos + (half * corner).rotated(entry.angle))
	return poly


func _polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	# Bring b to the copy of the world nearest a (names can straddle the seam).
	var shift := Vector2(_map_width * round((a[0].x - b[0].x) / _map_width), 0)
	var moved := PackedVector2Array()
	for v in b:
		moved.append(v + shift)
	return not Geometry2D.intersect_polygons(a, moved).is_empty()


## Wastelands are named across their extent in muted brown, like map lettering.
func _build_wasteland_labels() -> void:
	for p: Province in world.provinces.values():
		if not p.is_wasteland:
			continue
		var span := sqrt(float(p.area)) * 1.3
		if span < 20.0:
			continue
		var text := p.name.to_upper()
		var colors := _label_colors(Color(0.36, 0.27, 0.18, 0.8), Color(0.95, 0.9, 0.8, 0.45),
			MapModes.WASTE_COLORS.get(p.terrain, MapModes.UNCOLONISED))
		var label := _make_label(text, 48, colors[0], colors[1])
		label.outline_size = 8
		label.pixel_size = clampf(span * 0.8 * UNITS_PER_PIXEL / (text.length() * 48 * 0.62), 0.0004, 0.02)
		_viewport.add_child(label)
		_country_labels.append({"tag": "", "label": label, "pos": p.label_position, "span": span,
			"half": _label_half(text, label.pixel_size), "angle": 0.0, "blockers": []})


## Named seas, lettered across the water at the world and region levels like
## a paper map. Only each sea's main tile carries a big label; the other tiles
## ("Coast of Brittany", "Western North Atlantic Ocean") are named at the
## province level.
func _build_sea_labels() -> void:
	var qualifiers := ["Coast of ", "Western ", "Eastern ", "Northern ", "Southern ", "Outer ", "Central ", "Inner "]
	for p: Province in world.provinces.values():
		if not p.is_sea:
			continue
		var minor := false
		for q: String in qualifiers:
			if p.name.begins_with(q):
				minor = true
		if minor or p.name.right(1).is_valid_int():
			continue
		var span := sqrt(float(p.area)) * 1.3
		if span < 20.0:
			continue
		var text := p.name.to_upper()
		var colors := _label_colors(Color(SEA_LABEL_COLOR, 0.75), Color(SEA_LABEL_OUTLINE, 0.4), SEA_BACKDROP)
		var label := _make_label(text, 48, colors[0], colors[1])
		label.outline_size = 6
		label.pixel_size = clampf(span * 0.7 * UNITS_PER_PIXEL / (text.length() * 48 * 0.62), 0.0004, 0.012)
		_viewport.add_child(label)
		_country_labels.append({"tag": "", "label": label, "pos": p.label_position, "span": span,
			"half": _label_half(text, label.pixel_size), "angle": 0.0, "blockers": []})


## Province names: a grid of label points for quick on-screen lookup, and a
## 2D canvas above the 3D layer that draws the chosen names.
func _build_province_label_pool() -> void:
	for p: Province in world.provinces.values():
		var key := _label_cell(p.label_position)
		if not _province_label_grid.has(key):
			_province_label_grid[key] = PackedInt32Array()
		_province_label_grid[key].append(p.id)
	var plain := SystemFont.new()
	plain.font_names = PackedStringArray(MAP_FONT_NAMES)
	_name_font = plain
	_name_canvas = Node2D.new()
	_name_canvas.draw.connect(_draw_province_names)
	get_parent().add_child(_name_canvas)


func _label_cell(pos: Vector2) -> int:
	return int(pos.y / LABEL_GRID) * 4096 + int(fposmod(pos.x, _map_width) / LABEL_GRID)


## Makes the distance-field glyph of every character a name on the map can
## use, before any name is laid out: a glyph made later grows the shared atlas
## under names already laid out and garbles them (letters swapped for others).
## Every name — provinces, seas, wastelands, countries (and the colonial
## nations that may be founded), colonial regions, goods — in both cases,
## plain Latin, digits and punctuation; letters already made (or loaded from
## the glyph cache) are skipped, so this is cheap to repeat. New glyphs are
## saved to the cache.
func _prewarm_glyphs() -> void:
	var chars := {}
	var add := func(text: String) -> void:
		for ch in text:
			chars[ch] = true
		for ch in text.to_upper():
			chars[ch] = true
	for code in range(0x20, 0x7F):
		chars[String.chr(code)] = true
	add.call("–—’‘“”·…→←≈×÷•€")
	for p: Province in world.provinces.values():
		add.call(p.name)
	for c: Country in world.countries.values():
		add.call(c.name)
		add.call(c.adjective)
	for r: Array in Overseas.REGIONS:
		add.call(r[1])
	for named: Array in Overseas.NATION_NAMES.values():
		add.call(named[0])
	for good: String in Goods.CATALOGUE:
		add.call(Goods.name_of(good))
	var fresh := PackedInt32Array()
	for ch: String in chars:
		var code := ch.unicode_at(0)
		if not _glyphs_made.has(code):
			_glyphs_made[code] = true
			fresh.append(code)
	if fresh.is_empty():
		return
	var ts := TextServerManager.get_primary_interface()
	var file := _font as FontFile
	var before := _glyph_count(file)
	for rid: RID in _font.get_rids():
		for code in fresh:
			ts.font_render_range(rid, Vector2i(48, 0), code, code)
	if file != null and _glyph_count(file) != before:
		_save_glyph_cache()  # letters new to this device
	if _name_font != null:
		_name_font.get_string_size("".join(PackedStringArray(chars.keys())), HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(PROVINCE_LABEL_PX))


var _glyphs_made := {}  # character codes whose distance-field glyphs exist


## Glyphs a font file holds (its first size).
static func _glyph_count(f: FontFile) -> int:
	if f == null or f.get_cache_count() == 0 or f.get_size_cache_list(0).is_empty():
		return 0
	return f.get_glyph_list(0, f.get_size_cache_list(0)[0]).size()


## Province names at the province level and closer, for what is on screen
## only: candidates are placed largest-province first, keeping names already
## shown, and skipped when they would overlap another name or not fit their
## province.
func _process(_delta: float) -> void:
	if _scenery_pending and map_camera:
		_update_scenery(map_camera.zoom.x, _lod.level)


## The map mode's value for a province ("" if none), cached until the palette changes.
func _info_text(p: Province) -> String:
	if not _info_mode:
		return ""
	if not _info_cache.has(p.id):
		_info_cache[p.id] = map_view.info_text(p)
	return _info_cache[p.id]


func _on_palette_refreshed() -> void:
	_info_cache.clear()
	var info := map_view.mode in MapModes.INFO_MODES
	var regions := map_view.mode in MapModes.REGION_LABEL_MODES
	_regions.clear()
	if regions:
		_build_regions()
	if info != _info_mode or regions != _region_mode:
		_info_mode = info
		_region_mode = regions
		_shown_names.clear()
		_shown_regions.clear()
		_sync_camera()
	elif map_camera:
		_update_province_labels(map_camera.zoom.x)


## Connected land provinces sharing the mode's value, each block measured like
## a country's territory (area, centre, principal axis) so its one name can
## run along it.
func _build_regions() -> void:
	var seen := {}
	for p: Province in world.provinces.values():
		if p.is_sea or p.is_wasteland or seen.has(p.id):
			continue
		var text := _info_text(p)
		if text == "":
			continue
		var area := 0.0
		var sum := Vector2.ZERO
		var sxx := 0.0
		var syy := 0.0
		var sxy := 0.0
		var anchor := p.label_position
		var members: Array[Province] = []
		var queue: Array[int] = [p.id]
		seen[p.id] = true
		while not queue.is_empty():
			var q := world.get_province(queue.pop_back())
			members.append(q)
			var rel := q.label_position - anchor
			rel.x -= _map_width * round(rel.x / _map_width)
			sum += rel * q.area
			area += q.area
			var spread := q.area / (4.0 * PI)
			sxx += q.area * (rel.x * rel.x + spread)
			syy += q.area * (rel.y * rel.y + spread)
			sxy += q.area * rel.x * rel.y
			for n in q.neighbour_ids:
				var np := world.get_province(n)
				if not seen.has(n) and not np.is_wasteland and not np.is_sea and _info_text(np) == text:
					seen[n] = true
					queue.append(n)
		var mean := sum / area
		var cxx := sxx / area - mean.x * mean.x
		var cyy := syy / area - mean.y * mean.y
		var cxy := sxy / area - mean.x * mean.y
		var half_diff := sqrt(0.25 * (cxx - cyy) * (cxx - cyy) + cxy * cxy)
		var major := 0.5 * (cxx + cyy) + half_diff
		var minor := maxf(0.5 * (cxx + cyy) - half_diff, 1e-6)
		var span := sqrt(area) * 1.3
		var angle := 0.0
		var max_letter := INF
		if sqrt(major / minor) >= LABEL_ROTATE_ELONGATION:
			var axis := 0.5 * atan2(2.0 * cxy, cxx - cyy)
			if absf(axis) <= deg_to_rad(LABEL_MAX_TILT_DEG):
				angle = axis if absf(axis) >= deg_to_rad(LABEL_MIN_TILT_DEG) else 0.0
				span = maxf(span, 2.1 * sqrt(major))
				max_letter = 0.5 * sqrt(12.0 * minor)
		# The centre of a crescent can fall outside it: then the member nearest it.
		var pos := anchor + mean
		var inside := false
		var nearest := members[0].label_position
		var best := INF
		for m in members:
			var d := m.label_position - pos
			d.x -= _map_width * round(d.x / _map_width)
			if d.length_squared() < best:
				best = d.length_squared()
				nearest = m.label_position
		var under := world.get_province(map_view.province_at(pos))
		inside = under != null and under in members
		if not inside:
			pos = nearest
		var key := text + str(members.map(func(m: Province) -> int: return m.id).min())
		_regions.append({"key": key, "text": text.to_upper(), "pos": Vector2(fposmod(pos.x, _map_width), pos.y),
			"span": span, "angle": angle, "max_letter": max_letter})


## Region names on screen: each as large as its region allows (snapped to a
## few sizes), largest first, keeping names already shown, none overlapping.
## Fills `placed` with their screen boxes for the province names to avoid.
func _place_region_labels(z: float, view: Rect2, placed: Array[Rect2]) -> void:
	var candidates := []  # [sort key, region, size, width, centre, box]
	for r: Dictionary in _regions:
		var text: String = r.text
		var want := minf(r.span * REGION_LABEL_WIDTH * z / (text.length() * 0.62), r.max_letter * z * 1.4)
		var size := 0
		for s: int in REGION_LABEL_SIZES:
			if s <= want:
				size = s
		if size == 0:
			continue
		var w := _name_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := map_camera.map_to_screen(_near(r.pos))
		var half := Vector2(w * 0.5, size * 0.6)
		var box := Rect2(at, Vector2.ZERO)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			box = box.expand(at + (half * corner).rotated(r.angle))
		if not view.intersects(box):
			continue
		candidates.append([(0 if _shown_regions.has(r.key) else 1000) - size, r, size, w, at, box])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var shown := {}
	for c: Array in candidates:
		if _placed_regions.size() >= REGION_LABEL_POOL:
			break
		var box: Rect2 = c[5]
		var padded := box.grow(LABEL_PADDING_PX)
		var clear := true
		for other in placed:
			if other.intersects(padded):
				clear = false
				break
		if clear:
			placed.append(box)
			shown[c[1].key] = true
			_placed_regions.append([c[4], c[1].angle, c[1].text, c[2], c[3]])
	_shown_regions = shown


func _update_province_labels(z: float) -> void:
	var shown := {}
	_placed_names.clear()
	_placed_regions.clear()
	var placed: Array[Rect2] = []
	var view := Rect2(Vector2.ZERO, map_camera.view_size())
	if _region_mode:
		_place_region_labels(z, view, placed)
	# Province names from the province zoom; in number modes (economy,
	# population) each province's value from the region zoom too.
	var names := _lod.level >= MapLod.Level.PROVINCE
	var values := _info_mode and not _region_mode
	if names or (values and _lod.level >= MapLod.Level.REGION):
		var half := map_camera.view_size() * 0.5 / z
		var center := map_camera.position
		var cols := int(ceil(_map_width / LABEL_GRID))
		var candidates: Array[int] = []
		for cy in range(int((center.y - half.y) / LABEL_GRID), int((center.y + half.y) / LABEL_GRID) + 1):
			for cx in range(int(floor((center.x - half.x) / LABEL_GRID)), int(floor((center.x + half.x) / LABEL_GRID)) + 1):
				var key := cy * 4096 + posmod(cx, cols)
				if _province_label_grid.has(key):
					candidates.append_array(_province_label_grid[key])
		# Names already shown first (stable), then larger provinces: one native sort
		# on packed keys (shown bit, inverted area, id).
		var keys := PackedInt64Array()
		keys.resize(candidates.size())
		for k in candidates.size():
			var id := candidates[k]
			var area := mini(world.get_province(id).area, 0xFFFFFF)
			keys[k] = (0 if _shown_names.has(id) else 1) << 40 | (0xFFFFFF - area) << 16 | id
		keys.sort()
		for k in keys.size():
			candidates[k] = keys[k] & 0xFFFF
		var size := int(PROVINCE_LABEL_PX)
		var names_placed := 0
		for id in candidates:
			if names_placed >= PROVINCE_LABEL_POOL:
				break
			var p := world.get_province(id)
			var info := _info_text(p) if values else ""
			var lines := []  # [text, size, colour, outline]
			if names:
				var name_size := int(INFO_NAME_PX) if info != "" else size
				lines.append([p.name, name_size, SEA_LABEL_COLOR if p.is_sea else PROVINCE_LABEL_COLOR,
					SEA_LABEL_OUTLINE if p.is_sea else PROVINCE_LABEL_OUTLINE])
			if info != "":
				lines.append([info, int(INFO_LABEL_PX), INFO_LABEL_COLOR, PROVINCE_LABEL_OUTLINE])
			if lines.is_empty():
				continue
			var text_size := Vector2.ZERO
			for line: Array in lines:
				var line_size := _name_font.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1])
				text_size = Vector2(maxf(text_size.x, line_size.x), text_size.y + line_size.y)
			# Skip names that would spill far outside a small province (a lone
			# value may spill a little more: it is short and wanted everywhere).
			if sqrt(float(p.area)) * z < text_size.x * (0.45 if names else 0.3):
				continue
			var at := map_camera.map_to_screen(_near(p.label_position + Vector2(0, 7)))
			var rect := Rect2(at - text_size * 0.5, text_size)
			if not view.intersects(rect):
				continue
			var padded := rect.grow(LABEL_PADDING_PX)
			var clear := true
			for other in placed:
				if other.intersects(padded):
					clear = false
					break
			if clear:
				placed.append(rect)
				names_placed += 1
				shown[id] = true
				_placed_names.append([rect.position, rect.size.x, lines])
	_shown_names = shown
	_name_canvas.queue_redraw()


func _draw_province_names() -> void:
	# Region names first (under the province names), each turned along its region.
	for outline in [true, false]:
		for entry: Array in _placed_regions:
			var font_size: int = entry[3]
			_name_canvas.draw_set_transform(entry[0], entry[1])
			var at := Vector2(-entry[4] * 0.5, (_name_font.get_ascent(font_size) - _name_font.get_descent(font_size)) * 0.5)
			if outline:
				_name_canvas.draw_string_outline(_name_font, at, entry[2], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
					maxi(4, font_size / 5), PROVINCE_LABEL_OUTLINE)
			else:
				_name_canvas.draw_string(_name_font, at, entry[2], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INFO_LABEL_COLOR)
	_name_canvas.draw_set_transform(Vector2.ZERO, 0.0)
	for outline in [true, false]:  # all halos first, so no halo covers a letter
		for entry: Array in _placed_names:
			var y: float = entry[0].y
			for line: Array in entry[2]:
				var line_size: int = line[1]
				y += _name_font.get_ascent(line_size)
				var w := _name_font.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line_size).x
				var at := Vector2(entry[0].x + (entry[1] - w) * 0.5, y)  # centred lines
				if outline:
					_name_canvas.draw_string_outline(_name_font, at, line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line_size, 4, line[3])
				else:
					_name_canvas.draw_string(_name_font, at, line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line_size, line[2])
				y += _name_font.get_descent(line_size)


# --- Selection ----------------------------------------------------------------

func _build_selection_pin() -> void:
	_selection_pin = Node3D.new()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.3)
	gold.metallic = 0.6
	gold.roughness = 0.35
	var gem := SphereMesh.new()
	gem.radius = 0.045
	gem.height = 0.12
	gem.radial_segments = 4
	gem.rings = 2
	gem.material = gold
	_add_mesh(_selection_pin, gem, Vector3(0, 0.32, 0))
	var stem := CylinderMesh.new()
	stem.top_radius = 0.008
	stem.bottom_radius = 0.002
	stem.height = 0.26
	stem.material = gold
	_add_mesh(_selection_pin, stem, Vector3(0, 0.13, 0))
	_add_blob_shadow(_selection_pin, 0.025, 0.36)
	_selection_pin.visible = false
	_props.add_child(_selection_pin)


func _on_province_selected(province_id: int) -> void:
	var p := world.get_province(province_id)
	_selection_pin.visible = p != null
	if p:
		var offset := Vector2.ZERO
		for c: Country in world.countries.values():
			if c.capital_province_id == province_id:
				offset = Vector2(12, 0)  # stand beside the castle
		_selection_pos = p.label_position + offset
		_selection_pin.position = to_3d(_near(_selection_pos))


## A save was loaded or a new campaign began: rebuild names and capitals.
## A country founded (a colonial nation): its name's letters are made before
## the names are laid out again — once, at the end of the frame.
func _on_countries_changed() -> void:
	if not _countries_pending:
		_countries_pending = true
		var epoch := _labels_epoch
		(func():
			_countries_pending = false
			if epoch == _labels_epoch:  # not rebuilt since (a restore rebuilds at once)
				_on_campaign_restored()).call_deferred()


var _countries_pending := false
var _labels_epoch := 0  # counts rebuilds of every name and keep


func _on_campaign_restored() -> void:
	_labels_epoch += 1
	_prewarm_glyphs()  # names founded since (colonial nations) may bring new letters
	_rebuild_all_country_labels()
	_update_label_blockers()
	for tag: String in _capitals:
		_capitals[tag].node.queue_free()
	_capitals.clear()
	_build_capitals()
	_marker_scale = -1.0  # new keeps need their zoom-dependent scale
	_sync_camera()


## Names of the countries involved are rebuilt — once per frame, however many
## provinces change hands in it (a month can bring dozens).
func _on_owner_changed(_province_id: int, old_owner: String, new_owner: String) -> void:
	for tag in [old_owner, new_owner]:
		if tag != "":
			_labels_dirty[tag] = true
	if not _labels_pending:
		_labels_pending = true
		_rebuild_dirty_labels.call_deferred()


func _rebuild_dirty_labels() -> void:
	_labels_pending = false
	var by_owner := {}
	for tag: String in _labels_dirty:
		by_owner[tag] = []
	for p: Province in world.ownable_provinces():
		if by_owner.has(p.owner_id):
			by_owner[p.owner_id].append(p)
	for tag: String in _labels_dirty:
		_rebuild_country_labels(tag, by_owner[tag])
	_labels_dirty.clear()
	_update_label_blockers()
	for tag: String in _capitals.keys():
		if world.get_country(tag).capital_province_id == 0:
			_capitals[tag].node.queue_free()
			_capitals.erase(tag)
	_sync_camera()
