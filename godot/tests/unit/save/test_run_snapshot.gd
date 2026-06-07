extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")

func run() -> Dictionary:
	_supported_schema_parses()
	_unsupported_schema_is_rejected()
	_seed_progression_flags_are_explicit()
	_run_state_contract_round_trips()
	_rng_stream_dictionary_round_trips()
	return result()


func _supported_schema_parses() -> void:
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.root_seed = 123

	var result_value: ActionResult = RunSnapshot.parse(snapshot.to_dictionary())

	assert_true(result_value.succeeded, "RunSnapshot should parse the current schema.")
	assert_equal(result_value.metadata.get("snapshot").root_seed, 123, "RunSnapshot should preserve root seed.")


func _unsupported_schema_is_rejected() -> void:
	var result_value: ActionResult = RunSnapshot.parse({
		"schema_version": RunSnapshot.SCHEMA_VERSION + 1,
		"content_version": "future"
	})

	assert_true(result_value.is_error(), "RunSnapshot should reject unsupported schemas.")
	assert_equal(result_value.error_code, &"unsupported_save_schema", "RunSnapshot should explain unsupported schemas.")


func _seed_progression_flags_are_explicit() -> void:
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.is_manual_seed = true
	snapshot.meta_progression_eligible = false

	var data: Dictionary = snapshot.to_dictionary()
	var result_value: ActionResult = RunSnapshot.parse(data)
	var parsed: RunSnapshot = result_value.metadata.get("snapshot")

	assert_false(data.has("manual_seed_eligible_for_progression"), "Run snapshots should not use the ambiguous manual-seed progression field.")
	assert_true(parsed.is_manual_seed, "Run snapshots should preserve manual seed state.")
	assert_false(parsed.meta_progression_eligible, "Run snapshots should preserve explicit meta-progression eligibility.")


func _run_state_contract_round_trips() -> void:
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.profile_id = "profile-a"
	snapshot.run_id = "run-a"
	snapshot.route_state = {"nodes": [{"id": "start"}], "visited_node_ids": ["start"]}
	snapshot.current_route_node_id = "start"
	snapshot.revealed_route_node_ids = ["start", "choice-a"]
	snapshot.level_state = {"level_id": "level-1"}
	snapshot.turn_state = {"turn_number": 4, "active_actor_id": "hero"}
	snapshot.inventory = [{"definition_id": "iron_key", "quantity": 1}]
	snapshot.equipment = {"weapon": "practice_blade"}
	snapshot.passives = ["oath_memory"]
	snapshot.curses = ["salt_debt"]
	snapshot.gold = 12
	snapshot.oath_shards = 3
	snapshot.corruption = 1
	snapshot.affinities = {"salt": 2}
	snapshot.meta_progression = {"unlock_ids": ["starter"]}

	var result_value: ActionResult = RunSnapshot.parse(snapshot.to_dictionary())
	var parsed: RunSnapshot = result_value.metadata.get("snapshot")

	assert_true(result_value.succeeded, "RunSnapshot should parse the full run-state contract.")
	assert_equal(parsed.profile_id, "profile-a", "RunSnapshot should preserve profile split.")
	assert_equal(parsed.current_route_node_id, "start", "RunSnapshot should preserve current route node.")
	assert_equal(parsed.revealed_route_node_ids, ["start", "choice-a"], "RunSnapshot should preserve revealed route info.")
	assert_equal(parsed.turn_state.get("turn_number"), 4, "RunSnapshot should preserve turn state.")
	assert_equal(parsed.inventory.size(), 1, "RunSnapshot should preserve inventory state.")
	assert_equal(parsed.gold, 12, "RunSnapshot should preserve run currency.")
	assert_equal(parsed.meta_progression.get("unlock_ids"), ["starter"], "RunSnapshot should preserve meta/profile data separately.")


func _rng_stream_dictionary_round_trips() -> void:
	var streams: RngStreamSet = RngStreamSet.new(9876)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	streams.rand_float(RngStreamSet.STREAM_REWARDS, {"system": "rewards"})

	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.rng_streams = streams.to_snapshot()

	var result_value: ActionResult = RunSnapshot.parse(snapshot.to_dictionary())
	var parsed: RunSnapshot = result_value.metadata.get("snapshot")
	var parsed_streams: Dictionary = parsed.rng_streams.get("streams")

	assert_true(result_value.succeeded, "RunSnapshot should parse RNG stream dictionaries.")
	assert_equal(parsed.rng_streams.get("root_seed"), 9876, "RunSnapshot should preserve RNG root seed.")
	assert_equal(parsed_streams.get("combat").get("draw_index"), 1, "RunSnapshot should preserve combat draw index.")
	assert_equal(parsed_streams.get("rewards").get("draw_index"), 1, "RunSnapshot should preserve rewards draw index.")
	assert_true(parsed_streams.get("combat").has("seed"), "RunSnapshot should preserve RNG stream seed.")
	assert_true(parsed_streams.get("combat").has("state"), "RunSnapshot should preserve RNG stream state.")
