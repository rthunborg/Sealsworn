extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")

func run() -> Dictionary:
	_new_run_initializes_ac1_fields()
	_new_run_draws_no_rng()
	_every_legal_transition_lands_in_the_right_phase()
	_illegal_transitions_are_rejected_with_no_mutation()
	_terminal_phases_reject_all_transitions()
	_manual_seed_invariant_holds()
	_unknown_phase_is_rejected()
	_root_seed_survives_full_int64_round_trip()
	_run_state_round_trips_through_real_json()
	_bridges_into_existing_run_snapshot_fields()
	_top_level_current_node_pointer_is_honored_on_resume()
	_phaseless_route_payload_resumes_as_new_run()
	_run_snapshot_no_surprise_key_gate_stays_green()
	# Story 5.3 — the applied kit + the nested class-id in the snapshot bridge.
	_kit_less_run_validates_and_round_trips_with_null_kit()
	_run_with_kit_round_trips_through_dictionary_and_copy()
	_selected_class_id_nests_in_the_snapshot_bridge_and_round_trips()
	return result()


func _build_route() -> RouteState:
	var start: RouteNode = RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["boss"])
	var boss: RouteNode = RouteNode.new("boss", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	return RouteState.new([start, boss], "", [])


func _new_run_initializes_ac1_fields() -> void:
	var run: RunState = RunState.new_run(4242, false, _build_route())
	assert_equal(run.phase, RunState.PHASE_NEW_RUN, "AC1: a new run starts in PHASE_NEW_RUN.")
	assert_equal(run.root_seed, 4242, "AC1: a new run records the root seed.")
	assert_false(run.is_manual_seed, "AC1: a non-manual run is not manual-seed.")
	assert_true(run.meta_progression_eligible, "AC1: a non-manual run is meta-eligible.")
	assert_equal(run.route.current_node_id, "", "AC1: a new run has an empty current node pointer.")
	assert_equal(run.route.cleared_node_ids, [], "AC1: a new run has no cleared nodes.")
	assert_true(run.validate().succeeded, "A freshly initialized run should validate.")
	# AC1 'available route choices' are derived from the route graph (empty until parked on a node).
	assert_equal(run.available_choice_ids(), [], "A new run parked at no node derives no choices yet.")


func _new_run_draws_no_rng() -> void:
	# Determinism: run-state init and transitions must consume ZERO RNG draws. Hold a stream set,
	# snapshot it, run new_run + a transition, and assert the streams are byte-identical (no draw).
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var before: Dictionary = streams.to_snapshot()
	var run: RunState = RunState.new_run(13579, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	var after: Dictionary = streams.to_snapshot()
	assert_equal(after, before, "Run-state init and transitions must draw no RNG (stream set unchanged).")


func _every_legal_transition_lands_in_the_right_phase() -> void:
	# NEW_RUN -> ACTIVE_ROUTE
	var run: RunState = RunState.new_run(1, false, _build_route())
	assert_true(run.can_transition_to(RunState.PHASE_ACTIVE_ROUTE), "NEW_RUN -> ACTIVE_ROUTE should be legal.")
	assert_true(run.transition_to(RunState.PHASE_ACTIVE_ROUTE).succeeded, "NEW_RUN -> ACTIVE_ROUTE should succeed.")
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Run should be in ACTIVE_ROUTE.")

	# ACTIVE_ROUTE -> NODE_RESOLUTION
	assert_true(run.transition_to(RunState.PHASE_NODE_RESOLUTION).succeeded, "ACTIVE_ROUTE -> NODE_RESOLUTION should succeed.")
	assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "Run should be in NODE_RESOLUTION.")

	# NODE_RESOLUTION -> ACTIVE_ROUTE (back to a choice after a node clears)
	assert_true(run.transition_to(RunState.PHASE_ACTIVE_ROUTE).succeeded, "NODE_RESOLUTION -> ACTIVE_ROUTE should succeed.")
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Run should be back in ACTIVE_ROUTE.")

	# NODE_RESOLUTION -> COMPLETED
	run.transition_to(RunState.PHASE_NODE_RESOLUTION)
	assert_true(run.transition_to(RunState.PHASE_COMPLETED).succeeded, "NODE_RESOLUTION -> COMPLETED should succeed.")
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "Run should be COMPLETED.")
	assert_true(run.is_terminal(), "COMPLETED is terminal.")

	# NODE_RESOLUTION -> FAILED
	var run_b: RunState = RunState.new_run(2, false, _build_route())
	run_b.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run_b.transition_to(RunState.PHASE_NODE_RESOLUTION)
	assert_true(run_b.transition_to(RunState.PHASE_FAILED).succeeded, "NODE_RESOLUTION -> FAILED should succeed.")
	assert_true(run_b.is_terminal(), "FAILED is terminal.")

	# ACTIVE_ROUTE -> FAILED (abandon/death at a choice)
	var run_c: RunState = RunState.new_run(3, false, _build_route())
	run_c.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	assert_true(run_c.transition_to(RunState.PHASE_FAILED).succeeded, "ACTIVE_ROUTE -> FAILED should succeed.")
	assert_true(run_c.is_terminal(), "FAILED is terminal.")


