extends RefCounted
## Projection and vector rasterisation for the world generator.
##
## Map projection: Mercator, longitudes -170..190 (the seam runs through the
## Bering Sea so no major landmass is split), latitudes 76N..62S: enough to show
## the Barents Sea north of Lapland and the Drake Passage south of Cape Horn as
## open, sailable water, while leaving out the polar caps. Mercator keeps shapes
## recognisable and gives Europe the extra pixels its province density needs.

const LON_WEST := -170.0
const LAT_NORTH := 76.0
const LAT_SOUTH := -62.0
const EARTH_RADIUS_KM := 6371.0

var width: int
var height: int
var _y_north: float
var _y_south: float


func _init(p_width: int) -> void:
	width = p_width
	_y_north = _merc(LAT_NORTH)
	_y_south = _merc(LAT_SOUTH)
	height = int(round(width * (_y_north - _y_south) / TAU))


static func _merc(lat: float) -> float:
	lat = clampf(lat, -85.0, 85.0)
	return log(tan(PI * 0.25 + deg_to_rad(lat) * 0.5))


func lon_to_x(lon: float) -> float:
	return (lon - LON_WEST) / 360.0 * width


func lat_to_y(lat: float) -> float:
	return (_y_north - _merc(lat)) / (_y_north - _y_south) * height


func x_to_lon(x: float) -> float:
	return LON_WEST + x / width * 360.0


func y_to_lat(y: float) -> float:
	var m := _y_north - y / height * (_y_north - _y_south)
	return rad_to_deg(2.0 * atan(exp(m)) - PI * 0.5)


## Pixel coordinates (x, y) of a lat/lon, with longitudes wrapped into the map.
func to_px(lat: float, lon: float) -> Vector2:
	if lon < LON_WEST:
		lon += 360.0
	return Vector2(lon_to_x(lon), lat_to_y(lat))


## True area in km² of one pixel in row y (Mercator is conformal: square pixels).
func pixel_area_km2(y: int) -> float:
	var lat := deg_to_rad(y_to_lat(y + 0.5))
	var side := 360.0 / width * (PI / 180.0) * EARTH_RADIUS_KM * cos(lat)
	return side * side


static func haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var p1 := deg_to_rad(lat1)
	var p2 := deg_to_rad(lat2)
	var dp := p2 - p1
	var dl := deg_to_rad(lon2 - lon1)
	var a := sin(dp * 0.5) * sin(dp * 0.5) + cos(p1) * cos(p2) * sin(dl * 0.5) * sin(dl * 0.5)
	return 2.0 * EARTH_RADIUS_KM * asin(minf(1.0, sqrt(a)))


## Loads a GeoJSON FeatureCollection. Returns [{props, polygons, lines}]:
## each polygon is an Array of rings, each ring and each line a
## PackedVector2Array of (lon, lat).
static func load_features(path: String) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := []
	for f: Dictionary in data.features:
		var g: Dictionary = f.geometry if f.geometry else {}
		var polygons := []
		var lines := []
		match g.get("type", ""):
			"Polygon":
				polygons.append(_rings(g.coordinates))
			"MultiPolygon":
				for poly in g.coordinates:
					polygons.append(_rings(poly))
			"LineString":
				lines = _rings([g.coordinates])
			"MultiLineString":
				lines = _rings(g.coordinates)
		out.append({"props": f.properties, "polygons": polygons, "lines": lines})
	return out


static func _rings(coords: Array) -> Array:
	var rings := []
	for ring: Array in coords:
		var pts := PackedVector2Array()
		pts.resize(ring.size())
		for k in ring.size():
			pts[k] = Vector2(ring[k][0], ring[k][1])
		rings.append(pts)
	return rings


## Writes `value` into every pixel whose centre lies inside any polygon
## (even-odd rule across each polygon's rings, so holes work). Polygons that
## cross the map seam are drawn twice, shifted by 360 degrees, and clipped.
func fill_polygons(target: PackedInt32Array, polygons: Array, value: int) -> void:
	for rings: Array in polygons:
		var min_lon := INF
		var max_lon := -INF
		for ring: PackedVector2Array in rings:
			for v in ring:
				min_lon = minf(min_lon, v.x)
				max_lon = maxf(max_lon, v.x)
		for shift in [0.0, 360.0]:
			if max_lon + shift < LON_WEST or min_lon + shift > LON_WEST + 360.0:
				continue
			var projected := []
			for ring: PackedVector2Array in rings:
				var pts := PackedVector2Array()
				pts.resize(ring.size())
				for k in ring.size():
					pts[k] = Vector2(lon_to_x(ring[k].x + shift), lat_to_y(ring[k].y))
				projected.append(pts)
			_scanline_fill(target, projected, value)


