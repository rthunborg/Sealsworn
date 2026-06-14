extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

func run() -> Dictionary:
	_supported_schema_parses()
	_unsupported_schema_is_rejected()
	_seed_progression_flags_are_explicit()
	_run_state_contract_round_trips()
	_rng_stream_dictionary_round_trips()
	_between_level_composes_tactical_snapshot_into_level_state()
	_between_level_field_contract_round_trips_with_no_surprise_fields()
	_between_level_rejects_corrupt_embedded_tactical_snapshot()
	_between_level_manual_seed_marks_no_meta_progression()
	_root_seed_survives_full_int64_round_trip()
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
	assert_equal(int(str(parsed.rng_streams.get("root_seed"))), 9876, "RunSnapshot should preserve RNG root seed.")
	assert_equal(parsed_streams.get("combat").get("draw_index"), 1, "RunSnapshot should preserve combat draw index.")
	assert_equal(parsed_streams.get("rewards").get("draw_index"), 1, "RunSnapshot should preserve rewards draw index.")
	assert_true(parsed_streams.get("combat").has("seed"), "RunSnapshot should preserve RNG stream seed.")
	assert_true(parsed_streams.get("combat").has("state"), "RunSnapshot should preserve RNG stream state.")


# AC1/AC3: the between-level run save COMPOSES the Epic 1 TacticalSnapshot under a stable
# level_state key rather than inventing a parallel scene-owned tactical save format.
func _between_level_composes_tactical_snapshot_into_level_state() -> void:
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(4242)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	var turn_state: Dictionary = {"turn_number": 3, "active_actor_id": "hero"}

	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {
		"is_manual_seed": false,
		"current_route_node_id": "node-2",
		"turn_state": turn_state
	})
	assert_true(compose_result.succeeded, "RunSnapshot.from_between_level should compose a valid between-level save: %s" % compose_result.metadata)
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	assert_true(snapshot.level_state.has(RunSnapshot.TACTICAL_SNAPSHOT_KEY), "Between-level save should embed the tactical snapshot under the stable level_state key.")
	var embedded: Dictionary = snapshot.level_state.get(RunSnapshot.TACTICAL_SNAPSHOT_KEY)
	var embedded_parse: ActionResult = TacticalSnapshot.parse(embedded)
	assert_true(embedded_parse.succeeded, "Embedded tactical snapshot must parse via TacticalSnapshot.parse (proving reuse, not a forked format): %s" % embedded_parse.metadata)

	# The composer must NOT flatten tactical board/turn/telegraph/event fields onto the run save root.
	assert_equal(snapshot.board, {}, "Between-level composer must not duplicate the tactical board as a top-level run-save field.")
	assert_false(snapshot.level_state.has("cells"), "Between-level composer must not flatten tactical board cells into level_state.")

	# The embedded tactical snapshot must still strictly extract and validate from the run save.
	var extracted: ActionResult = snapshot.try_tactical_snapshot()
	assert_true(extracted.succeeded, "try_tactical_snapshot should return the strictly validated embedded snapshot.")
	var extracted_snapshot: TacticalSnapshot = extracted.metadata.get("snapshot")
	assert_equal(extracted_snapshot.turn_state.get("turn_number"), 3, "Extracted tactical snapshot should preserve embedded turn state.")


# AC2: every AC2-required field round-trips, future fields stay empty/nullable, no surprise keys.
func _between_level_field_contract_round_trips_with_no_surprise_fields() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	var streams: RngStreamSet = RngStreamSet.new(2026)
	streams.rand_int(RngStreamSet.STREAM_LOOT, 1, 100, {"system": "loot"})

	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {
		"is_manual_seed": false,
		"current_route_node_id": "boundary-1"
	})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	var data: Dictionary = snapshot.to_dictionary()
	var parse_result: ActionResult = RunSnapshot.parse(data)
	assert_true(parse_result.succeeded, "Between-level snapshot should round-trip through to_dictionary -> parse.")
	var parsed: RunSnapshot = parse_result.metadata.get("snapshot")

	# Schema + content version.
	assert_equal(parsed.schema_version, RunSnapshot.SCHEMA_VERSION, "AC2: schema version must be present.")
	assert_equal(parsed.content_version, "mvp-0", "AC2: content version must be present.")
	# Root seed + RNG stream states.
	assert_equal(parsed.root_seed, 2026, "AC2: root seed must round-trip.")
	assert_true(parsed.rng_streams.has("streams"), "AC2: RNG stream states must be present.")
	assert_equal(int(parsed.rng_streams.get("streams").get("loot").get("draw_index")), 1, "AC2: RNG stream draw indexes must round-trip.")
	# Route / current-node state (empty where unavailable; current node set here).
	assert_equal(parsed.route_state, {}, "AC2: route state defaults empty until route systems arrive.")
	assert_equal(parsed.current_route_node_id, "boundary-1", "AC2: current route node should round-trip when available.")
	assert_equal(parsed.revealed_route_node_ids, [], "AC2: revealed route nodes default empty.")
	# Player/level state (the embedded tactical snapshot).
	assert_true(parsed.level_state.has(RunSnapshot.TACTICAL_SNAPSHOT_KEY), "AC2: level state should carry the composed tactical snapshot.")
	# Inventory placeholder + other gameplay fields stay at empty/nullable defaults.
	assert_equal(parsed.inventory, [], "AC2: inventory placeholder must stay empty.")
	assert_equal(parsed.equipment, {}, "AC2: equipment must stay empty default.")
	assert_equal(parsed.passives, [], "AC2: passives must stay empty default.")
	assert_equal(parsed.curses, [], "AC2: curses must stay empty default.")
	assert_equal(parsed.gold, 0, "AC2: gold must stay zero default.")
	assert_equal(parsed.oath_shards, 0, "AC2: oath shards must stay zero default.")
	assert_equal(parsed.corruption, 0, "AC2: corruption must stay zero default.")
	assert_equal(parsed.affinities, {}, "AC2: affinities must stay empty default.")
	assert_equal(parsed.meta_progression, {}, "AC2: meta progression must stay empty default.")
	# Manual-seed eligibility split.
	assert_false(parsed.is_manual_seed, "AC2: manual-seed flag must round-trip.")
	assert_true(parsed.meta_progression_eligible, "AC2: meta-progression eligibility must round-trip.")
	# No surprise keys and the resolved ambiguous field stays gone.
	assert_false(data.has("manual_seed_eligible_for_progression"), "AC2: the ambiguous manual-seed progression field must not reappear.")
	var allowed_keys: Dictionary = _allowed_run_snapshot_keys()
	for key: Variant in data.keys():
		assert_true(allowed_keys.has(key), "AC2: between-level save must not introduce a surprise top-level key (%s)." % str(key))


