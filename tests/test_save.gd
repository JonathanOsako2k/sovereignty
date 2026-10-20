extends "res://tests/test_case.gd"
## Campaign state, save files and their failure modes (structure.md §12).

const DIR := "user://test_saves"


func _campaign() -> Campaign:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	return Campaign.new(world)


func _service() -> SaveService:
	var service := SaveService.new(DIR)
	_clean()
	return service


func _clean() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR.path_join(file))
		DirAccess.remove_absolute(DIR)


## A little play: time, ownership, occupation, money, unrest, randomness.
func _play(c: Campaign) -> void:
	for i in 75:
		c.clock.step_day()
	var w := c.world
	w.transfer_province(w.province_near(50.85, 4.35).id, "FRA")  # Brussels ceded to France
	w.set_controller(w.province_near(48.86, 2.35).id, "SPA")  # Paris occupied by Spain
	w.transfer_province(w.province_near(37.0, -76.5).id, "ENG")  # Virginia colonised
	var eng := w.get_country("ENG")
	eng.treasury = 123.456789012345
	eng.stability = 2
	var london := w.province_near(51.51, -0.13)
	london.unrest = 3.25
	london.add_people("commoners", 1234)
	w.set_player_country("FRA")
	for i in 17:
		c.rng.randf()


## First difference between two campaign dictionaries, or "" when equal.
func _diff(a: Dictionary, b: Dictionary) -> String:
	for key in ["date", "random"]:
		if a[key] != b[key]:
			return "%s: %s vs %s" % [key, a[key], b[key]]
	var wa: Dictionary = a.world
	var wb: Dictionary = b.world
	if wa.player != wb.player:
		return "player %s vs %s" % [wa.player, wb.player]
	for tag: String in wa.countries:
		if wa.countries[tag] != wb.countries.get(tag):
			return "country %s: %s vs %s" % [tag, wa.countries[tag], wb.countries.get(tag)]
	if wa.provinces.size() != wb.provinces.size():
		return "%d vs %d province rows" % [wa.provinces.size(), wb.provinces.size()]
	for i in wa.provinces.size():
		if wa.provinces[i] != wb.provinces[i]:
			return "province row %s vs %s" % [wa.provinces[i], wb.provinces[i]]
	return "" if a == b else "dictionaries differ"


func _rewrite(service: SaveService, slot: String, edit: Callable) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(service.path_of(slot)))
	edit.call(data)
	var f := FileAccess.open(service.path_of(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false, true))
	f.close()


func test_campaign_state_round_trips_through_json() -> void:
	var c := _campaign()
	_play(c)
	var before := c.to_dict()
	var copy: Dictionary = JSON.parse_string(JSON.stringify(before, "", false, true))
	var other := _campaign()
	var errors := other.restore(copy)
	check(errors.is_empty(), "restore: %s" % [errors])
	check_eq(_diff(other.to_dict(), before), "", "restored state")


func test_save_then_load_restores_identical_world() -> void:
	var service := _service()
	var a := _campaign()
	_play(a)
	check(service.save(a, "slot1"), "save: %s" % [service.errors])
	var b := _campaign()
	check(service.load_into(b, "slot1"), "load: %s" % [service.errors])
	check_eq(_diff(b.to_dict(), a.to_dict()), "", "state after load")
	var paris := b.world.province_near(48.86, 2.35)
	check(paris.owner_id == "FRA" and paris.controller_id == "SPA", "occupation survives")
	check_eq(b.world.player_country_id, "FRA", "player survives")
	check_eq(b.clock.format_date(), a.clock.format_date(), "date survives")
	check(b.clock.paused, "a loaded campaign starts paused")
	check_eq(b.rng.randf(), a.rng.randf(), "the random stream continues identically")
	check(not FileAccess.file_exists(service.temp_path_of("slot1")), "no temp file left")
	check_eq(Array(DirAccess.get_files_at(DIR)), ["slot1.srt"], "only the save itself on disk")
	_clean()


func test_save_carries_versions_and_timestamp() -> void:
	var service := _service()
	var c := _campaign()
	check(service.save(c, "versions"), "save: %s" % [service.errors])
	var data := service.read("versions")
	check_eq(data.get("format"), SaveService.FORMAT, "format tag")
	check_eq(int(data.get("schema_version", -1)), SaveService.SCHEMA_VERSION, "schema version")
	check_eq(int(data.get("world_version", -1)), c.world.data_version, "world data version")
	check(int(data.get("saved_at", 0)) > 1_700_000_000, "real-time timestamp")
	check("England" in str(data.get("title")) and "1590" in str(data.get("title")), "title: %s" % data.get("title"))
	check_eq(data.get("world_fingerprint"), c.world.data_fingerprint, "world fingerprint")
	check_eq(c.world.data_fingerprint.length(), 32, "fingerprint is an MD5")
	_clean()


