extends "res://tests/unit/test_case.gd"

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_board_snapshot_round_trips()
	_bounds_check_uses_domain_dimensions()
	_invalid_board_created_event_does_not_mutate()
	_board_created_event_rejects_malformed_payload_dimensions()
	_replayed_board_created_event_is_rejected()
	_event_batches_are_atomic()
	_event_batches_reject_invalid_types_atomically()
	_unsupported_board_events_use_stable_reason_code()
	_corrupt_snapshot_is_rejected()
	_snapshot_cells_are_sorted_by_coordinate()
	_fixed_domain_board_places_player_and_enemy()
	_terrain_and_occupancy_queries_do_not_mutate()
	_blocking_entities_cannot_share_cell()
	_invalid_entity_setup_does_not_mutate()
	_blocking_terrain_rejects_entities_on_cell()
	_entity_snapshot_round_trips_with_tactical_state()
	_corrupt_entity_snapshots_are_rejected()
	return result()


func _board_snapshot_round_trips() -> void:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(2, 2)
	command.execute(board)

	var place_result: ActionResult = board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(1, 1),
		18,
		18
	))
	assert_true(place_result.succeeded, "Snapshot test setup should place a valid entity.")

	var cell: BoardCell = board.get_cell(Vector2i(1, 1))
	cell.visible = true
	cell.explored = true

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


func _board_created_event_rejects_malformed_payload_dimensions() -> void:
	var valid_json_event_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify({
		"event_id": "board_created",
		"sequence_id": 1,
		"actor_id": "",
		"payload": {
			"width": 2,
			"height": 2
		}
	})) as Dictionary)
	var valid_json_board: BoardState = BoardState.new()
	var valid_json_event: DomainEvent = valid_json_event_result.metadata.get("event") as DomainEvent
	var valid_json_result: ActionResult = valid_json_board.apply_event(valid_json_event)

	var string_payload_board: BoardState = BoardState.new()
	var string_payload_event: DomainEvent = DomainEvent.new(
		DomainEvent.Type.BOARD_CREATED,
		string_payload_board.next_sequence_id(),
		&"",
		{"width": "2", "height": 2}
	)
	var string_payload_result: ActionResult = string_payload_board.apply_event(string_payload_event)

	var fractional_payload_board: BoardState = BoardState.new()
	var fractional_payload_event: DomainEvent = DomainEvent.new(
		DomainEvent.Type.BOARD_CREATED,
		fractional_payload_board.next_sequence_id(),
		&"",
		{"width": 2.5, "height": 2}
	)
	var fractional_payload_result: ActionResult = fractional_payload_board.apply_event(fractional_payload_event)

	assert_true(valid_json_event_result.succeeded, "JSON round-tripped board-created events should parse.")
	assert_true(valid_json_result.succeeded, "JSON round-tripped integral board dimensions should replay.")
	assert_true(string_payload_result.is_error(), "String board dimensions should be rejected.")
	assert_equal(string_payload_result.error_code, &"invalid_board_size", "String dimensions should use the stable board-size error code.")
	assert_false(string_payload_board.has_cells(), "String dimension payloads must not mutate the board.")
	assert_true(fractional_payload_result.is_error(), "Fractional board dimensions should be rejected.")
	assert_equal(fractional_payload_result.error_code, &"invalid_board_size", "Fractional dimensions should use the stable board-size error code.")
	assert_false(fractional_payload_board.has_cells(), "Fractional dimension payloads must not mutate the board.")


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


func _event_batches_reject_invalid_types_atomically() -> void:
	var board: BoardState = BoardState.new()
	var snapshot_before: Dictionary = board.to_snapshot()
	var events: Array = [
		DomainEvent.board_created(1, 2, 2),
		"not_a_domain_event"
	]

	var result_value: ActionResult = board.apply_events(events)

	assert_true(result_value.is_error(), "Event batches should reject non-DomainEvent values.")
	assert_equal(result_value.error_code, &"invalid_event_type", "Invalid batch event types should use a stable error code.")
	assert_false(result_value.has_events(), "Failed event batches should not expose partial events.")
	assert_equal(board.to_snapshot(), snapshot_before, "Rejected event batches must not mutate board snapshots.")


