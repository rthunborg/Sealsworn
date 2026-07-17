extends "res://tests/unit/test_case.gd"

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
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
	_entity_moved_event_updates_occupancy_atomically()
	_invalid_entity_moved_events_do_not_mutate()
	_visibility_updated_event_updates_current_visible_and_memory_atomically()
	_invalid_visibility_updated_events_do_not_mutate()
	_attack_damage_events_update_hp_and_replay_atomically()
	_damage_application_clamps_hp_without_outcome_events()
	_attack_status_events_are_replayable_noops()
	_knockback_events_update_position_and_occupancy_atomically()
	_invalid_attack_events_do_not_mutate()
	_detonation_events_reject_outcome_position_contradictions()
	_outcome_events_advance_sequence_without_board_mutation()
	_invalid_outcome_events_do_not_mutate()
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
	_malformed_cell_snapshots_are_rejected_strictly()
	_malformed_cells_container_is_rejected_without_mutation()
	_malformed_top_level_snapshot_fields_are_rejected()
	_snapshot_occupant_consistency_is_strict()
	_dead_blocking_entity_releases_its_cell_occupancy()
	_hero_waited_event_validates_and_applies_as_noop()
	_snapshot_tolerates_a_nonblocking_corpse_sharing_a_living_occupants_cell()
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


func _entity_moved_event_updates_occupancy_atomically() -> void:
	var board: BoardState = _new_board(3, 2)
	board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(0, 0),
		18,
		18
	))
	var event: DomainEvent = DomainEvent.entity_moved(board.next_sequence_id(), &"hero", Vector2i(0, 0), Vector2i(2, 1), 3, 3)

	var result_value: ActionResult = board.apply_event(event)

	assert_true(result_value.succeeded, "Valid movement events should apply to board state.")
	assert_equal(board.next_sequence_id(), 3, "Movement events should advance board event sequence ids once.")
	assert_equal(board.get_entity(&"hero").position, Vector2i(2, 1), "Movement events should update stored entity position.")
	assert_equal(board.occupant_at(Vector2i(0, 0)), &"", "Movement events should clear previous blocking occupant.")
	assert_equal(board.occupant_at(Vector2i(2, 1)), &"hero", "Movement events should set target blocking occupant.")


func _invalid_entity_moved_events_do_not_mutate() -> void:
	var missing_actor_board: BoardState = _new_board(2, 2)
	var missing_actor_before: Dictionary = missing_actor_board.to_snapshot()
	var missing_actor_result: ActionResult = missing_actor_board.apply_event(
		DomainEvent.entity_moved(missing_actor_board.next_sequence_id(), &"missing", Vector2i(0, 0), Vector2i(1, 0), 1, 3)
	)

	var from_mismatch_board: BoardState = _movement_event_board()
	var from_mismatch_before: Dictionary = from_mismatch_board.to_snapshot()
	var from_mismatch_result: ActionResult = from_mismatch_board.apply_event(
		DomainEvent.entity_moved(from_mismatch_board.next_sequence_id(), &"hero", Vector2i(1, 0), Vector2i(1, 1), 1, 3)
	)

	var out_of_bounds_board: BoardState = _movement_event_board()
	var out_of_bounds_before: Dictionary = out_of_bounds_board.to_snapshot()
	var out_of_bounds_result: ActionResult = out_of_bounds_board.apply_event(
		DomainEvent.entity_moved(out_of_bounds_board.next_sequence_id(), &"hero", Vector2i(0, 0), Vector2i(3, 0), 3, 3)
	)

	var wall_board: BoardState = _movement_event_board()
	wall_board.set_cell_terrain_for_setup(Vector2i(1, 0), BoardCell.Terrain.WALL)
	var wall_before: Dictionary = wall_board.to_snapshot()
	var wall_result: ActionResult = wall_board.apply_event(
		DomainEvent.entity_moved(wall_board.next_sequence_id(), &"hero", Vector2i(0, 0), Vector2i(1, 0), 1, 3)
	)

	var occupied_board: BoardState = _movement_event_board()
	occupied_board.place_entity_for_setup(_entity(
		&"enemy_1",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(1, 0),
		10,
		10
	))
	var occupied_before: Dictionary = occupied_board.to_snapshot()
	var occupied_result: ActionResult = occupied_board.apply_event(
		DomainEvent.entity_moved(occupied_board.next_sequence_id(), &"hero", Vector2i(0, 0), Vector2i(1, 0), 1, 3)
	)

	assert_true(missing_actor_result.is_error(), "Movement events should reject missing actors.")
	assert_equal(missing_actor_result.error_code, &"invalid_movement_event", "Missing actor movement should use a stable board-event code.")
	assert_equal(missing_actor_result.metadata.get("reason"), "invalid_actor", "Missing actor movement should expose reason metadata.")
	assert_equal(missing_actor_board.to_snapshot(), missing_actor_before, "Missing actor movement must not mutate board state.")
	assert_true(from_mismatch_result.is_error(), "Movement events should reject source-cell mismatches.")
	assert_equal(from_mismatch_result.metadata.get("reason"), "from_mismatch", "Source mismatch should expose reason metadata.")
	assert_equal(from_mismatch_board.to_snapshot(), from_mismatch_before, "Source mismatch movement must not mutate board state.")
	assert_true(out_of_bounds_result.is_error(), "Movement events should reject out-of-bounds targets.")
	assert_equal(out_of_bounds_result.metadata.get("reason"), "out_of_bounds", "Out-of-bounds movement should expose reason metadata.")
	assert_equal(out_of_bounds_board.to_snapshot(), out_of_bounds_before, "Out-of-bounds movement must not mutate board state.")
	assert_true(wall_result.is_error(), "Movement events should reject blocking terrain.")
	assert_equal(wall_result.metadata.get("reason"), "blocked", "Blocking terrain movement should expose reason metadata.")
	assert_equal(wall_board.to_snapshot(), wall_before, "Blocking terrain movement must not mutate board state.")
	assert_true(occupied_result.is_error(), "Movement events should reject occupied targets.")
	assert_equal(occupied_result.metadata.get("reason"), "occupied", "Occupied movement should expose reason metadata.")
	assert_equal(occupied_board.to_snapshot(), occupied_before, "Occupied movement must not mutate board state.")


