extends "res://tests/unit/test_case.gd"

# Story 8.5 Tasks 2/4 (AC1): the RecordFirstDeathCommand — the first-death LATCH behind the run-end seam. A FIRST death on
# a FAILED run SETS first_death_recorded + emits the first_death_recorded event + round-trips through ProfileRepository at
# SCHEMA_VERSION == 1 (no migration); a SECOND death is a no-op reject (first_death_already_recorded, profile byte-identical,
# ZERO event — AC1 "not repeated as a first-death event"); a COMPLETED run rejects (run_not_failed, ZERO mutation — the
# death-only gate, the discriminator vs the Epic-9 first-VICTORY reveal); a non-terminal / invalid-context / bad-sequence-id
# run rejects with ZERO mutation; on ANY reject the profile + run are byte-identical (the 4.3 no-mutation-on-reject
# guarantee). The ELIGIBILITY DECISION (Option A): a manual-seed FAILED first death STILL sets the flag + emits (the line is
# narrative flavor, not meta progression — it is NOT gated on eligibility). The command draws ZERO RNG. The first-death
# latch is INDEPENDENT of the award/merge seed markers (any caller order is safe).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RecordFirstDeathCommand = preload("res://scripts/core/commands/record_first_death_command.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

const TEST_PROFILE_PATH := "user://test_first_death_profile.json"

func run() -> Dictionary:
	_first_death_on_failed_run_sets_flag_and_emits_event()
	_first_death_round_trips_through_the_repository()
	_second_death_is_a_no_op_reject_flag_and_line_not_repeated()
	_completed_run_rejects_death_only_gate()
	_non_terminal_run_rejects_with_zero_mutation()
	_invalid_context_is_rejected()
	_invalid_sequence_id_is_rejected()
	_reject_leaves_profile_and_run_byte_identical()
	_manual_seed_first_death_still_records_option_a()
	_first_death_independent_of_award_and_merge_markers()
	_cleanup()
	return result()


func _first_death_on_failed_run_sets_flag_and_emits_event() -> void:
	# A FIRST death on a FAILED run SETS the first_death_recorded latch + emits exactly one first_death_recorded event
	# carrying the line-by-id + the skippable flag + the profile id.
	var run: RunState = _failed_run(2, 4242, false)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	assert_false(profile.first_death_recorded, "Setup: a fresh profile has NOT recorded a first death.")

	var death_result: ActionResult = RecordFirstDeathCommand.new(profile, 7).execute(run)

	assert_true(death_result.succeeded, "A first death on a FAILED run should record: %s" % death_result.metadata)
	assert_true(profile.first_death_recorded, "The first-death latch must be SET on the first death.")
	assert_equal(death_result.metadata.get("line_id"), String(DomainEvent.FIRST_DEATH_LINE_ID), "The result must carry the line-by-id.")
	assert_equal(death_result.metadata.get("is_skippable"), true, "The result must mark the beat skippable (FR65).")
	assert_equal(death_result.metadata.get("profile_id"), "default", "The result must carry the profile id.")

	# Exactly one first_death_recorded event, self-consistent + round-trippable.
	assert_equal(death_result.events.size(), 1, "Exactly one first_death_recorded event should be emitted.")
	var event: DomainEvent = death_result.events[0]
	assert_equal(event.event_type, DomainEvent.Type.FIRST_DEATH_RECORDED, "The emitted event must be first_death_recorded.")
	assert_equal(String(event.payload.get("line_id")), String(DomainEvent.FIRST_DEATH_LINE_ID), "The event must carry the line-by-id (NOT the raw prose).")
	assert_equal(bool(event.payload.get("is_skippable")), true, "The event must carry the skippable flag.")
	assert_equal(String(event.payload.get("profile_id")), "default", "The event must carry the profile id.")
	# ZERO RNG: a recorded flag, not a roll — no roll/draw_index on the payload.
	assert_false(event.payload.has("roll"), "first_death_recorded must NOT carry a roll (ZERO RNG).")
	assert_false(event.payload.has("draw_index"), "first_death_recorded must NOT carry a draw_index (ZERO RNG).")
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parse_result.succeeded, "The emitted first-death event must be a valid round-trippable domain event: %s" % parse_result.metadata)


