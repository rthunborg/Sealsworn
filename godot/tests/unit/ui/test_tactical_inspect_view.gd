extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalInspectView = preload("res://scripts/ui/view_models/tactical_inspect_view.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_visible_terrain_inspect_exposes_copied_cell_and_movement_preview()
	_invalid_movement_budget_preserves_query_reason()
	_visible_enemy_inspect_exposes_occupant_and_attack_preview_without_command()
	_memory_and_hidden_inspect_respect_visibility_boundaries()
	_pending_telegraph_is_exposed_only_for_known_cells()
	_inspect_dictionaries_are_deep_copied_and_reference_free()
	_board_view_model_carries_sanitized_inspect_data()
	return result()


func _visible_terrain_inspect_exposes_copied_cell_and_movement_preview() -> void:
	var board: BoardState = _inspect_board()
	var streams: RngStreamSet = RngStreamSet.new(2401)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)

	var inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(1, 2), {
		"actor_id": &"hero",
		"movement_budget": 3
	}).to_dictionary()
	var movement: Dictionary = inspect.get("movement", {})
	var attack_preview: Dictionary = inspect.get("attack_preview", {})

	assert_equal(_sorted_keys(inspect), [
		"attack_preview",
		"authoritative",
		"available",
		"cell",
		"cue_ids",
		"hazards",
		"kind",
		"metadata",
		"movement",
		"occupant",
		"reason",
		"target_cell",
		"telegraphs",
		"visibility_state"
	], "Inspect view should expose stable top-level keys.")
	assert_equal(inspect.get("kind"), "inspect", "Inspect view should identify its kind.")
	assert_equal(inspect.get("available"), true, "Visible terrain should be inspectable.")
	assert_equal(inspect.get("reason"), "visible", "Visible terrain should use a stable visible reason.")
	assert_equal(inspect.get("target_cell"), _cell(1, 2), "Inspect target cell should be copied.")
	assert_equal(inspect.get("visibility_state"), "visible", "Visible terrain should expose visible state.")
	assert_equal(inspect.get("authoritative"), true, "Visible terrain should be authoritative.")
	assert_equal((inspect.get("cell", {}) as Dictionary).get("position"), _cell(1, 2), "Visible cell data should be copied.")
	assert_equal((inspect.get("cell", {}) as Dictionary).get("terrain"), BoardCell.Terrain.FLOOR, "Visible cell should expose current terrain.")
	assert_equal(inspect.get("occupant"), {}, "Empty visible terrain should not invent an occupant.")
	assert_equal(movement.get("kind"), "move", "Inspect movement should reuse the movement preview DTO.")
	assert_equal(movement.get("available"), true, "Reachable terrain inspect should expose movement availability.")
	assert_equal(movement.get("reason"), "valid", "Movement preview reason should come from TacticalMovementPreview.")
	assert_equal((movement.get("metadata", {}) as Dictionary).get("movement_cost"), 1, "Inspect movement should expose deterministic move cost.")
	assert_equal((movement.get("metadata", {}) as Dictionary).get("path"), [_cell(0, 2), _cell(1, 2)], "Inspect movement should expose copied movement path for visible cells.")
	assert_equal(attack_preview.get("available"), false, "Attack preview should be disabled when no weapon is supplied.")
	assert_equal(attack_preview.get("reason"), "missing_weapon", "Missing weapon should use a stable disabled preview reason.")
	assert_equal(inspect.get("hazards"), [], "Hazards should stay an empty domain-backed placeholder.")
	assert_true((inspect.get("cue_ids", []) as Array).has("inspect_visible"), "Visible inspect should expose a stable cue id.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Building terrain inspect data must not mutate board, turn, RNG, telegraphs, or event log.")
	_assert_no_forbidden_references(inspect, "Inspect data should not expose raw domain, command, resource, or scene references.")


func _invalid_movement_budget_preserves_query_reason() -> void:
	var board: BoardState = _inspect_board()
	var streams: RngStreamSet = RngStreamSet.new(2411)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])

	var inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(1, 2), {
		"actor_id": &"hero",
		"movement_budget": 0
	}).to_dictionary()
	var movement: Dictionary = inspect.get("movement", {})
	var movement_metadata: Dictionary = movement.get("metadata", {})

	assert_equal(movement.get("available"), false, "Inspect movement should not convert an invalid budget into an available preview.")
	assert_equal(movement.get("reason"), "invalid_budget", "Inspect movement should preserve the movement query invalid-budget reason.")
	assert_equal(movement_metadata.get("movement_budget"), 0, "Inspect movement should pass explicit invalid budgets through to the movement query.")


