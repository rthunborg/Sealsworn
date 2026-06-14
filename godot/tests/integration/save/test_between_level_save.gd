extends "res://tests/unit/test_case.gd"

# End-to-end between-level save foundation (Story 2.7):
#   assemble real domain state -> compose RunSnapshot embedding a TacticalSnapshot ->
#   SaveRepository.write_run_snapshot() -> read_run_snapshot() -> reparse the embedded
#   tactical snapshot strictly, asserting the save COMPOSES the Epic 1 tactical snapshot
#   (no parallel scene-owned format), preserves seed/RNG/board/turn/manual-seed fidelity
#   across a real JSON round-trip, contains only serializable domain data, and reports a
#   structured failure without corrupting domain state.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveManager = preload("res://scripts/autoloads/save_manager.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

const TEST_SAVE_PATH := "user://test_between_level_save.json"

func run() -> Dictionary:
	_assemble_write_read_reparse_round_trip_preserves_fidelity()
	_written_save_contains_only_serializable_domain_data()
	_failed_write_reports_structured_error_and_preserves_domain_and_file()
	_cleanup()
	return result()


func _assemble_write_read_reparse_round_trip_preserves_fidelity() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	board.get_cell(Vector2i(0, 2)).visible = true
	board.get_cell(Vector2i(0, 2)).explored = true
	var streams: RngStreamSet = RngStreamSet.new(135790)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	streams.rand_int(RngStreamSet.STREAM_MAP, 1, 20, {"system": "map"})
	streams.rand_float(RngStreamSet.STREAM_REWARDS, {"system": "rewards"})
	var turn_state: Dictionary = {"turn_number": 5, "active_actor_id": "hero", "phase": "player"}
	var pending_telegraphs: Array[Dictionary] = [{
		"telegraph_id": "ash_seer_mark:enemy_seer:6",
		"kind": "ash_seer_mark",
		"source_entity_id": "enemy_seer",
		"target_entity_id": "hero",
		"marked_cell": {"x": 0, "y": 2},
		"created_turn_number": 5,
		"due_turn_number": 6,
		"damage": 4,
		"damage_type": "physical",
		"status": "pending"
	}]
	var events: Array[DomainEvent] = [
		DomainEvent.board_created(1, board.width, board.height)
	]

	# Snapshot the source RNG state BEFORE composing, to prove save is a non-mutating read.
	var rng_before_compose: Dictionary = streams.to_snapshot()
	var board_before_compose: Dictionary = board.to_snapshot()

	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {
		"is_manual_seed": false,
		"current_route_node_id": "level-2-entry",
		"turn_state": turn_state,
		"pending_telegraphs": pending_telegraphs,
		"event_log": events
	})
	assert_true(compose_result.succeeded, "Between-level composition should succeed: %s" % compose_result.metadata)
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	# Composition must not mutate the source domain state.
	assert_equal(streams.to_snapshot(), rng_before_compose, "Composing a between-level save must not consume RNG draws or mutate streams.")
	assert_equal(board.to_snapshot(), board_before_compose, "Composing a between-level save must not mutate the source board.")

	# Write through the real repository, then read it back.
	var repository: SaveRepository = SaveRepository.new()
	var write_result: ActionResult = repository.write_run_snapshot(snapshot, TEST_SAVE_PATH)
	assert_true(write_result.succeeded, "Between-level save should write through SaveRepository: %s" % write_result.metadata)

	var read_result: ActionResult = repository.read_run_snapshot(TEST_SAVE_PATH)
	assert_true(read_result.succeeded, "Between-level save should read back through SaveRepository: %s" % read_result.metadata)
	var loaded: RunSnapshot = read_result.metadata.get("snapshot")

	# Run-level fidelity across the JSON round-trip.
	assert_equal(loaded.root_seed, 135790, "Root seed must survive write -> read.")
	assert_equal(loaded.current_route_node_id, "level-2-entry", "Current route node must survive write -> read.")
	assert_false(loaded.is_manual_seed, "Manual-seed flag must survive write -> read.")
	assert_true(loaded.meta_progression_eligible, "Meta-progression eligibility must survive write -> read.")

	# Run-level RNG snapshot must restore losslessly (64-bit state preserved).
	var restored_run_streams: RngStreamSet = RngStreamSet.new(0)
	var run_rng_restore: ActionResult = restored_run_streams.try_restore(loaded.rng_streams)
	assert_true(run_rng_restore.succeeded, "Run-level RNG snapshot must restore after a real JSON save round-trip: %s" % run_rng_restore.metadata)
	# The restored run-level streams must reproduce the same next draw as the live streams.
	var live_next: ActionResult = streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 1000000, {"system": "combat", "consumer": "round_trip_check"})
	var restored_next: ActionResult = restored_run_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 1000000, {"system": "combat", "consumer": "round_trip_check"})
	assert_equal(restored_next.metadata.get("value"), live_next.metadata.get("value"), "Restored run-level RNG must reproduce the exact next combat draw (determinism preserved).")

	# AC3: the embedded tactical snapshot must reparse strictly after the JSON round-trip.
	var tactical_extract: ActionResult = loaded.try_tactical_snapshot()
	assert_true(tactical_extract.succeeded, "Embedded tactical snapshot must reparse strictly after write -> read: %s" % tactical_extract.metadata)
	var loaded_tactical: TacticalSnapshot = tactical_extract.metadata.get("snapshot")

	# Embedded tactical board must restore and preserve turn/telegraph fidelity.
	var board_restore: ActionResult = BoardState.try_from_snapshot(loaded_tactical.board)
	assert_true(board_restore.succeeded, "Embedded tactical board must restore from the loaded save.")
	var restored_board: BoardState = board_restore.metadata.get("board")
	assert_equal(restored_board.width, board.width, "Restored board width must match.")
	assert_equal(restored_board.height, board.height, "Restored board height must match.")
	assert_equal(loaded_tactical.turn_state.get("turn_number"), 5, "Embedded turn state must survive the round-trip.")
	assert_equal(loaded_tactical.pending_telegraphs.size(), 1, "Embedded pending telegraphs must survive the round-trip.")
	assert_equal(loaded_tactical.pending_telegraphs[0].get("kind"), "ash_seer_mark", "Embedded telegraph kind must survive the round-trip.")

	# Embedded tactical RNG must also restore losslessly.
	var restored_tactical_streams: RngStreamSet = RngStreamSet.new(0)
	var tactical_rng_restore: ActionResult = restored_tactical_streams.try_restore(loaded_tactical.rng_streams)
	assert_true(tactical_rng_restore.succeeded, "Embedded tactical RNG snapshot must restore after write -> read.")
	_cleanup()


