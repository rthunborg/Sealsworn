extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_run_started_serializes_and_parses_stable_payload()
	_route_advanced_serializes_and_parses_stable_payload()
	_route_advanced_rejects_malformed_payloads()
	_route_advanced_tolerates_hyphenated_node_ids()
	_node_entered_serializes_and_parses_stable_payload()
	_node_entered_rejects_malformed_payloads()
	_node_exited_serializes_and_parses_stable_payload()
	_node_exited_rejects_malformed_payloads()
	_route_sealed_serializes_and_parses_stable_payload()
	_route_sealed_rejects_malformed_payloads()
	_node_placeholder_resolved_serializes_and_parses_stable_payload()
	_node_placeholder_resolved_rejects_malformed_payloads()
	_run_completed_serializes_and_parses_stable_payload()
	_run_completed_rejects_malformed_payloads()
	_item_gained_serializes_and_parses_stable_payload()
	_item_gained_rejects_malformed_payloads()
	_reward_offered_serializes_and_parses_stable_payload()
	_reward_offered_rejects_malformed_payloads()
	_reward_resolved_serializes_and_parses_stable_payload()
	_reward_resolved_rejects_malformed_payloads()
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

	# Story 4.6 (closes the 4.1 Round-2 _has_decimal_string_payload loose-is_valid_int() defer): an OUT-OF-
	# int64-range decimal-string root_seed must now be REJECTED with the stable invalid_event_payload + field:
	# root_seed (it passes is_valid_int() but String.to_int() saturates/wraps it, so it does not round-trip).
	# max-int64+1 (wraps to negative) and an over-2^64 string (saturates to max-int64) are both rejected.
	for out_of_range_seed: String in ["9223372036854775808", "99999999999999999999"]:
		var oversize: ActionResult = DomainEvent.try_from_dictionary({
			"event_id": "run_started",
			"sequence_id": 1,
			"actor_id": "",
			"payload": {
				"root_seed": out_of_range_seed,
				"is_manual_seed": false,
				"node_count": 9
			}
		})
		assert_true(oversize.is_error(), "Run-started with an out-of-int64-range root_seed (%s) should be rejected (lossless round-trip)." % out_of_range_seed)
		assert_equal(oversize.error_code, &"invalid_event_payload", "An out-of-range root_seed should use the stable invalid_event_payload code (%s)." % out_of_range_seed)
		assert_equal(oversize.metadata.get("field"), "root_seed", "An out-of-range root_seed rejection should name the root_seed field (%s)." % out_of_range_seed)

	# The max-int64 value ITSELF (the largest in-range seed) must STILL round-trip (the lossless tighten must
	# not over-reject the boundary).
	var max_int64_seed: DomainEvent = DomainEvent.run_started(1, {
		"root_seed": "9223372036854775807",
		"is_manual_seed": false,
		"node_count": 12
	})
	var max_round_trip: Variant = JSON.parse_string(JSON.stringify(max_int64_seed.to_dictionary()))
	var max_parse: ActionResult = DomainEvent.try_from_dictionary(max_round_trip)
	assert_true(max_parse.succeeded, "Run-started with the max-int64 root_seed must still parse (the lossless tighten must not over-reject the boundary): %s" % max_parse.metadata)

	# node_count bounded-disposition check (closes the 4.1 Round-1 node_count raw-JSON-number defer as
	# permanently benign): the run_started payload carries node_count as a raw JSON integer (NOT decimal-string
	# encoded) and the validator accepts the MVP route's bounded [8, 12] non-boss count. node_count is a small
	# bounded count, never a seed, so it correctly stays a raw number; the run-start command pins the [8, 12]
	# bound across seeds (see test_run_start_command.gd).
	for bounded_count: int in [8, 12]:
		var counted: DomainEvent = DomainEvent.run_started(1, {
			"root_seed": "42",
			"is_manual_seed": false,
			"node_count": bounded_count
		})
		var counted_round_trip: Variant = JSON.parse_string(JSON.stringify(counted.to_dictionary()))
		var counted_parse: ActionResult = DomainEvent.try_from_dictionary(counted_round_trip)
		assert_true(counted_parse.succeeded, "Run-started with a bounded node_count (%d) must parse." % bounded_count)
		assert_equal((counted_parse.metadata.get("event") as DomainEvent).payload.get("node_count"), bounded_count, "node_count must round-trip as a raw integer (%d)." % bounded_count)


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


