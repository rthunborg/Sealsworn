extends "res://tests/unit/test_case.gd"

# Story 2.8 — domain-side resume service unit tests.
#
# RunResumeService composes the existing restore primitives
# (SaveRepository.read_run_snapshot -> RunSnapshot.parse -> try_tactical_snapshot ->
# BoardState.try_from_snapshot -> RngStreamSet.try_restore) into a single structured
# ActionResult. These tests prove:
#   AC1 — a valid between-level save (written through SaveRepository, read through it)
#         restores BoardState (incl. fog flags), the embedded TacticalSnapshot
#         (turn_state, pending_telegraphs), and the run-level RngStreamSet faithfully, and
#         the resume payload contains only domain objects / JSON-compatible data with no
#         scene/audio/presentation references.
#   AC2 — incompatible/corrupt saves fail with a stable structured error_code + diagnostic
#         metadata and expose NO partial restored state, and the original save file is
#         intact after a failed read.
#   RNG authority — the run-level rng_streams equals the embedded tactical rng_streams for a
#         between-level save (closes a Story 2.7 deferred item); the run-level streams are the
#         restored live gameplay streams.
#   AC3 — a mid-level (arbitrary-turn-boundary) save round-trips fog + entities + pending turn
#         state + RNG stream state + event log faithfully through the resume service.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const GameSession = preload("res://scripts/autoloads/game_session.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveManager = preload("res://scripts/autoloads/save_manager.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

const TEST_SAVE_PATH := "user://test_run_resume_service.json"

func run() -> Dictionary:
	_resume_restores_valid_between_level_save()
	_resume_payload_exposes_only_domain_state_no_scene_truth()
	_resume_run_level_streams_equal_embedded_tactical_streams()
	_resume_missing_file_fails_structured()
	_resume_unparseable_bytes_fail_structured()
	_resume_unsupported_schema_fails_structured()
	_resume_corrupt_embedded_tactical_fails_structured_no_partial_state()
	_resume_malformed_rng_fails_structured_no_partial_state()
	_resume_failed_read_leaves_original_save_intact()
	_resume_restores_mid_level_fog_entities_pending_turn_and_rng()
	_save_manager_resume_run_delegates_to_service()
	_game_session_restore_preserves_full_int64_root_seed()
	_cleanup()
	return result()


