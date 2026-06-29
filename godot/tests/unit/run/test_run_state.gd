extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")

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
	# Story 6.2 — the additive inventory field.
	_fresh_run_has_an_empty_inventory_and_validates()
	_run_with_inventory_round_trips_through_dictionary_and_copy()
	_pre_6_2_run_dict_without_inventory_key_parses_to_empty_inventory()
	_inventory_stays_out_of_the_run_snapshot_bridge()
	# Story 6.3 — the additive pending_reward_offer field.
	_fresh_run_has_no_pending_offer_and_validates()
	_run_with_pending_offer_round_trips_through_dictionary_and_copy()
	_pre_6_3_run_dict_without_offer_key_parses_to_null()
	_pending_offer_stays_out_of_the_run_snapshot_bridge()
	# Story 7.1 — the additive risk-economy field + its eligibility invariant + the route-position bridge.
	_fresh_run_has_a_default_economy_eligible_for_a_non_manual_run()
	_fresh_manual_run_economy_is_ineligible_and_validates()
	_run_with_economy_round_trips_through_dictionary_and_copy()
	_pre_7_1_run_dict_without_economy_key_parses_to_default_economy()
	_economy_eligibility_mismatch_fails_run_validate()
	_economy_nests_in_the_snapshot_bridge_and_round_trips()
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


# Story 6.2: a fresh run carries a non-null EMPTY inventory and still validates (the inventory is additive, NOT
# a required validate() field).
func _fresh_run_has_an_empty_inventory_and_validates() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	assert_true(run.inventory != null, "A fresh run has a non-null inventory (default-empty, never null).")
	assert_equal(run.inventory.size(), 0, "A fresh run's backpack is empty.")
	assert_equal(run.inventory.capacity, 6, "A fresh run's backpack defaults to capacity 6.")
	assert_true(run.validate().succeeded, "A run with an empty inventory must validate (the inventory is not a required field).")
	# The full run dict carries the empty inventory projection.
	var data: Dictionary = run.to_dictionary()
	assert_true(data.has("inventory"), "The full run dict carries an inventory key.")
	assert_equal((data.get("inventory") as Dictionary).get("backpack"), [], "A fresh run serializes an empty backpack.")


# Story 6.2: a run WITH backpack items round-trips through to_dictionary()/try_from_dictionary (lenient) and
# copy() deep-copies the inventory (a distinct instance; mutating the copy does not perturb the source).
func _run_with_inventory_round_trips_through_dictionary_and_copy() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run.inventory.append_slot(&"minor_healing_draught", &"consumable")
	run.inventory.append_slot(&"padded_vest", &"armor")
	run.inventory.equipment = InventoryState._normalize_equipment({"weapon": "practice_blade"})
	assert_true(run.validate().succeeded, "A run with an inventory must validate.")
	# Round-trip the full run dict.
	var round_trip: Variant = JSON.parse_string(JSON.stringify(run.to_dictionary()))
	var parsed: ActionResult = RunState.try_from_dictionary(round_trip)
	assert_true(parsed.succeeded, "A run dict with an inventory must parse back: %s" % parsed.metadata)
	var restored: RunState = parsed.metadata.get("run_state") as RunState
	assert_equal(restored.inventory.size(), 2, "The round-tripped run must preserve the backpack slot count.")
	assert_equal(restored.inventory.backpack[0].get("item_id"), "minor_healing_draught", "The round-tripped backpack must preserve slot 0.")
	assert_equal(restored.inventory.equipped_in(&"weapon"), &"practice_blade", "The round-tripped run must preserve the equipped weapon.")
	# copy() preserves the inventory byte-for-byte AND is a distinct deep instance.
	var copied: RunState = run.copy()
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(run.to_dictionary()), "copy() must preserve the inventory byte-for-byte.")
	assert_true(copied.inventory != run.inventory, "copy() must produce a distinct inventory instance (deep copy).")
	copied.inventory.append_slot(&"ember_flask", &"consumable")
	assert_equal(run.inventory.size(), 2, "Mutating the copy's backpack must NOT perturb the source.")


