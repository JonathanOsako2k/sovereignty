extends "res://tests/test_case.gd"
## Map modes: the bottom bar's groups and the values written on the map.


func test_every_mode_sits_in_one_group() -> void:
	var seen := {}
	for group: Array in MapModes.GROUPS:
		check(not group[1].is_empty(), "group %s has modes" % group[0])
		for mode in group[1]:
			check(not seen.has(mode), "%s in one group only" % MapModes.NAMES[mode])
			seen[mode] = true
	for mode in MapModes.NAMES:
		check(seen.has(mode), "%s has a group" % MapModes.NAMES[mode])
		check_eq(mode in MapModes.GROUPS[MapModes.group_of(mode)][1], true, "group_of(%s)" % MapModes.NAMES[mode])


func test_info_modes_write_values_on_provinces() -> void:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	var c := Campaign.new(world)
	var e := EconomySystem.new(c)
	var paris := world.province_near(48.86, 2.35)
	check_eq(MapModes.info_text(paris, MapModes.Mode.CLIMATE), Land.display(paris.climate), "climate")
	check_eq(MapModes.info_text(paris, MapModes.Mode.TOPOGRAPHY), Land.display(paris.topography), "topography")
	check_eq(MapModes.info_text(paris, MapModes.Mode.VEGETATION), Land.display(paris.vegetation), "vegetation")
	check(MapModes.info_text(paris, MapModes.Mode.GOODS).begins_with(Goods.name_of(paris.resource)), "goods")
	check(MapModes.info_text(paris, MapModes.Mode.ECONOMY, e).ends_with("ducats"), "output value")
	check(MapModes.info_text(paris, MapModes.Mode.POPULATION) != "", "population")
	check_eq(MapModes.info_text(paris, MapModes.Mode.POLITICAL), "", "political shows names only")
	for mode in MapModes.INFO_MODES:
		check_eq(MapModes.info_text(world.sea_tiles()[0], mode, e), "", "nothing written on the sea")
	# A manufactory shows what it makes.
	var jingdezhen: Province = null
	for p: Province in world.ownable_provinces():
		if "kilns" in p.buildings:
			jingdezhen = p
	check(jingdezhen != null and MapModes.info_text(jingdezhen, MapModes.Mode.GOODS) == "Kaolin → Porcelain", "kaolin to porcelain")
	check_eq(MapModes.compact_number(313100), "313k", "thousands")
	check_eq(MapModes.compact_number(1234567), "1.2M", "millions")
	check_eq(MapModes.compact_number(950), "950", "small")
