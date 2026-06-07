class_name TacticalSnapshot
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")

const SCHEMA_VERSION: int = 1
const CONTENT_VERSION: String = "mvp-0"
const MAX_SERIALIZABLE_DEPTH: int = 32

var schema_version: int = SCHEMA_VERSION
var content_version: String = CONTENT_VERSION
var board: Dictionary = {}
var turn_state: Dictionary = {}
var pending_telegraphs: Array[Dictionary] = []
var rng_streams: Dictionary = {}
var event_log: Array[Dictionary] = []

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"content_version": content_version,
		"board": board.duplicate(true),
		"turn_state": turn_state.duplicate(true),
		"pending_telegraphs": pending_telegraphs.duplicate(true),
		"rng_streams": rng_streams.duplicate(true),
		"event_log": event_log.duplicate(true)
	}


static func parse(data: Dictionary) -> ActionResult:
	if not _has_field(data, &"schema_version") or not _is_integral_number(_field(data, &"schema_version")):
		return _invalid(&"missing_or_invalid_schema_version", {"field": "schema_version"})

	var parsed_schema_version: int = int(_field(data, &"schema_version"))
	if parsed_schema_version != SCHEMA_VERSION:
		return _invalid(&"unsupported_schema_version", {
			"expected_schema_version": SCHEMA_VERSION,
			"actual_schema_version": parsed_schema_version
		})

	if not _has_string_like_field(data, &"content_version"):
		return _invalid(&"missing_or_invalid_content_version", {"field": "content_version"})
	var parsed_content_version: String = String(_field(data, &"content_version"))
	if parsed_content_version != CONTENT_VERSION:
		return _invalid(&"unsupported_content_version", {
			"expected_content_version": CONTENT_VERSION,
			"actual_content_version": parsed_content_version
		})
	if not _has_dictionary_field(data, &"board"):
		return _invalid(&"missing_or_invalid_board", {"field": "board"})
	if not _has_dictionary_field(data, &"turn_state"):
		return _invalid(&"missing_or_invalid_turn_state", {"field": "turn_state"})
	if not _has_array_field(data, &"pending_telegraphs"):
		return _invalid(&"missing_or_invalid_pending_telegraphs", {"field": "pending_telegraphs"})
	if not _has_dictionary_field(data, &"rng_streams"):
		return _invalid(&"missing_or_invalid_rng_streams", {"field": "rng_streams"})
	if not _has_array_field(data, &"event_log"):
		return _invalid(&"missing_or_invalid_event_log", {"field": "event_log"})

	var board_result: ActionResult = _copy_serializable_dictionary_result(_field(data, &"board"))
	if board_result.is_error():
		return board_result
	var board_data: Dictionary = board_result.metadata.get("value")
	var board_validation: ActionResult = BoardState.try_from_snapshot(board_data)
	if board_validation.is_error():
		return _wrap_validation_error(&"board", board_validation)

	var turn_result: ActionResult = _copy_serializable_dictionary_result(_field(data, &"turn_state"))
	if turn_result.is_error():
		return turn_result
	var turn_data: Dictionary = turn_result.metadata.get("value")

	var pending_result: ActionResult = _copy_serializable_dictionary_array_result(_field(data, &"pending_telegraphs"), &"pending_telegraphs")
	if pending_result.is_error():
		return pending_result
	var pending_data: Array[Dictionary] = pending_result.metadata.get("value")

	var rng_result: ActionResult = _copy_serializable_dictionary_result(_field(data, &"rng_streams"))
	if rng_result.is_error():
		return rng_result
	var rng_data: Dictionary = rng_result.metadata.get("value")
	var restored_rng: RngStreamSet = RngStreamSet.new(0)
	var rng_validation: ActionResult = restored_rng.try_restore(rng_data)
	if rng_validation.is_error():
		return _wrap_validation_error(&"rng_streams", rng_validation)

	var event_result: ActionResult = _event_log_from_array(_field(data, &"event_log"))
	if event_result.is_error():
		return event_result
	var event_data: Array[Dictionary] = event_result.metadata.get("value")

	var snapshot: TacticalSnapshot = load("res://scripts/save/snapshots/tactical_snapshot.gd").new()
	snapshot.schema_version = parsed_schema_version
	snapshot.content_version = parsed_content_version
	snapshot.board = board_data.duplicate(true)
	snapshot.turn_state = turn_data.duplicate(true)
	snapshot.pending_telegraphs = pending_data.duplicate(true)
	snapshot.rng_streams = rng_data.duplicate(true)
	snapshot.event_log = event_data.duplicate(true)
	return ActionResult.ok([], {"snapshot": snapshot})


