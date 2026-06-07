extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CommandBridgeResult = preload("res://scripts/ui/command_bridge/command_bridge_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MoveCommand = preload("res://scripts/core/commands/move_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalCommandBridge = preload("res://scripts/ui/command_bridge/tactical_command_bridge.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_move_intent_builds_command_without_mutation_then_executes()
	_attack_intent_builds_command_without_mutation_then_executes()
	_inspect_intent_returns_selection_metadata_without_command_or_mutation()
	_execute_intent_handles_inspect_without_command_or_mutation()
	_invalid_intents_return_stable_disabled_results_without_mutation()
	_malformed_intent_and_invalid_context_return_stable_disabled_results()
	return result()


func _move_intent_builds_command_without_mutation_then_executes() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var streams: RngStreamSet = RngStreamSet.new(100)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [{"id": "ash_mark", "x": 2, "y": 2}])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)

	var result_value: CommandBridgeResult = TacticalCommandBridge.new().build_command(context, {
		"intent_id": "move",
		"actor_id": "hero",
		"target_cell": _cell(2, 1),
		"movement_budget": 3
	})

	assert_true(result_value.succeeded, "Valid move intent should convert.")
	assert_false(result_value.disabled, "Valid move intent should not be disabled.")
	assert_equal(result_value.error_code, &"", "Valid move conversion should not set an error.")
	assert_equal(result_value.reason, "valid", "Valid move conversion should expose a stable reason.")
	assert_equal(result_value.intent_id, &"move", "Result should preserve intent id.")
	assert_equal(result_value.command_id, &"move", "Result should identify the typed command.")
	assert_true(result_value.command is MoveCommand, "Move intent should create MoveCommand.")
	assert_equal(result_value.metadata.get("movement_cost"), 3, "Move conversion should copy validation metadata.")
	assert_false(result_value.metadata.has("path"), "Move conversion should not expose path internals before Story 2.2 preview DTOs.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Move conversion must not mutate domain state.")

	var execute_result: ActionResult = result_value.command.execute(context)

	assert_true(execute_result.succeeded, "Executing returned MoveCommand should succeed through the command path.")
	assert_equal(execute_result.events.size(), 1, "MoveCommand should emit movement event on explicit execution.")
	assert_equal(board.get_entity(&"hero").position, Vector2i(2, 1), "Explicit command execution should mutate board state.")


func _attack_intent_builds_command_without_mutation_then_executes() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(101)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)

	var result_value: CommandBridgeResult = TacticalCommandBridge.new().build_command(context, {
		"intent_id": "attack",
		"actor_id": "hero",
		"target_cell": _cell(2, 1),
		"weapon": _weapon(&"sword"),
		"attacker_support": _support(&"none"),
		"defender_support": null
	})

	assert_true(result_value.succeeded, "Valid attack intent should convert.")
	assert_false(result_value.disabled, "Valid attack intent should not be disabled.")
	assert_equal(result_value.reason, "valid", "Valid attack conversion should expose a stable reason.")
	assert_equal(result_value.command_id, &"attack", "Result should identify AttackCommand.")
	assert_true(result_value.command is AttackCommand, "Attack intent should create AttackCommand.")
	assert_equal(result_value.metadata.get("target_entity_id"), "enemy_1", "Attack conversion should copy preview target metadata.")
	assert_equal(result_value.metadata.get("expected_base_damage"), 4, "Attack conversion should copy preview damage metadata.")
	assert_false(result_value.metadata.has("line_cells"), "Attack conversion should not expose line internals before Story 2.2 preview DTOs.")
	assert_false(result_value.metadata.has("blocker_cells"), "Attack conversion should not expose blocker internals before Story 2.2 preview DTOs.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Attack conversion must not mutate domain state or consume RNG.")

	var execute_result: ActionResult = result_value.command.execute(context)

	assert_true(execute_result.succeeded, "Executing returned AttackCommand should succeed through the command path.")
	assert_equal(execute_result.events.size(), 2, "Sword attack should emit attack and damage events.")
	assert_equal(board.get_entity(&"enemy_1").current_hp, 6, "Explicit command execution should mutate target HP.")