func _first_death_round_trips_through_the_repository() -> void:
	# The set first-death flag persists + reads back at SCHEMA_VERSION == 1 (Task 4 — no migration; the flag rides
	# to_dictionary() automatically; the repository is UNCHANGED).
	_cleanup()
	var run: RunState = _failed_run(2, 555, false)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var death_result: ActionResult = RecordFirstDeathCommand.new(profile, 3).execute(run)
	assert_true(death_result.succeeded, "The first-death record should succeed before persisting.")

	var repository: ProfileRepository = ProfileRepository.new()
	var write_result: ActionResult = repository.write_profile(profile, TEST_PROFILE_PATH)
	assert_true(write_result.succeeded, "The first-death profile should persist: %s" % write_result.metadata)

	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "The first-death profile should read back.")
	var restored: ProfileSnapshot = read_result.metadata.get("snapshot")
	assert_true(restored.first_death_recorded, "The persisted profile must retain the SET first-death flag.")
	# The schema is UNCHANGED (no migration — 8.5 SETS the existing home at SCHEMA_VERSION == 1).
	assert_equal(restored.schema_version, ProfileSnapshot.SCHEMA_VERSION, "The first-death record must NOT bump the schema version (no migration).")
	_cleanup()


func _second_death_is_a_no_op_reject_flag_and_line_not_repeated() -> void:
	# AC1 "the line is tracked so it is not repeated as a first-death event": a SECOND death (flag already true) is a stable
	# no-op reject — no double-mutation, ZERO second event, so the first-death line NEVER re-fires.
	var first_run: RunState = _failed_run(2, 4242, false)
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	var first: ActionResult = RecordFirstDeathCommand.new(profile, 1).execute(first_run)
	assert_true(first.succeeded, "The first death should record.")
	var profile_after_first: Dictionary = profile.to_dictionary()

	# A SECOND death (a DIFFERENT later run) must NOT re-record — the latch is per-PROFILE-lifetime, not per-run.
	var second_run: RunState = _failed_run(3, 9999, false)
	var second: ActionResult = RecordFirstDeathCommand.new(profile, 2).execute(second_run)
	assert_true(second.is_error(), "A subsequent death must be rejected (the first-death line is not repeated).")
	assert_equal(second.error_code, &"first_death_already_recorded", "A subsequent death must reject with the stable once-only code.")
	assert_false(second.has_events(), "A subsequent death must emit NO second first-death event (the line is not repeated).")
	assert_equal(profile.to_dictionary(), profile_after_first, "A subsequent death must leave the profile byte-identical (no double-mutation).")


func _completed_run_rejects_death_only_gate() -> void:
	# DEATH-ONLY GATE (AC1): a COMPLETED run (a victory) is NOT a first death — reject with run_not_failed + ZERO mutation.
	# This is the discriminator vs the Epic-9 first-VICTORY reveal (which keys off the completed phase).
	var run: RunState = _completed_run(2, 4242, false)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var profile_before: Dictionary = profile.to_dictionary()

	var death_result: ActionResult = RecordFirstDeathCommand.new(profile, 2).execute(run)

	assert_true(death_result.is_error(), "A COMPLETED (victory) run must be rejected (a victory is not a first death).")
	assert_equal(death_result.error_code, &"run_not_failed", "A completed run must reject with the stable death-only code.")
	assert_false(death_result.has_events(), "A completed run must emit NO first-death event.")
	assert_equal(profile.to_dictionary(), profile_before, "A completed run must leave the profile byte-identical.")
	assert_false(profile.first_death_recorded, "A completed run must NOT set the first-death flag.")


