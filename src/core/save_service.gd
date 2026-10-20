class_name SaveService
extends RefCounted
## Versioned, atomic campaign saves (structure.md §12.2).
##
## A save is one file, `<slot>.srt` (the game's own extension; JSON inside): a header (format, schema version,
## world-data version, real-time timestamp, title) and the campaign state.
## Static world data is not saved; a save only loads into the world data it
## was made with: same version and, when the save records one, the same
## fingerprint (an MD5 of the province-id map, which changes whenever provinces
## are renumbered or reshaped, even without a version bump) — or one the world
## data lists as compatible (the map only redrawn, every province kept).
##
## Where: `device_save_dir()` — on Android a folder the player can reach
## (Documents/Sovereignty in shared storage, shown by the Files app and over
## USB), elsewhere `user://saves`.
##
## Writing is atomic: the save goes to `<slot>.tmp.srt`, is read back and
## checked, and only then does the previous save become `<slot>.bak.srt` and
## the new file take its place. Backups and temporary files end in `.srt` too,
## so Android's shared storage treats every file the same way (the startup
## write test uses the same extension). Loading never applies a save
## partially; every problem comes back as a readable diagnostic in `errors`.

const FORMAT := "sovereignty-save"
## Bump whenever the saved layout changes, and add the upgrade step to _migrate().
## 1: first release. 2: diplomacy (subjects, alliances, rivals, opinion).
## 3: economy (country debt and last month's ledger).
## 4: estates, goods, buildings, policies, loans and bankruptcy.
## 5: estate taxes as percentage rates instead of five levels.
## 6: colonisation (colonial policy, colonies in progress).
## 7: armies, navies, wars (military); spending policies in percent (court,
##    minting, forts, army, navy) instead of levels.
const SCHEMA_VERSION := 8
const DEFAULT_DIR := "user://saves"
## Folder name inside the device's Documents (Android).
const DEVICE_FOLDER := "Sovereignty"
## Save files use the game's own extension (user's choice); the content is JSON.
const EXTENSION := ".srt"
const BACKUP_EXTENSION := ".bak.srt"
const TEMP_EXTENSION := ".tmp.srt"
const AUTOSAVE_SLOT := "autosave"

var save_dir := DEFAULT_DIR
## Diagnostics from the last operation (empty after a success).
var errors := PackedStringArray()


func _init(dir := DEFAULT_DIR) -> void:
	save_dir = dir


func path_of(slot: String) -> String:
	return save_dir.path_join(slot + EXTENSION)


func backup_path_of(slot: String) -> String:
	return save_dir.path_join(slot + BACKUP_EXTENSION)


func temp_path_of(slot: String) -> String:
	return save_dir.path_join(slot + TEMP_EXTENSION)


## The save folder as an absolute path on this device, for showing the player.
func folder_path() -> String:
	return ProjectSettings.globalize_path(save_dir)


## Where saves should live on this device. On Android, app-private storage
## (user://) cannot be opened by the player, so saves go to Documents/Sovereignty
## on shared storage (visible in the Files app and over USB) or, failing that,
## the app's own folder on shared storage (Android/data/<package>/files/...,
## reachable over USB) — whichever passes a write, rename and listing test.
## Everywhere else: user://saves.
static func device_save_dir() -> String:
	if OS.get_name() != "Android":
		return DEFAULT_DIR
	for shared in [true, false]:
		var documents := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS, shared)
		if documents != "":
			var dir := documents.path_join(DEVICE_FOLDER)
			if is_usable_dir(dir):
				return dir
	return DEFAULT_DIR