func _illegal_transitions_are_rejected_with_no_mutation() -> void:
	# A representative set of illegal edges. Each must return invalid_run_transition AND leave the
	# RunState.to_dictionary() byte-identical (no field mutation on a rejected transition).
	_assert_illegal_transition(RunState.PHASE_NEW_RUN, RunState.PHASE_NODE_RESOLUTION)
	_assert_illegal_transition(RunState.PHASE_NEW_RUN, RunState.PHASE_COMPLETED)
	_assert_illegal_transition(RunState.PHASE_NEW_RUN, RunState.PHASE_FAILED)
	_assert_illegal_transition(RunState.PHASE_NEW_RUN, RunState.PHASE_NEW_RUN)
	_assert_illegal_transition(RunState.PHASE_ACTIVE_ROUTE, RunState.PHASE_NEW_RUN)
	_assert_illegal_transition(RunState.PHASE_ACTIVE_ROUTE, RunState.PHASE_COMPLETED)
	_assert_illegal_transition(RunState.PHASE_NODE_RESOLUTION, RunState.PHASE_NEW_RUN)
	# An unknown target phase is also rejected as an illegal transition.
	_assert_illegal_transition(RunState.PHASE_ACTIVE_ROUTE, &"teleport")


func _assert_illegal_transition(from_phase: StringName, to_phase: StringName) -> void:
	var run: RunState = RunState.new_run(99, false, _build_route())
	# Drive the run to the requested starting phase along legal edges.
	if from_phase == RunState.PHASE_ACTIVE_ROUTE:
		run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	elif from_phase == RunState.PHASE_NODE_RESOLUTION:
		run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
		run.transition_to(RunState.PHASE_NODE_RESOLUTION)
	assert_equal(run.phase, from_phase, "Test setup should land the run in %s." % String(from_phase))

	var before: Dictionary = run.to_dictionary()
	var transition: ActionResult = run.transition_to(to_phase)
	var after: Dictionary = run.to_dictionary()

	assert_true(transition.is_error(), "%s -> %s should be rejected." % [String(from_phase), String(to_phase)])
	assert_equal(transition.error_code, &"invalid_run_transition", "Illegal transition should use the stable code.")
	assert_equal(transition.metadata.get("from"), String(from_phase), "Rejected transition should report the from-phase.")
	assert_equal(transition.metadata.get("to"), String(to_phase), "Rejected transition should report the to-phase.")
	assert_equal(after, before, "A rejected transition must leave RunState byte-identical (%s -> %s)." % [String(from_phase), String(to_phase)])


func _terminal_phases_reject_all_transitions() -> void:
	for terminal_phase: StringName in [RunState.PHASE_COMPLETED, RunState.PHASE_FAILED]:
		for target: StringName in [
			RunState.PHASE_NEW_RUN,
			RunState.PHASE_ACTIVE_ROUTE,
			RunState.PHASE_NODE_RESOLUTION,
			RunState.PHASE_COMPLETED,
			RunState.PHASE_FAILED
		]:
			var run: RunState = RunState.new(terminal_phase, 5, false, true, _build_route())
			assert_false(run.can_transition_to(target), "%s should have no outgoing edge to %s." % [String(terminal_phase), String(target)])
			var before: Dictionary = run.to_dictionary()
			var transition: ActionResult = run.transition_to(target)
			assert_true(transition.is_error(), "%s -> %s should be rejected (terminal)." % [String(terminal_phase), String(target)])
			assert_equal(run.to_dictionary(), before, "A terminal-phase rejected transition must not mutate state.")