func _visibility_updated_event_updates_current_visible_and_memory_atomically() -> void:
	var board: BoardState = _new_board(3, 3)
	var place_result: ActionResult = board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(1, 1),
		18,
		18
	))
	board.get_cell(Vector2i(0, 0)).visible = true
	board.get_cell(Vector2i(0, 0)).explored = true
	board.get_cell(Vector2i(2, 2)).explored = true
	var event: DomainEvent = DomainEvent.visibility_updated(
		board.next_sequence_id(),
		&"hero",
		Vector2i(1, 1),
		4,
		[Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 1), Vector2i(2, 1)]
	)

	var result_value: ActionResult = board.apply_event(event)

	assert_true(place_result.succeeded, "Visibility event setup should place the hero.")
	assert_true(result_value.succeeded, "Valid visibility events should apply to board state.")
	assert_equal(board.next_sequence_id(), 3, "Visibility events should advance board event sequence ids once.")
	assert_false(board.get_cell(Vector2i(0, 0)).visible, "Visibility updates should clear previous current-visible flags.")
	assert_true(board.get_cell(Vector2i(0, 0)).explored, "Visibility updates should preserve old explored memory.")
	assert_true(board.get_cell(Vector2i(1, 1)).visible, "Visibility updates should mark payload cells visible.")
	assert_true(board.get_cell(Vector2i(1, 1)).explored, "Visible payload cells should also be explored.")
	assert_true(board.get_cell(Vector2i(2, 1)).visible, "Visibility updates should mark newly visible payload cells visible.")
	assert_true(board.get_cell(Vector2i(2, 1)).explored, "Newly visible payload cells should become explored.")
	assert_false(board.get_cell(Vector2i(2, 2)).visible, "Previously explored cells outside payload should remain not visible.")
	assert_true(board.get_cell(Vector2i(2, 2)).explored, "Previously explored cells outside payload should remain explored.")


func _invalid_visibility_updated_events_do_not_mutate() -> void:
	var invalid_actor_board: BoardState = _visibility_event_board()
	var invalid_actor_before: Dictionary = invalid_actor_board.to_snapshot()
	var invalid_actor_result: ActionResult = invalid_actor_board.apply_event(DomainEvent.visibility_updated(
		invalid_actor_board.next_sequence_id(),
		&"missing",
		Vector2i(1, 1),
		4,
		[Vector2i(1, 1)],
		[Vector2i(1, 1)]
	))

	var duplicate_board: BoardState = _visibility_event_board()
	var duplicate_before: Dictionary = duplicate_board.to_snapshot()
	var duplicate_result: ActionResult = duplicate_board.apply_event(DomainEvent.visibility_updated(
		duplicate_board.next_sequence_id(),
		&"hero",
		Vector2i(1, 1),
		4,
		[Vector2i(1, 1), Vector2i(1, 1)],
		[Vector2i(1, 1)]
	))

	var out_of_bounds_board: BoardState = _visibility_event_board()
	var out_of_bounds_before: Dictionary = out_of_bounds_board.to_snapshot()
	var out_of_bounds_result: ActionResult = out_of_bounds_board.apply_event(DomainEvent.visibility_updated(
		out_of_bounds_board.next_sequence_id(),
		&"hero",
		Vector2i(1, 1),
		4,
		[Vector2i(1, 1), Vector2i(3, 1)],
		[Vector2i(1, 1)]
	))

	var empty_visible_board: BoardState = _visibility_event_board()
	var empty_visible_before: Dictionary = empty_visible_board.to_snapshot()
	var empty_visible_result: ActionResult = empty_visible_board.apply_event(DomainEvent.visibility_updated(
		empty_visible_board.next_sequence_id(),
		&"hero",
		Vector2i(1, 1),
		4,
		[],
		[]
	))

	var missing_newly_board: BoardState = _visibility_event_board()
	var missing_newly_before: Dictionary = missing_newly_board.to_snapshot()
	var missing_newly_result: ActionResult = missing_newly_board.apply_event(DomainEvent.visibility_updated(
		missing_newly_board.next_sequence_id(),
		&"hero",
		Vector2i(1, 1),
		4,
		[Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 1)]
	))

	var sequence_board: BoardState = _visibility_event_board()
	var sequence_before: Dictionary = sequence_board.to_snapshot()
	var sequence_result: ActionResult = sequence_board.apply_event(DomainEvent.visibility_updated(
		99,
		&"hero",
		Vector2i(1, 1),
		4,
		[Vector2i(1, 1)],
		[Vector2i(1, 1)]
	))

	assert_true(invalid_actor_result.is_error(), "Visibility events should reject missing actors.")
	assert_equal(invalid_actor_result.error_code, &"invalid_visibility_event", "Missing actor visibility should use a stable board-event code.")
	assert_equal(invalid_actor_result.metadata.get("reason"), "invalid_actor", "Missing actor visibility should expose reason metadata.")
	assert_equal(invalid_actor_board.to_snapshot(), invalid_actor_before, "Missing actor visibility must not mutate board state.")
	assert_true(duplicate_result.is_error(), "Visibility events should reject duplicate cells.")
	assert_equal(duplicate_result.metadata.get("reason"), "duplicate_cell", "Duplicate visibility cells should expose reason metadata.")
	assert_equal(duplicate_board.to_snapshot(), duplicate_before, "Duplicate visibility cells must not mutate board state.")
	assert_true(out_of_bounds_result.is_error(), "Visibility events should reject out-of-bounds cells.")
	assert_equal(out_of_bounds_result.metadata.get("reason"), "out_of_bounds", "Out-of-bounds visibility should expose reason metadata.")
	assert_equal(out_of_bounds_board.to_snapshot(), out_of_bounds_before, "Out-of-bounds visibility must not mutate board state.")
	assert_true(empty_visible_result.is_error(), "Visibility events should reject empty visible sets.")
	assert_equal(empty_visible_result.metadata.get("reason"), "empty_visible_cells", "Empty visible sets should expose reason metadata.")
	assert_equal(empty_visible_board.to_snapshot(), empty_visible_before, "Empty visible sets must not mutate board state.")
	assert_true(missing_newly_result.is_error(), "Visibility events should reject omitted newly explored cells.")
	assert_equal(missing_newly_result.metadata.get("reason"), "newly_explored_mismatch", "Omitted newly explored cells should expose reason metadata.")
	assert_equal(missing_newly_board.to_snapshot(), missing_newly_before, "Omitted newly explored cells must not mutate board state.")
	assert_true(sequence_result.is_error(), "Visibility events should reject sequence mismatches.")
	assert_equal(sequence_result.error_code, &"event_sequence_mismatch", "Visibility sequence mismatches should use stable event sequencing.")
	assert_equal(sequence_board.to_snapshot(), sequence_before, "Sequence mismatches must not mutate board state.")


