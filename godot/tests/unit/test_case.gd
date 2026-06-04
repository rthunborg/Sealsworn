class_name TestCase
extends RefCounted

var failures: Array[String] = []

func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_false(condition: bool, message: String) -> void:
	if condition:
		failures.append(message)


func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s Expected <%s>, got <%s>." % [message, expected, actual])


func result() -> Dictionary:
	return {
		"failures": failures.duplicate()
	}

