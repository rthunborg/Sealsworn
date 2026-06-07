extends Node

signal diagnostic_recorded(record: Dictionary)

enum Severity {
	INFO,
	WARNING,
	ERROR
}

var _records: Array[Dictionary] = []

func info(category: StringName, code: StringName, payload: Dictionary = {}) -> void:
	record(Severity.INFO, category, code, payload)


func warning(category: StringName, code: StringName, payload: Dictionary = {}) -> void:
	record(Severity.WARNING, category, code, payload)


func record_error(category: StringName, code: StringName, payload: Dictionary = {}) -> void:
	record(Severity.ERROR, category, code, payload)


func record(severity: int, category: StringName, code: StringName, payload: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"severity": severity,
		"category": String(category),
		"code": String(code),
		"payload": payload.duplicate(true),
		"ticks_msec": Time.get_ticks_msec()
	}
	_records.append(entry)
	diagnostic_recorded.emit(entry)


func recent_records() -> Array[Dictionary]:
	return _records.duplicate(true)


func clear() -> void:
	_records.clear()

