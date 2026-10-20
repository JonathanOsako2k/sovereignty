extends SceneTree
## Profiles a campaign in the real game scene, headless: plays as a country
## and reports, per month, the real time of each scheduled system (summed over
## the month's days), of everything else the days did ("other": daily
## listeners such as the forces on the map) and of the frame that follows
## (deferred map, label and panel refreshes).
##   godot --headless --path . --script res://tools/profile/campaign_profile.gd -- --play=ENG --years=12

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args := {"play": "ENG", "years": "12"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var game: Node = load("res://game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._play_as(args.play)
	await process_frame
	var clock: GameClock = game.clock
	var scheduler: SimulationScheduler = game.scheduler
	var end_year := clock.year + int(args.years)
	while clock.year < end_year:
		var t0 := Time.get_ticks_usec()
		var month := clock.month
		var totals := {}  # system -> real time summed over the month's days
		while clock.month == month:
			scheduler.last_usec.clear()
			clock.step_day()
			for name in scheduler.last_usec:
				totals[name] = totals.get(name, 0) + scheduler.last_usec[name]
		var t1 := Time.get_ticks_usec()
		await process_frame
		var t2 := Time.get_ticks_usec()
		var parts := []
		var systems := 0
		for name in totals:
			systems += totals[name]
			if totals[name] > 2000:
				parts.append("%s %d" % [name, totals[name] / 1000])
		parts.append("other %d" % ((t1 - t0 - systems) / 1000))
		print("%d-%02d  days %4d ms  frame %4d ms  | %s" % [clock.year, clock.month, (t1 - t0) / 1000, (t2 - t1) / 1000, ", ".join(parts)])
	quit()
