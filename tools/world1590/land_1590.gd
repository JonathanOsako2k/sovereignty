extends RefCounted
## Climate, topography and vegetation for every province, EU5-style, from real
## data (both in tools/source_data, fetched by tools/fetch_source_data.sh):
##
## * Köppen-Geiger climate classification, 0.5° grid, 1951-2000
##   (Kottek et al. 2006, doi:10.1127/0941-2948/2006/0130) → climate.
## * ETOPO1 elevation (NOAA NGDC, public domain) sampled every 5 arc-minutes
##   → mean elevation and ruggedness → topography.
##
## Vegetation is the natural cover the climate supports (Köppen classes were
## drawn on vegetation boundaries), adjusted by topography, Natural Earth's
## named steppes/deserts/wetlands, and — for farmland — how densely the
## province was peopled in 1590.
##
## Usage: load(); per map pixel sample(index, lat, lon); then classify each.

const KOPPEN_PATH := "res://tools/source_data/Koeppen-Geiger-ASCII.txt"
const ETOPO_PATH := "res://tools/source_data/etopo1_5min.nc"

const KOPPEN := ["Af", "Am", "As", "Aw", "BWk", "BWh", "BSk", "BSh", "Cfa", "Cfb", "Cfc", "Csa", "Csb",
	"Csc", "Cwa", "Cwb", "Cwc", "Dfa", "Dfb", "Dfc", "Dfd", "Dsa", "Dsb", "Dsc", "Dsd", "Dwa", "Dwb",
	"Dwc", "Dwd", "EF", "ET"]
## Köppen class → game climate (Land.CLIMATE).
const CLIMATE_OF := {
	"Af": "equatorial", "Am": "tropical", "As": "tropical", "Aw": "tropical",
	"BWh": "hot_arid", "BSh": "hot_arid", "BWk": "cold_arid", "BSk": "cold_arid",
	"Cfa": "subtropical", "Cwa": "subtropical", "Cwb": "subtropical", "Cwc": "subtropical",
	"Cfb": "oceanic", "Cfc": "oceanic", "Csa": "mediterranean", "Csb": "mediterranean", "Csc": "mediterranean",
	"Dfa": "continental", "Dfb": "continental", "Dwa": "continental", "Dwb": "continental",
	"Dsa": "continental", "Dsb": "continental",
	"Dfc": "subarctic", "Dfd": "subarctic", "Dwc": "subarctic", "Dwd": "subarctic",
	"Dsc": "subarctic", "Dsd": "subarctic", "ET": "arctic", "EF": "arctic",
}
## Köppen class → the vegetation it supports untouched.
const NATURAL_VEGETATION := {
	"Af": "jungle", "Am": "jungle", "As": "woods", "Aw": "woods",
	"BWh": "desert", "BWk": "desert", "BSh": "sparse", "BSk": "grasslands",
	"Cfa": "forest", "Cfb": "forest", "Cfc": "sparse", "Csa": "woods", "Csb": "woods", "Csc": "woods",
	"Cwa": "woods", "Cwb": "woods", "Cwc": "woods",
	"Dfa": "forest", "Dfb": "forest", "Dfc": "forest", "Dfd": "forest", "Dsa": "woods", "Dsb": "woods",
	"Dsc": "forest", "Dsd": "forest", "Dwa": "forest", "Dwb": "forest", "Dwc": "forest", "Dwd": "forest",
	"ET": "sparse", "EF": "desert",
}

## How thickly a land of each Köppen class was peopled in 1590 against the
## best farmland (monsoon rice, the Gangetic plain, the Yangtze), for spreading
## a region's people over its provinces: savanna millet and Mediterranean grain
## less, the northern forests and the steppe far less, desert and ice hardly
## at all (a great river's oasis aside: people_factor).
const KOPPEN_PEOPLE := {
	"Af": 0.35, "Am": 1.0, "As": 0.8, "Aw": 0.7,
	"BWh": 0.03, "BWk": 0.03, "BSh": 0.25, "BSk": 0.25,
	"Cfa": 1.0, "Cfb": 0.8, "Cfc": 0.2, "Csa": 0.7, "Csb": 0.7, "Csc": 0.3,
	"Cwa": 1.1, "Cwb": 0.8, "Cwc": 0.3,
	"Dfa": 0.6, "Dfb": 0.5, "Dfc": 0.08, "Dfd": 0.03, "Dsa": 0.5, "Dsb": 0.5, "Dsc": 0.08, "Dsd": 0.03,
	"Dwa": 0.9, "Dwb": 0.5, "Dwc": 0.08, "Dwd": 0.03,
	"ET": 0.02, "EF": 0.0,
}
## The same for the lie of the land.
const TOPOGRAPHY_PEOPLE := {"flatland": 1.0, "plateau": 0.8, "hills": 0.7, "mountains": 0.3, "wetlands": 0.5}
## In the tropics (this far from the equator) the healthy highlands — Ethiopia,
## the Andes, Mexico, the Great Lakes — held people best, up to a height.
const TROPICS_LATITUDE := 25.0
const TROPICAL_HIGHLAND := [1000.0, 3600.0]
const TROPICAL_HIGHLAND_PEOPLE := 1.4
## Elsewhere high ground was thinly peopled (Tibet, the Pamirs).
const HIGH_GROUND := 2500.0
const HIGH_GROUND_PEOPLE := 0.4
const VERY_HIGH_GROUND := 4200.0
const VERY_HIGH_GROUND_PEOPLE := 0.15
## A great river: more people along it, and in dry land an oasis.
const RIVER_PEOPLE := 1.5
const RIVER_OASIS_PEOPLE := 12.0

