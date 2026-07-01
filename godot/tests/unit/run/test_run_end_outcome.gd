extends "res://tests/unit/test_case.gd"

# Story 8.1 — RunEndOutcome (the scene-free RUN-END read surface / flow signal). Covers the AC1/AC2 flow signal: a
# FAILED run projects { has_ended, phase: failed, outcome_or_cause: <cause>, next_destination: outpost, meta_eligible }
# and a COMPLETED run projects the same shape with the completion outcome; BOTH carry next_destination == outpost; the
# eligibility field MIRRORS run.meta_progression_eligible (true for a normal run, false for a manual-seed run); the
# projection has an EXACT pinned key set; the read is pure (twice -> identical); and a non-terminal / null run projects
# the fail-closed empty fact (has_ended == false).

const RunEndOutcome = preload("res://scripts/run/run_end_outcome.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_failed_run_reports_outpost_and_cause()
	_completed_run_reports_outpost_and_outcome()
	_manual_seed_run_reports_ineligible()
	_non_terminal_or_null_run_projects_empty_fact()
	_projection_keys_are_exact()
	_read_is_pure()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A run forced into a terminal phase (FAILED or COMPLETED), with the given manual-seed flag. Built directly so the read
# DTO can be exercised without driving a full command sequence.
func _terminal_run(phase: StringName, is_manual_seed: bool) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_CLEARED, [])
	var route: RouteState = RouteState.new([start, boss], "node-1-0", ["node-0-0", "node-1-0"])
	var run: RunState = RunState.new(phase, 4242, is_manual_seed, not is_manual_seed, route)
	assert_true(run.validate().succeeded, "Setup: the terminal %s run should validate." % String(phase))
	return run


# ---- AC1: a failed run reports the outpost + the cause --------------------------------------------

func _failed_run_reports_outpost_and_cause() -> void:
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, false)
	var outcome: RunEndOutcome = RunEndOutcome.for_failed(run, &"hero_death")
	var data: Dictionary = outcome.to_dictionary()

	assert_true(bool(data.get("has_ended")), "A failed run's outcome should report has_ended == true.")
	assert_equal(data.get("phase"), "failed", "A failed run's outcome should report the failed phase.")
	assert_equal(data.get("outcome_or_cause"), "hero_death", "A failed run's outcome should carry the death cause.")
	assert_equal(data.get("next_destination"), "outpost", "A failed run's next destination is the outpost (AC1).")
	assert_true(bool(data.get("meta_progression_eligible")), "A non-manual failed run is meta-eligible (mirrors the run).")


# ---- AC2: a completed run reports the outpost + the outcome ---------------------------------------

func _completed_run_reports_outpost_and_outcome() -> void:
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, false)
	var outcome: RunEndOutcome = RunEndOutcome.for_completed(run, &"completed")
	var data: Dictionary = outcome.to_dictionary()

	assert_true(bool(data.get("has_ended")), "A completed run's outcome should report has_ended == true.")
	assert_equal(data.get("phase"), "completed", "A completed run's outcome should report the completed phase.")
	assert_equal(data.get("outcome_or_cause"), "completed", "A completed run's outcome should carry the completion outcome.")
	assert_equal(data.get("next_destination"), "outpost", "A completed run's next destination is the outpost (AC2).")
	assert_true(bool(data.get("meta_progression_eligible")), "A non-manual completed run is meta-eligible (mirrors the run).")


# ---- the eligibility field mirrors meta_progression_eligible (READ-ONLY; 8.1 grants nothing) -----

func _manual_seed_run_reports_ineligible() -> void:
	# A manual-seed run is NEVER meta-eligible (lockstep with is_manual_seed). The flow signal REPORTS this; 8.1 takes
	# no award action (the actual meta gate + awarding is Story 8.3).
	var failed_manual: RunState = _terminal_run(RunState.PHASE_FAILED, true)
	assert_false(failed_manual.meta_progression_eligible, "Setup: a manual-seed run is not meta-eligible.")
	var failed_outcome: Dictionary = RunEndOutcome.for_failed(failed_manual, &"hero_death").to_dictionary()
	assert_false(bool(failed_outcome.get("meta_progression_eligible")), "A manual-seed failed run reports meta_progression_eligible == false.")
	# Still routes to the outpost (eligibility does not change the destination).
	assert_equal(failed_outcome.get("next_destination"), "outpost", "A manual-seed run still routes to the outpost.")

	var completed_manual: RunState = _terminal_run(RunState.PHASE_COMPLETED, true)
	var completed_outcome: Dictionary = RunEndOutcome.for_completed(completed_manual, &"completed").to_dictionary()
	assert_false(bool(completed_outcome.get("meta_progression_eligible")), "A manual-seed completed run reports meta_progression_eligible == false.")


