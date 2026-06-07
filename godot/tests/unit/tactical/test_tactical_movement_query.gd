extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalMovementQuery = preload("res://scripts/tactical/movement/tactical_movement_query.gd")

func run() -> Dictionary:
	_reachable_paths_are_cardinal_and_budgeted()
	_invalid_query_reasons_are_stable_and_domain_derived()
	_queries_do_not_mutate_board()
	return result()


func _reachable_paths_are_cardinal_and_budgeted() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var query: TacticalMovementQuery = TacticalMovementQuery.new()

	var result_value: ActionResult = query.validate_target(board, &"hero", Vector2i(2, 1), 3)

	assert_true(result_value.succeeded, "Movement query should accept a 3-step cardinal path.")
	assert_equal(result_value.metadata.get("movement_cost"), 3, "Movement query should report cardinal path cost.")
	assert_equal(result_value.metadata.get("path"), [
		{"x": 0, "y": 0},
		{"x": 1, "y": 0},
		{"x": 2, "y": 0},
		{"x": 2, "y": 1}
	], "Movement query should return a deterministic path.")


func _invalid_query_reasons_are_stable_and_domain_derived() -> void:
	var query: TacticalMovementQuery = TacticalMovementQuery.new()

	_assert_query_reason(query, _visible_board(BoardFixtureFactory.blocked_cell()), &"hero", Vector2i(1, 1), 3, &"blocked")
	_assert_query_reason(query, _visible_board(BoardFixtureFactory.occupied_cell()), &"hero", Vector2i(1, 1), 3, &"occupied")
	_assert_query_reason(query, _visible_board(BoardFixtureFactory.edge_corner_movement()), &"hero", Vector2i(3, 0), 3, &"out_of_bounds")
	_assert_query_reason(query, _visible_board(BoardFixtureFactory.edge_corner_movement()), &"hero", Vector2i(2, 2), 3, &"beyond_budget")
	_assert_query_reason(query, _visible_board(BoardFixtureFactory.edge_corner_movement()), &"missing_actor", Vector2i(1, 0), 3, &"invalid_actor")
	_assert_query_reason(query, BoardFixtureFactory.edge_corner_movement(), &"hero", Vector2i(1, 0), 3, &"not_visible")
	_assert_query_reason(query, _visible_board(BoardFixtureFactory.disconnected_cells()), &"hero", Vector2i(2, 0), 3, &"unreachable")
	_assert_query_reason(query, _visible_board(BoardFixtureFactory.edge_corner_movement()), &"hero", Vector2i(0, 0), 3, &"same_cell")


func _queries_do_not_mutate_board() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.disconnected_cells())
	var snapshot_before: Dictionary = board.to_snapshot()
	var sequence_before: int = board.next_sequence_id()
	var query: TacticalMovementQuery = TacticalMovementQuery.new()

	query.validate_target(board, &"hero", Vector2i(2, 0), 3)
	query.validate_target(board, &"hero", Vector2i(0, 2), 3)

	assert_equal(board.to_snapshot(), snapshot_before, "Movement queries must not mutate board snapshots.")
	assert_equal(board.next_sequence_id(), sequence_before, "Movement queries must not advance board sequence ids.")


func _assert_query_reason(
	query: TacticalMovementQuery,
	board: BoardState,
	actor_id: StringName,
	target_cell: Vector2i,
	budget: int,
	expected_reason: StringName
) -> void:
	var result_value: ActionResult = query.validate_target(board, actor_id, target_cell, budget)

	assert_true(result_value.is_error(), "Movement query should reject %s." % String(expected_reason))
	assert_equal(result_value.error_code, &"invalid_movement", "Movement query should use the stable movement error code.")
	assert_equal(result_value.metadata.get("reason"), String(expected_reason), "Movement query should expose the expected reason.")
	assert_false(result_value.has_events(), "Invalid movement queries should not emit events.")


func _visible_board(board: BoardState) -> BoardState:
	for cell: BoardCell in board.cells():
		cell.visible = true
		cell.explored = true
	return board
