extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_board_created_serializes_stable_event_id()
	_entity_moved_serializes_stable_payload()
	_event_dictionary_uses_deterministic_fields_and_copies_payload()
	_try_from_dictionary_parses_valid_event_dictionaries()
	_try_from_dictionary_parses_entity_moved_events()
	_try_from_dictionary_rejects_malformed_entity_moved_payloads()
	_try_from_dictionary_accepts_json_round_tripped_integral_sequence_ids()
	_try_from_dictionary_rejects_malformed_event_dictionaries()
	_from_dictionary_keeps_unknown_compatibility_wrapper()
	_event_identifiers_are_stable_machine_ids()
	return result()


func _board_created_serializes_stable_event_id() -> void:
	var event: DomainEvent = DomainEvent.board_created(4, 5, 6)
	var serialized: Dictionary = event.to_dictionary()
	var restored: DomainEvent = DomainEvent.from_dictionary(serialized)

	assert_equal(serialized.get("event_id"), "board_created", "DomainEvent should serialize stable string ids.")
	assert_false(serialized.has("event_type"), "DomainEvent should not serialize enum integers.")
	assert_equal(restored.event_type, DomainEvent.Type.BOARD_CREATED, "DomainEvent should restore event type from stable id.")
	assert_equal(restored.sequence_id, 4, "DomainEvent should preserve sequence id.")


func _entity_moved_serializes_stable_payload() -> void:
	var event: DomainEvent = DomainEvent.entity_moved(5, &"hero", Vector2i(0, 0), Vector2i(2, 1), 3, 3)
	var serialized: Dictionary = event.to_dictionary()
	var restored: DomainEvent = DomainEvent.from_dictionary(serialized)

	assert_equal(serialized.get("event_id"), "entity_moved", "Movement events should serialize stable string ids.")
	assert_equal(serialized.get("actor_id"), "hero", "Movement events should serialize the moving actor id.")
	assert_equal(serialized.get("payload", {}).get("from"), {"x": 0, "y": 0}, "Movement events should serialize source cells.")
	assert_equal(serialized.get("payload", {}).get("to"), {"x": 2, "y": 1}, "Movement events should serialize target cells.")
	assert_equal(serialized.get("payload", {}).get("movement_cost"), 3, "Movement events should serialize movement cost.")
	assert_equal(serialized.get("payload", {}).get("movement_budget"), 3, "Movement events should serialize movement budget.")
	assert_equal(restored.event_type, DomainEvent.Type.ENTITY_MOVED, "Movement events should parse back to ENTITY_MOVED.")


func _event_dictionary_uses_deterministic_fields_and_copies_payload() -> void:
	var payload: Dictionary = {
		"stream_id": "combat",
		"rolls": [1, 2]
	}
	var event: DomainEvent = DomainEvent.new(DomainEvent.Type.RNG_STREAM_ADVANCED, 7, &"combat_rng", payload)
	payload["stream_id"] = "mutated"
	payload["rolls"].append(3)
	var serialized: Dictionary = event.to_dictionary()
	serialized["payload"]["stream_id"] = "serialized_mutation"

	assert_equal(event.payload.get("stream_id"), "combat", "DomainEvent should deep-copy payload at creation.")
	assert_equal(event.payload.get("rolls"), [1, 2], "DomainEvent should preserve nested payload values.")
	assert_equal(serialized.get("event_id"), "rng_stream_advanced", "DomainEvent should serialize stable event ids.")
	assert_equal(serialized.get("sequence_id"), 7, "DomainEvent should serialize positive sequence ids.")
	assert_equal(serialized.get("actor_id"), "combat_rng", "DomainEvent should serialize stable actor ids.")
	assert_false(serialized.has("event_type"), "DomainEvent dictionaries must not expose raw enum integers.")
	assert_equal(event.payload.get("stream_id"), "combat", "DomainEvent.to_dictionary should deep-copy payload data.")


func _try_from_dictionary_parses_valid_event_dictionaries() -> void:
	var parse_result: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "board_created",
		"sequence_id": 3,
		"actor_id": "",
		"payload": {
			"width": 4,
			"height": 5
		}
	})
	var event: DomainEvent = parse_result.metadata.get("event") as DomainEvent

	assert_true(parse_result.succeeded, "DomainEvent.try_from_dictionary should parse valid event dictionaries.")
	assert_equal(event.event_type, DomainEvent.Type.BOARD_CREATED, "Parsed event should restore event type from stable id.")
	assert_equal(event.sequence_id, 3, "Parsed event should preserve sequence id.")
	assert_equal(event.actor_id, &"", "Parsed event should preserve empty actor id for system events.")
	assert_equal(event.payload.get("width"), 4, "Parsed event should preserve payload values.")


func _try_from_dictionary_parses_entity_moved_events() -> void:
	var parse_result: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "entity_moved",
		"sequence_id": 8,
		"actor_id": "hero",
		"payload": {
			"from": {"x": 0, "y": 0},
			"to": {"x": 1, "y": 0},
			"movement_cost": 1,
			"movement_budget": 3
		}
	})
	var event: DomainEvent = parse_result.metadata.get("event") as DomainEvent

	assert_true(parse_result.succeeded, "DomainEvent.try_from_dictionary should parse valid movement events.")
	assert_equal(event.event_type, DomainEvent.Type.ENTITY_MOVED, "Parsed movement event should restore type from stable id.")
	assert_equal(event.sequence_id, 8, "Parsed movement event should preserve sequence id.")
	assert_equal(event.actor_id, &"hero", "Parsed movement event should preserve actor id.")
	assert_equal(event.payload.get("movement_cost"), 1, "Parsed movement event should preserve movement cost.")


