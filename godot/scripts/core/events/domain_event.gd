class_name DomainEvent
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

enum Type {
	UNKNOWN,
	RUN_STARTED,
	BOARD_CREATED,
	RNG_STREAM_ADVANCED,
	COMMAND_REJECTED,
	ENTITY_MOVED,
	VISIBILITY_UPDATED
}

const EVENT_ID_UNKNOWN := &"unknown"
const EVENT_ID_RUN_STARTED := &"run_started"
const EVENT_ID_BOARD_CREATED := &"board_created"
const EVENT_ID_RNG_STREAM_ADVANCED := &"rng_stream_advanced"
const EVENT_ID_COMMAND_REJECTED := &"command_rejected"
const EVENT_ID_ENTITY_MOVED := &"entity_moved"
const EVENT_ID_VISIBILITY_UPDATED := &"visibility_updated"

var event_type: int = Type.UNKNOWN
var sequence_id: int = 0
var actor_id: StringName = &""
var payload: Dictionary = {}

func _init(
	new_event_type: int = Type.UNKNOWN,
	new_sequence_id: int = 0,
	new_actor_id: StringName = &"",
	new_payload: Dictionary = {}
) -> void:
	event_type = new_event_type
	sequence_id = new_sequence_id
	actor_id = new_actor_id
	payload = new_payload.duplicate(true)


static func board_created(sequence_id: int, width: int, height: int) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(Type.BOARD_CREATED, sequence_id, &"", {
		"width": width,
		"height": height
	})


static func entity_moved(
	sequence_id: int,
	actor_id: StringName,
	from_cell: Vector2i,
	to_cell: Vector2i,
	movement_cost: int,
	movement_budget: int
) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(Type.ENTITY_MOVED, sequence_id, actor_id, {
		"from": _cell_payload(from_cell),
		"to": _cell_payload(to_cell),
		"movement_cost": movement_cost,
		"movement_budget": movement_budget
	})


static func visibility_updated(
	sequence_id: int,
	actor_id: StringName,
	origin: Vector2i,
	radius: int,
	visible_cells: Array,
	newly_explored_cells: Array
) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(Type.VISIBILITY_UPDATED, sequence_id, actor_id, {
		"origin": _cell_payload(origin),
		"radius": radius,
		"visible_cells": _cell_array_payload(visible_cells),
		"newly_explored_cells": _cell_array_payload(newly_explored_cells)
	})


func to_dictionary() -> Dictionary:
	return {
		"event_id": String(id_for_type(event_type)),
		"sequence_id": sequence_id,
		"actor_id": String(actor_id),
		"payload": payload.duplicate(true)
	}


