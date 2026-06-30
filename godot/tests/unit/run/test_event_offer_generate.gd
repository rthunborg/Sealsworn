extends "res://tests/unit/test_case.gd"

# Story 7.3 Task 3 — the event GENERATE path (RunOrchestrator.generate_event_offer): the FIRST live `events`-stream
# consumer. Pins:
#   - GENERATE draws a DETERMINISTIC offer through the RUN-LEVEL RngStreamSet on the named `events` stream
#     (metadata.stream_name == "events"; the offer is stored on RunState as `pending`; an event_offered event is
#     emitted; the sequence counter advances);
#   - NAMED-STREAM ISOLATION (the 7.1 retro caution): ONLY the `events` stream advances its draw_index — rewards / loot /
#     map / level / combat / cosmetic stay at 0 (the event offer must NOT perturb any other stream);
#   - SAME seed reproduces a byte-identical offer; a DIFFERENT seed can diverge (the draw keys off the stream);
#   - the run-level `events` stream ADVANCED + a route-position save persists the advanced stream (interrupted ==
#     uninterrupted once RNG advances mid-run);
#   - an unknown event id fails closed (no fabricated offer); a generate while an event offer is still pending fails
#     closed (no silently-dropped offer); an explicit baseline id presents THAT event.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

const SAVE_PATH := "user://test_event_offer_generate_save.json"
const SEED_SAMPLE: Array[int] = [1, 7, 42, 99, 2026]

func run() -> Dictionary:
	_generate_draws_a_deterministic_offer_through_the_events_stream()
	_generate_advances_only_the_events_stream()
	_same_seed_reproduces_a_byte_identical_offer()
	_explicit_event_id_presents_that_event()
	_generate_advances_the_run_level_stream_and_route_position_save_persists_it()
	_unknown_event_fails_closed()
	_generate_while_an_offer_is_pending_fails_closed()
	_cleanup()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _started(seed_value: int) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(seed_value, false).succeeded, "Seed %d: start should succeed." % seed_value)
	return orchestrator


func _write_through_repository(snapshot: RunSnapshot) -> void:
	var write_result: ActionResult = SaveRepository.new().write_run_snapshot(snapshot, SAVE_PATH)
	assert_true(write_result.succeeded, "Writing the route-position snapshot should succeed: %s" % write_result.metadata)


func _draw_index_for(orchestrator: RunOrchestrator, stream_name: String) -> int:
	var snapshot: Dictionary = orchestrator.streams.to_snapshot()
	var stream: Dictionary = (snapshot.get("streams") as Dictionary).get(stream_name)
	return int(stream.get("draw_index"))


# ---- AC1: deterministic generate through the events stream ---------------------------------------

func _generate_draws_a_deterministic_offer_through_the_events_stream() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	var generate: ActionResult = orchestrator.generate_event_offer()
	assert_true(generate.succeeded, "Generating an event offer should succeed: %s" % generate.metadata)
	# The draw used the named events stream.
	assert_equal(String(generate.metadata.get("stream_name")), "events", "The event draw must use the named events stream.")
	# The offer is stored on RunState as pending.
	assert_true(orchestrator.run.pending_event_offer != null, "The generated offer must be stored on RunState.")
	assert_true(orchestrator.run.pending_event_offer.is_pending(), "The stored offer must be pending.")
	# The offered event is a real baseline event id, and the offered choice ids match its definition.
	var offered_event_id: StringName = orchestrator.run.pending_event_offer.event_id
	assert_true(EventRepository.BASELINE_EVENT_IDS.has(offered_event_id), "The offered event must be a real baseline event id.")
	assert_true(orchestrator.run.pending_event_offer.offered_choice_ids.size() >= 1, "The offer must carry the event's choice ids.")
	assert_equal(String(orchestrator.run.pending_event_offer.stream_name), "events", "The stored offer records the events stream.")
	# An event_offered event was emitted + is payload-valid.
	assert_equal(generate.events.size(), 1, "Generating an event offer emits exactly one event.")
	assert_equal(generate.events[0].event_type, DomainEvent.Type.EVENT_OFFERED, "The emitted event should be event_offered.")
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(generate.events[0].to_dictionary())))
	assert_true(parsed.succeeded, "The emitted event_offered event should pass payload validation: %s" % parsed.metadata)


func _generate_advances_only_the_events_stream() -> void:
	# NAMED-STREAM ISOLATION (the 7.1 retro caution): the event offer draws the `events` stream ONLY — every other
	# stream stays at draw_index 0 (the event offer must NOT perturb rewards/loot/map/level/combat/cosmetic). This is
	# the load-bearing proof the FIRST `events` consumer is correctly isolated.
	var orchestrator: RunOrchestrator = _started(2026)
	for stream_name: String in ["events", "rewards", "loot", "map", "level", "combat", "cosmetic"]:
		assert_equal(_draw_index_for(orchestrator, stream_name), 0, "Setup: the %s stream starts at draw_index 0." % stream_name)
	assert_true(orchestrator.generate_event_offer().succeeded, "The event generate should succeed.")
	# ONLY the events stream advanced.
	assert_equal(_draw_index_for(orchestrator, "events"), 1, "The event offer must ADVANCE the events stream (draw_index 0 -> 1).")
	for other_stream: String in ["rewards", "loot", "map", "level", "combat", "cosmetic"]:
		assert_equal(_draw_index_for(orchestrator, other_stream), 0, "The event offer must NOT advance the %s stream (named-stream isolation)." % other_stream)


