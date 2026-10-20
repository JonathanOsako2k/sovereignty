extends RefCounted
## Minimal assertion base for the headless test runner. Test scripts extend this
## file and define `test_*` methods.

var failures := PackedStringArray()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])
