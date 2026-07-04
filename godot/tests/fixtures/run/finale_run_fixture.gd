class_name FinaleRunFixture
extends RefCounted

# Story 9.5 test fixture — the FULL RUN driven THROUGH THE SHELL to the boss-setup terminus. It drives
# RunOrchestrator.start(root_seed[, class_id]) -> run_to_completion() to the 9.1 boss-setup terminus (the run parks
# NON-terminal in PHASE_NODE_RESOLUTION with boss_encounter_pending == true — it does NOT auto-play the fight) and
# surfaces the seated orchestrator + the parked run. This is the shared entry point BOTH the finale seed-regression
# suite AND the full-run integration use to get a real full run standing on its terminal boss node, so the two tests
# drive the SAME shell path (not a hand-built run).
#
# It builds NO new domain state and owns NO gameplay decision — it SEQUENCES the existing orchestrator drive (start ->
# run_to_completion) and returns the result. It draws no RNG itself (the orchestrator's start/route generation does,
# through the run-level streams). The run it returns is NON-terminal (awaiting the boss fight + the caller-driven
# run-END resolution).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# Drive a fresh full run (start -> run_to_completion) to the boss-setup terminus and return the seated orchestrator. The
# orchestrator's `run` is parked NON-terminal in NODE_RESOLUTION with boss_encounter_pending() == true. `is_manual_seed`
# defaults false (a meta-eligible run); pass true for a manual-seed (practice) run. `class_id` defaults &"" (the legacy
# no-class start). Returns the ORCHESTRATOR (the caller reads orchestrator.run + the boss surface + drives the run-END).
static func drive_to_boss_terminus(root_seed: int, is_manual_seed: bool = false, class_id: StringName = &"") -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var start_result: ActionResult = orchestrator.start(root_seed, is_manual_seed, class_id)
	if start_result.is_error():
		push_error("FinaleRunFixture start failed: %s" % String(start_result.error_code))
		return orchestrator
	var completion: ActionResult = orchestrator.run_to_completion()
	if completion.is_error():
		push_error("FinaleRunFixture run_to_completion failed: %s" % String(completion.error_code))
	return orchestrator


# A convenience: the NON-terminal boss-terminus RunState alone (for a caller that only needs the parked run, e.g. driving
# CompleteRunCommand directly). Parked in NODE_RESOLUTION with the boss encounter set up.
static func boss_terminus_run(root_seed: int, is_manual_seed: bool = false, class_id: StringName = &"") -> RunState:
	return drive_to_boss_terminus(root_seed, is_manual_seed, class_id).run


# The live boss arena BoardState restored from the orchestrator's boss_arena_payload() (the arena the run set up at the
# terminus). The board carries NO entities yet (the 9.1 arena reserves the boss SLOT; the caller places the live boss +
# hero). Returns null if the payload is missing/malformed (a fail-loud defensive guard).
static func boss_arena_board(orchestrator: RunOrchestrator) -> BoardState:
	var payload: Dictionary = orchestrator.boss_arena_payload()
	var snapshot: Dictionary = payload.get("board_snapshot", {})
	if snapshot.is_empty():
		push_error("FinaleRunFixture: boss arena payload has no board_snapshot.")
		return null
	var board_result: ActionResult = BoardState.try_from_snapshot(snapshot)
	if board_result.is_error():
		push_error("FinaleRunFixture: boss arena board snapshot rejected: %s" % String(board_result.error_code))
		return null
	return board_result.metadata.get("board") as BoardState


# The boss route node's id on the parked run (the terminal TYPE_BOSS node the run stands on). Used by the boss_cleared
# reconciliation (mark this node cleared on victory). Returns "" if not found (defensive).
static func boss_node_id(run: RunState) -> String:
	if run == null or run.route == null:
		return ""
	for node in run.route.nodes():
		if node.type == &"boss":
			return node.id
	return ""
