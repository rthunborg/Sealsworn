class_name TacticalVisibilityQuery
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

const DEFAULT_LINE_OF_SIGHT_RADIUS: int = 4

func calculate_visible_cells(
	board: BoardState,
	origin: Vector2i,
	radius: int = DEFAULT_LINE_OF_SIGHT_RADIUS
) -> ActionResult:
	if board == null:
		return _invalid(&"invalid_board")
	if radius <= 0:
		return _invalid(&"invalid_radius", {"radius": radius})
	if not board.in_bounds(origin):
		return _invalid(&"origin_out_of_bounds", _cell_metadata(origin))

	var visible_cells: Array[Vector2i] = []
	var radius_squared: int = radius * radius
	for y: int in range(board.height):
		for x: int in range(board.width):
			var candidate: Vector2i = Vector2i(x, y)
			if origin.distance_squared_to(candidate) > radius_squared:
				continue
			if _has_line_of_sight(board, origin, candidate):
				visible_cells.append(candidate)

	return ActionResult.ok([], {
		"origin": _cell_metadata(origin),
		"radius": radius,
		"visible_cells": _serialize_cells(visible_cells)
	})


func create_visibility_updated_event(
	board: BoardState,
	actor_id: StringName,
	radius: int = DEFAULT_LINE_OF_SIGHT_RADIUS
) -> ActionResult:
	if board == null:
		return _invalid(&"invalid_board")
	if actor_id == &"":
		return _invalid(&"invalid_actor", {"actor_id": String(actor_id)})

	var actor: TacticalEntityState = board.get_entity(actor_id)
	if actor == null:
		return _invalid(&"invalid_actor", {"actor_id": String(actor_id)})

	var calculation: ActionResult = calculate_visible_cells(board, actor.position, radius)
	if calculation.is_error():
		return calculation

	var visible_cells: Array[Vector2i] = _deserialize_cells(calculation.metadata.get("visible_cells", []))
	var newly_explored_cells: Array[Vector2i] = []
	for cell: Vector2i in visible_cells:
		var board_cell: BoardCell = board.get_cell(cell)
		if board_cell != null and not board_cell.explored:
			newly_explored_cells.append(cell)

	var event: DomainEvent = DomainEvent.visibility_updated(
		board.next_sequence_id(),
		actor_id,
		actor.position,
		radius,
		visible_cells,
		newly_explored_cells
	)
	return ActionResult.ok([event], {
		"origin": _cell_metadata(actor.position),
		"radius": radius,
		"visible_cells": _serialize_cells(visible_cells),
		"newly_explored_cells": _serialize_cells(newly_explored_cells)
	})


func visible_facts_for_cell(board: BoardState, cell: Vector2i) -> ActionResult:
	if board == null:
		return _invalid(&"invalid_board")
	if not board.in_bounds(cell):
		return _invalid(&"out_of_bounds", _cell_metadata(cell))

	var board_cell: BoardCell = board.get_cell(cell)
	if board_cell == null:
		return _invalid(&"out_of_bounds", _cell_metadata(cell))

	var position: Dictionary = _cell_metadata(cell)
	if not board_cell.visible and not board_cell.explored:
		return ActionResult.ok([], {
			"fact": {
				"position": position,
				"visibility_state": "hidden"
			}
		})

	if not board_cell.visible and board_cell.explored:
		return ActionResult.ok([], {
			"fact": {
				"position": position,
				"visibility_state": "memory",
				"authoritative": false,
				"terrain": board_cell.terrain,
				"blocks_line_of_sight": board_cell.blocks_line_of_sight(),
				"terrain_blocks_occupancy": board_cell.terrain_blocks_occupancy()
			}
		})

	var fact: Dictionary = {
		"position": position,
		"visibility_state": "visible",
		"authoritative": true,
		"terrain": board_cell.terrain,
		"blocks_line_of_sight": board_cell.blocks_line_of_sight(),
		"terrain_blocks_occupancy": board_cell.terrain_blocks_occupancy()
	}
	if board_cell.occupant_id != &"":
		fact["occupant_id"] = String(board_cell.occupant_id)
		var occupant: TacticalEntityState = board.get_entity(board_cell.occupant_id)
		if occupant != null:
			fact["entity_type"] = String(TacticalEntityState.id_for_entity_type(occupant.entity_type))
			fact["faction"] = String(occupant.faction)
			fact["current_hp"] = occupant.current_hp
			fact["max_hp"] = occupant.max_hp
			fact["blocks_movement"] = occupant.blocks_movement
	return ActionResult.ok([], {"fact": fact})


func _has_line_of_sight(board: BoardState, origin: Vector2i, target: Vector2i) -> bool:
	var line: Array[Vector2i] = _supercover_line(origin, target)
	for index: int in range(1, max(1, line.size() - 1)):
		var board_cell: BoardCell = board.get_cell(line[index])
		if board_cell != null and board_cell.blocks_line_of_sight():
			return false
	return true


func _supercover_line(origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
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


func _append_unique_cell(cells: Array[Vector2i], cell: Vector2i) -> void:
	if not cells.has(cell):
		cells.append(cell)


func _step_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


func _serialize_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var sorted_cells: Array[Vector2i] = cells.duplicate()
	sorted_cells.sort_custom(_sort_cells_by_position)
	var result: Array[Dictionary] = []
	for cell: Vector2i in sorted_cells:
		result.append(_cell_metadata(cell))
	return result


func _deserialize_cells(cells_value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not cells_value is Array:
		return result
	var cells: Array = cells_value
	for cell_value: Variant in cells:
		if not cell_value is Dictionary:
			continue
		var cell_data: Dictionary = cell_value
		result.append(Vector2i(
			int(cell_data.get("x", 0)),
			int(cell_data.get("y", 0))
		))
	return result


func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_visibility_query", result_metadata)


static func _sort_cells_by_position(first: Vector2i, second: Vector2i) -> bool:
	if first.y == second.y:
		return first.x < second.x
	return first.y < second.y
