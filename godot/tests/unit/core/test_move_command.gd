extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MoveCommand = preload("res://scripts/core/commands/move_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

func run() -> Dictionary:
	_successful_player_move_emits_event_and_advances_turn()
	_successful_move_events_replay_to_matching_board_snapshot()
	_invalid_movement_cases_do_not_mutate()
	_invalid_context_type_returns_invalid_movement()
	return result()


func _successful_player_move_emits_event_and_advances_turn() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var streams: RngStreamSet = RngStreamSet.new(1337)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var command: MoveCommand = MoveCommand.new(&"hero", Vector2i(2, 1))
	var before_rng: Dictionary = streams.to_snapshot()

	var result_value: ActionResult = command.execute(context)
	var event: DomainEvent = result_value.events[0]
	var payload: Dictionary = event.payload

	assert_true(result_value.succeeded, "Reachable visible movement should succeed.")
	assert_equal(result_value.events.size(), 1, "MoveCommand should emit one movement event.")
	assert_equal(event.event_type, DomainEvent.Type.ENTITY_MOVED, "MoveCommand should emit ENTITY_MOVED.")
	assert_equal(event.actor_id, &"hero", "Movement event should identify the moving actor.")
	assert_equal(payload.get("from"), {"x": 0, "y": 0}, "Movement event should serialize source cell.")
	assert_equal(payload.get("to"), {"x": 2, "y": 1}, "Movement event should serialize target cell.")
	assert_equal(payload.get("movement_cost"), 3, "Movement event should record path cost.")
	assert_equal(payload.get("movement_budget"), 3, "Movement event should record movement budget.")
	assert_equal(board.get_entity(&"hero").position, Vector2i(2, 1), "Successful movement should update actor position.")
	assert_equal(board.occupant_at(Vector2i(0, 0)), &"", "Successful movement should clear the previous blocking occupant.")
	assert_equal(board.occupant_at(Vector2i(2, 1)), &"hero", "Successful movement should set the target blocking occupant.")
	assert_equal(streams.to_snapshot(), before_rng, "Movement must not advance RNG streams.")
	assert_equal(result_value.metadata.get("advances_turn"), true, "Successful movement should tell future turn flow to advance.")
	assert_equal(result_value.metadata.get("movement_cost"), 3, "Result metadata should expose movement cost.")
	assert_equal(result_value.metadata.get("movement_budget"), 3, "Result metadata should expose movement budget.")


func _successful_move_events_replay_to_matching_board_snapshot() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var replay_board: BoardState = BoardState.from_snapshot(board.to_snapshot())
	var streams: RngStreamSet = RngStreamSet.new(2026)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var command: MoveCommand = MoveCommand.new(&"hero", Vector2i(0, 2))

	var result_value: ActionResult = command.execute(context)
	var replay_result: ActionResult = replay_board.apply_events(result_value.events)

	assert_true(result_value.succeeded, "Valid movement should succeed before replay.")
	assert_true(replay_result.succeeded, "BoardState should replay movement events.")
	assert_equal(replay_board.to_snapshot(), board.to_snapshot(), "Replayed movement event should reproduce the command-mutated board snapshot.")


func _invalid_movement_cases_do_not_mutate() -> void:
	_assert_invalid_move(
		"wall targets should be rejected",
		_visible_board(BoardFixtureFactory.blocked_cell()),
		&"hero",
		Vector2i(1, 1),
		&"blocked"
	)
	_assert_invalid_move(
		"occupied targets should be rejected",
		_visible_board(BoardFixtureFactory.occupied_cell()),
		&"hero",
		Vector2i(1, 1),
		&"occupied"
	)
	_assert_invalid_move(
		"out-of-bounds targets should be rejected",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		&"hero",
		Vector2i(3, 0),
		&"out_of_bounds"
	)
	_assert_invalid_move(
		"targets beyond budget should be rejected",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		&"hero",
		Vector2i(2, 2),
		&"beyond_budget"
	)
	_assert_invalid_move(
		"invalid actors should be rejected",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		&"missing_actor",
		Vector2i(1, 0),
		&"invalid_actor"
	)
	_assert_invalid_move_with_phase(
		"wrong turn phases should be rejected",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		TacticalTurnState.Phase.ENEMY_PLANNING,
		&"hero",
		Vector2i(1, 0),
		&"wrong_phase"
	)
	_assert_invalid_move(
		"unseen targets should be rejected",
		BoardFixtureFactory.edge_corner_movement(),
		&"hero",
		Vector2i(1, 0),
		&"not_visible"
	)
	_assert_invalid_move(
		"disconnected targets should be rejected",
		_visible_board(BoardFixtureFactory.disconnected_cells()),
		&"hero",
		Vector2i(2, 0),
		&"unreachable"
	)
	_assert_invalid_move(
		"same-cell movement should be rejected",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		&"hero",
		Vector2i(0, 0),
		&"same_cell"
	)


func _invalid_context_type_returns_invalid_movement() -> void:
	var command: MoveCommand = MoveCommand.new(&"hero", Vector2i(1, 0))
	var result_value: ActionResult = command.execute(BoardFixtureFactory.edge_corner_movement())

	assert_true(result_value.is_error(), "MoveCommand should reject non-context state.")
	assert_equal(result_value.error_code, &"invalid_movement", "Invalid context should use movement command error.")
	assert_equal(result_value.metadata.get("reason"), "invalid_context", "Invalid context should expose a machine-readable reason.")
	assert_false(result_value.has_events(), "Invalid movement should not emit events.")


func _assert_invalid_move(
	message: String,
	board: BoardState,
	actor_id: StringName,
	target_cell: Vector2i,
	expected_reason: StringName
) -> void:
	_assert_invalid_move_with_phase(message, board, TacticalTurnState.Phase.PLAYER_PLANNING, actor_id, target_cell, expected_reason)


func _assert_invalid_move_with_phase(
	message: String,
	board: BoardState,
	phase: int,
	actor_id: StringName,
	target_cell: Vector2i,
	expected_reason: StringName
) -> void:
	var streams: RngStreamSet = RngStreamSet.new(42)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, phase, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var event_log: Array[DomainEvent] = []
	var snapshot_before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, event_log)
	var command: MoveCommand = MoveCommand.new(actor_id, target_cell)

	var result_value: ActionResult = command.execute(context)

	assert_true(result_value.is_error(), message)
	assert_equal(result_value.error_code, &"invalid_movement", message)
	assert_equal(result_value.metadata.get("reason"), String(expected_reason), message)
	assert_false(result_value.has_events(), message)
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, event_log), snapshot_before, "%s should not mutate tactical snapshot data." % message)


func _tactical_snapshot_dictionary(
	board: BoardState,
	streams: RngStreamSet,
	turn_state: TacticalTurnState,
	event_log: Array[DomainEvent]
) -> Dictionary:
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams, turn_state.to_dictionary(), [], event_log)
	assert_true(result_value.succeeded, "Test helper should export a top-level tactical snapshot.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()


func _visible_board(board: BoardState) -> BoardState:
	for cell: BoardCell in board.cells():
		cell.visible = true
		cell.explored = true
	return board