# AC3: a corrupt embedded tactical snapshot is rejected with a structured error and exposes no
# partial state. The run-save parse() stays lenient for forward-compat, but the embedded tactical
# payload must remain strictly validated on extraction.
func _between_level_rejects_corrupt_embedded_tactical_snapshot() -> void:
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(7)
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	# Corrupt the embedded tactical board (occupant referencing no entity) after composition.
	var corrupt_embedded: Dictionary = snapshot.level_state.get(RunSnapshot.TACTICAL_SNAPSHOT_KEY).duplicate(true)
	var cells: Array = corrupt_embedded.get("board").get("cells")
	cells[0]["occupant_id"] = "ghost_that_does_not_exist"
	snapshot.level_state[RunSnapshot.TACTICAL_SNAPSHOT_KEY] = corrupt_embedded

	# The lenient run-save parse still succeeds (forward-compat of run-level fields)...
	var run_parse: ActionResult = RunSnapshot.parse(snapshot.to_dictionary())
	assert_true(run_parse.succeeded, "Run-save parse stays lenient for run-level forward-compat.")
	# ...but strict tactical extraction must reject the corrupt embedded payload with structure.
	var parsed: RunSnapshot = run_parse.metadata.get("snapshot")
	var extracted: ActionResult = parsed.try_tactical_snapshot()
	assert_true(extracted.is_error(), "Corrupt embedded tactical snapshot must be rejected on strict extraction.")
	assert_equal(extracted.error_code, &"invalid_tactical_snapshot", "Corrupt embedded tactical snapshot must surface the tactical validation error code.")
	assert_false(extracted.metadata.has("snapshot"), "Rejected embedded tactical snapshot must not expose partial state.")

	# A missing embedded tactical snapshot is also a structured error, not a crash.
	var no_tactical: RunSnapshot = RunSnapshot.new()
	var missing_extract: ActionResult = no_tactical.try_tactical_snapshot()
	assert_true(missing_extract.is_error(), "Missing embedded tactical snapshot must be a structured error.")
	assert_equal(missing_extract.error_code, &"missing_tactical_snapshot", "Missing embedded tactical snapshot must use a stable error code.")


# Manual-seed contract: a manual-seed between-level save grants no meta progression.
func _between_level_manual_seed_marks_no_meta_progression() -> void:
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(99)
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {"is_manual_seed": true})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	assert_true(snapshot.is_manual_seed, "Manual-seed run should set is_manual_seed.")
	assert_false(snapshot.meta_progression_eligible, "Manual-seed run must not be eligible for meta progression.")


# AC2/AC6: root seed must preserve full int64 fidelity through a serialization round-trip.
func _root_seed_survives_full_int64_round_trip() -> void:
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.root_seed = 9223372036854775000
	var data: Dictionary = snapshot.to_dictionary()
	var json_data: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(json_data is Dictionary, "Run snapshot should survive JSON stringify/parse.")
	var parse_result: ActionResult = RunSnapshot.parse(json_data)
	assert_true(parse_result.succeeded, "Run snapshot with a full-range int64 root seed should parse after JSON.")
	assert_equal(parse_result.metadata.get("snapshot").root_seed, 9223372036854775000, "Full int64 root seed must not lose precision through a JSON save round-trip.")


func _allowed_run_snapshot_keys() -> Dictionary:
	var keys: Dictionary = {}
	for key: String in [
		"schema_version", "content_version", "profile_id", "run_id", "root_seed",
		"is_manual_seed", "meta_progression_eligible", "route_state", "current_route_node_id",
		"revealed_route_node_ids", "level_state", "turn_state", "rng_streams", "board",
		"inventory", "equipment", "passives", "curses", "gold", "oath_shards", "corruption",
		"affinities", "meta_progression"
	]:
		keys[key] = true
	return keys
