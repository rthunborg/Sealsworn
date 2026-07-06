class_name RunFlowController
extends RefCounted

# Story 11.3 (AC1) — the scene-free RUN-FLOW SEQUENCER. It is the orchestration-layer seam the presenters DRIVE:
# it SEQUENCES the EXISTING RunOrchestrator live methods (it adds NO new run logic, mints NO event, draws NO RNG
# itself, owns NO run truth — the RunOrchestrator + the Epic-1..9 commands own all state) and exposes the run-end
# fact (RunEndOutcome) + the destination flow stage (via RunFlowRouter) the SceneManager routes on.
#
# ⭐ IT COMPOSES THE 11.2-INHERITED SEAM (the single most load-bearing cross-story constraint for 11.3). 11.2
# shipped the live pre-boss path (resolve_current_node_live / run_to_completion_live — STOPS at the boss-setup
# terminus) and the boss auto-play (auto_play_boss_fight / auto_play_full_run — the resolve_boss_victory
# PRODUCTION call site) but left them INTENTIONALLY un-composed (the human-acknowledged 2026-07-05 decision).
# Composing them into ONE hands-off start -> boss -> victory play flow is 11.3's concern; this controller does it
# at the SCENE/orchestration layer (NOT by forking a new domain method): the flow drives live combat nodes
# node-by-node up to boss_encounter_pending(), then drives the live boss fight to resolve_boss_victory().
#
# ⭐ THE FINGERPRINT-SAFETY POSTURE STAYS: the composed hands-off/smoke path uses the LIVE pre-boss driver
# (run_to_completion_live) + the boss auto-play — it NEVER touches the DEFAULT run_to_completion (the v0
# auto-resolve the reward/route/finale fingerprints depend on), so no fingerprint moves. The scripted live hero
# is deterministic but NOT universally-winning across arbitrary seeds (a mutually-unreachable straggler fails
# loud — live_combat_did_not_resolve); the hands-off/smoke path uses a VERIFIED seed (the approved-seed-catalog
# discipline; seed 4242 canonical for the finale). For ON-SCREEN play the HUMAN drives the hero via taps (the
# command bridge in the tactical-board presenter) — the human replaces the scripted driver; this controller's
# hands-off path is the headless smoke / auto-play seam a test exercises.
#
# ⭐ THE HERO LOADOUT IS DRIVER-SUPPLIED (11.2's documented boundary, inherited): the live methods take
# hero_hp / hero_weapon_id (defaulting to LiveCombatResolver.DEFAULT_HERO_HP / DEFAULT_HERO_WEAPON). 11.3 threads
# the hero HP from the class start (the selected class's StartingKit.baseline_hp where the seam allows) — it
# builds NO new class-kit -> combat-loadout system (that is a later story). A run with no kit falls back to the
# LiveCombatResolver defaults.
#
# ⭐ FAIL-CLOSED (adopting the resolver's validate-then-reject discipline from the start, per the Epic-11 retro):
# an unstarted controller (no seated run) returns a structured not-started result — never a crash; a
# rejected start surfaces the command error VERBATIM and seats nothing. The run-end outcome of an unstarted /
# non-terminal run is the fail-closed empty fact (has_ended == false).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
const RunEndOutcome = preload("res://scripts/run/run_end_outcome.gd")
const RunFlowRouter = preload("res://scripts/ui/flow/run_flow_router.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")

# The node types that HOST A LIVE TACTICAL BOARD (combat / elite). The ONE shared source for the "which nodes
# are played on a board" decision — both presenters (the route map and the gameplay shell) read this so the
# resolve-then-advance sequencing is defined in one place, NOT re-listed per presenter. The boss terminus is a
# DISTINCT case (boss_encounter_pending() / boss_arena_payload()), so it is intentionally not in this set.
const LIVE_BOARD_NODE_TYPES: Array[StringName] = [RouteNode.TYPE_COMBAT, RouteNode.TYPE_ELITE_COMBAT]

var _orchestrator: RunOrchestrator = null

