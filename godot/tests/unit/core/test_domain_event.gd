extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_board_created_serializes_stable_event_id()
	_entity_moved_serializes_stable_payload()
	_event_dictionary_uses_deterministic_fields_and_copies_payload()
	_try_from_dictionary_parses_valid_event_dictionaries()
	_try_from_dictionary_parses_entity_moved_events()
	_visibility_updated_serializes_stable_payload()
	_attack_events_serialize_and_parse_stable_payloads()
	_try_from_dictionary_rejects_malformed_entity_moved_payloads()
	_try_from_dictionary_rejects_malformed_visibility_payloads()
	_try_from_dictionary_rejects_malformed_attack_payloads()
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


func _visibility_updated_serializes_stable_payload() -> void:
	var event: DomainEvent = DomainEvent.visibility_updated(
		9,
		&"hero",
		Vector2i(2, 1),
		4,
		[Vector2i(2, 1), Vector2i(1, 1)],
		[Vector2i(1, 1)]
	)
	var serialized: Dictionary = event.to_dictionary()
	var restored: DomainEvent = DomainEvent.from_dictionary(serialized)

	assert_equal(serialized.get("event_id"), "visibility_updated", "Visibility events should serialize stable string ids.")
	assert_equal(serialized.get("actor_id"), "hero", "Visibility events should serialize the actor id.")
	assert_equal(serialized.get("payload", {}).get("origin"), {"x": 2, "y": 1}, "Visibility events should serialize origin cells.")
	assert_equal(serialized.get("payload", {}).get("radius"), 4, "Visibility events should serialize radius.")
	assert_equal(serialized.get("payload", {}).get("visible_cells"), [{"x": 1, "y": 1}, {"x": 2, "y": 1}], "Visibility events should serialize visible cells sorted by y then x.")
	assert_equal(serialized.get("payload", {}).get("newly_explored_cells"), [{"x": 1, "y": 1}], "Visibility events should serialize newly explored cells.")
	assert_equal(restored.event_type, DomainEvent.Type.VISIBILITY_UPDATED, "Visibility events should parse back to VISIBILITY_UPDATED.")
	assert_equal(restored.actor_id, &"hero", "Visibility events should preserve actor id when parsed.")


func _attack_events_serialize_and_parse_stable_payloads() -> void:
	var attacked_payload: Dictionary = _attack_payload()
	var attacked: DomainEvent = DomainEvent.entity_attacked(
		11,
		&"hero",
		&"enemy_1",
		Vector2i(2, 1),
		&"sword",
		attacked_payload
	)
	var damage: DomainEvent = DomainEvent.damage_applied(
		12,
		&"hero",
		&"enemy_1",
		4,
		10,
		6,
		10,
		{
			"weapon_id": "sword",
			"base_damage": 4,
			"support_bonus_damage": 0,
			"armor_reduction": 0,
			"block_succeeded": false,
			"damage_type": "physical",
			"rng_draws": []
		}
	)
	var status: DomainEvent = DomainEvent.status_effect_applied(
		13,
		&"hero",
		&"enemy_1",
		&"bleed",
		{
			"weapon_id": "axe",
			"rng_draw": _rng_draw("bleed", 0.2, 0.35, true)
		}
	)
	var knockback: DomainEvent = DomainEvent.entity_knocked_back(
		14,
		&"hero",
		&"enemy_1",
		Vector2i(2, 1),
		Vector2i(3, 1),
		&"crossbow",
		{"source_cell": {"x": 0, "y": 1}}
	)

	_assert_round_trips(attacked, DomainEvent.Type.ENTITY_ATTACKED, "entity_attacked")
	_assert_round_trips(damage, DomainEvent.Type.DAMAGE_APPLIED, "damage_applied")
	_assert_round_trips(status, DomainEvent.Type.STATUS_EFFECT_APPLIED, "status_effect_applied")
	_assert_round_trips(knockback, DomainEvent.Type.ENTITY_KNOCKED_BACK, "entity_knocked_back")
	assert_equal(attacked.to_dictionary().get("payload", {}).get("target_cell"), {"x": 2, "y": 1}, "Attack events should serialize target cells.")
	assert_equal(damage.to_dictionary().get("payload", {}).get("hp_after"), 6, "Damage events should serialize post-damage HP.")
	assert_equal(status.to_dictionary().get("payload", {}).get("effect_id"), "bleed", "Status events should serialize effect ids.")
	assert_equal(knockback.to_dictionary().get("payload", {}).get("to"), {"x": 3, "y": 1}, "Knockback events should serialize destination cells.")


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


