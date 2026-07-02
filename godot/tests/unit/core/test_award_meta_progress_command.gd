extends "res://tests/unit/test_case.gd"

# Story 8.3 Tasks 4/6/7/8 (AC1-AC5): the AwardMetaProgressCommand — the two-gate award application. An eligible completed
# run raises the profile's cross-run oath_shards + emits the meta-award event + persists (round-trip through the
# repository); a manual-seed run awards NOTHING (0 shards, no event, profile byte-identical — AC4) + the summary carries
# the replay/practice warning data; a non-terminal run rejects with ZERO mutation; a re-invocation for the same
# already-awarded run does NOT double-award (idempotency — AC1/8.1 seam); on reject the profile + run are byte-identical
# (the 4.3 no-mutation-on-reject guarantee); a failed profile write leaves the RunSummary fully readable (AC5); run /
# profile / unlock state stay separable (AC2).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AwardMetaProgressCommand = preload("res://scripts/core/commands/award_meta_progress_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MetaAwardRules = preload("res://scripts/save/meta_award_rules.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

const TEST_PROFILE_PATH := "user://test_award_profile.json"

func run() -> Dictionary:
	_eligible_completed_run_awards_updates_profile_emits_event()
	_award_round_trips_through_the_repository()
	_manual_seed_run_awards_nothing_profile_unchanged()
	_manual_seed_summary_carries_the_replay_practice_warning()
	_non_terminal_run_rejects_with_zero_mutation()
	_reinvocation_for_same_run_does_not_double_award()
	_reject_leaves_profile_and_run_byte_identical()
	_invalid_context_is_rejected()
	_invalid_sequence_id_is_rejected()
	_failed_profile_write_leaves_summary_readable()
	_run_profile_and_unlock_state_stay_separable()
	_failed_run_awards_zero_but_is_recorded_as_resolved()
	_cleanup()
	return result()


func _eligible_completed_run_awards_updates_profile_emits_event() -> void:
	# A completed 3-node run: award = min(1 + 3, 5) = 4. The profile's cross-run total rises + the event is emitted.
	var run: RunState = _completed_run(3, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 10

	var command: AwardMetaProgressCommand = AwardMetaProgressCommand.new(profile, summary, 1)
	var award_result: ActionResult = command.execute(run)

	assert_true(award_result.succeeded, "An eligible completed run should award: %s" % award_result.metadata)
	var expected_amount: int = MetaAwardRules.oath_shard_award_for(run)
	assert_equal(award_result.metadata.get("amount"), expected_amount, "The result should carry the awarded amount.")
	assert_equal(profile.oath_shards, 10 + expected_amount, "The profile's cross-run total must rise by the awarded amount.")
	assert_equal(award_result.metadata.get("oath_shards_after"), 10 + expected_amount, "oath_shards_after must match the new total.")
	assert_equal(profile.last_awarded_run_seed, "4242", "The idempotency marker must record the run identity (root_seed).")

	# The meta-award event is emitted and self-consistent (before + amount == after).
	assert_equal(award_result.events.size(), 1, "Exactly one oath_shards_awarded event should be emitted.")
	var event: DomainEvent = award_result.events[0]
	assert_equal(event.event_type, DomainEvent.Type.OATH_SHARDS_AWARDED, "The emitted event must be oath_shards_awarded.")
	assert_equal(event.payload.get("amount"), expected_amount, "The event must carry the awarded amount.")
	assert_equal(event.payload.get("oath_shards_before"), 10, "The event must carry the before total.")
	assert_equal(event.payload.get("oath_shards_after"), 10 + expected_amount, "The event must carry the after total.")
	assert_equal(event.payload.get("reason"), "run_completed_eligible", "The event must carry the eligible-completion reason.")
	# The emitted event is a valid, round-trippable domain event.
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parse_result.succeeded, "The emitted award event must be a valid round-trippable domain event: %s" % parse_result.metadata)


