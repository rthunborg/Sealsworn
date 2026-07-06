extends "res://tests/unit/test_case.gd"

# Story 11.3 Task 1 — RunFlowRouter (AC1): the testable route-table + next_destination routing helper the thin
# SceneManager autoload delegates to (pulled OUT of the autoload so the scene-free harness can unit-test it —
# the harness runs script.new().run() with NO SceneTree, so the routing LOGIC must live in a RefCounted).
#
# RunFlowRouter owns TWO things (it navigates; it owns NO run/tactical truth — it reads the destination the
# DOMAIN reports):
#   (1) the named flow-stage -> .tscn route table (boot/launch -> hero_select -> route_map -> tactical_board ->
#       run_end), so a call site names a STAGE, not a hardcoded scene string;
#   (2) the RunEndOutcome.next_destination -> flow-stage transition (the pinned RUN_END_DESTINATION_OUTPOST ==
#       "outpost" marker routes the run-end return to the run_end stage; a non-terminal "" destination does not
#       route anywhere).
#
# This test pins the stage vocabulary, every stage's scene path, the ordered walk (launch -> ... -> run_end),
# the next_destination mapping (outpost -> run_end; "" -> no route), and the fail-closed unknown-stage/dest.

const RunFlowRouter = preload("res://scripts/ui/flow/run_flow_router.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RunEndOutcome = preload("res://scripts/run/run_end_outcome.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteState = preload("res://scripts/run/route_state.gd")

func run() -> Dictionary:
	_stage_vocabulary_is_the_five_flow_stages()
	_every_stage_maps_to_a_real_scene_path()
	_ordered_walk_is_launch_to_run_end()
	_next_destination_outpost_routes_to_run_end_stage()
	_non_terminal_destination_routes_nowhere()
	_unknown_stage_and_destination_are_fail_closed()
	_scene_path_for_run_end_outcome_from_a_terminal_run()
	return result()


# AC1: the flow-stage vocabulary is the ordered run-flow stages (launch -> hero_select -> route_map ->
# tactical_board -> run_end). Story 11.5 APPENDS the `outpost` stage (the real OutpostViewModel-bound scene the
# run-end return lands on); `run_end` STAYS as the minimal fail-loud dead-end landing.
func _stage_vocabulary_is_the_five_flow_stages() -> void:
	assert_equal(RunFlowRouter.STAGES, [
		"launch",
		"hero_select",
		"route_map",
		"tactical_board",
		"run_end",
		"outpost"
	], "The flow-stage vocabulary must be the ordered run-flow stages (11.5 appends the outpost stage).")


# AC1: each stage resolves to a real .tscn path via the route table (a call site names a STAGE, not a string).
func _every_stage_maps_to_a_real_scene_path() -> void:
	assert_equal(RunFlowRouter.scene_path_for_stage("launch"), "res://scenes/app/main.tscn", "launch -> main.tscn (the boot chain target).")
	assert_equal(RunFlowRouter.scene_path_for_stage("hero_select"), "res://scenes/ui/hero_select.tscn", "hero_select -> hero_select.tscn.")
	assert_equal(RunFlowRouter.scene_path_for_stage("route_map"), "res://scenes/ui/route_map.tscn", "route_map -> route_map.tscn.")
	assert_equal(RunFlowRouter.scene_path_for_stage("tactical_board"), "res://scenes/game/gameplay_shell.tscn", "tactical_board -> the gameplay shell (board + HUD).")
	assert_equal(RunFlowRouter.scene_path_for_stage("run_end"), "res://scenes/ui/run_end.tscn", "run_end -> run_end.tscn (the minimal dead-end landing).")
	assert_equal(RunFlowRouter.scene_path_for_stage("outpost"), "res://scenes/ui/outpost.tscn", "outpost -> outpost.tscn (the real OutpostViewModel-bound scene — Story 11.5).")


# AC1: the ordered walk steps launch -> hero_select -> route_map -> tactical_board -> run_end -> outpost (next_stage).
# Story 11.5 appends the outpost stage as the terminal step (the run-end return lands on the real outpost scene).
func _ordered_walk_is_launch_to_run_end() -> void:
	assert_equal(RunFlowRouter.next_stage("launch"), "hero_select", "launch advances to hero_select.")
	assert_equal(RunFlowRouter.next_stage("hero_select"), "route_map", "hero_select advances to route_map.")
	assert_equal(RunFlowRouter.next_stage("route_map"), "tactical_board", "route_map advances to the tactical board.")
	assert_equal(RunFlowRouter.next_stage("tactical_board"), "run_end", "the tactical board advances to run_end.")
	assert_equal(RunFlowRouter.next_stage("run_end"), "outpost", "run_end advances to the outpost (Story 11.5).")
	assert_equal(RunFlowRouter.next_stage("outpost"), "", "outpost is terminal (no next stage).")


# AC1 (the routing signal): the run-end return routes off RunEndOutcome.next_destination — the pinned
# RUN_END_DESTINATION_OUTPOST == "outpost" marker maps to the real `outpost` stage (Story 11.5 re-points it from the
# 11.3 minimal `run_end` placeholder to the OutpostViewModel-bound outpost scene), NOT a hardcoded string at the call site.
func _next_destination_outpost_routes_to_run_end_stage() -> void:
	assert_equal(String(DomainEvent.RUN_END_DESTINATION_OUTPOST), "outpost", "Sanity: the pinned destination marker is 'outpost'.")
	assert_equal(RunFlowRouter.stage_for_destination(DomainEvent.RUN_END_DESTINATION_OUTPOST), "outpost", "The outpost destination must route to the outpost stage (Story 11.5).")
	assert_equal(RunFlowRouter.stage_for_destination(&"outpost"), "outpost", "The literal outpost marker must route to the outpost stage.")
	assert_equal(RunFlowRouter.scene_path_for_destination(&"outpost"), "res://scenes/ui/outpost.tscn", "The outpost destination resolves to the outpost scene path.")


# AC1: a non-terminal run yields next_destination == "" -> no routing (the run continues; the map/board flow owns it).
func _non_terminal_destination_routes_nowhere() -> void:
	assert_equal(RunFlowRouter.stage_for_destination(&""), "", "An empty destination routes nowhere (a non-terminal run).")


# Fail-closed: an unknown stage / destination returns "" (never a crash, never a wrong scene).
func _unknown_stage_and_destination_are_fail_closed() -> void:
	assert_equal(RunFlowRouter.scene_path_for_stage("does_not_exist"), "", "An unknown stage resolves to no scene (fail-closed).")
	assert_equal(RunFlowRouter.next_stage("does_not_exist"), "", "An unknown stage has no next stage (fail-closed).")
	assert_equal(RunFlowRouter.stage_for_destination(&"unknown_dest"), "", "An unknown destination routes nowhere (fail-closed).")


# AC1 end-to-end: a terminal run's RunEndOutcome routes to the real outpost scene path via the router (Story 11.5).
func _scene_path_for_run_end_outcome_from_a_terminal_run() -> void:
	var run: RunState = RunState.new(RunState.PHASE_COMPLETED, 4242, false, true, RouteState.new([], "", []))
	var outcome: RunEndOutcome = RunEndOutcome.for_completed(run, DomainEvent.RUN_COMPLETED_OUTCOME_VICTORY)
	assert_equal(String(outcome.next_destination), "outpost", "A completed run's next_destination is the outpost marker.")
	var stage: String = RunFlowRouter.stage_for_destination(outcome.next_destination)
	assert_equal(stage, "outpost", "A completed run routes to the outpost stage (Story 11.5).")
	assert_equal(RunFlowRouter.scene_path_for_stage(stage), "res://scenes/ui/outpost.tscn", "The outpost stage resolves to the outpost scene path.")
