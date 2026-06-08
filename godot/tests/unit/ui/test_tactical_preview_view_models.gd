extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const AttackPreviewContractMatrix = preload("res://tests/fixtures/tactical/attack_preview_contract_matrix.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CommandBridgeResult = preload("res://scripts/ui/command_bridge/command_bridge_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MoveCommand = preload("res://scripts/core/commands/move_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackPreview = preload("res://scripts/ui/view_models/tactical_attack_preview.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalCommandBridge = preload("res://scripts/ui/command_bridge/tactical_command_bridge.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalMovementPreview = preload("res://scripts/ui/view_models/tactical_movement_preview.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_movement_preview_contract_cases_do_not_mutate_domain()
	_attack_preview_contract_matrix_does_not_mutate_domain()
	_preview_dictionaries_are_deep_copied_and_reference_free()
	_board_view_model_preserves_preview_contracts_and_commit_availability()
	_command_bridge_still_strips_path_and_line_internals()
	return result()


func _movement_preview_contract_cases_do_not_mutate_domain() -> void:
	var cases: Array[Dictionary] = [
		{
			"id": "valid_reachable_tile",
			"board": _visible_board(BoardFixtureFactory.edge_corner_movement()),
			"target": Vector2i(2, 1),
			"budget": 3,
			"reason": "valid",
			"available": true,
			"path": [_cell(0, 0), _cell(1, 0), _cell(2, 0), _cell(2, 1)],
			"movement_cost": 3
		},
		{
			"id": "same_cell",
			"board": _visible_board(BoardFixtureFactory.edge_corner_movement()),
			"target": Vector2i(0, 0),
			"budget": 3,
			"reason": "same_cell",
			"available": false
		},
		{
			"id": "out_of_bounds",
			"board": _visible_board(BoardFixtureFactory.edge_corner_movement()),
			"target": Vector2i(3, 0),
			"budget": 3,
			"reason": "out_of_bounds",
			"available": false
		},
		{
			"id": "hidden_not_visible",
			"board": _hidden_movement_board(),
			"target": Vector2i(1, 0),
			"budget": 3,
			"reason": "not_visible",
			"available": false
		},
		{
			"id": "wall_blocked",
			"board": _visible_board(BoardFixtureFactory.blocked_cell()),
			"target": Vector2i(1, 1),
			"budget": 3,
			"reason": "blocked",
			"available": false
		},
		{
			"id": "occupied",
			"board": _visible_board(BoardFixtureFactory.occupied_cell()),
			"target": Vector2i(1, 1),
			"budget": 3,
			"reason": "occupied",
			"available": false
		},
		{
			"id": "unreachable",
			"board": _visible_board(BoardFixtureFactory.disconnected_cells()),
			"target": Vector2i(2, 0),
			"budget": 3,
			"reason": "unreachable",
			"available": false
		},
		{
			"id": "beyond_budget",
			"board": _visible_board(BoardFixtureFactory.edge_corner_movement()),
			"target": Vector2i(2, 1),
			"budget": 2,
			"reason": "beyond_budget",
			"available": false,
			"movement_cost": 3
		}
	]

	for case_data: Dictionary in cases:
		var board: BoardState = case_data.get("board") as BoardState
		var target_cell: Vector2i = case_data.get("target")
		var movement_budget: int = int(case_data.get("budget", 3))
		var expected_available: bool = bool(case_data.get("available", false))
		var expected_reason: String = String(case_data.get("reason", ""))
		var streams: RngStreamSet = RngStreamSet.new(220201)
		var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
		var pending_telegraphs: Array[Dictionary] = [{"id": "ash_mark", "target": _cell(2, 2)}]
		var event_log: Array[DomainEvent] = []
		var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log)

		var preview_model: TacticalMovementPreview = TacticalMovementPreview.from_query(board, &"hero", target_cell, movement_budget)
		var preview: Dictionary = preview_model.to_dictionary()
		var metadata: Dictionary = preview.get("metadata", {})

		assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log), before, "Movement preview %s must not mutate board, turn, telegraphs, RNG, or event log." % String(case_data.get("id", "")))
		assert_equal(_sorted_keys(preview), [
			"actor_id",
			"available",
			"commit_available",
			"commit_reason",
			"cue_ids",
			"kind",
			"metadata",
			"reason",
			"target_cell",
			"target_valid"
		], "Movement preview %s should expose stable top-level keys." % String(case_data.get("id", "")))
		assert_equal(preview.get("kind"), "move", "Movement preview should identify its kind.")
		assert_equal(preview.get("actor_id"), "hero", "Movement preview should expose copied actor id.")
		assert_equal(preview.get("target_cell"), _cell(target_cell.x, target_cell.y), "Movement preview should expose copied target cell.")
		assert_equal(preview.get("available"), expected_available, "Movement preview availability should match query legality.")
		assert_equal(preview.get("target_valid"), expected_available, "Movement preview target validity should match query legality.")
		assert_equal(preview.get("commit_available"), expected_available, "Movement preview commit availability should match query legality.")
		assert_equal(preview.get("reason"), expected_reason, "Movement preview reason should preserve query reason.")
		assert_equal(preview.get("commit_reason"), expected_reason, "Movement preview commit reason should preserve query reason.")
		assert_equal(metadata.get("movement_budget"), movement_budget, "Movement preview should expose validation budget.")
		assert_equal(metadata.get("blocked_reason"), "" if expected_available else expected_reason, "Movement preview should expose invalid movement reason as metadata.")
		assert_equal(metadata.get("movement_cost"), int(case_data.get("movement_cost", 0)), "Movement preview should expose deterministic movement cost when available.")
		if expected_available:
			assert_equal(metadata.get("path"), case_data.get("path", []), "Valid movement preview should expose copied path.")
			_assert_has_all_cues(preview, ["move_preview_valid", "commit_available"], "Valid movement preview cues should be stable.")
		else:
			assert_equal(metadata.get("path"), [], "Invalid movement previews must not invent paths.")
			_assert_has_all_cues(preview, ["move_preview_invalid", "commit_unavailable"], "Invalid movement preview cues should be stable.")
		_assert_no_forbidden_references(preview, "Movement preview should not expose raw domain, command, resource, or scene references.")