func _node_entered_serializes_and_parses_stable_payload() -> void:
	# Story 4.4: a node_entered SYSTEM event (no actor). node_id carries hyphens (plain non-empty string,
	# NOT lower_snake); node_type / recipe_id / size_class / level_request_node_id are lower_snake;
	# node_depth is a non-negative integral. Factory output must round-trip through real JSON.
	var event: DomainEvent = DomainEvent.node_entered(7, {
		"node_id": "node-1-0",
		"node_type": "combat",
		"node_depth": 1,
		"level_request_node_id": "node_1_0",
		"recipe_id": "small_combat_basic",
		"size_class": "small"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "node_entered", "node_entered should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "node_entered is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "node_entered should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.NODE_ENTERED, "node_entered should parse back to NODE_ENTERED.")
	assert_equal(restored.payload.get("node_id"), "node-1-0", "The hyphenated node id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("level_request_node_id"), "node_1_0", "The derived lower_snake request id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("recipe_id"), "small_combat_basic", "The recipe id must survive a JSON round-trip.")

	# A hyphenated node id with a boss-depth value also passes (the plain-string guard tolerates hyphens).
	var elite: DomainEvent = DomainEvent.node_entered(3, {
		"node_id": "node-4-1",
		"node_type": "elite_combat",
		"node_depth": 4,
		"level_request_node_id": "node_4_1",
		"recipe_id": "medium_combat_basic",
		"size_class": "medium"
	})
	var elite_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(elite.to_dictionary())))
	assert_true(elite_parse.succeeded, "node_entered with a hyphenated id + elite mapping should parse: %s" % elite_parse.metadata)


func _node_entered_rejects_malformed_payloads() -> void:
	# Missing node_id is rejected with the stable code + the offending field.
	var missing_node: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_entered",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_type": "combat",
			"node_depth": 1,
			"level_request_node_id": "node_1_0",
			"recipe_id": "small_combat_basic",
			"size_class": "small"
		}
	})
	assert_true(missing_node.is_error(), "node_entered missing node_id should be rejected.")
	assert_equal(missing_node.error_code, &"invalid_event_payload", "Malformed node_entered should use the stable code.")
	assert_equal(missing_node.metadata.get("field"), "node_id", "Malformed node_entered should name the missing field.")

	# A non-lower_snake node_type is rejected.
	var bad_type: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_entered",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"node_type": "Elite-Combat",
			"node_depth": 1,
			"level_request_node_id": "node_1_0",
			"recipe_id": "small_combat_basic",
			"size_class": "small"
		}
	})
	assert_true(bad_type.is_error(), "node_entered with a non-lower_snake type should be rejected.")
	assert_equal(bad_type.metadata.get("field"), "node_type", "node_entered should require a lower_snake node_type.")

	# A hyphenated level_request_node_id (NOT lower_snake) is rejected — the DERIVED request id must be
	# lower_snake (the command replaces hyphens; a hyphen here would be a bug).
	var bad_request_id: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_entered",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"node_type": "combat",
			"node_depth": 1,
			"level_request_node_id": "node-1-0",
			"recipe_id": "small_combat_basic",
			"size_class": "small"
		}
	})
	assert_true(bad_request_id.is_error(), "node_entered with a hyphenated level_request_node_id should be rejected.")
	assert_equal(bad_request_id.metadata.get("field"), "level_request_node_id", "node_entered should require a lower_snake level_request_node_id.")

	# A negative node_depth is rejected.
	var bad_depth: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_entered",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"node_type": "combat",
			"node_depth": -1,
			"level_request_node_id": "node_1_0",
			"recipe_id": "small_combat_basic",
			"size_class": "small"
		}
	})
	assert_true(bad_depth.is_error(), "node_entered with a negative depth should be rejected.")
	assert_equal(bad_depth.metadata.get("field"), "node_depth", "node_entered should require a non-negative depth.")


