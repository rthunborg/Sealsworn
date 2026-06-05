class_name BoardState
extends RefCounted

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

var width: int = 0
var height: int = 0

var _cells: Dictionary = {}
var _entities: Dictionary = {}
var _next_sequence_id: int = 1

func has_cells() -> bool:
	return not _cells.is_empty()


func cell_count() -> int:
	return _cells.size()


func entity_count() -> int:
	return _entities.size()


func next_sequence_id() -> int:
	return _next_sequence_id


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func get_cell(cell: Vector2i) -> BoardCell:
	return _cells.get(cell) as BoardCell


func has_entity(entity_id: StringName) -> bool:
	return _entities.has(entity_id)


func get_entity(entity_id: StringName) -> TacticalEntityState:
	var entity: TacticalEntityState = _entities.get(entity_id) as TacticalEntityState
	if entity == null:
		return null
	return entity.copy()


func cells() -> Array[BoardCell]:
	var result: Array[BoardCell] = []
	for value: Variant in _cells.values():
		if value is BoardCell:
			result.append(value)
	result.sort_custom(_sort_cells_by_position)
	return result


func entities() -> Array[TacticalEntityState]:
	var result: Array[TacticalEntityState] = []
	for value: Variant in _entities.values():
		if value is TacticalEntityState:
			result.append((value as TacticalEntityState).copy())
	result.sort_custom(_sort_entities_by_id)
	return result


func occupant_at(cell: Vector2i) -> StringName:
	var board_cell: BoardCell = get_cell(cell)
	if board_cell == null:
		return &""
	return board_cell.occupant_id


func entity_at(cell: Vector2i) -> TacticalEntityState:
	var occupant_id: StringName = occupant_at(cell)
	if occupant_id != &"":
		return get_entity(occupant_id)

	for entity: TacticalEntityState in entities():
		if entity.position == cell:
			return entity
	return null


func can_occupy(cell: Vector2i, entity_id: StringName = &"") -> ActionResult:
	return _validate_cell_for_occupancy(cell, entity_id)


func set_cell_terrain_for_setup(cell: Vector2i, terrain: int) -> ActionResult:
	if not in_bounds(cell):
		return _cell_out_of_bounds(cell)
	if not _is_valid_terrain(terrain):
		return ActionResult.error(&"invalid_terrain", {
			"terrain": terrain
		})

	var board_cell: BoardCell = get_cell(cell)
	if board_cell == null:
		return _cell_out_of_bounds(cell)
	if terrain == BoardCell.Terrain.WALL:
		var existing_entity: TacticalEntityState = entity_at(cell)
		if existing_entity != null:
			return ActionResult.error(&"cell_occupied", {
				"x": cell.x,
				"y": cell.y,
				"occupant_id": String(existing_entity.entity_id)
			})
		if board_cell.is_occupied():
			return ActionResult.error(&"cell_occupied", {
				"x": cell.x,
				"y": cell.y,
				"occupant_id": String(board_cell.occupant_id)
			})

	board_cell.terrain = terrain
	return ActionResult.ok()


func place_entity_for_setup(entity: TacticalEntityState) -> ActionResult:
	var validation: ActionResult = _validate_entity_for_setup(entity)
	if validation.is_error():
		return validation

	_store_entity_for_setup(entity)
	return ActionResult.ok([], {
		"entity_id": String(entity.entity_id)
	})


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

	var entity_snapshots: Array[Dictionary] = []
	for entity: TacticalEntityState in entities():
		entity_snapshots.append(entity.to_dictionary())

	return {
		"width": width,
		"height": height,
		"next_sequence_id": _next_sequence_id,
		"cells": cell_snapshots,
		"entities": entity_snapshots
	}


