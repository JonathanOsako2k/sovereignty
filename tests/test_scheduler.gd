extends "res://tests/test_case.gd"
## SimulationScheduler: cadences, ordering, budgeted jobs, pause (M3).


func _scheduler() -> SimulationScheduler:
	return SimulationScheduler.new(GameClock.new())


func test_cadences_over_a_year() -> void:
	var s := _scheduler()
	for cadence in SimulationScheduler.Cadence.values():
		s.register(str(cadence), cadence, func() -> void: pass)
	for i in 365:  # 2 January 1590 .. 1 January 1591
		s.clock.step_day()
	check_eq(s.clock.format_date(), "1 January 1591", "date")
	var C := SimulationScheduler.Cadence
	check_eq(s.run_counts[str(C.DAILY)], 365, "daily")
	check_eq(s.run_counts[str(C.WEEKLY)], 52, "weekly")
	check_eq(s.run_counts[str(C.MONTHLY)], 12, "monthly")
	check_eq(s.run_counts[str(C.QUARTERLY)], 4, "quarterly")
	check_eq(s.run_counts[str(C.YEARLY)], 1, "yearly")


func test_weeks_count_from_1590_not_from_loading() -> void:
	var a := _scheduler()
	var b := _scheduler()
	var weeks_a := []
	var weeks_b := []
	a.register("w", SimulationScheduler.Cadence.WEEKLY, func() -> void: weeks_a.append(a.clock.format_date()))
	b.register("w", SimulationScheduler.Cadence.WEEKLY, func() -> void: weeks_b.append(b.clock.format_date()))
	for i in 100:
		a.clock.step_day()
	b.clock.set_date(1590, 3, 3)  # "loaded" mid-campaign
	for i in 100 - GameClock.days_since_epoch(1590, 3, 3):
		b.clock.step_day()
	check_eq(a.clock.format_date(), b.clock.format_date(), "same end date")
	check_eq(weeks_b, weeks_a.slice(weeks_a.size() - weeks_b.size()), "same weekdays")


func test_systems_run_in_registration_order() -> void:
	var s := _scheduler()
	var calls := []
	s.register("a", SimulationScheduler.Cadence.YEARLY, func() -> void: calls.append("a"))
	s.register("b", SimulationScheduler.Cadence.MONTHLY, func() -> void: calls.append("b"))
	s.register("c", SimulationScheduler.Cadence.DAILY, func() -> void: calls.append("c"))
	s.clock.set_date(1590, 12, 31)
	s.clock.step_day()
	check_eq(calls, ["a", "b", "c"], "1 January runs everything in order")


## A job of `slices` steps that records each slice in `calls`.
func _job(slices: int, calls: Array, name: String) -> Callable:
	return func() -> Callable:
		var done := [0]
		return func() -> bool:
			done[0] += 1
			calls.append("%s%d" % [name, done[0]])
			return done[0] >= slices


func test_jobs_hold_the_clock_until_finished() -> void:
	var s := _scheduler()
	var calls := []
	s.register_job("job", SimulationScheduler.Cadence.DAILY, _job(4, calls, "j"))
	s.register("after", SimulationScheduler.Cadence.DAILY, func() -> void: calls.append("after"))
	s.frame_budget_usec = 0  # one slice per frame
	s.clock.set_speed(GameClock.MAX_SPEED)
	s.clock.set_paused(false)
	check_eq(s.process_frame(1.0), 1, "first frame starts a day")
	check(s.is_busy(), "the day's job is unfinished")
	check_eq(calls, ["j1"], "one slice in the first frame")
	var date := s.clock.format_date()
	for frame in 3:
		check_eq(s.process_frame(1.0), 0, "clock holds while busy")
	check_eq(s.clock.format_date(), date, "date unchanged until the day's work is done")
	check_eq(calls, ["j1", "j2", "j3", "j4"], "one slice per frame")
	check(s.is_busy(), "the system after the job still waits")
	check_eq(s.process_frame(1.0), 1, "the last piece runs, then the next day starts")
	check_eq(calls.slice(4), ["after", "j1"], "system after the job ran before the next day")


func test_headless_days_run_jobs_to_completion() -> void:
	var s := _scheduler()
	var calls := []
	s.register_job("job", SimulationScheduler.Cadence.MONTHLY, _job(3, calls, "j"))
	s.clock.set_date(1590, 1, 31)
	s.clock.step_day()
	check_eq(calls, ["j1", "j2", "j3"], "all slices ran within step_day")
	check(not s.is_busy(), "nothing pending")


func test_finish_pending_completes_work() -> void:
	var s := _scheduler()
	var calls := []
	s.register_job("job", SimulationScheduler.Cadence.DAILY, _job(5, calls, "j"))
	s.frame_budget_usec = 0
	s.clock.set_paused(false)
	s.process_frame(1.0)
	check(s.is_busy(), "busy after one frame")
	s.finish_pending()
	check(not s.is_busy() and calls.size() == 5, "finished: %s" % [calls])


func test_pause_stops_everything() -> void:
	var s := _scheduler()
	var runs := [0]
	s.register("d", SimulationScheduler.Cadence.DAILY, func() -> void: runs[0] += 1)
	for frame in 120:
		s.process_frame(1.0 / 60.0)
	check_eq(runs[0], 0, "paused clock runs no systems")
	check_eq(s.clock.format_date(), "1 January 1590", "and no time passes")


func test_speeds_produce_expected_ticks() -> void:
	for speed in range(GameClock.MIN_SPEED, GameClock.MAX_SPEED + 1):
		var s := _scheduler()
		var runs := [0]
		s.register("d", SimulationScheduler.Cadence.DAILY, func() -> void: runs[0] += 1)
		s.clock.set_speed(speed)
		s.clock.set_paused(false)
		for frame in 120:  # two seconds at 60 fps
			s.process_frame(1.0 / 60.0)
		var expected := int(GameClock.DAYS_PER_SECOND[speed] * 2)
		check(absi(runs[0] - expected) <= 1, "speed %d: expected ~%d daily runs, got %d" % [speed, expected, runs[0]])
