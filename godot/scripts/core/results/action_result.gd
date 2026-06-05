class_name ActionResult
extends RefCounted

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

var succeeded: bool = false
var error_code: StringName = &""
var events: Array[DomainEvent] = []
var metadata: Dictionary = {}

static func ok(new_events: Array = [], new_metadata: Dictionary = {}) -> ActionResult:
	var result: ActionResult = load("res://scripts/core/results/action_result.gd").new()
	result.succeeded = true
	for event: Variant in new_events:
		if not event is DomainEvent:
			return error(&"invalid_result_event", {"event_value": str(event)})
		result.events.append(event)
	result.metadata = new_metadata.duplicate(true)
	return result


static func error(new_error_code: StringName, new_metadata: Dictionary = {}) -> ActionResult:
	var result: ActionResult = load("res://scripts/core/results/action_result.gd").new()
	result.succeeded = false
	result.error_code = new_error_code
	if not _is_valid_error_code(result.error_code):
		result.error_code = &"invalid_error_code"
	result.metadata = new_metadata.duplicate(true)
	return result


func is_error() -> bool:
	return not succeeded


func has_events() -> bool:
	return not events.is_empty()


static func _is_valid_error_code(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	if text.strip_edges() != text:
		return false
	if text != text.to_lower():
		return false

	var invalid_fragments: Array[String] = [" ", ".", ":", ";", "-", "/", "\\", "'", "\""]
	for fragment: String in invalid_fragments:
		if text.contains(fragment):
			return false

	return true