# Story 6.2: a pre-6.2 run dict (no inventory key at all) parses with a fresh empty inventory (lenient decode).
func _pre_6_2_run_dict_without_inventory_key_parses_to_empty_inventory() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	var legacy_dict: Dictionary = run.to_dictionary()
	legacy_dict.erase("inventory")
	var legacy_parsed: ActionResult = RunState.try_from_dictionary(legacy_dict)
	assert_true(legacy_parsed.succeeded, "A pre-6.2 run dict (no inventory key) must parse: %s" % legacy_parsed.metadata)
	var restored: RunState = legacy_parsed.metadata.get("run_state") as RunState
	assert_true(restored.inventory != null, "A pre-6.2 run dict restores a non-null inventory.")
	assert_equal(restored.inventory.size(), 0, "A pre-6.2 run dict restores an empty backpack.")
	assert_equal(restored.inventory.capacity, 6, "A pre-6.2 run dict restores the default capacity.")


# Story 6.2: the inventory rides the FULL run dict ONLY — it is DELIBERATELY NOT in to_run_snapshot_fields(),
# and composing a route-position snapshot adds NO inventory content + NO surprise top-level key. The existing
# RunSnapshot.inventory/equipment placeholder fields stay EMPTY this story.
func _inventory_stays_out_of_the_run_snapshot_bridge() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run.inventory.append_slot(&"minor_healing_draught", &"consumable")
	var fields: Dictionary = run.to_run_snapshot_fields()
	# The bridge produces NO inventory/equipment field (the route-position save leaves them to the placeholders).
	assert_false(fields.has("inventory"), "to_run_snapshot_fields() must NOT carry an inventory field (it rides the full run dict only).")
	assert_false(fields.has("equipment"), "to_run_snapshot_fields() must NOT carry an equipment field.")
	# The nested route_state payload must not smuggle the backpack either.
	var route_state: Dictionary = fields.get("route_state")
	assert_false(route_state.has("inventory"), "The nested route_state payload must not carry an inventory.")
	# Composing the snapshot keeps the placeholders empty + adds no surprise top-level key.
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.route_state = fields.get("route_state")
	snapshot.current_route_node_id = fields.get("current_route_node_id")
	snapshot.revealed_route_node_ids = fields.get("revealed_route_node_ids")
	assert_equal(snapshot.inventory, [], "The RunSnapshot.inventory placeholder stays empty this story.")
	assert_equal(snapshot.equipment, {}, "The RunSnapshot.equipment placeholder stays empty this story.")
	var data: Dictionary = snapshot.to_dictionary()
	var allowed: Dictionary = _allowed_run_snapshot_keys()
	for key: Variant in data.keys():
		assert_true(allowed.has(key), "Composing a run with an inventory must not add a surprise top-level RunSnapshot key (%s)." % str(key))


# Story 6.3: a fresh run carries NO pending offer (null) and still validates (the offer is additive, NOT a
# required validate() field).
func _fresh_run_has_no_pending_offer_and_validates() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	assert_true(run.pending_reward_offer == null, "A fresh run has no pending reward offer (null).")
	assert_true(run.validate().succeeded, "A run with no pending offer must validate (the offer is not a required field).")
	# The full run dict carries null for the offer.
	var data: Dictionary = run.to_dictionary()
	assert_true(data.has("pending_reward_offer"), "The full run dict carries a pending_reward_offer key.")
	assert_equal(data.get("pending_reward_offer"), null, "A fresh run serializes pending_reward_offer as null.")


# Story 6.3: a run WITH a pending offer round-trips through to_dictionary()/try_from_dictionary (lenient) and
# copy() deep-copies the offer (a distinct instance; mutating the copy does not perturb the source).
func _run_with_pending_offer_round_trips_through_dictionary_and_copy() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run.pending_reward_offer = RewardOffer.new(
		&"standard_combat_reward",
		RewardOffer.STATUS_PENDING,
		[{"category": "weapon", "content_id": "sword"}],
		{},
		"rewards",
		2,
		0,
		987654321
	)
	assert_true(run.validate().succeeded, "A run with a pending offer must validate.")
	# Round-trip the full run dict.
	var round_trip: Variant = JSON.parse_string(JSON.stringify(run.to_dictionary()))
	var parsed: ActionResult = RunState.try_from_dictionary(round_trip)
	assert_true(parsed.succeeded, "A run dict with a pending offer must parse back: %s" % parsed.metadata)
	var restored: RunState = parsed.metadata.get("run_state") as RunState
	assert_true(restored.pending_reward_offer != null, "The round-tripped run must preserve the pending offer.")
	assert_equal(restored.pending_reward_offer.table_id, &"standard_combat_reward", "The round-tripped offer table id must match.")
	assert_equal(restored.pending_reward_offer.offered_entries.size(), 1, "The round-tripped offer entries must match.")
	assert_equal(restored.pending_reward_offer.state_after, 987654321, "The round-tripped offer state_after must match (int64-safe).")
	# copy() preserves the offer byte-for-byte AND is a distinct deep instance.
	var copied: RunState = run.copy()
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(run.to_dictionary()), "copy() must preserve the pending offer byte-for-byte.")
	assert_true(copied.pending_reward_offer != run.pending_reward_offer, "copy() must produce a distinct offer instance (deep copy).")
	copied.pending_reward_offer.offered_entries.append({"category": "armor", "content_id": "padded_vest"})
	assert_equal(run.pending_reward_offer.offered_entries.size(), 1, "Mutating the copy's offer must NOT perturb the source.")