## True if saves can be written, renamed, listed, read and removed in `dir`
## (creating it if needed). Leaves nothing behind.
static func is_usable_dir(dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var first := dir.path_join("write-test-a" + TEMP_EXTENSION)
	var second := dir.path_join("write-test-b" + TEMP_EXTENSION)
	var f := FileAccess.open(first, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("{}")
	f.close()
	var ok := DirAccess.rename_absolute(first, second) == OK \
		and FileAccess.get_file_as_string(second) == "{}" \
		and second.get_file() in DirAccess.get_files_at(dir)
	for path in [first, second]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	return ok and not FileAccess.file_exists(second)


static func is_valid_slot(slot: String) -> bool:
	if slot.is_empty() or slot.length() > 64:
		return false
	for ch in slot:
		if not (ch in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
			return false
	return true


## An unused slot name for a new manual save, e.g. "eng_1760546512".
func new_slot_name(campaign: Campaign) -> String:
	var tag := campaign.world.player_country_id.to_lower()
	var base := "%s_%d" % [tag if is_valid_slot(tag) else "save", int(Time.get_unix_time_from_system())]
	var slot := base
	var n := 2
	while FileAccess.file_exists(path_of(slot)) or FileAccess.file_exists(backup_path_of(slot)):
		slot = "%s_%d" % [base, n]
		n += 1
	return slot


# --- Saving ---------------------------------------------------------------------

func save(campaign: Campaign, slot: String) -> bool:
	errors.clear()
	if not is_valid_slot(slot):
		errors.append("invalid save name '%s'" % slot)
		return false
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		errors.append("cannot create %s (%s)" % [save_dir, error_string(err)])
		return false
	var data := {
		"format": FORMAT,
		"schema_version": SCHEMA_VERSION,
		"world_version": campaign.world.data_version,
		"world_fingerprint": campaign.world.data_fingerprint,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": int(Time.get_unix_time_from_system()),
		"title": campaign.title(),
		"player": campaign.world.player_country_id,
		"country": campaign.player_name(),
		"date_text": campaign.clock.format_date(),
		"campaign": campaign.to_dict(),
	}
	# Full precision so floats come back exactly as they were.
	var text := JSON.stringify(data, "", false, true)
	var path := path_of(slot)
	var tmp := temp_path_of(slot)
	if not _write(tmp, text):
		return false

	# Check what actually reached storage before touching the previous save.
	var written := FileAccess.get_file_as_string(tmp)
	if written != text:
		errors.append("the save was not written completely (%d of %d bytes)" % [written.length(), text.length()])
	else:
		var parsed := _parse(written, tmp)
		if not parsed.is_empty():
			errors.append_array(campaign.check(parsed.campaign))
	if not errors.is_empty():
		DirAccess.remove_absolute(tmp)
		return false

	var backup := backup_path_of(slot)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		err = DirAccess.rename_absolute(path, backup)
		if err != OK:
			errors.append("cannot keep the previous save as a backup (%s)" % error_string(err))
			DirAccess.remove_absolute(tmp)
			return false
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		errors.append("cannot move the new save into place (%s)" % error_string(err))
		if FileAccess.file_exists(backup) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup, path)  # put the previous save back
		return false
	return true


func _write(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		errors.append("cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK:
		errors.append("writing %s failed (%s)" % [path, error_string(err)])
		return false
	return true


# --- Loading --------------------------------------------------------------------

## Reads, checks and migrates a save file without applying it. Returns {} on
## failure, with the reasons in `errors`.
func read(slot: String, from_backup := false) -> Dictionary:
	errors.clear()
	var path := backup_path_of(slot) if from_backup else path_of(slot)
	if not FileAccess.file_exists(path):
		errors.append("there is no save at %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("%s is empty or unreadable (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var data := _parse(text, path)
	return _migrate(data) if not data.is_empty() else data


## Loads a save into the campaign. All or nothing: on failure the campaign is
## unchanged and `errors` says why.
func load_into(campaign: Campaign, slot: String, from_backup := false) -> bool:
	var data := read(slot, from_backup)
	if data.is_empty():
		return false
	var mismatch := _world_mismatch(data, campaign.world.data_version, campaign.world.data_fingerprint,
		campaign.world.compatible_fingerprints)
	if mismatch != "":
		errors.append(mismatch)
		return false
	errors = campaign.restore(data.campaign)
	return errors.is_empty()


func _parse(text: String, path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s is damaged or incomplete (%s)" % [path.get_file(), json.get_error_message()])
		return {}
	var data: Variant = json.data
	if not (data is Dictionary and data.get("format") == FORMAT):
		errors.append("%s is not a Sovereignty save" % path.get_file())
		return {}
	for key in ["schema_version", "world_version", "saved_at"]:
		if not (data.get(key) is float or data.get(key) is int):
			errors.append("%s has no valid %s" % [path.get_file(), key])
	if not data.get("campaign") is Dictionary:
		errors.append("%s has no campaign data" % path.get_file())
	if not errors.is_empty():
		return {}
	var version := int(data.schema_version)
	if version > SCHEMA_VERSION:
		errors.append("%s was saved by a newer version of the game (save format %d; this version reads up to %d)"
			% [path.get_file(), version, SCHEMA_VERSION])
		return {}
	return data


## Upgrades an older save one schema step at a time. Every step is explicit;
## a version without a step is reported, never guessed.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.schema_version)
	while version < SCHEMA_VERSION:
		match version:
			1:
				_upgrade_1_to_2(data)
			2:
				_upgrade_2_to_3(data)
			3:
				_upgrade_3_to_4(data)
			4:
				_upgrade_4_to_5(data)
			5:
				_upgrade_5_to_6(data)
			6:
				_upgrade_6_to_7(data)
			7:
				_upgrade_7_to_8(data)
			_:
				errors.append("save format %d is too old to load (no upgrade to %d)" % [version, version + 1])
				return {}
		version += 1
	data.schema_version = SCHEMA_VERSION
	return data


## Format 1 had no diplomacy: the campaign continues with no treaties,
## rivalries or opinion modifiers.
static func _upgrade_1_to_2(data: Dictionary) -> void:
	data.campaign["diplomacy"] = {"subjects": [], "alliances": [], "marriages": [], "rivals": [],
		"modifiers": [], "envoys": [], "cooldowns": []}


## Format 2 had no economy: countries start debt-free with an empty ledger.
static func _upgrade_2_to_3(data: Dictionary) -> void:
	var countries: Variant = data.campaign.get("world", {}).get("countries", {})
	if countries is Dictionary:
		for tag: String in countries:
			countries[tag]["debt"] = 0.0
			countries[tag]["ledger"] = []


## Format 3 had one debt figure and no estates, goods or policies: the debt
## becomes a single loan at 8 %, policies start at their defaults, and each
## province keeps its 1590 good and divides its people as at the start.
static func _upgrade_3_to_4(data: Dictionary) -> void:
	var world: Dictionary = data.campaign.get("world", {})
	for tag: String in world.get("countries", {}):
		var c: Dictionary = world.countries[tag]
		var debt := float(c.get("debt", 0.0))
		c.erase("debt")
		c["loans"] = [[debt, 0.08, 0]] if debt > 0.0 else []
		c["policies"] = {"taxes": [2, 2, 2, 2, 2], "court": 1, "mint": 0, "forts": 1}
		c["inflation"] = 0.0
		c["satisfaction"] = [50.0, 50.0, 50.0, 50.0, 50.0]
		c["bankrupt_until"] = -1
		c["last_bankruptcy"] = -1
	world["province_fields"] = WorldState.PROVINCE_FIELDS.duplicate()
	for row: Array in world.get("provinces", []):
		row.append_array([null, [], [], [], null])


## Format 4 set each estate's tax as a level (None, Low, Normal, High, Very
## high: 0, ½, 1, 1½, 2 × custom); format 5 keeps the rate in percent.
static func _upgrade_4_to_5(data: Dictionary) -> void:
	var world: Dictionary = data.campaign.get("world", {})
	for tag: String in world.get("countries", {}):
		var policies: Variant = world.countries[tag].get("policies")
		if not (policies is Dictionary and policies.get("taxes") is Array and policies.taxes.size() == Estates.ROLES.size()):
			continue  # validation reports it
		var rates := []
		for i in Estates.ROLES.size():
			var role: String = Estates.ROLES[i]
			var level := clampi(int(policies.taxes[i]), 0, 4)
			rates.append(mini(roundi(Estates.CUSTOMARY_TAX[role] * level * 0.5), Estates.TAX_MAX[role]))
		policies.taxes = rates


## Format 5 had no colonisation: no colonies under way, and each country's
## colonial policy as in the scenario (null = the scenario's on restore).
static func _upgrade_5_to_6(data: Dictionary) -> void:
	var world: Dictionary = data.campaign.get("world", {})
	for tag: String in world.get("countries", {}):
		var policies: Variant = world.countries[tag].get("policies")
		if policies is Dictionary:
			policies["colonial"] = null
	world["province_fields"] = WorldState.PROVINCE_FIELDS.duplicate()
	for row: Array in world.get("provinces", []):
		row.append_array(["", 0.0])


## Format 6 had no armies (forces as at the start, made on restore) and set
## court, minting and forts as levels: now percentages (army and navy at full
## maintenance).
static func _upgrade_6_to_7(data: Dictionary) -> void:
	data.campaign["military"] = null
	var world: Dictionary = data.campaign.get("world", {})
	for tag: String in world.get("countries", {}):
		var policies: Variant = world.countries[tag].get("policies")
		if not policies is Dictionary:
			continue
		policies["court"] = [50, 100, 160, 240][clampi(int(policies.get("court", 1)), 0, 3)]
		policies["mint"] = [0, 5, 10, 20][clampi(int(policies.get("mint", 0)), 0, 3)]
		policies["forts"] = [50, 100, 150][clampi(int(policies.get("forts", 1)), 0, 2)]
		policies["army"] = 100
		policies["navy"] = 100


## Format 8: cores and claims (as at the start), and armies that know the
## fleet carrying them and whether they are falling back.
static func _upgrade_7_to_8(data: Dictionary) -> void:
	data.campaign["claims"] = null
	var military: Variant = data.campaign.get("military")
	if military is Dictionary and military.get("armies") is Array:
		for row: Variant in military.armies:
			if row is Array and row.size() == 10:
				row.append_array([0, false])


## Fingerprints of earlier drawings of the map that saves may still carry
## (the game sets them from the world data).
var compatible_fingerprints: Array = []


static func _world_mismatch(data: Dictionary, world_version: int, fingerprint := "", compatible: Array = []) -> String:
	var saved := int(data.world_version)
	if saved != world_version:
		return "made for world data version %d; this game uses version %d" % [saved, world_version]
	var saved_print := str(data.get("world_fingerprint", ""))
	if saved_print != "" and fingerprint != "" and saved_print != fingerprint and not saved_print in compatible:
		return "made with a different build of the world map (version %d was regenerated since)" % saved
	return ""


# --- Listing and housekeeping -------------------------------------------------------

## Saves on disk, newest first. Each entry: slot, title, player, country,
## date_text, saved_at (unix seconds), ok (loadable), error (why not),
## has_backup, backup_ok.
## Damaged saves are listed too, so the player can see what happened and fall
## back to the backup copy.
func list_saves(world_version: int, fingerprint := "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(save_dir)
	if dir == null:
		errors.clear()
		return result
	var slots := {}
	for file in dir.get_files():
		if file.ends_with(TEMP_EXTENSION):
			continue  # an interrupted write; the next save replaces it
		var slot := file.trim_suffix(BACKUP_EXTENSION) if file.ends_with(BACKUP_EXTENSION) else file.trim_suffix(EXTENSION)
		if file.ends_with(EXTENSION) and is_valid_slot(slot):
			slots[slot] = true
	for slot: String in slots:
		var info := {
			"slot": slot, "title": slot, "player": "", "country": slot, "date_text": "", "saved_at": 0, "ok": false, "error": "",
			"has_backup": FileAccess.file_exists(backup_path_of(slot)), "backup_ok": false,
		}
		var data := read(slot) if FileAccess.file_exists(path_of(slot)) else {}
		if FileAccess.file_exists(path_of(slot)) and data.is_empty():
			info.error = errors[0] if not errors.is_empty() else "unreadable"
		elif data.is_empty():
			info.error = "the save is missing (only its backup exists)"
		else:
			_fill_info(info, data)
			info.error = _world_mismatch(data, world_version, fingerprint, compatible_fingerprints)
			info.ok = info.error == ""
		if info.has_backup:
			var backup := read(slot, true)
			info.backup_ok = not backup.is_empty() and _world_mismatch(backup, world_version, fingerprint, compatible_fingerprints) == ""
			if not info.ok and info.backup_ok:
				_fill_info(info, backup)
		result.append(info)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.saved_at > b.saved_at if a.saved_at != b.saved_at else a.slot < b.slot)
	errors.clear()
	return result


static func _fill_info(info: Dictionary, data: Dictionary) -> void:
	info.title = str(data.get("title", info.slot))
	info.player = str(data.get("player", ""))
	info.country = str(data.get("country", info.title))
	info.date_text = str(data.get("date_text", ""))
	info.saved_at = int(data.get("saved_at", 0))


## The newest loadable save, or {} if there is none.
func latest_save(world_version: int, fingerprint := "") -> Dictionary:
	for info in list_saves(world_version, fingerprint):
		if info.ok:
			return info
	return {}


## Removes a save and its backup. Returns false if anything could not be removed.
func delete(slot: String) -> bool:
	errors.clear()
	if not is_valid_slot(slot):
		errors.append("invalid save name '%s'" % slot)
		return false
	for path in [path_of(slot), backup_path_of(slot), temp_path_of(slot)]:
		if FileAccess.file_exists(path):
			var err := DirAccess.remove_absolute(path)
			if err != OK:
				errors.append("cannot delete %s (%s)" % [path.get_file(), error_string(err)])
	return errors.is_empty()


## Human-readable local time of a save, e.g. "15 Oct 2026, 18:42".
static func format_timestamp(unix_seconds: int) -> String:
	if unix_seconds <= 0:
		return "unknown time"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var t := Time.get_datetime_dict_from_unix_time(unix_seconds + bias * 60)
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %d, %02d:%02d" % [t.day, MONTHS[t.month - 1], t.year, t.hour, t.minute]