static func try_from_snapshot(snapshot: Dictionary) -> ActionResult:
	var snapshot_width: int = int(snapshot.get("width", 0))
	var snapshot_height: int = int(snapshot.get("height", 0))
	var cell_snapshots: Array = snapshot.get("cells", [])
	var entity_snapshots_value: Variant = snapshot.get("entities", [])

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
	var snapshot_occupants: Dictionary = {}

	for cell_data: Variant in cell_snapshots:
		if not cell_data is Dictionary:
			return ActionResult.error(&"invalid_board_snapshot_cell")

		var board_cell: BoardCell = BoardCell.from_dictionary(cell_data)
		if not _is_valid_terrain(board_cell.terrain):
			return ActionResult.error(&"invalid_terrain", {
				"x": board_cell.position.x,
				"y": board_cell.position.y,
				"terrain": board_cell.terrain
			})
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
		if board_cell.occupant_id != &"":
			snapshot_occupants[board_cell.position] = board_cell.occupant_id
			board_cell.occupant_id = &""
		board._cells[board_cell.position] = board_cell

	if not entity_snapshots_value is Array:
		return ActionResult.error(&"invalid_board_snapshot_entities")

	var seen_entity_ids: Dictionary = {}
	var entity_snapshots: Array = entity_snapshots_value
	for entity_data: Variant in entity_snapshots:
		if not entity_data is Dictionary:
			return ActionResult.error(&"invalid_entity_data")

		var entity_result: ActionResult = TacticalEntityState.try_from_dictionary(entity_data)
		if entity_result.is_error():
			return entity_result

		var entity: TacticalEntityState = entity_result.metadata.get("entity") as TacticalEntityState
		if seen_entity_ids.has(entity.entity_id):
			return ActionResult.error(&"duplicate_entity_id", {
				"entity_id": String(entity.entity_id)
			})

		seen_entity_ids[entity.entity_id] = true
		var placement_validation: ActionResult = board._validate_entity_for_setup(entity)
		if placement_validation.is_error():
			return placement_validation

		board._store_entity_for_setup(entity)

	var occupant_validation: ActionResult = board._validate_snapshot_occupants(snapshot_occupants)
	if occupant_validation.is_error():
		return occupant_validation

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
	_entities.clear()
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
			var width_value: Variant = event.payload.get("width")
			var height_value: Variant = event.payload.get("height")
			if not _is_integral_number(width_value) or not _is_integral_number(height_value):
				return ActionResult.error(&"invalid_board_size")

			var event_width: int = int(width_value)
			var event_height: int = int(height_value)
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
	for entity: TacticalEntityState in entities():
		board._entities[entity.entity_id] = entity.copy()
	return board


func _validate_entity_for_setup(entity: TacticalEntityState) -> ActionResult:
	if entity == null:
		return ActionResult.error(&"invalid_entity_data", {
			"field": "entity"
		})

	var entity_validation: ActionResult = entity.validate()
	if entity_validation.is_error():
		return entity_validation
	if _entities.has(entity.entity_id):
		return ActionResult.error(&"entity_id_already_exists", {
			"entity_id": String(entity.entity_id)
		})

	return _validate_cell_for_occupancy(entity.position, entity.entity_id)


func _store_entity_for_setup(entity: TacticalEntityState) -> void:
	var stored_entity: TacticalEntityState = entity.copy()
	_entities[stored_entity.entity_id] = stored_entity

	if stored_entity.blocks_movement:
		var board_cell: BoardCell = get_cell(stored_entity.position)
		board_cell.occupant_id = stored_entity.entity_id


func _validate_cell_for_occupancy(cell: Vector2i, entity_id: StringName = &"") -> ActionResult:
	if not in_bounds(cell):
		return _cell_out_of_bounds(cell)

	var board_cell: BoardCell = get_cell(cell)
	if board_cell == null:
		return _cell_out_of_bounds(cell)
	if board_cell.terrain_blocks_occupancy():
		return ActionResult.error(&"terrain_blocks_occupancy", {
			"x": cell.x,
			"y": cell.y,
			"terrain": board_cell.terrain
		})
	if board_cell.occupant_id != &"" and board_cell.occupant_id != entity_id:
		return ActionResult.error(&"cell_occupied", {
			"x": cell.x,
			"y": cell.y,
			"occupant_id": String(board_cell.occupant_id)
		})

	return ActionResult.ok()


func _validate_snapshot_occupants(snapshot_occupants: Dictionary) -> ActionResult:
	for position_value: Variant in snapshot_occupants.keys():
		var position: Vector2i = position_value
		var occupant_id: StringName = snapshot_occupants.get(position, &"")
		var entity: TacticalEntityState = _entities.get(occupant_id) as TacticalEntityState
		if entity == null:
			return _invalid_cell_occupant(position, occupant_id)
		if entity.position != position or not entity.blocks_movement:
			return _invalid_cell_occupant(position, occupant_id)

		var board_cell: BoardCell = get_cell(position)
		if board_cell == null or board_cell.occupant_id != occupant_id:
			return _invalid_cell_occupant(position, occupant_id)

	return ActionResult.ok()


func _invalid_cell_occupant(cell: Vector2i, occupant_id: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_cell_occupant", {
		"x": cell.x,
		"y": cell.y,
		"occupant_id": String(occupant_id)
	})


func _cell_out_of_bounds(cell: Vector2i) -> ActionResult:
	return ActionResult.error(&"cell_out_of_bounds", {
		"x": cell.x,
		"y": cell.y,
		"width": width,
		"height": height
	})


static func _is_valid_terrain(terrain: int) -> bool:
	return terrain >= BoardCell.Terrain.FLOOR and terrain <= BoardCell.Terrain.EXIT


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


static func _position_in_dimensions(position: Vector2i, board_width: int, board_height: int) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < board_width and position.y < board_height


static func _sort_cells_by_position(first: BoardCell, second: BoardCell) -> bool:
	if first.position.y == second.position.y:
		return first.position.x < second.position.x
	return first.position.y < second.position.y


static func _sort_entities_by_id(first: TacticalEntityState, second: TacticalEntityState) -> bool:
	return String(first.entity_id) < String(second.entity_id)
