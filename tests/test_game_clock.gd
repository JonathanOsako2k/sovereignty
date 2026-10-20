extends "res://tests/test_case.gd"


func test_starts_paused_on_1_january_1590() -> void:
	var c := GameClock.new()
	check(c.paused, "clock should start paused")
	check_eq(c.format_date(), "1 January 1590")


func test_paused_clock_does_not_advance() -> void:
	var c := GameClock.new()
	check_eq(c.advance(10.0), 0)
	check_eq(c.format_date(), "1 January 1590")


func test_speed_controls_days_per_second() -> void:
	for speed in range(GameClock.MIN_SPEED, GameClock.MAX_SPEED + 1):
		var c := GameClock.new()
		c.set_speed(speed)
		c.set_paused(false)
		var days := 0
		for frame in 60:  # one second at 60 fps
			days += c.advance(1.0 / 60.0)
		var expected: int = int(GameClock.DAYS_PER_SECOND[speed])
		check(absi(days - expected) <= 1, "speed %d: expected ~%d days, got %d" % [speed, expected, days])


func test_ticks_per_frame_are_bounded() -> void:
	var c := GameClock.new()
	c.set_speed(GameClock.MAX_SPEED)
	c.set_paused(false)
	check_eq(c.advance(5.0), GameClock.MAX_TICKS_PER_FRAME, "a 5 s frame")
	check(c.advance(0.0) <= 1, "backlog should be dropped, not carried over")


func test_month_and_year_rollover_signals() -> void:
	var c := GameClock.new()
	c.set_date(1590, 12, 30)
	var months := [0]
	var years := [0]
	c.month_passed.connect(func(): months[0] += 1)
	c.year_passed.connect(func(): years[0] += 1)
	c.step_day()
	check_eq(months[0], 0, "31 Dec is not a new month")
	c.step_day()
	check_eq(c.format_date(), "1 January 1591")
	check_eq(months[0], 1)
	check_eq(years[0], 1)


func test_gregorian_leap_years() -> void:
	check(GameClock.is_leap_year(1600), "1600 is a leap year")
	check(not GameClock.is_leap_year(1700), "1700 is not a leap year")
	check(GameClock.is_leap_year(1704), "1704 is a leap year")
	check_eq(GameClock.days_in_month(1600, 2), 29)
	check_eq(GameClock.days_in_month(1700, 2), 28)


func test_full_year_has_correct_day_count() -> void:
	var c := GameClock.new()
	c.set_date(1600, 1, 1)
	var days := [0]
	c.day_passed.connect(func(): days[0] += 1)
	while c.year == 1600:
		c.step_day()
	check_eq(days[0], 366)


func test_campaign_ends_after_1949() -> void:
	var c := GameClock.new()
	c.set_date(1949, 12, 30)
	c.set_paused(false)
	var ended := [false]
	c.campaign_ended.connect(func(): ended[0] = true)
	c.step_day()
	c.step_day()
	check(ended[0], "campaign_ended should fire")
	check_eq(c.format_date(), "31 December 1949")
	check(c.paused, "clock pauses at the end")
	c.set_paused(false)
	check(c.paused, "cannot unpause an ended campaign")


func test_serialisation_round_trip() -> void:
	var a := GameClock.new()
	a.set_date(1702, 3, 14)
	a.set_speed(4)
	var b := GameClock.new()
	b.load_dict(a.to_dict())
	check_eq(b.format_date(), "14 March 1702")
	check_eq(b.speed, 4)
	check(b.paused, "loaded clocks start paused")
