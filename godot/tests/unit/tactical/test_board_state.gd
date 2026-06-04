extends "res://tests/unit/test_case.gd"

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_board_snapshot_round_trips()
	_bounds_check_uses_domain_dimensions()
	_invalid_board_created_event_does_not_mutate()
	_replayed_board_created_event_is_rejected()
	_event_batches_are_atomic()
	_corrupt_snapshot_is_rejected()
	_snapshot_cells_are_sorted_by_coordinate()
	return result()


func _board_snapshot_round_trips() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(2, 2)
	command.execute(board)

	var cell: BoardCell = board.get_cell(Vector2i(1, 1))
	cell.visible = true
	cell.explored = true
	cell.occupant_id = &"hero"

	var restored: BoardState = BoardState.from_snapshot(board.to_snapshot())
	var restored_cell: BoardCell = restored.get_cell(Vector2i(1, 1))

	assert_equal(restored.width, 2, "Board snapshot should preserve width.")
	assert_equal(restored.height, 2, "Board snapshot should preserve height.")
	assert_equal(restored.cell_count(), 4, "Board snapshot should preserve cells.")
	assert_true(restored_cell.visible, "Board snapshot should preserve visibility.")
	assert_true(restored_cell.explored, "Board snapshot should preserve explored memory.")
	assert_equal(restored_cell.occupant_id, &"hero", "Board snapshot should preserve occupant id.")


func _bounds_check_uses_domain_dimensions() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(3, 3)
	command.execute(board)

	assert_true(board.in_bounds(Vector2i(0, 0)), "Origin should be in bounds.")
	assert_true(board.in_bounds(Vector2i(2, 2)), "Max legal coordinate should be in bounds.")
	assert_false(board.in_bounds(Vector2i(3, 0)), "X beyond width should be out of bounds.")
	assert_false(board.in_bounds(Vector2i(0, 3)), "Y beyond height should be out of bounds.")


func _invalid_board_created_event_does_not_mutate() -> void:
	var board: BoardState = BoardState.new()
	var bad_event: DomainEvent = DomainEvent.board_created(board.next_sequence_id(), 0, 3)

	var result_value: ActionResult = board.apply_event(bad_event)

	assert_true(result_value.is_error(), "Invalid board-created event should fail.")
	assert_equal(result_value.error_code, &"invalid_board_size", "Invalid board-created event should explain bad dimensions.")
	assert_false(board.has_cells(), "Invalid board-created event must not mutate board state.")


func _replayed_board_created_event_is_rejected() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(2, 2)
	command.execute(board)

	var replay_event: DomainEvent = DomainEvent.board_created(1, 2, 2)
	var result_value: ActionResult = board.apply_event(replay_event)

	assert_true(result_value.is_error(), "Replayed board-created event should fail.")
	assert_equal(result_value.error_code, &"event_sequence_mismatch", "Replayed event should explain sequence mismatch.")
	assert_equal(board.cell_count(), 4, "Replayed event must not recreate board state.")


func _event_batches_are_atomic() -> void:
	var board: BoardState = BoardState.new()
	var events: Array[DomainEvent] = [
		DomainEvent.board_created(1, 2, 2),
		DomainEvent.board_created(2, 3, 3)
	]

	var result_value: ActionResult = board.apply_events(events)

	assert_true(result_value.is_error(), "Invalid event batches should fail validation.")
	assert_equal(result_value.error_code, &"board_already_created", "Batch validation should report the later invalid event.")
	assert_false(board.has_cells(), "A failed event batch must not partially mutate board state.")


func _corrupt_snapshot_is_rejected() -> void:
	var result_value: ActionResult = BoardState.try_from_snapshot({
		"width": 2,
		"height": 2,
		"next_sequence_id": 2,
		"cells": [
			_cell_snapshot(0, 0),
			_cell_snapshot(1, 0),
			_cell_snapshot(1, 0),
			_cell_snapshot(0, 3)
		]
	})

	assert_true(result_value.is_error(), "Corrupt board snapshots should be rejected.")
	assert_equal(result_value.error_code, &"duplicate_board_snapshot_cell", "Snapshot validation should reject duplicate coordinates before restore.")


func _snapshot_cells_are_sorted_by_coordinate() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(2, 2)
	command.execute(board)

	var positions: Array[String] = []
	for cell_data: Dictionary in board.to_snapshot().get("cells", []):
		var position: Dictionary = cell_data.get("position", {})
		positions.append("%s,%s" % [position.get("x", -1), position.get("y", -1)])

	assert_equal(positions, ["0,0", "1,0", "0,1", "1,1"], "Board snapshots should serialize cells in stable coordinate order.")


func _cell_snapshot(x: int, y: int) -> Dictionary:
	return {
		"position": {
			"x": x,
			"y": y
		},
		"terrain": BoardCell.Terrain.FLOOR,
		"occupant_id": "",
		"explored": false,
		"visible": false
	}