func _visible_enemy_inspect_exposes_occupant_and_attack_preview_without_command() -> void:
	var board: BoardState = _inspect_board()
	var streams: RngStreamSet = RngStreamSet.new(2402)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)

	var inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(3, 2), {
		"actor_id": &"hero",
		"weapon": _weapon(&"bow")
	}).to_dictionary()
	var occupant: Dictionary = inspect.get("occupant", {})
	var attack_preview: Dictionary = inspect.get("attack_preview", {})
	var attack_metadata: Dictionary = attack_preview.get("metadata", {})

	assert_equal(inspect.get("available"), true, "Visible occupied enemy cell should be inspectable.")
	assert_equal(occupant.get("entity_id"), "enemy_iron", "Visible inspect should expose occupant id.")
	assert_equal(occupant.get("faction"), "enemy", "Visible inspect should expose occupant faction.")
	assert_equal(occupant.get("current_hp"), 10, "Visible inspect should expose current HP.")
	assert_equal(occupant.get("definition_id"), "iron_cultist", "Visible inspect should expose definition id.")
	assert_equal(attack_preview.get("kind"), "attack", "Inspect attack data should reuse the attack preview DTO.")
	assert_equal(attack_preview.get("available"), true, "Bow attack preview should be available for visible enemy.")
	assert_equal(attack_preview.get("reason"), "valid", "Attack preview reason should come from TacticalAttackPreview.")
	assert_equal(attack_preview.get("target_entity_id"), "enemy_iron", "Attack preview should expose visible target entity id.")
	assert_equal(attack_metadata.get("weapon_id"), "bow", "Attack preview metadata should expose copied weapon id.")
	assert_equal(attack_metadata.get("expected_damage"), 3, "Attack preview should expose deterministic expected damage.")
	assert_true(attack_metadata.has("warnings"), "Attack preview metadata should include warnings array.")
	assert_true(attack_metadata.has("effects"), "Attack preview metadata should include effects array.")
	assert_true((attack_preview.get("cue_ids", []) as Array).has("commit_available"), "Valid attack preview should expose commit availability cue without committing.")
	assert_equal(board.get_entity(&"enemy_iron").current_hp, 10, "Inspecting attack preview must not damage the target.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Building enemy inspect data must not mutate board, HP, turn, RNG, telegraphs, or event log.")
	_assert_no_forbidden_references(inspect, "Enemy inspect data should stay presenter-safe.")


func _memory_and_hidden_inspect_respect_visibility_boundaries() -> void:
	var board: BoardState = _inspect_board()
	var streams: RngStreamSet = RngStreamSet.new(2403)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])

	var memory_inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(1, 5), {
		"actor_id": &"hero",
		"weapon": _weapon(&"bow")
	}).to_dictionary()
	var hidden_inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(5, 0), {
		"actor_id": &"hero",
		"weapon": _weapon(&"bow")
	}).to_dictionary()

	assert_equal(memory_inspect.get("available"), true, "Explored memory cells should be inspectable.")
	assert_equal(memory_inspect.get("reason"), "memory", "Explored memory cells should use a stable memory reason.")
	assert_equal(memory_inspect.get("visibility_state"), "memory", "Explored memory cells should expose memory visibility.")
	assert_equal(memory_inspect.get("authoritative"), false, "Explored memory cells should be non-authoritative.")
	assert_equal((memory_inspect.get("cell", {}) as Dictionary).get("terrain"), BoardCell.Terrain.FLOOR, "Memory inspect may expose remembered terrain.")
	assert_equal(memory_inspect.get("occupant"), {}, "Memory inspect must not expose current occupants.")
	assert_false(memory_inspect.has("current_hp"), "Memory inspect must not expose HP at top level.")
	assert_false((memory_inspect.get("cell", {}) as Dictionary).has("occupant_id"), "Memory cell inspect must not expose occupant ids.")
	assert_false((memory_inspect.get("attack_preview", {}) as Dictionary).has("target_entity_id"), "Memory attack data must not expose hidden target ids.")

	assert_equal(hidden_inspect.get("available"), false, "Hidden unexplored cells should not be available as factual inspect data.")
	assert_equal(hidden_inspect.get("reason"), "hidden_unexplored", "Hidden unexplored cells should expose a stable hidden reason.")
	assert_equal(hidden_inspect.get("target_cell"), _cell(5, 0), "Hidden inspect should still copy target coordinates.")
	assert_equal(hidden_inspect.get("visibility_state"), "hidden", "Hidden inspect should expose hidden visibility state.")
	assert_false((hidden_inspect.get("cell", {}) as Dictionary).has("terrain"), "Hidden inspect must not expose terrain.")
	assert_equal(hidden_inspect.get("occupant"), {}, "Hidden inspect must not expose occupants.")
	assert_equal(hidden_inspect.get("hazards"), [], "Hidden inspect must not expose hazards.")
	assert_equal(hidden_inspect.get("telegraphs"), [], "Hidden inspect must not expose telegraphs.")
	assert_false((hidden_inspect.get("movement", {}) as Dictionary).has("path"), "Hidden inspect must not expose movement paths.")
	assert_equal((hidden_inspect.get("movement", {}) as Dictionary).get("reason"), "not_visible", "Hidden inspect movement should expose only a stable disabled preview reason.")
	assert_false(((hidden_inspect.get("movement", {}) as Dictionary).get("metadata", {}) as Dictionary).has("path"), "Hidden inspect must not expose nested movement paths.")
	assert_false((hidden_inspect.get("attack_preview", {}) as Dictionary).has("target_entity_id"), "Hidden inspect must not expose attack target facts.")
	assert_equal((hidden_inspect.get("attack_preview", {}) as Dictionary).get("reason"), "not_visible", "Hidden inspect attack preview should expose only a stable disabled preview reason.")
	assert_false(((hidden_inspect.get("attack_preview", {}) as Dictionary).get("metadata", {}) as Dictionary).has("line_cells"), "Hidden inspect must not expose attack line metadata.")