func _award_round_trips_through_the_repository() -> void:
	# The awarded profile persists + reads back with the raised total (AC1 — "updated through a versioned repository").
	_cleanup()
	var run: RunState = _completed_run(2, 555, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	var command: AwardMetaProgressCommand = AwardMetaProgressCommand.new(profile, summary, 1)
	var award_result: ActionResult = command.execute(run)
	assert_true(award_result.succeeded, "The award should succeed before persisting.")

	var repository: ProfileRepository = ProfileRepository.new()
	var write_result: ActionResult = repository.write_profile(profile, TEST_PROFILE_PATH)
	assert_true(write_result.succeeded, "The awarded profile should persist: %s" % write_result.metadata)

	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "The awarded profile should read back.")
	var restored: ProfileSnapshot = read_result.metadata.get("snapshot")
	assert_equal(restored.oath_shards, profile.oath_shards, "The persisted profile must retain the awarded total.")
	assert_equal(restored.last_awarded_run_seed, "555", "The persisted profile must retain the idempotency marker.")
	_cleanup()


func _manual_seed_run_awards_nothing_profile_unchanged() -> void:
	# AC4/FR28: a manual-seed run awards NOTHING — reject, 0 shards, no event, the profile byte-identical.
	var run: RunState = _completed_run(3, 4242, true)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 7
	var profile_before: Dictionary = profile.to_dictionary()

	var command: AwardMetaProgressCommand = AwardMetaProgressCommand.new(profile, summary, 1)
	var award_result: ActionResult = command.execute(run)

	assert_true(award_result.is_error(), "A manual-seed run must be denied (FR28/AC4).")
	assert_equal(award_result.error_code, &"run_not_meta_eligible", "A manual-seed run must reject with the stable ineligibility code.")
	assert_false(award_result.has_events(), "A manual-seed run must emit NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "A manual-seed run must leave the profile byte-identical (0 shards, no mastery, no unlock).")
	assert_equal(profile.oath_shards, 7, "A manual-seed run must not change the Oath-Shard total.")


func _manual_seed_summary_carries_the_replay_practice_warning() -> void:
	# AC4: "the summary shows a replay/practice warning" — the Story 8.2 fields meta_progression_eligible == false +
	# is_manual_seed == true ARE the warning data (no redundant signal needed).
	var run: RunState = _completed_run(3, 4242, true)
	var summary: Dictionary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})]).to_dictionary()

	assert_true(bool(summary.get("has_summary")), "A manual-seed terminal run still has a summary.")
	assert_false(bool(summary.get("meta_progression_eligible")), "A manual-seed run's summary reports meta_progression_eligible == false (the AC4 warning data).")
	assert_true(bool(summary.get("is_manual_seed")), "A manual-seed run's summary reports is_manual_seed == true (the AC4 warning data).")
	# The awarded count in the summary stays 0 for a manual-seed run (no award landed).
	assert_equal((summary.get("profile_meta") as Dictionary).get("oath_shards_earned"), 0, "A manual-seed run's summary reports 0 awarded.")