# AC1: a valid between-level save restores domain state through a real JSON write -> read.
func _resume_restores_valid_between_level_save() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	# Partial fog: mark a couple of cells visible/explored so fog flags must survive restore.
	board.get_cell(Vector2i(0, 2)).visible = true
	board.get_cell(Vector2i(0, 2)).explored = true
	board.get_cell(Vector2i(1, 2)).explored = true
	var streams: RngStreamSet = RngStreamSet.new(135790)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	streams.rand_int(RngStreamSet.STREAM_MAP, 1, 20, {"system": "map"})
	streams.rand_float(RngStreamSet.STREAM_REWARDS, {"system": "rewards"})
	var turn_state: Dictionary = {"turn_number": 5, "active_actor_id": "hero", "phase": "player"}
	var pending_telegraphs: Array[Dictionary] = [{
		"telegraph_id": "ash_seer_mark:enemy_seer:6",
		"kind": "ash_seer_mark",
		"marked_cell": {"x": 0, "y": 2}
	}]
	var events: Array[DomainEvent] = [DomainEvent.board_created(1, board.width, board.height)]

	var source_board_snapshot: Dictionary = board.to_snapshot()

	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {
		"is_manual_seed": false,
		"current_route_node_id": "level-2-entry",
		"turn_state": turn_state,
		"pending_telegraphs": pending_telegraphs,
		"event_log": events
	})
	assert_true(compose_result.succeeded, "Between-level composition should succeed: %s" % compose_result.metadata)
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Save should write through SaveRepository.")

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.succeeded, "Resuming a valid between-level save should succeed: %s" % resume.metadata)

	var restored_board: BoardState = resume.metadata.get("board")
	assert_true(restored_board != null, "Resume must return a restored BoardState.")
	# Restored board snapshot equals the source board snapshot (incl. fog flags + occupancy).
	assert_equal(restored_board.to_snapshot(), source_board_snapshot, "Restored board snapshot must equal the source board snapshot (fog flags included).")

	var restored_tactical: TacticalSnapshot = resume.metadata.get("tactical_snapshot")
	assert_true(restored_tactical != null, "Resume must return the restored TacticalSnapshot.")
	assert_equal(restored_tactical.turn_state.get("turn_number"), 5, "Restored tactical snapshot must preserve turn_number.")
	assert_equal(restored_tactical.turn_state.get("phase"), "player", "Restored tactical snapshot must preserve turn phase.")
	assert_equal(restored_tactical.pending_telegraphs.size(), 1, "Restored tactical snapshot must preserve pending telegraphs.")
	assert_equal(restored_tactical.pending_telegraphs[0].get("kind"), "ash_seer_mark", "Restored telegraph kind must survive.")
	assert_equal(restored_tactical.event_log.size(), 1, "Restored tactical snapshot must preserve the event log.")

	var restored_run: RunSnapshot = resume.metadata.get("run_snapshot")
	assert_true(restored_run != null, "Resume must return the restored RunSnapshot.")
	assert_equal(restored_run.root_seed, 135790, "Restored run root_seed must survive write -> read.")
	assert_equal(restored_run.current_route_node_id, "level-2-entry", "Restored run route node must survive.")

	# Run-level streams restored as the live gameplay streams; must reproduce the exact next draw.
	var restored_streams: RngStreamSet = resume.metadata.get("rng_streams")
	assert_true(restored_streams != null, "Resume must return the restored run-level RngStreamSet.")
	var live_next: ActionResult = streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 1000000, {"system": "combat", "consumer": "resume_check"})
	var restored_next: ActionResult = restored_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 1000000, {"system": "combat", "consumer": "resume_check"})
	assert_equal(restored_next.metadata.get("value"), live_next.metadata.get("value"), "Restored run-level RNG must reproduce the exact next combat draw.")
	_cleanup()


# AC1: the resume payload is domain state only — no scene node, no audio/presentation/scene
# reference is ever serialized or returned. Presentation rebuilds FROM restored domain state.
func _resume_payload_exposes_only_domain_state_no_scene_truth() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(24680)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {"current_route_node_id": "n-3"})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Save should write for resume inspection.")

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.succeeded, "Resume should succeed for the no-scene-truth check.")

	# The restored domain objects serialize back to JSON-compatible, scene-free dictionaries.
	var restored_board: BoardState = resume.metadata.get("board")
	var restored_tactical: TacticalSnapshot = resume.metadata.get("tactical_snapshot")
	var restored_run: RunSnapshot = resume.metadata.get("run_snapshot")
	var restored_streams: RngStreamSet = resume.metadata.get("rng_streams")
	assert_true(_is_json_compatible(restored_board.to_snapshot()), "Restored board snapshot must be JSON-compatible domain data.")
	assert_false(_contains_forbidden_reference(restored_board.to_snapshot()), "Restored board must not carry scene/audio/presentation references.")
	assert_true(_is_json_compatible(restored_tactical.to_dictionary()), "Restored tactical snapshot must be JSON-compatible domain data.")
	assert_false(_contains_forbidden_reference(restored_tactical.to_dictionary()), "Restored tactical snapshot must not carry forbidden references.")
	assert_true(_is_json_compatible(restored_run.to_dictionary()), "Restored run snapshot must be JSON-compatible domain data.")
	assert_false(_contains_forbidden_reference(restored_run.to_dictionary()), "Restored run snapshot must not carry forbidden references.")
	assert_true(_is_json_compatible(restored_streams.to_snapshot()), "Restored RNG snapshot must be JSON-compatible domain data.")
	_cleanup()