## Topography thresholds: the province's median ruggedness (elevation step to
## the neighbouring 5' cells, metres; the median so a mountainous fringe does
## not decide) and its mean elevation.
const MOUNTAIN_RUGGEDNESS := 170.0
const HILL_RUGGEDNESS := 55.0
## High ground that is not too broken: the Meseta, the Deccan, Anatolia, Iran.
const PLATEAU_ELEVATION := 600.0
const PLATEAU_MAX_RUGGEDNESS := 140.0
## High plateaus are more broken in absolute metres: the limit rises by this
## much per metre above PLATEAU_ELEVATION (Anatolia, Iran stay plateaus).
const PLATEAU_RUGGEDNESS_PER_M := 0.03
## High, steep ground counts as mountains at a lower ruggedness.
const HIGH_MOUNTAIN_ELEVATION := 2500.0
const HIGH_MOUNTAIN_RUGGEDNESS := 110.0
## Ground too high for trees, by absolute latitude band (metres).
const TREELINE := [[0.0, 3800.0], [30.0, 3300.0], [45.0, 2200.0], [60.0, 900.0]]
## People per km² above which a province's land counts as cleared farmland in 1590.
const FARMLAND_DENSITY := 18.0
## In deserts and dry scrub a great river with this many people per km² means
## irrigated fields along it (the Nile, Mesopotamia, the Oxus).
const RIVER_OASIS_DENSITY := 1.5
## …counted on no more than this much of the province (km²): a vast desert
## province with a river through it (Timbuktu, Dongola) stays desert.
const RIVER_OASIS_AREA := 30000.0
## Köppen's alpine tundra (ET/EF) closer to the equator than this is mountain
## cold, not polar: the game calls it subarctic.
const ALPINE_LATITUDE := 55.0
## Share of a province in Natural Earth wetlands that makes it wetlands.
const WETLAND_SHARE := 0.25

const KG_COLS := 720
const KG_ROWS := 360

var _koppen := PackedByteArray()  # KG_ROWS x KG_COLS, KOPPEN index + 1, sea filled from nearest land
var _elev := PackedInt32Array()  # metres, row 0 = 90°S
var _rugged := PackedInt32Array()
var _rows := 0
var _cols := 0  # distinct longitudes (the duplicated 180° column dropped)
var _lat0 := -90.0
var _step := 1.0 / 12.0

# Per-province accumulators (index = province id).
var _n := PackedInt32Array()
var _elev_sum := PackedFloat64Array()
var _rugged_sum := PackedFloat64Array()
var _kg := PackedInt32Array()  # n_provinces x KOPPEN.size()
## Ruggedness histogram per province (RUGGED_BIN-metre bins), for medians:
## a mountainous fringe must not turn a plain or plateau into hills.
var _rugged_hist := PackedInt32Array()
const RUGGED_BIN := 10
const RUGGED_BINS := 80

var errors := PackedStringArray()


func load_data(province_slots: int) -> bool:
	_load_koppen()
	_load_etopo()
	_n.resize(province_slots)
	_elev_sum.resize(province_slots)
	_rugged_sum.resize(province_slots)
	_kg.resize(province_slots * KOPPEN.size())
	_rugged_hist.resize(province_slots * RUGGED_BINS)
	return errors.is_empty()


# --- Sampling ------------------------------------------------------------------