func _non_terminal_run_rejects_with_zero_mutation() -> void:
	# A non-terminal run (still active) has no first-death record — reject with ZERO mutation.
	var route: RouteState = _cleared_route(2)
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var profile_before: Dictionary = profile.to_dictionary()

	var death_result: ActionResult = RecordFirstDeathCommand.new(profile, 2).execute(run)

	assert_true(death_result.is_error(), "A non-terminal run must be rejected.")
	assert_equal(death_result.error_code, &"run_not_terminal", "A non-terminal run must reject with the stable code.")
	assert_false(death_result.has_events(), "A non-terminal run must emit NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "A non-terminal run must leave the profile byte-identical.")


func _invalid_context_is_rejected() -> void:
	# A null profile and a non-RunState state both reject with invalid_context.
	var run: RunState = _failed_run(2, 4242, false)

	var null_profile: ActionResult = RecordFirstDeathCommand.new(null, 1).execute(run)
	assert_true(null_profile.is_error(), "A null profile must be rejected.")
	assert_equal(null_profile.error_code, &"invalid_context", "A null profile must reject with invalid_context.")

	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var not_a_run: ActionResult = RecordFirstDeathCommand.new(profile, 1).execute("not-a-run")
	assert_true(not_a_run.is_error(), "A non-RunState state must be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A non-RunState state must reject with invalid_context.")
	assert_false(profile.first_death_recorded, "An invalid-context reject must NOT set the flag.")


func _invalid_sequence_id_is_rejected() -> void:
	# The 4.3 self-consistency gate: sequence_id <= 0 is rejected BEFORE any mutation.
	var run: RunState = _failed_run(2, 4242, false)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var profile_before: Dictionary = profile.to_dictionary()

	var death_result: ActionResult = RecordFirstDeathCommand.new(profile, 0).execute(run)
	assert_true(death_result.is_error(), "A non-positive sequence id must be rejected.")
	assert_equal(death_result.error_code, &"invalid_event_sequence_id", "A non-positive sequence id must reject with the stable code.")
	assert_equal(profile.to_dictionary(), profile_before, "A sequence-id reject must leave the profile byte-identical.")
	assert_false(profile.first_death_recorded, "A sequence-id reject must NOT set the flag.")


func _reject_leaves_profile_and_run_byte_identical() -> void:
	# The 4.3 no-mutation-on-reject guarantee: on ANY reject the run AND the profile are byte-identical. Here a COMPLETED
	# run (rejects at the death-only gate) with a non-trivial profile.
	var run: RunState = _completed_run(2, 4242, false)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 3
	profile.echoes = ["echo_of_salt"]
	var run_before: Dictionary = run.to_dictionary()
	var profile_before: Dictionary = profile.to_dictionary()

	var death_result: ActionResult = RecordFirstDeathCommand.new(profile, 1).execute(run)
	assert_true(death_result.is_error(), "The completed run should reject at the death-only gate.")
	assert_equal(run.to_dictionary(), run_before, "A reject must leave the RunState byte-identical.")
	assert_equal(profile.to_dictionary(), profile_before, "A reject must leave the ProfileSnapshot byte-identical.")


func _manual_seed_first_death_still_records_option_a() -> void:
	# ELIGIBILITY DECISION (Option A): the first-death flag is DELIBERATELY NOT gated on eligibility. A manual-seed FAILED
	# first death STILL sets the flag + emits (the line is narrative flavor, not meta progression — FR61/FR64). This is the
	# DISCRIMINATOR from the award/merge, which DENY a manual-seed run at their FR28 gate.
	var run: RunState = _failed_run(2, 4242, true)
	assert_false(run.meta_progression_eligible, "Setup: a manual-seed run is NOT meta-progression eligible.")
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	var death_result: ActionResult = RecordFirstDeathCommand.new(profile, 2).execute(run)

	assert_true(death_result.succeeded, "A manual-seed FIRST death must STILL record (Option A — narrative flavor, not gated on eligibility).")
	assert_true(profile.first_death_recorded, "A manual-seed first death must set the latch (the line is available in a practice death).")
	assert_equal(death_result.events.size(), 1, "A manual-seed first death must STILL emit the first-death event.")
	# It grants ZERO meta progression (the latch is a narrative marker, NOT progression — it must not violate FR28).
	assert_equal(profile.oath_shards, 0, "The first-death latch must grant ZERO Oath Shards (it is a narrative marker, not progression).")
	assert_equal(profile.echoes.size(), 0, "The first-death latch must grant ZERO Echoes.")
	assert_equal(profile.unlock_progress.size(), 0, "The first-death latch must grant ZERO unlock progress.")


func _first_death_independent_of_award_and_merge_markers() -> void:
	# The THREE-MECHANISM invariant: the first-death latch is INDEPENDENT of the award's last_awarded_run_seed AND the
	# merge's unlock_progress["_last_merged_run_seed"]. A profile whose award + merge markers ALREADY match this run (both
	# ran first) still records the first death (the latch keys off the bool ITSELF, not either seed marker) — any caller
	# order is safe.
	var run: RunState = _failed_run(2, 4242, false)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.last_awarded_run_seed = str(4242)  # the award already ran for this run
	profile.unlock_progress = {"_last_merged_run_seed": str(4242)}  # the merge already ran for this run

	var death_result: ActionResult = RecordFirstDeathCommand.new(profile, 2).execute(run)
	assert_true(death_result.succeeded, "The first-death record must succeed even when the award + merge markers already match (independent markers).")
	assert_true(profile.first_death_recorded, "The first-death latch must set regardless of the award/merge seed markers.")
	# The award + merge markers are UNTOUCHED by the first-death command (it sets ONLY the bool).
	assert_equal(profile.last_awarded_run_seed, str(4242), "The first-death command must NOT touch the award's last_awarded_run_seed marker.")
	assert_equal(String(profile.unlock_progress.get("_last_merged_run_seed")), str(4242), "The first-death command must NOT touch the merge's marker.")


# ---- fixtures -----------------------------------------------------------------------------------

func _cleared_route(cleared: int) -> RouteState:
	var nodes: Array[RouteNode] = []
	var cleared_ids: Array[String] = []
	var count: int = max(cleared, 1)
	for index: int in range(count):
		var node_id: String = "node-%d" % index
		var next_ids: Array[String] = []
		if index < count - 1:
			next_ids = ["node-%d" % (index + 1)]
		nodes.append(RouteNode.new(node_id, RouteNode.TYPE_COMBAT, index, RouteNode.REVEAL_CLEARED, next_ids))
		if index < cleared:
			cleared_ids.append(node_id)
	var current_id: String = cleared_ids[cleared_ids.size() - 1] if not cleared_ids.is_empty() else ""
	return RouteState.new(nodes, current_id, cleared_ids)


func _failed_run(cleared: int, seed_value: int, is_manual_seed: bool) -> RunState:
	var run: RunState = RunState.new(RunState.PHASE_FAILED, seed_value, is_manual_seed, not is_manual_seed, _cleared_route(cleared))
	assert_true(run.validate().succeeded, "Setup: the failed run should validate.")
	assert_true(run.is_terminal(), "Setup: a failed run is terminal.")
	return run


func _completed_run(cleared: int, seed_value: int, is_manual_seed: bool) -> RunState:
	var run: RunState = RunState.new(RunState.PHASE_COMPLETED, seed_value, is_manual_seed, not is_manual_seed, _cleared_route(cleared))
	assert_true(run.validate().succeeded, "Setup: the completed run should validate.")
	return run


func _cleanup() -> void:
	for path: String in [TEST_PROFILE_PATH, "%s.tmp" % TEST_PROFILE_PATH, "%s.bak" % TEST_PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