# RNG authority (closes Story 2.7 defer): for a between-level save the run-level rng_streams
# equals the embedded tactical rng_streams; the run-level streams win as the live streams.
func _resume_run_level_streams_equal_embedded_tactical_streams() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	var streams: RngStreamSet = RngStreamSet.new(555)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	streams.rand_int(RngStreamSet.STREAM_LEVEL, 1, 4, {"system": "level"})
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {"current_route_node_id": "x"})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Save should write for RNG-authority check.")

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.succeeded, "Resume should succeed for the RNG-authority check.")
	var restored_run: RunSnapshot = resume.metadata.get("run_snapshot")
	var restored_tactical: TacticalSnapshot = resume.metadata.get("tactical_snapshot")
	# Equal by construction at the between-level boundary — assert it so a future refactor can't
	# silently diverge run-level and embedded-tactical RNG snapshots.
	assert_equal(restored_run.rng_streams, restored_tactical.rng_streams, "Run-level rng_streams must equal embedded tactical rng_streams for a between-level save.")

	# The returned live streams are the run-level streams (authority): they must reproduce the
	# same next draw as a fresh restore of the run-level snapshot.
	var restored_streams: RngStreamSet = resume.metadata.get("rng_streams")
	var run_level_streams: RngStreamSet = RngStreamSet.new(0)
	assert_true(run_level_streams.try_restore(restored_run.rng_streams).succeeded, "Run-level snapshot must restore independently.")
	var from_service: ActionResult = restored_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 1000000, {"system": "combat", "consumer": "authority"})
	var from_run_level: ActionResult = run_level_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 1000000, {"system": "combat", "consumer": "authority"})
	assert_equal(from_service.metadata.get("value"), from_run_level.metadata.get("value"), "Resume must hand back the run-level streams as the live gameplay streams.")
	_cleanup()


# AC2 (a): missing file -> save_not_found, no partial state.
func _resume_missing_file_fails_structured() -> void:
	_cleanup()
	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.is_error(), "Resuming a missing save must be a structured error.")
	assert_equal(resume.error_code, &"save_not_found", "Missing save must use the save_not_found code.")
	_assert_no_partial_state(resume, "save_not_found")


# AC2 (b): non-JSON garbage bytes -> save_parse_failed, no partial state.
func _resume_unparseable_bytes_fail_structured() -> void:
	_cleanup()
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	assert_true(file != null, "Should be able to write garbage bytes for the parse-failure test.")
	file.store_string("this is not json {{{ ]]]")
	file.flush()
	file = null

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.is_error(), "Resuming unparseable bytes must be a structured error.")
	assert_equal(resume.error_code, &"save_parse_failed", "Unparseable save must use the save_parse_failed code.")
	_assert_no_partial_state(resume, "save_parse_failed")
	_cleanup()


# AC2 (c): unsupported schema_version -> unsupported_save_schema, no partial state.
func _resume_unsupported_schema_fails_structured() -> void:
	_cleanup()
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	assert_true(file != null, "Should be able to write a future-schema save.")
	file.store_string(JSON.stringify({
		"schema_version": RunSnapshot.SCHEMA_VERSION + 1,
		"content_version": "future"
	}))
	file.flush()
	file = null

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.is_error(), "Resuming an unsupported schema must be a structured error.")
	assert_equal(resume.error_code, &"unsupported_save_schema", "Future-schema save must use the unsupported_save_schema code.")
	_assert_no_partial_state(resume, "unsupported_save_schema")
	_cleanup()


