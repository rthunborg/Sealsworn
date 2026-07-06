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
	_run_completed_completion_outcome_serializes_and_parses()
	_run_completed_victory_outcome_serializes_and_parses()
	_run_completed_rejects_broadened_malformed_payloads()
	_run_failed_serializes_and_parses_stable_payload()
	_run_failed_rejects_malformed_payloads()
	_oath_shards_awarded_serializes_and_parses_stable_payload()
	_oath_shards_awarded_rejects_malformed_payloads()
	_oath_shards_spent_serializes_and_parses_stable_payload()
	_oath_shards_spent_rejects_malformed_payloads()
	_content_discovered_serializes_and_parses_stable_payload()
	_content_discovered_rejects_malformed_payloads()
	_profile_progress_merged_serializes_and_parses_stable_payload()
	_profile_progress_merged_rejects_malformed_payloads()
	_first_death_recorded_serializes_and_parses_stable_payload()
	_first_death_recorded_rejects_malformed_payloads()
	_boss_encounter_started_serializes_and_parses_stable_payload()
	_boss_encounter_started_rejects_malformed_payloads()
	_boss_phase_changed_serializes_and_parses_stable_payload()
	_boss_phase_changed_rejects_malformed_payloads()
	_first_victory_recorded_serializes_and_parses_stable_payload()
	_first_victory_recorded_rejects_malformed_payloads()
	_boss_defeated_serializes_and_parses_stable_payload()
	_boss_defeated_rejects_malformed_payloads()
	_item_gained_serializes_and_parses_stable_payload()
	_item_gained_rejects_malformed_payloads()
	_reward_offered_serializes_and_parses_stable_payload()
	_reward_offered_rejects_malformed_payloads()
	_reward_resolved_serializes_and_parses_stable_payload()
	_reward_resolved_rejects_malformed_payloads()
	_passive_consumed_serializes_and_parses_stable_payload()
	_passive_consumed_rejects_malformed_payloads()
	_passive_destroyed_serializes_and_parses_stable_payload()
	_passive_destroyed_rejects_malformed_payloads()
	_item_consumed_serializes_and_parses_stable_payload()
	_item_consumed_rejects_malformed_payloads()
	_economy_changed_serializes_and_parses_stable_payload()
	_economy_changed_rejects_malformed_payloads()
	_curse_applied_serializes_and_parses_stable_payload()
	_curse_applied_rejects_malformed_payloads()
	_event_offered_serializes_and_parses_stable_payload()
	_event_offered_rejects_malformed_payloads()
	_event_resolved_serializes_and_parses_stable_payload()
	_event_resolved_rejects_malformed_payloads()
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
	# Story 8.1 (AC2): the boss run_completed now ALSO carries the outpost next-destination flow signal (defaulted by
	# the factory) — the boss path picks it up automatically without changing the boss outcome value.
	assert_equal(restored.payload.get("next_destination"), "outpost", "The boss run_completed must carry the outpost next-destination (defaulted by the factory).")


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

	# A WRONG outcome value (lower_snake but not in the completion allowlist) is rejected (value-equality, mirroring
	# level_victory_reached's outcome == "victory"). Story 9.4: `victory` is now a VALID marker (the 8.1-reserved value,
	# unblocked), so a genuine garbage value (`not_a_real_outcome`) takes over as the non-marker example here.
	var wrong_outcome: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"outcome": "not_a_real_outcome",
			"boss_node_id": "node-7-0",
			"cleared_node_count": 9
		}
	})
	assert_true(wrong_outcome.is_error(), "run_completed with a non-marker outcome value should be rejected.")
	assert_equal(wrong_outcome.metadata.get("field"), "outcome", "run_completed should pin the allowlisted outcome markers (boss_placeholder/completed/victory).")

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


func _run_completed_completion_outcome_serializes_and_parses() -> void:
	# Story 8.1 (AC2): the BROADENED run_completed for a generic completion/victory — outcome `completed` (NOT the boss
	# placeholder), NO boss_node_id (tolerated absent for a non-boss completion), the outpost next-destination flow
	# signal. It validates + round-trips through real JSON, exactly like the boss path.
	var event: DomainEvent = DomainEvent.run_completed(31, {
		"outcome": "completed",
		"cleared_node_count": 8,
		"next_destination": "outpost"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "run_completed", "A generic completion still uses the run_completed event id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "A generic completion run_completed should validate (the broadened allowlist): %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.payload.get("outcome"), "completed", "The `completed` outcome must survive a JSON round-trip.")
	assert_equal(restored.payload.get("cleared_node_count"), 8, "The cleared_node_count must survive a JSON round-trip.")
	assert_equal(restored.payload.get("next_destination"), "outpost", "The outpost next-destination must survive a JSON round-trip.")

	# A non-boss completion does not require boss_node_id (the factory does not set it; the validator tolerates it).
	assert_false(restored.payload.has("boss_node_id"), "A generic completion run_completed should NOT carry a boss_node_id.")

	# The marker const is pinned.
	assert_equal(String(DomainEvent.RUN_COMPLETED_OUTCOME_COMPLETED), "completed", "RUN_COMPLETED_OUTCOME_COMPLETED must be `completed`.")
	assert_equal(String(DomainEvent.RUN_END_DESTINATION_OUTPOST), "outpost", "RUN_END_DESTINATION_OUTPOST must be `outpost`.")


func _run_completed_victory_outcome_serializes_and_parses() -> void:
	# Story 9.4 (AC1): the REAL Larval-Avatar boss VICTORY — outcome `victory` (the 8.1-reserved third completion marker,
	# now UNBLOCKED), NO boss_node_id (a non-boss completion), the outpost next-destination flow signal. It VALIDATES +
	# round-trips through real JSON, exactly like the `completed` completion — the run-victory IS run_completed + outcome ==
	# victory (NOT a parallel run_victory event).
	var event: DomainEvent = DomainEvent.run_completed(41, {
		"outcome": "victory",
		"cleared_node_count": 9,
		"next_destination": "outpost"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "run_completed", "The boss victory still uses the run_completed event id (no parallel run_victory event).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "A `victory` run_completed should validate (the 9.4-unblocked allowlist): %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(String(restored.payload.get("outcome")), "victory", "The `victory` outcome must survive a JSON round-trip.")
	assert_equal(int(restored.payload.get("cleared_node_count")), 9, "The cleared_node_count must survive a JSON round-trip.")
	assert_equal(String(restored.payload.get("next_destination")), "outpost", "The outpost next-destination must survive a JSON round-trip.")
	# A victory (like a generic completion) carries NO boss node id (the boss defeat derives boss progress from the route).
	assert_false(restored.payload.has("boss_node_id"), "A `victory` run_completed should NOT carry a boss_node_id (a non-boss-placeholder completion).")

	# The marker const is pinned.
	assert_equal(String(DomainEvent.RUN_COMPLETED_OUTCOME_VICTORY), "victory", "RUN_COMPLETED_OUTCOME_VICTORY must be `victory`.")


func _run_completed_rejects_broadened_malformed_payloads() -> void:
	# Story 9.4 (AC1): `victory` is now an ACCEPTED completion outcome (the 8.1-reserved marker, UNBLOCKED). A WRONG/garbage
	# outcome (lower_snake but none of boss_placeholder / completed / victory — e.g. `not_a_real_outcome`) is still REJECTED
	# (the allowlist did not become permissive — this is the load-bearing AC2/AC1 guard; a NEW garbage value takes over as
	# the rejection guard now that `victory` is a real marker).
	var stray: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"outcome": "not_a_real_outcome", "cleared_node_count": 8, "next_destination": "outpost"}
	})
	assert_true(stray.is_error(), "A stray `not_a_real_outcome` outcome must still be rejected (the allowlist is boss_placeholder/completed/victory).")
	assert_equal(stray.metadata.get("field"), "outcome", "A garbage outcome should name the outcome field.")

	# A `completed` outcome MISSING the next_destination flow signal is rejected (the destination is required — FR32).
	var missing_destination: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"outcome": "completed", "cleared_node_count": 8}
	})
	assert_true(missing_destination.is_error(), "A completion run_completed missing next_destination should be rejected.")
	assert_equal(missing_destination.metadata.get("field"), "next_destination", "A missing destination should name the next_destination field.")

	# A `completed` outcome with a WRONG destination (not the outpost marker) is rejected.
	var wrong_destination: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"outcome": "completed", "cleared_node_count": 8, "next_destination": "dungeon"}
	})
	assert_true(wrong_destination.is_error(), "A completion run_completed with a non-outpost destination should be rejected.")
	assert_equal(wrong_destination.metadata.get("field"), "next_destination", "A wrong destination should name the next_destination field.")

	# A non-boss completion with a PRESENT-but-non-string boss_node_id is rejected (tolerant of ABSENCE, not of garbage).
	var bad_boss_field: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_completed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"outcome": "completed", "boss_node_id": 42, "cleared_node_count": 8, "next_destination": "outpost"}
	})
	assert_true(bad_boss_field.is_error(), "A completion run_completed with a non-string boss_node_id should be rejected.")
	assert_equal(bad_boss_field.metadata.get("field"), "boss_node_id", "A non-string boss_node_id should name the boss_node_id field.")


func _run_failed_serializes_and_parses_stable_payload() -> void:
	# Story 8.1 (AC1): a run_failed SYSTEM event (no actor) — the run-FAILED boundary. cause is lower_snake AND in the
	# allowlist; node_id carries hyphens (plain string, OPTIONAL); cleared_node_count is non-negative integral;
	# next_destination is the outpost marker.
	var event: DomainEvent = DomainEvent.run_failed(12, {
		"cause": "hero_death",
		"node_id": "node-3-1",
		"cleared_node_count": 4,
		"next_destination": "outpost"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "run_failed", "run_failed should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "run_failed is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "run_failed should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.RUN_FAILED, "run_failed should parse back to RUN_FAILED.")
	assert_equal(restored.payload.get("cause"), "hero_death", "The cause must survive a JSON round-trip.")
	assert_equal(restored.payload.get("node_id"), "node-3-1", "The hyphenated node id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("cleared_node_count"), 4, "The cleared_node_count must survive a JSON round-trip.")
	assert_equal(restored.payload.get("next_destination"), "outpost", "The outpost next-destination must survive a JSON round-trip.")

	# An abandoned-at-a-choice run has NO node — an EMPTY node_id is tolerated.
	var abandoned: DomainEvent = DomainEvent.run_failed(13, {
		"cause": "abandoned",
		"node_id": "",
		"cleared_node_count": 0,
		"next_destination": "outpost"
	})
	var abandoned_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(abandoned.to_dictionary())))
	assert_true(abandoned_parse.succeeded, "run_failed with an empty node_id (abandoned at a choice) should validate: %s" % abandoned_parse.metadata)


func _run_failed_rejects_malformed_payloads() -> void:
	# A missing cause is rejected.
	var missing_cause: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_failed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"node_id": "node-1-0", "cleared_node_count": 1, "next_destination": "outpost"}
	})
	assert_true(missing_cause.is_error(), "run_failed missing cause should be rejected.")
	assert_equal(missing_cause.error_code, &"invalid_event_payload", "Malformed run_failed should use the stable code.")
	assert_equal(missing_cause.metadata.get("field"), "cause", "run_failed should name the missing cause field.")

	# An OFF-ALLOWLIST cause (lower_snake but not in RUN_FAILED_CAUSES) is rejected.
	var bad_cause: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_failed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"cause": "exploded", "node_id": "node-1-0", "cleared_node_count": 1, "next_destination": "outpost"}
	})
	assert_true(bad_cause.is_error(), "run_failed with an off-allowlist cause should be rejected.")
	assert_equal(bad_cause.metadata.get("field"), "cause", "An off-allowlist cause should name the cause field.")

	# A non-string node_id is rejected (node_id is empty-tolerant but must be a string when present).
	var bad_node: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_failed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"cause": "hero_death", "node_id": 7, "cleared_node_count": 1, "next_destination": "outpost"}
	})
	assert_true(bad_node.is_error(), "run_failed with a non-string node_id should be rejected.")
	assert_equal(bad_node.metadata.get("field"), "node_id", "A non-string node_id should name the node_id field.")

	# A negative cleared_node_count is rejected.
	var bad_count: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_failed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"cause": "hero_death", "node_id": "node-1-0", "cleared_node_count": -1, "next_destination": "outpost"}
	})
	assert_true(bad_count.is_error(), "run_failed with a negative cleared_node_count should be rejected.")
	assert_equal(bad_count.metadata.get("field"), "cleared_node_count", "run_failed should require a non-negative cleared_node_count.")

	# A missing/wrong next_destination is rejected (FR32 — death routes to the outpost).
	var missing_destination: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_failed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"cause": "hero_death", "node_id": "node-1-0", "cleared_node_count": 1}
	})
	assert_true(missing_destination.is_error(), "run_failed missing next_destination should be rejected.")
	assert_equal(missing_destination.metadata.get("field"), "next_destination", "A missing destination should name the next_destination field.")

	var wrong_destination: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "run_failed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"cause": "hero_death", "node_id": "node-1-0", "cleared_node_count": 1, "next_destination": "dungeon"}
	})
	assert_true(wrong_destination.is_error(), "run_failed with a non-outpost destination should be rejected.")
	assert_equal(wrong_destination.metadata.get("field"), "next_destination", "A wrong destination should name the next_destination field.")


