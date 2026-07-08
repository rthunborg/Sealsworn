extends "res://tests/unit/test_case.gd"

# Story 11.3 Task 1 — RunFlowController (AC1): the scene-free run-flow SEQUENCER that COMPOSES the 11.2-inherited
# live-pre-boss + boss-auto-play seam into ONE hands-off start -> boss -> victory play flow (the single most
# load-bearing cross-story constraint for 11.3 — 11.2 left the live pre-boss path and the boss auto-play
# INTENTIONALLY un-composed; composing them at the orchestration layer is 11.3's concern). The presenters DRIVE
# this controller; it SEQUENCES the EXISTING orchestrator live methods (it adds NO new run logic, mints no event,
# owns no run truth — the RunOrchestrator + the Epic-1..9 commands own all state) and computes the run-end
# RunEndOutcome + the destination stage via RunFlowRouter.
#
# This test proves (headlessly — the controller is scene-free RefCounted, driven by an explicit call, exactly as
# 11.2's live loop is driven by an auto-play driver): a fresh start seats a run; the composed hands-off flow
# drives the live pre-boss nodes THEN the boss fight to a run-END; the terminal RunEndOutcome routes to the
# outpost destination -> the run_end stage; a fail-closed guard on an unstarted controller. Uses the VERIFIED
# finale seed 4242 (the approved-seed-catalog discipline — the scripted hero is deterministic but not
# universally-winning; the hands-off/smoke path uses a verified seed).

const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunEndProfileBridge = preload("res://scripts/ui/flow/run_end_profile_bridge.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")

# Story 11.5: a throwaway profile path for the finalize_run_end bridge seam (so the controller test does not touch the
# real user://profile.json).
const BRIDGE_PROFILE_PATH := "user://test_run_flow_controller_bridge_profile.json"

# The canonical finale seed (test_finale_full_run's verified seed; the boss auto-play reaches victory on it). Its
# depth-0 combat start node a strong sword hero clears live (the approved-seed-catalog discipline).
const FINALE_SEED: int = 4242

func run() -> Dictionary:
	_fresh_start_seats_a_run()
	_hands_off_full_run_reaches_a_terminal_outcome_and_routes_to_outpost()
	_unstarted_controller_is_fail_closed()
	_run_end_outcome_routes_off_next_destination()
	_current_node_needs_board_gates_the_depth_0_opener()
	_current_node_needs_board_is_fail_closed_off_a_run()
	# Story 11.5 — the run-end -> profile bridge seam (finalize_run_end) + the sequence-id accessor
	_finalize_run_end_builds_the_outpost_off_a_terminal_run()
	_finalize_run_end_is_null_on_an_unstarted_controller()
	_next_sequence_id_is_a_readonly_cursor_past_the_start()
	# Story 12.2 (AC1) — the live-combat loadout accessors are now KIT-DERIVED (the 11.2 boundary revision).
	_hero_loadout_accessors_derive_from_the_class_kit()
	_hero_hp_falls_back_to_the_driver_default_on_a_kitless_run()
	_hands_off_flow_stays_on_the_tuned_default_loadout()
	_cleanup()
	return result()


# AC1: start(root_seed, is_manual_seed, class_id) seats a fresh run through the AUTHORITATIVE fail-closed
# RunOrchestrator.start. The controller holds the live run handle; the domain owns the state.
func _fresh_start_seats_a_run() -> void:
	var controller: RunFlowController = RunFlowController.new()
	var start: Dictionary = controller.start(FINALE_SEED, false, &"warrior")
	assert_equal(start.get("started"), true, "A valid start must seat a run.")
	assert_true(controller.run() != null, "The controller must expose the seated run handle.")
	assert_equal(String(controller.run().selected_class_id), "warrior", "The seated run must record the selected class.")
	assert_false(controller.run().is_terminal(), "A fresh run is not terminal.")


# AC1 (the composition crux): the hands-off flow drives the live pre-boss nodes THEN the boss fight to a run-END
# (a SINGLE composed start -> boss -> victory play flow — the seam 11.2 left un-composed). On the verified finale
# seed the run reaches a terminal PHASE_COMPLETED (boss victory) and the RunEndOutcome routes to the outpost.
func _hands_off_full_run_reaches_a_terminal_outcome_and_routes_to_outpost() -> void:
	var controller: RunFlowController = RunFlowController.new()
	assert_equal(controller.start(FINALE_SEED, false, &"warrior").get("started"), true, "Start should seat the finale-seed run.")
	var result_data: Dictionary = controller.play_hands_off_to_run_end()
	assert_true(result_data.get("ok", false), "The composed hands-off flow must reach a run-end without error: %s" % result_data)
	assert_true(controller.run().is_terminal(), "The composed flow must drive the run to a terminal state.")
	# The RunEndOutcome is surfaced + routes to the outpost destination -> the outpost stage (Story 11.5 re-pointed the
	# outpost destination from the 11.3 minimal run_end placeholder to the real OutpostViewModel-bound outpost scene).
	var outcome: Dictionary = controller.run_end_outcome()
	assert_equal(outcome.get("has_ended"), true, "A terminal run must surface an ended RunEndOutcome.")
	assert_equal(outcome.get("next_destination"), "outpost", "The run-end must route to the outpost destination.")
	assert_equal(controller.run_end_stage(), "outpost", "The run-end destination must map to the outpost flow stage (Story 11.5).")