func _init(orchestrator: RunOrchestrator = null) -> void:
	# Default to a fresh baseline orchestrator; tests may inject one (mirroring the RunOrchestrator repository
	# injection posture). The orchestrator owns the run/streams; this controller only sequences it.
	_orchestrator = orchestrator if orchestrator != null else RunOrchestrator.new()


# The seated live run handle (or null before start). A pure read — the domain owns the state.
func run() -> RunState:
	return _orchestrator.run


# The underlying orchestrator (for the presenters that drive per-node live resolution + read the live board).
func orchestrator() -> RunOrchestrator:
	return _orchestrator


# ⭐ THE SHARED SEQUENCING SEAM (AC1/AC2 — the H1 fix). True when the run is parked on an UNRESOLVED live node
# (a combat/elite node NOT yet in cleared_node_ids) that MUST be hosted on a board BEFORE the route map offers
# the next choices — mirroring the domain live driver run_to_completion_live's resolve-current-THEN-advance
# order (run_orchestrator.gd:1036-1047). Without this seam the on-screen path advanced-THEN-resolved: the route
# map offered the depth-1 successors while the depth-0 opening combat node (RouteGenerator GUARANTEES depth 0 is
# always a combat node; RunStartCommand parks current_node_id there with cleared_node_ids empty) was still
# unresolved, and picking a depth-1 choice made RouteAdvanceCommand SEAL the unplayed depth-0 node into
# cleared_node_ids without ever hosting it on a board. The presenters call this to route to the board first.
# Pure read — draws no RNG, mutates nothing, owns no run truth (the boss terminus is a DISTINCT case both
# presenters check via boss_encounter_pending() before consulting this seam).
func current_node_needs_board() -> bool:
	var current: RunState = _orchestrator.run
	if current == null or current.is_terminal() or current.route == null:
		return false
	if _orchestrator.boss_encounter_pending():
		return false
	var node: RouteNode = current.route.node_by_id(current.route.current_node_id)
	if node == null:
		return false
	if current.route.cleared_node_ids.has(node.id):
		return false
	return LIVE_BOARD_NODE_TYPES.has(node.type)


# AC1: start a FRESH run from (root_seed, is_manual_seed, class_id) via the AUTHORITATIVE fail-closed
# RunOrchestrator.start (the class-picker confirm hands a class_id here; a locked/unknown class is rejected
# fail-closed and seats NO run). Returns a small structured result the presenter reads. This is the launch ->
# hero-select confirm -> run-start hand-off.
func start(root_seed: int, is_manual_seed: bool = false, class_id: StringName = &"") -> Dictionary:
	var start_result: ActionResult = _orchestrator.start(root_seed, is_manual_seed, class_id)
	if start_result.is_error():
		return {
			"started": false,
			"error_code": String(start_result.error_code),
			"metadata": start_result.metadata.duplicate(true)
		}
	return {
		"started": true,
		"root_seed": root_seed,
		"class_id": String(class_id)
	}


# The driver-supplied hero HP for the LIVE-COMBAT DRIVER (the 11.2 seam's hero_hp parameter). This is the
# LiveCombatResolver.DEFAULT_HERO_HP loadout HP — deliberately DISTINCT from the class StartingKit.baseline_hp the
# G1 HUD DISPLAYS between levels. The two are different concerns: the class baseline_hp (e.g. warrior 18) is a
# BALANCE number for a not-yet-existent HP-scaling system, NOT a live-combat driver HP — threading it into the
# scripted focus-fire driver makes the hero die (the class-kit -> combat-loadout wiring is a LATER story, 11.2's
# documented boundary). The live-combat driver therefore uses the resolver's tuned loadout HP (the same value
# 11.2's live methods default to), which reaches a real terminal board outcome on the verified seed. 11.3 builds
# NO class-kit -> loadout system; this is the driver-supplied loadout the seam already exposes.
func hero_hp() -> int:
	return LiveCombatResolver.DEFAULT_HERO_HP