func _oath_shards_awarded_serializes_and_parses_stable_payload() -> void:
	# Story 8.3 (AC1/AC2): an oath_shards_awarded SYSTEM event (no actor) — the FIRST cross-run meta-award record.
	# reason is lower_snake AND in the allowlist; amount / oath_shards_before / oath_shards_after are non-negative
	# integral; before + amount == after; profile_id is a plain string; ZERO roll/draw_index (a recorded amount).
	var event: DomainEvent = DomainEvent.oath_shards_awarded(21, {
		"amount": 4,
		"oath_shards_before": 10,
		"oath_shards_after": 14,
		"reason": "run_completed_eligible",
		"profile_id": "default"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "oath_shards_awarded", "oath_shards_awarded should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "oath_shards_awarded is a system event with an empty actor id.")
	# ZERO RNG: a recorded amount, not a roll — no roll/draw_index on the payload.
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "oath_shards_awarded must NOT carry a roll (it is a recorded amount, ZERO RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "oath_shards_awarded must NOT carry a draw_index (ZERO RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "oath_shards_awarded should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.OATH_SHARDS_AWARDED, "oath_shards_awarded should parse back to OATH_SHARDS_AWARDED.")
	assert_equal(restored.payload.get("amount"), 4, "The amount must survive a JSON round-trip.")
	assert_equal(restored.payload.get("oath_shards_before"), 10, "oath_shards_before must survive a JSON round-trip.")
	assert_equal(restored.payload.get("oath_shards_after"), 14, "oath_shards_after must survive a JSON round-trip.")
	assert_equal(restored.payload.get("reason"), "run_completed_eligible", "The reason must survive a JSON round-trip.")
	assert_equal(restored.payload.get("profile_id"), "default", "The profile_id must survive a JSON round-trip.")

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.OATH_SHARDS_AWARDED), &"oath_shards_awarded", "id_for_type must map the new event.")
	assert_equal(DomainEvent.type_for_id(&"oath_shards_awarded"), DomainEvent.Type.OATH_SHARDS_AWARDED, "type_for_id must map the new event back.")


func _oath_shards_awarded_rejects_malformed_payloads() -> void:
	# A missing reason is rejected.
	var missing_reason: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_awarded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 1, "oath_shards_before": 0, "oath_shards_after": 1, "profile_id": "default"}
	})
	assert_true(missing_reason.is_error(), "oath_shards_awarded missing reason should be rejected.")
	assert_equal(missing_reason.error_code, &"invalid_event_payload", "Malformed oath_shards_awarded should use the stable code.")
	assert_equal(missing_reason.metadata.get("field"), "reason", "oath_shards_awarded should name the missing reason field.")

	# An OFF-ALLOWLIST reason (lower_snake but not in OATH_SHARDS_AWARDED_REASONS) is rejected.
	var bad_reason: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_awarded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 1, "oath_shards_before": 0, "oath_shards_after": 1, "reason": "free_money", "profile_id": "default"}
	})
	assert_true(bad_reason.is_error(), "oath_shards_awarded with an off-allowlist reason should be rejected.")
	assert_equal(bad_reason.metadata.get("field"), "reason", "An off-allowlist reason should name the reason field.")

	# A negative amount is rejected (an award amount is never negative).
	var negative_amount: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_awarded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": -3, "oath_shards_before": 0, "oath_shards_after": 0, "reason": "run_completed_eligible", "profile_id": "default"}
	})
	assert_true(negative_amount.is_error(), "oath_shards_awarded with a negative amount should be rejected.")
	assert_equal(negative_amount.metadata.get("field"), "amount", "A negative amount should name the amount field.")

	# A dishonest arithmetic (before + amount != after) is rejected.
	var dishonest: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_awarded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 4, "oath_shards_before": 10, "oath_shards_after": 99, "reason": "run_completed_eligible", "profile_id": "default"}
	})
	assert_true(dishonest.is_error(), "oath_shards_awarded whose after diverges from before+amount should be rejected.")
	assert_equal(dishonest.metadata.get("field"), "oath_shards_after", "A dishonest arithmetic should name the oath_shards_after field.")

	# A non-string profile_id is rejected.
	var bad_profile: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_awarded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 1, "oath_shards_before": 0, "oath_shards_after": 1, "reason": "run_completed_eligible", "profile_id": 7}
	})
	assert_true(bad_profile.is_error(), "oath_shards_awarded with a non-string profile_id should be rejected.")
	assert_equal(bad_profile.metadata.get("field"), "profile_id", "A non-string profile_id should name the profile_id field.")


func _oath_shards_spent_serializes_and_parses_stable_payload() -> void:
	# Story 11.6 (AC1/FR59): an oath_shards_spent SYSTEM event (no actor) — the meta-SPEND record (the oath_shards_awarded
	# counterpart at the OPPOSITE sign). reason is lower_snake AND in the allowlist; unlock_id is lower_snake; amount is a
	# POSITIVE int; oath_shards_before/after are non-negative integral; before - amount == after; ZERO roll/draw_index.
	var event: DomainEvent = DomainEvent.oath_shards_spent(31, {
		"amount": 3,
		"oath_shards_before": 10,
		"oath_shards_after": 7,
		"reason": "class_unlock",
		"unlock_id": "necromancer",
		"profile_id": "default"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "oath_shards_spent", "oath_shards_spent should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "oath_shards_spent is a system event with an empty actor id.")
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "oath_shards_spent must NOT carry a roll (ZERO RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "oath_shards_spent must NOT carry a draw_index (ZERO RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "oath_shards_spent should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.OATH_SHARDS_SPENT, "oath_shards_spent should parse back to OATH_SHARDS_SPENT.")
	assert_equal(restored.payload.get("amount"), 3, "The amount must survive a JSON round-trip.")
	assert_equal(restored.payload.get("oath_shards_before"), 10, "oath_shards_before must survive a JSON round-trip.")
	assert_equal(restored.payload.get("oath_shards_after"), 7, "oath_shards_after must survive a JSON round-trip.")
	assert_equal(restored.payload.get("reason"), "class_unlock", "The reason must survive a JSON round-trip.")
	assert_equal(restored.payload.get("unlock_id"), "necromancer", "The unlock_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("profile_id"), "default", "The profile_id must survive a JSON round-trip.")

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.OATH_SHARDS_SPENT), &"oath_shards_spent", "id_for_type must map the new event.")
	assert_equal(DomainEvent.type_for_id(&"oath_shards_spent"), DomainEvent.Type.OATH_SHARDS_SPENT, "type_for_id must map the new event back.")


func _oath_shards_spent_rejects_malformed_payloads() -> void:
	# A missing reason is rejected.
	var missing_reason: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_spent",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 3, "oath_shards_before": 10, "oath_shards_after": 7, "unlock_id": "necromancer", "profile_id": "default"}
	})
	assert_true(missing_reason.is_error(), "oath_shards_spent missing reason should be rejected.")
	assert_equal(missing_reason.error_code, &"invalid_event_payload", "Malformed oath_shards_spent should use the stable code.")
	assert_equal(missing_reason.metadata.get("field"), "reason", "oath_shards_spent should name the missing reason field.")

	# An OFF-ALLOWLIST reason (lower_snake but not in OATH_SHARDS_SPENT_REASONS) is rejected.
	var bad_reason: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_spent",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 3, "oath_shards_before": 10, "oath_shards_after": 7, "reason": "buy_stats", "unlock_id": "necromancer", "profile_id": "default"}
	})
	assert_true(bad_reason.is_error(), "oath_shards_spent with an off-allowlist reason should be rejected.")
	assert_equal(bad_reason.metadata.get("field"), "reason", "An off-allowlist reason should name the reason field.")

	# A missing unlock_id is rejected.
	var missing_unlock: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_spent",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 3, "oath_shards_before": 10, "oath_shards_after": 7, "reason": "class_unlock", "profile_id": "default"}
	})
	assert_true(missing_unlock.is_error(), "oath_shards_spent missing unlock_id should be rejected.")
	assert_equal(missing_unlock.metadata.get("field"), "unlock_id", "oath_shards_spent should name the missing unlock_id field.")

	# A ZERO amount is rejected (a spend of 0 is not a spend — the amount must be positive).
	var zero_amount: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_spent",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 0, "oath_shards_before": 10, "oath_shards_after": 10, "reason": "class_unlock", "unlock_id": "necromancer", "profile_id": "default"}
	})
	assert_true(zero_amount.is_error(), "oath_shards_spent with a zero amount should be rejected (a spend must be positive).")
	assert_equal(zero_amount.metadata.get("field"), "amount", "A zero amount should name the amount field.")

	# A dishonest arithmetic (before - amount != after) is rejected (the OPPOSITE sign of the award check).
	var dishonest: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_spent",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 3, "oath_shards_before": 10, "oath_shards_after": 9, "reason": "class_unlock", "unlock_id": "necromancer", "profile_id": "default"}
	})
	assert_true(dishonest.is_error(), "oath_shards_spent whose after diverges from before-amount should be rejected.")
	assert_equal(dishonest.metadata.get("field"), "oath_shards_after", "A dishonest arithmetic should name the oath_shards_after field.")

	# A spend that would drive the total negative (before - amount < 0) is rejected via the non-negative after check.
	var negative_after: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "oath_shards_spent",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"amount": 3, "oath_shards_before": 1, "oath_shards_after": -2, "reason": "class_unlock", "unlock_id": "necromancer", "profile_id": "default"}
	})
	assert_true(negative_after.is_error(), "oath_shards_spent whose after is negative should be rejected (a spend never drives a negative total).")
	assert_equal(negative_after.metadata.get("field"), "oath_shards_after", "A negative after should name the oath_shards_after field.")


