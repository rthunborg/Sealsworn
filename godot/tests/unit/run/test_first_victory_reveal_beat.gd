extends "res://tests/unit/test_case.gd"

# Story 9.4 Task 6/7 (AC2/AC3): the FirstVictoryRevealBeat — the scene-free, skippable first-victory reveal read DTO, the
# OPPOSITE-terminal-phase twin of FirstDeathNarrativeBeat. The beat build is a PURE read (ZERO RNG, ZERO mutation); an exact
# pinned DICTIONARY_KEYS; a first-victory input projects has_beat == true + the resolved line ("It did not die. It learned
# the way back.") + is_skippable == true; a null / unresolvable / non-first-victory input projects the fail-closed empty beat
# (has_beat == false); a simulated build+read+dismiss leaves the profile/run byte-identical (AC3 — a skip is a structural
# no-op); the beat is INDEPENDENT of RunSummary (building one never touches the other, and the summary carries NO reveal
# field — AC3 off-critical-path).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const FirstVictoryRevealBeat = preload("res://scripts/run/first_victory_reveal_beat.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RecordFirstVictoryCommand = preload("res://scripts/core/commands/record_first_victory_command.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

func run() -> Dictionary:
	_first_victory_beat_projects_the_resolved_line()
	_dictionary_key_set_is_exact_and_pinned()
	_empty_beat_is_fail_closed()
	_unresolvable_line_id_projects_empty_beat()
	_beat_from_event_projects_the_resolved_line()
	_build_read_dismiss_is_a_structural_no_op()
	_repeated_builds_are_byte_identical()
	_beat_is_independent_of_run_summary()
	return result()


func _first_victory_beat_projects_the_resolved_line() -> void:
	# A first-victory beat projects has_beat == true + the resolved display prose (FR62) + is_skippable == true (FR65).
	var beat: FirstVictoryRevealBeat = FirstVictoryRevealBeat.for_first_victory()

	assert_true(beat.has_beat, "A first-victory beat must have a meaningful beat.")
	assert_equal(String(beat.line_id), String(DomainEvent.FIRST_VICTORY_LINE_ID), "The beat must carry the line-by-id.")
	assert_equal(beat.line, FirstVictoryRevealBeat.FIRST_VICTORY_LINE, "The beat must resolve the first-victory display prose.")
	assert_equal(beat.line, "It did not die. It learned the way back.", "The resolved line must be the FR62 first-victory reveal.")
	assert_true(beat.is_skippable, "The first-victory beat must be skippable (FR65).")


func _dictionary_key_set_is_exact_and_pinned() -> void:
	# The exact-key discipline (the FirstDeathNarrativeBeat precedent): to_dictionary() projects EXACTLY the pinned
	# DICTIONARY_KEYS set.
	var beat: FirstVictoryRevealBeat = FirstVictoryRevealBeat.for_first_victory()
	var data: Dictionary = beat.to_dictionary()

	var actual_keys: Array = data.keys()
	actual_keys.sort()
	var expected_keys: Array = FirstVictoryRevealBeat.DICTIONARY_KEYS.duplicate()
	expected_keys.sort()

	assert_equal(actual_keys, expected_keys, "FirstVictoryRevealBeat.to_dictionary() must project EXACTLY the pinned DICTIONARY_KEYS set.")
	assert_equal(data.size(), FirstVictoryRevealBeat.DICTIONARY_KEYS.size(), "FirstVictoryRevealBeat.to_dictionary() must have no surprise keys.")

	# The empty beat also holds the pinned key shape (the exact-key contract holds for the fail-closed projection too).
	var empty_data: Dictionary = FirstVictoryRevealBeat.new().to_dictionary()
	var empty_keys: Array = empty_data.keys()
	empty_keys.sort()
	assert_equal(empty_keys, expected_keys, "The empty beat must project the SAME pinned key set (fail-closed exact-key).")


func _empty_beat_is_fail_closed() -> void:
	# A default/empty beat is fail-closed: has_beat == false + empty fields, so a consumer branches on has_beat without
	# inspecting the empty fields.
	var beat: FirstVictoryRevealBeat = FirstVictoryRevealBeat.new()
	assert_false(beat.has_beat, "An empty beat must have has_beat == false.")
	assert_equal(String(beat.line_id), "", "An empty beat must carry an empty line_id.")
	assert_equal(beat.line, "", "An empty beat must carry an empty line.")
	assert_false(beat.is_skippable, "An empty beat must have is_skippable == false.")


func _unresolvable_line_id_projects_empty_beat() -> void:
	# An UNKNOWN / blank line_id (not in LINE_BY_ID) projects the fail-closed empty beat (never a beat with no resolvable
	# line).
	var unknown: FirstVictoryRevealBeat = FirstVictoryRevealBeat.for_first_victory(&"not_a_real_line")
	assert_false(unknown.has_beat, "An unresolvable line_id must project the fail-closed empty beat.")
	assert_equal(unknown.line, "", "An unresolvable line_id must resolve NO line.")

	var blank: FirstVictoryRevealBeat = FirstVictoryRevealBeat.for_first_victory(&"")
	assert_false(blank.has_beat, "A blank line_id must project the fail-closed empty beat.")