func test_saving_again_keeps_the_previous_save_as_backup() -> void:
	var service := _service()
	var c := _campaign()
	check(service.save(c, "slot"), "first save")
	var first := c.to_dict()
	_play(c)
	check(service.save(c, "slot"), "second save")
	check(FileAccess.file_exists(service.backup_path_of("slot")), "backup exists")
	var from_backup := _campaign()
	_play(from_backup)
	check(service.load_into(from_backup, "slot", true), "backup loads: %s" % [service.errors])
	check_eq(_diff(from_backup.to_dict(), first), "", "backup holds the previous save")
	_clean()


func test_damaged_save_reports_and_leaves_campaign_untouched() -> void:
	var service := _service()
	var c := _campaign()
	service.save(c, "slot")
	_play(c)
	service.save(c, "slot")
	# Simulate a write interrupted half way (e.g. the phone died).
	var text := FileAccess.get_file_as_string(service.path_of("slot"))
	var f := FileAccess.open(service.path_of("slot"), FileAccess.WRITE)
	f.store_string(text.left(text.length() / 2))
	f.close()
	var target := _campaign()
	var before := target.to_dict()
	check(not service.load_into(target, "slot"), "damaged save is refused")
	check(service.errors.size() > 0 and "damaged" in service.errors[0], "diagnostic: %s" % [service.errors])
	check_eq(_diff(target.to_dict(), before), "", "campaign unchanged after failed load")
	var listed := service.list_saves(c.world.data_version)
	check_eq(listed.size(), 1, "listed once")
	if listed.size() == 1:
		check(not listed[0].ok and listed[0].error != "", "listed as damaged")
		check(listed[0].has_backup and listed[0].backup_ok, "backup offered")
	check(service.load_into(target, "slot", true), "backup still loads: %s" % [service.errors])
	_clean()


func test_unknown_ids_produce_diagnostics() -> void:
	var service := _service()
	var c := _campaign()
	service.save(c, "bad")
	_rewrite(service, "bad", func(data: Dictionary) -> void:
		var rows: Array = data.campaign.world.provinces
		rows.append([999999, "ENG", "ENG", 100, 1, 0.0, null, [], [], [], null, "", 0.0])
		rows[0][1] = "XXX"
		data.campaign.world.countries["ZZZ"] = data.campaign.world.countries["ENG"]
		data.campaign.world.countries["FRA"].capital = 424242)
	var target := _campaign()
	var before := target.to_dict()
	check(not service.load_into(target, "bad"), "invalid save is refused")
	var text := "\n".join(service.errors)
	check("unknown province id 999999" in text, "unknown province reported: %s" % text)
	check("unknown owner 'XXX'" in text, "unknown owner reported: %s" % text)
	check("unknown country 'ZZZ'" in text, "unknown country reported: %s" % text)
	check("capital 424242" in text, "unknown capital reported: %s" % text)
	check_eq(_diff(target.to_dict(), before), "", "campaign unchanged")
	_clean()


func test_out_of_range_values_are_rejected() -> void:
	var c := _campaign()
	var state := c.to_dict()
	state.world.provinces[0][3] = -5
	state.world.countries["ENG"].stability = 9
	state.date.month = 13
	var errors := c.restore(state)
	var text := "\n".join(errors)
	check("population" in text, "negative population: %s" % text)
	check("stability" in text, "stability range: %s" % text)
	check("not a campaign date" in text, "invalid date: %s" % text)


func test_restore_is_all_or_nothing() -> void:
	var c := _campaign()
	var before := c.to_dict()
	var state := c.to_dict()
	# Passes field checks but leaves France with a capital it does not own.
	state.world.countries["FRA"].capital = c.world.province_near(40.42, -3.70).id
	state.world.provinces[5][4] = 7
	var errors := c.restore(state)
	check(errors.size() > 0 and "does not own its capital" in errors[0], "inconsistent state rejected: %s" % [errors])
	check_eq(_diff(c.to_dict(), before), "", "nothing was applied")


