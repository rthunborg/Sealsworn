class_name TacticalLineQuery
extends RefCounted

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")

static func supercover_line(origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [origin]
	if origin == target:
		return cells

	var delta: Vector2i = target - origin
	var steps_x: int = abs(delta.x)
	var steps_y: int = abs(delta.y)
	var step_x: int = _step_sign(delta.x)
	var step_y: int = _step_sign(delta.y)
	var current: Vector2i = origin
	var walked_x: int = 0
	var walked_y: int = 0

	while walked_x < steps_x or walked_y < steps_y:
		var decision: int = (1 + 2 * walked_x) * steps_y - (1 + 2 * walked_y) * steps_x
		if decision == 0:
			if walked_x < steps_x:
				_append_unique_cell(cells, Vector2i(current.x + step_x, current.y))
			if walked_y < steps_y:
				_append_unique_cell(cells, Vector2i(current.x, current.y + step_y))
			current += Vector2i(step_x, step_y)
			walked_x += 1
			walked_y += 1
			_append_unique_cell(cells, current)
		elif decision < 0:
			current.x += step_x
			walked_x += 1
			_append_unique_cell(cells, current)
		else:
			current.y += step_y
			walked_y += 1
			_append_unique_cell(cells, current)

	return cells


static func has_line_of_sight(board: BoardState, origin: Vector2i, target: Vector2i) -> bool:
	if board == null:
		return false
	var blockers: Array[Vector2i] = blocking_cells(board, origin, target, false)
	return blockers.is_empty()


static func blocking_cells(
	board: BoardState,
	origin: Vector2i,
	target: Vector2i,
	include_entities: bool = true,
	ignored_entity_id: StringName = &""
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if board == null:
		return result

	var line: Array[Vector2i] = supercover_line(origin, target)
	for index: int in range(1, max(1, line.size() - 1)):
		var board_cell: BoardCell = board.get_cell(line[index])
		if board_cell == null:
			continue
		var terrain_blocks: bool = board_cell.blocks_line_of_sight()
		var entity_blocks: bool = (
			include_entities
			and board_cell.occupant_id != &""
			and board_cell.occupant_id != ignored_entity_id
		)
		if terrain_blocks or entity_blocks:
			result.append(line[index])

	return result


static func _append_unique_cell(cells: Array[Vector2i], cell: Vector2i) -> void:
	if not cells.has(cell):
		cells.append(cell)


static func _step_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0