func _content_discovered_serializes_and_parses_stable_payload() -> void:
	# Story 8.4 (AC1/AC2): a content_discovered SYSTEM event (no actor) — the run-scoped discovery record. content_kind is
	# lower_snake AND in the DISCOVERED_CONTENT_KINDS allowlist; content_id is lower_snake; ZERO roll/draw_index (a
	# deterministic record, not a roll).
	for kind: String in ["echo", "seal_fragment", "class_mastery", "unlock_flag"]:
		var event: DomainEvent = DomainEvent.content_discovered(9, {
			"content_kind": kind,
			"content_id": "some_content_id"
		})
		var serialized: Dictionary = event.to_dictionary()
		assert_equal(serialized.get("event_id"), "content_discovered", "content_discovered should serialize a stable string id.")
		assert_equal(serialized.get("actor_id"), "", "content_discovered is a system event with an empty actor id.")
		assert_false((serialized.get("payload") as Dictionary).has("roll"), "content_discovered must NOT carry a roll (ZERO RNG).")
		assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "content_discovered must NOT carry a draw_index (ZERO RNG).")

		var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
		assert_true(parse_result.succeeded, "content_discovered (%s) should parse: %s" % [kind, parse_result.metadata])
		var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
		assert_equal(restored.event_type, DomainEvent.Type.CONTENT_DISCOVERED, "content_discovered should parse back to CONTENT_DISCOVERED.")
		assert_equal(restored.payload.get("content_kind"), kind, "The content_kind must survive a JSON round-trip.")
		assert_equal(restored.payload.get("content_id"), "some_content_id", "The content_id must survive a JSON round-trip.")

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.CONTENT_DISCOVERED), &"content_discovered", "id_for_type must map content_discovered.")
	assert_equal(DomainEvent.type_for_id(&"content_discovered"), DomainEvent.Type.CONTENT_DISCOVERED, "type_for_id must map content_discovered back.")


func _content_discovered_rejects_malformed_payloads() -> void:
	# A missing content_kind is rejected.
	var missing_kind: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "content_discovered",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"content_id": "echo_of_salt"}
	})
	assert_true(missing_kind.is_error(), "content_discovered missing content_kind should be rejected.")
	assert_equal(missing_kind.error_code, &"invalid_event_payload", "Malformed content_discovered should use the stable code.")
	assert_equal(missing_kind.metadata.get("field"), "content_kind", "content_discovered should name the missing content_kind field.")

	# An OFF-ALLOWLIST content_kind (lower_snake but not in DISCOVERED_CONTENT_KINDS) is rejected.
	var bad_kind: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "content_discovered",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"content_kind": "relic_shard", "content_id": "echo_of_salt"}
	})
	assert_true(bad_kind.is_error(), "content_discovered with an off-allowlist content_kind should be rejected.")
	assert_equal(bad_kind.metadata.get("field"), "content_kind", "An off-allowlist content_kind should name the content_kind field.")

	# A missing content_id is rejected.
	var missing_id: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "content_discovered",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"content_kind": "echo"}
	})
	assert_true(missing_id.is_error(), "content_discovered missing content_id should be rejected.")
	assert_equal(missing_id.metadata.get("field"), "content_id", "content_discovered should name the missing content_id field.")

	# A non-lower_snake content_id (hyphenated) is rejected (a discovery id is a lower_snake content id, not a node id).
	var bad_id: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "content_discovered",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"content_kind": "echo", "content_id": "echo-of-salt"}
	})
	assert_true(bad_id.is_error(), "content_discovered with a hyphenated content_id should be rejected.")
	assert_equal(bad_id.metadata.get("field"), "content_id", "A non-lower_snake content_id should name the content_id field.")


func _first_death_recorded_serializes_and_parses_stable_payload() -> void:
	# Story 8.5 (AC1/FR61): a first_death_recorded SYSTEM event (no actor) — the first-death narrative marker. line_id is a
	# stable lower_snake NARRATIVE-LINE id (LINE-AS-ID — NOT the raw prose); is_skippable is a plain bool (FR65); profile_id
	# is a plain string; ZERO roll/draw_index (a deterministic record, not a roll).
	var event: DomainEvent = DomainEvent.first_death_recorded(31, {
		"line_id": "first_death",
		"is_skippable": true,
		"profile_id": "default"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "first_death_recorded", "first_death_recorded should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "first_death_recorded is a system event with an empty actor id.")
	# ZERO RNG: a recorded flag, not a roll — no roll/draw_index on the payload.
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "first_death_recorded must NOT carry a roll (ZERO RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "first_death_recorded must NOT carry a draw_index (ZERO RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "first_death_recorded should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.FIRST_DEATH_RECORDED, "first_death_recorded should parse back to FIRST_DEATH_RECORDED.")
	assert_equal(restored.payload.get("line_id"), "first_death", "The line_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("is_skippable"), true, "is_skippable must survive a JSON round-trip.")
	assert_equal(restored.payload.get("profile_id"), "default", "The profile_id must survive a JSON round-trip.")

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.FIRST_DEATH_RECORDED), &"first_death_recorded", "id_for_type must map first_death_recorded.")
	assert_equal(DomainEvent.type_for_id(&"first_death_recorded"), DomainEvent.Type.FIRST_DEATH_RECORDED, "type_for_id must map first_death_recorded back.")


func _first_death_recorded_rejects_malformed_payloads() -> void:
	# A missing line_id is rejected.
	var missing_line: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_death_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"is_skippable": true, "profile_id": "default"}
	})
	assert_true(missing_line.is_error(), "first_death_recorded missing line_id should be rejected.")
	assert_equal(missing_line.error_code, &"invalid_event_payload", "Malformed first_death_recorded should use the stable code.")
	assert_equal(missing_line.metadata.get("field"), "line_id", "first_death_recorded should name the missing line_id field.")

	# A non-lower_snake line_id (hyphenated) is rejected (a line id is a lower_snake content id, not a node id).
	var bad_line: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_death_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"line_id": "first-death", "is_skippable": true, "profile_id": "default"}
	})
	assert_true(bad_line.is_error(), "first_death_recorded with a hyphenated line_id should be rejected.")
	assert_equal(bad_line.metadata.get("field"), "line_id", "A non-lower_snake line_id should name the line_id field.")

	# A missing is_skippable is rejected (the skippability marker must be an explicit bool — FR65).
	var missing_skippable: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_death_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"line_id": "first_death", "profile_id": "default"}
	})
	assert_true(missing_skippable.is_error(), "first_death_recorded missing is_skippable should be rejected.")
	assert_equal(missing_skippable.metadata.get("field"), "is_skippable", "first_death_recorded should name the missing is_skippable field.")

	# A non-bool is_skippable (a string) is rejected — the marker is a strict bool, not a truthy value.
	var bad_skippable: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_death_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"line_id": "first_death", "is_skippable": "yes", "profile_id": "default"}
	})
	assert_true(bad_skippable.is_error(), "first_death_recorded with a non-bool is_skippable should be rejected.")
	assert_equal(bad_skippable.metadata.get("field"), "is_skippable", "A non-bool is_skippable should name the is_skippable field.")

	# A non-string profile_id is rejected.
	var bad_profile: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_death_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"line_id": "first_death", "is_skippable": true, "profile_id": 7}
	})
	assert_true(bad_profile.is_error(), "first_death_recorded with a non-string profile_id should be rejected.")
	assert_equal(bad_profile.metadata.get("field"), "profile_id", "A non-string profile_id should name the profile_id field.")


func _boss_encounter_started_serializes_and_parses_stable_payload() -> void:
	# Story 9.1 (AC1): a boss_encounter_started SYSTEM event (no actor) — the boss-ENCOUNTER-SETUP boundary. boss_node_id
	# is the ORIGINAL route boss node id (HYPHENATED — a plain non-empty string, NOT lower_snake); boss_entity_id is the
	# reserved boss-entity SLOT id (lower_snake — the Larval Avatar slot 9.2 fills); arena_width/arena_height are the boss
	# arena bounds (non-negative integral); ZERO roll/draw_index (the setup draws ZERO RNG — a deterministic record).
	var event: DomainEvent = DomainEvent.boss_encounter_started(44, {
		"boss_node_id": "node-7-0",
		"boss_entity_id": "larval_avatar",
		"arena_width": 12,
		"arena_height": 12
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "boss_encounter_started", "boss_encounter_started should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "boss_encounter_started is a system event with an empty actor id.")
	# ZERO RNG: a setup record, not a roll — no roll/draw_index on the payload.
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "boss_encounter_started must NOT carry a roll (ZERO RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "boss_encounter_started must NOT carry a draw_index (ZERO RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "boss_encounter_started should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.BOSS_ENCOUNTER_STARTED, "boss_encounter_started should parse back to BOSS_ENCOUNTER_STARTED.")
	# The HYPHENATED boss node id survives the round trip (validated as a plain string, NEVER lower_snake).
	assert_equal(restored.payload.get("boss_node_id"), "node-7-0", "The hyphenated boss_node_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("boss_entity_id"), "larval_avatar", "The boss_entity_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("arena_width"), 12, "arena_width must survive a JSON round-trip.")
	assert_equal(restored.payload.get("arena_height"), 12, "arena_height must survive a JSON round-trip.")

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.BOSS_ENCOUNTER_STARTED), &"boss_encounter_started", "id_for_type must map boss_encounter_started.")
	assert_equal(DomainEvent.type_for_id(&"boss_encounter_started"), DomainEvent.Type.BOSS_ENCOUNTER_STARTED, "type_for_id must map boss_encounter_started back.")


func _boss_encounter_started_rejects_malformed_payloads() -> void:
	# A missing boss_node_id is rejected.
	var missing_node: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_encounter_started",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval_avatar", "arena_width": 12, "arena_height": 12}
	})
	assert_true(missing_node.is_error(), "boss_encounter_started missing boss_node_id should be rejected.")
	assert_equal(missing_node.error_code, &"invalid_event_payload", "Malformed boss_encounter_started should use the stable code.")
	assert_equal(missing_node.metadata.get("field"), "boss_node_id", "boss_encounter_started should name the missing boss_node_id field.")

	# An EMPTY boss_node_id is rejected (the boss encounter must key off a real node).
	var empty_node: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_encounter_started",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_node_id": "", "boss_entity_id": "larval_avatar", "arena_width": 12, "arena_height": 12}
	})
	assert_true(empty_node.is_error(), "boss_encounter_started with an empty boss_node_id should be rejected.")
	assert_equal(empty_node.metadata.get("field"), "boss_node_id", "An empty boss_node_id should name the boss_node_id field.")

	# A non-lower_snake boss_entity_id (hyphenated) is rejected (a boss-entity slot id is a lower_snake content id).
	var bad_entity: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_encounter_started",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_node_id": "node-7-0", "boss_entity_id": "larval-avatar", "arena_width": 12, "arena_height": 12}
	})
	assert_true(bad_entity.is_error(), "boss_encounter_started with a hyphenated boss_entity_id should be rejected.")
	assert_equal(bad_entity.metadata.get("field"), "boss_entity_id", "A non-lower_snake boss_entity_id should name the boss_entity_id field.")

	# A negative arena_width is rejected (the bounds are non-negative integral).
	var bad_width: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_encounter_started",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_node_id": "node-7-0", "boss_entity_id": "larval_avatar", "arena_width": -1, "arena_height": 12}
	})
	assert_true(bad_width.is_error(), "boss_encounter_started with a negative arena_width should be rejected.")
	assert_equal(bad_width.metadata.get("field"), "arena_width", "A negative arena_width should name the arena_width field.")

	# A non-integral arena_height (a string) is rejected.
	var bad_height: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_encounter_started",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_node_id": "node-7-0", "boss_entity_id": "larval_avatar", "arena_width": 12, "arena_height": "tall"}
	})
	assert_true(bad_height.is_error(), "boss_encounter_started with a non-integral arena_height should be rejected.")
	assert_equal(bad_height.metadata.get("field"), "arena_height", "A non-integral arena_height should name the arena_height field.")


