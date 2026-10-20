class_name SimulationScheduler
extends RefCounted
## Runs simulation systems on their game-time cadence (structure.md §5.2) and
## is the only thing that moves the campaign forward in time.
##
## Each game day the clock ticks, the scheduler runs the systems due that day
## in registration order, so the same state and seed always give the same
## result. Cadences: daily; weekly (every 7th day counted from 1 January 1590,
## so loading a save never shifts the week); monthly on the 1st; quarterly on
## 1 January, April, July and October; yearly on 1 January. Monthly and yearly
## systems may name a later day of the month instead: heavy systems spread over
## the first days run in separate frames (nothing runs between them, so the
## outcome is the same as on one day, in the same order).
##
## Heavy systems can register as jobs: a job is split into slices and runs
## across frames within a time budget, and the clock holds still until all of
## that day's work has finished; systems due after a job wait for it. The game
## stays responsive during a long tick, and the outcome does not depend on the
## frame rate. Outside `process_frame` (a headless simulation calling
## `clock.step_day()` directly) every day's work runs to completion at once.

signal day_completed

enum Cadence { DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY }

## Real time the scheduler may spend on jobs per frame.
const FRAME_BUDGET_USEC := 4000

var clock: GameClock
var frame_budget_usec := FRAME_BUDGET_USEC
## Times each system or job has run, by name.
var run_counts: Dictionary = {}
## Real time each system or job took on its last run, in microseconds (jobs:
## summed over their slices) — for profiling.
var last_usec: Dictionary = {}

var _systems: Array[Dictionary] = []  # {name, cadence, run: Callable, job: bool}
## The day's work still to do, in order: {name, run: Callable, job: bool,
## step: Callable}. A job's step does one slice and returns true when done.
var _pending: Array[Dictionary] = []
## Real-time deadline for work in the current frame; -1 = no limit.
var _deadline := -1


func _init(p_clock: GameClock) -> void:
	clock = p_clock
	clock.day_passed.connect(_on_day_passed)


## A system that runs to completion on its days: `run` takes no arguments.
## `day`: the day of the month a monthly or yearly system runs on.
func register(name: String, cadence: Cadence, run: Callable, day := 1) -> void:
	_add(name, cadence, run, false, day)


## A system split into slices: `start` is called on its days and returns a
## step Callable; the step is called (possibly over several frames) until it
## returns true.
func register_job(name: String, cadence: Cadence, start: Callable) -> void:
	_add(name, cadence, start, true)


func unregister(name: String) -> void:
	for i in range(_systems.size() - 1, -1, -1):
		if _systems[i].name == name:
			_systems.remove_at(i)


func _add(name: String, cadence: Cadence, run: Callable, job: bool, day := 1) -> void:
	assert(not _systems.any(func(s: Dictionary) -> bool: return s.name == name), "duplicate system " + name)
	_systems.append({"name": name, "cadence": cadence, "run": run, "job": job, "day": day})
	run_counts[name] = 0


static func is_due(cadence: Cadence, year: int, month: int, day: int, day_number: int, on_day := 1) -> bool:
	match cadence:
		Cadence.DAILY:
			return true
		Cadence.WEEKLY:
			return day_number % 7 == 0
		Cadence.MONTHLY:
			return day == on_day
		Cadence.QUARTERLY:
			return day == 1 and (month - 1) % 3 == 0
		Cadence.YEARLY:
			return day == on_day and month == 1
	return false


## True while a job started on an earlier tick is still running; the clock
## does not advance meanwhile.
func is_busy() -> bool:
	return not _pending.is_empty()


## Per-frame entry point: continues unfinished jobs within the frame budget,
## then lets the clock advance by real time (holding it whenever a new day
## leaves work unfinished).
func process_frame(delta: float) -> int:
	_deadline = Time.get_ticks_usec() + frame_budget_usec
	_run_pending()
	var days := 0
	if not is_busy():
		days = clock.advance(delta, func() -> bool: return not is_busy())
	_deadline = -1
	return days


## Runs all unfinished work to completion now (before saving, for instance,
## so a save never captures half a day).
func finish_pending() -> void:
	var saved := _deadline
	_deadline = -1
	_run_pending()
	_deadline = saved


## Works through the queue until it is empty or the frame's time is up. At
## least one piece of work always runs, so jobs progress on every frame.
func _run_pending() -> void:
	while not _pending.is_empty():
		var work: Dictionary = _pending[0]
		var done := true
		var started := Time.get_ticks_usec()
		if not work.job:
			work.run.call()
		else:
			if not work.step.is_valid():
				work.step = work.run.call()  # the job starts when its turn comes
				last_usec[work.name] = 0
			done = work.step.call()
		var took := Time.get_ticks_usec() - started
		last_usec[work.name] = took if not work.job else last_usec.get(work.name, 0) + took
		if done:
			_pending.pop_front()
			if _pending.is_empty():
				day_completed.emit()
		if _deadline >= 0 and Time.get_ticks_usec() >= _deadline:
			return


func _on_day_passed() -> void:
	var n := clock.day_number()
	var any := false
	for s in _systems:
		if is_due(s.cadence, clock.year, clock.month, clock.day, n, s.day):
			run_counts[s.name] += 1
			_pending.append({"name": s.name, "run": s.run, "job": s.job, "step": Callable()})
			any = true
	if any:
		_run_pending()
	elif _pending.is_empty():
		day_completed.emit()