func koppen_at(lat: float, lon: float) -> int:
	var r := clampi(int(floor((lat + 90.0) * 2.0)), 0, KG_ROWS - 1)
	var c := posmod(int(floor((_wrap_lon(lon) + 180.0) * 2.0)), KG_COLS)
	return _koppen[r * KG_COLS + c] - 1


func _cell(lat: float, lon: float) -> int:
	var r := clampi(int(round((lat - _lat0) / _step)), 0, _rows - 1)
	var c := posmod(int(round((_wrap_lon(lon) + 180.0) / _step)), _cols)
	return r * _cols + c


func elevation_at(lat: float, lon: float) -> int:
	return _elev[_cell(lat, lon)]


func ruggedness_at(lat: float, lon: float) -> int:
	return _rugged[_cell(lat, lon)]


## Adds one map sample at (lat, lon) to province `id`.
func sample(id: int, lat: float, lon: float) -> void:
	var cell := _cell(lat, lon)
	_n[id] += 1
	_elev_sum[id] += maxi(_elev[cell], 0)
	_rugged_sum[id] += _rugged[cell]
	_rugged_hist[id * RUGGED_BINS + mini(_rugged[cell] / RUGGED_BIN, RUGGED_BINS - 1)] += 1
	var k := koppen_at(lat, lon)
	if k >= 0:
		_kg[id * KOPPEN.size() + k] += 1


func has_samples(id: int) -> bool:
	return _n[id] > 0


func mean_elevation(id: int) -> float:
	return _elev_sum[id] / maxf(_n[id], 1.0)


func mean_ruggedness(id: int) -> float:
	return _rugged_sum[id] / maxf(_n[id], 1.0)


## Median ruggedness of the province's samples (metres).
func median_ruggedness(id: int) -> float:
	var half := _n[id] / 2
	var count := 0
	for b in RUGGED_BINS:
		count += _rugged_hist[id * RUGGED_BINS + b]
		if count > half:
			return (b + 0.5) * RUGGED_BIN
	return RUGGED_BINS * RUGGED_BIN


## The province's dominant Köppen class ("" if it has no samples).
func main_koppen(id: int) -> String:
	var best := -1
	var best_n := 0
	for k in KOPPEN.size():
		var n := _kg[id * KOPPEN.size() + k]
		if n > best_n:
			best_n = n
			best = k
	return KOPPEN[best] if best >= 0 else ""


## The province's climate's capacity for people: its Köppen classes' mix
## (KOPPEN_PEOPLE), so a province half rice plain and half hills counts both.
func climate_capacity(id: int) -> float:
	var total := 0
	var sum := 0.0
	for k in KOPPEN.size():
		var n := _kg[id * KOPPEN.size() + k]
		total += n
		sum += n * float(KOPPEN_PEOPLE.get(KOPPEN[k], 0.3))
	return sum / total if total > 0 else 0.3


# --- Classification ----------------------------------------------------------------

## How many people a province's land fed against the best farmland, per km²:
## its climate (`capacity`, climate_capacity), the lie of the land, its height
## (the tropics' highlands best; elsewhere high ground poor), and a great river
## (an oasis in dry land).
static func people_factor(capacity: float, topography: String, mean_elev: float, lat: float,
		great_river: bool, koppen: String) -> float:
	var f: float = capacity * float(TOPOGRAPHY_PEOPLE.get(topography, 0.8))
	if absf(lat) < TROPICS_LATITUDE:
		if mean_elev >= TROPICAL_HIGHLAND[0] and mean_elev < TROPICAL_HIGHLAND[1]:
			f *= TROPICAL_HIGHLAND_PEOPLE
		elif mean_elev >= VERY_HIGH_GROUND:
			f *= VERY_HIGH_GROUND_PEOPLE
	elif mean_elev >= VERY_HIGH_GROUND:
		f *= VERY_HIGH_GROUND_PEOPLE
	elif mean_elev >= HIGH_GROUND:
		f *= HIGH_GROUND_PEOPLE
	if great_river:
		f *= RIVER_OASIS_PEOPLE if koppen.begins_with("BW") else RIVER_PEOPLE
	return f


static func climate_of(koppen: String, lat: float) -> String:
	if (koppen == "ET" or koppen == "EF") and absf(lat) < ALPINE_LATITUDE:
		return "subarctic"
	return CLIMATE_OF.get(koppen, "continental")


