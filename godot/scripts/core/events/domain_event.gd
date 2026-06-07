class_name DomainEvent
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

enum Type {
	UNKNOWN,
	RUN_STARTED,
	BOARD_CREATED,
	RNG_STREAM_ADVANCED,
	COMMAND_REJECTED,
	ENTITY_MOVED
}

const EVENT_ID_UNKNOWN := &"unknown"
const EVENT_ID_RUN_STARTED := &"run_started"
const EVENT_ID_BOARD_CREATED := &"board_created"
const EVENT_ID_RNG_STREAM_ADVANCED := &"rng_stream_advanced"
const EVENT_ID_COMMAND_REJECTED := &"command_rejected"
const EVENT_ID_ENTITY_MOVED := &"entity_moved"

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
	if parsed_event_type == Type.ENTITY_MOVED and String(actor_id_value).is_empty():
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


static func _cell_payload(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


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
		_:
			return Type.UNKNOWN
