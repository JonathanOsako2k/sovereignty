class_name MapForces
extends Node2D
## Armies, fleets and forts on the map. In the overlay's 3D world: a banner on
## a pole for each army and a ship for each fleet, in the owner's colour,
## spread apart when several share a province and gliding along their march;
## low star-fort walls where a province is fortified and a pier at each dock,
## on the side of its sea (from the region zoom in); fleets in port lie by it.
## Drawn in 2D above the map: the men under each token, rings round the
## selected, their road ahead (dashed, to an arrowhead) and sieges' progress.
## Taps and drags ask it what lies under them.

const PICK_PX := 24.0
const STACK_OFFSET := 14.0  # map px between armies sharing a province
## Foreign armies smaller than this show only from the province zoom in.
const MINOR_ARMY := 5000
## Banners and ships against the other map markers (castles, peaks).
const TOKEN_SCALE := 1.6
const FORT_OFFSET := Vector2(-11.0, 7.0)
## Docks: rays from a port's label look this far (map px) for its shore.
const SHORE_RAYS := 32
const SHORE_REACH := 160
const SHIP_OUT := 5.0  # map px from the dock out to where fleets in port lie
const DOCK_PX := 15.0  # without the id image: map px from the label towards the sea
const LABEL_PX := 13
const RING := Color(1.0, 0.84, 0.35)
const ROAD := Color(1.0, 0.92, 0.6, 0.95)
const SIEGE_COLOR := Color(1.0, 0.9, 0.75)
const TEXT_OUTLINE := Color(0.08, 0.06, 0.05, 0.9)

var world: WorldState
var overlay: MapOverlay3D
var map_camera: MapCamera
var player_tag := ""
var selected: Array[int] = []
## Map position -> province id (the map's id image), to find shores; unset in
## tests, where docks stand off the label towards their sea.
var province_at: Callable

var _tokens := {}  # army id -> Node3D
var _forts := {}  # province id -> Node3D
var _docks := {}  # province id -> Node3D (a pier)
var _dock_points := {}  # province id -> map position of its dock
var _dock_dirs := {}  # province id -> unit vector from the shore out to sea
var _positions := {}  # army id -> map position (one copy of the world)
var _cargo := {}  # fleet id -> men aboard
var _materials := {}  # Color -> StandardMaterial3D
var _meshes := {}
var _refresh_pending := false
var _positions_pending := false


func setup(p_world: WorldState, p_overlay: MapOverlay3D, p_camera: MapCamera) -> void:
	world = p_world
	overlay = p_overlay
	map_camera = p_camera
	_build_meshes()
	world.military.changed.connect(refresh_later)
	world.military.reset.connect(func():
		refresh_forts()
		refresh())
	world.campaign_restored.connect(refresh_forts)
	map_camera.view_changed.connect(func(): _sync())
	refresh_forts()
	refresh()


## Rebuilds once at the end of the frame, however many changes arrive.
func refresh_later() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		refresh.call_deferred()


func refresh() -> void:
	_refresh_pending = false
	var m := world.military
	for id: int in _tokens.keys():
		if not m.armies.has(id):
			_tokens[id].queue_free()
			_tokens.erase(id)
	for a: Army in m.armies.values():
		if not _tokens.has(a.id):
			var node := _make_ship(world.get_country(a.owner).color) if a.navy else _make_banner(world.get_country(a.owner).color)
			overlay.props().add_child(node)
			_tokens[a.id] = node
	selected = selected.filter(func(id: int) -> bool: return m.armies.has(id))
	update_positions()


## Positions once at the end of the frame, however many days passed in it.
func update_positions_later() -> void:
	if not _positions_pending and not _refresh_pending:
		_positions_pending = true
		_positions_due.call_deferred()


func _positions_due() -> void:
	if _positions_pending:  # unless a refresh has placed them meanwhile
		update_positions()


## Where each army stands or marches.
func update_positions() -> void:
	_positions_pending = false
	_positions.clear()
	_cargo.clear()
	for a: Army in world.military.armies.values():
		if a.aboard != 0:
			_cargo[a.aboard] = _cargo.get(a.aboard, 0) + a.men()
	var groups := {}
	for a: Army in world.military.armies.values():
		var here := world.get_province(a.location)
		if here == null:
			continue
		if a.is_moving() and a.leg_total > 0.0:
			var next := world.get_province(a.path[0])
			var from := _anchor(here, a.navy)
			var to := _anchor(next, a.navy)
			to.x += world.map_size.x * round((from.x - to.x) / world.map_size.x)
			_positions[a.id] = from.lerp(to, clampf(1.0 - a.leg_days / a.leg_total, 0.0, 1.0))
		else:
			var key := a.location * 2 + (1 if a.navy else 0)
			if not groups.has(key):
				groups[key] = []
			groups[key].append(a)
	for key: int in groups:
		var list: Array = groups[key]
		list.sort_custom(func(x: Army, y: Army) -> bool: return x.id < y.id)
		var base := _anchor(world.get_province(list[0].location), list[0].navy)
		for i in list.size():
			_positions[list[i].id] = base + Vector2((i - (list.size() - 1) * 0.5) * STACK_OFFSET, 0.0)
	_sync(false)  # forts and docks have not moved


