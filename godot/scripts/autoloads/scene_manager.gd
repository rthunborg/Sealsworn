extends Node

# The thin scene-navigation autoload (Story 2 baseline; EXTENDED by Story 11.3 with a named-flow surface). It
# NAVIGATES; it owns NO run/tactical truth. The bare change_scene wrapper is UNCHANGED (the BootController path);
# 11.3 adds a named FLOW-STAGE surface + a RunEndOutcome.next_destination routing transition that both DELEGATE to
# the scene-free RunFlowRouter (the route-table + destination-mapping LOGIC lives in a testable RefCounted, so the
# scene-free harness can unit-test it — this autoload stays thin glue over get_tree().change_scene_to_file).

const RunFlowRouter = preload("res://scripts/ui/flow/run_flow_router.gd")

var current_scene_path: String = ""

func change_scene(scene_path: String) -> Error:
	current_scene_path = scene_path
	return get_tree().change_scene_to_file(scene_path)


# Story 11.3 (AC1): navigate to a NAMED flow stage (launch / hero_select / route_map / tactical_board / run_end).
# The stage -> scene mapping is the RunFlowRouter route table (a call site names a STAGE, not a hardcoded scene
# string). An unknown stage resolves to "" and is a no-op error (fail-closed — never a wrong scene).
func go_to_stage(stage: String) -> Error:
	var scene_path: String = RunFlowRouter.scene_path_for_stage(stage)
	if scene_path.is_empty():
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"app", &"scene_manager_unknown_stage", {"stage": stage})
		return ERR_DOES_NOT_EXIST
	return change_scene(scene_path)


# Story 11.3 (AC1 — the routing signal): route the run-end return off RunEndOutcome.next_destination (the pinned
# RUN_END_DESTINATION_OUTPOST == "outpost" marker), NOT a hardcoded scene string at the call site. A non-terminal
# run's "" destination routes NOWHERE (a no-op — the run continues). The destination -> scene mapping is the
# RunFlowRouter transition. This is the seam a run-end/gameplay presenter calls with the domain-reported destination.
func route_after_run_end(next_destination: StringName) -> Error:
	var scene_path: String = RunFlowRouter.scene_path_for_destination(next_destination)
	if scene_path.is_empty():
		# A non-terminal run (empty destination) or an unknown destination — no navigation.
		return ERR_DOES_NOT_EXIST
	return change_scene(scene_path)