func _attack_damage_events_update_hp_and_replay_atomically() -> void:
	var board: BoardState = _attack_event_board()
	var replay_board: BoardState = BoardState.from_snapshot(board.to_snapshot())
	var first_sequence_id: int = board.next_sequence_id()
	var events: Array[DomainEvent] = [
		DomainEvent.entity_attacked(first_sequence_id, &"hero", &"enemy_1", Vector2i(2, 1), &"sword", _attack_payload()),
		DomainEvent.damage_applied(first_sequence_id + 1, &"hero", &"enemy_1", 4, 10, 6, 10, _damage_payload(4, 0, 0, false))
	]

	var result_value: ActionResult = board.apply_events(events)
	var replay_result: ActionResult = replay_board.apply_events(events)

	assert_true(result_value.succeeded, "Attack and damage events should apply as an atomic batch.")
	assert_true(replay_result.succeeded, "Copied boards should replay attack event batches.")
	assert_equal(board.get_entity(&"enemy_1").current_hp, 6, "Damage events should mutate stored target HP.")
	assert_equal(board.next_sequence_id(), first_sequence_id + 2, "Attack event sequence ids should advance contiguously.")
	assert_equal(replay_board.to_snapshot(), board.to_snapshot(), "Replayed attack events should reproduce the command-mutated board snapshot.")


func _damage_application_clamps_hp_without_outcome_events() -> void:
	var board: BoardState = _attack_event_board(3)
	var first_sequence_id: int = board.next_sequence_id()
	var events: Array[DomainEvent] = [
		DomainEvent.entity_attacked(first_sequence_id, &"hero", &"enemy_1", Vector2i(2, 1), &"sword", _attack_payload()),
		DomainEvent.damage_applied(first_sequence_id + 1, &"hero", &"enemy_1", 4, 3, 0, 10, _damage_payload(4, 0, 0, false))
	]

	var result_value: ActionResult = board.apply_events(events)

	assert_true(result_value.succeeded, "Lethal damage events should apply in this story.")
	assert_equal(board.get_entity(&"enemy_1").current_hp, 0, "Damage events should clamp target HP at zero.")
	for event: DomainEvent in result_value.events:
		assert_false(String(DomainEvent.id_for_type(event.event_type)).contains("death"), "Story 1.9 must not emit death events.")
		assert_false(String(DomainEvent.id_for_type(event.event_type)).contains("victory"), "Story 1.9 must not emit victory events.")


func _attack_status_events_are_replayable_noops() -> void:
	var board: BoardState = _attack_event_board()
	var before_entities: Array = board.to_snapshot().get("entities", [])
	var event: DomainEvent = DomainEvent.status_effect_applied(
		board.next_sequence_id(),
		&"hero",
		&"enemy_1",
		&"bleed",
		{
			"weapon_id": "axe",
			"rng_draw": {
				"stream_name": "combat",
				"draw_index": 0,
				"roll_value": 0.2,
				"threshold": 0.35,
				"effect_id": "bleed",
				"succeeded": true
			}
		}
	)

	var result_value: ActionResult = board.apply_event(event)

	assert_true(result_value.succeeded, "Status effect events should be accepted for replay before persistent status exists.")
	assert_equal(board.to_snapshot().get("entities", []), before_entities, "Status effect events should not mutate board entities in this story.")
	assert_equal(board.next_sequence_id(), 3, "Status no-op events should still advance event sequence ids.")