## Where a token stands in a province: a fleet in port off its dock.
func _anchor(p: Province, navy: bool) -> Vector2:
	if navy and not p.is_sea:
		return dock_point(p) + _dock_dirs[p.id] * SHIP_OUT
	return p.label_position


## A dock's place: on the port's shore facing the sea it opens on.
func dock_point(p: Province) -> Vector2:
	if not _dock_points.has(p.id):
		_find_shore(p)
	return _dock_points[p.id]


## Rays from the port's label, through its own land only, find the nearest
## water of the dock's sea (else any water): the dock stands at the last land
## pixel. Without the id image: a little way towards the sea's label.
func _find_shore(p: Province) -> void:
	var origin := p.label_position
	var port_sea := Military.port_sea(world, p)
	var hits := [[INF, origin, Vector2.RIGHT], [INF, origin, Vector2.RIGHT]]  # [port's sea, any water]
	if province_at.is_valid():
		for i in SHORE_RAYS:
			var dir := Vector2.from_angle(TAU * i / SHORE_RAYS)
			var last := origin
			for step in range(1, SHORE_REACH, 2):
				var at := origin + dir * step
				var id: int = province_at.call(at)
				if id == p.id:
					last = at
					continue
				var q := world.get_province(id)
				if q == null or q.is_sea:
					var which := 0 if id == port_sea else 1
					if step < hits[which][0]:
						hits[which] = [float(step), last, dir]
				break  # water, or a neighbour's land
	if hits[0][0] == INF and province_at.is_valid():
		hits[0] = _shore_by_scan(p, port_sea)
	for hit: Array in hits:
		if hit[0] < INF:
			_dock_points[p.id] = hit[1]
			_dock_dirs[p.id] = hit[2]
			return
	var sea := world.get_province(port_sea)
	var dir := Vector2.RIGHT
	if sea != null and _unwrapped_near(sea.label_position, origin) != origin:
		dir = (_unwrapped_near(sea.label_position, origin) - origin).normalized()
	_dock_points[p.id] = origin + dir * DOCK_PX
	_dock_dirs[p.id] = dir


func refresh_forts() -> void:
	for id: int in _forts.keys():
		_forts[id].queue_free()
	_forts.clear()
	for id: int in _docks.keys():
		_docks[id].queue_free()
	_docks.clear()
	for p: Province in world.ownable_provinces():
		if "fort" in p.buildings:
			var node := _make_fort()
			overlay.props().add_child(node)
			_forts[p.id] = node
		if "dock" in p.buildings:
			var pier := _make_dock()
			pier.rotation.y = _pier_angle(p)
			overlay.props().add_child(pier)
			_docks[p.id] = pier
	_sync()


## A port whose shore the rays missed (a narrow estuary): of its own pixels
## (sampled, at most a few thousand) beside the dock's sea, the nearest its
## label. [distance, point, direction to the water], distance INF if none.
func _shore_by_scan(p: Province, port_sea: int) -> Array:
	var best := [INF, p.label_position, Vector2.RIGHT]
	var b := p.bounds
	var stride := maxi(1, ceili(sqrt(b.size.x * b.size.y / 4000.0)))
	for y in range(b.position.y, b.end.y + 1, stride):
		for x in range(b.position.x, b.end.x + 1, stride):
			var at := Vector2(x + 0.5, y + 0.5)
			var d := at.distance_to(p.label_position)
			if d >= best[0] or province_at.call(at) != p.id:
				continue
			for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
				if province_at.call(at + dir) == port_sea or (stride > 1 and province_at.call(at + dir * stride) == port_sea):
					best = [d, at, dir]
					break
	return best


## The pier points from the shore out to sea.
func _pier_angle(p: Province) -> float:
	dock_point(p)
	var d: Vector2 = _dock_dirs[p.id]
	return -atan2(d.y, d.x)