func _node_exited_serializes_and_parses_stable_payload() -> void:
	# Story 4.4: a node_exited SYSTEM event (no actor). node_id carries hyphens; node_type is lower_snake;
	# node_depth is non-negative integral; rewards_placeholder is a bool.
	var event: DomainEvent = DomainEvent.node_exited(9, {
		"node_id": "node-2-0",
		"node_type": "elite_combat",
		"node_depth": 2,
		"rewards_placeholder": true
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "node_exited", "node_exited should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "node_exited is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "node_exited should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.NODE_EXITED, "node_exited should parse back to NODE_EXITED.")
	assert_equal(restored.payload.get("node_id"), "node-2-0", "The hyphenated node id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("rewards_placeholder"), true, "The rewards_placeholder flag must survive a JSON round-trip.")

	# rewards_placeholder == false is also valid.
	var no_reward: DomainEvent = DomainEvent.node_exited(3, {
		"node_id": "node-3-0",
		"node_type": "combat",
		"node_depth": 3,
		"rewards_placeholder": false
	})
	var no_reward_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(no_reward.to_dictionary())))
	assert_true(no_reward_parse.succeeded, "node_exited with rewards_placeholder false should parse: %s" % no_reward_parse.metadata)


func _node_exited_rejects_malformed_payloads() -> void:
	# Missing node_id is rejected.
	var missing_node: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_exited",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_type": "combat",
			"node_depth": 1,
			"rewards_placeholder": true
		}
	})
	assert_true(missing_node.is_error(), "node_exited missing node_id should be rejected.")
	assert_equal(missing_node.metadata.get("field"), "node_id", "Malformed node_exited should name the missing field.")

	# A non-bool rewards_placeholder is rejected.
	var bad_reward: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_exited",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"node_type": "combat",
			"node_depth": 1,
			"rewards_placeholder": "yes"
		}
	})
	assert_true(bad_reward.is_error(), "node_exited with a non-bool rewards_placeholder should be rejected.")
	assert_equal(bad_reward.metadata.get("field"), "rewards_placeholder", "node_exited should require a bool rewards_placeholder.")


func _route_sealed_serializes_and_parses_stable_payload() -> void:
	# Story 4.4 (AC3): a route_sealed SYSTEM event (no actor) — the door-sealed containment cue. node_id
	# carries hyphens; cue_id is lower_snake (the command + tests assert the exact door_sealed_placeholder
	# value).
	var event: DomainEvent = DomainEvent.route_sealed(11, {
		"node_id": "node-1-0",
		"cue_id": "door_sealed_placeholder"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "route_sealed", "route_sealed should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "route_sealed is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "route_sealed should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.ROUTE_SEALED, "route_sealed should parse back to ROUTE_SEALED.")
	assert_equal(restored.payload.get("node_id"), "node-1-0", "The hyphenated sealed node id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("cue_id"), "door_sealed_placeholder", "The door-sealed cue id must survive a JSON round-trip.")


func _route_sealed_rejects_malformed_payloads() -> void:
	# Missing cue_id is rejected.
	var missing_cue: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "route_sealed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0"
		}
	})
	assert_true(missing_cue.is_error(), "route_sealed missing cue_id should be rejected.")
	assert_equal(missing_cue.metadata.get("field"), "cue_id", "Malformed route_sealed should name the missing cue_id field.")

	# Missing node_id is rejected.
	var missing_node: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "route_sealed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"cue_id": "door_sealed_placeholder"
		}
	})
	assert_true(missing_node.is_error(), "route_sealed missing node_id should be rejected.")
	assert_equal(missing_node.metadata.get("field"), "node_id", "Malformed route_sealed should name the missing node_id field.")

	# A non-lower_snake cue_id is rejected (the validator enforces the lower_snake shape).
	var bad_cue: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "route_sealed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"cue_id": "Door-Sealed"
		}
	})
	assert_true(bad_cue.is_error(), "route_sealed with a non-lower_snake cue_id should be rejected.")
	assert_equal(bad_cue.metadata.get("field"), "cue_id", "route_sealed should require a lower_snake cue_id.")