func _boss_phase_changed_serializes_and_parses_stable_payload() -> void:
	# Story 9.2 (AC2): a boss_phase_changed SYSTEM event (no actor) — the deterministic record of an applied FORWARD-ONLY
	# Larval Avatar phase transition. boss_entity_id is the boss slot id (lower_snake); from_phase/to_phase are
	# non-negative integral phase indices with to_phase > from_phase; phase_id/trigger are lower_snake markers; ZERO
	# roll/draw_index (the phase resolve draws ZERO RNG — a deterministic record).
	var event: DomainEvent = DomainEvent.boss_phase_changed(45, {
		"boss_entity_id": "larval_avatar",
		"from_phase": 0,
		"to_phase": 1,
		"phase_id": "adaptation",
		"trigger": "hp_threshold"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "boss_phase_changed", "boss_phase_changed should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "boss_phase_changed is a system event with an empty actor id.")
	# ZERO RNG: a deterministic phase-change record, not a roll — no roll/draw_index on the payload.
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "boss_phase_changed must NOT carry a roll (ZERO RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "boss_phase_changed must NOT carry a draw_index (ZERO RNG).")

	# JSON round-trip: assert the SURVIVING typed fields after parse_string (the epic-9 int->float footgun — do NOT
	# assert a byte-identical re-stringify of a nested-dict payload; the small phase indices survive as ints).
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "boss_phase_changed should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.BOSS_PHASE_CHANGED, "boss_phase_changed should parse back to BOSS_PHASE_CHANGED.")
	assert_equal(String(restored.payload.get("boss_entity_id")), "larval_avatar", "The boss_entity_id must survive a JSON round-trip.")
	assert_equal(int(restored.payload.get("from_phase")), 0, "from_phase must survive a JSON round-trip as an int.")
	assert_equal(int(restored.payload.get("to_phase")), 1, "to_phase must survive a JSON round-trip as an int.")
	assert_equal(String(restored.payload.get("phase_id")), "adaptation", "phase_id must survive a JSON round-trip.")
	assert_equal(String(restored.payload.get("trigger")), "hp_threshold", "trigger must survive a JSON round-trip.")

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.BOSS_PHASE_CHANGED), &"boss_phase_changed", "id_for_type must map boss_phase_changed.")
	assert_equal(DomainEvent.type_for_id(&"boss_phase_changed"), DomainEvent.Type.BOSS_PHASE_CHANGED, "type_for_id must map boss_phase_changed back.")


func _boss_phase_changed_rejects_malformed_payloads() -> void:
	# A missing boss_entity_id is rejected.
	var missing_entity: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_phase_changed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"from_phase": 0, "to_phase": 1, "phase_id": "adaptation", "trigger": "hp_threshold"}
	})
	assert_true(missing_entity.is_error(), "boss_phase_changed missing boss_entity_id should be rejected.")
	assert_equal(missing_entity.error_code, &"invalid_event_payload", "Malformed boss_phase_changed should use the stable code.")
	assert_equal(missing_entity.metadata.get("field"), "boss_entity_id", "It should name the missing boss_entity_id field.")

	# A non-lower_snake boss_entity_id (hyphenated) is rejected.
	var bad_entity: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_phase_changed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval-avatar", "from_phase": 0, "to_phase": 1, "phase_id": "adaptation", "trigger": "hp_threshold"}
	})
	assert_true(bad_entity.is_error(), "A hyphenated boss_entity_id should be rejected.")
	assert_equal(bad_entity.metadata.get("field"), "boss_entity_id", "A non-lower_snake boss_entity_id should name the boss_entity_id field.")

	# A negative from_phase is rejected (indices are non-negative integral).
	var bad_from: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_phase_changed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval_avatar", "from_phase": -1, "to_phase": 1, "phase_id": "adaptation", "trigger": "hp_threshold"}
	})
	assert_true(bad_from.is_error(), "A negative from_phase should be rejected.")
	assert_equal(bad_from.metadata.get("field"), "from_phase", "A negative from_phase should name the from_phase field.")

	# A BACKWARD to_phase (to_phase < from_phase) is rejected (forward-only — a boss never reverts).
	var backward: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_phase_changed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval_avatar", "from_phase": 2, "to_phase": 1, "phase_id": "adaptation", "trigger": "hp_threshold"}
	})
	assert_true(backward.is_error(), "A backward to_phase (< from_phase) should be rejected (forward-only).")
	assert_equal(backward.metadata.get("field"), "to_phase", "A backward change should name the to_phase field.")

	# An EQUAL to_phase (to_phase == from_phase, a no-op change) is rejected (forward-only requires strict advance).
	var equal_phase: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_phase_changed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval_avatar", "from_phase": 1, "to_phase": 1, "phase_id": "adaptation", "trigger": "hp_threshold"}
	})
	assert_true(equal_phase.is_error(), "An equal (no-op) to_phase should be rejected (forward-only).")
	assert_equal(equal_phase.metadata.get("field"), "to_phase", "A no-op change should name the to_phase field.")

	# A non-lower_snake phase_id is rejected.
	var bad_phase_id: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_phase_changed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval_avatar", "from_phase": 0, "to_phase": 1, "phase_id": "Adaptation", "trigger": "hp_threshold"}
	})
	assert_true(bad_phase_id.is_error(), "A non-lower_snake phase_id should be rejected.")
	assert_equal(bad_phase_id.metadata.get("field"), "phase_id", "A bad phase_id should name the phase_id field.")

	# A non-lower_snake trigger is rejected.
	var bad_trigger: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_phase_changed",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval_avatar", "from_phase": 0, "to_phase": 1, "phase_id": "adaptation", "trigger": "HP Threshold"}
	})
	assert_true(bad_trigger.is_error(), "A non-lower_snake trigger should be rejected.")
	assert_equal(bad_trigger.metadata.get("field"), "trigger", "A bad trigger should name the trigger field.")


func _profile_progress_merged_serializes_and_parses_stable_payload() -> void:
	# Story 8.4 (AC1/AC3): a profile_progress_merged SYSTEM event (no actor) — the cross-run profile-merge record. The id
	# lists are lower_snake with NO duplicates; class_mastery_deltas carries {class_id, delta (positive)}; the count
	# fields == their matching list sizes; ZERO roll/draw_index (a deterministic record).
	var event: DomainEvent = DomainEvent.profile_progress_merged(12, {
		"added_echo_ids": ["echo_of_salt", "echo_of_tide"],
		"added_seal_fragment_ids": ["seal_a"],
		"added_unlock_flag_ids": ["variety_flag_1"],
		"thresholds_crossed": ["seal_gate_1"],
		"class_mastery_deltas": [{"class_id": "warrior", "delta": 2}],
		"echoes_added": 2,
		"seal_fragments_added": 1,
		"unlock_flags_added": 1,
		"thresholds_crossed_count": 1,
		"profile_id": "default"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "profile_progress_merged", "profile_progress_merged should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "profile_progress_merged is a system event with an empty actor id.")
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "profile_progress_merged must NOT carry a roll (ZERO RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "profile_progress_merged should parse: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.PROFILE_PROGRESS_MERGED, "profile_progress_merged should parse back to PROFILE_PROGRESS_MERGED.")
	assert_equal((restored.payload.get("added_echo_ids") as Array).size(), 2, "added_echo_ids must survive a JSON round-trip.")
	assert_equal((restored.payload.get("added_seal_fragment_ids") as Array).size(), 1, "added_seal_fragment_ids must survive a JSON round-trip.")
	assert_equal((restored.payload.get("thresholds_crossed") as Array).size(), 1, "thresholds_crossed must survive a JSON round-trip.")
	assert_equal(int((restored.payload.get("class_mastery_deltas") as Array)[0].get("delta")), 2, "The mastery delta must survive a JSON round-trip.")
	assert_equal(restored.payload.get("profile_id"), "default", "The profile_id must survive a JSON round-trip.")

	# An EMPTY merge (nothing newly added, no crossings) is a valid record.
	var empty_event: DomainEvent = DomainEvent.profile_progress_merged(13, {"profile_id": "default"})
	var empty_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(empty_event.to_dictionary())))
	assert_true(empty_parse.succeeded, "An empty profile_progress_merged (nothing added) is a valid record: %s" % empty_parse.metadata)

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.PROFILE_PROGRESS_MERGED), &"profile_progress_merged", "id_for_type must map profile_progress_merged.")
	assert_equal(DomainEvent.type_for_id(&"profile_progress_merged"), DomainEvent.Type.PROFILE_PROGRESS_MERGED, "type_for_id must map profile_progress_merged back.")


func _profile_progress_merged_rejects_malformed_payloads() -> void:
	# A DUPLICATE id in an id list is rejected (the list is the deduped newly-added delta).
	var duplicate_echo: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "profile_progress_merged",
		"sequence_id": 1,
		"actor_id": "",
		"payload": _merged_payload({"added_echo_ids": ["echo_a", "echo_a"], "echoes_added": 2})
	})
	assert_true(duplicate_echo.is_error(), "profile_progress_merged with a duplicate echo id should be rejected.")
	assert_equal(duplicate_echo.metadata.get("field"), "added_echo_ids", "A duplicate echo id should name the added_echo_ids field.")

	# A count that diverges from its list size is rejected (the honest-record arithmetic).
	var bad_count: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "profile_progress_merged",
		"sequence_id": 1,
		"actor_id": "",
		"payload": _merged_payload({"added_echo_ids": ["echo_a"], "echoes_added": 5})
	})
	assert_true(bad_count.is_error(), "profile_progress_merged whose echoes_added diverges from its list size should be rejected.")
	assert_equal(bad_count.metadata.get("field"), "echoes_added", "A divergent count should name the echoes_added field.")

	# A non-positive mastery delta is rejected (a merge only ever ADDS mastery).
	var bad_delta: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "profile_progress_merged",
		"sequence_id": 1,
		"actor_id": "",
		"payload": _merged_payload({"class_mastery_deltas": [{"class_id": "warrior", "delta": 0}]})
	})
	assert_true(bad_delta.is_error(), "profile_progress_merged with a non-positive mastery delta should be rejected.")
	assert_equal(bad_delta.metadata.get("field"), "class_mastery_deltas", "A non-positive delta should name the class_mastery_deltas field.")

	# A non-lower_snake threshold id is rejected.
	var bad_threshold: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "profile_progress_merged",
		"sequence_id": 1,
		"actor_id": "",
		"payload": _merged_payload({"thresholds_crossed": ["Seal-Gate-1"], "thresholds_crossed_count": 1})
	})
	assert_true(bad_threshold.is_error(), "profile_progress_merged with a non-lower_snake threshold id should be rejected.")
	assert_equal(bad_threshold.metadata.get("field"), "thresholds_crossed", "A malformed threshold id should name the thresholds_crossed field.")


# A well-formed profile_progress_merged payload with the given overrides applied (so a malformed-payload test perturbs
# exactly ONE field and every other field stays valid — an isolated per-field rejection).
func _merged_payload(overrides: Dictionary) -> Dictionary:
	var payload: Dictionary = {
		"added_echo_ids": [],
		"added_seal_fragment_ids": [],
		"added_unlock_flag_ids": [],
		"thresholds_crossed": [],
		"class_mastery_deltas": [],
		"echoes_added": 0,
		"seal_fragments_added": 0,
		"unlock_flags_added": 0,
		"thresholds_crossed_count": 0,
		"profile_id": "default"
	}
	for key: String in overrides.keys():
		payload[key] = overrides[key]
	return payload