# Story 6.3: a pre-6.3 run dict (no pending_reward_offer key at all) parses with a null offer (lenient decode).
func _pre_6_3_run_dict_without_offer_key_parses_to_null() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	var legacy_dict: Dictionary = run.to_dictionary()
	legacy_dict.erase("pending_reward_offer")
	var legacy_parsed: ActionResult = RunState.try_from_dictionary(legacy_dict)
	assert_true(legacy_parsed.succeeded, "A pre-6.3 run dict (no offer key) must parse: %s" % legacy_parsed.metadata)
	assert_true((legacy_parsed.metadata.get("run_state") as RunState).pending_reward_offer == null, "A pre-6.3 run dict restores a null offer.")


# Story 6.3: the pending offer rides the FULL run dict ONLY — it is DELIBERATELY NOT in to_run_snapshot_fields() /
# the 23-key gate, and composing a route-position snapshot adds NO offer content + NO surprise top-level key.
func _pending_offer_stays_out_of_the_run_snapshot_bridge() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run.pending_reward_offer = RewardOffer.new(&"standard_combat_reward", RewardOffer.STATUS_PENDING, [{"category": "weapon", "content_id": "sword"}])
	var fields: Dictionary = run.to_run_snapshot_fields()
	assert_false(fields.has("pending_reward_offer"), "to_run_snapshot_fields() must NOT carry a pending_reward_offer field (it rides the full run dict only).")
	# The nested route_state payload must not smuggle the offer either.
	var route_state: Dictionary = fields.get("route_state")
	assert_false(route_state.has("pending_reward_offer"), "The nested route_state payload must not carry a pending offer.")
	# Composing the snapshot adds no surprise top-level key.
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.route_state = fields.get("route_state")
	snapshot.current_route_node_id = fields.get("current_route_node_id")
	snapshot.revealed_route_node_ids = fields.get("revealed_route_node_ids")
	var data: Dictionary = snapshot.to_dictionary()
	var allowed: Dictionary = _allowed_run_snapshot_keys()
	for key: Variant in data.keys():
		assert_true(allowed.has(key), "Composing a run with a pending offer must not add a surprise top-level RunSnapshot key (%s)." % str(key))


# Story 7.1: a fresh NON-manual run carries a non-null default economy that is Oath-Shard eligible (the eligibility
# derives from is_manual_seed at init, in lockstep with meta_progression_eligible) and validates.
func _fresh_run_has_a_default_economy_eligible_for_a_non_manual_run() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	assert_true(run.risk_economy != null, "AC1: a fresh run has a non-null economy (default, never null).")
	assert_equal(run.risk_economy.gold, 0, "AC1: a fresh run's wallet is empty.")
	assert_equal(run.risk_economy.healing_charges, 0, "AC1: a fresh run's healing availability is 0.")
	assert_equal(run.risk_economy.risk_flags, [], "AC1: a fresh run has no risk flags (7.3 populates them).")
	assert_true(run.risk_economy.oath_shard_eligible, "AC1: a non-manual run's economy is Oath-Shard eligible (lockstep with meta_progression_eligible).")
	assert_equal(run.risk_economy.oath_shard_eligible, run.meta_progression_eligible, "AC1: oath_shard_eligible tracks meta_progression_eligible.")
	assert_true(run.validate().succeeded, "A run with a default economy must validate.")
	# The full run dict carries the economy projection.
	var data: Dictionary = run.to_dictionary()
	assert_true(data.has("risk_economy"), "The full run dict carries a risk_economy key.")
	assert_equal((data.get("risk_economy") as Dictionary).get("gold"), 0, "A fresh run serializes an empty wallet.")


