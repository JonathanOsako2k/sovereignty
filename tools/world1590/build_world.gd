extends SceneTree
## Builds the 1590 world: real geography from Natural Earth, 5000 ownable
## provinces split by regional quota, impassable wastelands on top, and the
## authored 1590 political map.
##
## Run from the project root (takes a couple of minutes):
##   godot --headless --path . --script res://tools/world1590/build_world.gd
##
## Pipeline:
##  1. Rasterise modern countries (land, population zones, 1590 rules), lakes,
##     geography regions (terrain), first-level divisions (counties,
##     departments, states...) and rivers onto a Mercator grid.
##  2. Mark wastelands: desert and high-mountain cores, Greenland's ice and the
##     high Arctic. They are impassable, unownable and not among the 5000.
##  3. Build provinces on the real divisions: small divisions are merged with
##     neighbours, large ones are split, so each region meets its quota. Splits
##     grow from seeds with high costs for crossing rivers and mountains, so
##     interior borders follow them. The map wraps east-west.
##  4. Split every large water body into named sea tiles (not ownable; they
##     record which seas and coasts they touch, for naval movement later).
##  5. Assign each province its 1590 owner, terrain, name and population.
##  5. Write data/map/*.res and the data/world, data/scenarios JSON.

const Geo := preload("res://tools/world1590/geo.gd")
const Regions := preload("res://tools/world1590/regions_1590.gd")
const Politics := preload("res://tools/world1590/polities_1590.gd")
const Land1590 := preload("res://tools/world1590/land_1590.gd")
const Resources := preload("res://tools/world1590/resources_1590.gd")

const SRC := "res://tools/source_data/"
const MAP_WIDTH := 6144
const SEED := 1590
const DATA_VERSION := 7
const PLAYER_COUNTRY := "ENG"
## Divisions worth less than this share of a province are merged into neighbours.
const MIN_GROUP_ALLOCATION := 0.55
const GRID := 24
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]
## Extra growth cost for crossing a river pixel (major, minor), mountains, hills.
const RIVER_COST := [0, 8, 14]
const MOUNTAIN_COST := 3
const HILL_COST := 1
## Waste types.
enum Waste { NONE, DESERT, MOUNTAIN, ICE, ARCTIC }
const WASTE_TERRAIN := ["", "desert", "mountains", "glacier", "tundra"]

## Palette for polities without an authored colour; picked to contrast with
## neighbours.
const AUTO_COLORS := ["#8e7cc3", "#c27ba0", "#6fa8dc", "#93c47d", "#e69138", "#e5c04a", "#76a5af",
	"#a64d79", "#45818e", "#b45f06", "#6aa84f", "#b8705a", "#3d85c6", "#bf9000", "#7a6aa8", "#38761d",
	"#b86a8a", "#7b9ad0", "#e06666", "#8a7a30", "#a2c4c9", "#d5a6bd", "#b6d7a8", "#f6b26b", "#9fc5e8",
	"#b4a7d6", "#dd7e6b", "#5a9a8a", "#9a5a3a", "#7a8a3a"]

var geo: Geo
var W: int
var H: int
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var _t0 := 0

var row_lat := PackedFloat64Array()
var row_area := PackedFloat64Array()
var col_lon := PackedFloat64Array()

var adm := PackedInt32Array()  # country index (into adm_codes), 0 = water
var adm_codes: Array[String] = [""]
var georeg := PackedInt32Array()  # geography feature index, 0 = none
var geo_terrain: PackedInt32Array = [-1]
var geo_seed_factor: PackedFloat32Array = [1.0]
var geo_names: Array[String] = [""]
var unit := PackedInt32Array()  # first-level division index, 0 = none
var unit_all := PackedInt32Array()  # same, before wastelands were cut out
var _stamps := []  # island states stamped onto the map: {px, code, name}
var units: Array[Dictionary] = [{}]
var river := PackedByteArray()  # 0 none, 1 minor, 2 major
var river_lines := []  # [lines, display value] for the relief texture
var river_id := PackedInt32Array()  # named river per pixel (index into river_names), 0 = none
var river_names: Array[String] = [""]
var waste := PackedByteArray()  # Waste type per pixel
var zone := PackedInt32Array()
var zone_keys: Array[String] = [""]
var zone_region: PackedInt32Array = [-1]
var zone_area: PackedFloat64Array = [0.0]
var zone_pop: PackedFloat64Array = [0.0]
var zone_seed_density: PackedFloat64Array = [0.0]
## Regions.SEED_BOOSTS on a coarse grid (BOOST_CELL px), multiplied into seed weights.
const BOOST_CELL := 8
var seed_boost := PackedFloat32Array()
var _boost_w := 1
var region_ids: Array = Regions.REGIONS.keys()
var region_quota := PackedInt32Array()

var groups: Array[Dictionary] = []
var group_of_unit := PackedInt32Array()
var gpx := PackedInt32Array()  # group per pixel, -1 = none

var seed_px := PackedInt32Array()
var seed_group := PackedInt32Array()
var seed_capital: Array[String] = []
var _grid: Dictionary = {}
var _grid_w: int

var ids := PackedInt32Array()
var province_count := 0
var waste_count := 0
var sea_count := 0
var marine := PackedInt32Array()  # named sea/gulf/strait/lake per pixel, 0 = none
var island := PackedInt32Array()  # named island or island group per pixel, 0 = none
var island_names: Array[String] = [""]
var marine_names: Array[String] = [""]
var sea_body := PackedInt32Array()  # per sea tile: index of its water body
var main_ocean_body := -1


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	rng.seed = SEED
	noise.seed = SEED
	noise.frequency = 0.06
	noise.fractal_octaves = 2
	geo = Geo.new(MAP_WIDTH)
	W = geo.width
	H = geo.height
	_grid_w = W / GRID + 1
	_log("Map %d x %d" % [W, H])
	_setup_rows()
	_rasterize_countries()
	_rasterize_geography()
	_rasterize_rivers()
	_rasterize_divisions()
	_rasterize_marine()
	_log("Rasterised countries, lakes, geography, rivers, seas and %d divisions" % (units.size() - 1))
	_build_zones()
	_mark_wastelands()
	_compute_zone_density()
	_compute_seed_boost()
	_fill_division_gaps()
	_log("Zones, wastelands and division gaps done")
	_collect_unit_stats()
	_build_groups()
	_log("Province groups built from divisions (%d)" % groups.size())
	_place_seeds()
	_log("Seeds placed: %d" % seed_px.size())
	_grow_provinces()
	_label_wastelands()
	_log("Provinces grown; %d wastelands" % waste_count)
	_build_seas()
	_log("Sea tiles: %d" % sea_count)
	var provinces := _collect_provinces()
	_log("Province statistics collected")
	_add_straits(provinces)
	_attach_places(provinces)
	_assign_owners(provinces)
	_assign_names(provinces)
	_assign_population(provinces)
	var countries := _build_countries(provinces)
	_log("Politics, names and population assigned")
	_assign_land(provinces)
	_log("Climate, topography and vegetation assigned")
	_assign_goods(provinces)
	_log("Goods, deposits and 1590 buildings assigned")
	_write_outputs(provinces, countries)
	_log("Outputs written")
	_report(provinces, countries)
	quit()


