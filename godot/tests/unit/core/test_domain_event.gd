extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_run_started_serializes_and_parses_stable_payload()
	_route_advanced_serializes_and_parses_stable_payload()
	_route_advanced_rejects_malformed_payloads()
	_route_advanced_tolerates_hyphenated_node_ids()
	_board_created_serializes_stable_event_id()
	_entity_moved_serializes_stable_payload()
	_event_dictionary_uses_deterministic_fields_and_copies_payload()
	_try_from_dictionary_parses_valid_event_dictionaries()
	_try_from_dictionary_parses_entity_moved_events()
	_visibility_updated_serializes_stable_payload()
	_attack_events_serialize_and_parse_stable_payloads()
	_enemy_turn_events_serialize_and_parse_stable_payloads()
	_outcome_events_serialize_and_parse_stable_payloads()
	_try_from_dictionary_rejects_malformed_entity_moved_payloads()
	_try_from_dictionary_rejects_malformed_visibility_payloads()
	_try_from_dictionary_rejects_malformed_attack_payloads()
	_try_from_dictionary_rejects_malformed_enemy_turn_payloads()
	_try_from_dictionary_rejects_malformed_outcome_payloads()
	_try_from_dictionary_accepts_json_round_tripped_integral_sequence_ids()
	_try_from_dictionary_rejects_malformed_event_dictionaries()
	_from_dictionary_keeps_unknown_compatibility_wrapper()
	_event_identifiers_are_stable_machine_ids()
	return result()


func _run_started_serializes_and_parses_stable_payload() -> void:
	# AC1: a run-started system event (no actor). Factory output must round-trip through
	# to_dictionary -> try_from_dictionary; an empty actor_id is accepted; a malformed payload is
	# rejected with the stable invalid_event_payload code.
	var event: DomainEvent = DomainEvent.run_started(1, {
		"root_seed": "9223372036854775000",
		"is_manual_seed": true,
		"node_count": 9
	})
	var serialized: Dictionary = event.to_dictionary()

	assert_equal(serialized.get("event_id"), "run_started", "Run-started events should serialize stable string ids.")
	assert_equal(serialized.get("actor_id"), "", "Run-started is a system event with an empty actor id.")
	assert_equal(serialized.get("payload", {}).get("root_seed"), "9223372036854775000", "Run-started should string-encode root_seed (int64-safe).")
	assert_equal(serialized.get("payload", {}).get("is_manual_seed"), true, "Run-started should serialize manual-seed flag.")
	assert_equal(serialized.get("payload", {}).get("node_count"), 9, "Run-started should serialize node count.")

	# Real JSON round-trip so the int64-string seed is exercised through stringify/parse.
	var json_data: Variant = JSON.parse_string(JSON.stringify(serialized))
	assert_true(json_data is Dictionary, "Run-started event should survive JSON stringify/parse.")
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(json_data)
	assert_true(parse_result.succeeded, "Run-started event should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.RUN_STARTED, "Run-started should parse back to RUN_STARTED.")
	assert_equal(restored.actor_id, &"", "Run-started restored actor id should stay empty.")
	assert_equal(String(restored.payload.get("root_seed")), "9223372036854775000", "Run-started seed must not lose precision through a JSON round-trip.")

	# A malformed payload (node_count missing) is rejected with the stable code.
	var malformed: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_started",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"root_seed": "42",
			"is_manual_seed": false
		}
	})
	assert_true(malformed.is_error(), "Malformed run-started payload should be rejected.")
	assert_equal(malformed.error_code, &"invalid_event_payload", "Malformed run-started payload should use the stable invalid_event_payload code.")
	assert_equal(malformed.metadata.get("field"), "node_count", "Malformed run-started payload should name the missing field.")

	# A non-string root_seed (raw int) is rejected — the seed must be the int64-safe string form.
	var numeric_seed: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_started",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"root_seed": 42,
			"is_manual_seed": false,
			"node_count": 3
		}
	})
	assert_true(numeric_seed.is_error(), "Run-started with a raw-int root_seed should be rejected.")
	assert_equal(numeric_seed.metadata.get("field"), "root_seed", "Run-started should require the decimal-string root_seed form.")