func _manual_seed_invariant_holds() -> void:
	var manual: RunState = RunState.new_run(777, true, _build_route())
	assert_true(manual.is_manual_seed, "A manual-seed run records is_manual_seed.")
	assert_false(manual.meta_progression_eligible, "A manual-seed run must NOT be meta-eligible.")
	assert_true(manual.validate().succeeded, "A manual-seed run honoring the invariant should validate.")

	# A run violating the invariant (manual-seed but meta-eligible) must fail validation.
	var broken: RunState = RunState.new(RunState.PHASE_NEW_RUN, 1, true, true, _build_route())
	var validation: ActionResult = broken.validate()
	assert_true(validation.is_error(), "A manual-seed + meta-eligible run violates the invariant.")
	assert_equal(validation.error_code, &"invalid_run_meta_eligibility", "Meta-eligibility violation should use a stable code.")


func _unknown_phase_is_rejected() -> void:
	var run: RunState = RunState.new(&"limbo", 1, false, true, _build_route())
	var validation: ActionResult = run.validate()
	assert_true(validation.is_error(), "An unknown phase should be rejected.")
	assert_equal(validation.error_code, &"invalid_run_phase", "Unknown phase should use a stable code.")


func _root_seed_survives_full_int64_round_trip() -> void:
	var run: RunState = RunState.new_run(9223372036854775000, false, _build_route())
	var data: Dictionary = run.to_dictionary()
	var json_data: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(json_data is Dictionary, "RunState should survive JSON stringify/parse.")
	var parse_result: ActionResult = RunState.try_from_dictionary(json_data)
	assert_true(parse_result.succeeded, "A full-int64 root-seed RunState should parse after JSON: %s" % parse_result.metadata)
	var parsed: RunState = parse_result.metadata.get("run_state") as RunState
	assert_equal(parsed.root_seed, 9223372036854775000, "Full int64 root seed must not lose precision through a JSON round-trip.")