func _unsupported_board_events_use_stable_reason_code() -> void:
	var board: BoardState = BoardState.new()
	var unsupported_event: DomainEvent = DomainEvent.new(
		DomainEvent.Type.RNG_STREAM_ADVANCED,
		board.next_sequence_id(),
		&"combat_rng",
		{"stream_id": "combat"}
	)

	var result_value: ActionResult = board.apply_event(unsupported_event)

	assert_true(result_value.is_error(), "BoardState should reject unsupported domain events.")
	assert_equal(result_value.error_code, &"unsupported_board_event", "Unsupported board events should use a stable reason code.")
	assert_equal(result_value.metadata.get("event_id"), "rng_stream_advanced", "Unsupported board event diagnostics should use stable event ids.")
	assert_false(result_value.has_events(), "Unsupported board events should not return partial events.")


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


func _fixed_domain_board_places_player_and_enemy() -> void:
	var board: BoardState = _new_board(3, 2)
	var hero: TacticalEntityState = _entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(0, 0),
		18,
		18
	)
	var enemy: TacticalEntityState = _entity(
		&"enemy_1",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(2, 1),
		10,
		10
	)

	var hero_result: ActionResult = board.place_entity_for_setup(hero)
	var enemy_result: ActionResult = board.place_entity_for_setup(enemy)

	assert_true(hero_result.succeeded, "Fixed board setup should place the player entity.")
	assert_true(enemy_result.succeeded, "Fixed board setup should place an optional enemy entity.")
	assert_true(board.has_entity(&"hero"), "Board should store entities by stable id.")
	assert_true(board.has_entity(&"enemy_1"), "Board should store optional enemies by stable id.")
	assert_equal(board.occupant_at(Vector2i(0, 0)), &"hero", "Occupancy query should return the player id.")
	assert_equal(board.occupant_at(Vector2i(2, 1)), &"enemy_1", "Occupancy query should return the enemy id.")
	assert_equal(board.entity_at(Vector2i(2, 1)).entity_id, &"enemy_1", "Entity lookup by cell should return the occupying entity.")
	var hero_variant: Variant = hero
	assert_false(hero_variant is Node, "Tactical entity state must be scene-independent.")

	var entity_ids: Array[String] = []
	for entity_data: Dictionary in board.to_snapshot().get("entities", []):
		entity_ids.append(str(entity_data.get("entity_id", "")))
	assert_equal(entity_ids, ["enemy_1", "hero"], "Entity snapshots should be exported in deterministic id order.")


func _terrain_and_occupancy_queries_do_not_mutate() -> void:
	var board: BoardState = _new_board(3, 3)
	board.set_cell_terrain_for_setup(Vector2i(1, 1), BoardCell.Terrain.WALL)
	board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(0, 0),
		18,
		18
	))
	var snapshot_before_queries: Dictionary = board.to_snapshot()
	var sequence_before_queries: int = board.next_sequence_id()

	var out_of_bounds: ActionResult = board.can_occupy(Vector2i(3, 0))
	var wall_cell: ActionResult = board.can_occupy(Vector2i(1, 1))
	var occupied_cell: ActionResult = board.can_occupy(Vector2i(0, 0), &"enemy_1")

	assert_true(out_of_bounds.is_error(), "Out-of-bounds occupancy query should fail.")
	assert_equal(out_of_bounds.error_code, &"cell_out_of_bounds", "Out-of-bounds query should use a stable error code.")
	assert_true(wall_cell.is_error(), "Wall occupancy query should fail.")
	assert_equal(wall_cell.error_code, &"terrain_blocks_occupancy", "Wall query should use a stable error code.")
	assert_true(occupied_cell.is_error(), "Occupied-cell query should fail for another blocking entity.")
	assert_equal(occupied_cell.error_code, &"cell_occupied", "Occupied-cell query should use a stable error code.")
	assert_equal(board.to_snapshot(), snapshot_before_queries, "Validation queries must not mutate the board snapshot.")
	assert_equal(board.next_sequence_id(), sequence_before_queries, "Validation queries must not advance event sequence ids.")