func _route_advanced_serializes_and_parses_stable_payload() -> void:
	# Story 4.3: a route-advanced SYSTEM event (no actor). Node ids carry hyphens, so they are plain
	# non-empty strings (NOT lower_snake); to_node_type is a lower_snake RouteNode.TYPE_* id. The
	# factory output must round-trip through to_dictionary -> JSON -> try_from_dictionary.
	var event: DomainEvent = DomainEvent.route_advanced(7, {
		"from_node_id": "node-0-0",
		"to_node_id": "node-1-0",
		"to_node_type": "elite_combat",
		"to_node_depth": 1,
		"cleared_node_id": "node-0-0",
		"revealed_node_ids": ["node-2-0", "node-2-1"]
	})
	var serialized: Dictionary = event.to_dictionary()

	assert_equal(serialized.get("event_id"), "route_advanced", "Route-advanced events should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "Route-advanced is a system event with an empty actor id.")
	var payload: Dictionary = serialized.get("payload", {})
	assert_equal(payload.get("from_node_id"), "node-0-0", "Route-advanced should carry the from-node id.")
	assert_equal(payload.get("to_node_id"), "node-1-0", "Route-advanced should carry the to-node id.")
	assert_equal(payload.get("to_node_type"), "elite_combat", "Route-advanced should carry the arrived node type.")
	assert_equal(payload.get("to_node_depth"), 1, "Route-advanced should carry the arrived node depth.")
	assert_equal(payload.get("cleared_node_id"), "node-0-0", "Route-advanced should carry the cleared (left) node id.")
	assert_equal(payload.get("revealed_node_ids"), ["node-2-0", "node-2-1"], "Route-advanced should carry the newly-revealed ids.")

	# Real JSON round-trip.
	var json_data: Variant = JSON.parse_string(JSON.stringify(serialized))
	assert_true(json_data is Dictionary, "Route-advanced event should survive JSON stringify/parse.")
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(json_data)
	assert_true(parse_result.succeeded, "Route-advanced event should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.ROUTE_ADVANCED, "Route-advanced should parse back to ROUTE_ADVANCED.")
	assert_equal(restored.actor_id, &"", "Route-advanced restored actor id should stay empty.")
	assert_equal(restored.payload.get("to_node_id"), "node-1-0", "Route-advanced to-node id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("revealed_node_ids"), ["node-2-0", "node-2-1"], "Revealed ids must survive a JSON round-trip.")

	# An empty revealed_node_ids list is valid (a node arriving at an all-already-revealed tier).
	var no_reveal: DomainEvent = DomainEvent.route_advanced(3, {
		"from_node_id": "node-0-0",
		"to_node_id": "node-1-0",
		"to_node_type": "combat",
		"to_node_depth": 1,
		"cleared_node_id": "node-0-0",
		"revealed_node_ids": []
	})
	var no_reveal_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(no_reveal.to_dictionary())))
	assert_true(no_reveal_parse.succeeded, "Route-advanced with an empty revealed list should parse: %s" % no_reveal_parse.metadata)


func _route_advanced_rejects_malformed_payloads() -> void:
	# Missing to_node_id is rejected with the stable invalid_event_payload code + the offending field.
	var missing_to: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "route_advanced",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"from_node_id": "node-0-0",
			"to_node_type": "combat",
			"to_node_depth": 1,
			"cleared_node_id": "node-0-0",
			"revealed_node_ids": []
		}
	})
	assert_true(missing_to.is_error(), "Route-advanced missing to_node_id should be rejected.")
	assert_equal(missing_to.error_code, &"invalid_event_payload", "Malformed route-advanced should use the stable code.")
	assert_equal(missing_to.metadata.get("field"), "to_node_id", "Malformed route-advanced should name the missing field.")

	# A non-lower_snake to_node_type is rejected.
	var bad_type: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "route_advanced",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"from_node_id": "node-0-0",
			"to_node_id": "node-1-0",
			"to_node_type": "Elite-Combat",
			"to_node_depth": 1,
			"cleared_node_id": "node-0-0",
			"revealed_node_ids": []
		}
	})
	assert_true(bad_type.is_error(), "Route-advanced with a non-lower_snake type should be rejected.")
	assert_equal(bad_type.metadata.get("field"), "to_node_type", "Route-advanced should require a lower_snake to_node_type.")

	# A negative to_node_depth is rejected.
	var bad_depth: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "route_advanced",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"from_node_id": "node-0-0",
			"to_node_id": "node-1-0",
			"to_node_type": "combat",
			"to_node_depth": -1,
			"cleared_node_id": "node-0-0",
			"revealed_node_ids": []
		}
	})
	assert_true(bad_depth.is_error(), "Route-advanced with a negative depth should be rejected.")
	assert_equal(bad_depth.metadata.get("field"), "to_node_depth", "Route-advanced should require a non-negative depth.")

	# A revealed_node_ids list with a non-string entry is rejected.
	var bad_revealed: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "route_advanced",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"from_node_id": "node-0-0",
			"to_node_id": "node-1-0",
			"to_node_type": "combat",
			"to_node_depth": 1,
			"cleared_node_id": "node-0-0",
			"revealed_node_ids": ["node-2-0", 42]
		}
	})
	assert_true(bad_revealed.is_error(), "Route-advanced with a non-string revealed id should be rejected.")
	assert_equal(bad_revealed.metadata.get("field"), "revealed_node_ids", "Route-advanced should reject a malformed revealed list.")

	# A revealed_node_ids list containing a duplicate id is rejected (de-dup guarantee #1: the
	# validator itself rejects duplicates, mirroring the defeated_enemy_ids duplicate guard).
	var duplicate_revealed: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "route_advanced",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"from_node_id": "node-0-0",
			"to_node_id": "node-1-0",
			"to_node_type": "combat",
			"to_node_depth": 1,
			"cleared_node_id": "node-0-0",
			"revealed_node_ids": ["node-2-0", "node-2-0"]
		}
	})
	assert_true(duplicate_revealed.is_error(), "Route-advanced with a duplicate revealed id should be rejected.")
	assert_equal(duplicate_revealed.error_code, &"invalid_event_payload", "Duplicate revealed ids should use the stable invalid_event_payload code.")
	assert_equal(duplicate_revealed.metadata.get("field"), "revealed_node_ids", "Route-advanced should reject a duplicate revealed list.")


