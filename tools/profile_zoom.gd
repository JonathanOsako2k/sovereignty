extends SceneTree
## Zoom performance probe: loads the game, holds still at several zoom levels
## and zooms continuously, printing frame time, the script time spent updating
## the view, draw calls and primitives. Needs a window (not --headless).
##   godot --path . --script res://tools/profile_zoom.gd -- [--at=lat,lon]

const ZOOMS := [0.3, 0.7, 1.2, 2.0, 3.0, 4.5, 6.5]


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://game.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await process_frame
	var camera: MapCamera = game.map_camera
	var world: WorldState = game.world
	var at := Vector2(50.0, 8.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var ll := a.trim_prefix("--at=").split(",")
			at = Vector2(float(ll[0]), float(ll[1]))
	var target := world.latlon_to_map(at.x, at.y)

	print("zoom   frame_ms  draw_calls  primitives  objects")
	for z: float in ZOOMS:
		camera.focus_on(target, z)
		for i in 20:
			await process_frame
		var t := Time.get_ticks_usec()
		for i in 40:
			await process_frame
		var frame_ms := (Time.get_ticks_usec() - t) / 40000.0
		print("%-6.2f %8.2f  %10d  %10d  %7d" % [z, frame_ms,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])

	# Continuous zoom in and back out, like a pinch or the mouse wheel.
	camera.focus_on(target, 0.3)
	for i in 10:
		await process_frame
	var update_us := 0
	var frames := 0
	var worst_ms := 0.0
	var worst_update_ms := 0.0
	var worst_at := 0.0
	var t0 := Time.get_ticks_usec()
	for direction in [1.035, 1.0 / 1.035, 1.035, 1.0 / 1.035]:
		for i in 90:
			var u := Time.get_ticks_usec()
			camera.zoom_by(direction)
			var spent := Time.get_ticks_usec() - u
			update_us += spent
			worst_update_ms = maxf(worst_update_ms, spent / 1000.0)
			var f := Time.get_ticks_usec()
			await process_frame
			var frame_ms := (Time.get_ticks_usec() - f) / 1000.0
			if frame_ms > worst_ms:
				worst_ms = frame_ms
				worst_at = camera.zoom.x
			if frame_ms > 20.0:
				print("  slow frame %.1f ms at zoom %.2f (pass %d)" % [frame_ms, camera.zoom.x, frames / 90 + 1])
			frames += 1
	print("continuous zoom: %.2f ms/frame avg, worst frame %.2f ms (at zoom %.2f), view-update script %.2f ms avg / %.2f ms worst" % [
		(Time.get_ticks_usec() - t0) / 1000.0 / frames, worst_ms, worst_at, update_us / 1000.0 / frames, worst_update_ms])

	# Pan across Europe while zoomed in: tiles and names stream in and out.
	camera.focus_on(target, 3.0)
	for i in 20:
		await process_frame
	var pan_worst := 0.0
	var p0 := Time.get_ticks_usec()
	for i in 120:
		var f := Time.get_ticks_usec()
		camera.focus_on(camera.position + Vector2(12.0, 2.0 if i < 60 else -2.0))
		await process_frame
		pan_worst = maxf(pan_worst, (Time.get_ticks_usec() - f) / 1000.0)
	print("pan at zoom 3: %.2f ms/frame avg, worst %.2f ms" % [(Time.get_ticks_usec() - p0) / 1000.0 / 120, pan_worst])
	quit()
