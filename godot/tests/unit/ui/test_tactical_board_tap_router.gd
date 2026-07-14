extends "res://tests/unit/test_case.gd"

# Story 13.1 (Task 4) — the tap-routing decision seam coverage. Proves TacticalBoardTapRouter.decide returns
# the right INTENT (move / attack / inspect / none) for the tapped cell's state, reading ONLY the pinned
# board-VM fields (no new VM key): an empty reachable tile -> move, an enemy-on-cell -> attack, a re-tap on
# the ARMED enemy -> attack-as-commit, the hero's own cell / a wall / a not-visible cell -> inspect, and an
# unavailable (out-of-bounds) mapping -> a safe no-op. The routing target math (the fit + hit-test) is proven
# in test_tactical_board_grid_fit.gd; this seam is purely the cell-state -> intent decision.

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalBoardTapRouter = preload("res://scripts/ui/view_models/tactical_board_tap_router.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

func run() -> Dictionary:
	_enemy_cell_routes_to_attack()
	_armed_enemy_re_tap_routes_to_attack_commit()
	_hero_cell_routes_to_inspect()
	_empty_visible_floor_routes_to_move()
	_wall_cell_routes_to_inspect()
	_unavailable_mapping_is_a_safe_no_op()
	_hidden_cell_routes_to_inspect()
	return result()


func _enemy_cell_routes_to_attack() -> void:
	# enemy_iron (iron_cultist, alive) sits at (3,2) on the revealed micro board.
	var decision: Dictionary = TacticalBoardTapRouter.decide(_mapping(3, 2), _revealed_vm())
	assert_equal(decision.get("intent"), "attack", "An alive enemy on the tapped cell should route to attack.")
	assert_equal(decision.get("is_commit"), false, "A first attack tap (no armed target) should arm, not commit.")
	assert_equal(decision.get("cell"), {"x": 3, "y": 2}, "The attack decision should carry the resolved cell.")


func _armed_enemy_re_tap_routes_to_attack_commit() -> void:
	var armed_dict: Dictionary = TacticalBoardTapRouter.decide(_mapping(3, 2), _revealed_vm(), {"x": 3, "y": 2})
	var armed_vec: Dictionary = TacticalBoardTapRouter.decide(_mapping(3, 2), _revealed_vm(), Vector2i(3, 2))
	assert_equal(armed_dict.get("intent"), "attack", "Re-tapping the armed enemy should still route to attack.")
	assert_equal(armed_dict.get("is_commit"), true, "Re-tapping the armed enemy cell should be the confirming commit.")
	assert_equal(armed_vec.get("is_commit"), true, "The armed cell should also match a Vector2i-typed armed target.")


func _hero_cell_routes_to_inspect() -> void:
	# The hero (player faction) sits at the entrance (0,2).
	var decision: Dictionary = TacticalBoardTapRouter.decide(_mapping(0, 2), _revealed_vm())
	assert_equal(decision.get("intent"), "inspect", "Tapping the hero's own cell should route to inspect, never attack.")
	assert_equal(decision.get("reason"), "occupant_inspect", "The hero-cell inspect should report the occupant reason.")


func _empty_visible_floor_routes_to_move() -> void:
	# (2,2) is an empty, visible floor cell between the hero and the enemy.
	var decision: Dictionary = TacticalBoardTapRouter.decide(_mapping(2, 2), _revealed_vm())
	assert_equal(decision.get("intent"), "move", "An empty, visible floor cell should route to move.")
	assert_equal(decision.get("reason"), "empty_reachable", "The move decision should report the empty_reachable reason.")


func _wall_cell_routes_to_inspect() -> void:
	# (3,1) is a WALL on the micro board — occupancy-blocking, so it inspects rather than moves.
	var decision: Dictionary = TacticalBoardTapRouter.decide(_mapping(3, 1), _revealed_vm())
	assert_equal(decision.get("intent"), "inspect", "A wall cell should route to inspect, not move.")
	assert_equal(decision.get("reason"), "blocked_terrain", "The wall inspect should report the blocked_terrain reason.")


func _unavailable_mapping_is_a_safe_no_op() -> void:
	var decision: Dictionary = TacticalBoardTapRouter.decide({"available": false, "reason": "out_of_bounds"}, _revealed_vm())
	assert_equal(decision.get("intent"), "none", "An out-of-bounds mapping should route to no-op.")
	assert_equal(decision.get("available"), false, "A no-op decision should not be available.")


func _hidden_cell_routes_to_inspect() -> void:
	# A hidden cell (no terrain leak) cannot be a confident move target -> inspect.
	var hidden_vm: Dictionary = {
		"occupants": [],
		"cells": [
			{"position": {"x": 4, "y": 4}, "visibility_state": "hidden"}
		]
	}
	var decision: Dictionary = TacticalBoardTapRouter.decide(_mapping(4, 4), hidden_vm)
	assert_equal(decision.get("intent"), "inspect", "A hidden (fogged) cell should route to inspect.")
	assert_equal(decision.get("reason"), "not_visible", "The hidden-cell inspect should report the not_visible reason.")


func _revealed_vm() -> Dictionary:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	return TacticalBoardViewModel.from_domain(board, turn_state, {}).to_dictionary()


func _mapping(x: int, y: int) -> Dictionary:
	return {
		"available": true,
		"reason": "valid",
		"cell": {"x": x, "y": y}
	}
