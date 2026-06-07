class_name LocalTimingRecorder
extends RefCounted

var enabled: bool = false
var _starts: Dictionary = {}
var _records: Array[Dictionary] = []

func _init(new_enabled: bool = false) -> void:
	enabled = new_enabled and OS.is_debug_build()


func begin(label: StringName) -> void:
	if not enabled:
		return
	_starts[String(label)] = Time.get_ticks_usec()


func end(label: StringName) -> void:
	if not enabled:
		return
	var key: String = String(label)
	if not _starts.has(key):
		return
	var started_usec: int = int(_starts.get(key))
	_starts.erase(key)
	_records.append({
		"label": key,
		"elapsed_usec": max(0, Time.get_ticks_usec() - started_usec)
	})


func records() -> Array[Dictionary]:
	return _records.duplicate(true)