func _node_placeholder_resolved_serializes_and_parses_stable_payload() -> void:
	# Story 4.5: a node_placeholder_resolved SYSTEM event (no actor). node_id carries hyphens (plain
	# non-empty string, NOT lower_snake); node_type + resolution are lower_snake; node_depth is non-negative
	# integral. The resolution value must equal the stable placeholder_completed marker.
	var event: DomainEvent = DomainEvent.node_placeholder_resolved(7, {
		"node_id": "node-3-1",
		"node_type": "shop",
		"node_depth": 3,
		"resolution": "placeholder_completed"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "node_placeholder_resolved", "node_placeholder_resolved should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "node_placeholder_resolved is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "node_placeholder_resolved should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.NODE_PLACEHOLDER_RESOLVED, "node_placeholder_resolved should parse back to NODE_PLACEHOLDER_RESOLVED.")
	assert_equal(restored.payload.get("node_id"), "node-3-1", "The hyphenated node id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("node_type"), "shop", "The node type must survive a JSON round-trip.")
	assert_equal(restored.payload.get("resolution"), "placeholder_completed", "The resolution marker must survive a JSON round-trip.")

	# The boss is a placeholder node too (boss node_type round-trips through the same event).
	var boss_placeholder: DomainEvent = DomainEvent.node_placeholder_resolved(3, {
		"node_id": "node-7-0",
		"node_type": "boss",
		"node_depth": 7,
		"resolution": "placeholder_completed"
	})
	var boss_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(boss_placeholder.to_dictionary())))
	assert_true(boss_parse.succeeded, "node_placeholder_resolved for the boss should parse: %s" % boss_parse.metadata)


func _node_placeholder_resolved_rejects_malformed_payloads() -> void:
	# Missing node_id is rejected.
	var missing_node: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_placeholder_resolved",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_type": "shop",
			"node_depth": 1,
			"resolution": "placeholder_completed"
		}
	})
	assert_true(missing_node.is_error(), "node_placeholder_resolved missing node_id should be rejected.")
	assert_equal(missing_node.error_code, &"invalid_event_payload", "Malformed node_placeholder_resolved should use the stable code.")
	assert_equal(missing_node.metadata.get("field"), "node_id", "Malformed node_placeholder_resolved should name the missing field.")

	# A non-lower_snake node_type is rejected.
	var bad_type: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_placeholder_resolved",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"node_type": "Shop",
			"node_depth": 1,
			"resolution": "placeholder_completed"
		}
	})
	assert_true(bad_type.is_error(), "node_placeholder_resolved with a non-lower_snake node_type should be rejected.")
	assert_equal(bad_type.metadata.get("field"), "node_type", "node_placeholder_resolved should require a lower_snake node_type.")

	# A missing resolution is rejected.
	var missing_resolution: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_placeholder_resolved",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"node_type": "shop",
			"node_depth": 1
		}
	})
	assert_true(missing_resolution.is_error(), "node_placeholder_resolved missing resolution should be rejected.")
	assert_equal(missing_resolution.metadata.get("field"), "resolution", "node_placeholder_resolved should name the missing resolution field.")

	# A WRONG resolution value (lower_snake but not the pinned marker) is rejected (value-equality).
	var wrong_resolution: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_placeholder_resolved",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"node_type": "shop",
			"node_depth": 1,
			"resolution": "something_else"
		}
	})
	assert_true(wrong_resolution.is_error(), "node_placeholder_resolved with a non-marker resolution value should be rejected.")
	assert_equal(wrong_resolution.metadata.get("field"), "resolution", "node_placeholder_resolved should pin the exact resolution marker.")

	# A negative node_depth is rejected.
	var bad_depth: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "node_placeholder_resolved",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"node_id": "node-1-0",
			"node_type": "shop",
			"node_depth": -1,
			"resolution": "placeholder_completed"
		}
	})
	assert_true(bad_depth.is_error(), "node_placeholder_resolved with a negative depth should be rejected.")
	assert_equal(bad_depth.metadata.get("field"), "node_depth", "node_placeholder_resolved should require a non-negative depth.")