# AC1 (the composition crux): drive the FULL run hands-off to a run-END through the LIVE flow, composing the
# 11.2-inherited seam. (1) run_to_completion_live drives the LIVE pre-boss combat nodes node-by-node to the
# boss-setup terminus (a live DEFEAT ends the run here); (2) if the run parked at the boss terminus,
# auto_play_boss_fight drives the LIVE boss fight (both sides simulated — the same seam, with its fail-closed
# placement discipline) to resolve_boss_victory() (or a hero death during the boss fight). The DEFAULT
# run_to_completion (the fingerprint-preserving v0 auto-resolve) is NEVER touched. Surfaces the FIRST error
# verbatim + STOPS (no partial progression). This is the headless smoke / hands-off auto-play seam; on screen the
# human drives the hero via taps (the presenter), and the presenter sequences the SAME per-node/boss methods.
func play_hands_off_to_run_end() -> Dictionary:
	return play_hands_off_to_run_end_with_hp(hero_hp())


# The HP-parameterized hands-off flow (the smoke / auto-play seam supplies a VERIFIED-winning loadout HP; the
# default path threads hero_hp() from the class start). Composes the SAME live-pre-boss + boss-auto-play seam.
func play_hands_off_to_run_end_with_hp(loadout_hp: int) -> Dictionary:
	if _orchestrator.run == null:
		return {"ok": false, "error_code": "no_active_run"}

	# (1) Live pre-boss walk to the boss terminus (or a live-defeat run-end).
	var pre_boss: ActionResult = _orchestrator.run_to_completion_live(loadout_hp)
	if pre_boss.is_error():
		return {"ok": false, "error_code": String(pre_boss.error_code), "metadata": pre_boss.metadata.duplicate(true)}

	# A live hero DEATH during the pre-boss walk already ended the run (PHASE_FAILED) — nothing more to compose.
	if _orchestrator.run.is_terminal():
		return {"ok": true, "phase": String(_orchestrator.run.phase), "resolution": "pre_boss_terminus"}

	# (2) Parked at the boss terminus -> drive the LIVE boss fight to victory (or a boss-context hero death).
	if not _orchestrator.boss_encounter_pending():
		# A non-terminal, non-boss-parked run should not happen after run_to_completion_live (it either ends or
		# parks at the boss). Fail loud rather than silently claim success.
		return {"ok": false, "error_code": "run_did_not_reach_boss_terminus", "phase": String(_orchestrator.run.phase)}

	var boss: ActionResult = _orchestrator.auto_play_boss_fight(loadout_hp)
	if boss.is_error():
		return {"ok": false, "error_code": String(boss.error_code), "metadata": boss.metadata.duplicate(true)}

	return {
		"ok": true,
		"phase": String(_orchestrator.run.phase),
		"resolution": String(boss.metadata.get("resolution", "")),
		"outcome": String(boss.metadata.get("outcome", "")),
		"cause": String(boss.metadata.get("cause", ""))
	}


# The run-end fact for the CURRENT run (AC1 — the routing signal). Derived from the terminal run via RunEndOutcome
# (a completed run -> for_completed with the captured outcome; a failed run -> for_failed with the captured cause);
# a non-terminal / unstarted run projects the fail-closed empty fact (has_ended == false). The controller reads the
# domain fact — it does NOT re-decide the run.
func run_end_outcome() -> Dictionary:
	var current: RunState = _orchestrator.run
	if current == null or not current.is_terminal():
		return RunEndOutcome._empty().to_dictionary()
	if current.phase == RunState.PHASE_COMPLETED:
		var completed_outcome: StringName = StringName(_orchestrator.run_completed_outcome())
		return RunEndOutcome.for_completed(current, completed_outcome).to_dictionary()
	# PHASE_FAILED: use the captured run-end cause.
	var cause: StringName = StringName(_orchestrator.run_failed_cause())
	return RunEndOutcome.for_failed(current, cause).to_dictionary()


# The flow STAGE the run-end return routes to (AC1 — next_destination -> stage via RunFlowRouter). A non-terminal /
# unstarted run routes NOWHERE ("").
func run_end_stage() -> String:
	var outcome: Dictionary = run_end_outcome()
	if not bool(outcome.get("has_ended", false)):
		return ""
	return RunFlowRouter.stage_for_destination(StringName(String(outcome.get("next_destination", ""))))