func _first_victory_recorded_serializes_and_parses_stable_payload() -> void:
	# Story 9.4 (AC2/FR62): a first_victory_recorded SYSTEM event (no actor) — the first-victory narrative marker, the
	# OPPOSITE-terminal-phase twin of first_death_recorded. line_id is a stable lower_snake NARRATIVE-LINE id (LINE-AS-ID —
	# NOT the raw prose); is_skippable is a plain bool (FR65); profile_id is a plain string; ZERO roll/draw_index (a
	# deterministic record, not a roll).
	var event: DomainEvent = DomainEvent.first_victory_recorded(31, {
		"line_id": "first_victory",
		"is_skippable": true,
		"profile_id": "default"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "first_victory_recorded", "first_victory_recorded should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "first_victory_recorded is a system event with an empty actor id.")
	# ZERO RNG: a recorded flag, not a roll — no roll/draw_index on the payload.
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "first_victory_recorded must NOT carry a roll (ZERO RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "first_victory_recorded must NOT carry a draw_index (ZERO RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "first_victory_recorded should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.FIRST_VICTORY_RECORDED, "first_victory_recorded should parse back to FIRST_VICTORY_RECORDED.")
	assert_equal(restored.payload.get("line_id"), "first_victory", "The line_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("is_skippable"), true, "is_skippable must survive a JSON round-trip.")
	assert_equal(restored.payload.get("profile_id"), "default", "The profile_id must survive a JSON round-trip.")

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.FIRST_VICTORY_RECORDED), &"first_victory_recorded", "id_for_type must map first_victory_recorded.")
	assert_equal(DomainEvent.type_for_id(&"first_victory_recorded"), DomainEvent.Type.FIRST_VICTORY_RECORDED, "type_for_id must map first_victory_recorded back.")
	# The line-id const is pinned.
	assert_equal(String(DomainEvent.FIRST_VICTORY_LINE_ID), "first_victory", "FIRST_VICTORY_LINE_ID must be `first_victory`.")


func _first_victory_recorded_rejects_malformed_payloads() -> void:
	# A missing line_id is rejected.
	var missing_line: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_victory_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"is_skippable": true, "profile_id": "default"}
	})
	assert_true(missing_line.is_error(), "first_victory_recorded missing line_id should be rejected.")
	assert_equal(missing_line.error_code, &"invalid_event_payload", "Malformed first_victory_recorded should use the stable code.")
	assert_equal(missing_line.metadata.get("field"), "line_id", "first_victory_recorded should name the missing line_id field.")

	# A non-lower_snake line_id (hyphenated) is rejected.
	var bad_line: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_victory_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"line_id": "first-victory", "is_skippable": true, "profile_id": "default"}
	})
	assert_true(bad_line.is_error(), "first_victory_recorded with a hyphenated line_id should be rejected.")
	assert_equal(bad_line.metadata.get("field"), "line_id", "A non-lower_snake line_id should name the line_id field.")

	# A missing is_skippable is rejected (the skippability marker must be an explicit bool — FR65).
	var missing_skippable: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_victory_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"line_id": "first_victory", "profile_id": "default"}
	})
	assert_true(missing_skippable.is_error(), "first_victory_recorded missing is_skippable should be rejected.")
	assert_equal(missing_skippable.metadata.get("field"), "is_skippable", "first_victory_recorded should name the missing is_skippable field.")

	# A non-bool is_skippable (a string) is rejected.
	var bad_skippable: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_victory_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"line_id": "first_victory", "is_skippable": "yes", "profile_id": "default"}
	})
	assert_true(bad_skippable.is_error(), "first_victory_recorded with a non-bool is_skippable should be rejected.")
	assert_equal(bad_skippable.metadata.get("field"), "is_skippable", "A non-bool is_skippable should name the is_skippable field.")

	# A non-string profile_id is rejected.
	var bad_profile: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "first_victory_recorded",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"line_id": "first_victory", "is_skippable": true, "profile_id": 7}
	})
	assert_true(bad_profile.is_error(), "first_victory_recorded with a non-string profile_id should be rejected.")
	assert_equal(bad_profile.metadata.get("field"), "profile_id", "A non-string profile_id should name the profile_id field.")


func _boss_defeated_serializes_and_parses_stable_payload() -> void:
	# Story 9.4 (AC1): a boss_defeated SYSTEM event (no actor) — the TACTICAL boss-defeat fact (the Larval Avatar entity
	# reached 0 HP), DISTINCT from the run-VICTORY (run_completed + victory) run-END record. boss_entity_id is a lower_snake
	# content id (the Larval Avatar slot); phase_id is the boss's active phase at defeat (lower_snake); final_hp is a
	# non-negative integral (0 for a defeat); ZERO roll/draw_index (a deterministic record, not a roll).
	var event: DomainEvent = DomainEvent.boss_defeated(50, {
		"boss_entity_id": "larval_avatar",
		"phase_id": "desperation",
		"final_hp": 0
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "boss_defeated", "boss_defeated should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "boss_defeated is a system event with an empty actor id (the boss is the subject, not the actor).")
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "boss_defeated must NOT carry a roll (ZERO RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "boss_defeated must NOT carry a draw_index (ZERO RNG).")

	# The int→float JSON footgun (retro §9-1): assert the SURVIVING typed field after parse_string, NOT a nested re-stringify.
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "boss_defeated should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.BOSS_DEFEATED, "boss_defeated should parse back to BOSS_DEFEATED.")
	assert_equal(String(restored.payload.get("boss_entity_id")), "larval_avatar", "The boss_entity_id must survive a JSON round-trip.")
	assert_equal(String(restored.payload.get("phase_id")), "desperation", "The phase_id must survive a JSON round-trip.")
	assert_equal(int(restored.payload.get("final_hp")), 0, "final_hp must survive a JSON round-trip as an int (the int→float footgun).")

	# id_for_type / type_for_id round-trip for the new event.
	assert_equal(DomainEvent.id_for_type(DomainEvent.Type.BOSS_DEFEATED), &"boss_defeated", "id_for_type must map boss_defeated.")
	assert_equal(DomainEvent.type_for_id(&"boss_defeated"), DomainEvent.Type.BOSS_DEFEATED, "type_for_id must map boss_defeated back.")


func _boss_defeated_rejects_malformed_payloads() -> void:
	# A missing boss_entity_id is rejected.
	var missing_entity: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_defeated",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"phase_id": "desperation", "final_hp": 0}
	})
	assert_true(missing_entity.is_error(), "boss_defeated missing boss_entity_id should be rejected.")
	assert_equal(missing_entity.error_code, &"invalid_event_payload", "Malformed boss_defeated should use the stable code.")
	assert_equal(missing_entity.metadata.get("field"), "boss_entity_id", "boss_defeated should name the missing boss_entity_id field.")

	# A non-lower_snake boss_entity_id (hyphenated) is rejected (the boss entity id is a lower_snake content id).
	var bad_entity: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_defeated",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval-avatar", "phase_id": "desperation", "final_hp": 0}
	})
	assert_true(bad_entity.is_error(), "boss_defeated with a hyphenated boss_entity_id should be rejected.")
	assert_equal(bad_entity.metadata.get("field"), "boss_entity_id", "A non-lower_snake boss_entity_id should name the boss_entity_id field.")

	# A missing phase_id is rejected.
	var missing_phase: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_defeated",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval_avatar", "final_hp": 0}
	})
	assert_true(missing_phase.is_error(), "boss_defeated missing phase_id should be rejected.")
	assert_equal(missing_phase.metadata.get("field"), "phase_id", "boss_defeated should name the missing phase_id field.")

	# A negative final_hp is rejected (final_hp is a non-negative integral).
	var bad_hp: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "boss_defeated",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {"boss_entity_id": "larval_avatar", "phase_id": "desperation", "final_hp": -1}
	})
	assert_true(bad_hp.is_error(), "boss_defeated with a negative final_hp should be rejected.")
	assert_equal(bad_hp.metadata.get("field"), "final_hp", "A negative final_hp should name the final_hp field.")


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


func _passive_consumed_serializes_and_parses_stable_payload() -> void:
	# Story 6.5 (AC1): a passive_consumed SYSTEM event (no actor) — the consume-specific resolution record emitted
	# by ConsumePassiveCommand AFTER the passive is registered + the offer flips to `resolved`. passive_id + table_id
	# are Story-5.4/6.1 content ids -> lower_snake.
	var event: DomainEvent = DomainEvent.passive_consumed(9, {
		"passive_id": "warrior_unbreakable_guard",
		"table_id": "passive_reward_choice"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "passive_consumed", "passive_consumed should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "passive_consumed is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "passive_consumed should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.PASSIVE_CONSUMED, "passive_consumed should parse back to PASSIVE_CONSUMED.")
	assert_equal(restored.payload.get("passive_id"), "warrior_unbreakable_guard", "The passive_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("table_id"), "passive_reward_choice", "The table_id must survive a JSON round-trip.")


func _passive_consumed_rejects_malformed_payloads() -> void:
	# A missing passive_id is rejected.
	var missing_passive: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "passive_consumed", "sequence_id": 1, "actor_id": "",
		"payload": {"table_id": "passive_reward_choice"}
	})
	assert_true(missing_passive.is_error(), "passive_consumed missing passive_id should be rejected.")
	assert_equal(missing_passive.metadata.get("field"), "passive_id", "passive_consumed should name the passive_id field.")

	# A non-lower_snake passive_id is rejected.
	var bad_passive: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "passive_consumed", "sequence_id": 1, "actor_id": "",
		"payload": {"passive_id": "Warrior-Guard", "table_id": "passive_reward_choice"}
	})
	assert_true(bad_passive.is_error(), "passive_consumed with a non-lower_snake passive_id should be rejected.")
	assert_equal(bad_passive.metadata.get("field"), "passive_id", "passive_consumed should reject a non-lower_snake passive_id.")

	# A missing table_id is rejected.
	var missing_table: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "passive_consumed", "sequence_id": 1, "actor_id": "",
		"payload": {"passive_id": "warrior_unbreakable_guard"}
	})
	assert_true(missing_table.is_error(), "passive_consumed missing table_id should be rejected.")
	assert_equal(missing_table.metadata.get("field"), "table_id", "passive_consumed should name the table_id field.")

	# A non-lower_snake table_id is rejected.
	var bad_table: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "passive_consumed", "sequence_id": 1, "actor_id": "",
		"payload": {"passive_id": "warrior_unbreakable_guard", "table_id": "Passive-Choice"}
	})
	assert_true(bad_table.is_error(), "passive_consumed with a non-lower_snake table_id should be rejected.")
	assert_equal(bad_table.metadata.get("field"), "table_id", "passive_consumed should reject a non-lower_snake table_id.")


