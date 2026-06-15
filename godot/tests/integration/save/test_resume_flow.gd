extends "res://tests/unit/test_case.gd"

# Story 2.8 AC4 — interrupted vs uninterrupted determinism.
#
# A run is saved, restored (through a REAL SaveRepository JSON write -> read), then given the same
# REMAINING command sequence. The interrupted path's final domain snapshots, event log, and
# gameplay RNG stream states must match the uninterrupted path, and any mismatch must identify the
# FIRST divergent event index or the first RNG stream whose state differs (not a bare boolean).
#
# The harness reuses existing committed actions (hand-built validated ENTITY_MOVED / DAMAGE_APPLIED
# DomainEvents applied through BoardState.apply_event) and existing RngStreamSet draws — no new
# gameplay is invented. Determinism is checked on three surfaces:
#   (1) board.to_snapshot() equality,
#   (2) the ordered applied-event log equality,
#   (3) RNG to_snapshot() equality AND the next-draw reproduction check (for run-level AND embedded
#       tactical streams — the embedded check closes a Story 2.7 deferred item).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

const TEST_SAVE_PATH := "user://test_resume_flow.json"

func run() -> Dictionary:
	_interrupted_path_matches_uninterrupted_path()
	_embedded_tactical_streams_reproduce_next_draw_after_resume()
	_divergence_helper_names_first_divergent_event()
	_divergence_helper_names_first_divergent_rng_stream()
	_cleanup()
	return result()


# AC4 core: full sequence (Path A) vs save-resume-then-remainder (Path B) agree on board, events,
# and RNG state, and the restored streams reproduce the exact next draw.
func _interrupted_path_matches_uninterrupted_path() -> void:
	_cleanup()

	# ---- Path A: uninterrupted. Apply the entire fixed sequence from the initial state. ----
	var board_a: BoardState = _initial_board()
	var streams_a: RngStreamSet = RngStreamSet.new(424242)
	var events_a: Array[DomainEvent] = []
	_apply_segment_one(board_a, streams_a, events_a)
	_apply_segment_two(board_a, streams_a, events_a)

	# ---- Path B: interrupted. Apply segment one, save between-level, resume, apply segment two. ----
	var board_b: BoardState = _initial_board()
	var streams_b: RngStreamSet = RngStreamSet.new(424242)
	var events_b: Array[DomainEvent] = []
	_apply_segment_one(board_b, streams_b, events_b)

	# Take a between-level save partway and persist it through the real repository (JSON transport).
	var compose: ActionResult = RunSnapshot.from_between_level(board_b, streams_b, {
		"current_route_node_id": "ac4-midpoint",
		"turn_state": {"turn_number": 2, "active_actor_id": "hero", "phase": "player"},
		"event_log": events_b
	})
	assert_true(compose.succeeded, "AC4 between-level save should compose: %s" % compose.metadata)
	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(compose.metadata.get("snapshot"), TEST_SAVE_PATH).succeeded, "AC4 save should write through SaveRepository.")

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.succeeded, "AC4 resume should succeed: %s" % resume.metadata)
	var resumed_board: BoardState = resume.metadata.get("board")
	var resumed_streams: RngStreamSet = resume.metadata.get("rng_streams")
	# The restored event log continues the interrupted sequence (canonical dictionaries).
	var resumed_event_log: Array = (resume.metadata.get("tactical_snapshot") as TacticalSnapshot).event_log.duplicate(true)

	# Apply the IDENTICAL remaining segment to the resumed state.
	var resumed_events: Array[DomainEvent] = []
	_apply_segment_two(resumed_board, resumed_streams, resumed_events)
	for event: DomainEvent in resumed_events:
		resumed_event_log.append(event.to_dictionary())

	# (1) Board snapshot equality.
	assert_equal(resumed_board.to_snapshot(), board_a.to_snapshot(), "AC4: interrupted board must match uninterrupted board.")

	# (2) Ordered event-log equality, reported by first divergent index on mismatch.
	# Normalize BOTH logs through the same JSON round-trip: Path B's restored prefix already went
	# through JSON (numbers become doubles), while Path A's is native; comparing them on a shared
	# canonical JSON representation proves same-events-same-order-same-content without conflating an
	# int-vs-float transport artifact with a real divergence.
	var event_log_a: Array = []
	for event: DomainEvent in events_a:
		event_log_a.append(event.to_dictionary())
	var event_divergence: int = _first_divergent_event_index(_json_normalized(event_log_a), _json_normalized(resumed_event_log))
	assert_equal(event_divergence, -1, "AC4: interrupted event log must match uninterrupted event log (first divergence at index %d)." % event_divergence)
	assert_equal(resumed_event_log.size(), event_log_a.size(), "AC4: interrupted and uninterrupted event logs must be the same length.")

	# (3) RNG state equality + next-draw reproduction.
	var rng_divergence: String = _first_divergent_rng_stream(streams_a, resumed_streams)
	assert_equal(rng_divergence, "", "AC4: interrupted RNG state must match uninterrupted RNG state (first divergent stream: %s)." % rng_divergence)
	# Strongest determinism proof: both paths reproduce the same next draw on every stream.
	for stream_name: StringName in RngStreamSet.required_streams():
		var a_draw: ActionResult = streams_a.rand_int(stream_name, 1, 1000000, {"system": "ac4", "consumer": "next_draw"})
		var b_draw: ActionResult = resumed_streams.rand_int(stream_name, 1, 1000000, {"system": "ac4", "consumer": "next_draw"})
		assert_equal(b_draw.metadata.get("value"), a_draw.metadata.get("value"), "AC4: stream '%s' must reproduce the exact next draw on the interrupted path." % String(stream_name))
	_cleanup()