func test_newer_or_foreign_saves_are_refused_clearly() -> void:
	var service := _service()
	var c := _campaign()
	service.save(c, "future")
	_rewrite(service, "future", func(data: Dictionary) -> void: data.schema_version = 99)
	check(not service.load_into(c, "future"), "newer schema refused")
	check(service.errors.size() > 0 and "newer version" in service.errors[0], "diagnostic: %s" % [service.errors])

	service.save(c, "oldmap")
	_rewrite(service, "oldmap", func(data: Dictionary) -> void: data.world_version = 1)
	check(not service.load_into(c, "oldmap"), "other world version refused")
	check(service.errors.size() > 0 and "world data version 1" in service.errors[0], "diagnostic: %s" % [service.errors])

	service.save(c, "regenerated")
	_rewrite(service, "regenerated", func(data: Dictionary) -> void: data.world_fingerprint = "0123456789abcdef0123456789abcdef")
	check(not service.load_into(c, "regenerated"), "same version, different map refused")
	check(service.errors.size() > 0 and "different build" in service.errors[0], "diagnostic: %s" % [service.errors])
	var listed := service.list_saves(c.world.data_version, c.world.data_fingerprint)
	check(listed.filter(func(i: Dictionary) -> bool: return i.slot == "regenerated" and not i.ok).size() == 1, "listed as not loadable")

	var f := FileAccess.open(service.path_of("junk"), FileAccess.WRITE)
	f.store_string("{\"hello\": 1}")
	f.close()
	check(not service.load_into(c, "junk"), "foreign JSON refused")
	check(service.errors.size() > 0 and "not a Sovereignty save" in service.errors[0], "diagnostic: %s" % [service.errors])
	_clean()


func test_saves_from_an_earlier_drawing_of_the_map_load() -> void:
	var data := {"world_version": 7, "world_fingerprint": "old-drawing"}
	check(SaveService._world_mismatch(data, 7, "new-drawing") != "", "a different map is refused")
	check_eq(SaveService._world_mismatch(data, 7, "new-drawing", ["old-drawing"]), "",
		"the same map redrawn (listed as compatible) loads")
	var world := WorldLoader.new().load_world()
	check(world.compatible_fingerprints is Array, "the world lists its compatible drawings")


func test_list_saves_newest_first_and_delete() -> void:
	var service := _service()
	var c := _campaign()
	service.save(c, "older")
	_rewrite(service, "older", func(data: Dictionary) -> void: data.saved_at = 1_700_000_000)
	_play(c)
	service.save(c, "newer")
	var listed := service.list_saves(c.world.data_version)
	check_eq(listed.map(func(i: Dictionary) -> String: return i.slot), ["newer", "older"], "newest first")
	check(listed[0].ok and "France" in listed[0].title, "title from header: %s" % listed[0].title)
	check_eq(service.latest_save(c.world.data_version).get("slot"), "newer", "latest save")
	check(service.delete("newer"), "delete")
	check_eq(service.list_saves(c.world.data_version).size(), 1, "one left")
	check(not service.is_valid_slot("../evil"), "slot names cannot escape the save folder")
	_clean()


func test_save_folder_is_reachable() -> void:
	# Desktop keeps user://; Android picks a shared folder (not testable here).
	if OS.get_name() != "Android":
		check_eq(SaveService.device_save_dir(), SaveService.DEFAULT_DIR, "desktop save folder")
	check(SaveService.is_usable_dir(DIR), "the write test passes in a writable folder")
	check_eq(Array(DirAccess.get_files_at(DIR)), [], "the write test leaves nothing behind")
	check(not SaveService.new(DIR).folder_path().begins_with("user://"), "folder shown as a real path")
	_clean()


func test_interrupted_write_is_ignored() -> void:
	var service := _service()
	var c := _campaign()
	service.save(c, "slot")
	var f := FileAccess.open(service.temp_path_of("slot"), FileAccess.WRITE)
	f.store_string("{\"format\": \"sovereignty-sa")  # the app died mid-write
	f.close()
	var listed := service.list_saves(c.world.data_version)
	check(listed.size() == 1 and listed[0].ok, "only the real save is listed: %s" % [listed])
	check(service.save(c, "slot"), "the next save replaces the leftover: %s" % [service.errors])
	check(not FileAccess.file_exists(service.temp_path_of("slot")), "leftover gone")
	_clean()


func test_new_campaign_starts_from_the_scenario() -> void:
	var c := _campaign()
	var initial := c.to_dict()
	_play(c)
	var errors := c.start_new("SPA", 77)
	check(errors.is_empty(), "start_new: %s" % [errors])
	check_eq(c.world.player_country_id, "SPA", "player")
	check_eq(c.clock.format_date(), "1 January 1590", "date")
	check_eq(c.rng.get_seed(), 77, "seed")
	initial.world.player = "SPA"
	initial.random = c.rng.to_dict()
	check_eq(_diff(c.to_dict(), initial), "", "world back at the scenario start")