func _passive_destroyed_serializes_and_parses_stable_payload() -> void:
	# Story 6.6 (AC1/AC4): a passive_destroyed SYSTEM event (no actor) — the destroy-specific resolution record
	# emitted by DestroyPassiveCommand AFTER the 70/20/10 outcome is rolled + the offer flips to `resolved`.
	# passive_id/table_id/outcome_category/outcome_id are lower_snake content ids; outcome_category is in the
	# DESTROY_OUTCOME_CATEGORIES allowlist; outcome_effect/explanation are non-empty; roll/draw_index are the draw
	# provenance (non-negative integral) because Destroy DRAWS RNG (unlike passive_consumed).
	var event: DomainEvent = DomainEvent.passive_destroyed(11, {
		"passive_id": "warrior_unbreakable_guard",
		"table_id": "destroy_outcome_baseline",
		"outcome_category": "small_immediate_benefit",
		"outcome_id": "minor_restoration",
		"outcome_effect": "destroy_outcome_small_immediate_benefit",
		"explanation": "Destroying the passive releases a small immediate benefit.",
		"roll": 3,
		"draw_index": 0
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "passive_destroyed", "passive_destroyed should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "passive_destroyed is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "passive_destroyed should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.PASSIVE_DESTROYED, "passive_destroyed should parse back to PASSIVE_DESTROYED.")
	assert_equal(restored.payload.get("passive_id"), "warrior_unbreakable_guard", "The passive_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("table_id"), "destroy_outcome_baseline", "The table_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("outcome_category"), "small_immediate_benefit", "The outcome_category must survive a JSON round-trip.")
	assert_equal(restored.payload.get("outcome_id"), "minor_restoration", "The outcome_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("outcome_effect"), "destroy_outcome_small_immediate_benefit", "The outcome_effect must survive a JSON round-trip.")
	assert_equal(int(restored.payload.get("roll")), 3, "The roll must survive a JSON round-trip.")
	assert_equal(int(restored.payload.get("draw_index")), 0, "The draw_index must survive a JSON round-trip.")


func _passive_destroyed_rejects_malformed_payloads() -> void:
	# A baseline VALID payload to clone-and-perturb one field at a time.
	var valid_payload: Dictionary = {
		"passive_id": "warrior_unbreakable_guard",
		"table_id": "destroy_outcome_baseline",
		"outcome_category": "small_immediate_benefit",
		"outcome_id": "minor_restoration",
		"outcome_effect": "destroy_outcome_small_immediate_benefit",
		"explanation": "Destroying the passive releases a small immediate benefit.",
		"roll": 3,
		"draw_index": 0
	}

	# A non-lower_snake passive_id is rejected.
	var bad_passive: ActionResult = _try_passive_destroyed_with(valid_payload, "passive_id", "Warrior-Guard")
	assert_true(bad_passive.is_error(), "passive_destroyed with a non-lower_snake passive_id should be rejected.")
	assert_equal(bad_passive.metadata.get("field"), "passive_id", "passive_destroyed should name the passive_id field.")

	# A non-lower_snake table_id is rejected.
	var bad_table: ActionResult = _try_passive_destroyed_with(valid_payload, "table_id", "Destroy-Table")
	assert_true(bad_table.is_error(), "passive_destroyed with a non-lower_snake table_id should be rejected.")
	assert_equal(bad_table.metadata.get("field"), "table_id", "passive_destroyed should name the table_id field.")

	# An off-allowlist outcome_category is rejected (even though it is lower_snake).
	var bad_category: ActionResult = _try_passive_destroyed_with(valid_payload, "outcome_category", "jackpot")
	assert_true(bad_category.is_error(), "passive_destroyed with an off-allowlist outcome_category should be rejected.")
	assert_equal(bad_category.metadata.get("field"), "outcome_category", "passive_destroyed should pin outcome_category to the allowlist.")

	# A non-lower_snake outcome_id is rejected.
	var bad_outcome_id: ActionResult = _try_passive_destroyed_with(valid_payload, "outcome_id", "Minor-Restoration")
	assert_true(bad_outcome_id.is_error(), "passive_destroyed with a non-lower_snake outcome_id should be rejected.")
	assert_equal(bad_outcome_id.metadata.get("field"), "outcome_id", "passive_destroyed should reject a non-lower_snake outcome_id.")

	# A blank outcome_effect is rejected.
	var bad_effect: ActionResult = _try_passive_destroyed_with(valid_payload, "outcome_effect", "")
	assert_true(bad_effect.is_error(), "passive_destroyed with a blank outcome_effect should be rejected.")
	assert_equal(bad_effect.metadata.get("field"), "outcome_effect", "passive_destroyed should require a non-empty outcome_effect.")

	# A blank explanation is rejected.
	var bad_explanation: ActionResult = _try_passive_destroyed_with(valid_payload, "explanation", "")
	assert_true(bad_explanation.is_error(), "passive_destroyed with a blank explanation should be rejected.")
	assert_equal(bad_explanation.metadata.get("field"), "explanation", "passive_destroyed should require a non-empty explanation.")

	# A negative roll is rejected.
	var bad_roll: ActionResult = _try_passive_destroyed_with(valid_payload, "roll", -1)
	assert_true(bad_roll.is_error(), "passive_destroyed with a negative roll should be rejected.")
	assert_equal(bad_roll.metadata.get("field"), "roll", "passive_destroyed should require a non-negative roll.")

	# A negative draw_index is rejected.
	var bad_index: ActionResult = _try_passive_destroyed_with(valid_payload, "draw_index", -1)
	assert_true(bad_index.is_error(), "passive_destroyed with a negative draw_index should be rejected.")
	assert_equal(bad_index.metadata.get("field"), "draw_index", "passive_destroyed should require a non-negative draw_index.")

	# A missing field (drop outcome_category) is rejected.
	var missing: Dictionary = valid_payload.duplicate(true)
	missing.erase("outcome_category")
	var missing_result: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "passive_destroyed", "sequence_id": 1, "actor_id": "", "payload": missing
	})
	assert_true(missing_result.is_error(), "passive_destroyed missing outcome_category should be rejected.")
	assert_equal(missing_result.metadata.get("field"), "outcome_category", "passive_destroyed should name the missing outcome_category field.")


# Build a passive_destroyed dictionary from the valid baseline with ONE field overridden, then run it through
# try_from_dictionary (the malformed-payload reject path). Keeps the per-field negatives terse.
func _try_passive_destroyed_with(valid_payload: Dictionary, field: String, value: Variant) -> ActionResult:
	var payload: Dictionary = valid_payload.duplicate(true)
	payload[field] = value
	return DomainEvent.try_from_dictionary({
		"event_id": "passive_destroyed", "sequence_id": 1, "actor_id": "", "payload": payload
	})


func _item_consumed_serializes_and_parses_stable_payload() -> void:
	# Story 6.7 (AC3): an item_consumed SYSTEM event (no actor) — a backpack consumable USE record. item_id is a
	# Story-6.1 content id (lower_snake, NO hyphens); outcome_effect + explanation are non-empty strings (the
	# resolved effect marker + the known result); backpack_size_after + slot_index are non-negative integral. UNLIKE
	# passive_destroyed there is NO roll/draw_index (Use draws ZERO RNG — the deterministic item_gained shell).
	var event: DomainEvent = DomainEvent.item_consumed(7, {
		"item_id": "minor_healing_draught",
		"outcome_effect": "restore_minor_health",
		"explanation": "Using the draught restores a small measure of the hero's health.",
		"backpack_size_after": 0,
		"slot_index": 0
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "item_consumed", "item_consumed should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "item_consumed is a system event with an empty actor id.")
	# It carries NO draw provenance (Use is deterministic — no roll).
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "item_consumed carries NO roll (Use draws zero RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "item_consumed carries NO draw_index (Use draws zero RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "item_consumed should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.ITEM_CONSUMED, "item_consumed should parse back to ITEM_CONSUMED.")
	assert_equal(restored.payload.get("item_id"), "minor_healing_draught", "The item_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("outcome_effect"), "restore_minor_health", "The outcome_effect must survive a JSON round-trip.")
	assert_equal(restored.payload.get("explanation"), "Using the draught restores a small measure of the hero's health.", "The explanation must survive a JSON round-trip.")
	assert_equal(restored.payload.get("backpack_size_after"), 0, "backpack_size_after must survive a JSON round-trip.")
	assert_equal(restored.payload.get("slot_index"), 0, "slot_index must survive a JSON round-trip.")


func _item_consumed_rejects_malformed_payloads() -> void:
	# A baseline VALID payload to clone-and-perturb one field at a time.
	var valid_payload: Dictionary = {
		"item_id": "minor_healing_draught",
		"outcome_effect": "restore_minor_health",
		"explanation": "Using the draught restores a small measure of the hero's health.",
		"backpack_size_after": 0,
		"slot_index": 0
	}

	# A non-lower_snake item_id is rejected.
	var bad_item: ActionResult = _try_item_consumed_with(valid_payload, "item_id", "Minor-Draught")
	assert_true(bad_item.is_error(), "item_consumed with a non-lower_snake item_id should be rejected.")
	assert_equal(bad_item.error_code, &"invalid_event_payload", "Malformed item_consumed should use the stable code.")
	assert_equal(bad_item.metadata.get("field"), "item_id", "item_consumed should name the item_id field.")

	# A blank outcome_effect is rejected.
	var bad_effect: ActionResult = _try_item_consumed_with(valid_payload, "outcome_effect", "")
	assert_true(bad_effect.is_error(), "item_consumed with a blank outcome_effect should be rejected.")
	assert_equal(bad_effect.metadata.get("field"), "outcome_effect", "item_consumed should require a non-empty outcome_effect.")

	# A blank explanation is rejected.
	var bad_explanation: ActionResult = _try_item_consumed_with(valid_payload, "explanation", "")
	assert_true(bad_explanation.is_error(), "item_consumed with a blank explanation should be rejected.")
	assert_equal(bad_explanation.metadata.get("field"), "explanation", "item_consumed should require a non-empty explanation.")

	# A negative backpack_size_after is rejected.
	var bad_size: ActionResult = _try_item_consumed_with(valid_payload, "backpack_size_after", -1)
	assert_true(bad_size.is_error(), "item_consumed with a negative backpack_size_after should be rejected.")
	assert_equal(bad_size.metadata.get("field"), "backpack_size_after", "item_consumed should require a non-negative backpack_size_after.")

	# A negative slot_index is rejected.
	var bad_index: ActionResult = _try_item_consumed_with(valid_payload, "slot_index", -1)
	assert_true(bad_index.is_error(), "item_consumed with a negative slot_index should be rejected.")
	assert_equal(bad_index.metadata.get("field"), "slot_index", "item_consumed should require a non-negative slot_index.")

	# A missing field (drop item_id) is rejected.
	var missing: Dictionary = valid_payload.duplicate(true)
	missing.erase("item_id")
	var missing_result: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "item_consumed", "sequence_id": 1, "actor_id": "", "payload": missing
	})
	assert_true(missing_result.is_error(), "item_consumed missing item_id should be rejected.")
	assert_equal(missing_result.metadata.get("field"), "item_id", "item_consumed should name the missing item_id field.")


# Build an item_consumed dictionary from the valid baseline with ONE field overridden, then run it through
# try_from_dictionary (the malformed-payload reject path). Keeps the per-field negatives terse.
func _try_item_consumed_with(valid_payload: Dictionary, field: String, value: Variant) -> ActionResult:
	var payload: Dictionary = valid_payload.duplicate(true)
	payload[field] = value
	return DomainEvent.try_from_dictionary({
		"event_id": "item_consumed", "sequence_id": 1, "actor_id": "", "payload": payload
	})


func _economy_changed_serializes_and_parses_stable_payload() -> void:
	# Story 7.1 (AC2): an economy_changed SYSTEM event (no actor) — a currency/healing-change record. `reason` is a
	# lower_snake marker; gold_before/after + healing_before/after are non-negative integral; gold_delta/healing_delta
	# are SIGNED integral (a credit positive, a spend negative). UNLIKE passive_destroyed there is NO roll/draw_index
	# (an economy change is a recorded amount, not a roll — deterministic).
	var event: DomainEvent = DomainEvent.economy_changed(9, {
		"reason": "gold_reward_resolved",
		"gold_before": 5,
		"gold_after": 17,
		"gold_delta": 12,
		"healing_before": 0,
		"healing_after": 0,
		"healing_delta": 0
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "economy_changed", "economy_changed should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "economy_changed is a system event with an empty actor id.")
	# It carries NO draw provenance (an economy change is deterministic — no roll).
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "economy_changed carries NO roll (deterministic — zero RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "economy_changed carries NO draw_index (deterministic — zero RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "economy_changed should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.ECONOMY_CHANGED, "economy_changed should parse back to ECONOMY_CHANGED.")
	assert_equal(restored.payload.get("reason"), "gold_reward_resolved", "The reason must survive a JSON round-trip.")
	assert_equal(restored.payload.get("gold_before"), 5, "gold_before must survive a JSON round-trip.")
	assert_equal(restored.payload.get("gold_after"), 17, "gold_after must survive a JSON round-trip.")
	assert_equal(restored.payload.get("gold_delta"), 12, "gold_delta must survive a JSON round-trip.")

	# A healing SPEND (a NEGATIVE delta) is valid — the signed-delta path.
	var heal_event: DomainEvent = DomainEvent.economy_changed(10, {
		"reason": "heal_spent",
		"gold_before": 0, "gold_after": 0, "gold_delta": 0,
		"healing_before": 3, "healing_after": 1, "healing_delta": -2
	})
	var heal_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(heal_event.to_dictionary())))
	assert_true(heal_parse.succeeded, "A healing-spend economy_changed (negative delta) should parse: %s" % heal_parse.metadata)
	assert_equal((heal_parse.metadata.get("event") as DomainEvent).payload.get("healing_delta"), -2, "A negative healing_delta must survive the round-trip (signed).")


func _economy_changed_rejects_malformed_payloads() -> void:
	# A baseline VALID payload to clone-and-perturb one field at a time.
	var valid_payload: Dictionary = {
		"reason": "gold_reward_resolved",
		"gold_before": 5,
		"gold_after": 17,
		"gold_delta": 12,
		"healing_before": 0,
		"healing_after": 0,
		"healing_delta": 0
	}

	# A non-lower_snake reason is rejected.
	var bad_reason: ActionResult = _try_economy_changed_with(valid_payload, "reason", "Gold-Reward")
	assert_true(bad_reason.is_error(), "economy_changed with a non-lower_snake reason should be rejected.")
	assert_equal(bad_reason.error_code, &"invalid_event_payload", "Malformed economy_changed should use the stable code.")
	assert_equal(bad_reason.metadata.get("field"), "reason", "economy_changed should name the reason field.")

	# A blank reason is rejected.
	var blank_reason: ActionResult = _try_economy_changed_with(valid_payload, "reason", "")
	assert_true(blank_reason.is_error(), "economy_changed with a blank reason should be rejected.")
	assert_equal(blank_reason.metadata.get("field"), "reason", "economy_changed should require a non-empty reason.")

	# A NEGATIVE gold_before/gold_after is rejected (a wallet count is never negative). The delta MAY be negative.
	var neg_before: ActionResult = _try_economy_changed_with(valid_payload, "gold_before", -1)
	assert_true(neg_before.is_error(), "economy_changed with a negative gold_before should be rejected.")
	assert_equal(neg_before.metadata.get("field"), "gold_before", "economy_changed should require a non-negative gold_before.")
	# (gold_after must stay consistent with before+delta; perturbing before alone breaks arithmetic, so name before.)

	# A non-integral gold_delta is rejected.
	var bad_delta: ActionResult = _try_economy_changed_with(valid_payload, "gold_delta", "lots")
	assert_true(bad_delta.is_error(), "economy_changed with a non-integral gold_delta should be rejected.")
	assert_equal(bad_delta.metadata.get("field"), "gold_delta", "economy_changed should name the gold_delta field.")

	# An ARITHMETIC inconsistency (gold_after != gold_before + gold_delta) is rejected (the record must be honest).
	var inconsistent: ActionResult = _try_economy_changed_with(valid_payload, "gold_after", 99)
	assert_true(inconsistent.is_error(), "economy_changed whose gold_after diverges from before+delta should be rejected.")
	assert_equal(inconsistent.metadata.get("field"), "gold_after", "economy_changed should reject an inconsistent gold_after.")

	# A missing field (drop reason) is rejected.
	var missing: Dictionary = valid_payload.duplicate(true)
	missing.erase("reason")
	var missing_result: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "economy_changed", "sequence_id": 1, "actor_id": "", "payload": missing
	})
	assert_true(missing_result.is_error(), "economy_changed missing reason should be rejected.")
	assert_equal(missing_result.metadata.get("field"), "reason", "economy_changed should name the missing reason field.")


# Build an economy_changed dictionary from the valid baseline with ONE field overridden, then run it through
# try_from_dictionary (the malformed-payload reject path).
func _try_economy_changed_with(valid_payload: Dictionary, field: String, value: Variant) -> ActionResult:
	var payload: Dictionary = valid_payload.duplicate(true)
	payload[field] = value
	return DomainEvent.try_from_dictionary({
		"event_id": "economy_changed", "sequence_id": 1, "actor_id": "", "payload": payload
	})


func _curse_applied_serializes_and_parses_stable_payload() -> void:
	# Story 7.2 (AC2/AC3): a curse_applied SYSTEM event (no actor) — a curse/corruption-change record. `curse_source` is
	# the AC3 source-identifying lower_snake marker; `reason` is a lower_snake marker; curse_before/after +
	# corruption_before/after are non-negative integral; curse_delta/corruption_delta are SIGNED integral (an increment
	# positive, a cleanse negative). UNLIKE passive_destroyed there is NO roll/draw_index (a curse change is a recorded
	# amount, not a roll — deterministic).
	var event: DomainEvent = DomainEvent.curse_applied(9, {
		"curse_source": "cursed_blade_of_the_forsaken",
		"reason": "cursed_reward_accepted",
		"curse_before": 0,
		"curse_after": 1,
		"curse_delta": 1,
		"corruption_before": 0,
		"corruption_after": 0,
		"corruption_delta": 0
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "curse_applied", "curse_applied should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "curse_applied is a system event with an empty actor id.")
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "curse_applied carries NO roll (deterministic — zero RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "curse_applied carries NO draw_index (deterministic — zero RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "curse_applied should parse with an empty actor id: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.CURSE_APPLIED, "curse_applied should parse back to CURSE_APPLIED.")
	assert_equal(restored.payload.get("curse_source"), "cursed_blade_of_the_forsaken", "The curse_source (AC3) must survive a JSON round-trip.")
	assert_equal(restored.payload.get("curse_after"), 1, "curse_after must survive a JSON round-trip.")
	assert_equal(restored.payload.get("curse_delta"), 1, "curse_delta must survive a JSON round-trip.")

	# The CLEANSE path: a NEGATIVE curse_delta (the signed-delta path that lets ONE event serve both apply + cleanse).
	var cleanse_event: DomainEvent = DomainEvent.curse_applied(10, {
		"curse_source": "passive_destroyed_cleanse",
		"reason": "passive_destroyed_cleanse",
		"curse_before": 2, "curse_after": 1, "curse_delta": -1,
		"corruption_before": 0, "corruption_after": 0, "corruption_delta": 0
	})
	var cleanse_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(cleanse_event.to_dictionary())))
	assert_true(cleanse_parse.succeeded, "A cleanse curse_applied (negative delta) should parse: %s" % cleanse_parse.metadata)
	assert_equal((cleanse_parse.metadata.get("event") as DomainEvent).payload.get("curse_delta"), -1, "A negative curse_delta must survive the round-trip (the signed cleanse path).")


func _curse_applied_rejects_malformed_payloads() -> void:
	var valid_payload: Dictionary = {
		"curse_source": "cursed_blade_of_the_forsaken",
		"reason": "cursed_reward_accepted",
		"curse_before": 0,
		"curse_after": 1,
		"curse_delta": 1,
		"corruption_before": 0,
		"corruption_after": 0,
		"corruption_delta": 0
	}

	# A non-lower_snake / blank curse_source is rejected (AC3 — the source must be a clean marker).
	var bad_source: ActionResult = _try_curse_applied_with(valid_payload, "curse_source", "Cursed-Blade")
	assert_true(bad_source.is_error(), "curse_applied with a non-lower_snake curse_source should be rejected.")
	assert_equal(bad_source.error_code, &"invalid_event_payload", "Malformed curse_applied should use the stable code.")
	assert_equal(bad_source.metadata.get("field"), "curse_source", "curse_applied should name the curse_source field.")

	var blank_source: ActionResult = _try_curse_applied_with(valid_payload, "curse_source", "")
	assert_true(blank_source.is_error(), "curse_applied with a blank curse_source should be rejected.")
	assert_equal(blank_source.metadata.get("field"), "curse_source", "curse_applied should require a non-empty curse_source.")

	# A non-lower_snake reason is rejected.
	var bad_reason: ActionResult = _try_curse_applied_with(valid_payload, "reason", "Bad Reason")
	assert_true(bad_reason.is_error(), "curse_applied with a non-lower_snake reason should be rejected.")
	assert_equal(bad_reason.metadata.get("field"), "reason", "curse_applied should name the reason field.")

	# A NEGATIVE curse_before is rejected (a curse count is never negative). The delta MAY be negative.
	var neg_before: ActionResult = _try_curse_applied_with(valid_payload, "curse_before", -1)
	assert_true(neg_before.is_error(), "curse_applied with a negative curse_before should be rejected.")
	assert_equal(neg_before.metadata.get("field"), "curse_before", "curse_applied should require a non-negative curse_before.")

	# A non-integral curse_delta is rejected.
	var bad_delta: ActionResult = _try_curse_applied_with(valid_payload, "curse_delta", "many")
	assert_true(bad_delta.is_error(), "curse_applied with a non-integral curse_delta should be rejected.")
	assert_equal(bad_delta.metadata.get("field"), "curse_delta", "curse_applied should name the curse_delta field.")

	# An ARITHMETIC inconsistency (curse_after != curse_before + curse_delta) is rejected (the record must be honest).
	var inconsistent: ActionResult = _try_curse_applied_with(valid_payload, "curse_after", 99)
	assert_true(inconsistent.is_error(), "curse_applied whose curse_after diverges from before+delta should be rejected.")
	assert_equal(inconsistent.metadata.get("field"), "curse_after", "curse_applied should reject an inconsistent curse_after.")

	# A corruption arithmetic inconsistency is rejected too (both halves are checked).
	var bad_corruption: ActionResult = _try_curse_applied_with(valid_payload, "corruption_after", 5)
	assert_true(bad_corruption.is_error(), "curse_applied whose corruption_after diverges from before+delta should be rejected.")
	assert_equal(bad_corruption.metadata.get("field"), "corruption_after", "curse_applied should reject an inconsistent corruption_after.")

	# A missing field (drop curse_source) is rejected.
	var missing: Dictionary = valid_payload.duplicate(true)
	missing.erase("curse_source")
	var missing_result: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "curse_applied", "sequence_id": 1, "actor_id": "", "payload": missing
	})
	assert_true(missing_result.is_error(), "curse_applied missing curse_source should be rejected.")
	assert_equal(missing_result.metadata.get("field"), "curse_source", "curse_applied should name the missing curse_source field.")


# Build a curse_applied dictionary from the valid baseline with ONE field overridden, then run it through
# try_from_dictionary (the malformed-payload reject path).
func _try_curse_applied_with(valid_payload: Dictionary, field: String, value: Variant) -> ActionResult:
	var payload: Dictionary = valid_payload.duplicate(true)
	payload[field] = value
	return DomainEvent.try_from_dictionary({
		"event_id": "curse_applied", "sequence_id": 1, "actor_id": "", "payload": payload
	})


func _event_offered_serializes_and_parses_stable_payload() -> void:
	# Story 7.3 (AC1): an event_offered SYSTEM event (no actor) — a risk/reward EVENT-OFFER record. event_id is a
	# lower_snake content id; offered_choice_ids is a NON-EMPTY Array of lower_snake choice ids; roll + draw_index are
	# non-negative integral (the OFFER was rolled — the GENERATE provenance, mirroring reward_offered).
	var event: DomainEvent = DomainEvent.event_offered(9, {
		"event_id": "smugglers_cache",
		"offered_choice_ids": ["take_the_gold", "leave_the_cache"],
		"roll": 1,
		"draw_index": 1
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "event_offered", "event_offered should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "event_offered is a system event with an empty actor id.")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "event_offered should parse: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.EVENT_OFFERED, "event_offered should parse back to EVENT_OFFERED.")
	assert_equal(restored.payload.get("event_id"), "smugglers_cache", "The offered event_id must survive a JSON round-trip.")
	assert_equal((restored.payload.get("offered_choice_ids") as Array).size(), 2, "The offered choice ids must survive a JSON round-trip.")
	assert_equal(restored.payload.get("roll"), 1, "The roll must survive a JSON round-trip.")


func _event_offered_rejects_malformed_payloads() -> void:
	var valid_payload: Dictionary = {
		"event_id": "smugglers_cache",
		"offered_choice_ids": ["take_the_gold", "leave_the_cache"],
		"roll": 1,
		"draw_index": 1
	}
	# A non-lower_snake event_id is rejected.
	var bad_id: ActionResult = _try_event_offered_with(valid_payload, "event_id", "Smugglers-Cache")
	assert_true(bad_id.is_error(), "event_offered with a non-lower_snake event_id should be rejected.")
	assert_equal(bad_id.error_code, &"invalid_event_payload", "Malformed event_offered should use the stable code.")
	assert_equal(bad_id.metadata.get("field"), "event_id", "event_offered should name the event_id field.")

	# An EMPTY offered_choice_ids list is rejected (an offer with no choices is meaningless).
	var empty_choices: ActionResult = _try_event_offered_with(valid_payload, "offered_choice_ids", [])
	assert_true(empty_choices.is_error(), "event_offered with an empty offered_choice_ids should be rejected.")
	assert_equal(empty_choices.metadata.get("field"), "offered_choice_ids", "event_offered should name the offered_choice_ids field.")

	# A non-lower_snake choice id in the list is rejected.
	var bad_choice: ActionResult = _try_event_offered_with(valid_payload, "offered_choice_ids", ["Take-The-Gold"])
	assert_true(bad_choice.is_error(), "event_offered with a non-lower_snake choice id should be rejected.")
	assert_equal(bad_choice.metadata.get("field"), "offered_choice_ids", "event_offered should reject a non-lower_snake choice id.")

	# A negative roll is rejected.
	var bad_roll: ActionResult = _try_event_offered_with(valid_payload, "roll", -1)
	assert_true(bad_roll.is_error(), "event_offered with a negative roll should be rejected.")
	assert_equal(bad_roll.metadata.get("field"), "roll", "event_offered should name the roll field.")


func _try_event_offered_with(valid_payload: Dictionary, field: String, value: Variant) -> ActionResult:
	var payload: Dictionary = valid_payload.duplicate(true)
	payload[field] = value
	return DomainEvent.try_from_dictionary({
		"event_id": "event_offered", "sequence_id": 1, "actor_id": "", "payload": payload
	})


func _event_resolved_serializes_and_parses_stable_payload() -> void:
	# Story 7.3 (AC2): an event_resolved SYSTEM event (no actor) — a risk/reward EVENT-CHOICE-RESOLUTION record. event_id
	# + choice_id are lower_snake content ids; risk_flags is a (possibly EMPTY) Array of lower_snake risk-flag ids the
	# choice RAISED (the AC2 "future systems can query the resulting risk flags" record); reason is a lower_snake marker.
	# UNLIKE event_offered there is NO roll/draw_index (the choice is a recorded tradeoff, not a roll — deterministic).
	var event: DomainEvent = DomainEvent.event_resolved(9, {
		"event_id": "smugglers_cache",
		"choice_id": "take_the_gold",
		"risk_flags": ["elite_chance"],
		"reason": "event_choice_resolved"
	})
	var serialized: Dictionary = event.to_dictionary()
	assert_equal(serialized.get("event_id"), "event_resolved", "event_resolved should serialize a stable string id.")
	assert_equal(serialized.get("actor_id"), "", "event_resolved is a system event with an empty actor id.")
	assert_false((serialized.get("payload") as Dictionary).has("roll"), "event_resolved carries NO roll (deterministic — zero RNG).")
	assert_false((serialized.get("payload") as Dictionary).has("draw_index"), "event_resolved carries NO draw_index (deterministic — zero RNG).")

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(serialized)))
	assert_true(parse_result.succeeded, "event_resolved should parse: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(restored.event_type, DomainEvent.Type.EVENT_RESOLVED, "event_resolved should parse back to EVENT_RESOLVED.")
	assert_equal(restored.payload.get("event_id"), "smugglers_cache", "The resolved event_id must survive a JSON round-trip.")
	assert_equal(restored.payload.get("choice_id"), "take_the_gold", "The resolved choice_id must survive a JSON round-trip.")
	assert_equal((restored.payload.get("risk_flags") as Array).size(), 1, "The raised risk_flags must survive a JSON round-trip.")

	# A SAFE choice raises NO risk flag: an EMPTY risk_flags list is valid (the AC2 record for a decline).
	var safe_event: DomainEvent = DomainEvent.event_resolved(10, {
		"event_id": "smugglers_cache",
		"choice_id": "leave_the_cache",
		"risk_flags": [],
		"reason": "event_choice_resolved"
	})
	var safe_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(safe_event.to_dictionary())))
	assert_true(safe_parse.succeeded, "A safe-choice event_resolved (empty risk_flags) should parse: %s" % safe_parse.metadata)
	assert_equal(((safe_parse.metadata.get("event") as DomainEvent).payload.get("risk_flags") as Array).size(), 0, "An empty risk_flags list survives the round-trip (a safe choice raises none).")


