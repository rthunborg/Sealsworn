extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")

func run() -> Dictionary:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(2, 2)

	var result_value: ActionResult = command.execute(board)

	assert_true(result_value.succeeded, "Headless integration smoke test should execute a domain command.")
	assert_equal(board.cell_count(), 4, "Headless integration smoke test should load tactical domain state.")

	return result()
