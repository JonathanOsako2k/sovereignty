extends "res://tests/test_case.gd"
## EU5-style land (topography, vegetation, climate), probed at real places.

## [place, lat, lon, field, expected]
const PLACES := [
	["Paris", 48.86, 2.35, "climate", "oceanic"], ["Rome", 41.90, 12.50, "climate", "mediterranean"],
	["Moscow", 55.75, 37.62, "climate", "continental"], ["Archangel", 64.54, 40.54, "climate", "subarctic"],
	["Cairo", 30.04, 31.24, "climate", "hot_arid"], ["Bukhara", 39.77, 64.42, "climate", "cold_arid"],
	["Kisangani", 0.52, 25.20, "climate", "equatorial"], ["Calcutta", 22.57, 88.36, "climate", "tropical"],
	["Shanghai", 31.23, 121.47, "climate", "subtropical"], ["Chukotka", 66.6, -172.1, "climate", "arctic"],
	["Amsterdam", 52.37, 4.90, "topography", "flatland"], ["Bern", 46.95, 7.45, "topography", "mountains"],
	["Madrid", 40.42, -3.70, "topography", "plateau"], ["Konya", 37.87, 32.48, "topography", "plateau"],
	["Lhasa", 29.65, 91.10, "topography", "mountains"], ["Kyoto", 35.01, 135.77, "topography", "hills"],
	["Paris", 48.86, 2.35, "vegetation", "farmland"], ["Kisangani", 0.52, 25.20, "vegetation", "jungle"],
	["Timbuktu", 16.77, -3.00, "vegetation", "desert"], ["Yakutsk", 62.03, 129.73, "vegetation", "forest"],
	["Kansas", 38.5, -98.0, "vegetation", "grasslands"], ["Manaus", -3.12, -60.02, "vegetation", "jungle"],
]


func _load() -> WorldState:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	return world


func test_every_land_province_has_valid_land() -> void:
	var world := _load()
	var bad := []
	for p: Province in world.provinces.values():
		if p.is_sea:
			check(p.topography == "" and p.vegetation == "" and p.climate == "", "sea tile %d has no land" % p.id)
		elif not Land.is_valid(p.topography, p.vegetation, p.climate):
			bad.append("%d %s: %s/%s/%s" % [p.id, p.name, p.topography, p.vegetation, p.climate])
	check(bad.is_empty(), "invalid land: %s" % [bad.slice(0, 5)])


func test_real_places() -> void:
	var world := _load()
	var image := MapView._load_image(world.id_texture_path)
	for row: Array in PLACES:
		var pos := world.latlon_to_map(row[1], row[2])
		var p := world.get_province(MapView.decode_id(image.get_pixelv(Vector2i(pos))))
		if p == null or p.is_sea:
			failures.append("%s is not on land" % row[0])
			continue
		check_eq(p.get(row[3]), row[4], "%s (%s) %s" % [row[0], p.name, row[3]])


func test_every_kind_occurs() -> void:
	var world := _load()
	var seen := {}
	for p: Province in world.ownable_provinces():
		seen[p.topography] = true
		seen[p.vegetation] = true
		seen[p.climate] = true
	for value in Land.TOPOGRAPHY + Land.VEGETATION + Land.CLIMATE:
		check(seen.has(value), "some province is %s" % value)
	check_eq(Land.display("hot_arid"), "Hot arid", "display name")