func _knockback_events_update_position_and_occupancy_atomically() -> void:
	var board: BoardState = _knockback_event_board()
	var event: DomainEvent = DomainEvent.entity_knocked_back(
		board.next_sequence_id(),
		&"hero",
		&"enemy_1",
		Vector2i(2, 1),
		Vector2i(3, 1),
		&"crossbow",
		{"source_cell": {"x": 0, "y": 1}}
	)

	var result_value: ActionResult = board.apply_event(event)

	assert_true(result_value.succeeded, "Valid knockback events should move the target.")
	assert_equal(board.get_entity(&"enemy_1").position, Vector2i(3, 1), "Knockback should update stored target position.")
	assert_equal(board.occupant_at(Vector2i(2, 1)), &"", "Knockback should clear previous target occupancy.")
	assert_equal(board.occupant_at(Vector2i(3, 1)), &"enemy_1", "Knockback should set destination occupancy.")


func _invalid_attack_events_do_not_mutate() -> void:
	var damage_board: BoardState = _attack_event_board()
	var damage_before: Dictionary = damage_board.to_snapshot()
	var bad_damage: DomainEvent = DomainEvent.damage_applied(
		damage_board.next_sequence_id(),
		&"hero",
		&"enemy_1",
		4,
		9,
		5,
		10,
		_damage_payload(4, 0, 0, false)
	)
	var damage_result: ActionResult = damage_board.apply_event(bad_damage)

	var knockback_board: BoardState = _knockback_event_board()
	knockback_board.set_cell_terrain_for_setup(Vector2i(3, 1), BoardCell.Terrain.WALL)
	var knockback_before: Dictionary = knockback_board.to_snapshot()
	var bad_knockback: DomainEvent = DomainEvent.entity_knocked_back(
		knockback_board.next_sequence_id(),
		&"hero",
		&"enemy_1",
		Vector2i(2, 1),
		Vector2i(3, 1),
		&"crossbow",
		{"source_cell": {"x": 0, "y": 1}}
	)
	var knockback_result: ActionResult = knockback_board.apply_event(bad_knockback)

	var stale_knockback_board: BoardState = _knockback_event_board()
	var stale_source_cell: BoardCell = stale_knockback_board.get_cell(Vector2i(2, 1))
	stale_source_cell.occupant_id = &""
	var stale_knockback_before: Dictionary = stale_knockback_board.to_snapshot()
	var stale_knockback: DomainEvent = DomainEvent.entity_knocked_back(
		stale_knockback_board.next_sequence_id(),
		&"hero",
		&"enemy_1",
		Vector2i(2, 1),
		Vector2i(3, 1),
		&"crossbow",
		{"source_cell": {"x": 0, "y": 1}}
	)
	var stale_knockback_result: ActionResult = stale_knockback_board.apply_event(stale_knockback)

	var final_damage_board: BoardState = _attack_event_board()
	var final_damage_before: Dictionary = final_damage_board.to_snapshot()
	var bad_final_damage_payload: Dictionary = _damage_payload(4, 0, 0, false, 3)
	bad_final_damage_payload["target_entity_id"] = "enemy_1"
	bad_final_damage_payload["amount"] = 4
	bad_final_damage_payload["hp_before"] = 10
	bad_final_damage_payload["hp_after"] = 6
	bad_final_damage_payload["max_hp"] = 10
	var bad_final_damage: DomainEvent = DomainEvent.new(
		DomainEvent.Type.DAMAGE_APPLIED,
		final_damage_board.next_sequence_id(),
		&"hero",
		bad_final_damage_payload
	)
	var final_damage_result: ActionResult = final_damage_board.apply_event(bad_final_damage)

	assert_true(damage_result.is_error(), "Damage events should reject mismatched HP preconditions.")
	assert_equal(damage_result.error_code, &"invalid_damage_event", "Invalid damage events should use a stable board-event code.")
	assert_equal(damage_result.metadata.get("reason"), "hp_before_mismatch", "Damage HP mismatches should expose a stable reason.")
	assert_equal(damage_board.to_snapshot(), damage_before, "Rejected damage events must not mutate board state.")
	assert_true(knockback_result.is_error(), "Knockback events should reject blocked destinations.")
	assert_equal(knockback_result.error_code, &"invalid_knockback_event", "Invalid knockback events should use a stable board-event code.")
	assert_equal(knockback_result.metadata.get("reason"), "blocked", "Blocked knockback should expose a stable reason.")
	assert_equal(knockback_board.to_snapshot(), knockback_before, "Rejected knockback events must not mutate board state.")
	assert_true(stale_knockback_result.is_error(), "Knockback events should reject stale source occupancy.")
	assert_equal(stale_knockback_result.error_code, &"invalid_knockback_event", "Stale knockback should use the stable board-event code.")
	assert_equal(stale_knockback_result.metadata.get("reason"), "from_mismatch", "Stale knockback should expose a stable source mismatch reason.")
	assert_equal(stale_knockback_board.to_snapshot(), stale_knockback_before, "Rejected stale knockback events must not mutate board state.")
	assert_true(final_damage_result.is_error(), "Damage events should reject contradictory final damage metadata.")
	assert_equal(final_damage_result.error_code, &"invalid_damage_event", "Final damage mismatch should use the stable board-event code.")
	assert_equal(final_damage_result.metadata.get("reason"), "final_damage_mismatch", "Final damage mismatches should expose a stable reason.")
	assert_equal(final_damage_board.to_snapshot(), final_damage_before, "Rejected final damage events must not mutate board state.")