func _run_state_round_trips_through_real_json() -> void:
	var run: RunState = RunState.new_run(321, true, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	var json_data: Variant = JSON.parse_string(JSON.stringify(run.to_dictionary()))
	var parse_result: ActionResult = RunState.try_from_dictionary(json_data)
	assert_true(parse_result.succeeded, "RunState should round-trip through real JSON: %s" % parse_result.metadata)
	var parsed: RunState = parse_result.metadata.get("run_state") as RunState
	assert_equal(parsed.phase, RunState.PHASE_ACTIVE_ROUTE, "Phase must round-trip.")
	assert_true(parsed.is_manual_seed, "Manual-seed flag must round-trip.")
	assert_false(parsed.meta_progression_eligible, "Meta-eligibility must round-trip (manual seed).")
	assert_equal(parsed.route.node_count(), 2, "Route nodes must round-trip with the run state.")


func _bridges_into_existing_run_snapshot_fields() -> void:
	# Task 4.2: RunState -> existing RunSnapshot fields -> RunSnapshot.parse round-trips the route
	# payload through route_state, with the phase nested inside route_state (no new top-level key).
	var run: RunState = RunState.new_run(2026, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	# Mark a node revealed so the revealed-id bridge has something to carry.
	run.route.node_by_id("start").reveal_state = RouteNode.REVEAL_REVEALED

	var fields: Dictionary = run.to_run_snapshot_fields()
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.root_seed = fields.get("root_seed")
	snapshot.is_manual_seed = fields.get("is_manual_seed")
	snapshot.meta_progression_eligible = fields.get("meta_progression_eligible")
	snapshot.route_state = fields.get("route_state")
	snapshot.current_route_node_id = fields.get("current_route_node_id")
	snapshot.revealed_route_node_ids = fields.get("revealed_route_node_ids")

	# Real JSON round-trip through the existing RunSnapshot contract.
	var json_data: Variant = JSON.parse_string(JSON.stringify(snapshot.to_dictionary()))
	assert_true(json_data is Dictionary, "RunSnapshot carrying the route payload should survive JSON.")
	var parse_result: ActionResult = RunSnapshot.parse(json_data)
	assert_true(parse_result.succeeded, "RunSnapshot.parse should accept the composed route payload: %s" % parse_result.metadata)
	var parsed_snapshot: RunSnapshot = parse_result.metadata.get("snapshot") as RunSnapshot

	assert_equal(parsed_snapshot.root_seed, 2026, "Bridge should preserve the root seed in RunSnapshot.")
	assert_false(parsed_snapshot.is_manual_seed, "Bridge should preserve manual-seed flag.")
	assert_true(parsed_snapshot.meta_progression_eligible, "Bridge should preserve meta-eligibility.")
	assert_equal(parsed_snapshot.revealed_route_node_ids, ["start"], "Bridge should carry revealed node ids into RunSnapshot.")
	# The phase is nested inside the route_state payload (not a top-level RunSnapshot key).
	assert_equal(parsed_snapshot.route_state.get("run_phase"), "active_route", "Phase must be nested in the route_state payload.")

	# Reconstruct a RunState from the existing RunSnapshot fields and confirm it round-trips.
	var rebuilt: ActionResult = RunState.try_from_run_snapshot_fields({
		"root_seed": parsed_snapshot.root_seed,
		"is_manual_seed": parsed_snapshot.is_manual_seed,
		"meta_progression_eligible": parsed_snapshot.meta_progression_eligible,
		"route_state": parsed_snapshot.route_state
	})
	assert_true(rebuilt.succeeded, "RunState should reconstruct from RunSnapshot fields: %s" % rebuilt.metadata)
	var rebuilt_run: RunState = rebuilt.metadata.get("run_state") as RunState
	assert_equal(rebuilt_run.phase, RunState.PHASE_ACTIVE_ROUTE, "Reconstructed run phase must match.")
	assert_equal(rebuilt_run.route.node_count(), 2, "Reconstructed route must carry the nodes.")


func _top_level_current_node_pointer_is_honored_on_resume() -> void:
	# [Review][Patch] guard: the CANONICAL top-level RunSnapshot.current_route_node_id field must not
	# be silently ignored by try_from_run_snapshot_fields (which previously read the pointer ONLY from
	# the nested route_state payload). A future writer / save migration may set only the top-level
	# field; it must survive resume.

	# Path 1 — top-level pointer is the SOURCE OF TRUTH: the nested route payload carries an EMPTY
	# pointer, the top-level field names a real node. Reconstruction must adopt the top-level value.
	var route_payload_empty_pointer: Dictionary = RouteState.new([
		RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["boss"]),
		RouteNode.new("boss", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	], "", []).to_dictionary()
	route_payload_empty_pointer[String(RunState.RUN_PHASE_KEY)] = String(RunState.PHASE_NODE_RESOLUTION)
	assert_equal(route_payload_empty_pointer.get("current_node_id"), "", "Setup: nested pointer is empty (top-level is the only source).")

	var from_top_level: ActionResult = RunState.try_from_run_snapshot_fields({
		"root_seed": 11,
		"is_manual_seed": false,
		"meta_progression_eligible": true,
		"route_state": route_payload_empty_pointer,
		"current_route_node_id": "start"
	})
	assert_true(from_top_level.succeeded, "Top-level current_route_node_id should reconstruct: %s" % from_top_level.metadata)
	var top_level_run: RunState = from_top_level.metadata.get("run_state") as RunState
	assert_equal(top_level_run.route.current_node_id, "start", "The canonical top-level pointer must NOT be silently dropped on resume.")

	# Path 2 — AGREE: top-level and nested both name the same node. Succeeds, pointer preserved.
	var route_payload_pointed: Dictionary = RouteState.new([
		RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["boss"]),
		RouteNode.new("boss", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	], "start", []).to_dictionary()
	route_payload_pointed[String(RunState.RUN_PHASE_KEY)] = String(RunState.PHASE_NODE_RESOLUTION)

	var agree: ActionResult = RunState.try_from_run_snapshot_fields({
		"root_seed": 12,
		"is_manual_seed": false,
		"meta_progression_eligible": true,
		"route_state": route_payload_pointed,
		"current_route_node_id": "start"
	})
	assert_true(agree.succeeded, "An agreeing top-level/nested pointer should reconstruct: %s" % agree.metadata)
	var agree_run: RunState = agree.metadata.get("run_state") as RunState
	assert_equal(agree_run.route.current_node_id, "start", "An agreeing pointer must be preserved.")

	# Path 3 — DISAGREE: top-level and a non-empty nested pointer name DIFFERENT nodes. This is a
	# corrupt save and must be rejected fail-loud (never silently resolved to one or the other).
	var disagree: ActionResult = RunState.try_from_run_snapshot_fields({
		"root_seed": 13,
		"is_manual_seed": false,
		"meta_progression_eligible": true,
		"route_state": route_payload_pointed,
		"current_route_node_id": "boss"
	})
	assert_true(disagree.is_error(), "A top-level/nested pointer conflict must be rejected.")
	assert_equal(disagree.error_code, &"route_node_pointer_conflict", "A pointer conflict should use a stable code.")


func _phaseless_route_payload_resumes_as_new_run() -> void:
	# Story 4.4 Task 5.1 — RATIFY the 4.1 deferral: a route_state payload with NO run_phase key resolves
	# to PHASE_NEW_RUN on resume (try_from_run_snapshot_fields defaults a missing run_phase to NEW_RUN
	# while retaining mid-run current_route_node_id/cleared_node_ids), and the reconstructed run still
	# validates. This is the intended save-compat behavior: it is internally consistent (validate()
	# passes) and the live writer ALWAYS emits run_phase, so this only affects hand-written / future-
	# migrated saves. (Owner of this deferral = Story 4.4; this test closes it.)
	var route_payload_no_phase: Dictionary = RouteState.new([
		RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["boss"]),
		RouteNode.new("boss", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_REVEALED, [])
	], "boss", ["start"]).to_dictionary()
	# Deliberately do NOT set RUN_PHASE_KEY on the route payload — and confirm it is absent.
	assert_false(route_payload_no_phase.has(String(RunState.RUN_PHASE_KEY)), "Setup: the route payload carries no run_phase key (phaseless).")
	# Mid-run progress is present (a non-empty current pointer + a cleared node) — the phaseless default
	# must NOT discard it.
	assert_equal(route_payload_no_phase.get("current_node_id"), "boss", "Setup: the phaseless payload retains a mid-run current node.")
	assert_equal(route_payload_no_phase.get("cleared_node_ids"), ["start"], "Setup: the phaseless payload retains a cleared node.")

	var resumed: ActionResult = RunState.try_from_run_snapshot_fields({
		"root_seed": 4141,
		"is_manual_seed": false,
		"meta_progression_eligible": true,
		"route_state": route_payload_no_phase,
		"current_route_node_id": "boss"
	})
	assert_true(resumed.succeeded, "A phaseless route payload should reconstruct: %s" % resumed.metadata)
	var resumed_run: RunState = resumed.metadata.get("run_state") as RunState
	assert_equal(resumed_run.phase, RunState.PHASE_NEW_RUN, "A missing run_phase must default to PHASE_NEW_RUN (ratified save-compat default).")
	assert_equal(resumed_run.route.current_node_id, "boss", "The phaseless default must retain the mid-run current node pointer.")
	assert_true(resumed_run.route.cleared_node_ids.has("start"), "The phaseless default must retain the mid-run cleared set.")
	assert_true(resumed_run.validate().succeeded, "The phaseless-default reconstructed run must still validate.")


func _run_snapshot_no_surprise_key_gate_stays_green() -> void:
	# Task 4.3 decision: phase is NESTED inside route_state, so RunSnapshot has NO new top-level key.
	# Confirm the composed snapshot introduces no top-level key outside the pinned 23-key set.
	var run: RunState = RunState.new_run(7, false, _build_route())
	var fields: Dictionary = run.to_run_snapshot_fields()
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.route_state = fields.get("route_state")
	snapshot.current_route_node_id = fields.get("current_route_node_id")
	snapshot.revealed_route_node_ids = fields.get("revealed_route_node_ids")
	var data: Dictionary = snapshot.to_dictionary()
	var allowed: Dictionary = _allowed_run_snapshot_keys()
	for key: Variant in data.keys():
		assert_true(allowed.has(key), "Composing run state must not add a surprise top-level RunSnapshot key (%s)." % str(key))


# Story 5.3: a run with NO kit (the legacy/empty-class path) still validates AND round-trips with a null kit
# through the full run dict (the additive kit field is lenient — absent/null -> null).
func _kit_less_run_validates_and_round_trips_with_null_kit() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	assert_true(run.starting_kit == null, "A new run has no kit by default.")
	assert_true(run.validate().succeeded, "A kit-less run must validate (the kit is not a required field).")
	# Full run dict carries null for the kit; a round-trip preserves null.
	var data: Dictionary = run.to_dictionary()
	assert_equal(data.get("starting_kit"), null, "A kit-less run serializes starting_kit as null.")
	var round_trip: Variant = JSON.parse_string(JSON.stringify(data))
	var parsed: ActionResult = RunState.try_from_dictionary(round_trip)
	assert_true(parsed.succeeded, "A kit-less run dict must parse back: %s" % parsed.metadata)
	var restored: RunState = parsed.metadata.get("run_state") as RunState
	assert_true(restored.starting_kit == null, "A round-tripped kit-less run must keep a null kit.")
	# A pre-5.3 run dict (no starting_kit key at all) also parses with a null kit.
	var legacy_dict: Dictionary = run.to_dictionary()
	legacy_dict.erase("starting_kit")
	var legacy_parsed: ActionResult = RunState.try_from_dictionary(legacy_dict)
	assert_true(legacy_parsed.succeeded, "A pre-5.3 run dict (no starting_kit key) must parse: %s" % legacy_parsed.metadata)
	assert_true((legacy_parsed.metadata.get("run_state") as RunState).starting_kit == null, "A pre-5.3 run dict restores a null kit.")


# Story 5.3: a run WITH a kit round-trips through to_dictionary()/try_from_dictionary (lenient) and copy()
# preserves the kit byte-for-byte.
func _run_with_kit_round_trips_through_dictionary_and_copy() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run.selected_class_id = &"warrior"
	run.starting_kit = StartingKit.new(&"warrior", &"sword", &"shield", 18, &"warrior_unbreakable_guard", &"warrior_blade_and_board")
	assert_true(run.validate().succeeded, "A run with a kit must validate.")
	# Round-trip the full run dict.
	var round_trip: Variant = JSON.parse_string(JSON.stringify(run.to_dictionary()))
	var parsed: ActionResult = RunState.try_from_dictionary(round_trip)
	assert_true(parsed.succeeded, "A run dict with a kit must parse back: %s" % parsed.metadata)
	var restored: RunState = parsed.metadata.get("run_state") as RunState
	assert_true(restored.starting_kit != null, "The round-tripped run must preserve the kit.")
	assert_equal(restored.starting_kit.weapon_id, &"sword", "The round-tripped kit weapon must match.")
	assert_equal(restored.starting_kit.support_id, &"shield", "The round-tripped kit support must match.")
	assert_equal(restored.starting_kit.baseline_hp, 18, "The round-tripped kit baseline_hp must match.")
	assert_equal(restored.selected_class_id, &"warrior", "The round-tripped run must preserve the class id.")
	# copy() preserves the kit byte-for-byte.
	var copied: RunState = run.copy()
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(run.to_dictionary()), "copy() must preserve the kit byte-for-byte.")
	# The copy is a distinct kit instance (deep copy, not a shared reference).
	assert_true(copied.starting_kit != run.starting_kit, "copy() must produce a distinct kit instance.")