## `wet_share`: share of the province in Natural Earth wetlands/marshes.
static func topography_of(mean_elev: float, rugged: float, wet_share: float) -> String:
	if wet_share >= WETLAND_SHARE and rugged < HILL_RUGGEDNESS:
		return "wetlands"
	if rugged >= MOUNTAIN_RUGGEDNESS or (mean_elev >= HIGH_MOUNTAIN_ELEVATION and rugged >= HIGH_MOUNTAIN_RUGGEDNESS):
		return "mountains"
	var plateau_limit := PLATEAU_MAX_RUGGEDNESS + (mean_elev - PLATEAU_ELEVATION) * PLATEAU_RUGGEDNESS_PER_M
	if mean_elev >= PLATEAU_ELEVATION and rugged < plateau_limit:
		return "plateau"
	if rugged >= HILL_RUGGEDNESS:
		return "hills"
	return "flatland"


## `hint`: the old Natural Earth terrain of the province (steppe, desert,
## jungle, marsh, tundra… or ""); `density`: people per km² in 1590;
## `great_river`: a major river runs through it.
static func vegetation_of(koppen: String, topography: String, mean_elev: float, lat: float,
		hint: String, density: float, great_river := false, area_km2 := 0.0) -> String:
	var veg: String = NATURAL_VEGETATION.get(koppen, "woods")
	# Named landscapes from Natural Earth sharpen the climate's guess.
	match hint:
		"desert":
			if veg != "jungle":
				veg = "desert" if koppen.begins_with("BW") or koppen == "" else "sparse"
		"steppe":
			if veg in ["forest", "woods", "jungle"]:
				veg = "grasslands"
		"jungle":
			if veg in ["forest", "woods", "grasslands"]:
				veg = "jungle"
		"tundra":
			veg = "sparse"
	if topography == "mountains" and mean_elev >= _treeline(lat) and veg != "desert":
		veg = "sparse"
	# Cleared and tilled where people were thick on the ground (including
	# irrigated river valleys in dry lands, like the Nile).
	if density >= FARMLAND_DENSITY and topography != "mountains":
		veg = "farmland"
	elif great_river and veg in ["desert", "sparse"] 			and density * minf(1.0, RIVER_OASIS_AREA / maxf(area_km2, 1.0)) >= RIVER_OASIS_DENSITY:
		veg = "farmland"
	return veg


static func _treeline(lat: float) -> float:
	var alat := absf(lat)
	var line: float = TREELINE[0][1]
	for band: Array in TREELINE:
		if alat >= band[0]:
			line = band[1]
	return line


# --- Loading ---------------------------------------------------------------------

static func _wrap_lon(lon: float) -> float:
	return fposmod(lon + 180.0, 360.0) - 180.0


func _load_koppen() -> void:
	var f := FileAccess.open(KOPPEN_PATH, FileAccess.READ)
	if f == null:
		errors.append("cannot read %s; run tools/fetch_source_data.sh" % KOPPEN_PATH)
		return
	_koppen.resize(KG_ROWS * KG_COLS)
	f.get_line()  # header
	while not f.eof_reached():
		var parts := f.get_line().split(" ", false)
		if parts.size() < 3:
			continue
		var k := KOPPEN.find(parts[2])
		if k < 0:
			continue
		var r := clampi(int(floor((float(parts[0]) + 90.0) * 2.0)), 0, KG_ROWS - 1)
		var c := clampi(int(floor((float(parts[1]) + 180.0) * 2.0)), 0, KG_COLS - 1)
		_koppen[r * KG_COLS + c] = k + 1
	# Coasts on the map need not match the 0.5° land cells: spread each class
	# outward over the sea so every land pixel finds its nearest climate.
	var frontier := PackedInt32Array()
	for i in _koppen.size():
		if _koppen[i] != 0:
			frontier.append(i)
	while not frontier.is_empty():
		var next := PackedInt32Array()
		for i in frontier:
			var r := i / KG_COLS
			var c := i % KG_COLS
			for d in [[0, 1], [0, -1], [1, 0], [-1, 0]]:
				var rr: int = r + d[0]
				if rr < 0 or rr >= KG_ROWS:
					continue
				var j: int = rr * KG_COLS + posmod(c + d[1], KG_COLS)
				if _koppen[j] == 0:
					_koppen[j] = _koppen[i]
					next.append(j)
		frontier = next