func _detonation_events_reject_outcome_position_contradictions() -> void:
	var avoided_board: BoardState = _detonation_event_board(Vector2i(1, 2))
	var avoided_before: Dictionary = avoided_board.to_snapshot()
	var avoided_event: DomainEvent = DomainEvent.marked_tile_detonated(
		avoided_board.next_sequence_id(),
		&"enemy_seer",
		&"hero",
		Vector2i(1, 2),
		"ash_seer_mark:enemy_seer:2",
		&"avoided",
		_detonation_payload()
	)

	var avoided_result: ActionResult = avoided_board.apply_events([avoided_event])

	assert_true(avoided_result.is_error(), "Avoided detonation events should reject targets still on the marked cell.")
	assert_equal(avoided_result.error_code, &"invalid_detonation_event", "Contradictory detonation outcomes should use the detonation event code.")
	assert_equal(avoided_result.metadata.get("reason"), "target_still_marked", "Avoided contradiction should identify the target position problem.")
	assert_equal(avoided_board.to_snapshot(), avoided_before, "Rejected avoided detonation replay must not mutate board state.")

	var hit_board: BoardState = _detonation_event_board(Vector2i(1, 1))
	var hit_before: Dictionary = hit_board.to_snapshot()
	var hit_event: DomainEvent = DomainEvent.marked_tile_detonated(
		hit_board.next_sequence_id(),
		&"enemy_seer",
		&"hero",
		Vector2i(1, 2),
		"ash_seer_mark:enemy_seer:2",
		&"hit",
		_detonation_payload()
	)

	var hit_result: ActionResult = hit_board.apply_events([hit_event])

	assert_true(hit_result.is_error(), "Hit detonation events should reject targets no longer on the marked cell.")
	assert_equal(hit_result.error_code, &"invalid_detonation_event", "Hit contradiction should use the detonation event code.")
	assert_equal(hit_result.metadata.get("reason"), "target_cell_mismatch", "Hit contradiction should identify the target position mismatch.")
	assert_equal(hit_board.to_snapshot(), hit_before, "Rejected hit detonation replay must not mutate board state.")


func _outcome_events_advance_sequence_without_board_mutation() -> void:
	var victory_board: BoardState = BoardFixtureFactory.outcome_all_enemies_dead()
	var defeat_board: BoardState = BoardFixtureFactory.outcome_player_dead()
	var victory_before: Dictionary = victory_board.to_snapshot()
	var defeat_before: Dictionary = defeat_board.to_snapshot()
	var victory_event: DomainEvent = DomainEvent.level_victory_reached(
		victory_board.next_sequence_id(),
		1,
		0,
		["enemy_iron", "enemy_seer"],
		12,
		"All enemies were defeated."
	)
	var defeat_event: DomainEvent = DomainEvent.level_defeat_reached(
		defeat_board.next_sequence_id(),
		&"hero",
		9,
		&"damage_applied",
		&"enemy_iron",
		&"physical",
		3,
		"Hero fell to enemy_iron."
	)

	var victory_result: ActionResult = victory_board.apply_event(victory_event)
	var defeat_result: ActionResult = defeat_board.apply_event(defeat_event)
	var victory_after: Dictionary = victory_board.to_snapshot()
	var defeat_after: Dictionary = defeat_board.to_snapshot()
	victory_before["next_sequence_id"] = victory_after["next_sequence_id"]
	defeat_before["next_sequence_id"] = defeat_after["next_sequence_id"]

	assert_true(victory_result.succeeded, "Victory outcome events should replay on board state.")
	assert_true(defeat_result.succeeded, "Defeat outcome events should replay on board state.")
	assert_equal(victory_after, victory_before, "Victory events should only advance sequence ids, not mutate board truth.")
	assert_equal(defeat_after, defeat_before, "Defeat events should only advance sequence ids, not mutate board truth.")


func _invalid_outcome_events_do_not_mutate() -> void:
	var victory_board: BoardState = BoardFixtureFactory.outcome_active_combat()
	var victory_before: Dictionary = victory_board.to_snapshot()
	var victory_event: DomainEvent = DomainEvent.level_victory_reached(
		victory_board.next_sequence_id(),
		1,
		0,
		["enemy_iron", "enemy_seer"],
		12,
		"All enemies were defeated."
	)
	var defeat_board: BoardState = BoardFixtureFactory.outcome_active_combat()
	var defeat_before: Dictionary = defeat_board.to_snapshot()
	var defeat_event: DomainEvent = DomainEvent.level_defeat_reached(
		defeat_board.next_sequence_id(),
		&"hero",
		9,
		&"damage_applied",
		&"enemy_iron",
		&"physical",
		3,
		"Hero fell to enemy_iron."
	)

	var victory_result: ActionResult = victory_board.apply_event(victory_event)
	var defeat_result: ActionResult = defeat_board.apply_event(defeat_event)

	assert_true(victory_result.is_error(), "Victory events should reject boards with living enemies.")
	assert_equal(victory_result.error_code, &"invalid_outcome_event", "Invalid victory replay should use a stable outcome event code.")
	assert_equal(victory_board.to_snapshot(), victory_before, "Invalid victory events must not mutate board state.")
	assert_true(defeat_result.is_error(), "Defeat events should reject boards with living players.")
	assert_equal(defeat_result.error_code, &"invalid_outcome_event", "Invalid defeat replay should use a stable outcome event code.")
	assert_equal(defeat_board.to_snapshot(), defeat_before, "Invalid defeat events must not mutate board state.")


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
		],
		"entities": []
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