func _blocking_entities_cannot_share_cell() -> void:
	var board: BoardState = _new_board(2, 2)
	var hero: TacticalEntityState = _entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(1, 1),
		18,
		18
	)
	var enemy: TacticalEntityState = _entity(
		&"enemy_1",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(1, 1),
		10,
		10
	)

	var hero_result: ActionResult = board.place_entity_for_setup(hero)
	var snapshot_after_hero: Dictionary = board.to_snapshot()
	var enemy_result: ActionResult = board.place_entity_for_setup(enemy)

	assert_true(hero_result.succeeded, "Initial blocking entity placement should succeed.")
	assert_true(enemy_result.is_error(), "Second blocking entity in same cell should be rejected.")
	assert_equal(enemy_result.error_code, &"cell_occupied", "Duplicate blocking occupancy should report occupied cell.")
	assert_equal(board.occupant_at(Vector2i(1, 1)), &"hero", "Original occupant should remain in the cell.")
	assert_equal(board.to_snapshot(), snapshot_after_hero, "Rejected duplicate occupancy must not mutate board state.")


func _invalid_entity_setup_does_not_mutate() -> void:
	var board: BoardState = _new_board(2, 2)
	var wall_result: ActionResult = board.set_cell_terrain_for_setup(Vector2i(1, 0), BoardCell.Terrain.WALL)
	assert_true(wall_result.succeeded, "Wall setup should succeed before invalid entity placement checks.")
	var snapshot_before_invalid_setup: Dictionary = board.to_snapshot()

	var invalid_id_result: ActionResult = board.place_entity_for_setup(_entity(
		&"",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(0, 0),
		18,
		18
	))
	var wall_placement_result: ActionResult = board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(1, 0),
		18,
		18
	))
	var out_of_bounds_result: ActionResult = board.place_entity_for_setup(_entity(
		&"enemy_1",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(2, 0),
		10,
		10
	))

	assert_true(invalid_id_result.is_error(), "Entity placement should reject invalid entity data.")
	assert_equal(invalid_id_result.error_code, &"invalid_entity_data", "Invalid entity data should have a stable error code.")
	assert_true(wall_placement_result.is_error(), "Entity placement should reject blocking terrain.")
	assert_equal(wall_placement_result.error_code, &"terrain_blocks_occupancy", "Blocking terrain placement should have a stable error code.")
	assert_true(out_of_bounds_result.is_error(), "Entity placement should reject out-of-bounds positions.")
	assert_equal(out_of_bounds_result.error_code, &"cell_out_of_bounds", "Out-of-bounds placement should have a stable error code.")
	assert_equal(board.to_snapshot(), snapshot_before_invalid_setup, "Failed entity setup must not mutate board state.")


func _blocking_terrain_rejects_entities_on_cell() -> void:
	var board: BoardState = _new_board(2, 2)
	var nonblocking_entity: TacticalEntityState = _entity(
		&"pickup_marker",
		TacticalEntityState.EntityType.ENEMY,
		&"neutral",
		Vector2i(1, 1),
		1,
		1,
		false
	)
	var place_result: ActionResult = board.place_entity_for_setup(nonblocking_entity)
	var snapshot_before_wall: Dictionary = board.to_snapshot()

	var terrain_result: ActionResult = board.set_cell_terrain_for_setup(Vector2i(1, 1), BoardCell.Terrain.WALL)

	assert_true(place_result.succeeded, "Non-blocking entity setup should be valid before wall placement.")
	assert_true(terrain_result.is_error(), "Wall setup should reject any entity already positioned on the cell.")
	assert_equal(terrain_result.error_code, &"cell_occupied", "Wall-over-entity setup should use occupied-cell validation.")
	assert_equal(board.to_snapshot(), snapshot_before_wall, "Rejected terrain setup must not mutate board state.")


