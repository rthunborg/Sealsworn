extends "res://tests/unit/test_case.gd"

# Story 8.4 Tasks 2/3/6 (AC1-AC3): the MergeRunDiscoveriesCommand — the two-gate discovery merge. An eligible run with
# content_discovered events MERGES echoes/seal-fragments/mastery/unlock-flags into the profile + emits the merge event +
# round-trips through the repository (AC1); a DUPLICATE-id discovery list grants each unique unlock EXACTLY once (AC1); a
# re-invocation for the same run is a no-op (idempotency — AC1); a manual-seed run merges NOTHING (profile byte-identical,
# denied at Gate 2 — AC2); a non-terminal / invalid-context / bad-sequence-id run rejects with ZERO mutation; on reject
# the profile + run are byte-identical (the 4.3 no-mutation-on-reject guarantee); a threshold crossing is recorded (AC3);
# the merge draws ZERO RNG.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MergeRunDiscoveriesCommand = preload("res://scripts/core/commands/merge_run_discoveries_command.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const UnlockProgressRules = preload("res://scripts/save/unlock_progress_rules.gd")

const TEST_PROFILE_PATH := "user://test_merge_profile.json"

func run() -> Dictionary:
	_eligible_run_merges_discoveries_and_emits_event()
	_merge_round_trips_through_the_repository()
	_duplicate_ids_grant_each_unique_unlock_once()
	_reinvocation_for_same_run_is_a_no_op()
	_manual_seed_run_merges_nothing_profile_unchanged()
	_non_terminal_run_rejects_with_zero_mutation()
	_invalid_context_is_rejected()
	_invalid_sequence_id_is_rejected()
	_reject_leaves_profile_and_run_byte_identical()
	_class_mastery_accumulates_across_runs()
	_threshold_crossing_is_recorded_in_the_merge_event()
	_merge_and_award_markers_are_independent()
	_cleanup()
	return result()


func _eligible_run_merges_discoveries_and_emits_event() -> void:
	# An eligible completed run with one Echo + one Seal Fragment + one class-mastery + one unlock-flag discovery merges
	# each into the correct profile home + emits the merge event.
	var run: RunState = _completed_run(2, 4242, false)
	var events: Array = [
		DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"}),
		DomainEvent.content_discovered(2, {"content_kind": "seal_fragment", "content_id": "seal_a"}),
		DomainEvent.content_discovered(3, {"content_kind": "class_mastery", "content_id": "warrior"}),
		DomainEvent.content_discovered(4, {"content_kind": "unlock_flag", "content_id": "variety_flag_1"})
	]
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 5).execute(run)

	assert_true(merge_result.succeeded, "An eligible run with discoveries should merge: %s" % merge_result.metadata)
	assert_true(profile.echoes.has("echo_of_salt"), "The Echo must merge into profile.echoes.")
	assert_true((profile.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY) as Array).has("seal_a"), "The Seal Fragment must merge into unlock_progress.seal_fragments.")
	assert_equal(int(profile.class_mastery.get("warrior")), 1, "The class-mastery point must merge into profile.class_mastery.")
	assert_true(bool(profile.unlock_progress.get("variety_flag_1")), "The unlock flag must merge into unlock_progress.")

	# Exactly one profile_progress_merged event, self-consistent + round-trippable.
	assert_equal(merge_result.events.size(), 1, "Exactly one profile_progress_merged event should be emitted.")
	var event: DomainEvent = merge_result.events[0]
	assert_equal(event.event_type, DomainEvent.Type.PROFILE_PROGRESS_MERGED, "The emitted event must be profile_progress_merged.")
	assert_equal((event.payload.get("added_echo_ids") as Array).size(), 1, "The event must record the newly-added Echo.")
	assert_equal((event.payload.get("added_seal_fragment_ids") as Array).size(), 1, "The event must record the newly-added Seal Fragment.")
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parse_result.succeeded, "The emitted merge event must be a valid round-trippable domain event: %s" % parse_result.metadata)


