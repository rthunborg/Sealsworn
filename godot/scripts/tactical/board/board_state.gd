class_name BoardState
extends RefCounted

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

var width: int = 0
var height: int = 0

var _cells: Dictionary = {}
var _next_sequence_id: int = 1

func has_cells() -> bool:
	return not _cells.is_empty()


func cell_count() -> int:
	return _cells.size()


func next_sequence_id() -> int:
	return _next_sequence_id


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func get_cell(cell: Vector2i) -> BoardCell:
	return _cells.get(cell) as BoardCell


func cells() -> Array[BoardCell]:
	var result: Array[BoardCell] = []
	for value: Variant in _cells.values():
		if value is BoardCell:
			result.append(value)
	result.sort_custom(_sort_cells_by_position)
	return result


func apply_events(events: Array) -> ActionResult:
	var staged_board: BoardState = _copy_for_validation()
	for event: Variant in events:
		if not event is DomainEvent:
			return ActionResult.error(&"invalid_event_type")
		var result: ActionResult = staged_board.apply_event(event)
		if result.is_error():
			return result

	for event: DomainEvent in events:
		_apply_validated_event(event)
	return ActionResult.ok(events)


func apply_event(event: DomainEvent) -> ActionResult:
	var validation: ActionResult = _validate_event(event)
	if validation.is_error():
		return validation

	_apply_validated_event(event)
	return ActionResult.ok([event])


func to_snapshot() -> Dictionary:
	var cell_snapshots: Array[Dictionary] = []
	for board_cell: BoardCell in cells():
		cell_snapshots.append(board_cell.to_dictionary())

	return {
		"width": width,
		"height": height,
		"next_sequence_id": _next_sequence_id,
		"cells": cell_snapshots
	}


static func try_from_snapshot(snapshot: Dictionary) -> ActionResult:
	var snapshot_width: int = int(snapshot.get("width", 0))
	var snapshot_height: int = int(snapshot.get("height", 0))
	var cell_snapshots: Array = snapshot.get("cells", [])

	if snapshot_width <= 0 or snapshot_height <= 0:
		return ActionResult.error(&"invalid_board_snapshot_dimensions", {
			"width": snapshot_width,
			"height": snapshot_height
		})
	if cell_snapshots.size() != snapshot_width * snapshot_height:
		return ActionResult.error(&"invalid_board_snapshot_cell_count", {
			"expected_cell_count": snapshot_width * snapshot_height,
			"actual_cell_count": cell_snapshots.size()
		})

	var board: BoardState = load("res://scripts/tactical/board/board_state.gd").new()
	board.width = snapshot_width
	board.height = snapshot_height
	board._next_sequence_id = max(1, int(snapshot.get("next_sequence_id", 1)))

	var seen_positions: Dictionary = {}

	for cell_data: Variant in cell_snapshots:
		if not cell_data is Dictionary:
			return ActionResult.error(&"invalid_board_snapshot_cell")

		var board_cell: BoardCell = BoardCell.from_dictionary(cell_data)
		if not _position_in_dimensions(board_cell.position, snapshot_width, snapshot_height):
			return ActionResult.error(&"board_snapshot_cell_out_of_bounds", {
				"x": board_cell.position.x,
				"y": board_cell.position.y,
				"width": snapshot_width,
				"height": snapshot_height
			})

		var position_key: String = "%s,%s" % [board_cell.position.x, board_cell.position.y]
		if seen_positions.has(position_key):
			return ActionResult.error(&"duplicate_board_snapshot_cell", {
				"x": board_cell.position.x,
				"y": board_cell.position.y
			})

		seen_positions[position_key] = true
		board._cells[board_cell.position] = board_cell

	return ActionResult.ok([], {"board": board})


static func from_snapshot(snapshot: Dictionary) -> BoardState:
	var result: ActionResult = try_from_snapshot(snapshot)
	if result.is_error():
		push_error("BoardState snapshot parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("board")


func _apply_board_created(new_width: int, new_height: int) -> void:
	width = new_width
	height = new_height
	_cells.clear()
	for y: int in range(height):
		for x: int in range(width):
			var position: Vector2i = Vector2i(x, y)
			_cells[position] = BoardCell.new(position)


func _apply_validated_event(event: DomainEvent) -> void:
	match event.event_type:
		DomainEvent.Type.BOARD_CREATED:
			_apply_board_created(
				int(event.payload.get("width", 0)),
				int(event.payload.get("height", 0))
			)
	_next_sequence_id = event.sequence_id + 1


func _validate_event(event: DomainEvent) -> ActionResult:
	if event.sequence_id != _next_sequence_id:
		return ActionResult.error(&"event_sequence_mismatch", {
			"expected_sequence_id": _next_sequence_id,
			"actual_sequence_id": event.sequence_id
		})

	match event.event_type:
		DomainEvent.Type.BOARD_CREATED:
			var event_width: int = int(event.payload.get("width", 0))
			var event_height: int = int(event.payload.get("height", 0))
			if has_cells():
				return ActionResult.error(&"board_already_created")
			if event_width <= 0 or event_height <= 0:
				return ActionResult.error(&"invalid_board_size")
		_:
			return ActionResult.error(&"unsupported_board_event", {
				"event_id": String(DomainEvent.id_for_type(event.event_type))
			})

	return ActionResult.ok()


func _copy_for_validation() -> BoardState:
	var board: BoardState = load("res://scripts/tactical/board/board_state.gd").new()
	board.width = width
	board.height = height
	board._next_sequence_id = _next_sequence_id
	for board_cell: BoardCell in cells():
		var cell_copy: BoardCell = BoardCell.from_dictionary(board_cell.to_dictionary())
		board._cells[cell_copy.position] = cell_copy
	return board


static func _position_in_dimensions(position: Vector2i, board_width: int, board_height: int) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < board_width and position.y < board_height


static func _sort_cells_by_position(first: BoardCell, second: BoardCell) -> bool:
	if first.position.y == second.position.y:
		return first.position.x < second.position.x
	return first.position.y < second.position.y