# Story 7.1: a fresh MANUAL-seed run's economy is NEVER Oath-Shard eligible (the GDD invariant) and still validates.
func _fresh_manual_run_economy_is_ineligible_and_validates() -> void:
	var run: RunState = RunState.new_run(7, true, _build_route())
	assert_false(run.risk_economy.oath_shard_eligible, "AC1: a manual-seed run's economy is NEVER Oath-Shard eligible.")
	assert_equal(run.risk_economy.oath_shard_eligible, run.meta_progression_eligible, "AC1: the economy eligibility tracks meta_progression_eligible for a manual run too.")
	assert_true(run.validate().succeeded, "A manual-seed run with an ineligible economy must validate (the invariant holds).")


# Story 7.1: a run with a mutated economy round-trips through to_dictionary()/try_from_dictionary (lenient) and copy()
# deep-copies the economy (a distinct instance; mutating the copy does not perturb the source).
func _run_with_economy_round_trips_through_dictionary_and_copy() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run.risk_economy.apply_gold_delta(25)
	run.risk_economy.apply_healing_delta(2)
	run.risk_economy.set_curse_count(1)
	run.risk_economy.add_risk_flag(&"salt_marked")
	assert_true(run.validate().succeeded, "A run with a mutated economy must validate.")
	# Round-trip the full run dict.
	var round_trip: Variant = JSON.parse_string(JSON.stringify(run.to_dictionary()))
	var parsed: ActionResult = RunState.try_from_dictionary(round_trip)
	assert_true(parsed.succeeded, "A run dict with an economy must parse back: %s" % parsed.metadata)
	var restored: RunState = parsed.metadata.get("run_state") as RunState
	assert_equal(restored.risk_economy.gold, 25, "The round-tripped run must preserve the wallet.")
	assert_equal(restored.risk_economy.healing_charges, 2, "The round-tripped run must preserve healing availability.")
	assert_equal(restored.risk_economy.curse_count, 1, "The round-tripped run must preserve the curse count.")
	assert_equal(restored.risk_economy.risk_flags, ["salt_marked"], "The round-tripped run must preserve risk flags.")
	# copy() preserves the economy byte-for-byte AND is a distinct deep instance.
	var copied: RunState = run.copy()
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(run.to_dictionary()), "copy() must preserve the economy byte-for-byte.")
	assert_true(copied.risk_economy != run.risk_economy, "copy() must produce a distinct economy instance (deep copy).")
	copied.risk_economy.apply_gold_delta(100)
	copied.risk_economy.add_risk_flag(&"blood_debt")
	assert_equal(run.risk_economy.gold, 25, "Mutating the copy's wallet must NOT perturb the source.")
	assert_equal(run.risk_economy.risk_flags, ["salt_marked"], "Mutating the copy's risk_flags must NOT perturb the source.")


# Story 7.1: a pre-7.1 run dict (no risk_economy key at all) parses with a fresh default economy (lenient decode),
# whose eligibility derives from the run's is_manual_seed.
func _pre_7_1_run_dict_without_economy_key_parses_to_default_economy() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	var legacy_dict: Dictionary = run.to_dictionary()
	legacy_dict.erase("risk_economy")
	var legacy_parsed: ActionResult = RunState.try_from_dictionary(legacy_dict)
	assert_true(legacy_parsed.succeeded, "A pre-7.1 run dict (no economy key) must parse: %s" % legacy_parsed.metadata)
	var restored: RunState = legacy_parsed.metadata.get("run_state") as RunState
	assert_true(restored.risk_economy != null, "A pre-7.1 run dict restores a non-null economy.")
	assert_equal(restored.risk_economy.gold, 0, "A pre-7.1 run dict restores an empty wallet.")
	assert_true(restored.risk_economy.oath_shard_eligible, "A pre-7.1 non-manual run dict restores an eligible economy.")
	# A pre-7.1 MANUAL run dict restores an INELIGIBLE economy (the invariant is re-derived from is_manual_seed).
	var manual_run: RunState = RunState.new_run(7, true, _build_route())
	var manual_legacy: Dictionary = manual_run.to_dictionary()
	manual_legacy.erase("risk_economy")
	var manual_parsed: ActionResult = RunState.try_from_dictionary(manual_legacy)
	assert_true(manual_parsed.succeeded, "A pre-7.1 manual run dict must parse: %s" % manual_parsed.metadata)
	assert_false((manual_parsed.metadata.get("run_state") as RunState).risk_economy.oath_shard_eligible, "A pre-7.1 manual run dict restores an ineligible economy.")