func _malformed_cell_snapshots_are_rejected_strictly() -> void:
	var missing_position: Dictionary = _snapshot_with_entities([])
	missing_position["cells"][0].erase("position")
	var non_dictionary_position: Dictionary = _snapshot_with_entities([])
	non_dictionary_position["cells"][0]["position"] = []
	var missing_position_x: Dictionary = _snapshot_with_entities([])
	missing_position_x["cells"][0]["position"].erase("x")
	var non_integral_position_y: Dictionary = _snapshot_with_entities([])
	non_integral_position_y["cells"][0]["position"]["y"] = "0"
	var missing_terrain: Dictionary = _snapshot_with_entities([])
	missing_terrain["cells"][0].erase("terrain")
	var non_integral_terrain: Dictionary = _snapshot_with_entities([])
	non_integral_terrain["cells"][0]["terrain"] = "floor"
	var non_string_occupant: Dictionary = _snapshot_with_entities([])
	non_string_occupant["cells"][0]["occupant_id"] = 12
	var non_bool_explored: Dictionary = _snapshot_with_entities([])
	non_bool_explored["cells"][0]["explored"] = "false"
	var non_bool_visible: Dictionary = _snapshot_with_entities([])
	non_bool_visible["cells"][0]["visible"] = 1

	_assert_invalid_board_snapshot(missing_position, &"invalid_cell_data", "Cell snapshots should require a position dictionary.")
	_assert_invalid_board_snapshot(non_dictionary_position, &"invalid_cell_data", "Cell snapshots should reject non-dictionary positions.")
	_assert_invalid_board_snapshot(missing_position_x, &"invalid_cell_data", "Cell snapshots should require integral x coordinates.")
	_assert_invalid_board_snapshot(non_integral_position_y, &"invalid_cell_data", "Cell snapshots should reject non-integral y coordinates.")
	_assert_invalid_board_snapshot(missing_terrain, &"invalid_cell_data", "Cell snapshots should require terrain.")
	_assert_invalid_board_snapshot(non_integral_terrain, &"invalid_cell_data", "Cell snapshots should reject non-integral terrain.")
	_assert_invalid_board_snapshot(non_string_occupant, &"invalid_cell_data", "Cell snapshots should reject non-string occupant ids.")
	_assert_invalid_board_snapshot(non_bool_explored, &"invalid_cell_data", "Cell snapshots should require boolean explored state.")
	_assert_invalid_board_snapshot(non_bool_visible, &"invalid_cell_data", "Cell snapshots should require boolean visible state.")


func _malformed_cells_container_is_rejected_without_mutation() -> void:
	var malformed_cells: Dictionary = _snapshot_with_entities([])
	malformed_cells["cells"] = {}

	_assert_invalid_board_snapshot(malformed_cells, &"invalid_board_snapshot_cells", "Board snapshots should reject a non-array cells container before typed assignment.")


func _malformed_top_level_snapshot_fields_are_rejected() -> void:
	var missing_sequence_id: Dictionary = _snapshot_with_entities([])
	missing_sequence_id.erase("next_sequence_id")
	var zero_sequence_id: Dictionary = _snapshot_with_entities([])
	zero_sequence_id["next_sequence_id"] = 0
	var negative_sequence_id: Dictionary = _snapshot_with_entities([])
	negative_sequence_id["next_sequence_id"] = -1
	var missing_entities: Dictionary = _snapshot_with_entities([])
	missing_entities.erase("entities")
	var malformed_entities: Dictionary = _snapshot_with_entities([])
	malformed_entities["entities"] = {}

	_assert_invalid_board_snapshot(missing_sequence_id, &"invalid_board_snapshot_sequence_id", "Board snapshots should reject missing sequence ids.")
	_assert_invalid_board_snapshot(zero_sequence_id, &"invalid_board_snapshot_sequence_id", "Board snapshots should reject zero sequence ids.")
	_assert_invalid_board_snapshot(negative_sequence_id, &"invalid_board_snapshot_sequence_id", "Board snapshots should reject negative sequence ids.")
	_assert_invalid_board_snapshot(missing_entities, &"invalid_board_snapshot_entities", "Board snapshots should require an entities container.")
	_assert_invalid_board_snapshot(malformed_entities, &"invalid_board_snapshot_entities", "Board snapshots should reject malformed entities containers.")