func _attack_preview_contract_matrix_does_not_mutate_domain() -> void:
	for case_data: Dictionary in AttackPreviewContractMatrix.baseline_cases():
		var board: BoardState = _attack_board_from_fixture(String(case_data.get("fixture", "")))
		var target_cell: Vector2i = case_data.get("target_cell")
		var weapon: WeaponDefinition = _weapon(case_data.get("weapon_id"))
		var expected_reason: String = String(case_data.get("expected_reason", ""))
		var expected_available: bool = expected_reason == "valid"
		var streams: RngStreamSet = RngStreamSet.new(220202)
		var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
		var pending_telegraphs: Array[Dictionary] = [{"id": "ash_mark", "target": _cell(2, 2)}]
		var event_log: Array[DomainEvent] = []
		var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log)

		var preview_model: TacticalAttackPreview = TacticalAttackPreview.from_query(board, &"hero", target_cell, weapon)
		var preview: Dictionary = preview_model.to_dictionary()
		var metadata: Dictionary = preview.get("metadata", {})

		assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, pending_telegraphs, event_log), before, "Attack preview %s must not mutate board, HP, turn, telegraphs, RNG, or event log." % String(case_data.get("id", "")))
		assert_equal(_sorted_keys(preview), [
			"actor_id",
			"available",
			"commit_available",
			"commit_reason",
			"cue_ids",
			"kind",
			"metadata",
			"reason",
			"target_cell",
			"target_entity_id",
			"target_valid"
		], "Attack preview %s should expose stable top-level keys." % String(case_data.get("id", "")))
		assert_equal(preview.get("kind"), "attack", "Attack preview should identify its kind.")
		assert_equal(preview.get("actor_id"), "hero", "Attack preview should expose copied actor id.")
		assert_equal(preview.get("target_cell"), _cell(target_cell.x, target_cell.y), "Attack preview should expose copied target cell.")
		assert_equal(preview.get("available"), expected_available, "Attack preview availability should match query legality.")
		assert_equal(preview.get("target_valid"), expected_available, "Attack preview target validity should match query legality.")
		assert_equal(preview.get("commit_available"), expected_available, "Attack preview commit availability should match query legality.")
		assert_equal(preview.get("reason"), expected_reason, "Attack preview reason should preserve query reason.")
		assert_equal(preview.get("commit_reason"), expected_reason, "Attack preview commit reason should preserve query reason.")
		assert_equal(metadata.get("weapon_id"), String(weapon.weapon_id), "Attack preview should expose weapon id.")
		assert_equal(metadata.get("weapon_reach"), weapon.attack_range, "Attack preview should expose weapon reach.")
		assert_equal(metadata.get("targeting_shape"), String(weapon.targeting_shape), "Attack preview should expose targeting shape.")
		assert_equal(metadata.get("expected_base_damage"), int(case_data.get("expected_base_damage", -1)), "Attack preview should expose deterministic base damage only.")
		assert_equal(metadata.get("expected_damage"), int(case_data.get("expected_base_damage", -1)), "Attack preview should not include execution-only damage outcomes.")
		assert_equal(metadata.get("blocker_ignored"), bool(case_data.get("expected_blocker_ignored", false)), "Attack preview should preserve blocker ignored flag.")
		assert_true(metadata.has("line_cells"), "Attack preview metadata should always include line_cells.")
		assert_true(metadata.has("blocker_cells"), "Attack preview metadata should always include blocker_cells.")
		assert_true(metadata.has("warnings"), "Attack preview metadata should always include warnings.")
		assert_true(metadata.has("effects"), "Attack preview metadata should always include effects.")
		assert_true(metadata.has("explanation"), "Attack preview metadata should always include explanation text.")
		_assert_warning_ids(metadata.get("warnings", []), case_data.get("expected_warning_ids", []), String(case_data.get("id", "")))
		_assert_effect_ids(metadata.get("effects", []), case_data.get("expected_effect_ids", []), String(case_data.get("id", "")))
		if expected_available:
			_assert_has_all_cues(preview, ["attack_preview_valid", "commit_available"], "Valid attack preview cues should be stable.")
		else:
			_assert_has_all_cues(preview, ["attack_preview_invalid", "commit_unavailable"], "Invalid attack preview cues should be stable.")
		if expected_reason == "blocked_line":
			assert_equal(metadata.get("blocker_state"), "blocked", "Blocked line previews should expose stable blocker state.")
			_assert_has_all_cues(preview, ["attack_preview_blocked_line"], "Blocked line previews should expose cue id.")
		elif bool(case_data.get("expected_blocker_ignored", false)):
			assert_equal(metadata.get("blocker_state"), "ignored", "Wand blocker override should expose ignored blocker state.")
			_assert_has_all_cues(preview, ["attack_preview_blocker_ignored"], "Ignored blocker previews should expose cue id.")
		elif expected_available:
			assert_equal(metadata.get("blocker_state"), "clear", "Clear legal attack previews should expose clear blocker state.")
		_assert_no_forbidden_references(preview, "Attack preview should not expose raw domain, command, resource, or scene references.")