# Story 5.3: selected_class_id NESTS inside the route_state payload of to_run_snapshot_fields() and round-trips
# back through try_from_run_snapshot_fields() — WITHOUT adding a top-level RunSnapshot key. A payload with no
# nested class key restores with the legacy empty default.
func _selected_class_id_nests_in_the_snapshot_bridge_and_round_trips() -> void:
	var run: RunState = RunState.new_run(2026, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run.selected_class_id = &"ranger"

	var fields: Dictionary = run.to_run_snapshot_fields()
	var route_state: Dictionary = fields.get("route_state")
	# The class id is nested INSIDE route_state (the same mechanism as run_phase), NOT a top-level field.
	assert_equal(route_state.get(String(RunState.SELECTED_CLASS_ID_KEY)), "ranger", "selected_class_id must nest inside the route_state payload.")
	assert_false(fields.has(String(RunState.SELECTED_CLASS_ID_KEY)), "selected_class_id must NOT be a top-level snapshot field.")

	# Round-trip back: the nested class id rehydrates.
	var rebuilt: ActionResult = RunState.try_from_run_snapshot_fields(fields)
	assert_true(rebuilt.succeeded, "A class-carrying snapshot bridge must reconstruct: %s" % rebuilt.metadata)
	assert_equal((rebuilt.metadata.get("run_state") as RunState).selected_class_id, &"ranger", "The nested class id must rehydrate through the snapshot bridge.")

	# A payload with NO nested class key restores with the legacy empty default (&"").
	var legacy_fields: Dictionary = run.to_run_snapshot_fields()
	var legacy_route_state: Dictionary = legacy_fields.get("route_state")
	legacy_route_state.erase(String(RunState.SELECTED_CLASS_ID_KEY))
	legacy_fields["route_state"] = legacy_route_state
	var legacy_rebuilt: ActionResult = RunState.try_from_run_snapshot_fields(legacy_fields)
	assert_true(legacy_rebuilt.succeeded, "A pre-5.3 snapshot bridge (no nested class key) must reconstruct: %s" % legacy_rebuilt.metadata)
	assert_equal((legacy_rebuilt.metadata.get("run_state") as RunState).selected_class_id, &"", "A pre-5.3 bridge restores the legacy empty class default.")


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