func _inspect_intent_returns_selection_metadata_without_command_or_mutation() -> void:
	var board: BoardState = _inspect_board()
	var streams: RngStreamSet = RngStreamSet.new(102)
	var turn_state: TacticalTurnState = TacticalTurnState.new(4, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [{"id": "telegraph", "target": _cell(3, 2)}])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)

	var result_value: CommandBridgeResult = TacticalCommandBridge.new().build_command(context, {
		"intent_id": "inspect",
		"target_cell": _cell(3, 2)
	})
	var dictionary: Dictionary = result_value.to_dictionary()
	(dictionary.get("metadata", {}) as Dictionary)["cell"]["position"]["x"] = 99

	assert_true(result_value.succeeded, "Inspect intent should succeed for in-bounds cells.")
	assert_false(result_value.disabled, "Inspect intent should not be disabled for valid cells.")
	assert_equal(result_value.reason, "inspect", "Inspect intent should expose inspect reason.")
	assert_equal(result_value.command_id, &"", "Inspect intent should not identify a gameplay command.")
	assert_equal(result_value.command, null, "Inspect intent should not return executable gameplay command.")
	assert_equal(result_value.metadata.get("cell", {}).get("visibility_state"), "visible", "Inspect metadata should include copied visible cell facts.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Inspect intent must not mutate tactical snapshot data.")
	assert_equal(result_value.metadata.get("cell", {}).get("position"), _cell(3, 2), "Mutating result dictionaries should not mutate result metadata.")


func _execute_intent_handles_inspect_without_command_or_mutation() -> void:
	var board: BoardState = _inspect_board()
	var streams: RngStreamSet = RngStreamSet.new(104)
	var turn_state: TacticalTurnState = TacticalTurnState.new(4, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [{"id": "telegraph", "target": _cell(3, 2)}])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)

	var result_value: ActionResult = TacticalCommandBridge.new().execute_intent(context, {
		"intent_id": "inspect",
		"target_cell": _cell(3, 2)
	})

	assert_true(result_value.succeeded, "Executing inspect intent should return metadata-only success.")
	assert_false(result_value.has_events(), "Inspect execution should not emit gameplay events.")
	assert_equal(result_value.metadata.get("reason"), "inspect", "Inspect execution should preserve inspect reason.")
	assert_equal(result_value.metadata.get("intent_id"), "inspect", "Inspect execution should identify the intent.")
	assert_equal(((result_value.metadata.get("metadata", {}) as Dictionary).get("target_cell", {}) as Dictionary), _cell(3, 2), "Inspect execution should include copied inspect metadata.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Inspect execution must not mutate tactical snapshot data.")


func _invalid_intents_return_stable_disabled_results_without_mutation() -> void:
	_assert_invalid_bridge_result(
		"unsupported intents should be disabled",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "dance",
			"target_cell": _cell(1, 0)
		},
		&"unsupported_intent",
		"unsupported_intent"
	)
	_assert_invalid_bridge_result(
		"malformed target payloads should be disabled",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "move",
			"actor_id": "hero",
			"target_cell": "2,1"
		},
		&"invalid_ui_intent",
		"malformed_target_cell"
	)
	_assert_invalid_bridge_result(
		"missing actors should be disabled before command creation",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "move",
			"target_cell": _cell(1, 0)
		},
		&"invalid_ui_intent",
		"missing_actor"
	)
	_assert_invalid_bridge_result(
		"missing target cells should be disabled before command creation",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "move",
			"actor_id": "hero"
		},
		&"invalid_ui_intent",
		"missing_target_cell"
	)
	_assert_invalid_bridge_result(
		"invalid actors should be unavailable without mutation",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "move",
			"actor_id": "missing_actor",
			"target_cell": _cell(1, 0)
		},
		&"action_unavailable",
		"invalid_actor"
	)
	_assert_invalid_bridge_result(
		"occupied move targets should be unavailable without mutation",
		_visible_board(BoardFixtureFactory.occupied_cell()),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "move",
			"actor_id": "hero",
			"target_cell": _cell(1, 1)
		},
		&"action_unavailable",
		"occupied"
	)
	_assert_invalid_bridge_result(
		"blocked move targets should be unavailable without mutation",
		_visible_board(BoardFixtureFactory.blocked_cell()),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "move",
			"actor_id": "hero",
			"target_cell": _cell(1, 1)
		},
		&"action_unavailable",
		"blocked"
	)
	_assert_invalid_bridge_result(
		"wrong turn phases should be unavailable without mutation",
		_visible_board(BoardFixtureFactory.edge_corner_movement()),
		TacticalTurnState.Phase.ENEMY_PLANNING,
		{
			"intent_id": "move",
			"actor_id": "hero",
			"target_cell": _cell(1, 0)
		},
		&"action_unavailable",
		"wrong_phase"
	)
	_assert_invalid_bridge_result(
		"invalid attack weapons should be unavailable without mutation",
		BoardFixtureFactory.attack_command_survive_board(),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "attack",
			"actor_id": "hero",
			"target_cell": _cell(2, 1),
			"weapon": WeaponDefinition.new()
		},
		&"action_unavailable",
		"invalid_weapon"
	)
	_assert_invalid_bridge_result(
		"invalid attack support should be unavailable without mutation",
		BoardFixtureFactory.attack_command_survive_board(),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "attack",
			"actor_id": "hero",
			"target_cell": _cell(2, 1),
			"weapon": _weapon(&"sword"),
			"attacker_support": "not_support"
		},
		&"action_unavailable",
		"invalid_support"
	)
	_assert_invalid_bridge_result(
		"dead attack actors should be unavailable without mutation",
		BoardFixtureFactory.attack_preview_dead_actor(),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "attack",
			"actor_id": "hero",
			"target_cell": _cell(2, 1),
			"weapon": _weapon(&"sword")
		},
		&"action_unavailable",
		"dead_actor"
	)
	_assert_invalid_bridge_result(
		"hidden attack targets should be unavailable without leaking command execution",
		BoardFixtureFactory.attack_preview_hidden_enemy(),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "attack",
			"actor_id": "hero",
			"target_cell": _cell(2, 1),
			"weapon": _weapon(&"sword")
		},
		&"action_unavailable",
		"not_visible"
	)
	_assert_invalid_bridge_result(
		"out-of-range attack targets should be unavailable without mutation",
		BoardFixtureFactory.attack_preview_open_lane(),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "attack",
			"actor_id": "hero",
			"target_cell": _cell(3, 1),
			"weapon": _weapon(&"sword")
		},
		&"action_unavailable",
		"out_of_range"
	)
	_assert_invalid_bridge_result(
		"blocked-line attack targets should be unavailable without mutation",
		BoardFixtureFactory.attack_preview_blocked_lane(),
		TacticalTurnState.Phase.PLAYER_PLANNING,
		{
			"intent_id": "attack",
			"actor_id": "hero",
			"target_cell": _cell(4, 1),
			"weapon": _weapon(&"bow")
		},
		&"action_unavailable",
		"blocked_line"
	)