func _route_advanced_tolerates_hyphenated_node_ids() -> void:
	# Regression for the "ids aren't lower_snake" trap: hyphenated node ids (node-1-0) MUST survive
	# payload validation. The plain-string guards must NOT enforce lower_snake (which rejects hyphens).
	var event: DomainEvent = DomainEvent.route_advanced(5, {
		"from_node_id": "node-3-1",
		"to_node_id": "node-4-0",
		"to_node_type": "boss",
		"to_node_depth": 7,
		"cleared_node_id": "node-3-1",
		"revealed_node_ids": ["node-5-0"]
	})
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parse_result.succeeded, "Hyphenated node ids must pass route-advanced payload validation: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.payload.get("from_node_id"), "node-3-1", "Hyphenated from-node id must survive validation.")
	assert_equal(restored.payload.get("revealed_node_ids"), ["node-5-0"], "Hyphenated revealed id must survive validation.")


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
			"final_damage": 4,
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


func _enemy_turn_events_serialize_and_parse_stable_payloads() -> void:
	var marked: DomainEvent = DomainEvent.tile_marked(
		15,
		&"enemy_seer",
		&"hero",
		Vector2i(1, 2),
		"ash_seer_mark:enemy_seer:15",
		{
			"enemy_definition_id": "ash_seer",
			"created_turn_number": 1,
			"due_turn_number": 2,
			"damage": 4,
			"damage_type": "physical",
			"explanation": "Ash Seer marked hero's tile."
		}
	)
	var detonated: DomainEvent = DomainEvent.marked_tile_detonated(
		16,
		&"enemy_seer",
		&"hero",
		Vector2i(1, 2),
		"ash_seer_mark:enemy_seer:15",
		&"hit",
		{
			"damage": 4,
			"damage_type": "physical",
			"explanation": "Ash Seer mark detonated."
		}
	)
	var waited: DomainEvent = DomainEvent.enemy_waited(
		17,
		&"enemy_iron",
		&"blocked",
		{
			"enemy_definition_id": "iron_cultist",
			"action_id": "wait",
			"score": 0,
			"reasons": ["no_legal_approach"],
			"explanation": "Iron Cultist waited because it was blocked."
		}
	)

	_assert_round_trips(marked, DomainEvent.Type.TILE_MARKED, "tile_marked")
	_assert_round_trips(detonated, DomainEvent.Type.MARKED_TILE_DETONATED, "marked_tile_detonated")
	_assert_round_trips(waited, DomainEvent.Type.ENEMY_WAITED, "enemy_waited")
	assert_equal(marked.to_dictionary().get("payload", {}).get("marked_cell"), {"x": 1, "y": 2}, "Mark events should serialize marked cells.")
	assert_equal(detonated.to_dictionary().get("payload", {}).get("outcome"), "hit", "Detonation events should serialize hit/avoided outcome.")
	assert_equal(waited.to_dictionary().get("payload", {}).get("reason"), "blocked", "Wait events should serialize the stable wait reason.")