# Closes a Story 2.7 defer: the embedded tactical streams (not just the run-level streams) restore
# to the "reproduce exact next draw" bar, making the determinism coverage symmetric.
func _embedded_tactical_streams_reproduce_next_draw_after_resume() -> void:
	_cleanup()
	var board: BoardState = _initial_board()
	var streams: RngStreamSet = RngStreamSet.new(909090)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	streams.rand_float(RngStreamSet.STREAM_LOOT, {"system": "loot"})
	var compose: ActionResult = RunSnapshot.from_between_level(board, streams, {"current_route_node_id": "embedded-check"})
	assert_true(compose.succeeded, "Embedded-stream save should compose.")
	var repository: SaveRepository = SaveRepository.new()
	assert_true(repository.write_run_snapshot(compose.metadata.get("snapshot"), TEST_SAVE_PATH).succeeded, "Embedded-stream save should write.")

	var resume: ActionResult = RunResumeService.new().resume(TEST_SAVE_PATH)
	assert_true(resume.succeeded, "Embedded-stream resume should succeed.")
	var tactical: TacticalSnapshot = resume.metadata.get("tactical_snapshot")

	# Restore the EMBEDDED tactical streams independently and assert they reproduce the same next
	# draw as the live streams on every stream (symmetric with the run-level check).
	var embedded_streams: RngStreamSet = RngStreamSet.new(0)
	assert_true(embedded_streams.try_restore(tactical.rng_streams).succeeded, "Embedded tactical RNG must restore.")
	for stream_name: StringName in RngStreamSet.required_streams():
		var live_draw: ActionResult = streams.rand_int(stream_name, 1, 1000000, {"system": "embedded", "consumer": "next_draw"})
		var embedded_draw: ActionResult = embedded_streams.rand_int(stream_name, 1, 1000000, {"system": "embedded", "consumer": "next_draw"})
		assert_equal(embedded_draw.metadata.get("value"), live_draw.metadata.get("value"), "Embedded tactical stream '%s' must reproduce the exact next draw after resume." % String(stream_name))
	_cleanup()


# Prove the first-divergence event helper actually NAMES the first differing index (AC4 requires
# more than a bare boolean — a deliberately induced mismatch must be located).
func _divergence_helper_names_first_divergent_event() -> void:
	var board: BoardState = _initial_board()
	var streams: RngStreamSet = RngStreamSet.new(1)
	var events_full: Array[DomainEvent] = []
	_apply_segment_one(board, streams, events_full)
	_apply_segment_two(board, streams, events_full)

	var log_full: Array = []
	for event: DomainEvent in events_full:
		log_full.append(event.to_dictionary())
	# Identical logs: no divergence.
	assert_equal(_first_divergent_event_index(log_full, log_full.duplicate(true)), -1, "Identical event logs must report no divergence (-1).")
	# Truncated remainder: the first missing index is the divergence point.
	var truncated: Array = log_full.duplicate(true)
	truncated.remove_at(truncated.size() - 1)
	assert_equal(_first_divergent_event_index(log_full, truncated), log_full.size() - 1, "A missing trailing event must be reported at its index.")
	# Mutated middle entry: the divergence is the first differing index.
	var mutated: Array = log_full.duplicate(true)
	mutated[0] = {"event_id": "enemy_waited", "sequence_id": 999, "actor_id": "ghost", "payload": {}}
	assert_equal(_first_divergent_event_index(log_full, mutated), 0, "A mutated first event must be reported at index 0.")