func _malformed_intent_and_invalid_context_return_stable_disabled_results() -> void:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var streams: RngStreamSet = RngStreamSet.new(105)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)

	var malformed_result: CommandBridgeResult = TacticalCommandBridge.new().build_command(context, "move:hero")

	assert_false(malformed_result.succeeded, "Malformed intent payloads should be disabled.")
	assert_true(malformed_result.disabled, "Malformed intent payloads should be disabled.")
	assert_equal(malformed_result.error_code, &"invalid_ui_intent", "Malformed intent payloads should use stable error code.")
	assert_equal(malformed_result.reason, "malformed_intent", "Malformed intent payloads should use stable reason.")
	assert_equal(malformed_result.command, null, "Malformed intent payloads should not return commands.")

	var invalid_context: TacticalActionContext = TacticalActionContext.new(board, null, null, [])
	var context_result: CommandBridgeResult = TacticalCommandBridge.new().build_command(invalid_context, {
		"intent_id": "inspect",
		"target_cell": _cell(1, 0)
	})

	assert_false(context_result.succeeded, "Partial contexts should be disabled.")
	assert_true(context_result.disabled, "Partial contexts should be disabled.")
	assert_equal(context_result.error_code, &"invalid_command_context", "Partial contexts should use stable error code.")
	assert_equal(context_result.reason, "invalid_context", "Partial contexts should use stable reason.")
	assert_equal(context_result.command, null, "Partial contexts should not return commands.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Malformed intents and invalid contexts must not mutate tactical snapshot data.")


func _assert_invalid_bridge_result(
	message: String,
	board: BoardState,
	phase: int,
	intent: Dictionary,
	expected_error_code: StringName,
	expected_reason: String
) -> void:
	var streams: RngStreamSet = RngStreamSet.new(103)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, phase, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [{"id": "pending"}])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)

	var result_value: CommandBridgeResult = TacticalCommandBridge.new().build_command(context, intent)

	assert_false(result_value.succeeded, message)
	assert_true(result_value.disabled, message)
	assert_equal(result_value.error_code, expected_error_code, message)
	assert_equal(result_value.reason, expected_reason, message)
	assert_equal(result_value.command_id, &"", message)
	assert_equal(result_value.command, null, message)
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "%s should not mutate tactical snapshot data." % message)


func _inspect_board() -> BoardState:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_visible_board(board)
	return board


func _visible_board(board: BoardState) -> BoardState:
	for cell: BoardCell in board.cells():
		cell.visible = true
		cell.explored = true
	return board


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _support(support_id: StringName) -> Variant:
	return SupportRepository.create_baseline_repository().get_support(support_id)


func _cell(x: int, y: int) -> Dictionary:
	return {
		"x": x,
		"y": y
	}


func _tactical_snapshot_dictionary(
	board: BoardState,
	streams: RngStreamSet,
	turn_state: TacticalTurnState,
	pending_telegraphs: Array[Dictionary],
	event_log: Array[DomainEvent]
) -> Dictionary:
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams, turn_state.to_dictionary(), pending_telegraphs, event_log)
	assert_true(result_value.succeeded, "Test helper should export a tactical snapshot.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()