func _preview_dictionaries_are_deep_copied_and_reference_free() -> void:
	var movement_board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var movement_preview: TacticalMovementPreview = TacticalMovementPreview.from_query(movement_board, &"hero", Vector2i(2, 1), 3)
	var first_movement_dictionary: Dictionary = movement_preview.to_dictionary()
	(first_movement_dictionary.get("metadata", {}) as Dictionary)["path"][0]["x"] = 99
	(first_movement_dictionary.get("cue_ids", []) as Array)[0] = "presenter_mutation"

	var second_movement_dictionary: Dictionary = movement_preview.to_dictionary()

	assert_equal(((second_movement_dictionary.get("metadata", {}) as Dictionary).get("path", []) as Array)[0], _cell(0, 0), "Movement preview should return fresh nested path dictionaries.")
	assert_equal((second_movement_dictionary.get("cue_ids", []) as Array)[0], "move_preview_valid", "Movement preview should return fresh cue id arrays.")
	_assert_no_forbidden_references(second_movement_dictionary, "Movement preview copies should remain reference-free.")

	var attack_board: BoardState = BoardFixtureFactory.attack_preview_adjacent_enemy()
	var attack_preview: TacticalAttackPreview = TacticalAttackPreview.from_query(attack_board, &"hero", Vector2i(2, 1), _weapon(&"bow"))
	var first_attack_dictionary: Dictionary = attack_preview.to_dictionary()
	(first_attack_dictionary.get("metadata", {}) as Dictionary)["line_cells"][0]["x"] = 99
	(first_attack_dictionary.get("metadata", {}) as Dictionary)["warnings"][0]["id"] = "presenter_mutation"
	(first_attack_dictionary.get("cue_ids", []) as Array)[0] = "presenter_mutation"

	var second_attack_dictionary: Dictionary = attack_preview.to_dictionary()
	var attack_metadata: Dictionary = second_attack_dictionary.get("metadata", {})

	assert_equal(((attack_metadata.get("line_cells", []) as Array)[0] as Dictionary), _cell(1, 1), "Attack preview should return fresh nested line dictionaries.")
	assert_equal(((attack_metadata.get("warnings", []) as Array)[0] as Dictionary).get("id"), "adjacent_ranged_penalty", "Attack preview should return fresh warning dictionaries.")
	assert_equal((second_attack_dictionary.get("cue_ids", []) as Array)[0], "attack_preview_valid", "Attack preview should return fresh cue id arrays.")
	_assert_no_forbidden_references(second_attack_dictionary, "Attack preview copies should remain reference-free.")


