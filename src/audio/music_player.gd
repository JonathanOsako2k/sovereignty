class_name MusicPlayer
extends Node
## The soundtrack. Tracks live in res://music/<n Age>/<Region>/ (files right
## in an age's folder suit every region). The campaign's date picks the age —
## 1 from 1590, 2 from 1690, 3 from 1750, 4 from 1830, 5 from 1900 — and the
## player's part of the world picks the region folder (any region's music if
## that one has none). One track follows another after a short pause; in an
## age's last years the next age's music creeps in, more often the nearer the
## turn, so the soundtrack moves on gradually. A jump in time (loading a save,
## a new campaign) crossfades at once. An age without music yet borrows the
## nearest earlier age's. Whether music plays is kept in user://settings.cfg.
##
## Music never touches the campaign's random numbers (it has its own).

const ROOT := "res://music"
const AGE_STARTS := [1590, 1690, 1750, 1830, 1900]
const TRANSITION_YEARS := 10.0
const FADE_SECONDS := 4.0
const GAP_SECONDS := Vector2(3.0, 8.0)
const VOLUME_DB := -6.0
const SILENT_DB := -60.0
const AUDIO_EXTENSIONS := ["mp3", "ogg", "wav"]
const SETTINGS_PATH := "user://settings.cfg"
## World region -> music region folders to look for, in order.
const REGION_FOLDERS := {
	"EUR": ["Europe"], "CJK": ["East Asia", "Asia"], "IND": ["South Asia", "India", "Asia"],
	"MECA": ["Middle East", "Asia"], "AFR": ["Africa"], "SEA": ["South East Asia", "Asia"],
	"NAM": ["Americas", "North America"], "SAM": ["Americas", "South America"], "OCE": ["Oceania"], "OTH": [],
}

var enabled := true
var _tracks := {}  # age index -> {region folder ("" = every region): [paths]}
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _year := 1590
var _region := "EUR"
var _playing_age := -1
var _last_path := ""
var _gap: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		enabled = bool(settings.get_value("audio", "music", true))
	_scan()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		player.finished.connect(_on_finished.bind(i))
		add_child(player)
		_players.append(player)
	_gap = Timer.new()
	_gap.one_shot = true
	_gap.timeout.connect(_play_next)
	add_child(_gap)
	if enabled:
		_play_next()


## The music folder: ages by the number their folder starts with.
func _scan() -> void:
	_tracks.clear()
	if not DirAccess.dir_exists_absolute(ROOT):
		return
	for entry: String in ResourceLoader.list_directory(ROOT):
		if not entry.ends_with("/"):
			continue
		var age := entry.get_slice(" ", 0).to_int() - 1
		if age < 0 or age >= AGE_STARTS.size():
			continue
		var regions := {}
		_collect(ROOT + "/" + entry, "", regions)
		for sub: String in ResourceLoader.list_directory(ROOT + "/" + entry):
			if sub.ends_with("/"):
				_collect(ROOT + "/" + entry + sub, sub.trim_suffix("/"), regions)
		if not regions.is_empty():
			_tracks[age] = regions


func _collect(dir: String, region: String, into: Dictionary) -> void:
	for f: String in ResourceLoader.list_directory(dir):
		if f.get_extension().to_lower() in AUDIO_EXTENSIONS:
			if not into.has(region):
				into[region] = []
			into[region].append(dir.path_join(f))


static func age_of(year: int) -> int:
	var age := 0
	for i in AGE_STARTS.size():
		if year >= AGE_STARTS[i]:
			age = i
	return age


func has_music() -> bool:
	return not _tracks.is_empty()


## The age to draw the next track from: this one, or near its end sometimes
## the next; then the nearest age (earlier first) that has music.
func _pick_age() -> int:
	var age := age_of(_year)
	if age + 1 < AGE_STARTS.size():
		var to_next: float = AGE_STARTS[age + 1] - _year
		if to_next <= TRANSITION_YEARS and _rng.randf() < 1.0 - to_next / TRANSITION_YEARS:
			age += 1
	for a in range(age, -1, -1):
		if _tracks.has(a):
			return a
	for a in range(age + 1, AGE_STARTS.size()):
		if _tracks.has(a):
			return a
	return -1


## An age's tracks for the player's region (with those for every region), or
## all of the age's tracks if the region has none.
func _pool(age: int) -> Array:
	var regions: Dictionary = _tracks[age]
	var out := []
	for folder: String in REGION_FOLDERS.get(_region, []):
		if regions.has(folder):
			out.append_array(regions[folder])
			break
	if out.is_empty():
		for folder: String in regions:
			out.append_array(regions[folder])
	elif regions.has(""):
		out.append_array(regions[""])
	return out


func _play_next() -> void:
	if not enabled:
		return
	var age := _pick_age()
	if age < 0:
		return
	var pool := _pool(age)
	if pool.size() > 1:
		pool.erase(_last_path)
	var path: String = pool[_rng.randi_range(0, pool.size() - 1)]
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_last_path = path
	_playing_age = age
	var player := _players[_active]
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	_fade(player, VOLUME_DB)


func _on_finished(index: int) -> void:
	if index == _active and enabled:
		_gap.start(_rng.randf_range(GAP_SECONDS.x, GAP_SECONDS.y))


func _fade(player: AudioStreamPlayer, to_db: float, then_stop := false) -> void:
	var tween := create_tween()
	tween.tween_method(func(v: float): player.volume_db = linear_to_db(maxf(v, 0.001)),
		db_to_linear(player.volume_db), db_to_linear(to_db), FADE_SECONDS)
	if then_stop:
		tween.tween_callback(player.stop)


## The campaign's year moved on: later tracks follow the new age.
func set_year(year: int) -> void:
	_year = year


## A jump in time or place (a new campaign, a loaded save, another country):
## crossfade at once if the music should change.
func jump_to(year: int, region := "") -> void:
	_year = year
	var region_changed := region != "" and region != _region
	if region != "":
		_region = region
	if not enabled:
		return
	var wanted := _pick_age()
	var playing := _players[_active].playing
	if playing and wanted == _playing_age and not region_changed:
		return
	if playing:
		_fade(_players[_active], SILENT_DB, true)
		_active = 1 - _active
	_gap.stop()
	_play_next()


func set_enabled(on: bool) -> void:
	if on == enabled:
		return
	enabled = on
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio", "music", on)
	settings.save(SETTINGS_PATH)
	if on:
		_play_next()
	else:
		_gap.stop()
		for p in _players:
			if p.playing:
				_fade(p, SILENT_DB, true)