func _beat_from_event_projects_the_resolved_line() -> void:
	# The from_event convenience seam: a first_victory_recorded event projects the populated beat; a wrong-type / null event
	# projects the fail-closed empty beat.
	var event: DomainEvent = DomainEvent.first_victory_recorded(1, {
		"line_id": String(DomainEvent.FIRST_VICTORY_LINE_ID),
		"is_skippable": true,
		"profile_id": "default"
	})
	var beat: FirstVictoryRevealBeat = FirstVictoryRevealBeat.from_event(event)
	assert_true(beat.has_beat, "from_event on a first_victory_recorded event must project a populated beat.")
	assert_equal(beat.line, "It did not die. It learned the way back.", "from_event must resolve the first-victory line.")
	assert_true(beat.is_skippable, "from_event must carry the event's skippable flag.")

	# A null event -> empty beat.
	assert_false(FirstVictoryRevealBeat.from_event(null).has_beat, "from_event on a null event must project the empty beat.")

	# A wrong-type event (first_death_recorded) -> empty beat (the OPPOSITE terminal-phase twin must not cross-resolve).
	var wrong: DomainEvent = DomainEvent.first_death_recorded(1, {"line_id": "first_death", "is_skippable": true, "profile_id": "default"})
	assert_false(FirstVictoryRevealBeat.from_event(wrong).has_beat, "from_event on a first_death_recorded event must project the empty beat (distinct events).")


func _build_read_dismiss_is_a_structural_no_op() -> void:
	# AC3 "skipping does not alter rewards or progression": building + reading + a simulated dismiss of the beat leaves the
	# profile + run byte-identical (the DTO owns no truth to change; there is NO skip command). The line delivery (this DTO)
	# is SEPARATE from the flag mutation (RecordFirstVictoryCommand), so a skip cannot mutate the flag.
	var run: RunState = _completed_run(9, 4242, false)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	# Record the first victory FIRST (the flag mutation is the command's job), THEN snapshot state before touching the beat.
	RecordFirstVictoryCommand.new(profile, 1).execute(run)
	var run_before: Dictionary = run.to_dictionary()
	var profile_before: Dictionary = profile.to_dictionary()

	# Build + read the beat, then "dismiss" it (simply drop the reference — there is no skip command).
	var beat: FirstVictoryRevealBeat = FirstVictoryRevealBeat.for_first_victory()
	var _read_line: String = beat.line
	var _read_dict: Dictionary = beat.to_dictionary()
	beat = null  # dismiss = stop rendering; no domain effect.

	assert_equal(run.to_dictionary(), run_before, "Building/reading/dismissing the beat must leave the run byte-identical (skip is a no-op).")
	assert_equal(profile.to_dictionary(), profile_before, "Building/reading/dismissing the beat must leave the profile byte-identical (skip is a no-op).")
	# The flag stays set regardless of whether the beat was shown or skipped (the flag records the FACT, not the display).
	assert_true(profile.first_victory_recorded, "The first-victory flag stays set whether or not the beat is shown/skipped.")


func _repeated_builds_are_byte_identical() -> void:
	# Determinism: repeated builds/reads are byte-identical (the beat draws ZERO RNG).
	var first: Dictionary = FirstVictoryRevealBeat.for_first_victory().to_dictionary()
	var second: Dictionary = FirstVictoryRevealBeat.for_first_victory().to_dictionary()
	assert_equal(first, second, "Repeated beat builds must be byte-identical (ZERO RNG).")

	# A mutation of a returned dict must NOT perturb a fresh build (the deep-copy discipline).
	first["line"] = "mutated"
	assert_equal(FirstVictoryRevealBeat.for_first_victory().line, "It did not die. It learned the way back.", "Mutating a returned dict must not perturb a fresh build.")


func _beat_is_independent_of_run_summary() -> void:
	# AC3: the reveal is a SEPARATE optional surface — building it never touches RunSummary and RunSummary carries NO reveal
	# field. Building both from the SAME completed run keeps them independent (the summary key set is unchanged; the summary
	# has no narrative key). The run SUMMARY + outpost RETURN are COMPLETE without the reveal (AC3 off-critical-path).
	var run: RunState = _completed_run(9, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [])
	var beat: FirstVictoryRevealBeat = FirstVictoryRevealBeat.for_first_victory()

	assert_true(beat.has_beat, "The beat builds independently of the summary.")
	assert_true(summary.has_summary, "The summary builds independently of the beat.")
	# The summary carries NO narrative/reveal field (AC3 non-dependency fence).
	var summary_data: Dictionary = summary.to_dictionary()
	assert_false(summary_data.has("line"), "The RunSummary must NOT carry a narrative line field (AC3 — the reveal is off the summary critical path).")
	assert_false(summary_data.has("line_id"), "The RunSummary must NOT carry a narrative line_id field (AC3).")
	assert_false(summary_data.has("has_beat"), "The RunSummary must NOT carry the beat's has_beat field (AC3).")
	# The summary's top-level key set is UNCHANGED (still exactly RunSummary.DICTIONARY_KEYS — 9.4 added no reveal key).
	var summary_keys: Array = summary_data.keys()
	summary_keys.sort()
	var expected_summary_keys: Array = RunSummary.DICTIONARY_KEYS.duplicate()
	expected_summary_keys.sort()
	assert_equal(summary_keys, expected_summary_keys, "9.4 must NOT add a reveal field to RunSummary (the 8.2/8.4 key pin stays green).")


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
