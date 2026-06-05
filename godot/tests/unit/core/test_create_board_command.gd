extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_valid_command_creates_board()
	_valid_command_events_replay_to_matching_board_snapshot()
	_invalid_command_does_not_mutate()
	_invalid_create_cases_return_no_events_and_do_not_mutate_snapshot()
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


func _valid_command_events_replay_to_matching_board_snapshot() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(4, 3)

	var result_value: ActionResult = command.execute(board)
	var replay_board: BoardState = BoardState.new()
	var replay_result: ActionResult = replay_board.apply_events(result_value.events)

	assert_true(result_value.succeeded, "Valid CreateBoardCommand should succeed before replay.")
	assert_true(replay_result.succeeded, "BoardState should replay returned command events.")
	assert_equal(replay_board.to_snapshot(), board.to_snapshot(), "Replayed command events should reproduce the command-mutated board snapshot.")


func _invalid_command_does_not_mutate() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(0, 2)

	var result_value: ActionResult = command.execute(board)

	assert_true(result_value.is_error(), "Invalid CreateBoardCommand should return an error.")
	assert_equal(result_value.error_code, &"invalid_board_size", "Invalid CreateBoardCommand should explain the failure.")
	assert_false(board.has_cells(), "Invalid CreateBoardCommand must not mutate board state.")


func _invalid_create_cases_return_no_events_and_do_not_mutate_snapshot() -> void:
	var invalid_board: BoardState = BoardState.new()
	var invalid_snapshot: Dictionary = invalid_board.to_snapshot()
	var invalid_result: ActionResult = CreateBoardCommand.new(0, 2).execute(invalid_board)

	var existing_board: BoardState = BoardState.new()
	var create_result: ActionResult = CreateBoardCommand.new(2, 2).execute(existing_board)
	var existing_snapshot: Dictionary = existing_board.to_snapshot()
	var duplicate_result: ActionResult = CreateBoardCommand.new(3, 3).execute(existing_board)

	assert_true(invalid_result.is_error(), "Invalid board dimensions should fail.")
	assert_false(invalid_result.has_events(), "Invalid board dimensions should return no events.")
	assert_equal(invalid_board.to_snapshot(), invalid_snapshot, "Invalid board dimensions must not mutate board snapshots.")
	assert_true(create_result.succeeded, "Duplicate setup should create the initial board.")
	assert_true(duplicate_result.is_error(), "Duplicate board creation should fail.")
	assert_false(duplicate_result.has_events(), "Duplicate board creation should return no events.")
	assert_equal(existing_board.to_snapshot(), existing_snapshot, "Duplicate board creation must not mutate existing board snapshots.")


func _duplicate_create_is_rejected() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(2, 2)

	var first_result: ActionResult = command.execute(board)
	var second_result: ActionResult = command.execute(board)

	assert_true(first_result.succeeded, "First CreateBoardCommand should succeed.")
	assert_true(second_result.is_error(), "Second CreateBoardCommand should fail on an existing board.")
	assert_equal(second_result.error_code, &"board_already_created", "Duplicate CreateBoardCommand should explain the failure.")
	assert_equal(board.cell_count(), 4, "Duplicate CreateBoardCommand must not recreate or resize board state.")