func _board_view_model_preserves_preview_contracts_and_commit_availability() -> void:
	var movement_board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var movement_preview: Dictionary = TacticalMovementPreview.from_query(movement_board, &"hero", Vector2i(2, 1), 3).to_dictionary()
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var movement_data: Dictionary = TacticalBoardViewModel.from_domain(movement_board, turn_state, {
		"preview": movement_preview
	}).to_dictionary()
	var movement_vm_preview: Dictionary = movement_data.get("preview", {})
	var movement_availability: Dictionary = movement_data.get("action_availability", {})

	assert_equal(movement_vm_preview.get("target_cell"), _cell(2, 1), "Board VM should preserve movement preview target cell.")
	assert_equal((movement_vm_preview.get("metadata", {}) as Dictionary).get("path"), [_cell(0, 0), _cell(1, 0), _cell(2, 0), _cell(2, 1)], "Board VM should preserve sanitized movement preview path.")
	assert_equal((movement_availability.get("move", {}) as Dictionary).get("enabled"), true, "Move action should use preview commit availability.")
	assert_equal((movement_availability.get("move", {}) as Dictionary).get("reason"), "valid", "Move action should preserve commit reason.")
	assert_equal((movement_availability.get("confirm", {}) as Dictionary).get("enabled"), true, "Confirm should be available when the current preview can commit.")
	assert_equal((movement_availability.get("confirm", {}) as Dictionary).get("reason"), "valid", "Confirm should preserve preview commit reason.")
	assert_equal((movement_availability.get("attack", {}) as Dictionary).get("enabled"), false, "Attack should be unavailable for a move preview.")
	assert_equal((movement_availability.get("inspect", {}) as Dictionary).get("enabled"), true, "Inspect should remain metadata-only available.")
	assert_equal((movement_availability.get("cancel", {}) as Dictionary).get("enabled"), false, "Cancel remains out of scope until Story 2.3.")

	var attack_board: BoardState = BoardFixtureFactory.attack_preview_adjacent_enemy()
	var attack_preview: Dictionary = TacticalAttackPreview.from_query(attack_board, &"hero", Vector2i(2, 1), _weapon(&"bow")).to_dictionary()
	var attack_data: Dictionary = TacticalBoardViewModel.from_domain(attack_board, turn_state, {
		"preview": attack_preview
	}).to_dictionary()
	var attack_vm_preview: Dictionary = attack_data.get("preview", {})
	var attack_availability: Dictionary = attack_data.get("action_availability", {})

	assert_equal(attack_vm_preview.get("target_entity_id"), "enemy_1", "Board VM should preserve attack preview target entity id.")
	assert_equal(((attack_vm_preview.get("metadata", {}) as Dictionary).get("warnings", []) as Array)[0].get("id"), "adjacent_ranged_penalty", "Board VM should preserve sanitized attack warnings.")
	assert_equal((attack_availability.get("attack", {}) as Dictionary).get("enabled"), true, "Attack action should use preview commit availability.")
	assert_equal((attack_availability.get("confirm", {}) as Dictionary).get("enabled"), true, "Confirm should be available for commit-ready attack previews.")
	assert_equal((attack_availability.get("move", {}) as Dictionary).get("enabled"), false, "Move should be unavailable for an attack preview.")

	var invalid_preview: Dictionary = TacticalAttackPreview.from_query(attack_board, &"hero", Vector2i(1, 1), _weapon(&"sword")).to_dictionary()
	var invalid_data: Dictionary = TacticalBoardViewModel.from_domain(attack_board, turn_state, {
		"preview": invalid_preview
	}).to_dictionary()
	var invalid_availability: Dictionary = invalid_data.get("action_availability", {})

	assert_equal((invalid_availability.get("attack", {}) as Dictionary).get("enabled"), false, "Invalid attack previews should not expose commit availability.")
	assert_equal((invalid_availability.get("attack", {}) as Dictionary).get("reason"), "same_cell", "Invalid attack availability should preserve stable reason.")
	assert_equal((invalid_availability.get("confirm", {}) as Dictionary).get("enabled"), false, "Confirm should be unavailable for invalid previews.")


