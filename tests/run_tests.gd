extends SceneTree
## Headless test runner. Exit code is non-zero when any test fails.
##   godot --headless --path . --script res://tests/run_tests.gd
##
## A runtime script error (e.g. calling a method on null) aborts a test
## method without an assertion failing, so the runner also listens to the
## engine's error log and fails any test during which a script error occurred.
## Errors reported with push_error (expected in some tests) do not count.

const TEST_DIR := "res://tests/"


class ScriptErrorLog extends Logger:
	var errors := PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_mutex.lock()
		errors.append("script error: %s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := errors
		errors = PackedStringArray()
		_mutex.unlock()
		return out


func _initialize() -> void:
	_run()


func _run() -> void:
	# The root only enters the tree after _initialize; wait for it so tests
	# that instantiate scenes get their nodes' _ready calls.
	await process_frame
	var error_log := ScriptErrorLog.new()
	OS.add_logger(error_log)
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TEST_DIR + file)
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			total += 1
			var instance = script.new()
			error_log.take()
			instance.call(name)
			var problems: PackedStringArray = instance.failures
			problems.append_array(error_log.take())
			if problems.is_empty():
				print("  ok    %s::%s" % [file, name])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [file, name])
				for f in problems:
					print("          " + f)
	OS.remove_logger(error_log)
	print("\n%d passed, %d failed" % [total - failed, failed])
	quit(1 if failed > 0 else 0)