func _same_seed_reproduces_a_byte_identical_offer() -> void:
	for seed_value: int in SEED_SAMPLE:
		var a: RunOrchestrator = _started(seed_value)
		var b: RunOrchestrator = _started(seed_value)
		assert_true(a.generate_event_offer().succeeded, "Seed %d: offer A should generate." % seed_value)
		assert_true(b.generate_event_offer().succeeded, "Seed %d: offer B should generate." % seed_value)
		assert_equal(
			JSON.stringify(a.run.pending_event_offer.to_dictionary()),
			JSON.stringify(b.run.pending_event_offer.to_dictionary()),
			"Seed %d: the same seed + same pre-draw state must reproduce a byte-identical event offer." % seed_value
		)


func _explicit_event_id_presents_that_event() -> void:
	# When the caller supplies a specific baseline event id, the offer presents THAT event (the draw still advances the
	# events stream for reproducible provenance).
	var orchestrator: RunOrchestrator = _started(42)
	var generate: ActionResult = orchestrator.generate_event_offer(&"corrupting_reforge")
	assert_true(generate.succeeded, "Generating a specific event offer should succeed: %s" % generate.metadata)
	assert_equal(orchestrator.run.pending_event_offer.event_id, &"corrupting_reforge", "An explicit event id presents that exact event.")
	# The events stream still advanced (a single-candidate roll still draws).
	assert_equal(_draw_index_for(orchestrator, "events"), 1, "An explicit-id offer still advances the events stream.")


# ---- the run-level stream advances + the route-position save persists it --------------------------

func _generate_advances_the_run_level_stream_and_route_position_save_persists_it() -> void:
	var orchestrator: RunOrchestrator = _started(2026)
	assert_equal(_draw_index_for(orchestrator, "events"), 0, "Setup: the events stream starts at draw_index 0 (inert before 7.3).")
	assert_true(orchestrator.generate_event_offer().succeeded, "The event generate should succeed for the persistence proof.")
	assert_equal(_draw_index_for(orchestrator, "events"), 1, "The event draw must ADVANCE the run-level events stream.")

	# Peek the LIVE post-draw next events draw from a restored copy (so the live streams stay untouched).
	var post_snapshot: Dictionary = orchestrator.streams.to_snapshot()
	var expected_streams: RngStreamSet = RngStreamSet.new(0)
	assert_true(expected_streams.try_restore(post_snapshot).succeeded, "The post-draw snapshot should restore for the expected-draw peek.")
	var expected_draw: ActionResult = expected_streams.rand_int(RngStreamSet.STREAM_EVENTS, 0, 1000000, {})
	assert_true(expected_draw.succeeded, "The expected next events draw should succeed.")

	# Compose the route-position snapshot AFTER the event draw, write + read it through the REAL repository, and assert
	# the restored run-level streams reproduce the EXACT next events draw (the advanced stream round-trips).
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	assert_true(snapshot != null, "compose_route_position_snapshot should return a snapshot after an event draw.")
	_write_through_repository(snapshot)
	var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(restore.succeeded, "Resuming the post-event-draw route position should succeed: %s" % restore.metadata)
	var restored_streams: RngStreamSet = restore.metadata.get("rng_streams") as RngStreamSet
	assert_true(restored_streams != null, "The route-position resume should return restored RNG streams.")
	var restored_draw: ActionResult = restored_streams.rand_int(RngStreamSet.STREAM_EVENTS, 0, 1000000, {})
	assert_true(restored_draw.succeeded, "The restored next events draw should succeed.")
	assert_equal(restored_draw.metadata.get("value"), expected_draw.metadata.get("value"), "The restored run-level streams must reproduce the EXACT next EVENTS draw — the route-position save persists the stream the event roll advanced.")


# ---- fail-closed ---------------------------------------------------------------------------------

func _unknown_event_fails_closed() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	var rejected: ActionResult = orchestrator.generate_event_offer(&"does_not_exist")
	assert_true(rejected.is_error(), "Generating from an unknown event id must fail closed.")
	assert_equal(rejected.error_code, &"unknown_event", "An unknown event should use the stable unknown_event code.")
	assert_true(orchestrator.run.pending_event_offer == null, "A failed generate must store NO offer (no fabricated default).")
	assert_false(rejected.has_events(), "A failed generate must emit no event.")
	# A failed generate (an unknown id is checked BEFORE the draw) must draw NO RNG (the events stream stays at 0).
	assert_equal(_draw_index_for(orchestrator, "events"), 0, "A failed generate (unknown event, pre-draw reject) draws NO RNG.")


func _generate_while_an_offer_is_pending_fails_closed() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	assert_true(orchestrator.generate_event_offer().succeeded, "The first generate should succeed.")
	var first_event_id: StringName = orchestrator.run.pending_event_offer.event_id
	var second: ActionResult = orchestrator.generate_event_offer()
	assert_true(second.is_error(), "Generating a second offer while one is pending must fail closed (no silently-dropped offer).")
	assert_equal(second.error_code, &"event_offer_pending", "A pending-offer generate should use the stable event_offer_pending code.")
	assert_equal(orchestrator.run.pending_event_offer.event_id, first_event_id, "The first (still-pending) offer must be preserved.")


func _cleanup() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