static func from_dictionary(data: Dictionary) -> TacticalSnapshot:
	var result: ActionResult = parse(data)
	if result.is_error():
		push_error("TacticalSnapshot parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("snapshot") as TacticalSnapshot


static func from_domain(
	board_state: BoardState,
	streams: RngStreamSet,
	new_turn_state: Dictionary = {},
	new_pending_telegraphs: Array[Dictionary] = [],
	new_event_log: Array[DomainEvent] = []
) -> ActionResult:
	if board_state == null:
		return _invalid(&"missing_board_state", {"field": "board_state"})
	if streams == null:
		return _invalid(&"missing_rng_streams", {"field": "rng_streams"})

	var board_consistency: ActionResult = board_state.validate_snapshot_consistency()
	if board_consistency.is_error():
		return _wrap_validation_error(&"board", board_consistency)

	var board_result: ActionResult = _copy_serializable_dictionary_result(board_state.to_snapshot())
	if board_result.is_error():
		return board_result
	var board_data: Dictionary = board_result.metadata.get("value")
	var board_validation: ActionResult = BoardState.try_from_snapshot(board_data)
	if board_validation.is_error():
		return _wrap_validation_error(&"board", board_validation)

	var rng_result: ActionResult = _copy_serializable_dictionary_result(streams.to_snapshot())
	if rng_result.is_error():
		return rng_result
	var rng_data: Dictionary = rng_result.metadata.get("value")
	var restored_rng: RngStreamSet = RngStreamSet.new(0)
	var rng_validation: ActionResult = restored_rng.try_restore(rng_data)
	if rng_validation.is_error():
		return _wrap_validation_error(&"rng_streams", rng_validation)

	var turn_result: ActionResult = _copy_serializable_dictionary_result(new_turn_state)
	if turn_result.is_error():
		return turn_result
	var turn_data: Dictionary = turn_result.metadata.get("value")

	var pending_result: ActionResult = _copy_serializable_dictionary_array_result(new_pending_telegraphs, &"pending_telegraphs")
	if pending_result.is_error():
		return pending_result
	var pending_data: Array[Dictionary] = pending_result.metadata.get("value")

	var event_entries: Array[Dictionary] = []
	for event: DomainEvent in new_event_log:
		if event == null:
			return _invalid(&"invalid_event_log_entry", {"field": "event_log"})
		var event_result: ActionResult = _copy_serializable_dictionary_result(event.to_dictionary())
		if event_result.is_error():
			return event_result
		var event_data: Dictionary = event_result.metadata.get("value")
		var parsed_event: ActionResult = DomainEvent.try_from_dictionary(event_data)
		if parsed_event.is_error():
			return _wrap_validation_error(&"event_log", parsed_event)
		event_entries.append(event_data)

	var snapshot: TacticalSnapshot = load("res://scripts/save/snapshots/tactical_snapshot.gd").new()
	snapshot.schema_version = SCHEMA_VERSION
	snapshot.content_version = CONTENT_VERSION
	snapshot.board = board_data.duplicate(true)
	snapshot.turn_state = turn_data.duplicate(true)
	snapshot.pending_telegraphs = pending_data.duplicate(true)
	snapshot.rng_streams = rng_data.duplicate(true)
	snapshot.event_log = event_entries.duplicate(true)
	return ActionResult.ok([], {"snapshot": snapshot})


static func _event_log_from_array(value: Variant) -> ActionResult:
	if not value is Array:
		return _invalid(&"missing_or_invalid_event_log", {"field": "event_log"})

	var result: Array[Dictionary] = []
	for event_value: Variant in value:
		if not event_value is Dictionary:
			return _invalid(&"invalid_event_log_entry", {"field": "event_log"})
		var event_copy_result: ActionResult = _copy_serializable_dictionary_result(event_value)
		if event_copy_result.is_error():
			return event_copy_result
		var event_data: Dictionary = event_copy_result.metadata.get("value")
		var parsed_result: ActionResult = DomainEvent.try_from_dictionary(event_data)
		if parsed_result.is_error():
			return _wrap_validation_error(&"event_log", parsed_result)
		var parsed_event: DomainEvent = parsed_result.metadata.get("event") as DomainEvent
		var canonical_result: ActionResult = _copy_serializable_dictionary_result(parsed_event.to_dictionary())
		if canonical_result.is_error():
			return canonical_result
		result.append(canonical_result.metadata.get("value"))
	return ActionResult.ok([], {"value": result})


static func _copy_serializable_dictionary_array_result(value: Variant, field_name: StringName) -> ActionResult:
	if not value is Array:
		return _invalid(&"invalid_dictionary_array", {"field": String(field_name)})

	var result: Array[Dictionary] = []
	for item: Variant in value:
		if not item is Dictionary:
			return _invalid(&"invalid_dictionary_array_entry", {"field": String(field_name)})
		var copy_result: ActionResult = _copy_serializable_dictionary_result(item)
		if copy_result.is_error():
			return copy_result
		result.append(copy_result.metadata.get("value"))
	return ActionResult.ok([], {"value": result})


static func _copy_serializable_dictionary_result(value: Variant) -> ActionResult:
	if not value is Dictionary:
		return _invalid(&"invalid_dictionary", {})
	var copy_result: Dictionary = _copy_serializable_dictionary(value, 0)
	if copy_result.get("ok") == false:
		return _invalid(StringName(str(copy_result.get("reason", "invalid_serializable_value"))), {
			"field": str(copy_result.get("field", "")),
			"value_type": int(copy_result.get("value_type", TYPE_NIL))
		})
	return ActionResult.ok([], {"value": copy_result.get("value")})


static func _copy_serializable_dictionary(source: Dictionary, depth: int) -> Dictionary:
	if depth > MAX_SERIALIZABLE_DEPTH:
		return {"ok": false, "reason": "max_depth_exceeded"}

	var result: Dictionary = {}
	for key: Variant in source.keys():
		var copied_key_result: Dictionary = _copy_serializable_key(key)
		if copied_key_result.get("ok") == false:
			return copied_key_result

		var copied_value_result: Dictionary = _copy_serializable_value(source[key], depth + 1)
		if copied_value_result.get("ok") == false:
			return copied_value_result
		result[copied_key_result.get("value")] = copied_value_result.get("value")
	return {"ok": true, "value": result}


static func _copy_serializable_array(source: Array, depth: int) -> Dictionary:
	if depth > MAX_SERIALIZABLE_DEPTH:
		return {"ok": false, "reason": "max_depth_exceeded"}

	var result: Array = []
	for item: Variant in source:
		var copied_item_result: Dictionary = _copy_serializable_value(item, depth + 1)
		if copied_item_result.get("ok") == false:
			return copied_item_result
		result.append(copied_item_result.get("value"))
	return {"ok": true, "value": result}


static func _copy_serializable_value(value: Variant, depth: int) -> Dictionary:
	if depth > MAX_SERIALIZABLE_DEPTH:
		return {"ok": false, "reason": "max_depth_exceeded"}

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			if typeof(value) == TYPE_FLOAT:
				var numeric_value: float = float(value)
				if is_nan(numeric_value) or is_inf(numeric_value):
					return {"ok": false, "reason": "non_finite_float", "value_type": TYPE_FLOAT}
			return {"ok": true, "value": value}
		TYPE_STRING:
			if _is_forbidden_reference_string(value):
				return {"ok": false, "reason": "forbidden_reference_string", "value_type": TYPE_STRING}
			return {"ok": true, "value": value}
		TYPE_STRING_NAME:
			var text: String = String(value)
			if _is_forbidden_reference_string(text):
				return {"ok": false, "reason": "forbidden_reference_string", "value_type": TYPE_STRING_NAME}
			return {"ok": true, "value": text}
		TYPE_ARRAY:
			return _copy_serializable_array(value, depth + 1)
		TYPE_DICTIONARY:
			return _copy_serializable_dictionary(value, depth + 1)
		_:
			return {"ok": false, "reason": "unsupported_serializable_type", "value_type": typeof(value)}


static func _copy_serializable_key(key: Variant) -> Dictionary:
	match typeof(key):
		TYPE_STRING:
			return {"ok": true, "value": key}
		TYPE_STRING_NAME:
			return {"ok": true, "value": String(key)}
		_:
			return {"ok": false, "reason": "unsupported_dictionary_key", "value_type": typeof(key)}


static func _is_forbidden_reference_string(value: String) -> bool:
	return (
		value.begins_with("res://")
		or value.ends_with(".tscn")
		or value.ends_with(".scn")
		or value.ends_with(".anim")
		or value.ends_with(".ogg")
		or value.ends_with(".wav")
		or value.ends_with(".mp3")
		or value.to_lower().contains("presentation")
	)


static func _wrap_validation_error(section: StringName, result: ActionResult) -> ActionResult:
	return _invalid(&"invalid_section", {
		"section": String(section),
		"source_error_code": String(result.error_code),
		"source_metadata": result.metadata.duplicate(true)
	})


static func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_tactical_snapshot", result_metadata)


static func _has_dictionary_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _field(data, field_name) is Dictionary


static func _has_array_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _field(data, field_name) is Array


static func _has_string_like_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _is_string_like(_field(data, field_name))


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _is_string_like(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false