static func from_dictionary(data: Dictionary) -> DomainEvent:
	var parse_result: Variant = try_from_dictionary(data)
	if parse_result.succeeded:
		return parse_result.metadata.get("event") as DomainEvent

	return load("res://scripts/core/events/domain_event.gd").new()


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	if not data.has("event_id"):
		return _error_result(&"invalid_event_id", {"field": "event_id"})

	var event_id_value: Variant = data.get("event_id")
	if not (event_id_value is String or event_id_value is StringName):
		return _error_result(&"invalid_event_id", {"field": "event_id"})

	var event_id: StringName = StringName(String(event_id_value))
	var parsed_event_type: int = type_for_id(event_id)
	if parsed_event_type == Type.UNKNOWN:
		return _error_result(&"invalid_event_id", {
			"event_id": String(event_id)
		})

	if not data.has("sequence_id"):
		return _error_result(&"invalid_event_sequence_id", {"field": "sequence_id"})

	var sequence_id_value: Variant = data.get("sequence_id")
	if not _is_integral_number(sequence_id_value):
		return _error_result(&"invalid_event_sequence_id", {"field": "sequence_id"})

	var parsed_sequence_id: int = int(sequence_id_value)
	if parsed_sequence_id <= 0:
		return _error_result(&"invalid_event_sequence_id", {
			"sequence_id": parsed_sequence_id
		})

	if not data.has("actor_id"):
		return _error_result(&"invalid_event_actor_id", {"field": "actor_id"})

	var actor_id_value: Variant = data.get("actor_id")
	if not (actor_id_value is String or actor_id_value is StringName):
		return _error_result(&"invalid_event_actor_id", {"field": "actor_id"})
	if (parsed_event_type == Type.ENTITY_MOVED or parsed_event_type == Type.VISIBILITY_UPDATED) and String(actor_id_value).is_empty():
		return _error_result(&"invalid_event_actor_id", {"field": "actor_id"})

	if not data.has("payload"):
		return _error_result(&"invalid_event_payload", {"field": "payload"})

	var payload_value: Variant = data.get("payload")
	if not payload_value is Dictionary:
		return _error_result(&"invalid_event_payload", {"field": "payload"})
	var payload_validation: ActionResult = _validate_payload_for_event(parsed_event_type, payload_value)
	if payload_validation.is_error():
		return payload_validation

	var event: DomainEvent = load("res://scripts/core/events/domain_event.gd").new(
		parsed_event_type,
		parsed_sequence_id,
		StringName(String(actor_id_value)),
		payload_value
	)
	return _ok_result({"event": event})


static func _ok_result(new_metadata: Dictionary = {}) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.succeeded = true
	result.metadata = new_metadata.duplicate(true)
	return result


static func _error_result(new_error_code: StringName, new_metadata: Dictionary = {}) -> ActionResult:
	return ActionResult.error(new_error_code, new_metadata)


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


static func _validate_payload_for_event(event_type_value: int, payload_value: Dictionary) -> ActionResult:
	match event_type_value:
		Type.ENTITY_MOVED:
			return _validate_entity_moved_payload(payload_value)
		Type.VISIBILITY_UPDATED:
			return _validate_visibility_updated_payload(payload_value)
		_:
			return _ok_result()


static func _validate_entity_moved_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_cell_payload(payload_value, &"from"):
		return _error_result(&"invalid_event_payload", {"field": "from"})
	if not _has_cell_payload(payload_value, &"to"):
		return _error_result(&"invalid_event_payload", {"field": "to"})
	if not payload_value.has("movement_cost") or not _is_integral_number(payload_value.get("movement_cost")):
		return _error_result(&"invalid_event_payload", {"field": "movement_cost"})
	if not payload_value.has("movement_budget") or not _is_integral_number(payload_value.get("movement_budget")):
		return _error_result(&"invalid_event_payload", {"field": "movement_budget"})

	var movement_cost: int = int(payload_value.get("movement_cost"))
	var movement_budget: int = int(payload_value.get("movement_budget"))
	if movement_cost <= 0:
		return _error_result(&"invalid_event_payload", {"field": "movement_cost"})
	if movement_budget <= 0:
		return _error_result(&"invalid_event_payload", {"field": "movement_budget"})
	if movement_cost > movement_budget:
		return _error_result(&"invalid_event_payload", {"field": "movement_cost"})

	return _ok_result()


static func _validate_visibility_updated_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_cell_payload(payload_value, &"origin"):
		return _error_result(&"invalid_event_payload", {"field": "origin"})
	if not payload_value.has("radius") or not _is_integral_number(payload_value.get("radius")):
		return _error_result(&"invalid_event_payload", {"field": "radius"})
	if int(payload_value.get("radius")) <= 0:
		return _error_result(&"invalid_event_payload", {"field": "radius"})
	if not _has_cell_array_payload(payload_value, &"visible_cells", false):
		return _error_result(&"invalid_event_payload", {"field": "visible_cells"})
	if not _has_cell_array_payload(payload_value, &"newly_explored_cells", true):
		return _error_result(&"invalid_event_payload", {"field": "newly_explored_cells"})
	if _cell_array_has_duplicates(payload_value.get("visible_cells", [])):
		return _error_result(&"invalid_event_payload", {"field": "visible_cells"})
	if _cell_array_has_duplicates(payload_value.get("newly_explored_cells", [])):
		return _error_result(&"invalid_event_payload", {"field": "newly_explored_cells"})

	return _ok_result()