## Places tokens at the copy of the world nearest the camera, scaled with the
## markers. Our forces always show; at the region zoom foreign forts, and
## foreign armies of some size (or our enemies'); every army closer in.
## `static_props`: forts and docks too (after the camera moved, or they changed).
func _sync(static_props := true) -> void:
	if overlay == null:
		return
	var s := overlay.marker_scale()
	var level := overlay.lod_level()
	var detail := level >= MapLod.Level.REGION
	var token_scale := Vector3.ONE * s * TOKEN_SCALE
	for id: int in _tokens:
		var a: Army = world.military.armies.get(id)
		var node: Node3D = _tokens[id]
		var show := a != null and _positions.has(id) and a.aboard == 0 and (a.owner == player_tag or level >= MapLod.Level.PROVINCE
			or (detail and (world.military.at_war(player_tag, a.owner) or a.men() >= MINOR_ARMY)))
		# Only what changed is touched: hidden tokens are placed when they show.
		if node.visible != show:
			node.visible = show
		if not show:
			continue
		var at := MapOverlay3D.to_3d(overlay.near(_positions[id]))
		if node.position != at:
			node.position = at
		if node.scale != token_scale:
			node.scale = token_scale
	if not static_props:
		queue_redraw()
		return
	for id: int in _forts:
		var node: Node3D = _forts[id]
		node.visible = detail
		if detail:
			node.position = MapOverlay3D.to_3d(overlay.near(world.get_province(id).label_position + FORT_OFFSET))
			node.scale = Vector3.ONE * s
	for id: int in _docks:
		var node: Node3D = _docks[id]
		node.visible = detail
		if detail:
			node.position = MapOverlay3D.to_3d(overlay.near(dock_point(world.get_province(id))))
			node.scale = Vector3.ONE * s
	queue_redraw()


# --- Picking --------------------------------------------------------------------------

func army_position(id: int) -> Vector2:
	return overlay.near(_positions.get(id, Vector2.ZERO))


## The army whose token is under a map point (0 if none): the nearest within a
## finger's reach, own armies preferred when tokens overlap. Zoomed out to the
## whole world a tap picks provinces and countries (drag a box for armies).
func army_at(map_pos: Vector2) -> int:
	if overlay.lod_level() < MapLod.Level.REGION:
		return 0
	var best := 0
	var best_d := PICK_PX / map_camera.zoom.x
	for id: int in _tokens:
		var a: Army = world.military.armies.get(id)
		if a == null or not _tokens[id].visible:
			continue  # (a token outlives its army until the next refresh)
		var d := army_position(id).distance_to(map_pos)
		if a.owner == player_tag:
			d *= 0.8
		if d < best_d:
			best_d = d
			best = id
	return best


## Our armies and fleets inside a map rectangle.
func armies_in(rect: Rect2) -> Array[int]:
	var out: Array[int] = []
	for a: Army in world.military.armies.values():
		if a.owner == player_tag and _positions.has(a.id) and rect.has_point(army_position(a.id)):
			out.append(a.id)
	return out


# --- 2D: men, selection, roads, sieges ---------------------------------------------------

func _draw() -> void:
	if overlay == null or map_camera == null:
		return
	var font := overlay.map_font()
	var view := Rect2(Vector2.ZERO, map_camera.view_size()).grow(40.0)
	# Roads of the selected armies.
	for id: int in selected:
		var a: Army = world.military.armies.get(id)
		if a == null or not a.is_moving():
			continue
		var at := map_camera.map_to_screen(army_position(id))
		var prev_screen := at
		var prev_map := army_position(id)
		for step: int in a.path:
			var to_map := _unwrapped_near(world.get_province(step).label_position, prev_map)
			var to := map_camera.map_to_screen(to_map)
			draw_dashed_line(at, to, ROAD, 3.0, 9.0)
			prev_screen = at
			prev_map = to_map
			at = to
		var dir := (at - prev_screen).normalized()
		if dir != Vector2.ZERO:
			var side := dir.orthogonal() * 7.0
			draw_colored_polygon(PackedVector2Array([at, at - dir * 12.0 + side, at - dir * 12.0 - side]), ROAD)
	# Men under each visible token; rings round the selected.
	for id: int in _tokens:
		var node: Node3D = _tokens[id]
		if not node.visible:
			continue
		var a: Army = world.military.armies.get(id)
		if a == null:
			continue  # (a token outlives its army until the next refresh)
		var at := map_camera.map_to_screen(army_position(id))
		if not view.has_point(at):
			continue
		if id in selected:
			draw_arc(at + Vector2(0, 2), 15.0, 0.0, TAU, 28, RING, 3.0)
		var text := _men_text(a.men()) if not a.navy else "%d ⚓" % a.regiments.size()
		if a.navy and _cargo.has(a.id):
			text += " · " + _men_text(_cargo[a.id])
		if a.retreating:
			text += " ↩"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX).x
		var pos := at + Vector2(-w * 0.5, 20.0)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX, 4, TEXT_OUTLINE)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX, Color.WHITE)
	# Sieges under way.
	if overlay.lod_level() >= MapLod.Level.REGION:
		for loc: int in world.military.sieges:
			var p := world.get_province(loc)
			var s: Dictionary = world.military.sieges[loc]
			var total := 10.0
			if "fort" in p.buildings:
				total = Policies.fort_days(world.get_country(p.owner_id).spending.forts if world.get_country(p.owner_id) else 100)
				if world.get_country(p.owner_id) and world.get_country(p.owner_id).capital_province_id == p.id:
					total *= MilitarySystem.CAPITAL_SIEGE
			var at := map_camera.map_to_screen(overlay.near(p.label_position)) + Vector2(0, -26)
			if not view.has_point(at):
				continue
			var text := "Siege %d %%" % mini(int(s.progress / total * 100.0), 99)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX).x
			draw_string_outline(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX, 4, TEXT_OUTLINE)
			draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX, SIEGE_COLOR)