func _command_bridge_still_strips_path_and_line_internals() -> void:
	var move_board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var move_streams: RngStreamSet = RngStreamSet.new(220203)
	var move_turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var move_context: TacticalActionContext = TacticalActionContext.new(move_board, move_turn_state, move_streams, [])
	var move_result: CommandBridgeResult = TacticalCommandBridge.new().build_command(move_context, {
		"intent_id": "move",
		"actor_id": "hero",
		"target_cell": _cell(2, 1),
		"movement_budget": 3
	})

	assert_true(move_result.succeeded, "Move bridge regression should build a valid command.")
	assert_true(move_result.command is MoveCommand, "Move bridge regression should return MoveCommand.")
	assert_false(move_result.metadata.has("path"), "Command bridge must keep path internals out of conversion metadata.")

	var attack_board: BoardState = BoardFixtureFactory.attack_preview_adjacent_enemy()
	var attack_streams: RngStreamSet = RngStreamSet.new(220204)
	var attack_turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var attack_context: TacticalActionContext = TacticalActionContext.new(attack_board, attack_turn_state, attack_streams, [])
	var attack_result: CommandBridgeResult = TacticalCommandBridge.new().build_command(attack_context, {
		"intent_id": "attack",
		"actor_id": "hero",
		"target_cell": _cell(2, 1),
		"weapon": _weapon(&"bow"),
		"attacker_support": _support(&"none"),
		"defender_support": null
	})

	assert_true(attack_result.succeeded, "Attack bridge regression should build a valid command.")
	assert_true(attack_result.command is AttackCommand, "Attack bridge regression should return AttackCommand.")
	assert_false(attack_result.metadata.has("line_cells"), "Command bridge must keep line internals out of conversion metadata.")
	assert_false(attack_result.metadata.has("blocker_cells"), "Command bridge must keep blocker internals out of conversion metadata.")


func _visible_board(board: BoardState) -> BoardState:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true
	return board


func _hidden_movement_board() -> BoardState:
	var board: BoardState = _visible_board(BoardFixtureFactory.edge_corner_movement())
	var hidden_cell: BoardCell = board.get_cell(Vector2i(1, 0))
	hidden_cell.visible = false
	hidden_cell.explored = false
	return board