func _merge_round_trips_through_the_repository() -> void:
	# The merged profile persists + reads back with the populated homes (AC1).
	_cleanup()
	var run: RunState = _completed_run(2, 555, false)
	var events: Array = [
		DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_tide"}),
		DomainEvent.content_discovered(2, {"content_kind": "seal_fragment", "content_id": "seal_b"})
	]
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 3).execute(run)
	assert_true(merge_result.succeeded, "The merge should succeed before persisting.")

	var repository: ProfileRepository = ProfileRepository.new()
	var write_result: ActionResult = repository.write_profile(profile, TEST_PROFILE_PATH)
	assert_true(write_result.succeeded, "The merged profile should persist: %s" % write_result.metadata)

	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "The merged profile should read back.")
	var restored: ProfileSnapshot = read_result.metadata.get("snapshot")
	assert_true(restored.echoes.has("echo_of_tide"), "The persisted profile must retain the merged Echo.")
	assert_true((restored.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY) as Array).has("seal_b"), "The persisted profile must retain the merged Seal Fragment.")
	# The schema is UNCHANGED (no migration — 8.4 merges into the existing SCHEMA_VERSION == 1 shape).
	assert_equal(restored.schema_version, ProfileSnapshot.SCHEMA_VERSION, "The merge must NOT bump the schema version (no migration).")
	_cleanup()


func _duplicate_ids_grant_each_unique_unlock_once() -> void:
	# AC1 "duplicate discoveries do not grant duplicate unique unlocks": a FIRST merge with a DIRTY list (the same Echo /
	# Seal Fragment / unlock-flag id repeated) grants each unique unlock EXACTLY once.
	var run: RunState = _completed_run(2, 4242, false)
	var events: Array = [
		DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"}),
		DomainEvent.content_discovered(2, {"content_kind": "echo", "content_id": "echo_of_salt"}),
		DomainEvent.content_discovered(3, {"content_kind": "seal_fragment", "content_id": "seal_a"}),
		DomainEvent.content_discovered(4, {"content_kind": "seal_fragment", "content_id": "seal_a"}),
		DomainEvent.content_discovered(5, {"content_kind": "unlock_flag", "content_id": "variety_flag_1"}),
		DomainEvent.content_discovered(6, {"content_kind": "unlock_flag", "content_id": "variety_flag_1"})
	]
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 7).execute(run)
	assert_true(merge_result.succeeded, "A dirty-list merge should succeed.")

	# Each unique unlock is granted exactly once (SET semantics).
	assert_equal(profile.echoes.count("echo_of_salt"), 1, "A duplicate Echo id must NOT be appended twice (unique set).")
	assert_equal((profile.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY) as Array).count("seal_a"), 1, "A duplicate Seal Fragment must NOT be unlocked twice (unique set).")
	# The event records exactly one newly-added Echo / Seal Fragment / unlock flag.
	var event: DomainEvent = merge_result.events[0]
	assert_equal((event.payload.get("added_echo_ids") as Array).size(), 1, "The event records the Echo added exactly once.")
	assert_equal((event.payload.get("added_seal_fragment_ids") as Array).size(), 1, "The event records the Seal Fragment added exactly once.")
	assert_equal((event.payload.get("added_unlock_flag_ids") as Array).size(), 1, "The event records the unlock flag added exactly once.")