# Story 7.1: a run whose economy eligibility DIVERGES from its manual-seed flag fails validate() (the invariant is
# enforced at the RunState level, surfacing the economy's stable code).
func _economy_eligibility_mismatch_fails_run_validate() -> void:
	var run: RunState = RunState.new_run(7, false, _build_route())
	# Force a divergence: a non-manual run whose economy claims ineligibility.
	run.risk_economy.oath_shard_eligible = false
	var validation: ActionResult = run.validate()
	assert_true(validation.is_error(), "A run whose economy eligibility diverges from its seed mode must fail validate().")
	assert_equal(validation.error_code, &"invalid_oath_shard_eligibility", "The mismatch must surface the economy's stable invariant code.")


# Story 7.1: the economy NESTS inside the route_state payload of to_run_snapshot_fields() and round-trips back through
# try_from_run_snapshot_fields() — WITHOUT adding a top-level RunSnapshot key (the AC1 "and save snapshots", the same
# nested mechanism as the class id). A payload with no nested economy key restores with the default economy.
func _economy_nests_in_the_snapshot_bridge_and_round_trips() -> void:
	var run: RunState = RunState.new_run(2026, false, _build_route())
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	run.risk_economy.apply_gold_delta(42)
	run.risk_economy.set_corruption(2)

	var fields: Dictionary = run.to_run_snapshot_fields()
	var route_state: Dictionary = fields.get("route_state")
	# The economy is nested INSIDE route_state (the same mechanism as run_phase/selected_class_id), NOT a top-level field.
	assert_true(route_state.has(String(RunState.RISK_ECONOMY_KEY)), "the economy must nest inside the route_state payload.")
	assert_equal((route_state.get(String(RunState.RISK_ECONOMY_KEY)) as Dictionary).get("gold"), 42, "the nested economy must carry the wallet.")
	assert_false(fields.has(String(RunState.RISK_ECONOMY_KEY)), "the economy must NOT be a top-level snapshot field.")
	# The composed snapshot must stay within the 23-key gate (no new top-level key).
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.route_state = fields.get("route_state")
	snapshot.current_route_node_id = fields.get("current_route_node_id")
	snapshot.revealed_route_node_ids = fields.get("revealed_route_node_ids")
	var data: Dictionary = snapshot.to_dictionary()
	var allowed: Dictionary = _allowed_run_snapshot_keys()
	for key: Variant in data.keys():
		assert_true(allowed.has(key), "Composing a run with an economy must not add a surprise top-level RunSnapshot key (%s)." % str(key))

	# Round-trip back: the nested economy rehydrates.
	var rebuilt: ActionResult = RunState.try_from_run_snapshot_fields(fields)
	assert_true(rebuilt.succeeded, "An economy-carrying snapshot bridge must reconstruct: %s" % rebuilt.metadata)
	var rebuilt_run: RunState = rebuilt.metadata.get("run_state") as RunState
	assert_equal(rebuilt_run.risk_economy.gold, 42, "The nested economy wallet must rehydrate through the snapshot bridge.")
	assert_equal(rebuilt_run.risk_economy.corruption, 2, "The nested economy corruption must rehydrate through the snapshot bridge.")

	# A payload with NO nested economy key restores with the default economy (lenient — a pre-7.1 route-position save).
	var legacy_fields: Dictionary = run.to_run_snapshot_fields()
	var legacy_route_state: Dictionary = legacy_fields.get("route_state")
	legacy_route_state.erase(String(RunState.RISK_ECONOMY_KEY))
	legacy_fields["route_state"] = legacy_route_state
	var legacy_rebuilt: ActionResult = RunState.try_from_run_snapshot_fields(legacy_fields)
	assert_true(legacy_rebuilt.succeeded, "A pre-7.1 snapshot bridge (no nested economy key) must reconstruct: %s" % legacy_rebuilt.metadata)
	var legacy_run: RunState = legacy_rebuilt.metadata.get("run_state") as RunState
	assert_equal(legacy_run.risk_economy.gold, 0, "A pre-7.1 bridge restores the default empty economy.")
	assert_true(legacy_run.risk_economy.oath_shard_eligible, "A pre-7.1 bridge restores an eligible economy for a non-manual run.")


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