func _event_resolved_rejects_malformed_payloads() -> void:
	var valid_payload: Dictionary = {
		"event_id": "smugglers_cache",
		"choice_id": "take_the_gold",
		"risk_flags": ["elite_chance"],
		"reason": "event_choice_resolved"
	}
	# A non-lower_snake event_id is rejected.
	var bad_event_id: ActionResult = _try_event_resolved_with(valid_payload, "event_id", "Smugglers Cache")
	assert_true(bad_event_id.is_error(), "event_resolved with a non-lower_snake event_id should be rejected.")
	assert_equal(bad_event_id.error_code, &"invalid_event_payload", "Malformed event_resolved should use the stable code.")
	assert_equal(bad_event_id.metadata.get("field"), "event_id", "event_resolved should name the event_id field.")

	# A non-lower_snake / blank choice_id is rejected.
	var bad_choice: ActionResult = _try_event_resolved_with(valid_payload, "choice_id", "Take-Gold")
	assert_true(bad_choice.is_error(), "event_resolved with a non-lower_snake choice_id should be rejected.")
	assert_equal(bad_choice.metadata.get("field"), "choice_id", "event_resolved should name the choice_id field.")

	var blank_choice: ActionResult = _try_event_resolved_with(valid_payload, "choice_id", "")
	assert_true(blank_choice.is_error(), "event_resolved with a blank choice_id should be rejected.")
	assert_equal(blank_choice.metadata.get("field"), "choice_id", "event_resolved should require a non-empty choice_id.")

	# A non-lower_snake risk flag in the list is rejected.
	var bad_flag: ActionResult = _try_event_resolved_with(valid_payload, "risk_flags", ["Elite-Chance"])
	assert_true(bad_flag.is_error(), "event_resolved with a non-lower_snake risk flag should be rejected.")
	assert_equal(bad_flag.metadata.get("field"), "risk_flags", "event_resolved should reject a non-lower_snake risk flag.")

	# A non-lower_snake reason is rejected.
	var bad_reason: ActionResult = _try_event_resolved_with(valid_payload, "reason", "Bad Reason")
	assert_true(bad_reason.is_error(), "event_resolved with a non-lower_snake reason should be rejected.")
	assert_equal(bad_reason.metadata.get("field"), "reason", "event_resolved should name the reason field.")

	# A missing field (drop choice_id) is rejected.
	var missing: Dictionary = valid_payload.duplicate(true)
	missing.erase("choice_id")
	var missing_result: ActionResult = DomainEvent.try_from_dictionary({
		"event_id": "event_resolved", "sequence_id": 1, "actor_id": "", "payload": missing
	})
	assert_true(missing_result.is_error(), "event_resolved missing choice_id should be rejected.")
	assert_equal(missing_result.metadata.get("field"), "choice_id", "event_resolved should name the missing choice_id field.")