func _pending_telegraph_is_exposed_only_for_known_cells() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_mark()
	var visible_mark_cell: Vector2i = Vector2i(1, 2)
	var hidden_mark_cell: Vector2i = Vector2i(4, 4)
	var visible_mark: Dictionary = _telegraph("ash_visible", visible_mark_cell)
	var hidden_mark: Dictionary = _telegraph("ash_hidden", hidden_mark_cell)
	var hidden_cell: BoardCell = board.get_cell(hidden_mark_cell)
	hidden_cell.visible = false
	hidden_cell.explored = false

	var streams: RngStreamSet = RngStreamSet.new(2404)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [visible_mark, hidden_mark])

	var visible_inspect: Dictionary = TacticalInspectView.from_context(context, visible_mark_cell, {
		"actor_id": &"hero"
	}).to_dictionary()
	var hidden_inspect: Dictionary = TacticalInspectView.from_context(context, hidden_mark_cell, {
		"actor_id": &"hero"
	}).to_dictionary()
	var telegraphs: Array = visible_inspect.get("telegraphs", [])

	assert_equal(telegraphs.size(), 1, "Known marked cell should expose matching pending telegraph only.")
	assert_equal((telegraphs[0] as Dictionary).get("telegraph_id"), "ash_visible", "Telegraph inspect should copy stable telegraph id.")
	assert_equal((telegraphs[0] as Dictionary).get("kind"), "ash_seer_mark", "Telegraph inspect should preserve kind.")
	assert_equal((telegraphs[0] as Dictionary).get("marked_cell"), _cell(1, 2), "Telegraph inspect should copy marked cell.")
	assert_equal((telegraphs[0] as Dictionary).get("damage"), 4, "Telegraph inspect should copy danger damage.")
	assert_true((visible_inspect.get("cue_ids", []) as Array).has("telegraph_pending"), "Visible telegraph should add pending cue.")
	assert_true((visible_inspect.get("cue_ids", []) as Array).has("danger_damage"), "Visible telegraph should add damage cue.")
	assert_equal(hidden_inspect.get("telegraphs"), [], "Hidden unexplored telegraph cells must not expose pending danger.")
	assert_false((hidden_inspect.get("cue_ids", []) as Array).has("telegraph_pending"), "Hidden telegraphs should not expose danger cues.")

	var mutated: Dictionary = visible_inspect.duplicate(true)
	((mutated.get("telegraphs", []) as Array)[0] as Dictionary)["damage"] = 99
	assert_equal(int(context.pending_telegraphs[0].get("damage", 0)), 4, "Mutating inspect telegraph dictionaries must not mutate context pending telegraphs.")