# ---- fail-closed: a non-terminal / null run projects the empty fact -------------------------------

func _non_terminal_or_null_run_projects_empty_fact() -> void:
	# A non-terminal run (or the wrong builder for the phase, or null) projects has_ended == false + empty fields, so a
	# consumer branches on has_ended without inspecting the empty fields.
	var active: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([active], "node-0-0", [])
	var active_run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 5, false, true, route)

	# for_failed on a non-FAILED run -> empty.
	var not_failed: Dictionary = RunEndOutcome.for_failed(active_run, &"hero_death").to_dictionary()
	assert_false(bool(not_failed.get("has_ended")), "for_failed on a non-FAILED run should project has_ended == false.")
	assert_equal(not_failed.get("phase"), "", "An empty fact has an empty phase.")
	assert_equal(not_failed.get("outcome_or_cause"), "", "An empty fact has an empty outcome_or_cause.")
	assert_equal(not_failed.get("next_destination"), "", "An empty fact has an empty next_destination (no destination claim for a non-ended run).")
	assert_false(bool(not_failed.get("meta_progression_eligible")), "An empty fact defaults meta_progression_eligible to false (no claim).")

	# for_completed on a non-COMPLETED run -> empty.
	var not_completed: Dictionary = RunEndOutcome.for_completed(active_run, &"completed").to_dictionary()
	assert_false(bool(not_completed.get("has_ended")), "for_completed on a non-COMPLETED run should project has_ended == false.")

	# Using the WRONG builder for the terminal phase (for_completed on a FAILED run) -> empty (a builder only accepts
	# its own terminal phase).
	var failed_run: RunState = _terminal_run(RunState.PHASE_FAILED, false)
	var wrong_builder: Dictionary = RunEndOutcome.for_completed(failed_run, &"completed").to_dictionary()
	assert_false(bool(wrong_builder.get("has_ended")), "for_completed on a FAILED run should project the empty fact (wrong builder).")

	# null run -> empty.
	var null_failed: Dictionary = RunEndOutcome.for_failed(null, &"hero_death").to_dictionary()
	assert_false(bool(null_failed.get("has_ended")), "for_failed(null) should project the empty fact.")
	var null_completed: Dictionary = RunEndOutcome.for_completed(null, &"completed").to_dictionary()
	assert_false(bool(null_completed.get("has_ended")), "for_completed(null) should project the empty fact.")


# ---- the projection has an EXACT pinned key set ---------------------------------------------------

func _projection_keys_are_exact() -> void:
	# The to_dictionary() key set is EXACTLY DICTIONARY_KEYS (no key silently appears/vanishes — the exact-key
	# discipline). Checked for a terminal AND an empty projection (both share the shape).
	var terminal: Dictionary = RunEndOutcome.for_completed(_terminal_run(RunState.PHASE_COMPLETED, false), &"completed").to_dictionary()
	var empty: Dictionary = RunEndOutcome.for_failed(null, &"hero_death").to_dictionary()

	for projected: Dictionary in [terminal, empty]:
		assert_equal(projected.size(), RunEndOutcome.DICTIONARY_KEYS.size(), "The projection must have exactly the pinned key count.")
		for key: String in RunEndOutcome.DICTIONARY_KEYS:
			assert_true(projected.has(key), "The projection must carry the pinned key `%s`." % key)
		for key_value: Variant in projected.keys():
			assert_true(RunEndOutcome.DICTIONARY_KEYS.has(String(key_value)), "The projection must NOT carry an un-pinned key `%s`." % String(key_value))


# ---- the read is pure (twice -> identical) --------------------------------------------------------

func _read_is_pure() -> void:
	# Repeated reads of the same outcome are byte-identical (no mutation, no RNG, no events — a pure read DTO).
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, false)
	var outcome: RunEndOutcome = RunEndOutcome.for_failed(run, &"level_defeat")
	var first: Dictionary = outcome.to_dictionary()
	var second: Dictionary = outcome.to_dictionary()
	assert_equal(second, first, "Repeated reads of a RunEndOutcome must be identical (pure read).")
	# Mutating the returned dict must not perturb the DTO (a fresh dict each call).
	first["has_ended"] = false
	assert_true(bool(outcome.to_dictionary().get("has_ended")), "Mutating a returned dict must not perturb the DTO.")
