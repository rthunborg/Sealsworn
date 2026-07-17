extends "res://tests/unit/test_case.gd"

# Story 14.1 (AC2/AC4) — WaitCommand: the F1 turn-advance backstop. Valid + wrong-phase / not-active-actor /
# dead-actor / invalid-context rejects (fail-closed, zero mutation), the append-only hero_waited event, the
# advances_turn metadata, and the ZERO-RNG guarantee.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WaitCommand = preload("res://scripts/core/commands/wait_command.gd")

func run() -> Dictionary:
	_valid_wait_emits_hero_waited_advances_turn_and_draws_zero_rng()
	_valid_wait_event_board_applies_and_advances_sequence()
	_wrong_phase_is_rejected_with_zero_mutation()
	_not_active_actor_is_rejected_with_zero_mutation()
	_dead_actor_is_rejected_with_zero_mutation()
	_invalid_context_is_rejected()
	return result()


func _valid_wait_emits_hero_waited_advances_turn_and_draws_zero_rng() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var streams: RngStreamSet = RngStreamSet.new(1337)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var before_rng: Dictionary = streams.to_snapshot()
	var hero_position_before: Vector2i = board.get_entity(&"hero").position
	var hp_before: int = board.get_entity(&"hero").current_hp

	var command: WaitCommand = WaitCommand.new(&"hero")
	var result_value: ActionResult = command.execute(context)

	assert_true(result_value.succeeded, "A valid hero wait should succeed.")
	assert_equal(result_value.events.size(), 1, "WaitCommand should emit exactly one event.")
	var event: DomainEvent = result_value.events[0]
	assert_equal(event.event_type, DomainEvent.Type.HERO_WAITED, "WaitCommand should emit HERO_WAITED.")
	assert_equal(event.actor_id, &"hero", "The wait event should identify the waiting hero.")
	assert_equal(String(event.payload.get("reason")), "voluntary", "The default wait reason is voluntary.")
	assert_equal(result_value.metadata.get("advances_turn"), true, "A committed wait must advance the turn (the enemy phase runs).")
	assert_equal(streams.to_snapshot(), before_rng, "WaitCommand must draw ZERO RNG.")
	assert_equal(board.get_entity(&"hero").position, hero_position_before, "A wait must not move the hero.")
	assert_equal(board.get_entity(&"hero").current_hp, hp_before, "A wait must not change hero HP.")


func _valid_wait_event_board_applies_and_advances_sequence() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var streams: RngStreamSet = RngStreamSet.new(7)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var sequence_before: int = board.next_sequence_id()

	var command: WaitCommand = WaitCommand.new(&"hero", WaitCommand.REASON_NO_LEGAL_ACTION)
	var result_value: ActionResult = command.execute(context)

	assert_true(result_value.succeeded, "A boxed-in hero wait should succeed.")
	assert_equal(String(result_value.events[0].payload.get("reason")), "no_legal_action", "The no_legal_action reason should carry through.")
	assert_equal(board.next_sequence_id(), sequence_before + 1, "A board-applied wait advances the board sequence id (no collision with the enemy phase).")

	# The wait event replays onto a fresh board snapshot (round-trip proof — a valid append-only event).
	var replay_board: BoardState = BoardState.from_snapshot(_visible_board(BoardFixtureFactory.edge_corner_movement()).to_snapshot())
	var replay_result: ActionResult = replay_board.apply_events(result_value.events)
	assert_true(replay_result.succeeded, "The hero_waited event should replay onto a matching board.")


func _wrong_phase_is_rejected_with_zero_mutation() -> void:
	_assert_invalid_wait(
		"a wait during the enemy phase should be rejected",
		TacticalTurnState.new(1, TacticalTurnState.Phase.ENEMY_PLANNING, &"hero"),
		&"hero",
		&"wrong_phase"
	)


func _not_active_actor_is_rejected_with_zero_mutation() -> void:
	_assert_invalid_wait(
		"a wait when another actor is active should be rejected",
		TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"enemy_1"),
		&"hero",
		&"wrong_phase"
	)


func _dead_actor_is_rejected_with_zero_mutation() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.attack_preview_dead_actor())
	var streams: RngStreamSet = RngStreamSet.new(42)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var snapshot_before: Dictionary = board.to_snapshot()

	var command: WaitCommand = WaitCommand.new(&"hero")
	var result_value: ActionResult = command.execute(context)

	assert_true(result_value.is_error(), "A dead hero cannot wait.")
	assert_equal(result_value.error_code, &"invalid_wait", "A rejected wait uses the stable invalid_wait code.")
	assert_equal(result_value.metadata.get("reason"), "dead_actor", "A dead actor wait exposes the dead_actor reason.")
	assert_false(result_value.has_events(), "A rejected wait emits no events.")
	assert_equal(board.to_snapshot(), snapshot_before, "A rejected wait must not mutate the board.")


func _invalid_context_is_rejected() -> void:
	var command: WaitCommand = WaitCommand.new(&"hero")
	var result_value: ActionResult = command.execute(BoardFixtureFactory.edge_corner_movement())

	assert_true(result_value.is_error(), "WaitCommand should reject a non-context state.")
	assert_equal(result_value.error_code, &"invalid_wait", "Invalid context should use the wait command error.")
	assert_equal(result_value.metadata.get("reason"), "invalid_context", "Invalid context should expose a machine-readable reason.")
	assert_false(result_value.has_events(), "Invalid wait should not emit events.")


func _assert_invalid_wait(
	message: String,
	turn_state: TacticalTurnState,
	actor_id: StringName,
	expected_reason: StringName
) -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var streams: RngStreamSet = RngStreamSet.new(42)
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var snapshot_before: Dictionary = board.to_snapshot()
	var rng_before: Dictionary = streams.to_snapshot()

	var command: WaitCommand = WaitCommand.new(actor_id)
	var result_value: ActionResult = command.execute(context)

	assert_true(result_value.is_error(), message)
	assert_equal(result_value.error_code, &"invalid_wait", message)
	assert_equal(result_value.metadata.get("reason"), String(expected_reason), message)
	assert_false(result_value.has_events(), "%s should emit no events." % message)
	assert_equal(board.to_snapshot(), snapshot_before, "%s should not mutate the board." % message)
	assert_equal(streams.to_snapshot(), rng_before, "%s should draw zero RNG." % message)


func _visible_board(board: BoardState) -> BoardState:
	for cell: BoardCell in board.cells():
		cell.visible = true
		cell.explored = true
	return board