func _run_completed_serializes_and_parses_stable_payload() -> void:
	# Story 4.5 (AC3): a run_completed SYSTEM event (no actor) — the boss-placeholder run-END boundary.
	# outcome is lower_snake AND value-equal to the boss_placeholder marker; boss_node_id carries hyphens
	# (plain non-empty string); cleared_node_count is non-negative integral.
	var event: DomainEvent = DomainEvent.run_completed(11, {
		"outcome": "boss_placeholder",
		"boss_node_id": "node-7-0",
		"cleared_node_count": 9
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "run_completed", "run_completed should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "run_completed is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "run_completed should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.RUN_COMPLETED, "run_completed should parse back to RUN_COMPLETED.")
	assert_equal(restored.payload.get("outcome"), "boss_placeholder", "The boss_placeholder outcome must survive a JSON round-trip.")
	assert_equal(restored.payload.get("boss_node_id"), "node-7-0", "The hyphenated boss node id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("cleared_node_count"), 9, "The cleared_node_count must survive a JSON round-trip.")


func _run_completed_rejects_malformed_payloads() -> void:
	# A missing outcome is rejected.
	var missing_outcome: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"boss_node_id": "node-7-0",
			"cleared_node_count": 9
		}
	})
	assert_true(missing_outcome.is_error(), "run_completed missing outcome should be rejected.")
	assert_equal(missing_outcome.error_code, &"invalid_event_payload", "Malformed run_completed should use the stable code.")
	assert_equal(missing_outcome.metadata.get("field"), "outcome", "run_completed should name the missing outcome field.")

	# A WRONG outcome value (lower_snake but not the pinned marker) is rejected (value-equality, mirroring
	# level_victory_reached's outcome == "victory").
	var wrong_outcome: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"outcome": "victory",
			"boss_node_id": "node-7-0",
			"cleared_node_count": 9
		}
	})
	assert_true(wrong_outcome.is_error(), "run_completed with a non-marker outcome value should be rejected.")
	assert_equal(wrong_outcome.metadata.get("field"), "outcome", "run_completed should pin the exact boss_placeholder outcome marker.")

	# A missing boss_node_id is rejected.
	var missing_boss: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"outcome": "boss_placeholder",
			"cleared_node_count": 9
		}
	})
	assert_true(missing_boss.is_error(), "run_completed missing boss_node_id should be rejected.")
	assert_equal(missing_boss.metadata.get("field"), "boss_node_id", "run_completed should name the missing boss_node_id field.")

	# A negative cleared_node_count is rejected.
	var bad_count: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"outcome": "boss_placeholder",
			"boss_node_id": "node-7-0",
			"cleared_node_count": -1
		}
	})
	assert_true(bad_count.is_error(), "run_completed with a negative cleared_node_count should be rejected.")
	assert_equal(bad_count.metadata.get("field"), "cleared_node_count", "run_completed should require a non-negative cleared_node_count.")