func _snapshot_occupant_consistency_is_strict() -> void:
	var missing_cell_occupant: Dictionary = _snapshot_with_entities([
		_entity_snapshot("hero", "player", "player", 0, 0, 18, 18)
	])
	var nonblocking_cell_occupant: Dictionary = _snapshot_with_entities([
		_entity_snapshot("pickup_marker", "enemy", "neutral", 0, 0, 1, 1, false)
	])
	nonblocking_cell_occupant["cells"][0]["occupant_id"] = "pickup_marker"

	var missing_result: ActionResult = BoardState.try_from_snapshot(missing_cell_occupant)
	var nonblocking_result: ActionResult = BoardState.try_from_snapshot(nonblocking_cell_occupant)

	assert_true(missing_result.is_error(), "Blocking entities must have a matching cell occupant id in imported snapshots.")
	assert_equal(missing_result.error_code, &"invalid_cell_occupant", "Missing blocking entity occupants should use a stable occupant error code.")
	assert_true(nonblocking_result.is_error(), "Non-blocking entities must not occupy cells in imported snapshots.")
	assert_equal(nonblocking_result.error_code, &"invalid_cell_occupant", "Non-blocking cell occupants should use a stable occupant error code.")


func _new_board(new_width: int, new_height: int) -> BoardState:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(new_width, new_height)
	var result_value: ActionResult = command.execute(board)
	assert_true(result_value.succeeded, "Test helper should create a valid board.")
	return board


func _movement_event_board() -> BoardState:
	var board: BoardState = _new_board(3, 2)
	var place_result: ActionResult = board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(0, 0),
		18,
		18
	))
	assert_true(place_result.succeeded, "Movement event test helper should place the hero.")
	return board


func _visibility_event_board() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	var place_result: ActionResult = board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(1, 1),
		18,
		18
	))
	assert_true(place_result.succeeded, "Visibility event test helper should place the hero.")
	return board


func _attack_event_board(enemy_hp: int = 10) -> BoardState:
	var board: BoardState = _new_board(3, 3)
	var hero_result: ActionResult = board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(1, 1),
		18,
		18
	))
	var enemy_result: ActionResult = board.place_entity_for_setup(_entity(
		&"enemy_1",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(2, 1),
		enemy_hp,
		10
	))
	assert_true(hero_result.succeeded, "Attack event test helper should place the hero.")
	assert_true(enemy_result.succeeded, "Attack event test helper should place the enemy.")
	return board


func _knockback_event_board() -> BoardState:
	var board: BoardState = _new_board(5, 3)
	var hero_result: ActionResult = board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		Vector2i(0, 1),
		18,
		18
	))
	var enemy_result: ActionResult = board.place_entity_for_setup(_entity(
		&"enemy_1",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(2, 1),
		10,
		10
	))
	assert_true(hero_result.succeeded, "Knockback test helper should place the hero.")
	assert_true(enemy_result.succeeded, "Knockback test helper should place the enemy.")
	return board


func _detonation_event_board(hero_position: Vector2i) -> BoardState:
	var board: BoardState = _new_board(6, 5)
	var hero_result: ActionResult = board.place_entity_for_setup(_entity(
		&"hero",
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		hero_position,
		18,
		18
	))
	var seer_result: ActionResult = board.place_entity_for_setup(_entity(
		&"enemy_seer",
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		Vector2i(5, 2),
		8,
		8
	))
	assert_true(hero_result.succeeded, "Detonation replay helper should place the hero.")
	assert_true(seer_result.succeeded, "Detonation replay helper should place the Ash Seer.")
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


func _attack_payload() -> Dictionary:
	return {
		"expected_base_damage": 4,
		"range": 1,
		"distance": 1,
		"line_cells": [{"x": 1, "y": 1}, {"x": 2, "y": 1}],
		"blocker_cells": [],
		"blocker_ignored": false,
		"warnings": [],
		"effects": [],
		"explanation": "sword previews 4 damage to enemy_1."
	}


func _damage_payload(
	base_damage: int,
	support_bonus_damage: int,
	armor_reduction: int,
	block_succeeded: bool,
	final_damage: int = -1
) -> Dictionary:
	var recorded_final_damage: int = final_damage
	if recorded_final_damage < 0:
		recorded_final_damage = max(1, base_damage + support_bonus_damage - armor_reduction)
	return {
		"weapon_id": "sword",
		"base_damage": base_damage,
		"support_bonus_damage": support_bonus_damage,
		"armor_reduction": armor_reduction,
		"block_succeeded": block_succeeded,
		"final_damage": recorded_final_damage,
		"damage_type": "physical",
		"rng_draws": []
	}


func _detonation_payload() -> Dictionary:
	return {
		"damage": 4,
		"damage_type": "physical",
		"explanation": "Ash Seer mark detonated."
	}


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


func _assert_invalid_board_snapshot(snapshot: Dictionary, expected_error_code: StringName, message: String) -> void:
	var source_board: BoardState = _new_board(1, 1)
	var before: Dictionary = source_board.to_snapshot()
	var result_value: ActionResult = BoardState.try_from_snapshot(snapshot)

	assert_true(result_value.is_error(), message)
	assert_equal(result_value.error_code, expected_error_code, message)
	assert_equal(source_board.to_snapshot(), before, "Rejected board imports must not mutate an existing board object.")