# AC2 (d): valid run shell but corrupt embedded tactical payload -> invalid_tactical_snapshot,
# no partial state. Mirrors test_run_snapshot.gd's corruption technique.
func _resume_corrupt_embedded_tactical_fails_structured_no_partial_state() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(7)
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	# Corrupt the embedded tactical board: occupant referencing no entity.
	var corrupt_embedded: Dictionary = snapshot.level_state.get(RunSnapshot.TACTICAL_SNAPSHOT_KEY).duplicate(true)
	var cells: Array = corrupt_embedded.get("board").get("cells")
	cells[0]["occupant_id"] = "ghost_that_does_not_exist"
	snapshot.level_state[RunSnapshot.TACTICAL_SNAPSHOT_KEY] = corrupt_embedded

	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Corrupt-tactical save should still write (run-level shell is valid).")

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.is_error(), "A corrupt embedded tactical payload must fail resume.")
	assert_equal(resume.error_code, &"invalid_tactical_snapshot", "Corrupt embedded tactical payload must surface invalid_tactical_snapshot.")
	_assert_no_partial_state(resume, "invalid_tactical_snapshot")
	_cleanup()


# AC2 (e): valid run shell but malformed rng_streams -> invalid_rng_snapshot, no partial state.
func _resume_malformed_rng_fails_structured_no_partial_state() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(11)
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	# Malform the run-level rng_streams (drop a required stream) while keeping the embedded
	# tactical payload valid, so the failure is isolated to the run-level RNG restore step.
	var broken_rng: Dictionary = snapshot.rng_streams.duplicate(true)
	var broken_streams: Dictionary = broken_rng.get("streams")
	broken_streams.erase(String(RngStreamSet.STREAM_COMBAT))
	snapshot.rng_streams = broken_rng

	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Malformed-RNG save should still write (run-level parse is lenient).")

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.is_error(), "A malformed run-level rng_streams must fail resume.")
	assert_equal(resume.error_code, &"invalid_rng_snapshot", "Malformed RNG must surface invalid_rng_snapshot.")
	_assert_no_partial_state(resume, "invalid_rng_snapshot")
	_cleanup()


# AC2: reads never write — the original save file is intact (byte-for-byte) after a failed read.
func _resume_failed_read_leaves_original_save_intact() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(99)
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	# Corrupt the embedded tactical so resume fails AFTER opening the file.
	var corrupt_embedded: Dictionary = snapshot.level_state.get(RunSnapshot.TACTICAL_SNAPSHOT_KEY).duplicate(true)
	var cells: Array = corrupt_embedded.get("board").get("cells")
	cells[0]["occupant_id"] = "ghost_that_does_not_exist"
	snapshot.level_state[RunSnapshot.TACTICAL_SNAPSHOT_KEY] = corrupt_embedded
	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Setup save should write.")

	var before_file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var before_bytes: String = before_file.get_as_text()
	before_file = null

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.is_error(), "Setup resume should fail on the corrupt embedded tactical payload.")

	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "A failed read must not delete the original save file.")
	var after_file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var after_bytes: String = after_file.get_as_text()
	after_file = null
	assert_equal(after_bytes, before_bytes, "A failed read must leave the original save file byte-for-byte intact.")
	_cleanup()