func _item_gained_serializes_and_parses_stable_payload() -> void:
	# Story 6.2 (AC2): an item_gained SYSTEM event (no actor) — a backpack item pickup record. item_id is a
	# Story-6.1 content id (lower_snake, NO hyphens — unlike route node ids); category is lower_snake AND in the
	# allowlist; backpack_size_after + slot_index are non-negative integral.
	var event: DomainEvent = DomainEvent.item_gained(5, {
		"item_id": "minor_healing_draught",
		"category": "consumable",
		"backpack_size_after": 1,
		"slot_index": 0
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "item_gained", "item_gained should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "item_gained is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "item_gained should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.ITEM_GAINED, "item_gained should parse back to ITEM_GAINED.")
	assert_equal(restored.payload.get("item_id"), "minor_healing_draught", "The item_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("category"), "consumable", "The category must survive a JSON round-trip.")
	assert_equal(restored.payload.get("backpack_size_after"), 1, "backpack_size_after must survive a JSON round-trip.")
	assert_equal(restored.payload.get("slot_index"), 0, "slot_index must survive a JSON round-trip.")
	# Every allowlisted category is accepted (the four equippable + the two backpack-only).
	for category: String in ["weapon", "armor", "jewelry", "support", "consumable", "pickup"]:
		var per_category: ActionResult = DomainEvent.try_from_dictionary(DomainEvent.item_gained(1, {
			"item_id": "some_item",
			"category": category,
			"backpack_size_after": 1,
			"slot_index": 0
		}).to_dictionary())
		assert_true(per_category.succeeded, "item_gained should accept the allowlisted category '%s'." % category)


func _item_gained_rejects_malformed_payloads() -> void:
	# A missing item_id is rejected.
	var missing_item: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "item_gained",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"category": "consumable", "backpack_size_after": 1, "slot_index": 0}
	})
	assert_true(missing_item.is_error(), "item_gained missing item_id should be rejected.")
	assert_equal(missing_item.error_code, &"invalid_event_payload", "Malformed item_gained should use the stable code.")
	assert_equal(missing_item.metadata.get("field"), "item_id", "item_gained should name the missing item_id field.")

	# A hyphenated (non-lower_snake) item_id is rejected (item ids are lower_snake, UNLIKE route node ids).
	var hyphen_item: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "item_gained",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"item_id": "not-snake", "category": "consumable", "backpack_size_after": 1, "slot_index": 0}
	})
	assert_true(hyphen_item.is_error(), "item_gained with a hyphenated item_id should be rejected.")
	assert_equal(hyphen_item.metadata.get("field"), "item_id", "item_gained should reject a non-lower_snake item_id.")

	# A missing category is rejected.
	var missing_category: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "item_gained",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"item_id": "minor_healing_draught", "backpack_size_after": 1, "slot_index": 0}
	})
	assert_true(missing_category.is_error(), "item_gained missing category should be rejected.")
	assert_equal(missing_category.metadata.get("field"), "category", "item_gained should name the missing category field.")

	# An OFF-allowlist category (lower_snake but not a backpack category) is rejected.
	var bad_category: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "item_gained",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"item_id": "some_gold", "category": "gold_reward", "backpack_size_after": 1, "slot_index": 0}
	})
	assert_true(bad_category.is_error(), "item_gained with an off-allowlist category should be rejected.")
	assert_equal(bad_category.metadata.get("field"), "category", "item_gained should pin the category to the allowlist.")

	# A negative backpack_size_after is rejected.
	var bad_size: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "item_gained",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"item_id": "minor_healing_draught", "category": "consumable", "backpack_size_after": -1, "slot_index": 0}
	})
	assert_true(bad_size.is_error(), "item_gained with a negative backpack_size_after should be rejected.")
	assert_equal(bad_size.metadata.get("field"), "backpack_size_after", "item_gained should require a non-negative backpack_size_after.")

	# A negative slot_index is rejected.
	var bad_index: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "item_gained",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"item_id": "minor_healing_draught", "category": "consumable", "backpack_size_after": 1, "slot_index": -1}
	})
	assert_true(bad_index.is_error(), "item_gained with a negative slot_index should be rejected.")
	assert_equal(bad_index.metadata.get("field"), "slot_index", "item_gained should require a non-negative slot_index.")