# Fail-closed: an unstarted controller has no run + play_hands_off returns a structured not-started result (never a crash).
func _unstarted_controller_is_fail_closed() -> void:
	var controller: RunFlowController = RunFlowController.new()
	assert_true(controller.run() == null, "An unstarted controller has no run.")
	var result_data: Dictionary = controller.play_hands_off_to_run_end()
	assert_false(result_data.get("ok", true), "play_hands_off on an unstarted controller must fail-closed (not ok).")
	# The run-end outcome of an unstarted controller is the fail-closed empty fact.
	assert_equal(controller.run_end_outcome().get("has_ended"), false, "An unstarted controller surfaces the empty (not-ended) run-end fact.")
	assert_equal(controller.run_end_stage(), "", "An unstarted controller routes nowhere.")


# AC1: the run-end outcome is DERIVED from the terminal run (RunEndOutcome) and routes off next_destination —
# the controller does not re-decide the run; it reads the domain fact + maps it to a flow stage.
func _run_end_outcome_routes_off_next_destination() -> void:
	var controller: RunFlowController = RunFlowController.new()
	controller.start(FINALE_SEED, false, &"warrior")
	controller.play_hands_off_to_run_end()
	var outcome: Dictionary = controller.run_end_outcome()
	# A completed finale run reports the victory completion outcome (the RunEndOutcome COMPLETED_OUTCOMES set).
	assert_equal(outcome.get("has_ended"), true, "The finale run must have ended.")
	assert_equal(outcome.get("outcome_or_cause"), String(DomainEvent.RUN_COMPLETED_OUTCOME_VICTORY), "A boss-victory finale reports the victory outcome.")


# ⭐ H1 REGRESSION — the SHARED SEQUENCING SEAM enforces resolve-THEN-advance for the depth-0 opener. The
# on-screen path previously advanced-then-resolved: the route map offered the depth-1 successors while the
# depth-0 opening combat node (RouteGenerator GUARANTEES depth 0 is always combat; RunStartCommand parks
# current_node_id there with cleared_node_ids empty) was still unplayed, and picking a depth-1 choice made
# RouteAdvanceCommand SEAL the unplayed depth-0 node into cleared_node_ids without ever hosting it on a board.
# The presenters now consult current_node_needs_board() (this seam) BEFORE offering choices. This proves the
# depth-0 node is flagged for the board on a fresh run, and is CLEARED ONLY after a live resolution (mirroring
# run_to_completion_live's resolve-current-then-advance order) — NOT silently skipped.
func _current_node_needs_board_gates_the_depth_0_opener() -> void:
	var controller: RunFlowController = RunFlowController.new()
	assert_equal(controller.start(FINALE_SEED, false, &"warrior").get("started"), true, "Setup: the finale-seed run should seat.")
	var run: RunState = controller.run()

	# The fresh run is parked on the depth-0 opener, which the generator GUARANTEES is a combat node, still uncleared.
	var start_node_id: String = run.route.current_node_id
	assert_false(start_node_id.is_empty(), "Setup: a fresh run parks on the depth-0 start node.")
	var start_node: RouteNode = run.route.node_by_id(start_node_id)
	assert_equal(start_node.depth, 0, "Setup: the parked node is the depth-0 opener.")
	assert_equal(String(start_node.type), String(RouteNode.TYPE_COMBAT), "Setup: the depth-0 opener is always a combat node.")
	assert_false(run.route.cleared_node_ids.has(start_node_id), "Setup: the depth-0 opener starts UNCLEARED.")

	# The seam FLAGS the opener for the board: the on-screen path must PLAY it (route to the board), NOT offer past
	# it. This is the assertion the depth-0 node is not silently skipped on the on-screen path.
	assert_true(controller.current_node_needs_board(), "The unresolved depth-0 combat opener MUST be flagged for the board (resolve-then-advance) — never skipped.")

	# Play the node LIVE through the orchestrator the shell drives (the shell's resolve-current-node-live seam).
	var resolved = controller.orchestrator().resolve_current_node_live()
	assert_true(resolved.succeeded, "The live depth-0 resolution should succeed on the verified seed: %s" % resolved.metadata)
	assert_equal(String(resolved.metadata.get("resolution")), "live_combat_victory", "The depth-0 node is decided by a real board outcome (played), not skipped.")

	# NOW the opener is cleared — and it was cleared by a LIVE PLAY (NodeExitCommand on victory), NOT by an advance
	# off an unplayed node. The seam no longer flags it, so the map correctly offers the (now revealed) successors.
	assert_true(run.route.cleared_node_ids.has(start_node_id), "After a live play, the depth-0 node joins cleared_node_ids (it was HOSTED on a board, not silently sealed).")
	assert_false(controller.current_node_needs_board(), "Once the current node is played/cleared, the seam clears — the map may offer the successors.")


