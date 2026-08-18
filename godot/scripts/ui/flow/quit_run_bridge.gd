class_name QuitRunBridge
extends RefCounted

# Story 15.4 (AC1) — the scene-free QUIT-SAVE COMPOSITION seam. When the player opens the live-board pause overlay
# and chooses Quit run, the run's route position must be saved through the EXISTING Epic-2 seam
# (RunOrchestrator.compose_route_position_snapshot -> SaveManager.autosave_route_position) so the descent survives
# closing the game. This seam houses the COMPOSE decision (the testable half) so the presenter is thin glue: it
# composes the board-free route-position snapshot from the live orchestrator and hands it back; the presenter
# persists it (SaveManager.autosave_route_position) then navigates to the boot/menu surface.
#
# ⭐ THE EPHEMERAL-FIGHT / RESUMABLE-BOUNDARY CRUX (AC1/AC3 — the in-node fight stays ephemeral). Quitting MID-FIGHT
# discards the ephemeral InteractiveCombatSession; the current node stays UN-CLEARED. But a mid-fight run is in
# PHASE_NODE_RESOLUTION (NodeEnterCommand transitioned it on entry), and re-entering on resume goes back through
# NodeEnterCommand which REQUIRES PHASE_ACTIVE_ROUTE (node_enter_command.gd:85) — so a NODE_RESOLUTION save would
# NOT re-enter cleanly. This seam composes the quit save at the RESUMABLE BOUNDARY: for a NODE_RESOLUTION run it
# backs the run out to PHASE_ACTIVE_ROUTE parked on the current, un-cleared node (a legal transition — the fight is
# discarded), so on resume the route map re-hosts that node via NodeEnterCommand from ACTIVE_ROUTE. It does this on
# a COPY of the run so the LIVE run/streams are UNMUTATED and the compose stays a PURE READ (zero RNG). No new save
# key, no mid-encounter save — the 23-key RunSnapshot gate stays 23 and SCHEMA_VERSION stays 1.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# Compose the board-free route-position quit save from the live orchestrator, at the resumable ACTIVE_ROUTE
# boundary. Returns the composed RunSnapshot, or null when there is nothing to save (no orchestrator / no seated
# run / a terminal run — a completed/failed run is not a resumable route position). A PURE READ of the live run +
# streams: it composes from a backed-out COPY when the run is mid-node, so the live orchestrator.run/streams are
# never mutated and no RNG is drawn.
static func compose_quit_save(orchestrator: RunOrchestrator) -> RunSnapshot:
	if orchestrator == null or orchestrator.run == null or orchestrator.streams == null:
		return null
	var run: RunState = orchestrator.run
	# A terminal run is a completed/failed run (the shell routes it to run-end/outpost, not a resumable quit).
	if run.is_terminal():
		return null

	var source_run: RunState = run
	if run.phase == RunState.PHASE_NODE_RESOLUTION:
		# Mid-fight: back the run out to the resumable ACTIVE_ROUTE boundary on a COPY (the live run is untouched;
		# the in-node fight is ephemeral and discarded by the caller). The node stays un-cleared, so on resume it is
		# re-entered fresh via NodeEnterCommand (which requires ACTIVE_ROUTE). Composing from the copy keeps this a
		# pure read of the live state.
		source_run = run.copy()
		# NODE_RESOLUTION -> ACTIVE_ROUTE is a legal edge; transition_to validates + mutates only on success.
		source_run.transition_to(RunState.PHASE_ACTIVE_ROUTE)

	# The board-free route-position compose (the SAME helper compose_route_position_snapshot uses; a pure read,
	# no RNG, seed cross-checked). Compose against the run-level streams the orchestrator owns.
	var compose: ActionResult = RunSnapshot.from_route_position(source_run, orchestrator.streams)
	if compose.is_error():
		return null
	return compose.metadata.get("snapshot") as RunSnapshot