func _reinvocation_for_same_run_is_a_no_op() -> void:
	# AC1 idempotency: a re-invocation for the SAME already-merged run must be a stable no-op (no double-grant).
	var run: RunState = _completed_run(2, 4242, false)
	var events: Array = [DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"})]
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	var first: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 1).execute(run)
	assert_true(first.succeeded, "The first merge should succeed.")
	var profile_after_first: Dictionary = profile.to_dictionary()

	var second: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 2).execute(run)
	assert_true(second.is_error(), "A re-invocation for the same already-merged run must be rejected (no double-grant).")
	assert_equal(second.error_code, &"run_already_merged", "A re-merge must reject with the stable idempotency code.")
	assert_false(second.has_events(), "A re-merge must emit NO second event.")
	assert_equal(profile.to_dictionary(), profile_after_first, "A re-merge must leave the profile byte-identical (no double-mutation).")

	# A DIFFERENT run (different root_seed) DOES merge again (the marker is per-run, not a global lock).
	var other_run: RunState = _completed_run(2, 9999, false)
	var other_events: Array = [DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_tide"})]
	var third: ActionResult = MergeRunDiscoveriesCommand.new(profile, other_events, 3).execute(other_run)
	assert_true(third.succeeded, "A DIFFERENT run should merge again (the idempotency marker is per-run).")
	assert_true(profile.echoes.has("echo_of_tide"), "A different run's discovery must merge.")


func _manual_seed_run_merges_nothing_profile_unchanged() -> void:
	# AC2/FR28: a manual-seed run merges NOTHING — reject at Gate 2, profile byte-identical.
	var run: RunState = _completed_run(2, 4242, true)
	var events: Array = [
		DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"}),
		DomainEvent.content_discovered(2, {"content_kind": "seal_fragment", "content_id": "seal_a"})
	]
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var profile_before: Dictionary = profile.to_dictionary()

	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 3).execute(run)

	assert_true(merge_result.is_error(), "A manual-seed run must be denied (FR28/AC2).")
	assert_equal(merge_result.error_code, &"run_not_meta_eligible", "A manual-seed run must reject with the stable ineligibility code.")
	assert_false(merge_result.has_events(), "A manual-seed run must emit NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "A manual-seed run must leave the profile byte-identical (0 echoes, 0 seal fragments, 0 mastery, 0 unlock progress).")
	assert_equal(profile.echoes.size(), 0, "A manual-seed run must merge ZERO Echoes.")
	assert_equal(profile.unlock_progress.size(), 0, "A manual-seed run must merge ZERO unlock progress.")


func _non_terminal_run_rejects_with_zero_mutation() -> void:
	# A non-terminal run (still active) has no merge — reject with ZERO mutation.
	var route: RouteState = _cleared_route(2)
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	var events: Array = [DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"})]
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var profile_before: Dictionary = profile.to_dictionary()

	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 2).execute(run)

	assert_true(merge_result.is_error(), "A non-terminal run must be rejected.")
	assert_equal(merge_result.error_code, &"run_not_terminal", "A non-terminal run must reject with the stable code.")
	assert_false(merge_result.has_events(), "A non-terminal run must emit NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "A non-terminal run must leave the profile byte-identical.")


func _invalid_context_is_rejected() -> void:
	# A null profile and a non-RunState state both reject with invalid_context.
	var run: RunState = _completed_run(2, 4242, false)
	var events: Array = [DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"})]

	var null_profile: ActionResult = MergeRunDiscoveriesCommand.new(null, events, 1).execute(run)
	assert_true(null_profile.is_error(), "A null profile must be rejected.")
	assert_equal(null_profile.error_code, &"invalid_context", "A null profile must reject with invalid_context.")

	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var not_a_run: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 1).execute("not-a-run")
	assert_true(not_a_run.is_error(), "A non-RunState state must be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A non-RunState state must reject with invalid_context.")


func _invalid_sequence_id_is_rejected() -> void:
	# The 4.3 self-consistency gate: sequence_id <= 0 is rejected BEFORE any mutation.
	var run: RunState = _completed_run(2, 4242, false)
	var events: Array = [DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"})]
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var profile_before: Dictionary = profile.to_dictionary()

	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 0).execute(run)
	assert_true(merge_result.is_error(), "A non-positive sequence id must be rejected.")
	assert_equal(merge_result.error_code, &"invalid_event_sequence_id", "A non-positive sequence id must reject with the stable code.")
	assert_equal(profile.to_dictionary(), profile_before, "A sequence-id reject must leave the profile byte-identical.")


func _reject_leaves_profile_and_run_byte_identical() -> void:
	# The 4.3 no-mutation-on-reject guarantee: on ANY reject the run AND the profile are byte-identical.
	var run: RunState = _completed_run(2, 4242, true)  # manual-seed -> rejects at Gate 2
	var events: Array = [DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"})]
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 3
	var run_before: Dictionary = run.to_dictionary()
	var profile_before: Dictionary = profile.to_dictionary()

	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 1).execute(run)
	assert_true(merge_result.is_error(), "The manual-seed run should reject.")
	assert_equal(run.to_dictionary(), run_before, "A reject must leave the RunState byte-identical.")
	assert_equal(profile.to_dictionary(), profile_before, "A reject must leave the ProfileSnapshot byte-identical.")


func _class_mastery_accumulates_across_runs() -> void:
	# class-mastery is the ACCUMULATING exception (a count that rises per discovery). Two discoveries of the same class in
	# ONE run add 2; a SECOND (different) run adds more. The per-RUN merge stays idempotent via the per-invocation marker.
	var run_a: RunState = _completed_run(2, 111, false)
	var events_a: Array = [
		DomainEvent.content_discovered(1, {"content_kind": "class_mastery", "content_id": "warrior"}),
		DomainEvent.content_discovered(2, {"content_kind": "class_mastery", "content_id": "warrior"})
	]
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	MergeRunDiscoveriesCommand.new(profile, events_a, 3).execute(run_a)
	assert_equal(int(profile.class_mastery.get("warrior")), 2, "Two mastery discoveries in one run accumulate to 2.")

	var run_b: RunState = _completed_run(2, 222, false)
	var events_b: Array = [DomainEvent.content_discovered(1, {"content_kind": "class_mastery", "content_id": "warrior"})]
	MergeRunDiscoveriesCommand.new(profile, events_b, 4).execute(run_b)
	assert_equal(int(profile.class_mastery.get("warrior")), 3, "A second run's mastery discovery accumulates to 3.")


func _threshold_crossing_is_recorded_in_the_merge_event() -> void:
	# AC3: merging enough Seal Fragments to cross a declared threshold flips the unlock STATE deterministically + reports
	# the crossing in the merge event. seal_gate_1 crosses at 1 seal fragment (the first threshold).
	var run: RunState = _completed_run(2, 4242, false)
	var events: Array = [DomainEvent.content_discovered(1, {"content_kind": "seal_fragment", "content_id": "seal_a"})]
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 2).execute(run)
	assert_true(merge_result.succeeded, "The merge should succeed.")

	var event: DomainEvent = merge_result.events[0]
	var crossed: Array = event.payload.get("thresholds_crossed")
	assert_true(crossed.has("seal_gate_1"), "Crossing the 1-seal-fragment threshold must be reported in the merge event (AC3).")
	assert_true(bool(profile.unlock_progress.get("seal_gate_1_unlocked")), "The unlock STATE flag must be flipped deterministically (AC3).")


func _merge_and_award_markers_are_independent() -> void:
	# The RUN-END META STEP ORDERING invariant: the merge's idempotency marker is INDEPENDENT of the award's
	# last_awarded_run_seed, so both orders (merge-then-award / award-then-merge) work. Here we prove the merge does NOT
	# read/consume last_awarded_run_seed: a profile whose last_awarded_run_seed ALREADY equals this run's seed (the award
	# ran first) still MERGES (the merge uses its own dedicated marker).
	var run: RunState = _completed_run(2, 4242, false)
	var events: Array = [DomainEvent.content_discovered(1, {"content_kind": "echo", "content_id": "echo_of_salt"})]
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.last_awarded_run_seed = str(4242)  # the award already ran for this run

	var merge_result: ActionResult = MergeRunDiscoveriesCommand.new(profile, events, 2).execute(run)
	assert_true(merge_result.succeeded, "The merge must succeed even when the award already ran (independent markers — award-then-merge order).")
	assert_true(profile.echoes.has("echo_of_salt"), "The merge must apply even after the award set its own marker.")
	# The award's marker is UNTOUCHED by the merge (the merge sets its OWN marker inside unlock_progress).
	assert_equal(profile.last_awarded_run_seed, str(4242), "The merge must NOT touch the award's last_awarded_run_seed marker.")


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