func _outcome_events_serialize_and_parse_stable_payloads() -> void:
	var victory: DomainEvent = DomainEvent.level_victory_reached(
		18,
		1,
		0,
		["enemy_iron", "enemy_seer"],
		17,
		"All enemies were defeated."
	)
	var defeat: DomainEvent = DomainEvent.level_defeat_reached(
		19,
		&"hero",
		18,
		&"damage_applied",
		&"enemy_seer",
		&"physical",
		4,
		"Hero fell to Ash Seer detonation."
	)

	_assert_round_trips(victory, DomainEvent.Type.LEVEL_VICTORY_REACHED, "level_victory_reached")
	_assert_round_trips(defeat, DomainEvent.Type.LEVEL_DEFEAT_REACHED, "level_defeat_reached")
	assert_equal(victory.to_dictionary().get("actor_id"), "", "Outcome events should be system events without an actor.")
	assert_equal(victory.to_dictionary().get("payload", {}).get("outcome"), "victory", "Victory events should record the outcome id.")
	assert_equal(victory.to_dictionary().get("payload", {}).get("defeated_enemy_ids"), ["enemy_iron", "enemy_seer"], "Victory events should serialize defeated enemy ids in stable order.")
	assert_equal(defeat.to_dictionary().get("payload", {}).get("outcome"), "defeat", "Defeat events should record the outcome id.")
	assert_equal(defeat.to_dictionary().get("payload", {}).get("cause_event_id"), "damage_applied", "Defeat events should serialize cause event ids.")
	assert_equal(defeat.to_dictionary().get("payload", {}).get("final_damage"), 4, "Defeat events should serialize cause damage.")


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
		DomainEvent.Type.ENTITY_KNOCKED_BACK: &"entity_knocked_back",
		DomainEvent.Type.TILE_MARKED: &"tile_marked",
		DomainEvent.Type.MARKED_TILE_DETONATED: &"marked_tile_detonated",
		DomainEvent.Type.ENEMY_WAITED: &"enemy_waited",
		DomainEvent.Type.LEVEL_VICTORY_REACHED: &"level_victory_reached",
		DomainEvent.Type.LEVEL_DEFEAT_REACHED: &"level_defeat_reached",
		DomainEvent.Type.ROUTE_ADVANCED: &"route_advanced"
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
			"final_damage": 4,
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
			"final_damage": 4,
			"damage_type": "physical",
			"rng_draws": []
		}
	})
	var damage_missing_final_damage: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "damage_applied",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": {
			"target_entity_id": "enemy_1",
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
	var damage_mismatched_final_damage: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "damage_applied",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": {
			"target_entity_id": "enemy_1",
			"amount": 4,
			"hp_before": 10,
			"hp_after": 6,
			"max_hp": 10,
			"weapon_id": "sword",
			"base_damage": 4,
			"support_bonus_damage": 0,
			"armor_reduction": 0,
			"block_succeeded": false,
			"final_damage": 3,
			"damage_type": "physical",
			"rng_draws": []
		}
	})
	var attacked_missing_weapon: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "entity_attacked",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": {
			"actor_id": "hero",
			"target_entity_id": "enemy_1",
			"target_cell": {"x": 2, "y": 1},
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
	})
	var status_missing_effect: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "status_effect_applied",
		"sequence_id": 1,
		"actor_id": "hero",
		"payload": {
			"target_entity_id": "enemy_1",
			"weapon_id": "axe",
			"rng_draw": _rng_draw("bleed", 0.2, 0.35, true)
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
	assert_equal(damage_missing_final_damage.error_code, &"invalid_event_payload", "Damage events should require final damage metadata.")
	assert_equal(damage_missing_final_damage.metadata.get("field"), "final_damage", "Damage final-damage diagnostics should identify the missing field.")
	assert_equal(damage_mismatched_final_damage.error_code, &"invalid_event_payload", "Damage events should reject contradictory final damage metadata.")
	assert_equal(damage_mismatched_final_damage.metadata.get("field"), "final_damage", "Damage final-damage mismatch diagnostics should identify the invalid field.")
	assert_equal(attacked_missing_weapon.error_code, &"invalid_event_payload", "Attack events should require weapon metadata.")
	assert_equal(attacked_missing_weapon.metadata.get("field"), "weapon_id", "Attack diagnostics should identify the missing weapon id.")
	assert_equal(status_missing_effect.error_code, &"invalid_event_payload", "Status events should require an effect id.")
	assert_equal(status_missing_effect.metadata.get("field"), "effect_id", "Status diagnostics should identify the missing effect id.")
	assert_equal(knockback_bad_cell.error_code, &"invalid_event_payload", "Knockback events should require source and destination cells.")
	assert_equal(knockback_bad_cell.metadata.get("field"), "to", "Knockback diagnostics should identify the missing destination.")


func _try_from_dictionary_rejects_malformed_enemy_turn_payloads() -> void:
	var mark_missing_cell: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "tile_marked",
		"sequence_id": 1,
		"actor_id": "enemy_seer",
		"payload": {
			"target_entity_id": "hero",
			"telegraph_id": "ash_seer_mark:enemy_seer:1",
			"enemy_definition_id": "ash_seer",
			"created_turn_number": 1,
			"due_turn_number": 2,
			"damage": 4,
			"damage_type": "physical",
			"explanation": "Ash Seer marked hero."
		}
	})
	var detonation_bad_outcome: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "marked_tile_detonated",
		"sequence_id": 1,
		"actor_id": "enemy_seer",
		"payload": {
			"target_entity_id": "hero",
			"marked_cell": {"x": 1, "y": 2},
			"telegraph_id": "ash_seer_mark:enemy_seer:1",
			"outcome": "maybe",
			"damage": 4,
			"damage_type": "physical",
			"explanation": "Ash Seer mark detonated."
		}
	})
	var wait_missing_reason: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "enemy_waited",
		"sequence_id": 1,
		"actor_id": "enemy_iron",
		"payload": {
			"enemy_definition_id": "iron_cultist",
			"action_id": "wait",
			"score": 0,
			"reasons": [],
			"explanation": "Iron Cultist waited."
		}
	})

	assert_equal(mark_missing_cell.error_code, &"invalid_event_payload", "Tile mark events should require marked cells.")
	assert_equal(mark_missing_cell.metadata.get("field"), "marked_cell", "Tile mark diagnostics should identify the missing cell.")
	assert_equal(detonation_bad_outcome.error_code, &"invalid_event_payload", "Detonation events should reject unknown outcomes.")
	assert_equal(detonation_bad_outcome.metadata.get("field"), "outcome", "Detonation diagnostics should identify the invalid outcome.")
	assert_equal(wait_missing_reason.error_code, &"invalid_event_payload", "Enemy wait events should require a wait reason.")
	assert_equal(wait_missing_reason.metadata.get("field"), "reason", "Wait diagnostics should identify the missing reason.")


