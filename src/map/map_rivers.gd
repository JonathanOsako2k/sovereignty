class_name MapRivers
extends Node2D
## Rivers as anti-aliased vector lines over the 2D map, so they stay thin and
## sharp at any zoom.
##
## Detail follows the view: rivers are cut into map tiles, and only tiles
## covering the screen plus a margin exist as Line2D nodes; others are freed.
## Line widths are kept roughly constant on screen, but a tile's lines are
## only rebuilt when the zoom has drifted WIDTH_STEP from their last build, so
## a smooth zoom does not re-tessellate every line every frame. Minor rivers
## appear only at the province level and closer. The world wraps east-west, so
## a tile is placed at whichever copy of the map the camera is over.

const DATA_PATH := "res://data/map/rivers.json"
const COLOR := Color(0.22, 0.38, 0.50, 0.9)
## Screen-pixel width by rank (1 = great rivers, 3 = minor rivers).
const WIDTH_PX := [0.0, 2.4, 1.7, 1.2]
const TILE := 512
## Extra area kept active around the screen, as a fraction of the view size.
const MARGIN := 0.5
## Rebuild a tile's line widths only when the zoom differs by this factor.
const WIDTH_STEP := 1.2
## New tiles built per frame, nearest the view centre first; the rest follow
## on later frames so a big jump in view never costs one long frame.
const NEW_TILES_PER_FRAME := 3

var _map_size := Vector2.ZERO
var _cols := 1
## Wrapped tile key -> Array of [PackedVector2Array, rank].
var _tile_lines: Dictionary = {}
## Unwrapped tile (Vector2i) -> {node, zoom, level}.
var _active: Dictionary = {}
var _pending: Array = []  # [center, view_size, zoom, level] while tiles remain to build


func setup(map_size: Vector2) -> void:
	_map_size = map_size
	_cols = int(ceil(map_size.x / TILE))
	var text := FileAccess.get_file_as_string(DATA_PATH)
	if text.is_empty():
		push_warning("No river data at %s" % DATA_PATH)
		return
	var data: Dictionary = JSON.parse_string(text)
	for river: Dictionary in data.rivers:
		var flat: Array = river.points
		var rank := int(river.rank)
		# Cut the polyline where it changes tile; pieces share the boundary point.
		var piece := PackedVector2Array()
		var piece_key := -1
		for k in range(0, flat.size(), 2):
			var pt := Vector2(flat[k], flat[k + 1])
			var key := _tile_key(pt)
			if piece_key != -1 and key != piece_key:
				piece.append(pt)
				_add_piece(piece_key, piece, rank)
				piece = PackedVector2Array()
			piece.append(pt)
			piece_key = key
		_add_piece(piece_key, piece, rank)


func _process(_delta: float) -> void:
	if not _pending.is_empty():
		update_view(_pending[0], _pending[1], _pending[2], _pending[3])


func _tile_key(pt: Vector2) -> int:
	return int(pt.y / TILE) * _cols + int(pt.x / TILE)


func _add_piece(key: int, points: PackedVector2Array, rank: int) -> void:
	if points.size() < 2:
		return
	if not _tile_lines.has(key):
		_tile_lines[key] = []
	_tile_lines[key].append([points, rank])


## Called on every camera change with the view centre and size in map pixels.
func update_view(center: Vector2, view_size: Vector2, zoom: float, level: MapLod.Level) -> void:
	var wanted := {}
	if level >= MapLod.Level.REGION:
		var half := view_size * (0.5 + MARGIN)
		var rows := int(ceil(_map_size.y / TILE))
		for ty in range(maxi(int(floor((center.y - half.y) / TILE)), 0), mini(int(floor((center.y + half.y) / TILE)), rows - 1) + 1):
			for tx in range(int(floor((center.x - half.x) / TILE)), int(floor((center.x + half.x) / TILE)) + 1):
				wanted[Vector2i(tx, ty)] = true
	for tile: Vector2i in _active.keys():
		if not wanted.has(tile):
			_active[tile].node.queue_free()
			_active.erase(tile)
	var order: Array = wanted.keys()
	var centre_tile := Vector2(center / TILE)
	order.sort_custom(func(a, b): return Vector2(a).distance_squared_to(centre_tile) < Vector2(b).distance_squared_to(centre_tile))
	var built := 0
	_pending = []
	for tile: Vector2i in order:
		var entry: Dictionary = _active.get(tile, {})
		if entry.is_empty():
			var key := tile.y * _cols + posmod(tile.x, _cols)
			if not _tile_lines.has(key):
				continue
			if built >= NEW_TILES_PER_FRAME:
				_pending = [center, view_size, zoom, level]
				continue
			built += 1
			var node := Node2D.new()
			node.position.x = floor(float(tile.x) / _cols) * _map_size.x
			for item: Array in _tile_lines[key]:
				var line := Line2D.new()
				line.points = item[0]
				line.default_color = COLOR
				line.antialiased = true
				line.joint_mode = Line2D.LINE_JOINT_ROUND
				line.begin_cap_mode = Line2D.LINE_CAP_ROUND
				line.end_cap_mode = Line2D.LINE_CAP_ROUND
				line.set_meta("rank", item[1])
				node.add_child(line)
			add_child(node)
			entry = {"node": node, "zoom": -1.0, "level": -1}
			_active[tile] = entry
		var drift: float = maxf(zoom / maxf(entry.zoom, 1e-6), entry.zoom / zoom)
		if drift > WIDTH_STEP or entry.level != level:
			entry.zoom = zoom
			entry.level = level
			for line: Line2D in entry.node.get_children():
				var rank: int = line.get_meta("rank")
				line.visible = level >= (MapLod.Level.PROVINCE if rank == 3 else MapLod.Level.REGION)
				if line.visible:
					line.width = WIDTH_PX[rank] / zoom