## Reads the altitude grid from a classic netCDF file (as served by ERDDAP).
func _load_etopo() -> void:
	var bytes := FileAccess.get_file_as_bytes(ETOPO_PATH)
	if bytes.is_empty():
		errors.append("cannot read %s; run tools/fetch_source_data.sh" % ETOPO_PATH)
		return
	var nc := NetCdf.new(bytes)
	if nc.error != "":
		errors.append("%s: %s" % [ETOPO_PATH, nc.error])
		return
	var alt: Dictionary = nc.variables.get("altitude", {})
	var lat: Dictionary = nc.variables.get("latitude", {})
	var lon: Dictionary = nc.variables.get("longitude", {})
	if alt.is_empty() or lat.is_empty() or lon.is_empty():
		errors.append("%s lacks altitude/latitude/longitude" % ETOPO_PATH)
		return
	var nlat: int = nc.dim_sizes[alt.dims[0]]
	var nlon: int = nc.dim_sizes[alt.dims[1]]
	var lat_first := nc.read_double(lat.begin)
	var lat_last := nc.read_double(lat.begin + (nlat - 1) * 8)
	var lon_first := nc.read_double(lon.begin)
	var lon_last := nc.read_double(lon.begin + (nlon - 1) * 8)
	_step = (lat_last - lat_first) / (nlat - 1)
	_lat0 = lat_first
	_rows = nlat
	# A grid running -180..180 repeats the seam column; keep one copy.
	_cols = nlon - 1 if is_equal_approx(lon_last - lon_first, 360.0) else nlon
	if not is_equal_approx(lon_first, -180.0) or _step <= 0.0:
		errors.append("%s: unexpected grid (lat %f..%f, lon %f..%f)" % [ETOPO_PATH, lat_first, lat_last, lon_first, lon_last])
		return
	_elev.resize(_rows * _cols)
	var base: int = alt.begin
	for r in _rows:
		var row_base := base + r * nlon * 2
		for c in _cols:
			var o := row_base + c * 2
			var v := (bytes[o] << 8) | bytes[o + 1]
			_elev[r * _cols + c] = v - 65536 if v >= 32768 else v
	# Ruggedness: mean elevation step to the four neighbours (sea counted as 0 m,
	# so coastlines do not read as cliffs).
	_rugged.resize(_rows * _cols)
	for r in _rows:
		for c in _cols:
			var e := maxi(_elev[r * _cols + c], 0)
			var total := 0
			total += absi(e - maxi(_elev[r * _cols + posmod(c + 1, _cols)], 0))
			total += absi(e - maxi(_elev[r * _cols + posmod(c - 1, _cols)], 0))
			total += absi(e - maxi(_elev[mini(r + 1, _rows - 1) * _cols + c], 0))
			total += absi(e - maxi(_elev[maxi(r - 1, 0) * _cols + c], 0))
			_rugged[r * _cols + c] = total / 4


## Minimal reader for classic (CDF-1/CDF-2) netCDF headers.
class NetCdf:
	var bytes: PackedByteArray
	var pos := 0
	var error := ""
	var dim_sizes: Array[int] = []
	var variables := {}  # name -> {dims: [dim ids], type, begin}
	var _offset_size := 4

	func _init(data: PackedByteArray) -> void:
		bytes = data
		if bytes.size() < 8 or bytes.slice(0, 3).get_string_from_ascii() != "CDF":
			error = "not a classic netCDF file"
			return
		_offset_size = 8 if bytes[3] == 2 else 4
		pos = 8  # magic + numrecs
		_read_dims()
		_skip_attributes()
		_read_variables()

	func _u32() -> int:
		var v := (bytes[pos] << 24) | (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3]
		pos += 4
		return v

	func _name() -> String:
		var n := _u32()
		var s := bytes.slice(pos, pos + n).get_string_from_utf8()
		pos += (n + 3) / 4 * 4
		return s

	func _read_dims() -> void:
		var tag := _u32()
		var n := _u32()
		if tag == 0:
			return
		for i in n:
			_name()
			dim_sizes.append(_u32())

	func _skip_attributes() -> void:
		var tag := _u32()
		var n := _u32()
		if tag == 0:
			return
		for i in n:
			_name()
			var type := _u32()
			var count := _u32()
			var size: int = [0, 1, 1, 2, 4, 4, 8][type] * count
			pos += (size + 3) / 4 * 4

	func _read_variables() -> void:
		var tag := _u32()
		var n := _u32()
		if tag == 0:
			return
		for i in n:
			var name := _name()
			var ndims := _u32()
			var dims: Array[int] = []
			for d in ndims:
				dims.append(_u32())
			_skip_attributes()
			var type := _u32()
			_u32()  # vsize
			var begin := _u32()
			if _offset_size == 8:
				begin = (begin << 32) | _u32()
			variables[name] = {"dims": dims, "type": type, "begin": begin}

	func read_double(offset: int) -> float:
		var b := bytes.slice(offset, offset + 8)
		b.reverse()
		return b.decode_double(0)