func _scanline_fill(target: PackedInt32Array, rings: Array, value: int) -> void:
	var rows := {}
	for ring: PackedVector2Array in rings:
		var n := ring.size()
		for k in n:
			var a := ring[k]
			var b := ring[(k + 1) % n]
			if a.y == b.y:
				continue
			var y0 := minf(a.y, b.y)
			var y1 := maxf(a.y, b.y)
			# Rows whose centre (r + 0.5) lies in [y0, y1).
			var r0 := maxi(int(ceil(y0 - 0.5)), 0)
			var r1 := mini(int(ceil(y1 - 0.5)) - 1, height - 1)
			if r1 < r0:
				continue
			var slope := (b.x - a.x) / (b.y - a.y)
			for r in range(r0, r1 + 1):
				var x := a.x + (r + 0.5 - a.y) * slope
				if not rows.has(r):
					rows[r] = PackedFloat32Array()
				rows[r].append(x)
	for r: int in rows:
		var xs: PackedFloat32Array = rows[r]
		xs.sort()
		var base := r * width
		for k in range(0, xs.size() - 1, 2):
			var xa := maxi(int(ceil(xs[k] - 0.5)), 0)
			var xb := mini(int(ceil(xs[k + 1] - 0.5)) - 1, width - 1)
			for x in range(xa, xb + 1):
				target[base + x] = value


## Draws polylines (lon, lat) into a byte mask at `scale` x map resolution,
## keeping the larger value where lines overlap. Steps are 4-connected so a
## line cannot be crossed diagonally.
func draw_lines(target: PackedByteArray, lines: Array, value: int, scale := 1.0) -> void:
	var w := int(width * scale)
	var h := int(ceil(height * scale))
	for line: PackedVector2Array in lines:
		var prev := Vector2.INF
		for v in line:
			var lon := v.x if v.x >= LON_WEST else v.x + 360.0
			var pt := Vector2(lon_to_x(lon), lat_to_y(v.y)) * scale
			if prev != Vector2.INF and absf(pt.x - prev.x) < w * 0.5:
				_draw_segment(target, w, h, prev, pt, value)
			prev = pt


## Like draw_lines, but writes an id into an int mask (last line wins).
func draw_line_ids(target: PackedInt32Array, lines: Array, id: int) -> void:
	for line: PackedVector2Array in lines:
		var prev := Vector2.INF
		for v in line:
			var lon := v.x if v.x >= LON_WEST else v.x + 360.0
			var pt := Vector2(lon_to_x(lon), lat_to_y(v.y))
			if prev != Vector2.INF and absf(pt.x - prev.x) < width * 0.5:
				var n := int(ceil(maxf(absf(pt.x - prev.x), absf(pt.y - prev.y)))) + 1
				for k in n + 1:
					var p := prev.lerp(pt, float(k) / n)
					var x := int(floor(p.x))
					var y := int(floor(p.y))
					if x >= 0 and x < width and y >= 0 and y < height:
						target[y * width + x] = id
			prev = pt


static func _draw_segment(target: PackedByteArray, w: int, h: int, a: Vector2, b: Vector2, value: int) -> void:
	var n := int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y)) * 2.0)) + 1
	var px := int(floor(a.x))
	var py := int(floor(a.y))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		var x := int(floor(p.x))
		var y := int(floor(p.y))
		if x != px and y != py:
			_plot(target, w, h, x, py, value)  # fill the corner: keep the line 4-connected
		_plot(target, w, h, x, y, value)
		px = x
		py = y


static func _plot(target: PackedByteArray, w: int, h: int, x: int, y: int, value: int) -> void:
	if x >= 0 and x < w and y >= 0 and y < h and target[y * w + x] < value:
		target[y * w + x] = value