# AC3: mid-level feasibility — a save taken at an arbitrary mid-turn boundary round-trips fog
# (visible/explored), entities (positions/HP/occupancy), pending turn state (mid-turn turn_state
# + non-empty pending_telegraphs), RNG stream state, and event log faithfully through resume.
func _resume_restores_mid_level_fog_entities_pending_turn_and_rng() -> void:
	_cleanup()
	# Build a realistic mid-combat state: partial fog, a damaged enemy, a mid-turn phase.
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	# Partial fog: hero cell + an adjacent cell visible, a remembered (explored-not-visible) cell.
	board.get_cell(Vector2i(0, 2)).visible = true
	board.get_cell(Vector2i(0, 2)).explored = true
	board.get_cell(Vector2i(1, 2)).visible = true
	board.get_cell(Vector2i(1, 2)).explored = true
	board.get_cell(Vector2i(2, 2)).explored = true # remembered, not currently visible
	# Mid-combat HP: damage the iron cultist to a partial value via a validated DAMAGE_APPLIED
	# event. The fixture board's next_sequence_id is 2 (BOARD_CREATED consumed sequence 1), so the
	# damage event is sequence 2; this both mutates board HP and provides a non-empty event log.
	var damage_event: DomainEvent = DomainEvent.damage_applied(
		2, &"hero", &"enemy_iron", 4, 10, 6, 10, _damage_payload()
	)
	assert_true(board.apply_event(damage_event).succeeded, "Setup damage event should apply, leaving enemy at partial HP.")

	var source_board_snapshot: Dictionary = board.to_snapshot()

	var streams: RngStreamSet = RngStreamSet.new(31337)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 20, {"system": "combat"})
	# Mid-turn turn state (player phase, mid-action) — an arbitrary turn boundary, not a clean exit.
	var turn_state: Dictionary = {"turn_number": 3, "active_actor_id": "hero", "phase": "player_action", "actions_remaining": 1}
	var pending_telegraphs: Array[Dictionary] = [{
		"telegraph_id": "ash_seer_mark:enemy_seer:5",
		"kind": "ash_seer_mark",
		"source_entity_id": "enemy_seer",
		"target_entity_id": "hero",
		"marked_cell": {"x": 0, "y": 2},
		"due_turn_number": 5,
		"status": "pending"
	}]
	var events: Array[DomainEvent] = [damage_event]

	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {
		"current_route_node_id": "level-1-midturn",
		"turn_state": turn_state,
		"pending_telegraphs": pending_telegraphs,
		"event_log": events
	})
	assert_true(compose_result.succeeded, "Mid-level composition should succeed: %s" % compose_result.metadata)
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Mid-level save should write through SaveRepository.")

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.succeeded, "Resuming a mid-level save should succeed: %s" % resume.metadata)
	var restored_board: BoardState = resume.metadata.get("board")
	var restored_tactical: TacticalSnapshot = resume.metadata.get("tactical_snapshot")

	# (1) Fog: visible/explored flags survive faithfully (whole-board snapshot equality covers it).
	assert_equal(restored_board.to_snapshot(), source_board_snapshot, "Mid-level restore must preserve the whole board incl. fog flags and occupancy.")
	assert_true(restored_board.get_cell(Vector2i(1, 2)).visible, "Mid-level restore must preserve a visible fog cell.")
	assert_true(restored_board.get_cell(Vector2i(2, 2)).explored, "Mid-level restore must preserve a remembered (explored) fog cell.")
	assert_false(restored_board.get_cell(Vector2i(2, 2)).visible, "Mid-level restore must preserve a remembered-not-visible fog cell.")

	# (2) Entities: damaged enemy HP + occupancy survive.
	var restored_enemy: TacticalEntityState = restored_board.get_entity(&"enemy_iron")
	assert_true(restored_enemy != null, "Mid-level restore must preserve entities.")
	assert_equal(restored_enemy.current_hp, 6, "Mid-level restore must preserve mid-combat HP.")
	assert_equal(restored_enemy.position, Vector2i(3, 2), "Mid-level restore must preserve entity position/occupancy.")

	# (3) Pending turn state: mid-turn turn_state + non-empty pending_telegraphs survive.
	assert_equal(restored_tactical.turn_state.get("phase"), "player_action", "Mid-level restore must preserve a mid-turn phase.")
	assert_equal(restored_tactical.turn_state.get("actions_remaining"), 1, "Mid-level restore must preserve mid-turn turn fields.")
	assert_equal(restored_tactical.pending_telegraphs.size(), 1, "Mid-level restore must preserve pending telegraphs.")
	assert_equal(restored_tactical.pending_telegraphs[0].get("due_turn_number"), 5, "Mid-level restore must preserve telegraph timing.")

	# (4) RNG stream state: restored run-level streams reproduce the exact next draw.
	var restored_streams: RngStreamSet = resume.metadata.get("rng_streams")
	var live_next: ActionResult = streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 1000000, {"system": "combat", "consumer": "midlevel_check"})
	var restored_next: ActionResult = restored_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 1000000, {"system": "combat", "consumer": "midlevel_check"})
	assert_equal(restored_next.metadata.get("value"), live_next.metadata.get("value"), "Mid-level restore must reproduce the exact next combat RNG draw.")

	# (5) Event log: the mid-combat event log survives.
	assert_equal(restored_tactical.event_log.size(), 1, "Mid-level restore must preserve the event log.")
	assert_equal(restored_tactical.event_log[0].get("event_id"), "damage_applied", "Mid-level restore must preserve event log ordering/content.")
	_cleanup()