static func _has_cell_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var cell_value: Variant = payload_value.get(String(field_name))
	if not cell_value is Dictionary:
		return false
	var cell_data: Dictionary = cell_value
	return (
		cell_data.has("x")
		and cell_data.has("y")
		and _is_integral_number(cell_data.get("x"))
		and _is_integral_number(cell_data.get("y"))
	)


static func _has_cell_array_payload(payload_value: Dictionary, field_name: StringName, allow_empty: bool) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var cells_value: Variant = payload_value.get(String(field_name))
	if not cells_value is Array:
		return false
	var cells: Array = cells_value
	if cells.is_empty() and not allow_empty:
		return false
	for cell_value: Variant in cells:
		if not cell_value is Dictionary:
			return false
		var cell_data: Dictionary = cell_value
		if not (
			cell_data.has("x")
			and cell_data.has("y")
			and _is_integral_number(cell_data.get("x"))
			and _is_integral_number(cell_data.get("y"))
		):
			return false
	return true


static func _cell_array_has_duplicates(cells_value: Variant) -> bool:
	if not cells_value is Array:
		return true
	var seen: Dictionary = {}
	for cell_value: Variant in cells_value:
		if not cell_value is Dictionary:
			return true
		var cell_data: Dictionary = cell_value
		var key: String = "%s,%s" % [int(cell_data.get("x", 0)), int(cell_data.get("y", 0))]
		if seen.has(key):
			return true
		seen[key] = true
	return false


static func _cell_payload(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


static func _cell_array_payload(cells: Array) -> Array[Dictionary]:
	var sorted_cells: Array[Vector2i] = []
	for cell_value: Variant in cells:
		if cell_value is Vector2i:
			sorted_cells.append(cell_value)
	sorted_cells.sort_custom(_sort_cells_by_position)
	var result: Array[Dictionary] = []
	for cell: Vector2i in sorted_cells:
		result.append(_cell_payload(cell))
	return result


static func id_for_type(type_value: int) -> StringName:
	match type_value:
		Type.RUN_STARTED:
			return EVENT_ID_RUN_STARTED
		Type.BOARD_CREATED:
			return EVENT_ID_BOARD_CREATED
		Type.RNG_STREAM_ADVANCED:
			return EVENT_ID_RNG_STREAM_ADVANCED
		Type.COMMAND_REJECTED:
			return EVENT_ID_COMMAND_REJECTED
		Type.ENTITY_MOVED:
			return EVENT_ID_ENTITY_MOVED
		Type.VISIBILITY_UPDATED:
			return EVENT_ID_VISIBILITY_UPDATED
		_:
			return EVENT_ID_UNKNOWN


static func type_for_id(event_id: StringName) -> int:
	match event_id:
		EVENT_ID_RUN_STARTED:
			return Type.RUN_STARTED
		EVENT_ID_BOARD_CREATED:
			return Type.BOARD_CREATED
		EVENT_ID_RNG_STREAM_ADVANCED:
			return Type.RNG_STREAM_ADVANCED
		EVENT_ID_COMMAND_REJECTED:
			return Type.COMMAND_REJECTED
		EVENT_ID_ENTITY_MOVED:
			return Type.ENTITY_MOVED
		EVENT_ID_VISIBILITY_UPDATED:
			return Type.VISIBILITY_UPDATED
		_:
			return Type.UNKNOWN


static func _sort_cells_by_position(first: Vector2i, second: Vector2i) -> bool:
	if first.y == second.y:
		return first.x < second.x
	return first.y < second.y