func _try_from_dictionary_rejects_malformed_entity_moved_payloads() -> void:
	_assert_invalid_entity_moved_payload({
		"to": {"x": 1, "y": 0},
		"movement_cost": 1,
		"movement_budget": 3
	}, &"from", "Movement events should require a source cell.")
	_assert_invalid_entity_moved_payload({
		"from": {"x": 0, "y": 0},
		"movement_cost": 1,
		"movement_budget": 3
	}, &"to", "Movement events should require a target cell.")
	_assert_invalid_entity_moved_payload({
		"from": {"x": 0, "y": 0},
		"to": {"x": 1, "y": 0},
		"movement_cost": 0,
		"movement_budget": 3
	}, &"movement_cost", "Movement events should reject non-positive movement costs.")
	_assert_invalid_entity_moved_payload({
		"from": {"x": 0, "y": 0},
		"to": {"x": 1, "y": 0},
		"movement_cost": 1,
		"movement_budget": 0
	}, &"movement_budget", "Movement events should reject non-positive movement budgets.")


func _try_from_dictionary_accepts_json_round_tripped_integral_sequence_ids() -> void:
	var json_data: Variant = JSON.parse_string(JSON.stringify({
		"event_id": "board_created",
		"sequence_id": 3,
		"actor_id": "",
		"payload": {
			"width": 4,
			"height": 5
		}
	}))
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(json_data as Dictionary)
	var event: DomainEvent = parse_result.metadata.get("event") as DomainEvent

	assert_true(parse_result.succeeded, "DomainEvent.try_from_dictionary should accept JSON round-tripped integral sequence ids.")
	assert_equal(event.sequence_id, 3, "JSON round-tripped sequence ids should preserve the integer value.")


func _try_from_dictionary_rejects_malformed_event_dictionaries() -> void:
	var missing_id: ActionResult = DomainEvent.try_from_dictionary({
		"sequence_id": 1,
		"actor_id": "",
		"payload": {}
	})
	var unknown_id: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "future_event",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {}
	})
	var invalid_sequence_type: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "board_created",
		"sequence_id": "1",
		"actor_id": "",
		"payload": {}
	})
	var invalid_sequence_value: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "board_created",
		"sequence_id": 0,
		"actor_id": "",
		"payload": {}
	})
	var invalid_actor_id: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "board_created",
		"sequence_id": 1,
		"actor_id": 12,
		"payload": {}
	})
	var invalid_payload: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "board_created",
		"sequence_id": 1,
		"actor_id": "",
		"payload": []
	})

	assert_equal(missing_id.error_code, &"invalid_event_id", "Missing event ids should be rejected with a stable code.")
	assert_equal(unknown_id.error_code, &"invalid_event_id", "Unknown event ids should be rejected by validated parsing.")
	assert_equal(invalid_sequence_type.error_code, &"invalid_event_sequence_id", "Non-int sequence ids should not be coerced.")
	assert_equal(invalid_sequence_value.error_code, &"invalid_event_sequence_id", "Non-positive sequence ids should be rejected.")
	assert_equal(invalid_actor_id.error_code, &"invalid_event_actor_id", "Non-string actor ids should not be coerced.")
	assert_equal(invalid_payload.error_code, &"invalid_event_payload", "Non-dictionary payloads should not be coerced.")
	assert_false(missing_id.has_events(), "Invalid event parse results should not contain events.")


func _from_dictionary_keeps_unknown_compatibility_wrapper() -> void:
	var restored: DomainEvent = DomainEvent.from_dictionary({
		"event_id": "future_event",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {}
	})

	assert_equal(restored.event_type, DomainEvent.Type.UNKNOWN, "Unknown event ids should not map to valid event types.")


func _event_identifiers_are_stable_machine_ids() -> void:
	var expected_ids: Dictionary = {
		DomainEvent.Type.RUN_STARTED: &"run_started",
		DomainEvent.Type.BOARD_CREATED: &"board_created",
		DomainEvent.Type.RNG_STREAM_ADVANCED: &"rng_stream_advanced",
		DomainEvent.Type.COMMAND_REJECTED: &"command_rejected",
		DomainEvent.Type.ENTITY_MOVED: &"entity_moved"
	}

	for event_type: int in expected_ids.keys():
		var event_id: StringName = DomainEvent.id_for_type(event_type)
		assert_equal(event_id, expected_ids[event_type], "DomainEvent ids should remain stable.")
		_assert_machine_id(String(event_id), "DomainEvent ids should be lower-snake machine ids.")


func _assert_machine_id(value: String, message: String) -> void:
	assert_equal(value, value.to_lower(), message)
	assert_false(value.contains(" "), message)
	assert_false(value.contains("."), message)
	assert_false(value.contains(":"), message)


func _assert_invalid_entity_moved_payload(payload: Dictionary, expected_field: StringName, message: String) -> void:
	var result_value: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "entity_moved",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": payload
	})

	assert_true(result_value.is_error(), message)
	assert_equal(result_value.error_code, &"invalid_event_payload", message)
	assert_equal(result_value.metadata.get("field"), String(expected_field), message)