func _reward_offered_serializes_and_parses_stable_payload() -> void:
	# Story 6.3 (AC1): a reward_offered SYSTEM event (no actor) — a deterministic reward-offer record. table_id +
	# each offered entry's category/content_id are Story-6.1 content ids (lower_snake, NO hyphens); the category
	# allowlist adds gold/passive; roll + draw_index are non-negative integral; offered_entries is a non-empty list.
	var event: DomainEvent = DomainEvent.reward_offered(7, {
		"table_id": "standard_combat_reward",
		"offered_entries": [
			{"category": "weapon", "content_id": "sword"},
			{"category": "gold", "content_id": "small_gold_purse"}
		],
		"roll": 3,
		"draw_index": 0
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "reward_offered", "reward_offered should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "reward_offered is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "reward_offered should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.REWARD_OFFERED, "reward_offered should parse back to REWARD_OFFERED.")
	assert_equal(restored.payload.get("table_id"), "standard_combat_reward", "The table_id must survive a JSON round-trip.")
	assert_equal((restored.payload.get("offered_entries") as Array).size(), 2, "The offered_entries must survive a JSON round-trip.")
	assert_equal(restored.payload.get("roll"), 3, "The roll must survive a JSON round-trip.")
	# The passive category is accepted (the reward allowlist is broader than the backpack allowlist).
	var passive_offer: ActionResult = DomainEvent.try_from_dictionary(DomainEvent.reward_offered(1, {
		"table_id": "passive_reward_choice",
		"offered_entries": [{"category": "passive", "content_id": "warrior_unbreakable_guard"}],
		"roll": 0, "draw_index": 0
	}).to_dictionary())
	assert_true(passive_offer.succeeded, "reward_offered should accept a passive offered entry (the reward allowlist adds passive).")


func _reward_offered_rejects_malformed_payloads() -> void:
	# A missing/hyphenated table_id is rejected.
	var bad_table: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_offered", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "not-snake", "offered_entries": [{"category": "weapon", "content_id": "sword"}], "roll": 0, "draw_index": 0}
	})
	assert_true(bad_table.is_error(), "reward_offered with a hyphenated table_id should be rejected.")
	assert_equal(bad_table.error_code, &"invalid_event_payload", "Malformed reward_offered should use the stable code.")
	assert_equal(bad_table.metadata.get("field"), "table_id", "reward_offered should name the table_id field.")

	# An EMPTY offered_entries list is rejected.
	var empty_entries: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_offered", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "standard_combat_reward", "offered_entries": [], "roll": 0, "draw_index": 0}
	})
	assert_true(empty_entries.is_error(), "reward_offered with an empty offered_entries list should be rejected.")
	assert_equal(empty_entries.metadata.get("field"), "offered_entries", "reward_offered should name the offered_entries field.")

	# An OFF-allowlist category in an offered entry is rejected.
	var bad_category: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_offered", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "standard_combat_reward", "offered_entries": [{"category": "relic", "content_id": "sword"}], "roll": 0, "draw_index": 0}
	})
	assert_true(bad_category.is_error(), "reward_offered with an off-allowlist entry category should be rejected.")
	assert_equal(bad_category.metadata.get("field"), "offered_entries", "reward_offered should pin entry categories to the allowlist.")

	# A non-lower_snake content_id in an offered entry is rejected.
	var bad_content: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_offered", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "standard_combat_reward", "offered_entries": [{"category": "weapon", "content_id": "Sword"}], "roll": 0, "draw_index": 0}
	})
	assert_true(bad_content.is_error(), "reward_offered with a non-lower_snake entry content_id should be rejected.")
	assert_equal(bad_content.metadata.get("field"), "offered_entries", "reward_offered should reject a non-lower_snake entry content_id.")

	# A negative roll is rejected.
	var bad_roll: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_offered", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "standard_combat_reward", "offered_entries": [{"category": "weapon", "content_id": "sword"}], "roll": -1, "draw_index": 0}
	})
	assert_true(bad_roll.is_error(), "reward_offered with a negative roll should be rejected.")
	assert_equal(bad_roll.metadata.get("field"), "roll", "reward_offered should require a non-negative roll.")

	# A negative draw_index is rejected.
	var bad_index: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_offered", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "standard_combat_reward", "offered_entries": [{"category": "weapon", "content_id": "sword"}], "roll": 0, "draw_index": -1}
	})
	assert_true(bad_index.is_error(), "reward_offered with a negative draw_index should be rejected.")
	assert_equal(bad_index.metadata.get("field"), "draw_index", "reward_offered should require a non-negative draw_index.")