func _entity_snapshot_round_trips_with_tactical_state() -> void:
	var board: BoardState = _new_board(3, 2)
	board.set_cell_terrain_for_setup(Vector2i(1, 0), BoardCell.Terrain.WALL)
	board.set_cell_terrain_for_setup(Vector2i(0, 0), BoardCell.Terrain.ENTRANCE)
	board.set_cell_terrain_for_setup(Vector2i(2, 1), BoardCell.Terrain.EXIT)
	board.get_cell(Vector2i(2, 1)).visible = true
	board.get_cell(Vector2i(2, 1)).explored = true
	board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(0, 0),
		18,
		18
	))
	board.place_entity_for_setup(_entity(
		&"enemy_1",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(2, 1),
		10,
		10
	))

	var snapshot: Dictionary = board.to_snapshot()
	var restore_result: ActionResult = BoardState.try_from_snapshot(snapshot)
	var restored: BoardState = restore_result.metadata.get("board") as BoardState

	assert_true(restore_result.succeeded, "Snapshot with entity state should restore successfully.")
	assert_equal(restored.width, 3, "Entity snapshot restore should preserve width.")
	assert_equal(restored.height, 2, "Entity snapshot restore should preserve height.")
	assert_equal(restored.cell_count(), 6, "Entity snapshot restore should preserve all terrain cells.")
	assert_equal(restored.entity_count(), 2, "Entity snapshot restore should preserve entity snapshots.")
	assert_equal(restored.get_cell(Vector2i(1, 0)).terrain, BoardCell.Terrain.WALL, "Entity snapshot restore should preserve blocking terrain.")
	assert_true(restored.get_cell(Vector2i(2, 1)).visible, "Entity snapshot restore should preserve visibility state.")
	assert_true(restored.get_cell(Vector2i(2, 1)).explored, "Entity snapshot restore should preserve explored memory state.")
	assert_equal(restored.occupant_at(Vector2i(0, 0)), &"hero", "Entity snapshot restore should preserve player occupancy.")
	assert_equal(restored.occupant_at(Vector2i(2, 1)), &"enemy_1", "Entity snapshot restore should preserve enemy occupancy.")
	assert_equal(restored.get_entity(&"hero").current_hp, 18, "Entity snapshot restore should preserve entity HP.")