func _try_event_resolved_with(valid_payload: Dictionary, field: String, value: Variant) -> ActionResult:
	var payload: Dictionary = valid_payload.duplicate(true)
	payload[field] = value
	return DomainEvent.try_from_dictionary({
		"event_id": "event_resolved", "sequence_id": 1, "actor_id": "", "payload": payload
	})


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
		DomainEvent.Type.REWARD_RESOLVED: &"reward_resolved",
		# Story 6.5: the passive_consumed SYSTEM event appended at the enum end (never renumbered).
		DomainEvent.Type.PASSIVE_CONSUMED: &"passive_consumed",
		# Story 6.6: the passive_destroyed SYSTEM event appended at the enum end (never renumbered).
		DomainEvent.Type.PASSIVE_DESTROYED: &"passive_destroyed",
		# Story 6.7: the item_consumed SYSTEM event appended at the enum end (never renumbered).
		DomainEvent.Type.ITEM_CONSUMED: &"item_consumed",
		# Story 7.1: the economy_changed SYSTEM event appended at the enum end (never renumbered).
		DomainEvent.Type.ECONOMY_CHANGED: &"economy_changed",
		# Story 7.2: the curse_applied SYSTEM event appended at the enum end (never renumbered).
		DomainEvent.Type.CURSE_APPLIED: &"curse_applied",
		# Story 7.3: the event_offered + event_resolved SYSTEM events appended at the enum end (never renumbered).
		DomainEvent.Type.EVENT_OFFERED: &"event_offered",
		DomainEvent.Type.EVENT_RESOLVED: &"event_resolved",
		# Story 8.1: the run_failed SYSTEM event appended at the enum end (never renumbered) — the run-FAILED boundary.
		DomainEvent.Type.RUN_FAILED: &"run_failed",
		# Story 8.3: the oath_shards_awarded SYSTEM event appended at the enum end (never renumbered) — the FIRST
		# persistent cross-run meta-award record.
		DomainEvent.Type.OATH_SHARDS_AWARDED: &"oath_shards_awarded",
		# Story 8.4: the content_discovered + profile_progress_merged SYSTEM events appended at the enum end (never
		# renumbered) — the run-scoped discovery record + the cross-run profile-merge record.
		DomainEvent.Type.CONTENT_DISCOVERED: &"content_discovered",
		DomainEvent.Type.PROFILE_PROGRESS_MERGED: &"profile_progress_merged",
		# Story 8.5: the first_death_recorded SYSTEM event appended at the enum end (never renumbered) — the first-death
		# narrative marker (the FIRST persistent per-profile-lifetime latch record).
		DomainEvent.Type.FIRST_DEATH_RECORDED: &"first_death_recorded",
		# Story 9.1: the boss_encounter_started SYSTEM event appended at the enum end (never renumbered) — the boss-
		# ENCOUNTER-SETUP boundary (the Larval Avatar encounter is requested + its arena set up; the run is NOT completed).
		DomainEvent.Type.BOSS_ENCOUNTER_STARTED: &"boss_encounter_started",
		# Story 9.2: the boss_phase_changed SYSTEM event appended at the enum end (never renumbered) — the deterministic
		# past-tense record of an applied FORWARD-ONLY Larval Avatar phase transition (to_phase > from_phase).
		DomainEvent.Type.BOSS_PHASE_CHANGED: &"boss_phase_changed",
		# Story 9.4: the first_victory_recorded + boss_defeated SYSTEM events appended at the enum end (never renumbered) —
		# the first-victory narrative marker (the OPPOSITE-terminal-phase twin of first_death_recorded) + the tactical
		# boss-defeat fact (DISTINCT from the run_completed + victory run-END record).
		DomainEvent.Type.FIRST_VICTORY_RECORDED: &"first_victory_recorded",
		DomainEvent.Type.BOSS_DEFEATED: &"boss_defeated",
		# Story 11.6: the oath_shards_spent SYSTEM event appended at the enum end (never renumbered) — the meta-SPEND
		# record (the oath_shards_awarded counterpart at the OPPOSITE sign; before - amount == after).
		DomainEvent.Type.OATH_SHARDS_SPENT: &"oath_shards_spent"
	}

	for event_type: int in expected_ids.keys():
		var event_id: StringName = DomainEvent.id_for_type(event_type)
		assert_equal(event_id, expected_ids[event_type], "DomainEvent ids should remain stable.")
		_assert_machine_id(String(event_id), "DomainEvent ids should be lower-snake machine ids.")
		# Round-trip: the id maps back to the same enum member (the append did not break type_for_id).
		assert_equal(DomainEvent.type_for_id(event_id), event_type, "DomainEvent id_for_type/type_for_id must round-trip.")

	# Story 7.1 (the 6.7 Round-1 Low / retro T3 hardening): tie expected_ids' size to the DomainEvent.Type member
	# count so a FUTURE appended event the author forgets to add here is caught (it would otherwise be silently
	# un-pinned and the test would still pass). The map pins every member EXCEPT the UNKNOWN sentinel, so
	# expected_ids.size() == Type.size() - 1; ADDITIONALLY iterate the enum asserting each non-UNKNOWN member is a
	# pinned key (a precise per-member message on a miss).
	assert_equal(expected_ids.size(), DomainEvent.Type.size() - 1, "expected_ids must pin EVERY DomainEvent.Type member except UNKNOWN (a future appended event must be added here).")
	for type_value: int in DomainEvent.Type.values():
		if type_value == DomainEvent.Type.UNKNOWN:
			continue
		assert_true(expected_ids.has(type_value), "Every non-UNKNOWN DomainEvent.Type member must be pinned in expected_ids (member %d is un-pinned)." % type_value)


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