func _log(msg: String) -> void:
	print("[%6.1fs] %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, msg])


func _lon(x: int) -> float:
	var lon := col_lon[x]
	return lon - 360.0 if lon > 180.0 else lon


func _land(p: int) -> bool:
	return adm[p] != 0 and waste[p] == Waste.NONE


# --- 1. Rasterisation ---------------------------------------------------------

func _setup_rows() -> void:
	row_lat.resize(H)
	row_area.resize(H)
	for y in H:
		row_lat[y] = geo.y_to_lat(y + 0.5)
		row_area[y] = geo.pixel_area_km2(y)
	col_lon.resize(W)
	for x in W:
		col_lon[x] = geo.x_to_lon(x + 0.5)


func _rasterize_countries() -> void:
	adm.resize(W * H)
	adm.fill(0)
	var features := Geo.load_features(SRC + "ne_50m_admin_0_countries.geojson")
	for f in features:
		adm_codes.append(f.props.ADM0_A3)
		geo.fill_polygons(adm, f.polygons, adm_codes.size() - 1)
	# Island states smaller than a pixel (e.g. the Maldives) get a small stamp so
	# they exist on the map.
	var counts := PackedInt32Array()
	counts.resize(adm_codes.size())
	for p in W * H:
		counts[adm[p]] += 1
	for k in features.size():
		if counts[k + 1] > 0 or features[k].polygons.is_empty():
			continue
		var ring: PackedVector2Array = features[k].polygons[0][0]
		var c := Vector2.ZERO
		for v in ring:
			c += v
		c /= ring.size()
		var pos := geo.to_px(c.y, c.x)
		var stamp := PackedInt32Array()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var y := int(pos.y) + dy
				if y >= 0 and y < H:
					adm[y * W + posmod(int(pos.x) + dx, W)] = k + 1
					stamp.append(y * W + posmod(int(pos.x) + dx, W))
		_stamps.append({"px": stamp, "code": adm_codes[k + 1], "name": str(features[k].props.NAME)})
	for f in Geo.load_features(SRC + "ne_50m_lakes.geojson"):
		# Modern reservoirs were dry land in 1590; the IJsselmeer was the Zuiderzee.
		if f.props.get("featurecla", "") == "Reservoir" and f.props.get("name", "") != "IJsselmeer":
			continue
		geo.fill_polygons(adm, f.polygons, 0)
	for water: Array in Regions.HISTORIC_WATER:
		geo.fill_polygons(adm, [_latlon_ring(water[1])], 0)


func _rasterize_geography() -> void:
	georeg.resize(W * H)
	georeg.fill(0)
	var features := Geo.load_features(SRC + "ne_50m_geography_regions_polys.geojson")
	# Island names (groups first, single islands on top), for naming Arctic wastes.
	island.resize(W * H)
	for cla in ["Island group", "Island"]:
		for f in features:
			if f.props.FEATURECLA == cla:
				island_names.append(Regions.waste_display_name(str(f.props.NAME)))
				geo.fill_polygons(island, f.polygons, island_names.size() - 1)
	for cla in Regions.GEO_CLASS_ORDER:
		for f in features:
			if f.props.FEATURECLA != cla:
				continue
			var name := str(f.props.NAME)
			var terrain := Regions.geo_terrain(cla, name)
			if terrain == "":
				continue
			geo_terrain.append(Regions.TERRAINS.find(terrain))
			geo_seed_factor.append(Regions.TERRAIN_SEED[terrain])
			geo_names.append(name)
			geo.fill_polygons(georeg, f.polygons, geo_terrain.size() - 1)


func _rasterize_rivers() -> void:
	river.resize(W * H)
	for f in Geo.load_features(SRC + "ne_10m_rivers_lake_centerlines.geojson"):
		var rank := int(f.props.get("scalerank", 10))
		if rank > 7:
			continue
		if f.props.get("featurecla", "") != "River":
			# Centrelines through lakes and reservoirs (the Nile through Lake Nasser)
			# still mark a river valley, but aren't drawn as rivers.
			if rank <= 4:
				geo.draw_lines(river, f.lines, 2)
			continue
		geo.draw_lines(river, f.lines, 2 if rank <= 4 else 1)
		if rank <= 6:
			river_lines.append([f.lines, 255 if rank <= 3 else (190 if rank <= 5 else 130)])
	for p in W * H:
		if adm[p] == 0:
			river[p] = 0
	# Named rivers (including smaller ones) for naming provinces.
	river_id.resize(W * H)
	for f in Geo.load_features(SRC + "ne_10m_rivers_lake_centerlines.geojson"):
		var name := str(f.props.get("name", "")) if f.props.get("name") != null else ""
		if f.props.get("featurecla", "") != "River" or name == "" or int(f.props.get("scalerank", 10)) > 9:
			continue
		river_names.append(name.trim_prefix("Río ").trim_prefix("Rio ").trim_suffix(" River"))
		geo.draw_line_ids(river_id, f.lines, river_names.size() - 1)


func _rasterize_divisions() -> void:
	unit.resize(W * H)
	unit.fill(0)
	for f in Geo.load_features(SRC + "ne_10m_admin_1_states_provinces.geojson"):
		var pr: Dictionary = f.props
		var raw := str(pr.name_en) if pr.get("name_en") != null else str(pr.get("name", ""))
		if raw == "" or raw == "<null>":
			raw = str(pr.get("name", "Unnamed"))
		units.append({"name": Regions.historic_admin_name(raw), "adm0": str(pr.adm0_a3)})
		geo.fill_polygons(unit, f.polygons, units.size() - 1)
	for p in W * H:
		if adm[p] == 0:
			unit[p] = 0
	# Stamped island states are their own division.
	for st: Dictionary in _stamps:
		units.append({"name": st.name, "adm0": st.code})
		for p: int in st.px:
			unit[p] = units.size() - 1


func _rasterize_marine() -> void:
	marine.resize(W * H)
	var features := Geo.load_features(SRC + "ne_10m_geography_marine_polys.geojson")
	for cla: String in Regions.MARINE_ORDER:
		for f in features:
			if str(f.props.get("featurecla", "")).to_lower() != cla:
				continue
			var name := str(f.props.name)
			if name == name.to_upper():
				name = name.to_lower().capitalize()
			marine_names.append(name)
			geo.fill_polygons(marine, f.polygons, marine_names.size() - 1)
	for f in Geo.load_features(SRC + "ne_50m_lakes.geojson"):
		var name := str(f.props.name) if f.props.get("name") != null else ""
		if name == "" or (f.props.get("featurecla", "") == "Reservoir" and name != "IJsselmeer"):
			continue
		marine_names.append(name)
		geo.fill_polygons(marine, f.polygons, marine_names.size() - 1)
	for water: Array in Regions.HISTORIC_WATER:
		marine_names.append(water[0])
		geo.fill_polygons(marine, [_latlon_ring(water[1])], marine_names.size() - 1)
	for k in marine_names.size():
		marine_names[k] = Regions.HISTORIC_WATER_NAMES.get(marine_names[k], marine_names[k])


## A single-ring polygon from [lat, lon] points, in the (lon, lat) form fill_polygons takes.
static func _latlon_ring(points: Array) -> Array:
	var ring := PackedVector2Array()
	for pt: Array in points:
		ring.append(Vector2(pt[1], pt[0]))
	return [ring]


func _build_zones() -> void:
	zone.resize(W * H)
	zone.fill(0)
	var index := {}
	var plain_zone := PackedInt32Array()
	plain_zone.resize(adm_codes.size())
	plain_zone.fill(-1)
	var special := ["RUS", "CHN", "USA"] + Regions.EUROPEAN_ONLY
	for y in H:
		var lat := row_lat[y]
		var base := y * W
		for x in W:
			var a := adm[base + x]
			if a == 0:
				continue
			var z := plain_zone[a]
			if z < 0:
				var code := adm_codes[a]
				var key := Regions.zone_key(code, lat, _lon(x)) if code in special else code
				if not index.has(key):
					index[key] = zone_keys.size()
					zone_keys.append(key)
					zone_area.append(0.0)
				z = index[key]
				if not code in special:
					plain_zone[a] = z
			zone[base + x] = z
			zone_area[z] += row_area[y]
	zone_region.resize(zone_keys.size())
	zone_pop.resize(zone_keys.size())
	zone_seed_density.resize(zone_keys.size())
	for z in range(1, zone_keys.size()):
		var key := zone_keys[z]
		zone_region[z] = region_ids.find(Regions.zone_region(key))
		zone_pop[z] = float(Regions.POPULATION_K.get(key, 2)) * 1000.0
	var total := 0
	for r in region_ids.size():
		var quota := int(round(Regions.TOTAL_PROVINCES * Regions.REGIONS[region_ids[r]][1]))
		region_quota.append(quota)
		total += quota
	region_quota[region_ids.find("OTH")] += Regions.TOTAL_PROVINCES - total


## Province density per zone from people per km² of *habitable* land: Egypt's
## population lives on the Nile, not spread over its deserts.
func _compute_zone_density() -> void:
	var habitable := PackedFloat64Array()
	habitable.resize(zone_keys.size())
	for y in H:
		var base := y * W
		for x in W:
			var p := base + x
			if zone[p] != 0 and waste[p] == Waste.NONE:
				habitable[zone[p]] += row_area[y]
	for z in range(1, zone_keys.size()):
		# Floor the area so micro-states don't dominate the density ranking.
		var density := zone_pop[z] / maxf(habitable[z], 20000.0)
		zone_seed_density[z] = pow(maxf(density, 0.02), 0.6) * Regions.SEED_DENSITY_BOOST.get(zone_keys[z], 1.0)


# --- 2. Wastelands --------------------------------------------------------------

## Computed at half resolution (distance fields are smooth) and expanded.
func _mark_wastelands() -> void:
	var hw := W / 2
	var hh := (H + 1) / 2
	var land := PackedByteArray()
	var desert := PackedByteArray()
	var ranges := PackedByteArray()
	var tibet := PackedByteArray()
	var tundra := PackedByteArray()
	var no_river := PackedByteArray()
	for a in [land, desert, ranges, tibet, tundra, no_river]:
		a.resize(hw * hh)
	var is_desert := PackedByteArray()
	var is_range := PackedByteArray()
	var tibet_id := -1
	is_desert.resize(geo_names.size())
	is_range.resize(geo_names.size())
	for g in range(1, geo_names.size()):
		var name := geo_names[g]
		if name == "PLATEAU OF TIBET":
			tibet_id = g
		elif Regions.is_waste_range(name) and geo_terrain[g] == Regions.TERRAINS.find("mountains"):
			is_range[g] = 1
		elif Regions.is_waste_desert(name):
			is_desert[g] = 1
	for y in hh:
		for x in hw:
			var i := y * hw + x
			var src := mini(y * 2, H - 1) * W + x * 2
			land[i] = 1 if adm[src] != 0 else 0
			var g := georeg[src]
			# Impassable ranges inside deserts count as desert for depth (Ahaggar, Tibesti).
			desert[i] = 1 if is_desert[g] or is_range[g] else 0
			ranges[i] = is_range[g]
			# The plateau and the impassable ranges around it count together, so no
			# habitable sliver is left between the Kunlun and the Changtang.
			tibet[i] = 1 if g == tibet_id or is_range[g] else 0
			tundra[i] = 1 if geo_terrain[g] == Regions.TERRAINS.find("tundra") else 0
			var r := 0
			for dy in 2:
				for dx in 2:
					var q := mini(y * 2 + dy, H - 1) * W + x * 2 + dx
					r = maxi(r, river[q])
			no_river[i] = 0 if r == 2 else 1
	var d_desert := _inside_distance(desert, hw, hh)
	var d_range := _inside_distance(ranges, hw, hh)
	var d_tibet := _inside_distance(tibet, hw, hh)
	var d_tundra := _inside_distance(tundra, hw, hh)
	var d_coast := _inside_distance(land, hw, hh)
	var d_river := _inside_distance(no_river, hw, hh)

	var half := PackedByteArray()
	half.resize(hw * hh)
	var grl := adm_codes.find("GRL")
	# Depth thresholds wander with noise so wasteland edges look organic rather
	# than tracing Natural Earth's coarse region outlines.
	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = SEED + 41
	edge_noise.frequency = 0.04
	edge_noise.fractal_octaves = 3
	for y in hh:
		var lat := geo.y_to_lat(y * 2 + 1)
		for x in hw:
			var i := y * hw + x
			if land[i] == 0:
				continue
			var lon := _lon(x * 2)
			var src := mini(y * 2, H - 1) * W + x * 2
			# Chamfer distances are x3 and in half-resolution pixels.
			var coast := d_coast[i] / 3.0 * 2.0
			var river_clear := d_river[i] / 3.0 * 2.0 >= Regions.WASTE_RIVER_CLEARANCE
			var wobble := 0.55 + 0.9 * (edge_noise.get_noise_2d(x, y) * 0.5 + 0.5)
			if lat <= Regions.ANTARCTIC_WASTE_LAT:
				half[i] = Waste.ICE
			elif adm[src] == grl and coast >= 4.0:
				half[i] = Waste.ICE
			elif d_range[i] / 3.0 * 2.0 >= Regions.WASTE_RANGE_DEPTH * wobble:
				half[i] = Waste.MOUNTAIN
			elif d_desert[i] / 3.0 * 2.0 >= Regions.WASTE_DESERT_DEPTH * wobble and d_river[i] / 3.0 * 2.0 >= Regions.WASTE_RIVER_CLEARANCE \
					and coast >= Regions.WASTE_COAST_CLEARANCE:
				half[i] = Waste.MOUNTAIN if ranges[i] else Waste.DESERT
			elif d_tibet[i] / 3.0 * 2.0 >= Regions.TIBET_PLATEAU_DEPTH * wobble and river_clear:
				half[i] = Waste.MOUNTAIN
			elif d_tundra[i] / 3.0 * 2.0 >= Regions.WASTE_TUNDRA_DEPTH * wobble * 1.6 and river_clear \
					and coast >= Regions.WASTE_COAST_CLEARANCE:
				half[i] = Waste.ARCTIC
	_arctic_islands(half, land, hw, hh, grl)

	# Keep oases and outposts habitable: clear wasteland around capitals and forced points.
	var protected := PackedByteArray()
	protected.resize(hw * hh)
	_carve_routes(half, land, protected, hw, hh)
	var keep := []
	for tag: String in Politics.POLITIES:
		keep.append([Politics.POLITIES[tag][3], 26])
	for pt in Politics.FORCED_POINTS:
		keep.append([pt, 14])
	var blob := FastNoiseLite.new()
	blob.seed = SEED + 21
	blob.frequency = 0.12
	for k: Array in keep:
		var pos := geo.to_px(k[0][0], k[0][1]) * 0.5
		var r: int = k[1] / 2
		for dy in range(-r * 2, r * 2 + 1):
			for dx in range(-r * 2, r * 2 + 1):
				var x := posmod(int(pos.x) + dx, hw)
				var y := int(pos.y) + dy
				# Irregular oasis shape rather than a circle.
				var reach := r * (0.6 + 0.9 * (blob.get_noise_2d(x, y) * 0.5 + 0.5))
				if y >= 0 and y < hh and dx * dx + dy * dy <= reach * reach:
					half[y * hw + x] = Waste.NONE
					protected[y * hw + x] = 1

	_drop_small_patches(half, hw, hh, 120)
	_connect_enclaves(half, land, protected, hw, hh)
	waste.resize(W * H)
	for y in H:
		for x in W:
			var p := y * W + x
			if adm[p] != 0:
				var hi := mini(y / 2, hh - 1) * hw + mini(x / 2, hw - 1)
				var t := half[hi]
				if t == Waste.NONE and land[hi] == 0:
					# The half-res sample fell in a lake: take the waste of the
					# neighbouring cells, so lake shores inside a waste stay waste.
					for k in 4:
						var ny: int = mini(y / 2, hh - 1) + DY[k]
						if ny >= 0 and ny < hh and land[ny * hw + posmod(mini(x / 2, hw - 1) + DX[k], hw)]:
							t = maxi(t, half[ny * hw + posmod(mini(x / 2, hw - 1) + DX[k], hw)])
				waste[p] = t


## Clears wasteland along the historic routes, as a band of slightly varying width.
func _carve_routes(half: PackedByteArray, land: PackedByteArray, protected: PackedByteArray, w: int, h: int) -> void:
	var wobble := FastNoiseLite.new()
	wobble.seed = SEED + 31
	wobble.frequency = 0.05
	for route: Array in Regions.TRADE_ROUTES:
		var points: Array = route[1]
		for k in points.size() - 1:
			var a := geo.to_px(points[k][0], points[k][1]) * 0.5
			var b := geo.to_px(points[k + 1][0], points[k + 1][1]) * 0.5
			if absf(b.x - a.x) > w * 0.5:
				b.x += w if a.x > b.x else -w
			var steps := int(ceil(a.distance_to(b)))
			for t in steps + 1:
				var c := a.lerp(b, float(t) / maxi(steps, 1))
				var r := Regions.ROUTE_HALF_WIDTH * 0.5 * (0.75 + 0.5 * (wobble.get_noise_2d(c.x, c.y) * 0.5 + 0.5))
				var ri := int(ceil(r))
				for dy in range(-ri, ri + 1):
					for dx in range(-ri, ri + 1):
						if dx * dx + dy * dy > r * r:
							continue
						var y := int(c.y) + dy
						if y < 0 or y >= h:
							continue
						var i := y * w + posmod(int(c.x) + dx, w)
						if land[i]:
							half[i] = Waste.NONE
							protected[i] = 1


## Habitable land walled in by wasteland (no coast, no land link to anything
## else) must stay reachable: sizeable or inhabited pockets (oases, capitals)
## get a passable corridor cut to the nearest other land; small slivers are
## absorbed into the wasteland around them.
func _connect_enclaves(half: PackedByteArray, land: PackedByteArray, protected: PackedByteArray, w: int, h: int) -> void:
	# Only water big enough for sea tiles is an outlet; a small lake (Qinghai
	# Lake) does not make the land around it reachable.
	var outlet := _sea_water_mask(land, w, h)
	var carved := 0
	var filled := 0
	for iteration in 40:
		var comp := PackedInt32Array()
		comp.resize(w * h)
		comp.fill(-1)
		var info := []
		var stack := PackedInt32Array()
		for start in w * h:
			if land[start] == 0 or half[start] != Waste.NONE or comp[start] != -1:
				continue
			var c := info.size()
			var d := {"pixels": PackedInt32Array(), "coastal": false, "protected": false, "walled": false}
			info.append(d)
			stack.clear()
			stack.append(start)
			comp[start] = c
			while not stack.is_empty():
				var p := stack[stack.size() - 1]
				stack.remove_at(stack.size() - 1)
				d.pixels.append(p)
				if protected[p]:
					d.protected = true
				var x := p % w
				var y := p / w
				# Edge neighbours only: land touching at a corner is not a passage.
				for k in 4:
					var ny: int = y + DY[k]
					if ny < 0 or ny >= h:
						continue
					var n: int = ny * w + (x + DX[k] + w) % w
					if land[n] == 0:
						if outlet[n]:
							d.coastal = true
					elif half[n] != Waste.NONE:
						d.walled = true
					elif comp[n] == -1:
						comp[n] = c
						stack.append(n)
		# Only pockets bordered by wasteland count: land cut off merely by lakes or
		# corner contacts (Finnish lakeland) is reachable through its provinces.
		var enclaves := info.filter(func(d): return not d.coastal and d.walled)
		if enclaves.is_empty():
			break
		for d: Dictionary in enclaves:
			if d.protected or d.pixels.size() >= 60:
				if _carve_corridor(half, land, comp, d.pixels, comp[d.pixels[0]], w, h):
					carved += 1
					continue
			if not d.protected:
				var around := _surrounding_waste(half, d.pixels, w, h)
				for p: int in d.pixels:
					half[p] = around
				filled += 1
		if iteration == 39:
			push_warning("Enclave pass did not converge")
	print("  enclaves: %d connected by corridors, %d absorbed into wasteland" % [carved, filled])


## Half-resolution mask of water belonging to bodies large enough for sea tiles.
func _sea_water_mask(land: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var body := PackedInt32Array()
	body.resize(w * h)
	body.fill(-1)
	var outlet := PackedByteArray()
	outlet.resize(w * h)
	var stack := PackedInt32Array()
	var members := PackedInt32Array()
	for start in w * h:
		if land[start] or body[start] != -1:
			continue
		stack.clear()
		members.clear()
		stack.append(start)
		body[start] = start
		var area := 0.0
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			members.append(p)
			area += row_area[mini((p / w) * 2, H - 1)] * 4.0
			var x := p % w
			var y := p / w
			for k in 8:
				var ny: int = y + DY[k]
				if ny < 0 or ny >= h:
					continue
				var n: int = ny * w + (x + DX[k] + w) % w
				if not land[n] and body[n] == -1:
					body[n] = start
					stack.append(n)
		if area >= Regions.MIN_SEA_BODY_KM2:
			for p in members:
				outlet[p] = 1
	return outlet


## Shortest path through wasteland from an enclave to other habitable land,
## cleared two pixels wide.
func _carve_corridor(half: PackedByteArray, land: PackedByteArray, comp: PackedInt32Array, pixels: PackedInt32Array,
		c: int, w: int, h: int) -> bool:
	var parent := {}
	var queue := PackedInt32Array()
	for p in pixels:
		parent[p] = -1
		queue.append(p)
	var head := 0
	var goal := -1
	while head < queue.size() and goal < 0:
		var p := queue[head]
		head += 1
		var x := p % w
		var y := p / w
		for k in 4:
			var ny: int = y + DY[k]
			if ny < 0 or ny >= h:
				continue
			var n: int = ny * w + (x + DX[k] + w) % w
			if land[n] == 0 or parent.has(n):
				continue
			parent[n] = p
			if half[n] == Waste.NONE and comp[n] != c:
				goal = n
				break
			queue.append(n)
	if goal < 0:
		return false
	var p: int = parent[goal]
	var step := 0
	while p >= 0 and comp[p] != c:
		var r := 3 + (step / 7) % 3  # 3..5 half-pixels: a road-width band, not a hairline
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var y := p / w + dy
				if dx * dx + dy * dy > r * r or y < 0 or y >= h:
					continue
				var n := y * w + posmod(p % w + dx, w)
				if land[n]:
					half[n] = Waste.NONE
		step += 1
		p = parent[p]
	return true


func _surrounding_waste(half: PackedByteArray, pixels: PackedInt32Array, w: int, h: int) -> int:
	var counts := {}
	for p in pixels:
		var x := p % w
		var y := p / w
		for k in 4:
			var ny: int = y + DY[k]
			if ny < 0 or ny >= h:
				continue
			var t := half[ny * w + (x + DX[k] + w) % w]
			if t != Waste.NONE:
				counts[t] = counts.get(t, 0) + 1
	var best: int = Waste.DESERT
	for t: int in counts:
		if counts[t] > counts.get(best, 0):
			best = t
	return best


## High-Arctic islands (centre north of ARCTIC_ISLAND_LAT) become wasteland
## whole, so no coast is cut by a straight line.
func _arctic_islands(half: PackedByteArray, land: PackedByteArray, w: int, h: int, greenland: int) -> void:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	var members := PackedInt32Array()
	for start in w * h:
		if not land[start] or seen[start]:
			continue
		stack.clear()
		members.clear()
		stack.append(start)
		seen[start] = 1
		var lat_sum := 0.0
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			members.append(p)
			lat_sum += row_lat[mini((p / w) * 2, H - 1)]
			var x := p % w
			var y := p / w
			for k in 8:
				var ny: int = y + DY[k]
				if ny < 0 or ny >= h:
					continue
				var n: int = ny * w + (x + DX[k] + w) % w
				if land[n] and not seen[n]:
					seen[n] = 1
					stack.append(n)
		var first := members[0]
		if adm[mini((first / w) * 2, H - 1) * W + (first % w) * 2] == greenland:
			continue  # Greenland: ice interior, habitable (Inuit) coasts
		if lat_sum / members.size() >= Regions.ARCTIC_ISLAND_LAT:
			for p in members:
				if half[p] == Waste.NONE:
					half[p] = Waste.ARCTIC


## Removes wasteland patches smaller than `min_size` half-resolution pixels.
func _drop_small_patches(mask: PackedByteArray, w: int, h: int, min_size: int) -> void:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	var members := PackedInt32Array()
	for start in w * h:
		if mask[start] == 0 or seen[start]:
			continue
		stack.clear()
		members.clear()
		stack.append(start)
		seen[start] = 1
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			members.append(p)
			var x := p % w
			var y := p / w
			for k in 8:
				var nx: int = (x + DX[k] + w) % w
				var ny: int = y + DY[k]
				if ny < 0 or ny >= h:
					continue
				var n := ny * w + nx
				if mask[n] != 0 and not seen[n]:
					seen[n] = 1
					stack.append(n)
		if members.size() < min_size:
			for p in members:
				mask[p] = 0


## Assigns every habitable land pixel to a division: gaps between the division
## and country rasters grow from neighbouring divisions; stray islands join the
## nearest division or, if remote, become sea.
func _fill_division_gaps() -> void:
	unit_all = unit.duplicate()  # keeps divisions under wastelands, for naming them
	var queue := PackedInt32Array()
	for p in W * H:
		if not _land(p):
			unit[p] = 0
		elif unit[p] != 0:
			queue.append(p)
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var x := p % W
		var y := p / W
		for k in 8:
			var ny: int = y + DY[k]
			if ny < 0 or ny >= H:
				continue
			var n: int = ny * W + (x + DX[k] + W) % W
			if unit[n] == 0 and _land(n):
				unit[n] = unit[p]
				queue.append(n)
	# Anything left is an island no division reached.
	var centres := {}
	for p in W * H:
		var u := unit[p]
		if u != 0 and not centres.has(u):
			centres[u] = p
	var dropped := 0
	var cache := {}
	for p in W * H:
		if unit[p] != 0 or not _land(p):
			continue
		var key := (p / W / 32) * 4096 + (p % W) / 32
		if not cache.has(key):
			var best := 0
			var best_d := 600.0
			var lat := row_lat[p / W]
			var lon := _lon(p % W)
			for u: int in centres:
				var c: int = centres[u]
				var d := Geo.haversine_km(lat, lon, row_lat[c / W], _lon(c % W))
				if d < best_d:
					best_d = d
					best = u
			cache[key] = best
		unit[p] = cache[key]
		if unit[p] == 0:
			var cap := _capital_near(p, 8)
			if cap != "":
				# A remote island that is some polity's seat becomes its own division.
				units.append({"name": Politics.POLITIES[cap][0], "adm0": adm_codes[adm[p]], "owner": cap})
				cache[key] = units.size() - 1
				unit[p] = cache[key]
				continue
			adm[p] = 0
			zone[p] = 0
			dropped += 1
	print("  %d stray island pixels dropped" % dropped)


## The polity whose capital lies within `radius` pixels of p, or "".
func _capital_near(p: int, radius: int) -> String:
	for tag: String in Politics.POLITIES:
		var cap: Array = Politics.POLITIES[tag][3]
		var pos := geo.to_px(cap[0], cap[1])
		var dx := absf(pos.x - p % W)
		dx = minf(dx, W - dx)
		if dx <= radius and absf(pos.y - p / W) <= radius:
			return tag
	return ""


# --- 3. Provinces from divisions ------------------------------------------------

func _seed_weight(p: int) -> float:
	var y := p / W
	var lat := absf(row_lat[y])
	var lat_factor := 0.35 if lat > 66.0 else (0.7 if lat > 60.0 else 1.0)
	var boost := seed_boost[(y / BOOST_CELL) * _boost_w + (p - y * W) / BOOST_CELL]
	return row_area[y] * zone_seed_density[zone[p]] * geo_seed_factor[georeg[p]] * lat_factor * boost


## Regions.SEED_BOOSTS per coarse cell, judged by the country under its centre.
func _compute_seed_boost() -> void:
	_boost_w = (W + BOOST_CELL - 1) / BOOST_CELL
	var bh := (H + BOOST_CELL - 1) / BOOST_CELL
	seed_boost.resize(_boost_w * bh)
	seed_boost.fill(1.0)
	for cy in bh:
		var y := mini(cy * BOOST_CELL + BOOST_CELL / 2, H - 1)
		var lat := row_lat[y]
		for cx in _boost_w:
			var x := mini(cx * BOOST_CELL + BOOST_CELL / 2, W - 1)
			var a := adm[y * W + x]
			if a == 0:
				continue
			var code := adm_codes[a]
			for b: Array in Regions.SEED_BOOSTS:
				if code == b[0] and lat >= b[1] and lat <= b[2]:
					var lon := _lon(x)
					if lon >= b[3] and lon <= b[4]:
						seed_boost[cy * _boost_w + cx] = b[5]


func _collect_unit_stats() -> void:
	var nr := region_ids.size()
	for u in range(1, units.size()):
		var d: Dictionary = units[u]
		d.px = 0
		d.weight = 0.0
		d.sx = 0.0
		d.sy = 0.0
		d.adj = {}
		d.regions = PackedInt32Array()
		d.regions.resize(nr)
	for y in H:
		var base := y * W
		for x in W:
			var p := base + x
			var u := unit[p]
			if u == 0:
				continue
			var d: Dictionary = units[u]
			d.px += 1
			d.weight += _seed_weight(p)
			d.sx += x
			d.sy += y
			d.regions[zone_region[zone[p]]] += 1
			var right := unit[p + 1] if x < W - 1 else unit[base]
			if right != 0 and right != u:
				_count_border(u, right)
			if y < H - 1:
				var down := unit[p + W]
				if down != 0 and down != u:
					_count_border(u, down)
	for u in range(1, units.size()):
		var d: Dictionary = units[u]
		if d.px == 0:
			continue
		d.cx = d.sx / d.px
		d.cy = d.sy / d.px
		var best := 0
		for r in nr:
			if d.regions[r] > d.regions[best]:
				best = r
		d.region = best


func _count_border(a: int, b: int) -> void:
	units[a].adj[b] = units[a].adj.get(b, 0) + 1
	units[b].adj[a] = units[b].adj.get(a, 0) + 1


## Groups of divisions that become one or more provinces. Divisions too small
## for a province of their own are merged into the neighbour they share the
## longest border with (preferring the same modern country), but never into a
## neighbour another polity held in 1590: merging Norway's thinly peopled
## Nordland into Swedish Norrbotten once put Sweden on the Atlantic coast.
func _build_groups() -> void:
	group_of_unit.resize(units.size())
	group_of_unit.fill(-1)
	var region_weight := PackedFloat64Array()
	region_weight.resize(region_ids.size())
	for u in range(1, units.size()):
		var d: Dictionary = units[u]
		if d.px == 0:
			continue
		region_weight[d.region] += d.weight
	for u in range(1, units.size()):
		var d: Dictionary = units[u]
		if d.px == 0:
			continue
		group_of_unit[u] = groups.size()
		groups.append({"index": groups.size(), "units": [u], "weight": d.weight, "px": d.px,
			"region": d.region, "adm0": d.adm0, "cx": d.cx, "cy": d.cy, "adj": {}, "alive": true,
			"owner": _unit_owner(d)})
	for g in groups.size():
		var u: int = groups[g].units[0]
		for v: int in units[u].adj:
			groups[g].adj[group_of_unit[v]] = units[u].adj[v]
	for g: Dictionary in groups:
		g.alloc = region_quota[g.region] * g.weight / maxf(region_weight[g.region], 1e-9)

	for r in region_ids.size():
		var limit := int(region_quota[r] * 0.92)
		var alive_count := groups.filter(func(g): return g.region == r).size()
		while true:
			var alive := groups.filter(func(g): return g.alive and g.region == r)
			alive.sort_custom(func(a, b): return a.alloc < b.alloc)
			if alive.is_empty() or (alive[0].alloc >= MIN_GROUP_ALLOCATION and alive_count <= limit):
				break
			var merged := false
			for g: Dictionary in alive:
				if not g.alive:
					continue
				if g.alloc >= MIN_GROUP_ALLOCATION and alive_count <= limit:
					break
				var target: Variant = _merge_target(g)
				if target == null:
					continue
				if OS.get_environment("WORLD_DEBUG_MERGES") != "":
					print("  merge %s/%s (%s) -> %s/%s (%s)" % [g.adm0, units[g.units[0]].name, g.owner,
						target.adm0, units[target.units[0]].name, target.owner])
				_merge_groups(target, g)
				alive_count -= 1
				merged = true
			if not merged:
				break

	# Compact and map units to final groups.
	var final: Array[Dictionary] = []
	for g: Dictionary in groups:
		if g.alive:
			g.index = final.size()
			final.append(g)
	for g: Dictionary in final:
		for u: int in g.units:
			group_of_unit[u] = g.index
	groups = final
	gpx.resize(W * H)
	for p in W * H:
		gpx[p] = group_of_unit[unit[p]] if unit[p] != 0 else -1


## Who held a division's centre on 1 January 1590 according to the ownership
## rules ("" = uncolonised), used to keep merges within one polity.
func _unit_owner(d: Dictionary) -> String:
	if d.has("owner"):
		return d.owner
	var lat := geo.y_to_lat(d.cy)
	var lon := geo.x_to_lon(d.cx)
	if d.adm0 in Regions.EUROPEAN_ONLY and not Regions.in_europe_box(lat, lon):
		return ""
	var rule: Variant = Politics.RULES.get(d.adm0, "")
	var owner := _apply_rule(rule, lat, lon)
	if owner == "" and rule is Array and Politics.is_settled(d.adm0, d.name):
		owner = _nearest_claim(rule, lat, lon)
	return owner


## Groups held by different polities in 1590 never merge; uncolonised land
## may join anything.
static func _same_polity(a: Dictionary, b: Dictionary) -> bool:
	return a.owner == "" or b.owner == "" or a.owner == b.owner


func _merge_target(g: Dictionary) -> Variant:
	var best: Variant = null
	var best_score := -INF
	for k: int in g.adj:
		var o: Dictionary = groups[k]
		if not o.alive or o.region != g.region or o.index == g.index or not _same_polity(o, g):
			continue
		var score: float = g.adj[k] * (4.0 if o.adm0 == g.adm0 else 1.0) / (o.alloc + 0.3)
		if score > best_score:
			best_score = score
			best = o
	if best != null:
		return best
	# Islands without land neighbours: the nearest group of the region, if close.
	var lat := geo.y_to_lat(g.cy)
	var lon := geo.x_to_lon(g.cx)
	var best_d := 450.0
	for o: Dictionary in groups:
		if not o.alive or o.region != g.region or o.index == g.index or not _same_polity(o, g):
			continue
		var d := Geo.haversine_km(lat, lon, geo.y_to_lat(o.cy), geo.x_to_lon(o.cx))
		if d < best_d:
			best_d = d
			best = o
	return best


func _merge_groups(into: Dictionary, g: Dictionary) -> void:
	var total_px: float = into.px + g.px
	into.cx = (into.cx * into.px + g.cx * g.px) / total_px
	into.cy = (into.cy * into.px + g.cy * g.px) / total_px
	into.px += g.px
	into.weight += g.weight
	into.alloc += g.alloc
	if into.owner == "":
		into.owner = g.owner
	into.units.append_array(g.units)
	var into_index: int = into.index
	var g_index: int = g.index
	for u: int in g.units:
		group_of_unit[u] = into_index
	for k: int in g.adj:
		if k == into_index:
			continue
		into.adj[k] = into.adj.get(k, 0) + g.adj[k]
		var o: Dictionary = groups[k]
		o.adj[into_index] = o.adj.get(into_index, 0) + o.adj.get(g_index, 0)
		o.adj.erase(g_index)
	into.adj.erase(g_index)
	g.alive = false


func _grid_key(x: int, y: int) -> int:
	return (y / GRID) * _grid_w + x / GRID


func _nearest_seed_px(x: int, y: int, radius: float) -> float:
	var r := int(ceil(radius / GRID))
	var gx := x / GRID
	var gy := y / GRID
	var best := INF
	for cy in range(gy - r, gy + r + 1):
		for cx in range(gx - r, gx + r + 1):
			if cx < 0 or cy < 0:
				continue
			var key := cy * _grid_w + cx
			if not _grid.has(key):
				continue
			for s in _grid[key]:
				var sp := seed_px[s]
				var dx := float(sp % W - x)
				var dy := float(sp / W - y)
				best = minf(best, dx * dx + dy * dy)
	return sqrt(best)


func _add_seed(p: int, capital := "") -> bool:
	var x := p % W
	var y := p / W
	if _nearest_seed_px(x, y, 3.0) <= 3.0:
		return false
	var s := seed_px.size()
	seed_px.append(p)
	seed_group.append(gpx[p])
	seed_capital.append(capital)
	var key := _grid_key(x, y)
	if not _grid.has(key):
		_grid[key] = PackedInt32Array()
	_grid[key].append(s)
	return true


func _snap_to_land(lat: float, lon: float, radius := 10) -> int:
	var pos := geo.to_px(lat, lon)
	var cx := int(pos.x)
	var cy := int(pos.y)
	var best := -1
	var best_d := 1 << 30
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := posmod(cx + dx, W)
			var y := cy + dy
			if y < 0 or y >= H:
				continue
			var d := dx * dx + dy * dy
			if d < best_d and _land(y * W + x) and gpx[y * W + x] >= 0:
				best_d = d
				best = y * W + x
	return best


func _place_seeds() -> void:
	# Capitals and outposts first: each is guaranteed its own province.
	for tag: String in Politics.POLITIES:
		var cap: Array = Politics.POLITIES[tag][3]
		var p := _snap_to_land(cap[0], cap[1])
		if p < 0 or not _add_seed(p, tag):
			push_warning("Capital of %s could not be seeded" % tag)
	for pt: Array in Politics.FORCED_POINTS:
		var p := _snap_to_land(pt[0], pt[1])
		if p >= 0:
			_add_seed(p)
	var forced := PackedInt32Array()
	forced.resize(groups.size())
	for s in seed_px.size():
		forced[seed_group[s]] += 1

	# Whole provinces per group, matching each region's quota exactly.
	for r in region_ids.size():
		var members := groups.filter(func(g): return g.region == r)
		var total := 0
		for g: Dictionary in members:
			g.minimum = maxi(1, forced[g.index])
			g.n = maxi(g.minimum, int(floor(g.alloc)))
			total += g.n
		while total < region_quota[r]:
			members.sort_custom(func(a, b): return a.alloc - a.n > b.alloc - b.n)
			members[0].n += 1
			total += 1
		while total > region_quota[r]:
			members.sort_custom(func(a, b): return a.n - a.alloc > b.n - b.alloc)
			var reduced := false
			for g: Dictionary in members:
				if g.n > g.minimum:
					g.n -= 1
					total -= 1
					reduced = true
					break
			if not reduced:
				push_error("Region %s cannot fit its quota: %d groups need at least %d provinces" % [region_ids[r], members.size(), total])
				break

	# Pixel lists per group (counting sort).
	var start := PackedInt32Array()
	start.resize(groups.size() + 1)
	for p in W * H:
		if gpx[p] >= 0:
			start[gpx[p] + 1] += 1
	for g in groups.size():
		start[g + 1] += start[g]
	var fill := start.duplicate()
	var order := PackedInt32Array()
	order.resize(start[groups.size()])
	for p in W * H:
		var g := gpx[p]
		if g >= 0:
			order[fill[g]] = p
			fill[g] += 1

	for g: Dictionary in groups:
		var need: int = g.n - forced[g.index]
		if need <= 0:
			continue
		var a := start[g.index]
		var b := start[g.index + 1]
		var w_max := 0.0
		for k in range(a, b):
			w_max = maxf(w_max, _seed_weight(order[k]))
		var mass: float = g.weight / g.n
		var placed := 0
		var factor := 0.85
		while placed < need and factor > 0.05:
			for attempt in need * 300:
				if placed >= need:
					break
				var p := order[a + rng.randi() % (b - a)]
				var w := _seed_weight(p)
				if rng.randf() * w_max > w:
					continue
				var d := factor * sqrt(mass / maxf(w, 1e-9))
				if _nearest_seed_px(p % W, p / W, d) < d:
					continue
				if _add_seed(p):
					placed += 1
			factor *= 0.8
		var guard := 0
		while placed < need and guard < 100000:
			guard += 1
			if _add_seed(order[a + rng.randi() % (b - a)]):
				placed += 1


## Multi-source Dijkstra (Dial's bucket queue) inside each group: rivers and
## mountains are expensive to cross, so provinces stop at them.
func _grow_provinces() -> void:
	var cost := PackedByteArray()
	cost.resize(W * H)
	var mountains := Regions.TERRAINS.find("mountains")
	var hills := Regions.TERRAINS.find("hills")
	for y in H:
		for x in W:
			var p := y * W + x
			if gpx[p] < 0:
				continue
			var n := clampf(noise.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 0.999)
			var t := geo_terrain[georeg[p]]
			var c: int = 2 + int(n * 2.0) + RIVER_COST[river[p]]
			c += MOUNTAIN_COST if t == mountains else (HILL_COST if t == hills else 0)
			cost[p] = c

	var dist := PackedInt32Array()
	dist.resize(W * H)
	dist.fill(0x7FFFFFFF)
	ids.resize(W * H)
	ids.fill(0)
	var buckets := []
	for k in 32:
		buckets.append(PackedInt32Array())
	for s in seed_px.size():
		ids[seed_px[s]] = s + 1
		dist[seed_px[s]] = 0
		buckets[0].append(seed_px[s])
	var cur := 0
	var idle := 0
	while idle < 32:
		var bucket: PackedInt32Array = buckets[cur & 31]
		if bucket.is_empty():
			idle += 1
			cur += 1
			continue
		idle = 0
		buckets[cur & 31] = PackedInt32Array()
		for p in bucket:
			if dist[p] != cur:
				continue
			var owner := ids[p]
			var group := gpx[p]
			var x := p % W
			var y := p / W
			for k in 8:
				var ny: int = y + DY[k]
				if ny < 0 or ny >= H:
					continue
				var n: int = ny * W + (x + DX[k] + W) % W
				if gpx[n] != group:
					continue
				var c := cost[n]
				var nd := cur + (c if k < 4 else c + (c >> 1))
				if nd < dist[n]:
					dist[n] = nd
					ids[n] = owner
					buckets[nd & 31].append(n)
		cur += 1
	province_count = seed_px.size()

	# Pieces of a group cut off from its seeds but touching other provinces by
	# land join those provinces, so no province is split by wasteland.
	var queue := PackedInt32Array()
	for p in W * H:
		if ids[p] != 0:
			queue.append(p)
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var x := p % W
		var y := p / W
		for k in 8:
			var ny: int = y + DY[k]
			if ny < 0 or ny >= H:
				continue
			var n: int = ny * W + (x + DX[k] + W) % W
			if ids[n] == 0 and gpx[n] >= 0:
				ids[n] = ids[p]
				queue.append(n)

	# What is left are islands with no seed: nearest seed of their group.
	var group_seeds := {}
	for s in seed_px.size():
		if not group_seeds.has(seed_group[s]):
			group_seeds[seed_group[s]] = []
		group_seeds[seed_group[s]].append(s)
	for p in W * H:
		if ids[p] != 0 or gpx[p] < 0:
			continue
		var x := p % W
		var y := p / W
		var best := 0
		var best_d := INF
		for s: int in group_seeds.get(gpx[p], []):
			var dx := absf(seed_px[s] % W - x)
			dx = minf(dx, W - dx)
			var dy := float(seed_px[s] / W - y)
			if dx * dx + dy * dy < best_d:
				best_d = dx * dx + dy * dy
				best = s + 1
		ids[p] = best


## Wasteland areas get ids after the provinces, split by named desert/range.
func _label_wastelands() -> void:
	var key := PackedInt32Array()
	key.resize(W * H)
	for p in W * H:
		if adm[p] != 0 and waste[p] != Waste.NONE:
			var g := georeg[p]
			key[p] = g + 1 if (waste[p] == Waste.DESERT or waste[p] == Waste.MOUNTAIN) and g != 0 else 100000 + waste[p]
	var comp := PackedInt32Array()
	comp.resize(W * H)
	comp.fill(-1)
	var sizes := PackedInt32Array()
	var stack := PackedInt32Array()
	for start in W * H:
		if key[start] == 0 or comp[start] != -1:
			continue
		var c := sizes.size()
		sizes.append(0)
		stack.clear()
		stack.append(start)
		comp[start] = c
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			sizes[c] += 1
			var x := p % W
			var y := p / W
			for k in 8:
				var ny: int = y + DY[k]
				if ny < 0 or ny >= H:
					continue
				var n: int = ny * W + (x + DX[k] + W) % W
				if key[n] == key[p] and comp[n] == -1:
					comp[n] = c
					stack.append(n)
	# Small pieces join the waste they touch most; ids for the rest.
	var merge_into := PackedInt32Array()
	merge_into.resize(sizes.size())
	for c in sizes.size():
		merge_into[c] = c
	var contact := {}
	for p in W * H:
		var c := comp[p]
		if c < 0 or sizes[c] >= 400:
			continue
		var x := p % W
		var y := p / W
		for k in 4:
			var ny: int = y + DY[k]
			if ny < 0 or ny >= H:
				continue
			var o: int = comp[ny * W + (x + DX[k] + W) % W]
			if o >= 0 and o != c and sizes[o] >= 400:
				var ck := c * 100000 + o
				contact[ck] = contact.get(ck, 0) + 1
	var best_contact := {}
	for ck: int in contact:
		var c := ck / 100000
		if contact[ck] > best_contact.get(c, [0, -1])[0]:
			best_contact[c] = [contact[ck], ck % 100000]
	for c: int in best_contact:
		merge_into[c] = best_contact[c][1]
	var id_of := {}
	for c in sizes.size():
		var root := merge_into[c]
		if not id_of.has(root):
			id_of[root] = province_count + id_of.size() + 1
	waste_count = id_of.size()
	for p in W * H:
		if comp[p] >= 0:
			ids[p] = id_of[merge_into[comp[p]]]


# --- 4. Sea tiles -----------------------------------------------------------------

## Splits each large water body into sea tiles: Poisson-spaced seeds (denser
## along coasts), grown across water only, so a tile never crosses land.
func _build_seas() -> void:
	var water := PackedByteArray()
	water.resize(W * H)
	for p in W * H:
		water[p] = 1 if adm[p] == 0 else 0
	# Water bodies, 8-connected and wrapping east-west.
	var body := PackedInt32Array()
	body.resize(W * H)
	body.fill(-1)
	var body_area := PackedFloat64Array()
	var stack := PackedInt32Array()
	for start in W * H:
		if water[start] == 0 or body[start] != -1:
			continue
		var b := body_area.size()
		body_area.append(0.0)
		stack.clear()
		stack.append(start)
		body[start] = b
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var x := p % W
			var y := p / W
			body_area[b] += row_area[y]
			for k in 8:
				var ny: int = y + DY[k]
				if ny < 0 or ny >= H:
					continue
				var n: int = ny * W + (x + DX[k] + W) % W
				if water[n] and body[n] == -1:
					body[n] = b
					stack.append(n)
	var eligible := PackedByteArray()
	eligible.resize(body_area.size())
	for b in body_area.size():
		eligible[b] = 1 if body_area[b] >= Regions.MIN_SEA_BODY_KM2 else 0
		if main_ocean_body < 0 or body_area[b] > body_area[main_ocean_body]:
			main_ocean_body = b
	var coast_d := _inside_distance(water, W, H)

	# Seeds from a shuffled jittered lattice, kept apart by the local spacing.
	var cell := 24
	var candidates := PackedInt32Array()
	for cy in range(0, H, cell):
		for cx in range(0, W, cell):
			var x := mini(cx + rng.randi() % cell, W - 1)
			var y := mini(cy + rng.randi() % cell, H - 1)
			candidates.append(y * W + x)
	for k in range(candidates.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp := candidates[k]
		candidates[k] = candidates[j]
		candidates[j] = tmp
	var seeds := PackedInt32Array()
	var grid := {}
	var gcell := 64
	var gw := W / gcell + 1
	var seeded := {}
	# Curated narrow seas first; the random seeds then keep their distance.
	for a: Array in Regions.SEA_ANCHORS:
		var pos := geo.to_px(a[0], a[1])
		var p := int(pos.y) * W + posmod(int(pos.x), W)
		if pos.y < 0 or pos.y >= H or not water[p] or not eligible[body[p]]:
			push_warning("sea anchor %s is not on open water" % [a])
			continue
		seeds.append(p)
		seeded[body[p]] = true
		var key := (p / W / gcell) * gw + (p % W) / gcell
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		grid[key].append(p)
	for p in candidates:
		if not water[p] or not eligible[body[p]]:
			continue
		var x := p % W
		var y := p / W
		var km_per_px := 360.0 / W * 111.32 * cos(deg_to_rad(row_lat[y]))
		var shore_km := coast_d[p] / 3.0 * km_per_px
		var spacing := lerpf(Regions.SEA_COASTAL_KM, Regions.SEA_OPEN_KM,
			smoothstep(0.0, Regions.SEA_OPEN_DISTANCE_KM, shore_km)) / km_per_px
		var r := int(ceil(spacing / gcell))
		var clear := true
		for gy in range(y / gcell - r, y / gcell + r + 1):
			for gx in range(x / gcell - r, x / gcell + r + 1):
				var key := gy * gw + posmod(gx, gw)
				if not grid.has(key):
					continue
				for q: int in grid[key]:
					var dx := absf(q % W - x)
					dx = minf(dx, W - dx)
					var dy := float(q / W - y)
					if dx * dx + dy * dy < spacing * spacing:
						clear = false
						break
				if not clear:
					break
			if not clear:
				break
		if not clear:
			continue
		seeds.append(p)
		seeded[body[p]] = true
		var key := (y / gcell) * gw + x / gcell
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		grid[key].append(p)
	# Every eligible body gets at least one tile, seeded at its most open water.
	var deepest := {}
	for p in W * H:
		var b := body[p]
		if b >= 0 and eligible[b] and not seeded.has(b) and coast_d[p] > deepest.get(b, [-1, 0])[0]:
			deepest[b] = [coast_d[p], p]
	for b: int in deepest:
		seeds.append(deepest[b][1])

	# Grow tiles across water (Dijkstra, slightly noisy costs).
	var base := province_count + waste_count
	var dist := PackedInt32Array()
	dist.resize(W * H)
	dist.fill(0x7FFFFFFF)
	var buckets := []
	for k in 8:
		buckets.append(PackedInt32Array())
	for s in seeds.size():
		ids[seeds[s]] = base + s + 1
		dist[seeds[s]] = 0
		buckets[0].append(seeds[s])
		sea_body.append(body[seeds[s]])
	var cur := 0
	var idle := 0
	while idle < 8:
		var bucket: PackedInt32Array = buckets[cur & 7]
		if bucket.is_empty():
			idle += 1
			cur += 1
			continue
		idle = 0
		buckets[cur & 7] = PackedInt32Array()
		for p in bucket:
			if dist[p] != cur:
				continue
			var x := p % W
			var y := p / W
			for k in 8:
				var ny: int = y + DY[k]
				if ny < 0 or ny >= H:
					continue
				var n: int = ny * W + (x + DX[k] + W) % W
				if not water[n] or not eligible[body[n]]:
					continue
				var c := 2 + int((noise.get_noise_2d(n % W, n / W) * 0.5 + 0.5) * 1.99)
				var nd := cur + (c if k < 4 else c + (c >> 1))
				if nd < dist[n]:
					dist[n] = nd
					ids[n] = ids[p]
					buckets[nd & 7].append(n)
		cur += 1
	sea_count = seeds.size()


# --- 5. Province data -----------------------------------------------------------

func _collect_provinces() -> Array:
	var total := province_count + waste_count + sea_count
	var tn := Regions.TERRAINS.size() + 1
	var provinces := []
	for v in total + 1:
		provinces.append({"id": v, "px": 0, "area": 0.0, "coastal": false, "neighbours": {},
			"min_x": W, "min_y": H, "max_x": 0, "max_y": 0,
			"wasteland": v > province_count and v <= province_count + waste_count,
			"sea": v > province_count + waste_count, "seas": {}, "coasts": {}, "marine_counts": {},
			"geo_counts": {}, "unit_counts": {}, "river_counts": {}, "waste_type": 0, "waste_types": {},
			"island_counts": {}, "great_river_px": 0, "samples": PackedInt32Array()})
	var tcount := PackedInt32Array()
	tcount.resize((total + 1) * tn)
	for y in H:
		var base := y * W
		for x in W:
			var i := base + x
			var v := ids[i]
			_link(provinces, v, ids[i + 1] if x < W - 1 else ids[base])  # wraps east-west
			if y < H - 1:
				_link(provinces, v, ids[i + W])
			if v == 0:
				continue
			var p: Dictionary = provinces[v]
			p.px += 1
			p.area += row_area[y]
			p.min_x = mini(p.min_x, x)
			p.max_x = maxi(p.max_x, x)
			p.min_y = mini(p.min_y, y)
			p.max_y = maxi(p.max_y, y)
			tcount[v * tn + geo_terrain[georeg[i]] + 1] += 1
			if p.sea:
				p.marine_counts[marine[i]] = p.marine_counts.get(marine[i], 0) + 1
				continue
			if river_id[i] != 0 and not p.wasteland:
				p.river_counts[river_id[i]] = p.river_counts.get(river_id[i], 0) + 1
			if river[i] == 2:
				p.great_river_px += 1
			if p.wasteland:
				p.waste_types[waste[i]] = p.waste_types.get(waste[i], 0) + 1
				p.island_counts[island[i]] = p.island_counts.get(island[i], 0) + 1
				p.geo_counts[georeg[i]] = p.geo_counts.get(georeg[i], 0) + 1
				p.unit_counts[unit_all[i]] = p.unit_counts.get(unit_all[i], 0) + 1

	# Points spread evenly over each land province (about OWNER_SAMPLES of
	# them), for judging its owner by majority rather than at one point.
	var skip := PackedInt32Array()
	skip.resize(total + 1)
	var seen := PackedInt32Array()
	seen.resize(total + 1)
	for v in range(1, province_count + 1):
		skip[v] = maxi(1, provinces[v].px / 9 / OWNER_SAMPLES)
	for y in range(1, H, 3):
		for x in range(1, W, 3):
			var v := ids[y * W + x]
			if v < 1 or v > province_count:
				continue
			if seen[v] % skip[v] == 0:
				provinces[v].samples.append(y * W + x)
			seen[v] += 1

	var labels := _label_points(total)
	provinces.pop_front()
	var climate_noise := FastNoiseLite.new()
	climate_noise.seed = SEED + 7
	climate_noise.frequency = 0.01
	var marsh := Regions.TERRAINS.find("marsh")
	for p: Dictionary in provinces:
		var v: int = p.id
		p.label = labels[v]
		p.marsh_share = float(tcount[v * tn + marsh + 1]) / maxf(p.px, 1.0)
		var sp: int = seed_px[v - 1] if not (p.wasteland or p.sea) else p.label[1] * W + p.label[0]
		p.seed = sp
		p.lat = row_lat[sp / W]
		p.lon = _lon(sp % W)
		p.zone = zone[sp]
		p.adm = adm_codes[adm[sp]]
		if p.sea:
			var lake: bool = sea_body[v - province_count - waste_count - 1] != main_ocean_body
			p.terrain = "lake" if lake else "sea"
			p.region = ""
			p.capital_of = ""
			continue
		if p.wasteland:
			for t: int in p.waste_types:
				if p.waste_types[t] > p.waste_types.get(p.waste_type, 0):
					p.waste_type = t
			p.region = region_ids[maxi(zone_region[zone[sp]], 0)]
			p.capital_of = ""
			p.terrain = WASTE_TERRAIN[p.waste_type]
			continue
		var g: Dictionary = groups[seed_group[v - 1]]
		p.region = region_ids[g.region]
		p.capital_of = seed_capital[v - 1]
		p.unit_name = units[unit[sp]].name
		p.group_main = units[_largest_unit(g)].name
		p.group_size = g.n
		var best_t := -1
		var best_n := 0
		for t in Regions.TERRAINS.size():
			var count := tcount[v * tn + t + 1]
			if count > best_n:
				best_n = count
				best_t = t
		if best_t == Regions.TERRAINS.find("mountains") and best_n < p.px * 0.6:
			# Partly mountainous provinces read as hills; mountain regions are broad blobs.
			best_t = Regions.TERRAINS.find("hills")
			best_n += tcount[v * tn + best_t + 1]
		if best_t >= 0 and best_n >= p.px * 0.35:
			p.terrain = Regions.TERRAINS[best_t]
		else:
			var nz := climate_noise.get_noise_2d(sp % W, sp / W) * 0.5 + 0.5
			p.terrain = Regions.climate_terrain(p.lat, p.lon, nz)
	return provinces


func _largest_unit(g: Dictionary) -> int:
	var best: int = g.units[0]
	for u: int in g.units:
		if units[u].px > units[best].px:
			best = u
	return best


## Records adjacency between two touching pixels' ids: land-land neighbours,
## sea-sea neighbours, and land-sea coasts (a province is coastal when it
## touches a sea tile; small lakes without tiles don't count).
func _link(provinces: Array, a: int, b: int) -> void:
	if a == b or a == 0 or b == 0:
		return
	var land_end := province_count
	var sea_start := province_count + waste_count
	var a_land := a <= land_end
	var b_land := b <= land_end
	var a_sea := a > sea_start
	var b_sea := b > sea_start
	if a_land and b_land:
		provinces[a].neighbours[b] = true
		provinces[b].neighbours[a] = true
	elif a_sea and b_sea:
		provinces[a].neighbours[b] = true
		provinces[b].neighbours[a] = true
	elif a_land and b_sea:
		_link_coast(provinces[a], provinces[b])
	elif a_sea and b_land:
		_link_coast(provinces[b], provinces[a])


func _link_coast(land: Dictionary, sea: Dictionary) -> void:
	land.coastal = true
	land.seas[sea.id] = land.seas.get(sea.id, 0) + 1
	sea.coasts[land.id] = sea.coasts.get(land.id, 0) + 1


## Most interior pixel of each province (chamfer distance transform).
func _label_points(n: int) -> Array:
	var dist := PackedInt32Array()
	dist.resize(W * H)
	for y in H:
		for x in W:
			var i := y * W + x
			var v := ids[i]
			var edge := x == 0 or y == 0 or x == W - 1 or y == H - 1
			if not edge:
				edge = ids[i - 1] != v or ids[i + 1] != v or ids[i - W] != v or ids[i + W] != v
			dist[i] = 0 if edge else 1 << 28
	for y in range(1, H):
		for x in range(1, W - 1):
			var i := y * W + x
			if dist[i] == 0:
				continue
			dist[i] = mini(dist[i], mini(mini(dist[i - 1] + 3, dist[i - W] + 3), mini(dist[i - W - 1] + 4, dist[i - W + 1] + 4)))
	for y in range(H - 2, -1, -1):
		for x in range(W - 2, 0, -1):
			var i := y * W + x
			if dist[i] == 0:
				continue
			dist[i] = mini(dist[i], mini(mini(dist[i + 1] + 3, dist[i + W] + 3), mini(dist[i + W + 1] + 4, dist[i + W - 1] + 4)))
	var best := PackedInt32Array()
	best.resize(n + 1)
	best.fill(-1)
	var label := []
	label.resize(n + 1)
	for i in W * H:
		var v := ids[i]
		if v != 0 and dist[i] > best[v]:
			best[v] = dist[i]
			label[v] = [i % W, i / W]
	return label


func _add_straits(provinces: Array) -> void:
	for pair: Array in Regions.STRAITS:
		var a := _snap_to_land(pair[0][0], pair[0][1], 8)
		var b := _snap_to_land(pair[1][0], pair[1][1], 8)
		if a < 0 or b < 0:
			continue
		var pa := ids[a]
		var pb := ids[b]
		if pa != 0 and pb != 0 and pa != pb and pa <= province_count and pb <= province_count:
			provinces[pa - 1].neighbours[pb] = true
			provinces[pb - 1].neighbours[pa] = true


func _assign_owners(provinces: Array) -> void:
	for p: Dictionary in provinces:
		if p.wasteland or p.sea:
			p.owner = ""
		elif p.capital_of != "":
			p.owner = p.capital_of
		elif p.adm in Regions.EUROPEAN_ONLY and not Regions.in_europe_box(p.lat, p.lon):
			p.owner = ""
		else:
			var rule: Variant = Politics.RULES.get(p.adm, "")
			if p.place != null and p.place.rank <= 6:
				# Judge a province by its main town when it has one: coastal
				# colonies (Salvador, Luanda...) sit in provinces whose centre
				# is far inland.
				p.owner = _owner_at(rule, p, p.place.lat, p.place.lon)
			else:
				# Otherwise by majority over its whole area: a seed in a far
				# corner (Chichibu for Saitama) must not decide for the rest.
				var votes := {}
				for i: int in p.samples:
					# Each point by the rules of the country it lies in (a province
					# can join islands of two modern countries, like Gotland and Saare).
					var here: String = adm_codes[adm[i]] if adm[i] > 0 else p.adm
					var tag := _owner_at(Politics.RULES.get(here, ""), p, row_lat[i / W], _lon(i % W))
					votes[tag] = votes.get(tag, 0) + 1
				var best := _owner_at(rule, p, p.lat, p.lon)  # ties and tiny provinces
				var best_n: int = votes.get(best, 0)
				for tag: String in votes:
					if votes[tag] > best_n:
						best = tag
						best_n = votes[tag]
				p.owner = best


## Points per province used to judge its owner by majority.
const OWNER_SAMPLES := 40


func _owner_at(rule: Variant, p: Dictionary, lat: float, lon: float) -> String:
	var owner := _apply_rule(rule, lat, lon)
	if owner == "" and rule is Array and Politics.is_settled(p.adm, p.unit_name):
		owner = _nearest_claim(rule, lat, lon)
	return owner


## The claimant with the nearest anchor, ignoring reach radii. Small-radius
## claims (trading posts and enclaves such as Macau or Goa) never qualify: a
## settled Ming province must not fall to a Portuguese factory 300 km away.
const MIN_FALLBACK_RADIUS_KM := 100.0


static func _nearest_claim(rule: Array, lat: float, lon: float) -> String:
	var best_tag: String = rule[0]
	var best_d := INF
	for k in range(1, rule.size()):
		var claim: Array = rule[k]
		var radius: float = claim[1]
		if claim[0] == "" or (radius > 0.0 and radius < MIN_FALLBACK_RADIUS_KM):
			continue
		for a: Array in claim[2]:
			var d := Geo.haversine_km(lat, lon, a[0], a[1])
			if d < best_d:
				best_d = d
				best_tag = claim[0]
	return best_tag


static func _apply_rule(rule: Variant, lat: float, lon: float) -> String:
	if rule is String:
		return rule
	var best_tag: String = rule[0]
	var best_d := INF
	for k in range(1, rule.size()):
		var claim: Array = rule[k]
		var radius: float = claim[1]
		for a: Array in claim[2]:
			var d := Geo.haversine_km(lat, lon, a[0], a[1])
			if (radius <= 0.0 or d <= radius) and d < best_d:
				best_d = d
				best_tag = claim[0]
	return best_tag


## Names come from real geography: the province's division (county,
## department, state...), and the major town it contains; split divisions use
## their towns, then directional forms of the division name.
func _attach_places(provinces: Array) -> void:
	for p: Dictionary in provinces:
		p.places = []
	for f in Geo.load_features(SRC + "ne_10m_populated_places_simple.geojson"):
		var pr: Dictionary = f.props
		var name := str(pr.name)
		var place := {"name": Regions.HISTORIC_NAMES.get(name, name), "rank": int(pr.scalerank),
			"pop": float(pr.pop_max), "lat": float(pr.latitude), "lon": float(pr.longitude)}
		var pos := geo.to_px(place.lat, place.lon)
		if pos.y < 0 or pos.y >= H:
			continue
		for r in 4:
			var q := _snap_to_land(place.lat, place.lon, r)
			if q >= 0:
				var v := ids[q]
				if v > 0 and v <= province_count:
					provinces[v - 1].places.append(place)
				break
	for p: Dictionary in provinces:
		p.places.sort_custom(func(a, b): return a.rank < b.rank or (a.rank == b.rank and a.pop > b.pop))
		p.place = p.places[0] if not p.places.is_empty() else null


## Names come from real geography: the province's division (county,
## department, state...), and the major town it contains; split divisions use
## their towns, then compass forms of the division name.
func _assign_names(provinces: Array) -> void:
	var order := provinces.filter(func(p): return not p.wasteland and not p.sea)
	order.sort_custom(func(a, b): return _place_rank(a) < _place_rank(b))
	var used := {}
	for p: Dictionary in order:
		var candidates: Array[String] = []
		var major: bool = p.place != null and p.place.rank <= 3 and p.owner != ""
		if major:
			candidates.append(p.place.name)
		if p.group_size == 1:
			candidates.append(p.group_main)
		else:
			candidates.append(p.unit_name)
		for place in p.places:
			candidates.append(place.name)
		# Then the rivers running through it, longest stretch first (Isar, Lech, Main...).
		var rivers: Array = p.river_counts.keys().filter(func(r): return p.river_counts[r] >= 6)
		rivers.sort_custom(func(a, b): return p.river_counts[a] > p.river_counts[b])
		for r: int in rivers:
			candidates.append(river_names[r])
		var u: Dictionary = units[unit[p.seed]]
		p.name = _unique_name(candidates, p, used, Vector2(u.cx, u.cy))

	_name_seas(provinces)

	var waste_used := {}
	for p: Dictionary in provinces:
		if not p.wasteland:
			continue
		var best_g := 0
		for g: int in p.geo_counts:
			if g != 0 and p.geo_counts[g] > p.geo_counts.get(best_g, 0):
				best_g = g
		var best_u := 0
		for u: int in p.unit_counts:
			if u != 0 and p.unit_counts[u] > p.unit_counts.get(best_u, 0):
				best_u = u
		var best_i := 0
		for isl: int in p.island_counts:
			if isl != 0 and p.island_counts[isl] > p.island_counts.get(best_i, 0):
				best_i = isl
		var base: String
		if best_i != 0 and p.waste_type == Waste.ARCTIC:
			base = island_names[best_i]
		elif best_g != 0 and p.waste_type in [Waste.DESERT, Waste.MOUNTAIN, Waste.ARCTIC]:
			base = Regions.waste_display_name(geo_names[best_g])
		elif p.waste_type == Waste.ICE:
			base = "Greenland Ice Sheet" if p.lat > 0.0 else "Antarctic Islands"
		elif best_u != 0:
			base = "%s Wastes" % units[best_u].name
		else:
			base = "Arctic Wastes"
		p.name = _unique_name([base] as Array[String], p, waste_used, Vector2(p.label[0], p.label[1]))


## Sea tiles take the name of the sea, gulf, bay or strait they mostly cover
## (the tile covering most of it gets the plain name); further tiles of the
## same sea become "Coast of <province>" when coastal, or a directional form
## ("Western North Atlantic Ocean") in open water.
func _name_seas(provinces: Array) -> void:
	var seas := provinces.filter(func(p): return p.sea)
	for p: Dictionary in seas:
		var best := 0
		for m: int in p.marine_counts:
			if m != 0 and p.marine_counts[m] > p.marine_counts.get(best, 0):
				best = m
		p.marine = best
		p.marine_share = p.marine_counts.get(best, 0)
	seas.sort_custom(func(a, b): return a.marine_share > b.marine_share)
	var used := {}
	for p: Dictionary in seas:
		var base: String = marine_names[p.marine] if p.marine != 0 else ("Lake" if p.terrain == "lake" else "Open Sea")
		if not used.has(base):
			used[base] = p
			p.name = base
			continue
		var coast := 0
		for c: int in p.coasts:
			if coast == 0 or p.coasts[c] > p.coasts[coast]:
				coast = c
		if coast != 0:
			var name := "Coast of %s" % provinces[coast - 1].name
			if not used.has(name):
				used[name] = p
				p.name = name
				continue
		var first: Dictionary = used[base]
		var dx: float = p.label[0] - first.label[0]
		dx -= W * round(dx / W)
		var dy: float = p.label[1] - first.label[1]
		var forms := ["Western", "Eastern"] if absf(dx) > absf(dy) else ["Northern", "Southern"]
		if dx > 0 and absf(dx) > absf(dy):
			forms.reverse()
		if dy > 0 and absf(dy) >= absf(dx):
			forms.reverse()
		forms.append_array(["Outer", "Central", "Inner"])
		p.name = ""
		for f: String in forms:
			var name := "%s %s" % [f, base]
			if not used.has(name):
				used[name] = p
				p.name = name
				break
		if p.name == "":
			var k := 2
			while used.has("%s %d" % [base, k]):
				k += 1
			p.name = "%s %d" % [base, k]
			used[p.name] = p

	# Every sizeable named sea, gulf or strait gets at least one tile: a narrow
	# one (the English Channel) can be outvoted in every tile it touches. Give
	# its name to the tile covering most of it, if that tile only has a
	# secondary name ("Coast of ...", "Western ...").
	var totals := {}
	for p: Dictionary in seas:
		for m: int in p.marine_counts:
			if m != 0:
				totals[m] = totals.get(m, 0) + p.marine_counts[m]
	var features: Array = totals.keys()
	features.sort_custom(func(a, b): return totals[a] > totals[b])
	for m: int in features:
		var name: String = marine_names[m]
		if used.has(name) or totals[m] < 150:
			continue
		var best: Dictionary = {}
		for p: Dictionary in seas:
			if p.marine_counts.get(m, 0) > (best.marine_counts.get(m, 0) if not best.is_empty() else 0) \
					and p.name != marine_names[p.marine]:
				best = p
		if not best.is_empty():
			used.erase(best.name)
			best.name = name
			used[name] = best


static func _place_rank(p: Dictionary) -> float:
	return 100.0 if p.place == null else p.place.rank - p.place.pop / 1e8


const QUALIFIERS := ["North", "South", "East", "West", "Upper", "Lower", "Inner", "Outer", "Greater",
	"Lesser", "Central", "Northern", "Southern", "Eastern", "Western", "Northeast", "Northwest", "Southeast",
	"Southwest"]
const ROMAN := ["II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]


## First unused candidate; otherwise the best candidate qualified by where the
## province lies relative to its division's centre ("Upper Bavaria", "West
## Swabia"); Roman numerals only as a last resort.
func _unique_name(candidates: Array[String], p: Dictionary, used: Dictionary, center: Vector2) -> String:
	for name in candidates:
		if not used.has(name):
			used[name] = p
			return name
	var base := candidates[0]
	var prefixes: Array[String] = []
	if not base.split(" ")[0] in QUALIFIERS:
		var offset := Vector2(p.label[0], p.label[1]) - center
		offset.x -= W * round(offset.x / W)
		if offset.length() < 6.0:
			prefixes.append("Central")
		var ns := "North" if offset.y < 0 else "South"
		var ew := "East" if offset.x > 0 else "West"
		if absf(offset.x) > absf(offset.y):
			prefixes.append_array([ew, ns])
		else:
			prefixes.append_array([ns, ew])
		prefixes.append("Upper" if offset.y < 0 else "Lower")
		# Eight-way compass forms, nearest direction first ("Northeast Bavaria").
		var diagonals := {"Northeast": Vector2(1, -1), "Northwest": Vector2(-1, -1), "Southeast": Vector2(1, 1),
			"Southwest": Vector2(-1, 1)}
		var by_angle: Array = diagonals.keys()
		by_angle.sort_custom(func(a, b): return offset.angle_to(diagonals[a]) ** 2 < offset.angle_to(diagonals[b]) ** 2)
		prefixes.append_array(by_angle)
		prefixes.append_array(["Central", "Inner", "Outer"])
	for prefix in prefixes:
		var name := "%s %s" % [prefix, base]
		if not used.has(name):
			used[name] = p
			return name
	for numeral in ROMAN:
		var name := "%s %s" % [base, numeral]
		if not used.has(name):
			used[name] = p
			return name
	var k := ROMAN.size() + 2
	while used.has("%s %d" % [base, k]):
		k += 1
	used["%s %d" % [base, k]] = p
	return "%s %d" % [base, k]


func _assign_population(provinces: Array) -> void:
	var zone_weight := {}
	for p: Dictionary in provinces:
		if p.wasteland or p.sea:
			continue
		var w: float = p.area * Regions.TERRAIN_POP[p.terrain]
		if p.coastal:
			w *= 1.2
		if p.capital_of != "":
			w *= 3.0
		if p.place != null and p.place.pop > 50000.0:
			w *= 1.0 + 0.15 * log(p.place.pop / 50000.0) / log(10.0)
		# Herders and forest peoples (tribal polities) live far more thinly than
		# farmers in the same zone: the Tümed plain is not the North China Plain.
		if p.owner != "" and Politics.POLITIES.get(p.owner, ["", ""])[1] == "tribal":
			w *= Regions.TRIBAL_POP
		p.pop_weight = w
		zone_weight[p.zone] = zone_weight.get(p.zone, 0.0) + w
	for p: Dictionary in provinces:
		if p.wasteland or p.sea:
			continue
		var share: float = p.pop_weight / maxf(zone_weight[p.zone], 1e-9)
		p.population = maxi(100, int(round(zone_pop[p.zone] * share / 100.0)) * 100)
		var density: float = p.population / maxf(p.area, 1.0)
		var dev := int(round(1.5 + 2.0 * log(density + 1.0) / log(10.0)))
		p.development = clampi(dev + (2 if p.capital_of != "" else 0), 1, 10)


## EU5-style land: climate (Köppen-Geiger), topography (ETOPO1 elevation and
## ruggedness), vegetation (climate + landscape + 1590 settlement). Runs after
## geometry and population, and draws nothing from `rng`, so it never moves a
## province.
func _assign_land(provinces: Array) -> void:
	var land := Land1590.new()
	if not land.load_data(province_count + waste_count + sea_count + 1):
		for e in land.errors:
			push_error(e)
		return
	for y in range(0, H, 2):
		var lat := geo.y_to_lat(y + 0.5)
		var base := y * W
		for x in range(0, W, 2):
			var v := ids[base + x]
			if v != 0 and v <= province_count + waste_count:
				land.sample(v, lat, geo.x_to_lon(x + 0.5))
	for p: Dictionary in provinces:
		if p.sea:
			continue
		if not land.has_samples(p.id):  # tiny islands and city states
			land.sample(p.id, p.lat, p.lon)
		var koppen := land.main_koppen(p.id)
		var elev := land.mean_elevation(p.id)
		var rugged := land.median_ruggedness(p.id)
		p.climate = Land1590.climate_of(koppen, p.lat)
		p.topography = Land1590.topography_of(elev, rugged, p.marsh_share)
		var hint: String = p.terrain
		if p.wasteland:
			hint = {"glacier": "desert", "mountains": "", "tundra": "tundra", "desert": "desert"}.get(p.terrain, "")
		var density: float = 0.0 if p.wasteland else p.population / maxf(p.area, 1.0)
		var great_river: bool = p.great_river_px >= 3
		p.vegetation = Land1590.vegetation_of(koppen, p.topography, elev, p.lat, hint, density, great_river)
		if p.wasteland and p.terrain == "glacier":
			p.climate = "arctic"
		p.elevation = int(round(elev))


## Every land province's good (named sites first, then its land), its hidden
## deposits, and the buildings at work in 1590. Uses no `rng`.
func _assign_goods(provinces: Array) -> void:
	var by_id := {}
	for p: Dictionary in provinces:
		by_id[p.id] = p
		p.resource = ""
		p.deposits = []
		p.buildings = []
	var centre := func(p: Dictionary) -> Vector2:
		return Vector2(geo.y_to_lat(p.label[1] + 0.5), geo.x_to_lon(p.label[0] + 0.5))
	var land := func(p: Dictionary) -> bool:
		return not p.sea and not p.wasteland
	# Sites: a province containing an anchor takes it; else the nearest anchor
	# within reach of its centre.
	for site: Array in Resources.SITES:
		for a: Array in site[2]:
			var v := _province_at_point(a[0], a[1])
			if v > 0 and land.call(by_id[v]) and by_id[v].resource == "":
				by_id[v].resource = site[0]
	for p: Dictionary in provinces:
		if not land.call(p) or p.resource != "":
			continue
		var c: Vector2 = centre.call(p)
		var best := ""
		var best_d := INF
		for site: Array in Resources.SITES:
			for a: Array in site[2]:
				var d := Geo.haversine_km(c.x, c.y, a[0], a[1])
				if d <= site[1] and d < best_d:
					best_d = d
					best = site[0]
		if best == "":
			var h := fposmod(sin(p.id * 12.9898) * 43758.5453, 1.0)
			best = Resources.fallback(p.vegetation, p.topography, p.climate, p.coastal, c.x, c.y, h)
		p.resource = best
	# Deposits revealed in their era, and unknown gold veins in high country.
	for dep: Array in Resources.DEPOSITS:
		var hit := {}
		for a: Array in dep[4]:
			var v := _province_at_point(a[0], a[1])
			if v > 0:
				hit[v] = true
		for p: Dictionary in provinces:
			if land.call(p) and not hit.has(p.id):
				var c: Vector2 = centre.call(p)
				for a: Array in dep[4]:
					if Geo.haversine_km(c.x, c.y, a[0], a[1]) <= dep[3]:
						hit[p.id] = true
						break
		for v: int in hit:
			if land.call(by_id[v]) and by_id[v].resource != dep[0]:
				by_id[v].deposits.append([dep[0], dep[1], dep[2]])
	var veins := 0
	for p: Dictionary in provinces:
		if land.call(p) and p.topography in ["hills", "mountains"] and p.resource != "gold":
			if fposmod(sin(p.id * 78.233) * 12543.1, 1.0) < Resources.GOLD_VEIN_SHARE:
				p.deposits.append(["gold", 1590, Resources.GOLD_VEIN_CHANCE])
				veins += 1
	# Buildings already at work.
	var placed := 0
	for entry: Array in Resources.STARTING_BUILDINGS:
		for a: Array in entry[1]:
			var v := _province_at_point(a[0], a[1])
			if v <= 0 or not land.call(by_id[v]):
				push_warning("1590 %s at %s is not on a land province" % [entry[0], a])
				continue
			var p: Dictionary = by_id[v]
			var why := _building_misfit(entry[0], p)
			if why != "":
				push_warning("1590 %s in %s skipped: %s" % [entry[0], p.name, why])
			elif not entry[0] in p.buildings:
				p.buildings.append(entry[0])
				placed += 1
	print("  %d gold veins hidden, %d buildings at work in 1590" % [veins, placed])


func _province_at_point(lat: float, lon: float) -> int:
	var px := _snap_to_land(lat, lon, 3)
	return ids[px] if px >= 0 else 0


## Why a 1590 building does not suit a province ("" if it does); mirrors
## Buildings.unsuitable() for generator data.
func _building_misfit(id: String, p: Dictionary) -> String:
	var b: Dictionary = Buildings.CATALOGUE.get(id, {})
	if b.is_empty():
		return "unknown building"
	if b.has("kinds") and not Goods.kind_of(p.resource) in b.kinds:
		return "%s does not suit %s" % [p.resource, id]
	if b.has("goods") and not p.resource in b.goods:
		return "%s does not suit %s" % [p.resource, id]
	if b.has("recipes") and not b.recipes.has(p.resource):
		return "cannot work %s" % p.resource
	if b.get("coastal", false) and not p.coastal:
		return "not coastal"
	return ""


func _build_countries(provinces: Array) -> Dictionary:
	var owned := {}
	for p: Dictionary in provinces:
		if p.owner != "":
			if not owned.has(p.owner):
				owned[p.owner] = []
			owned[p.owner].append(p)
	var countries := {}
	for tag: String in Politics.POLITIES:
		if not owned.has(tag):
			push_warning("Polity %s ended up with no provinces and is dropped" % tag)
			continue
		var def: Array = Politics.POLITIES[tag]
		var capital := 0
		for p: Dictionary in owned[tag]:
			if p.capital_of == tag:
				capital = p.id
		if capital == 0:
			var biggest: Dictionary = owned[tag][0]
			for p: Dictionary in owned[tag]:
				if p.population > biggest.population:
					biggest = p
			capital = biggest.id
		countries[tag] = {"name": def[0], "government": def[1], "color": def[2], "capital": capital,
			"provinces": owned[tag].size()}
	for p: Dictionary in provinces:
		if p.owner != "" and not countries.has(p.owner):
			p.owner = ""
	_assign_colors(provinces, countries)
	return countries


func _assign_colors(provinces: Array, countries: Dictionary) -> void:
	var adjacent := {}
	for tag in countries:
		adjacent[tag] = {}
	for p: Dictionary in provinces:
		if p.owner == "":
			continue
		for n: int in p.neighbours:
			var o: String = provinces[n - 1].owner
			if o != "" and o != p.owner:
				adjacent[p.owner][o] = true
	var order: Array = countries.keys()
	order.sort_custom(func(a, b): return countries[a].provinces > countries[b].provinces)
	var uses := {}
	for tag: String in order:
		if countries[tag].color != "":
			continue
		var best := ""
		var best_score := -INF
		for hex: String in AUTO_COLORS:
			var c := Color.from_string(hex, Color.GRAY)
			var min_d := 3.0
			for other: String in adjacent[tag]:
				var oc: String = countries[other].color
				if oc != "":
					var o := Color.from_string(oc, Color.GRAY)
					min_d = minf(min_d, Vector3(c.r - o.r, c.g - o.g, c.b - o.b).length())
			var score: float = min_d - 0.04 * uses.get(hex, 0)
			if score > best_score:
				best_score = score
				best = hex
		countries[tag].color = best
		uses[best] = uses.get(best, 0) + 1


# --- 5. Output ------------------------------------------------------------------

## Islands of a few pixels are hard to see and to tap, and the raster loses
## most of their islets (each smaller than a pixel). On the drawn map each such
## island is drawn from its real shape: every land polygon of the source map
## of the same country within ISLET_REACH_KM — its own and its islets — at its
## true place, each pixel a small round spot (ISLET_RADIUS), into the sea only
## and never beside other land. So the Maldives show as their chain of atolls,
## Saint Helena as one small island. Only the drawing changes: statistics,
## neighbours and coasts are as found. (Mainland slivers are left as they are.)
const ISLAND_MIN_PX := 40
const ISLET_RADIUS := 2.0
const ISLET_REACH_KM := 600.0


func _enlarge_islands(drawn: PackedInt32Array, provinces: Array) -> int:
	var sea := {}
	for p: Dictionary in provinces:
		if p.sea:
			sea[p.id] = true
	# The islands: small land provinces with no other land beside them.
	var islands := []  # [province, adm0, lat, lon]
	for p: Dictionary in provinces:
		if p.sea or p.wasteland or p.px >= ISLAND_MIN_PX or p.id > seed_px.size():
			continue
		var alone := true
		for y in range(p.min_y, p.max_y + 1):
			for x in range(p.min_x, p.max_x + 1):
				var q: int = y * W + (x + W) % W
				if drawn[q] == p.id and _beside_other_land(drawn, q, p.id, sea):
					alone = false
		if alone:
			var u: int = unit[seed_px[p.id - 1]]
			islands.append([p, str(units[u].get("adm0", "")), geo.y_to_lat(p.label[1] + 0.5), _lon(p.label[0])])
	# Their islets, from the source map: the nearest island of the same country.
	var spots := {}  # province id -> PackedInt32Array of pixels to draw round
	for isl: Array in islands:
		var own := PackedInt32Array()
		var p: Dictionary = isl[0]
		for y in range(p.min_y, p.max_y + 1):
			for x in range(p.min_x, p.max_x + 1):
				var q: int = y * W + (x + W) % W
				if drawn[q] == p.id:
					own.append(q)
		spots[p.id] = own
	for f in Geo.load_features(SRC + "ne_10m_admin_1_states_provinces.geojson"):
		var adm0 := str(f.props.get("adm0_a3", ""))
		for rings: Array in f.polygons:
			var ring: PackedVector2Array = rings[0]
			var c := Vector2.ZERO
			for v in ring:
				c += v
			c /= maxf(ring.size(), 1)
			var best := -1
			var best_km := ISLET_REACH_KM
			for k in islands.size():
				if islands[k][1] != adm0:
					continue
				var km := Geo.haversine_km(c.y, c.x, islands[k][2], islands[k][3])
				if km < best_km:
					best_km = km
					best = k
			if best < 0:
				continue
			var pts := PackedVector2Array()
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for v in ring:
				var px := Vector2(geo.lon_to_x(v.x), geo.lat_to_y(v.y))
				pts.append(px)
				lo = lo.min(px)
				hi = hi.max(px)
			var id: int = islands[best][0].id
			var cpx := Vector2(geo.lon_to_x(c.x), geo.lat_to_y(c.y))
			spots[id].append(int(cpx.y) * W + (int(cpx.x) + W) % W)
			if hi.x - lo.x < 40.0 and hi.y - lo.y < 40.0:
				for y in range(int(lo.y), int(hi.y) + 1):
					for x in range(int(lo.x), int(hi.x) + 1):
						if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
							spots[id].append(y * W + (x + W) % W)
	# Each spot drawn round, into the sea, never beside other land.
	var r := int(ceil(ISLET_RADIUS))
	for id: int in spots:
		for q: int in spots[id]:
			var x := q % W
			var y := q / W
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy > ISLET_RADIUS * ISLET_RADIUS:
						continue
					var ny := y + dy
					if ny < 1 or ny >= H - 1:
						continue
					var n: int = ny * W + (x + dx + W) % W
					if sea.has(drawn[n]) and not _beside_other_land(drawn, n, id, sea):
						drawn[n] = id
	return islands.size()


func _beside_other_land(drawn: PackedInt32Array, n: int, id: int, sea: Dictionary) -> bool:
	var x := n % W
	var y := n / W
	for k in 8:
		var m: int = (y + DY[k]) * W + (x + DX[k] + W) % W
		var v := drawn[m]
		if v != id and v != 0 and not sea.has(v):
			return true
	return false


## The id map saves were made with, if this build keeps every province (same
## ids and names): earlier fingerprints carried forward, and the one being
## replaced. Saves made with them still load.
func _compatible_maps(provinces: Array) -> Array:
	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/provinces.json"))
	if not old is Dictionary or not FileAccess.file_exists("res://data/map/province_ids.res"):
		return []
	var before := {}
	for key in ["provinces", "wastelands", "seas"]:
		for e: Dictionary in old.get(key, []):
			before[int(e.id)] = e.name
	if before.size() != provinces.size():
		return []
	for p: Dictionary in provinces:
		if before.get(p.id, null) != p.name:
			return []
	var out: Array = old.get("map", {}).get("compatible_id_textures", []).duplicate()
	var md5 := FileAccess.get_md5("res://data/map/province_ids.res")
	if not md5 in out:
		out.append(md5)
	return out


func _write_outputs(provinces: Array, countries: Dictionary) -> void:
	for dir in ["res://data/map", "res://data/world", "res://data/scenarios"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var compatible := _compatible_maps(provinces)
	var drawn := ids.duplicate()
	_log("Islands drawn from their real shapes: %d" % _enlarge_islands(drawn, provinces))
	var id_bytes := PackedByteArray()
	id_bytes.resize(W * H * 2)
	for i in W * H:
		id_bytes[i * 2] = drawn[i] & 0xFF
		id_bytes[i * 2 + 1] = (drawn[i] >> 8) & 0xFF
	var id_image := Image.create_from_data(W, H, false, Image.FORMAT_RG8, id_bytes)
	ResourceSaver.save(id_image, "res://data/map/province_ids.res", ResourceSaver.FLAG_COMPRESS)
	compatible.erase(FileAccess.get_md5("res://data/map/province_ids.res"))
	ResourceSaver.save(_relief(), "res://data/map/heightmap.res", ResourceSaver.FLAG_COMPRESS)
	_write_rivers()

	var out_provinces := []
	var out_wastes := []
	var out_seas := []
	for p: Dictionary in provinces:
		var entry := {
			"id": p.id, "name": p.name, "region": p.region, "terrain": p.terrain,
			"area": p.px, "area_km2": int(round(p.area)), "label": p.label,
			"lat": snappedf(p.lat, 0.01), "lon": snappedf(p.lon, 0.01),
			"bounds": [p.min_x, p.min_y, p.max_x - p.min_x + 1, p.max_y - p.min_y + 1],
		}
		if not p.sea:
			entry.topography = p.topography
			entry.vegetation = p.vegetation
			entry.climate = p.climate
			entry.elevation = p.elevation
		if not p.sea and not p.wasteland:
			entry.resource = p.resource
			entry.deposits = p.deposits
		if p.wasteland:
			out_wastes.append(entry)
			continue
		var neighbours: Array = p.neighbours.keys()
		neighbours.sort()
		entry.neighbours = neighbours
		if p.sea:
			var coasts: Array = p.coasts.keys()
			coasts.sort()
			entry.coasts = coasts
			out_seas.append(entry)
			continue
		var seas: Array = p.seas.keys()
		seas.sort()
		entry.coastal = p.coastal
		entry.division = p.unit_name
		entry.seas = seas
		out_provinces.append(entry)
	var regions := {}
	for r in region_ids.size():
		regions[region_ids[r]] = {"name": Regions.REGIONS[region_ids[r]][0], "quota": region_quota[r]}
	_write_json("res://data/world/provinces.json", {
		"version": DATA_VERSION,
		"map": {
			"width": W, "height": H,
			"id_texture": "res://data/map/province_ids.res",
			"height_texture": "res://data/map/heightmap.res",
			"compatible_id_textures": compatible,
			"projection": {"type": "mercator", "lon_west": Geo.LON_WEST, "lat_north": Geo.LAT_NORTH,
				"lat_south": Geo.LAT_SOUTH},
		},
		"regions": regions,
		"provinces": out_provinces,
		"wastelands": out_wastes,
		"seas": out_seas,
	})

	var out_countries := []
	var tags: Array = countries.keys()
	tags.sort()
	for tag: String in tags:
		out_countries.append({"id": tag, "name": countries[tag].name, "color": countries[tag].color})
	_write_json("res://data/world/countries.json", {"version": DATA_VERSION, "countries": out_countries})

	var scenario_countries := {}
	for tag: String in tags:
		var c: Dictionary = countries[tag]
		scenario_countries[tag] = {
			"capital": c.capital, "government": c.government,
			"treasury": mini(500, 30 + c.provinces * 2), "legitimacy": 75, "stability": 0,
			"colonial": Politics.COLONIAL_POLICY.get(tag, 0),
		}
	var scenario_provinces := {}
	for p: Dictionary in provinces:
		if not p.wasteland and not p.sea:
			scenario_provinces[str(p.id)] = {"owner": p.owner, "controller": p.owner,
				"population": p.population, "development": p.development, "buildings": p.buildings}
	_write_json("res://data/scenarios/1590.json", {
		"version": DATA_VERSION,
		"name": "The Long Century — 1 January 1590",
		"start_date": {"year": 1590, "month": 1, "day": 1},
		"player_country": PLAYER_COUNTRY,
		"countries": scenario_countries,
		"provinces": scenario_provinces,
		"diplomacy": _scenario_diplomacy(countries),
	})


## The 1590 subjects, alliances, royal marriages and rivalries, for countries
## that exist on the map.
func _scenario_diplomacy(countries: Dictionary) -> Dictionary:
	var keep := func(pair: Array) -> bool:
		for tag in pair.slice(0, 2):
			if not countries.has(tag):
				push_warning("1590 diplomacy: %s is not on the map; %s skipped" % [tag, pair])
				return false
		return true
	# Rows as saves store them: [overlord, subject, kind], [a, b], [rival-declarer, rival].
	return {
		"subjects": Politics.SUBJECTS.filter(keep),
		"alliances": Politics.ALLIANCES.filter(keep),
		"marriages": Politics.ROYAL_MARRIAGES.filter(keep),
		"rivals": Politics.RIVALRIES.filter(keep),
	}


## Rivers as polylines in map pixels (drawn as anti-aliased vector lines in the
## game, so they stay thin and sharp at any zoom). Split where they cross the
## map seam; points closer than ~1.5 px are dropped.
func _write_rivers() -> void:
	var out := []
	for entry: Array in river_lines:
		var rank := 1 if entry[1] >= 255 else (2 if entry[1] >= 190 else 3)
		for line: PackedVector2Array in entry[0]:
			var pts := []
			var last := Vector2.INF
			for v in line:
				var lon := v.x if v.x >= Geo.LON_WEST else v.x + 360.0
				var pt := Vector2(geo.lon_to_x(lon), geo.lat_to_y(v.y))
				if pt.y < 0 or pt.y > H:
					continue
				if last != Vector2.INF and absf(pt.x - last.x) > W * 0.5:
					if pts.size() >= 4:
						out.append({"rank": rank, "points": pts})
					pts = []
					last = Vector2.INF
				if last == Vector2.INF or pt.distance_to(last) >= 1.5:
					pts.append_array([snappedf(pt.x, 0.1), snappedf(pt.y, 0.1)])
					last = pt
			if pts.size() >= 4:
				out.append({"rank": rank, "points": pts})
	_write_json("res://data/map/rivers.json", {"version": DATA_VERSION, "rivers": out})


## Half-resolution relief, RG8. R: 0..127 sea depth (127 at the coast),
## 128..255 land elevation from mountain/hill regions with noise and soft
## edges. G: rivers.
func _relief() -> Image:
	var hw := W / 2
	var hh := (H + 1) / 2
	var mountains := Regions.TERRAINS.find("mountains")
	var hills := Regions.TERRAINS.find("hills")
	var land := PackedByteArray()
	land.resize(hw * hh)
	var mtn := PackedByteArray()
	mtn.resize(hw * hh)
	var hil := PackedByteArray()
	hil.resize(hw * hh)
	for y in hh:
		for x in hw:
			var src := mini(y * 2, H - 1) * W + x * 2
			var i := y * hw + x
			land[i] = 1 if adm[src] != 0 else 0
			var t := geo_terrain[georeg[src]]
			mtn[i] = 1 if t == mountains else 0
			hil[i] = 1 if t == hills else 0
	var d_mtn := _inside_distance(mtn, hw, hh)
	var d_hil := _inside_distance(hil, hw, hh)
	var sea := PackedByteArray()
	sea.resize(hw * hh)
	for i in hw * hh:
		sea[i] = 1 - land[i]
	var d_sea := _inside_distance(sea, hw, hh)
	var rivers := PackedByteArray()
	rivers.resize(hw * hh)
	for entry: Array in river_lines:
		geo.draw_lines(rivers, entry[0], entry[1], 0.5)

	var ridge := FastNoiseLite.new()
	ridge.seed = SEED + 11
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.frequency = 0.03
	ridge.fractal_octaves = 4
	var base := FastNoiseLite.new()
	base.seed = SEED + 12
	base.frequency = 0.02
	base.fractal_octaves = 3
	var bytes := PackedByteArray()
	bytes.resize(hw * hh * 2)
	for y in hh:
		for x in hw:
			var i := y * hw + x
			if land[i] == 0:
				bytes[i * 2] = int(127.0 - clampf(d_sea[i] / 3.0 / 14.0, 0.0, 1.0) * 127.0)
				continue
			var e := 0.07 + 0.06 * (base.get_noise_2d(x, y) * 0.5 + 0.5)
			e += 0.22 * smoothstep(0.0, 24.0, float(d_hil[i]))
			e += (0.35 + 0.35 * (ridge.get_noise_2d(x, y) * 0.5 + 0.5)) * smoothstep(0.0, 30.0, float(d_mtn[i]))
			bytes[i * 2] = 128 + int(clampf(e, 0.0, 1.0) * 127.0)
			bytes[i * 2 + 1] = rivers[i]
	return Image.create_from_data(hw, hh, false, Image.FORMAT_RG8, bytes)


## Chamfer distance (x3) from each mask pixel to the nearest non-mask pixel.
func _inside_distance(mask: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = (1 << 20) if mask[i] else 0
	for y in range(1, h):
		for x in range(1, w - 1):
			var i := y * w + x
			if d[i] == 0:
				continue
			d[i] = mini(d[i], mini(mini(d[i - 1] + 3, d[i - w] + 3), mini(d[i - w - 1] + 4, d[i - w + 1] + 4)))
	for y in range(h - 2, -1, -1):
		for x in range(w - 2, 0, -1):
			var i := y * w + x
			if d[i] == 0:
				continue
			d[i] = mini(d[i], mini(mini(d[i + 1] + 3, d[i + w] + 3), mini(d[i + w + 1] + 4, d[i + w - 1] + 4)))
	return d


func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()


func _report(provinces: Array, countries: Dictionary) -> void:
	var per_region := {}
	var uncolonised := 0
	var terrain := {}
	var tiny := 0
	var wastes := []
	var lakes := 0
	for p: Dictionary in provinces:
		if p.sea:
			lakes += 1 if p.terrain == "lake" else 0
			continue
		if p.wasteland:
			wastes.append("%s (%d km²)" % [p.name, int(p.area)])
			continue
		per_region[p.region] = per_region.get(p.region, 0) + 1
		terrain[p.terrain] = terrain.get(p.terrain, 0) + 1
		if p.owner == "":
			uncolonised += 1
		if p.px < 12:
			tiny += 1
	print("Provinces: %d ownable (%d uncolonised, %d under 12 px) + %d wastelands + %d sea tiles (%d on lakes)" % [
		province_count, uncolonised, tiny, waste_count, sea_count, lakes])
	for r in region_ids:
		print("  %-4s %4d / quota %4d" % [r, per_region.get(r, 0), region_quota[region_ids.find(r)]])
	print("Terrain: %s" % terrain)
	for key in ["climate", "topography", "vegetation"]:
		var counts := {}
		for p: Dictionary in provinces:
			if not p.sea and not p.wasteland:
				counts[p[key]] = counts.get(p[key], 0) + 1
		print("%s: %s" % [key.capitalize(), counts])
	print("Wastelands: %s" % ", ".join(wastes))
	print("Countries: %d of %d polities" % [countries.size(), Politics.POLITIES.size()])