# Fail-closed: an unstarted controller (no seated run) reports current_node_needs_board() == false (never a crash),
# so a presenter that consults it before a run exists routes nowhere rather than dereferencing a null run.
func _current_node_needs_board_is_fail_closed_off_a_run() -> void:
	var controller: RunFlowController = RunFlowController.new()
	assert_true(controller.run() == null, "Setup: an unstarted controller has no run.")
	assert_false(controller.current_node_needs_board(), "An unstarted controller's shared seam is fail-closed (false).")


# Story 11.5 (AC-wide — the run-end -> profile bridge crux): finalize_run_end drives the caller-driven bridge off the
# controller's terminal run, building the OutpostViewModel (the profile latch recorded off the REAL terminal state + the
# run summary). This proves the controller SEAM the outpost presenter drives — the H1 retro discipline (test the shared
# bridge seam, not just the individual commands). A test-supplied bridge (a throwaway profile path) keeps it headless.
func _finalize_run_end_builds_the_outpost_off_a_terminal_run() -> void:
	_cleanup()
	var controller: RunFlowController = RunFlowController.new()
	assert_equal(controller.start(FINALE_SEED, false, &"warrior").get("started"), true, "Setup: start the finale-seed run.")
	assert_true(controller.play_hands_off_to_run_end().get("ok", false), "Setup: the hands-off flow reaches a terminal victory.")
	assert_true(controller.run().is_terminal(), "Setup: the run is terminal.")

	var bridge: RunEndProfileBridge = RunEndProfileBridge.new(ProfileRepository.new(), BRIDGE_PROFILE_PATH)
	var outpost: OutpostViewModel = controller.finalize_run_end(bridge)
	assert_true(outpost != null, "finalize_run_end builds an outpost off a terminal run.")
	var data: Dictionary = outpost.to_dictionary()
	# A finale victory -> the first-victory reveal + the run summary (has_summary).
	assert_true(bool((data.get("first_victory_beat") as Dictionary).get("has_beat")), "The finalized outpost renders the first-victory reveal (a terminal victory).")
	assert_true(bool((data.get("run_summary") as Dictionary).get("has_summary")), "The finalized outpost embeds the just-ended run summary.")


# Fail-closed: finalize_run_end on an unstarted / non-terminal controller yields null (the presenter branches on null).
func _finalize_run_end_is_null_on_an_unstarted_controller() -> void:
	_cleanup()
	var controller: RunFlowController = RunFlowController.new()
	var bridge: RunEndProfileBridge = RunEndProfileBridge.new(ProfileRepository.new(), BRIDGE_PROFILE_PATH)
	assert_true(controller.finalize_run_end(bridge) == null, "finalize_run_end on an unstarted controller yields null (fail-closed).")

	assert_equal(controller.start(FINALE_SEED, false, &"warrior").get("started"), true, "Setup: seat a fresh (non-terminal) run.")
	assert_true(controller.finalize_run_end(bridge) == null, "finalize_run_end on a non-terminal run yields null (fail-closed).")


# Story 11.5: next_sequence_id() (the additive read-only accessor the bridge threads) is the run-level cursor — it starts
# past the run-start emitted ids and does NOT advance on read (a pure read; two reads agree).
func _next_sequence_id_is_a_readonly_cursor_past_the_start() -> void:
	var controller: RunFlowController = RunFlowController.new()
	assert_equal(controller.start(FINALE_SEED, false, &"warrior").get("started"), true, "Setup: seat a run.")
	var cursor: int = controller.orchestrator().next_sequence_id()
	assert_true(cursor > 0, "The sequence cursor is a positive id (a valid record sequence id).")
	assert_equal(controller.orchestrator().next_sequence_id(), cursor, "next_sequence_id() is a PURE READ — it does not advance on read (two reads agree).")


