class_name RunFlowRouter
extends RefCounted

# Story 11.3 (AC1) — the scene-free ROUTE-TABLE + next_destination routing helper the thin SceneManager autoload
# DELEGATES to. It is pulled OUT of the autoload precisely so the scene-free headless harness can unit-test the
# routing LOGIC (the harness runs script.new().run() with NO SceneTree; the autoload's get_tree().change_scene
# is untestable there, but this pure helper is). It NAVIGATES; it owns NO run/tactical truth — it reads the
# destination the DOMAIN reports (via RunEndOutcome.next_destination / the orchestrator result) and returns WHICH
# scene the autoload should change to.
#
# It owns TWO things and nothing else:
#   (1) THE NAMED FLOW-STAGE -> .tscn ROUTE TABLE (launch -> hero_select -> route_map -> tactical_board ->
#       run_end), so a call site names a STAGE, not a hardcoded scene string sprinkled per call site (the AC1
#       "NOT a hardcoded scene string per call site"). `launch` maps to the boot chain's main.tscn (the app entry
#       that boots into the flow); the tactical_board stage maps to the gameplay SHELL (which hosts the board +
#       the in-run HUD).
#   (2) THE RunEndOutcome.next_destination -> FLOW-STAGE TRANSITION: the run-end return routes off
#       next_destination (the pinned RUN_END_DESTINATION_OUTPOST == "outpost" marker), which maps to the run_end
#       stage — NOT a hardcoded string at the call site. A non-terminal run reports next_destination == "" and
#       routes NOWHERE (the run continues; the map/board flow owns the in-run navigation).
#
# FAIL-CLOSED: an unknown stage or destination returns "" (the autoload treats "" as "no navigation" — never a
# crash, never a silently-wrong scene). It draws NO RNG, mutates nothing, holds no state — every method is a
# pure lookup. It is a RefCounted helper — NOT a Control/Node/scene/autoload.

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

# The ordered run-flow stage vocabulary (the AC1 walk: launch -> hero select -> route map -> tactical board per
# node -> run-end return). Pinned by test.
const STAGES: Array[String] = [
	"launch",
	"hero_select",
	"route_map",
	"tactical_board",
	"run_end"
]

# The named flow-stage -> .tscn route table (the AC1 route table). `launch` is the boot-chain app entry
# (main.tscn) that boots into hero select; `tactical_board` is the gameplay SHELL (board + in-run HUD). Pinned by
# test — the scenes are 11.3's deliverables under godot/scenes/.
const _STAGE_SCENES: Dictionary = {
	"launch": "res://scenes/app/main.tscn",
	"hero_select": "res://scenes/ui/hero_select.tscn",
	"route_map": "res://scenes/ui/route_map.tscn",
	"tactical_board": "res://scenes/game/gameplay_shell.tscn",
	"run_end": "res://scenes/ui/run_end.tscn"
}

# The RunEndOutcome.next_destination marker -> flow-stage transition (the AC1 routing signal). The pinned outpost
# marker routes the run-end return to the run_end stage (a minimal run-end landing that then navigates to the
# outpost destination — the polished outpost SCENE is 11.5's, not 11.3's). A non-terminal run's "" destination is
# intentionally absent (routes nowhere).
const _DESTINATION_STAGES: Dictionary = {
	"outpost": "run_end"
}

# The .tscn path for a named flow stage, or "" for an unknown stage (fail-closed).
static func scene_path_for_stage(stage: String) -> String:
	return String(_STAGE_SCENES.get(stage, ""))


# The next flow stage in the ordered walk, or "" for the terminal stage / an unknown stage (fail-closed). This is
# the DEFAULT forward step; a call site MAY route explicitly (e.g. a run-end that jumps straight to run_end via
# stage_for_destination).
static func next_stage(stage: String) -> String:
	var index: int = STAGES.find(stage)
	if index < 0 or index >= STAGES.size() - 1:
		return ""
	return STAGES[index + 1]


# The flow stage a RunEndOutcome.next_destination marker routes to (the AC1 next_destination transition). The
# pinned RUN_END_DESTINATION_OUTPOST == "outpost" -> run_end; a non-terminal "" (or any unknown) -> "" (routes
# nowhere, fail-closed).
static func stage_for_destination(destination: StringName) -> String:
	return String(_DESTINATION_STAGES.get(String(destination), ""))


# Convenience: the .tscn path a run-end destination routes to directly (stage_for_destination -> scene path), or
# "" when the destination routes nowhere. The autoload uses this to route the run-end return off the domain
# destination in ONE call.
static func scene_path_for_destination(destination: StringName) -> String:
	var stage: String = stage_for_destination(destination)
	if stage.is_empty():
		return ""
	return scene_path_for_stage(stage)