func _written_save_contains_only_serializable_domain_data() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(24680)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {"current_route_node_id": "n-3"})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Save should write for serialization inspection.")

	# Read the raw bytes back and parse as JSON to inspect actual persisted data.
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	assert_true(file != null, "Written save file should be openable for inspection.")
	var raw_text: String = file.get_as_text()
	file = null
	var parsed: Variant = JSON.parse_string(raw_text)
	assert_true(parsed is Dictionary, "Persisted save must be a JSON object.")

	# AC1/AC6: only primitives/arrays/dictionaries, no Object/Node/Callable/RID, no forbidden refs.
	assert_true(_is_json_compatible(parsed), "Persisted save must contain only JSON-compatible primitives, arrays, and dictionaries.")
	assert_false(_contains_forbidden_reference(parsed), "Persisted save must not contain scene, audio, animation, or presentation references.")

	# The embedded tactical payload is present and itself serializable domain data.
	var level_state: Dictionary = parsed.get("level_state")
	assert_true(level_state.has(RunSnapshot.TACTICAL_SNAPSHOT_KEY), "Persisted save should embed the tactical snapshot under the stable key.")
	assert_true(level_state.get(RunSnapshot.TACTICAL_SNAPSHOT_KEY) is Dictionary, "Persisted embedded tactical snapshot should be a plain dictionary.")
	_cleanup()


func _failed_write_reports_structured_error_and_preserves_domain_and_file() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	var streams: RngStreamSet = RngStreamSet.new(8642)
	streams.rand_int(RngStreamSet.STREAM_LOOT, 1, 100, {"system": "loot"})
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {"current_route_node_id": "keep"})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	# Establish a prior valid save through the between-level entry point.
	var manager: Node = SaveManager.new()
	var first_write: ActionResult = manager.autosave_between_level(snapshot, TEST_SAVE_PATH)
	assert_true(first_write.succeeded, "Initial between-level autosave should succeed.")

	var board_before: Dictionary = board.to_snapshot()
	var rng_before: Dictionary = streams.to_snapshot()
	var snapshot_before: Dictionary = snapshot.to_dictionary()

	# Block the temp path with a directory to force a late failure on the canonical save path.
	var tmp_path: String = "%s.tmp" % TEST_SAVE_PATH
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	DirAccess.make_dir_absolute(tmp_path)

	var failing_write: ActionResult = manager.autosave_between_level(snapshot, TEST_SAVE_PATH)
	assert_true(failing_write.is_error(), "A blocked between-level autosave must return a structured error.")
	assert_equal(failing_write.error_code, &"save_open_failed", "Blocked autosave must surface the stable repository error code.")
	assert_true(failing_write.metadata.has("path"), "Blocked autosave must include diagnostic metadata.")

	# Domain state must be untouched by the failed write.
	assert_equal(board.to_snapshot(), board_before, "Failed autosave must not mutate the board.")
	assert_equal(streams.to_snapshot(), rng_before, "Failed autosave must not mutate the RNG streams.")
	assert_equal(snapshot.to_dictionary(), snapshot_before, "Failed autosave must not mutate the in-memory RunSnapshot.")

	# The original valid save must be preserved and readable.
	DirAccess.remove_absolute(tmp_path)
	var read_back: ActionResult = SaveRepository.new().read_run_snapshot(TEST_SAVE_PATH)
	assert_true(read_back.succeeded, "Original between-level save must be preserved and readable after a failed write.")
	assert_equal(read_back.metadata.get("snapshot").current_route_node_id, "keep", "Preserved save must retain original data.")

	manager.free()
	_cleanup()


func _cleanup() -> void:
	for path: String in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH, "%s.bak" % TEST_SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)


func _is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if not _is_json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				if typeof(key) != TYPE_STRING:
					return false
				if not _is_json_compatible(value[key]):
					return false
			return true
		_:
			return false


func _contains_forbidden_reference(value: Variant) -> bool:
	match typeof(value):
		TYPE_STRING:
			var text: String = value
			return (
				text.begins_with("res://")
				or text.ends_with(".tscn")
				or text.ends_with(".scn")
				or text.ends_with(".anim")
				or text.ends_with(".ogg")
				or text.ends_with(".wav")
				or text.ends_with(".mp3")
				or text.to_lower().contains("presentation")
			)
		TYPE_ARRAY:
			for item: Variant in value:
				if _contains_forbidden_reference(item):
					return true
			return false
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				if _contains_forbidden_reference(value[key]):
					return true
			return false
		_:
			return false