# Prove the first-divergence RNG helper actually NAMES the first differing stream.
func _divergence_helper_names_first_divergent_rng_stream() -> void:
	var streams_a: RngStreamSet = RngStreamSet.new(7777)
	var streams_b: RngStreamSet = RngStreamSet.new(7777)
	# Identical streams: no divergence.
	assert_equal(_first_divergent_rng_stream(streams_a, streams_b), "", "Identical RNG sets must report no divergent stream.")
	# Advance one stream on B only: that stream must be named as the first divergence.
	streams_b.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "divergence"})
	assert_equal(_first_divergent_rng_stream(streams_a, streams_b), String(RngStreamSet.STREAM_COMBAT), "An advanced stream must be named as the first divergent stream.")


# ---- Deterministic sequence segments (committed DomainEvents + RNG draws). ----
# The fixture board's next_sequence_id is 2 after _new_board (the CreateBoardCommand BOARD_CREATED
# event consumed sequence 1), so events start at the board's reported next_sequence_id — read it
# dynamically via board.next_sequence_id() rather than hardcoding the value.

func _apply_segment_one(board: BoardState, streams: RngStreamSet, log: Array[DomainEvent]) -> void:
	# Move hero (0,0) -> (1,0): a single orthogonal step, cost 1, budget 3.
	var move_event: DomainEvent = DomainEvent.entity_moved(
		board.next_sequence_id(), &"hero", board.get_entity(&"hero").position, Vector2i(1, 0), 1, 3
	)
	assert_true(board.apply_event(move_event).succeeded, "Segment one move must apply.")
	log.append(move_event)
	# One combat draw + one map draw (gameplay RNG advances independently of board state).
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 20, {"system": "combat", "step": "seg1"})
	streams.rand_int(RngStreamSet.STREAM_MAP, 1, 6, {"system": "map", "step": "seg1"})


func _apply_segment_two(board: BoardState, streams: RngStreamSet, log: Array[DomainEvent]) -> void:
	# Move hero (1,0) -> (2,0): another single orthogonal step.
	var move_event: DomainEvent = DomainEvent.entity_moved(
		board.next_sequence_id(), &"hero", board.get_entity(&"hero").position, Vector2i(2, 0), 1, 3
	)
	assert_true(board.apply_event(move_event).succeeded, "Segment two move must apply.")
	log.append(move_event)
	# Two further draws on different streams.
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 20, {"system": "combat", "step": "seg2"})
	streams.rand_float(RngStreamSet.STREAM_LOOT, {"system": "loot", "step": "seg2"})


func _initial_board() -> BoardState:
	return BoardFixtureFactory.edge_corner_movement()


# Normalize an array of event dictionaries through a single JSON round-trip so two logs are
# compared on the same representation (JSON coerces all numbers to doubles). Pure; mutates nothing.
func _json_normalized(log: Array) -> Array:
	var parsed: Variant = JSON.parse_string(JSON.stringify(log))
	if parsed is Array:
		return parsed
	return []


# Returns the index of the FIRST differing event, or -1 if the common prefix matches and lengths
# are equal. A length mismatch is reported at the first index that exists in only one log.
func _first_divergent_event_index(expected_log: Array, actual_log: Array) -> int:
	var common: int = min(expected_log.size(), actual_log.size())
	for index: int in range(common):
		if expected_log[index] != actual_log[index]:
			return index
	if expected_log.size() != actual_log.size():
		return common
	return -1


# Returns the name of the FIRST stream (in required_streams() order) whose snapshot state differs,
# or "" if all stream states match. Compares the per-stream serialized state + draw_index.
func _first_divergent_rng_stream(expected: RngStreamSet, actual: RngStreamSet) -> String:
	var expected_streams: Dictionary = expected.to_snapshot().get("streams", {})
	var actual_streams: Dictionary = actual.to_snapshot().get("streams", {})
	for stream_name: StringName in RngStreamSet.required_streams():
		var key: String = String(stream_name)
		if expected_streams.get(key) != actual_streams.get(key):
			return key
	return ""


func _cleanup() -> void:
	for path: String in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH, "%s.bak" % TEST_SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