func _try_from_dictionary_rejects_malformed_visibility_payloads() -> void:
	_assert_invalid_visibility_payload({
		"radius": 4,
		"visible_cells": [{"x": 0, "y": 0}],
		"newly_explored_cells": []
	}, &"origin", "Visibility events should require an origin.")
	_assert_invalid_visibility_payload({
		"origin": {"x": 0, "y": 0},
		"radius": 0,
		"visible_cells": [{"x": 0, "y": 0}],
		"newly_explored_cells": []
	}, &"radius", "Visibility events should reject non-positive radius.")
	_assert_invalid_visibility_payload({
		"origin": {"x": 0, "y": 0},
		"radius": 4,
		"visible_cells": [],
		"newly_explored_cells": []
	}, &"visible_cells", "Visibility events should reject empty visible sets.")
	_assert_invalid_visibility_payload({
		"origin": {"x": 0, "y": 0},
		"radius": 4,
		"visible_cells": [{"x": 0, "y": 0}, {"x": 0, "y": 0}],
		"newly_explored_cells": []
	}, &"visible_cells", "Visibility events should reject duplicate visible cells.")
	_assert_invalid_visibility_payload({
		"origin": {"x": 0, "y": 0},
		"radius": 4,
		"visible_cells": [{"x": 0, "y": 0}],
		"newly_explored_cells": [{"x": 1, "y": 0}, {"x": 1, "y": 0}]
	}, &"newly_explored_cells", "Visibility events should reject duplicate newly explored cells.")


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
		DomainEvent.Type.ENTITY_MOVED: &"entity_moved",
		DomainEvent.Type.VISIBILITY_UPDATED: &"visibility_updated",
		DomainEvent.Type.ENTITY_ATTACKED: &"entity_attacked",
		DomainEvent.Type.DAMAGE_APPLIED: &"damage_applied",
		DomainEvent.Type.STATUS_EFFECT_APPLIED: &"status_effect_applied",
		DomainEvent.Type.ENTITY_KNOCKED_BACK: &"entity_knocked_back"
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


func _try_from_dictionary_rejects_malformed_attack_payloads() -> void:
	var damage_missing_target: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "damage_applied",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": {
			"amount": 4,
			"hp_before": 10,
			"hp_after": 6,
			"max_hp": 10,
			"weapon_id": "sword",
			"base_damage": 4,
			"support_bonus_damage": 0,
			"armor_reduction": 0,
			"block_succeeded": false,
			"damage_type": "physical",
			"rng_draws": []
		}
	})
	var damage_below_zero: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "damage_applied",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": {
			"target_entity_id": "enemy_1",
			"amount": 4,
			"hp_before": 3,
			"hp_after": -1,
			"max_hp": 10,
			"weapon_id": "sword",
			"base_damage": 4,
			"support_bonus_damage": 0,
			"armor_reduction": 0,
			"block_succeeded": false,
			"damage_type": "physical",
			"rng_draws": []
		}
	})
	var knockback_bad_cell: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "entity_knocked_back",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": {
			"target_entity_id": "enemy_1",
			"from": {"x": 2, "y": 1},
			"weapon_id": "crossbow"
		}
	})

	assert_equal(damage_missing_target.error_code, &"invalid_event_payload", "Damage events should require a target entity id.")
	assert_equal(damage_missing_target.metadata.get("field"), "target_entity_id", "Damage target diagnostics should identify the missing field.")
	assert_equal(damage_below_zero.error_code, &"invalid_event_payload", "Damage events should reject negative HP after damage.")
	assert_equal(damage_below_zero.metadata.get("field"), "hp_after", "Damage HP diagnostics should identify the invalid field.")
	assert_equal(knockback_bad_cell.error_code, &"invalid_event_payload", "Knockback events should require source and destination cells.")
	assert_equal(knockback_bad_cell.metadata.get("field"), "to", "Knockback diagnostics should identify the missing destination.")


func _assert_invalid_visibility_payload(payload: Dictionary, expected_field: StringName, message: String) -> void:
	var result_value: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "visibility_updated",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": payload
	})

	assert_true(result_value.is_error(), message)
	assert_equal(result_value.error_code, &"invalid_event_payload", message)
	assert_equal(result_value.metadata.get("field"), String(expected_field), message)


func _assert_round_trips(event: DomainEvent, expected_type: int, expected_id: String) -> void:
	var serialized: Dictionary = event.to_dictionary()
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(serialized)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent

	assert_equal(serialized.get("event_id"), expected_id, "%s should serialize a stable event id." % expected_id)
	assert_true(parse_result.succeeded, "%s should parse from its serialized dictionary." % expected_id)
	assert_equal(restored.event_type, expected_type, "%s should restore the expected enum type." % expected_id)
	assert_equal(restored.sequence_id, event.sequence_id, "%s should preserve sequence id." % expected_id)
	assert_equal(restored.actor_id, event.actor_id, "%s should preserve actor id." % expected_id)


func _attack_payload() -> Dictionary:
	return {
		"expected_base_damage": 4,
		"range": 1,
		"distance": 1,
		"line_cells": [{"x": 1, "y": 1}, {"x": 2, "y": 1}],
		"blocker_cells": [],
		"blocker_ignored": false,
		"warnings": [],
		"effects": [],
		"explanation": "sword previews 4 damage to enemy_1."
	}


func _rng_draw(effect_id: String, roll_value: float, threshold: float, succeeded: bool) -> Dictionary:
	return {
		"stream_name": "combat",
		"draw_index": 0,
		"roll_value": roll_value,
		"threshold": threshold,
		"effect_id": effect_id,
		"succeeded": succeeded
	}
