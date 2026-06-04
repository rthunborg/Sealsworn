class_name DomainEvent
extends RefCounted

enum Type {
	UNKNOWN,
	RUN_STARTED,
	BOARD_CREATED,
	RNG_STREAM_ADVANCED,
	COMMAND_REJECTED
}

const EVENT_ID_UNKNOWN := &"unknown"
const EVENT_ID_RUN_STARTED := &"run_started"
const EVENT_ID_BOARD_CREATED := &"board_created"
const EVENT_ID_RNG_STREAM_ADVANCED := &"rng_stream_advanced"
const EVENT_ID_COMMAND_REJECTED := &"command_rejected"

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


func to_dictionary() -> Dictionary:
	return {
		"event_id": String(id_for_type(event_type)),
		"sequence_id": sequence_id,
		"actor_id": String(actor_id),
		"payload": payload.duplicate(true)
	}


static func from_dictionary(data: Dictionary) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(
		type_for_id(StringName(str(data.get("event_id", EVENT_ID_UNKNOWN)))),
		int(data.get("sequence_id", 0)),
		StringName(str(data.get("actor_id", ""))),
		data.get("payload", {})
	)


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
		_:
			return Type.UNKNOWN