# The thin SaveManager.resume_run autoload delegation returns the service's structured result
# UNCHANGED (no restore logic of its own). Verified for both the success and a failure path.
func _save_manager_resume_run_delegates_to_service() -> void:
	_cleanup()
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	var streams: RngStreamSet = RngStreamSet.new(20260614)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {"current_route_node_id": "delegation"})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	assert_true(SaveRepository.new().write_run_snapshot(snapshot, TEST_SAVE_PATH).succeeded, "Save should write for delegation check.")

	var manager: Node = SaveManager.new()
	var via_manager: ActionResult = manager.resume_run(TEST_SAVE_PATH)
	assert_true(via_manager.succeeded, "SaveManager.resume_run should delegate a successful resume.")
	assert_true(via_manager.metadata.has("board"), "Delegated resume must carry the restored board.")
	assert_true(via_manager.metadata.get("board") is BoardState, "Delegated resume board must be a BoardState domain object.")

	# Failure path: missing file surfaces the same structured error a direct service call would.
	_cleanup()
	var missing: ActionResult = manager.resume_run(TEST_SAVE_PATH)
	assert_true(missing.is_error(), "SaveManager.resume_run must surface a structured error for a missing save.")
	assert_equal(missing.error_code, &"save_not_found", "Delegated resume must preserve the stable error code.")
	manager.free()
	_cleanup()


# GameSession.restore_rng_snapshot must preserve a full-range (>2^53) root_seed that arrives as the
# decimal-string encoding RngStreamSet.to_snapshot() now emits — the int64-string contract Story
# 2.7 established. A raw int(...) cast on the string field would regress this; reading the value
# try_restore decoded keeps it lossless.
func _game_session_restore_preserves_full_int64_root_seed() -> void:
	var big_seed: int = 9223372036854775000
	var streams: RngStreamSet = RngStreamSet.new(big_seed)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	# Round-trip the snapshot through real JSON so root_seed arrives as a decimal string.
	var json_snapshot: Variant = JSON.parse_string(JSON.stringify(streams.to_snapshot()))
	assert_true(json_snapshot is Dictionary, "RNG snapshot should survive JSON for the GameSession check.")

	var session: Node = GameSession.new()
	var restore_result: ActionResult = session.restore_rng_snapshot(json_snapshot)
	assert_true(restore_result.succeeded, "GameSession should restore an int64-string RNG snapshot: %s" % restore_result.metadata)
	assert_equal(session.get_root_seed(), big_seed, "GameSession must preserve a full int64 root_seed (no >2^53 truncation).")
	session.free()


# A failed resume must expose no usable restored domain state and must carry diagnostic metadata.
func _assert_no_partial_state(resume: ActionResult, label: String) -> void:
	assert_false(resume.metadata.has("board"), "Failed resume (%s) must not expose a restored board." % label)
	assert_false(resume.metadata.has("rng_streams"), "Failed resume (%s) must not expose restored rng_streams." % label)
	assert_false(resume.metadata.has("tactical_snapshot"), "Failed resume (%s) must not expose a restored tactical snapshot." % label)
	assert_false(resume.metadata.has("run_snapshot"), "Failed resume (%s) must not expose a restored run snapshot." % label)
	assert_false(resume.metadata.is_empty(), "Failed resume (%s) must carry diagnostic metadata." % label)


func _damage_payload() -> Dictionary:
	return {
		"base_damage": 4,
		"support_bonus_damage": 0,
		"armor_reduction": 0,
		"block_succeeded": false,
		"damage_type": "physical",
		"weapon_id": "practice_blade",
		"rng_draws": []
	}


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
