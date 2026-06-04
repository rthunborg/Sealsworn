extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_valid_command_creates_board()
	_invalid_command_does_not_mutate()
	_duplicate_create_is_rejected()
	return result()


func _valid_command_creates_board() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(3, 2)

	var result_value: ActionResult = command.execute(board)

	assert_true(result_value.succeeded, "Valid CreateBoardCommand should succeed.")
	assert_equal(board.width, 3, "CreateBoardCommand should set board width.")
	assert_equal(board.height, 2, "CreateBoardCommand should set board height.")
	assert_equal(board.cell_count(), 6, "CreateBoardCommand should create one cell per coordinate.")
	assert_equal(result_value.events.size(), 1, "CreateBoardCommand should emit one event.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.BOARD_CREATED, "CreateBoardCommand should emit BOARD_CREATED.")


func _invalid_command_does_not_mutate() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(0, 2)

	var result_value: ActionResult = command.execute(board)

	assert_true(result_value.is_error(), "Invalid CreateBoardCommand should return an error.")
	assert_equal(result_value.error_code, &"invalid_board_size", "Invalid CreateBoardCommand should explain the failure.")
	assert_false(board.has_cells(), "Invalid CreateBoardCommand must not mutate board state.")


func _duplicate_create_is_rejected() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(2, 2)

	var first_result: ActionResult = command.execute(board)
	var second_result: ActionResult = command.execute(board)

	assert_true(first_result.succeeded, "First CreateBoardCommand should succeed.")
	assert_true(second_result.is_error(), "Second CreateBoardCommand should fail on an existing board.")
	assert_equal(second_result.error_code, &"board_already_created", "Duplicate CreateBoardCommand should explain the failure.")
	assert_equal(board.cell_count(), 4, "Duplicate CreateBoardCommand must not recreate or resize board state.")
