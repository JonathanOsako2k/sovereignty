class_name GameClock
extends RefCounted
## Campaign calendar and time control. Pure logic: owns no nodes and never
## renders. The game advances it with real elapsed time; each tick is one day.

signal day_passed
signal month_passed
signal year_passed
signal paused_changed(paused: bool)
signal speed_changed(speed: int)
signal campaign_ended

const MONTH_NAMES := ["January", "February", "March", "April", "May", "June", "July",
	"August", "September", "October", "November", "December"]
## Game days per real second, indexed by speed (index 0 unused).
const DAYS_PER_SECOND := [0.0, 1.0, 3.0, 8.0, 20.0, 60.0]
const MIN_SPEED := 1
const MAX_SPEED := 5
## Upper bound on days processed in one frame so a slow frame cannot cascade.
const MAX_TICKS_PER_FRAME := 8
## Day numbers count from this year's 1 January (day 0).
const EPOCH_YEAR := 1590

var year := 1590
var month := 1
var day := 1
var end_year := 1949
var paused := true
var speed := 2
var ended := false
var _accumulator := 0.0


func set_date(y: int, m: int, d: int) -> void:
	assert(m >= 1 and m <= 12 and d >= 1 and d <= days_in_month(y, m), "invalid date")
	year = y
	month = m
	day = d
	_accumulator = 0.0


func set_paused(value: bool) -> void:
	if ended:
		value = true
	if paused == value:
		return
	paused = value
	if paused:
		_accumulator = 0.0
	paused_changed.emit(paused)


func toggle_pause() -> void:
	set_paused(not paused)


func set_speed(value: int) -> void:
	value = clampi(value, MIN_SPEED, MAX_SPEED)
	if speed == value:
		return
	speed = value
	speed_changed.emit(speed)


## Advances by real elapsed seconds. Returns the number of days processed.
## `can_step`, if given, is asked before each day; returning false holds time
## (the simulation scheduler uses it while a day's work is still running).
func advance(delta: float, can_step := Callable()) -> int:
	if paused or ended:
		return 0
	_accumulator += delta * DAYS_PER_SECOND[speed]
	var ticks := 0
	while _accumulator >= 1.0 and ticks < MAX_TICKS_PER_FRAME and not ended:
		if can_step.is_valid() and not can_step.call():
			break
		_accumulator -= 1.0
		step_day()
		ticks += 1
	# Drop any backlog rather than trying to catch up across later frames.
	_accumulator = minf(_accumulator, 1.0)
	return ticks


## Advances exactly one day. Used by `advance()` and by headless simulations.
func step_day() -> void:
	if ended:
		return
	if year == end_year and month == 12 and day == 31:
		ended = true
		set_paused(true)
		campaign_ended.emit()
		return
	var new_month := false
	var new_year := false
	day += 1
	if day > days_in_month(year, month):
		day = 1
		month += 1
		new_month = true
		if month > 12:
			month = 1
			year += 1
			new_year = true
	day_passed.emit()
	if new_month:
		month_passed.emit()
	if new_year:
		year_passed.emit()


## Days since 1 January of EPOCH_YEAR (that day is 0). Stable across saves, so
## cadences such as "every 7 days" do not depend on when a campaign was loaded.
func day_number() -> int:
	return days_since_epoch(year, month, day)


static func days_since_epoch(y: int, m: int, d: int) -> int:
	var n := 0
	for yy in range(EPOCH_YEAR, y):
		n += 366 if is_leap_year(yy) else 365
	for mm in range(1, m):
		n += days_in_month(y, mm)
	return n + d - 1


func format_date() -> String:
	return "%d %s %d" % [day, MONTH_NAMES[month - 1], year]


func to_dict() -> Dictionary:
	return {"year": year, "month": month, "day": day, "speed": speed, "ended": ended}


## Problems with saved clock data; empty when `load_dict` will accept it.
func check_dict(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("date must be an object")
		return errors
	for key in ["year", "month", "day"]:
		var v: Variant = data.get(key)
		if not ((v is float or v is int) and float(v) == floorf(float(v))):
			errors.append("date %s must be a whole number, got %s" % [key, var_to_str(v)])
	if not errors.is_empty():
		return errors
	var y := int(data.year)
	var m := int(data.month)
	if y < 1 or y > end_year or m < 1 or m > 12 or int(data.day) < 1 or int(data.day) > days_in_month(y, m):
		errors.append("date %d-%d-%d is not a campaign date" % [y, m, int(data.day)])
	return errors


func load_dict(data: Dictionary) -> void:
	set_date(int(data.year), int(data.month), int(data.day))
	speed = clampi(int(data.get("speed", 2)), MIN_SPEED, MAX_SPEED)
	ended = bool(data.get("ended", false))
	paused = true


static func is_leap_year(y: int) -> bool:
	return (y % 4 == 0 and y % 100 != 0) or y % 400 == 0


static func days_in_month(y: int, m: int) -> int:
	match m:
		2:
			return 29 if is_leap_year(y) else 28
		4, 6, 9, 11:
			return 30
		_:
			return 31