func _try_from_dictionary_rejects_malformed_outcome_payloads() -> void:
	var victory_missing_explanation: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "level_victory_reached",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"outcome": "victory",
			"living_player_count": 1,
			"remaining_enemy_count": 0,
			"defeated_enemy_ids": ["enemy_iron"],
			"cause_event_sequence_id": 12
		}
	})
	var victory_bad_remaining: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "level_victory_reached",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"outcome": "victory",
			"living_player_count": 1,
			"remaining_enemy_count": 1,
			"defeated_enemy_ids": ["enemy_iron"],
			"cause_event_sequence_id": 12,
			"explanation": "All enemies defeated."
		}
	})
	var defeat_missing_player: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "level_defeat_reached",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"outcome": "defeat",
			"cause_event_sequence_id": 12,
			"cause_event_id": "damage_applied",
			"source_entity_id": "enemy_iron",
			"damage_type": "physical",
			"final_damage": 3,
			"explanation": "Hero fell."
		}
	})
	var defeat_bad_damage_type: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "level_defeat_reached",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"outcome": "defeat",
			"defeated_player_id": "hero",
			"cause_event_sequence_id": 12,
			"cause_event_id": "damage_applied",
			"source_entity_id": "enemy_iron",
			"damage_type": "Physical",
			"final_damage": 3,
			"explanation": "Hero fell."
		}
	})

	assert_equal(victory_missing_explanation.error_code, &"invalid_event_payload", "Victory events should require readable explanations.")
	assert_equal(victory_missing_explanation.metadata.get("field"), "explanation", "Victory diagnostics should identify missing explanations.")
	assert_equal(victory_bad_remaining.error_code, &"invalid_event_payload", "Victory events should require zero remaining enemies.")
	assert_equal(victory_bad_remaining.metadata.get("field"), "remaining_enemy_count", "Victory diagnostics should identify remaining enemy contradictions.")
	assert_equal(defeat_missing_player.error_code, &"invalid_event_payload", "Defeat events should require defeated player ids.")
	assert_equal(defeat_missing_player.metadata.get("field"), "defeated_player_id", "Defeat diagnostics should identify missing player ids.")
	assert_equal(defeat_bad_damage_type.error_code, &"invalid_event_payload", "Defeat events should require lower-snake damage types.")
	assert_equal(defeat_bad_damage_type.metadata.get("field"), "damage_type", "Defeat diagnostics should identify invalid damage type.")


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