# ---- Story 12.2 (AC1): the live-combat loadout accessors are KIT-DERIVED ---------------------------

func _hero_loadout_accessors_derive_from_the_class_kit() -> void:
	# The 11.2 boundary revision: hero_hp() / hero_weapon_id() / hero_support() now derive from the seated class's
	# StartingKit (run.starting_kit) instead of the flat DEFAULT_HERO_HP/sword. Proven for each of the three classes.
	var warrior: RunFlowController = RunFlowController.new()
	assert_true(warrior.start(FINALE_SEED, false, &"warrior").get("started"), "Setup: seat a warrior run.")
	assert_equal(warrior.hero_hp(), 18, "hero_hp() derives the warrior kit baseline_hp (18 — NOT the flat DEFAULT_HERO_HP 60).")
	assert_equal(String(warrior.hero_weapon_id()), "sword", "hero_weapon_id() derives the warrior kit weapon (sword).")
	assert_true(warrior.hero_support() != null and String(warrior.hero_support().support_id) == String(SupportDefinition.SUPPORT_SHIELD), "hero_support() derives the warrior kit shield.")

	var pyromancer: RunFlowController = RunFlowController.new()
	assert_true(pyromancer.start(FINALE_SEED, false, &"pyromancer").get("started"), "Setup: seat a pyromancer run.")
	assert_equal(String(pyromancer.hero_weapon_id()), "staff", "hero_weapon_id() derives the pyromancer kit weapon (staff).")
	assert_true(pyromancer.hero_support() != null and String(pyromancer.hero_support().support_id) == String(SupportDefinition.SUPPORT_TOME), "hero_support() derives the pyromancer kit tome.")

	var ranger: RunFlowController = RunFlowController.new()
	assert_true(ranger.start(FINALE_SEED, false, &"ranger").get("started"), "Setup: seat a ranger run.")
	assert_equal(String(ranger.hero_weapon_id()), "bow", "hero_weapon_id() derives the ranger kit weapon (bow).")
	assert_true(ranger.hero_support() == null, "hero_support() is null for the ranger (its support is the real no-op none).")


func _hero_hp_falls_back_to_the_driver_default_on_a_kitless_run() -> void:
	# A seed-only (empty-class) run records NO kit — the loadout accessors FALL OPEN to the driver default so the run
	# still resolves (the AC1 fail-open fallback; a run with NO kit uses the driver default).
	var controller: RunFlowController = RunFlowController.new()
	assert_true(controller.start(FINALE_SEED, false, &"").get("started"), "Setup: seat a seed-only (kitless) run.")
	assert_true(controller.run().starting_kit == null, "Setup: a seed-only run records NO kit.")
	assert_equal(controller.hero_hp(), LiveCombatResolver.DEFAULT_HERO_HP, "A kitless run falls back to the driver default HP (60).")
	assert_equal(String(controller.hero_weapon_id()), String(LiveCombatResolver.DEFAULT_HERO_WEAPON), "A kitless run falls back to the driver default weapon (sword).")
	assert_true(controller.hero_support() == null, "A kitless run carries no support (the byte-identical default path).")


func _hands_off_flow_stays_on_the_tuned_default_loadout() -> void:
	# AC4: the hands-off AUTO-RESOLVE smoke path is DECOUPLED from the now-kit-derived hero_hp() — it stays on the tuned
	# DEFAULT loadout (60/sword) so the byte-identical focus-fire LiveCombatResolver still reaches a terminal victory
	# (threading the warrior 18 HP into the focus-fire driver would reproduce the 11.3 death). A warrior run's hands-off
	# flow reaches a terminal outcome (it does NOT use the 18-HP kit HP that would kill the focus-fire driver).
	var controller: RunFlowController = RunFlowController.new()
	assert_true(controller.start(FINALE_SEED, false, &"warrior").get("started"), "Setup: seat a warrior run.")
	assert_equal(controller.hero_hp(), 18, "Setup: the warrior kit HP is 18 (the focus-fire driver would die on it).")
	var result_data: Dictionary = controller.play_hands_off_to_run_end()
	assert_true(result_data.get("ok", false), "The hands-off flow (on the tuned DEFAULT loadout, NOT the 18-HP kit) reaches a terminal outcome: %s" % result_data)
	assert_equal(String(result_data.get("phase")), String(RunState.PHASE_COMPLETED), "The hands-off flow completes the run (the tuned default loadout wins — it is NOT crippled by the 18-HP kit).")


func _cleanup() -> void:
	for path: String in [BRIDGE_PROFILE_PATH, "%s.tmp" % BRIDGE_PROFILE_PATH, "%s.bak" % BRIDGE_PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