func _non_terminal_run_rejects_with_zero_mutation() -> void:
	# A non-terminal run (still active) has no ended run to reward — reject with ZERO mutation.
	var route: RouteState = _cleared_route(2)
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	var summary: RunSummary = RunSummary.build(run, [])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 5
	var profile_before: Dictionary = profile.to_dictionary()

	var command: AwardMetaProgressCommand = AwardMetaProgressCommand.new(profile, summary, 1)
	var award_result: ActionResult = command.execute(run)

	assert_true(award_result.is_error(), "A non-terminal run must be rejected.")
	assert_equal(award_result.error_code, &"run_not_terminal", "A non-terminal run must reject with the stable code.")
	assert_false(award_result.has_events(), "A non-terminal run must emit NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "A non-terminal run must leave the profile byte-identical.")


func _reinvocation_for_same_run_does_not_double_award() -> void:
	# AC1 + the 8.1 seam: a re-invocation for the SAME already-awarded run must NOT double-award (idempotency).
	var run: RunState = _completed_run(3, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	var first: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(first.succeeded, "The first award should succeed.")
	var total_after_first: int = profile.oath_shards
	var profile_after_first: Dictionary = profile.to_dictionary()

	# Re-invoke for the SAME run (same root_seed already recorded on the profile).
	var second: ActionResult = AwardMetaProgressCommand.new(profile, summary, 2).execute(run)
	assert_true(second.is_error(), "A re-invocation for the same already-awarded run must be rejected (no double-award).")
	assert_equal(second.error_code, &"run_already_awarded", "A re-award must reject with the stable idempotency code.")
	assert_false(second.has_events(), "A re-award must emit NO second event.")
	assert_equal(profile.oath_shards, total_after_first, "A re-award must NOT raise the total again.")
	assert_equal(profile.to_dictionary(), profile_after_first, "A re-award must leave the profile byte-identical (no double-mutation).")

	# A DIFFERENT run (different root_seed) DOES award again (the marker is per-run, not a global lock).
	var other_run: RunState = _completed_run(3, 9999, false)
	var other_summary: RunSummary = RunSummary.build(other_run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var third: ActionResult = AwardMetaProgressCommand.new(profile, other_summary, 3).execute(other_run)
	assert_true(third.succeeded, "A DIFFERENT run should award again (the idempotency marker is per-run).")
	assert_true(profile.oath_shards > total_after_first, "A different run's award must raise the total.")


func _reject_leaves_profile_and_run_byte_identical() -> void:
	# The 4.3 no-mutation-on-reject guarantee: on ANY reject the run AND the profile are byte-identical.
	var run: RunState = _completed_run(3, 4242, true)  # manual-seed → will reject at Gate 2
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 3
	var run_before: Dictionary = run.to_dictionary()
	var profile_before: Dictionary = profile.to_dictionary()

	var award_result: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(award_result.is_error(), "The manual-seed run should reject.")
	assert_equal(run.to_dictionary(), run_before, "A reject must leave the RunState byte-identical.")
	assert_equal(profile.to_dictionary(), profile_before, "A reject must leave the ProfileSnapshot byte-identical.")


func _invalid_context_is_rejected() -> void:
	# A null profile, a non-RunState state, and a null-route run all reject with invalid_context (ZERO mutation).
	var run: RunState = _completed_run(3, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])

	var null_profile: ActionResult = AwardMetaProgressCommand.new(null, summary, 1).execute(run)
	assert_true(null_profile.is_error(), "A null profile must be rejected.")
	assert_equal(null_profile.error_code, &"invalid_context", "A null profile must reject with invalid_context.")

	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var not_a_run: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute("not-a-run")
	assert_true(not_a_run.is_error(), "A non-RunState state must be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A non-RunState state must reject with invalid_context.")


func _invalid_sequence_id_is_rejected() -> void:
	# The 4.3 self-consistency gate: sequence_id <= 0 is rejected BEFORE any mutation (a success path can never emit a
	# non-round-trippable event).
	var run: RunState = _completed_run(3, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	var profile_before: Dictionary = profile.to_dictionary()

	var award_result: ActionResult = AwardMetaProgressCommand.new(profile, summary, 0).execute(run)
	assert_true(award_result.is_error(), "A non-positive sequence id must be rejected.")
	assert_equal(award_result.error_code, &"invalid_event_sequence_id", "A non-positive sequence id must reject with the stable code.")
	assert_equal(profile.to_dictionary(), profile_before, "A sequence-id reject must leave the profile byte-identical.")


func _failed_profile_write_leaves_summary_readable() -> void:
	# AC5: a failed profile write returns a structured error AND leaves the RunSummary fully readable (no silent loss).
	# The RunSummary is a DERIVED read INDEPENDENT of the profile file.
	var run: RunState = _completed_run(3, 4242, false)
	var events: Array = [DomainEvent.run_completed(1, {"outcome": "completed"})]
	var summary: RunSummary = RunSummary.build(run, events)
	var summary_before: Dictionary = summary.to_dictionary()
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	# Apply the award, then force a write failure.
	var award_result: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(award_result.succeeded, "The award should succeed before the write is attempted.")

	var repository: ProfileRepository = ProfileRepository.new()
	var failing_path: String = "user://__test_missing_award_dir__/profile.json"
	var write_result: ActionResult = repository.write_profile(profile, failing_path)

	assert_true(write_result.is_error(), "The profile write into a missing dir must fail.")
	assert_equal(write_result.error_code, &"profile_save_open_failed", "The failed write must surface a structured error (AC5).")
	assert_true(write_result.metadata.has("path"), "The failed write must carry diagnostic metadata.")

	# AC5 — no silent loss: the RunSummary is STILL fully readable after the failed profile write (it does not read the
	# profile file; it is a derived read of the terminal run + events).
	var summary_after: Dictionary = RunSummary.build(run, events).to_dictionary()
	assert_equal(summary_after, summary_before, "A failed profile write must leave the RunSummary fully readable (AC5 — no silent loss).")
	assert_true(bool(summary_after.get("has_summary")), "The summary must still report has_summary == true after a failed write.")


func _run_profile_and_unlock_state_stay_separable() -> void:
	# AC2: run state, profile state, and unlock/content state remain separable. Awarding to the profile does NOT touch
	# the run's own oath-shard-related fields (the run stays run-scoped; the cross-run total lives in the profile).
	var run: RunState = _completed_run(3, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	# The run's economy Oath-Shard ELIGIBILITY is a gate, not an awarded count — awarding must not alter it.
	var eligibility_before: bool = run.risk_economy.oath_shard_eligible

	var award_result: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(award_result.succeeded, "The award should succeed.")

	assert_equal(run.risk_economy.oath_shard_eligible, eligibility_before, "The award must not alter the run's eligibility gate.")
	assert_equal(run.risk_economy.gold, 0, "The award must not touch the run-scoped economy.")
	# The profile's 8.4 unlock/content HOMES stay empty (8.3 awards ONLY the Oath-Shard currency).
	assert_equal(profile.class_mastery, {}, "The award must NOT touch the 8.4 class_mastery home.")
	assert_equal(profile.echoes, [], "The award must NOT touch the 8.4 echoes home.")
	assert_equal(profile.unlock_progress, {}, "The award must NOT touch the 8.4 unlock_progress home.")
	assert_false(profile.first_death_recorded, "The award must NOT touch the 8.5 first_death_recorded home.")


func _failed_run_awards_zero_but_is_recorded_as_resolved() -> void:
	# A failed (death) run is eligible (non-manual) but the RULE awards 0 — the command still SUCCEEDS with a 0 amount
	# and records the run identity (so a re-award is a no-op), emitting an honest 0-amount event.
	var run: RunState = _failed_run(3, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 6

	var award_result: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(award_result.succeeded, "A failed (eligible) run resolves the award (with a 0 amount this story).")
	assert_equal(award_result.metadata.get("amount"), 0, "A failed run awards 0 Oath Shards this story.")
	assert_equal(profile.oath_shards, 6, "A failed run must not change the Oath-Shard total (0 award).")
	assert_equal(profile.last_awarded_run_seed, "4242", "A failed run still records the run identity (a re-award is a no-op).")
	# The honest 0-amount event is emitted (before + 0 == after).
	assert_equal(award_result.events.size(), 1, "A resolved failed run emits an honest 0-amount event.")
	assert_equal((award_result.events[0] as DomainEvent).payload.get("amount"), 0, "The event records the 0 amount.")


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


func _failed_run(cleared: int, seed_value: int, is_manual_seed: bool) -> RunState:
	var run: RunState = RunState.new(RunState.PHASE_FAILED, seed_value, is_manual_seed, not is_manual_seed, _cleared_route(cleared))
	assert_true(run.validate().succeeded, "Setup: the failed run should validate.")
	return run


func _cleanup() -> void:
	for path: String in [TEST_PROFILE_PATH, "%s.tmp" % TEST_PROFILE_PATH, "%s.bak" % TEST_PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