func _reward_resolved_serializes_and_parses_stable_payload() -> void:
	# Story 6.3 (AC2): a reward_resolved SYSTEM event (no actor) — a reward-resolution record. table_id + content_id
	# are lower_snake content ids; category is lower_snake AND in the reward allowlist (adds gold/passive).
	var event: DomainEvent = DomainEvent.reward_resolved(8, {
		"table_id": "standard_combat_reward",
		"category": "weapon",
		"content_id": "sword"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "reward_resolved", "reward_resolved should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "reward_resolved is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "reward_resolved should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.REWARD_RESOLVED, "reward_resolved should parse back to REWARD_RESOLVED.")
	assert_equal(restored.payload.get("content_id"), "sword", "The content_id must survive a JSON round-trip.")
	# gold + passive categories are accepted.
	for category: String in ["gold", "passive"]:
		var per: ActionResult = DomainEvent.try_from_dictionary(DomainEvent.reward_resolved(1, {
			"table_id": "t", "category": category, "content_id": "some_id"
		}).to_dictionary())
		assert_true(per.succeeded, "reward_resolved should accept the reward category '%s'." % category)


func _reward_resolved_rejects_malformed_payloads() -> void:
	# A missing table_id is rejected.
	var missing_table: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_resolved", "sequence_id": 1, "actor_id": "",
		"payload": {"category": "weapon", "content_id": "sword"}
	})
	assert_true(missing_table.is_error(), "reward_resolved missing table_id should be rejected.")
	assert_equal(missing_table.metadata.get("field"), "table_id", "reward_resolved should name the table_id field.")

	# An off-allowlist category is rejected.
	var bad_category: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_resolved", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "t", "category": "relic", "content_id": "sword"}
	})
	assert_true(bad_category.is_error(), "reward_resolved with an off-allowlist category should be rejected.")
	assert_equal(bad_category.metadata.get("field"), "category", "reward_resolved should pin the category to the allowlist.")

	# A non-lower_snake content_id is rejected.
	var bad_content: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "reward_resolved", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "t", "category": "weapon", "content_id": "Sword"}
	})
	assert_true(bad_content.is_error(), "reward_resolved with a non-lower_snake content_id should be rejected.")
	assert_equal(bad_content.metadata.get("field"), "content_id", "reward_resolved should reject a non-lower_snake content_id.")


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
		DomainEvent.Type.ROUTE_ADVANCED: &"route_advanced",
		DomainEvent.Type.NODE_ENTERED: &"node_entered",
		DomainEvent.Type.NODE_EXITED: &"node_exited",
		DomainEvent.Type.ROUTE_SEALED: &"route_sealed",
		DomainEvent.Type.NODE_PLACEHOLDER_RESOLVED: &"node_placeholder_resolved",
		DomainEvent.Type.RUN_COMPLETED: &"run_completed",
		DomainEvent.Type.ITEM_GAINED: &"item_gained",
		# Story 6.3: the two new SYSTEM events appended at the enum end (never renumbered).
		DomainEvent.Type.REWARD_OFFERED: &"reward_offered",
		DomainEvent.Type.REWARD_RESOLVED: &"reward_resolved"
	}

	for event_type: int in expected_ids.keys():
		var event_id: StringName = DomainEvent.id_for_type(event_type)
		assert_equal(event_id, expected_ids[event_type], "DomainEvent ids should remain stable.")
		_assert_machine_id(String(event_id), "DomainEvent ids should be lower-snake machine ids.")
		# Round-trip: the id maps back to the same enum member (the append did not break type_for_id).
		assert_equal(DomainEvent.type_for_id(event_id), event_type, "DomainEvent id_for_type/type_for_id must round-trip.")


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