# Story 14.1 (AC1/AC4) — corpse-clearing: a dead BLOCKING entity releases its cell occupancy (F1) but STAYS in
# _entities (dead, at its position) for the victory payload + the corpse-decal read; blocks_movement flips false so
# the occupancy invariant stays consistent and the snapshot round-trips.
func _dead_blocking_entity_releases_its_cell_occupancy() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_kill_board()
	var enemy_cell: Vector2i = Vector2i(2, 1)
	assert_equal(board.occupant_at(enemy_cell), &"enemy_1", "Setup: the living enemy occupies its cell.")
	var damage: DomainEvent = DomainEvent.damage_applied(board.next_sequence_id(), &"hero", &"enemy_1", 3, 3, 0, 10, {})
	var apply: ActionResult = board.apply_events([damage])
	assert_true(apply.succeeded, "The lethal damage event applies.")
	assert_equal(board.occupant_at(enemy_cell), &"", "A dead blocking entity clears its cell occupant_id (the F1 corpse-clear).")
	assert_true(board.can_occupy(enemy_cell, &"hero").succeeded, "The death cell becomes occupiable (walkable) for a mover.")
	var corpse: TacticalEntityState = board.get_entity(&"enemy_1")
	assert_true(corpse != null, "The dead entity is NOT removed from the board.")
	assert_true(corpse.is_dead(), "The corpse has 0 HP.")
	assert_equal(corpse.position, enemy_cell, "The corpse stays at its death cell (for the decal + victory payload).")
	assert_false(corpse.blocks_movement, "The corpse no longer blocks movement (the _cells/_entities occupancy invariant stays consistent).")
	var round_trip: ActionResult = BoardState.try_from_snapshot(board.to_snapshot())
	assert_true(round_trip.succeeded, "A board with a released corpse round-trips through the strict snapshot validator: %s" % round_trip.error_code)


# Story 14.1 (AC2/AC4) — the hero_waited event is board-applied as a NO-OP that advances the sequence id (so a wait
# never collides sequence ids with the following enemy-phase events), and a malformed hero_waited is rejected.
func _hero_waited_event_validates_and_applies_as_noop() -> void:
	var board: BoardState = BoardFixtureFactory.edge_corner_movement()
	var sequence_before: int = board.next_sequence_id()
	var entities_before: Variant = board.to_snapshot().get("entities")
	var wait_event: DomainEvent = DomainEvent.hero_waited(board.next_sequence_id(), &"hero", &"no_legal_action")
	var apply: ActionResult = board.apply_events([wait_event])
	assert_true(apply.succeeded, "A valid hero_waited event applies.")
	assert_equal(board.next_sequence_id(), sequence_before + 1, "hero_waited advances the board sequence id (no enemy-phase collision).")
	assert_equal(board.to_snapshot().get("entities"), entities_before, "hero_waited is a no-op apply (no entity mutation).")
	var empty_actor: ActionResult = board.apply_events([DomainEvent.hero_waited(board.next_sequence_id(), &"", &"voluntary")])
	assert_true(empty_actor.is_error(), "A hero_waited with an empty actor is rejected.")
	var unknown_actor: ActionResult = board.apply_events([DomainEvent.hero_waited(board.next_sequence_id(), &"ghost", &"voluntary")])
	assert_true(unknown_actor.is_error(), "A hero_waited for an unknown actor is rejected.")


# Story 14.1 — the snapshot round-trip tolerates a NON-BLOCKING corpse sharing a cell with a living occupant (a hero
# that moved onto a vacated corpse cell), independent of entity-id storage order. A BLOCKING double-occupancy is still
# rejected (the tolerance is non-blocking-only).
func _snapshot_tolerates_a_nonblocking_corpse_sharing_a_living_occupants_cell() -> void:
	var snapshot: Dictionary = {
		"width": 3, "height": 3, "next_sequence_id": 5,
		"cells": _floor_cells_with_occupant(3, 3, Vector2i(1, 1), "hero"),
		"entities": [
			{"entity_id": "hero", "entity_type": "player", "faction": "player", "position": {"x": 1, "y": 1}, "current_hp": 18, "max_hp": 18, "blocks_movement": true, "definition_id": ""},
			{"entity_id": "zzz_corpse", "entity_type": "enemy", "faction": "enemy", "position": {"x": 1, "y": 1}, "current_hp": 0, "max_hp": 10, "blocks_movement": false, "definition_id": "iron_cultist"}
		]
	}
	var result_value: ActionResult = BoardState.try_from_snapshot(snapshot)
	assert_true(result_value.succeeded, "A non-blocking corpse may co-locate with a living occupant (the 14.1 setup tolerance): %s" % result_value.error_code)
	var board: BoardState = result_value.metadata.get("board")
	assert_equal(board.occupant_at(Vector2i(1, 1)), &"hero", "The living hero owns the shared cell (the corpse claims no occupancy).")
	assert_true(board.get_entity(&"zzz_corpse").is_dead(), "The co-located corpse is present and dead.")
	var blocking_snapshot: Dictionary = snapshot.duplicate(true)
	(blocking_snapshot.get("entities")[1] as Dictionary)["blocks_movement"] = true
	(blocking_snapshot.get("entities")[1] as Dictionary)["current_hp"] = 10
	var blocked: ActionResult = BoardState.try_from_snapshot(blocking_snapshot)
	assert_true(blocked.is_error(), "A BLOCKING entity sharing a cell is still rejected (the co-location tolerance is non-blocking-only).")


func _floor_cells_with_occupant(w: int, h: int, occ_cell: Vector2i, occ_id: String) -> Array:
	var cells: Array = []
	for y: int in range(h):
		for x: int in range(w):
			var occ: String = occ_id if Vector2i(x, y) == occ_cell else ""
			cells.append({"position": {"x": x, "y": y}, "terrain": 0, "occupant_id": occ, "explored": true, "visible": true})
	return cells