func _unwrapped_near(pos: Vector2, ref: Vector2) -> Vector2:
	return Vector2(pos.x + world.map_size.x * round((ref.x - pos.x) / world.map_size.x), pos.y)


static func _men_text(men: int) -> String:
	if men >= 10000:
		return "%dk" % roundi(men / 1000.0)
	if men >= 1000:
		return "%.1fk" % (men / 1000.0)
	return str(men)


# --- 3D tokens -------------------------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.7
		_materials[color] = m
	return _materials[color]


func _build_meshes() -> void:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.004
	pole.bottom_radius = 0.004
	pole.height = 0.2
	pole.radial_segments = 6
	pole.material = _material(Color(0.32, 0.25, 0.18))
	_meshes.pole = pole
	var flag := BoxMesh.new()
	flag.size = Vector3(0.075, 0.05, 0.008)
	_meshes.flag = flag
	var base := CylinderMesh.new()
	base.top_radius = 0.03
	base.bottom_radius = 0.035
	base.height = 0.012
	base.radial_segments = 10
	base.material = _material(Color(0.2, 0.18, 0.16))
	_meshes.base = base
	var hull := BoxMesh.new()
	hull.size = Vector3(0.11, 0.028, 0.04)
	hull.material = _material(Color(0.42, 0.28, 0.16))
	_meshes.hull = hull
	var sail := BoxMesh.new()
	sail.size = Vector3(0.006, 0.075, 0.055)
	sail.material = _material(Color(0.95, 0.93, 0.86))
	_meshes.sail = sail
	var ring := CylinderMesh.new()
	ring.top_radius = 0.05
	ring.bottom_radius = 0.056
	ring.height = 0.022
	ring.radial_segments = 6
	ring.material = _material(Color(0.62, 0.6, 0.55))
	_meshes.fort = ring
	var bastion := BoxMesh.new()
	bastion.size = Vector3(0.026, 0.026, 0.026)
	bastion.material = _material(Color(0.7, 0.68, 0.62))
	_meshes.bastion = bastion
	var deck := BoxMesh.new()
	deck.size = Vector3(0.12, 0.008, 0.026)
	deck.material = _material(Color(0.5, 0.36, 0.22))
	_meshes.deck = deck
	var post := CylinderMesh.new()
	post.top_radius = 0.005
	post.bottom_radius = 0.005
	post.height = 0.026
	post.radial_segments = 6
	post.material = _material(Color(0.3, 0.22, 0.15))
	_meshes.post = post


func _make_banner(color: Color) -> Node3D:
	var root := Node3D.new()
	_add(root, _meshes.base, Vector3(0, 0.006, 0))
	_add(root, _meshes.pole, Vector3(0, 0.1, 0))
	var flag := MeshInstance3D.new()
	flag.mesh = _meshes.flag
	flag.material_override = _material(color)
	flag.position = Vector3(0.04, 0.17, 0)
	root.add_child(flag)
	return root


func _make_ship(color: Color) -> Node3D:
	var root := Node3D.new()
	_add(root, _meshes.hull, Vector3(0, 0.014, 0))
	_add(root, _meshes.sail, Vector3(0, 0.07, 0))
	var flag := MeshInstance3D.new()
	flag.mesh = _meshes.flag
	flag.material_override = _material(color)
	flag.scale = Vector3(0.5, 0.5, 0.5)
	flag.position = Vector3(0.02, 0.12, 0)
	root.add_child(flag)
	return root


func _make_fort() -> Node3D:
	var root := Node3D.new()
	_add(root, _meshes.fort, Vector3(0, 0.011, 0))
	for corner in [Vector3(0.05, 0, 0), Vector3(-0.05, 0, 0), Vector3(0, 0, 0.05), Vector3(0, 0, -0.05)]:
		_add(root, _meshes.bastion, corner + Vector3(0, 0.013, 0))
	return root


## A wooden pier on posts, along +x (out to sea).
func _make_dock() -> Node3D:
	var root := Node3D.new()
	_add(root, _meshes.deck, Vector3(0, 0.022, 0))
	for x in [-0.05, 0.0, 0.05]:
		for z in [-0.011, 0.011]:
			_add(root, _meshes.post, Vector3(x, 0.013, z))
	return root


func _add(parent: Node3D, mesh: Mesh, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