func _inspect_dictionaries_are_deep_copied_and_reference_free() -> void:
	var board: BoardState = _inspect_board()
	var streams: RngStreamSet = RngStreamSet.new(2405)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [_telegraph("ash_visible", Vector2i(3, 2))])
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var inspect_view: TacticalInspectView = TacticalInspectView.from_context(context, Vector2i(3, 2), {
		"actor_id": &"hero",
		"weapon": _weapon(&"bow")
	})

	var first_dictionary: Dictionary = inspect_view.to_dictionary()
	(first_dictionary.get("cell", {}) as Dictionary)["terrain"] = BoardCell.Terrain.WALL
	(first_dictionary.get("occupant", {}) as Dictionary)["current_hp"] = 0
	((first_dictionary.get("telegraphs", []) as Array)[0] as Dictionary)["damage"] = 99
	(first_dictionary.get("attack_preview", {}) as Dictionary)["target_entity_id"] = "presenter_mutation"

	var second_dictionary: Dictionary = inspect_view.to_dictionary()

	assert_equal((second_dictionary.get("cell", {}) as Dictionary).get("terrain"), BoardCell.Terrain.FLOOR, "Inspect view should return fresh cell dictionaries.")
	assert_equal((second_dictionary.get("occupant", {}) as Dictionary).get("current_hp"), 10, "Inspect view should return fresh occupant dictionaries.")
	assert_equal(((second_dictionary.get("telegraphs", []) as Array)[0] as Dictionary).get("damage"), 4, "Inspect view should return fresh telegraph dictionaries.")
	assert_equal((second_dictionary.get("attack_preview", {}) as Dictionary).get("target_entity_id"), "enemy_iron", "Inspect view should return fresh attack preview dictionaries.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before, "Mutating returned inspect data must not mutate tactical snapshot data.")
	_assert_no_forbidden_references(second_dictionary, "Inspect dictionary copies should remain reference-free.")


func _board_view_model_carries_sanitized_inspect_data() -> void:
	var board: BoardState = _inspect_board()
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var streams: RngStreamSet = RngStreamSet.new(2406)
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [_telegraph("ash_visible", Vector2i(3, 2))])
	var inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(3, 2), {
		"actor_id": &"hero",
		"weapon": _weapon(&"bow")
	}).to_dictionary()
	inspect["raw_board"] = board
	inspect["metadata"]["raw_context"] = context

	var data: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"inspect": inspect
	}).to_dictionary()
	var carried_inspect: Dictionary = data.get("inspect", {})

	assert_equal(carried_inspect.get("kind"), "inspect", "Board VM should carry sanitized inspect dictionaries.")
	assert_equal(carried_inspect.get("target_cell"), _cell(3, 2), "Board VM should preserve inspect target cell.")
	assert_equal(carried_inspect.get("raw_board"), null, "Board VM inspect slot should strip raw BoardState references.")
	assert_equal((carried_inspect.get("metadata", {}) as Dictionary).get("raw_context"), null, "Board VM inspect metadata should strip raw context references.")
	assert_equal(((carried_inspect.get("telegraphs", []) as Array)[0] as Dictionary).get("telegraph_id"), "ash_visible", "Board VM should preserve copied telegraph inspect data.")
	_assert_no_forbidden_references(data, "Board VM inspect integration should stay presenter-safe.")


func _inspect_board() -> BoardState:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	for board_cell: BoardCell in board.cells():
		board_cell.visible = false
		board_cell.explored = false
	_set_visible(board, Vector2i(0, 2), true, true)
	_set_visible(board, Vector2i(1, 2), true, true)
	_set_visible(board, Vector2i(3, 2), true, true)
	_set_visible(board, Vector2i(1, 5), false, true)
	return board


func _set_visible(board: BoardState, cell: Vector2i, visible: bool, explored: bool) -> void:
	var board_cell: BoardCell = board.get_cell(cell)
	board_cell.visible = visible
	board_cell.explored = explored


func _telegraph(telegraph_id: String, marked_cell: Vector2i) -> Dictionary:
	return {
		"telegraph_id": telegraph_id,
		"kind": "ash_seer_mark",
		"source_entity_id": "enemy_seer",
		"target_entity_id": "hero",
		"marked_cell": _cell(marked_cell.x, marked_cell.y),
		"created_turn_number": 1,
		"due_turn_number": 2,
		"damage": 4,
		"damage_type": "fire",
		"status": "pending"
	}


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


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
			assert_false(value is WeaponDefinition, message)
			assert_false(value is Resource, message)
			assert_false(value is Node, message)
			assert_false(value is Control, message)


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