func _corrupt_entity_snapshots_are_rejected() -> void:
	var duplicate_id_result: ActionResult = BoardState.try_from_snapshot(_snapshot_with_entities([
		_entity_snapshot("hero", "player", "player", 0, 0, 18, 18),
		_entity_snapshot("hero", "enemy", "enemy", 1, 0, 10, 10)
	]))
	var out_of_bounds_result: ActionResult = BoardState.try_from_snapshot(_snapshot_with_entities([
		_entity_snapshot("enemy_1", "enemy", "enemy", 2, 0, 10, 10)
	]))
	var wall_entity_snapshot: Dictionary = _snapshot_with_entities([
		_entity_snapshot("hero", "player", "player", 1, 0, 18, 18)
	])
	var wall_cell: Dictionary = wall_entity_snapshot["cells"][1]
	wall_cell["terrain"] = BoardCell.Terrain.WALL
	var wall_entity_result: ActionResult = BoardState.try_from_snapshot(wall_entity_snapshot)
	var duplicate_occupant_result: ActionResult = BoardState.try_from_snapshot(_snapshot_with_entities([
		_entity_snapshot("hero", "player", "player", 0, 0, 18, 18),
		_entity_snapshot("enemy_1", "enemy", "enemy", 0, 0, 10, 10)
	]))
	var invalid_terrain_snapshot: Dictionary = _snapshot_with_entities([])
	invalid_terrain_snapshot["cells"][0]["terrain"] = 999
	var invalid_terrain_result: ActionResult = BoardState.try_from_snapshot(invalid_terrain_snapshot)
	var ghost_occupant_snapshot: Dictionary = _snapshot_with_entities([])
	ghost_occupant_snapshot["cells"][0]["occupant_id"] = "ghost"
	var ghost_occupant_result: ActionResult = BoardState.try_from_snapshot(ghost_occupant_snapshot)
	var misplaced_occupant_snapshot: Dictionary = _snapshot_with_entities([
		_entity_snapshot("hero", "player", "player", 1, 0, 18, 18)
	])
	misplaced_occupant_snapshot["cells"][0]["occupant_id"] = "hero"
	var misplaced_occupant_result: ActionResult = BoardState.try_from_snapshot(misplaced_occupant_snapshot)

	assert_true(duplicate_id_result.is_error(), "Corrupt snapshots should reject duplicate entity ids.")
	assert_equal(duplicate_id_result.error_code, &"duplicate_entity_id", "Duplicate entity ids should use a stable error code.")
	assert_true(out_of_bounds_result.is_error(), "Corrupt snapshots should reject entity positions outside the board.")
	assert_equal(out_of_bounds_result.error_code, &"cell_out_of_bounds", "Out-of-bounds entity positions should use a stable error code.")
	assert_true(wall_entity_result.is_error(), "Corrupt snapshots should reject entities on blocking terrain.")
	assert_equal(wall_entity_result.error_code, &"terrain_blocks_occupancy", "Entities on walls should use the terrain blocking error code.")
	assert_true(duplicate_occupant_result.is_error(), "Corrupt snapshots should reject duplicate blocking occupants.")
	assert_equal(duplicate_occupant_result.error_code, &"cell_occupied", "Duplicate blocking occupants should use the occupied-cell error code.")
	assert_true(invalid_terrain_result.is_error(), "Corrupt snapshots should reject invalid terrain enum values.")
	assert_equal(invalid_terrain_result.error_code, &"invalid_terrain", "Invalid terrain snapshots should use a stable terrain error code.")
	assert_true(ghost_occupant_result.is_error(), "Corrupt snapshots should reject occupant ids without matching entity snapshots.")
	assert_equal(ghost_occupant_result.error_code, &"invalid_cell_occupant", "Ghost occupants should use a stable occupant error code.")
	assert_true(misplaced_occupant_result.is_error(), "Corrupt snapshots should reject occupant ids on the wrong cell.")
	assert_equal(misplaced_occupant_result.error_code, &"invalid_cell_occupant", "Misplaced occupants should use a stable occupant error code.")


func _new_board(new_width: int, new_height: int) -> BoardState:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(new_width, new_height)
	var result_value: ActionResult = command.execute(board)
	assert_true(result_value.succeeded, "Test helper should create a valid board.")
	return board


func _entity(
	entity_id: StringName,
	entity_type: int,
	faction: StringName,
	position: Vector2i,
	current_hp: int = 1,
	max_hp: int = 1,
	blocks_movement: bool = true
) -> TacticalEntityState:
	return TacticalEntityState.new(
		entity_id,
		entity_type,
		faction,
		position,
		current_hp,
		max_hp,
		blocks_movement
	)


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


func _snapshot_with_entities(entity_snapshots: Array[Dictionary]) -> Dictionary:
	return {
		"width": 2,
		"height": 1,
		"next_sequence_id": 2,
		"cells": [
			_cell_snapshot(0, 0),
			_cell_snapshot(1, 0)
		],
		"entities": entity_snapshots
	}


func _entity_snapshot(
	entity_id: String,
	entity_type: String,
	faction: String,
	x: int,
	y: int,
	current_hp: int,
	max_hp: int,
	blocks_movement: bool = true
) -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_type": entity_type,
		"faction": faction,
		"position": {
			"x": x,
			"y": y
		},
		"current_hp": current_hp,
		"max_hp": max_hp,
		"blocks_movement": blocks_movement
	}