func _attack_board_from_fixture(fixture_name: String) -> BoardState:
	match fixture_name:
		"attack_preview_adjacent_enemy":
			return BoardFixtureFactory.attack_preview_adjacent_enemy()
		"attack_preview_blocked_lane":
			return BoardFixtureFactory.attack_preview_blocked_lane()
		"attack_preview_diagonal_enemy":
			return BoardFixtureFactory.attack_preview_diagonal_enemy()
		"attack_preview_open_lane":
			return BoardFixtureFactory.attack_preview_open_lane()
		"attack_preview_hidden_enemy":
			return BoardFixtureFactory.attack_preview_hidden_enemy()
		"attack_preview_memory_enemy":
			return BoardFixtureFactory.attack_preview_memory_enemy()
		"attack_preview_empty_target":
			return BoardFixtureFactory.attack_preview_empty_target()
		"attack_preview_dead_target":
			return BoardFixtureFactory.attack_preview_dead_target()
		"attack_preview_friendly_target":
			return BoardFixtureFactory.attack_preview_friendly_target()
		_:
			assert_true(false, "Unknown attack preview fixture: %s" % fixture_name)
			return BoardFixtureFactory.attack_preview_adjacent_enemy()


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _support(support_id: StringName) -> Variant:
	return SupportRepository.create_baseline_repository().get_support(support_id)


func _cell(x: int, y: int) -> Dictionary:
	return {
		"x": x,
		"y": y
	}


func _sorted_keys(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in data.keys():
		result.append(String(key))
	result.sort()
	return result


func _warning_ids(warnings: Array) -> Array[String]:
	var result: Array[String] = []
	for warning_value: Variant in warnings:
		if warning_value is Dictionary:
			result.append(String((warning_value as Dictionary).get("id", "")))
	result.sort()
	return result


func _effect_ids(effects: Array) -> Array[String]:
	var result: Array[String] = []
	for effect_value: Variant in effects:
		if effect_value is Dictionary:
			result.append(String((effect_value as Dictionary).get("id", "")))
	result.sort()
	return result


func _assert_warning_ids(warnings: Array, expected_warning_ids: Array, case_id: String) -> void:
	var actual_ids: Array[String] = _warning_ids(warnings)
	for expected_id: Variant in expected_warning_ids:
		assert_true(actual_ids.has(String(expected_id)), "Attack preview %s should expose warning id %s." % [case_id, String(expected_id)])
	if not expected_warning_ids.is_empty():
		assert_true(actual_ids.has("adjacent_ranged_penalty"), "Adjacency warning must keep the stable weapon warning id.")


func _assert_effect_ids(effects: Array, expected_effect_ids: Array, case_id: String) -> void:
	var actual_ids: Array[String] = _effect_ids(effects)
	for expected_id: Variant in expected_effect_ids:
		assert_true(actual_ids.has(String(expected_id)), "Attack preview %s should expose effect id %s." % [case_id, String(expected_id)])


func _assert_has_all_cues(preview: Dictionary, expected_cues: Array[String], message: String) -> void:
	var cue_ids: Array = preview.get("cue_ids", [])
	for cue_id: String in expected_cues:
		assert_true(cue_ids.has(cue_id), message)


func _assert_no_forbidden_references(value: Variant, message: String) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var data: Dictionary = value
			for key: Variant in data.keys():
				_assert_no_forbidden_references(data[key], message)
		TYPE_ARRAY:
			for item: Variant in value:
				_assert_no_forbidden_references(item, message)
		TYPE_OBJECT:
			assert_false(value is BoardState, message)
			assert_false(value is BoardCell, message)
			assert_false(value is TacticalEntityState, message)
			assert_false(value is TacticalActionContext, message)
			assert_false(value is ActionResult, message)
			assert_false(value is MoveCommand, message)
			assert_false(value is AttackCommand, message)
			assert_false(value is WeaponDefinition, message)
			assert_false(value is Resource, message)
			assert_false(value is Node, message)


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
