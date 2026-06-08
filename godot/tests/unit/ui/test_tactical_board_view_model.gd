extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

func run() -> Dictionary:
	_view_model_exposes_stable_read_only_board_data()
	_hidden_and_memory_cells_do_not_leak_current_domain_facts()
	_view_model_dictionary_edits_do_not_mutate_domain_state_or_cached_values()
	_view_model_sanitizes_options_and_normalizes_availability()
	return result()


func _view_model_exposes_stable_read_only_board_data() -> void:
	var board: BoardState = _visibility_board()
	var turn_state: TacticalTurnState = TacticalTurnState.new(2, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var view_model: TacticalBoardViewModel = TacticalBoardViewModel.from_domain(board, turn_state, _view_options())
	var data: Dictionary = view_model.to_dictionary()
	var cells: Array = data.get("cells", [])
	var occupants: Array = data.get("occupants", [])
	var preview: Dictionary = data.get("preview", {})
	var availability: Dictionary = data.get("action_availability", {})
	var turn: Dictionary = data.get("turn", {})

	assert_equal(_sorted_keys(data), [
		"action_availability",
		"cells",
		"commit_flow",
		"event_log_summary",
		"height",
		"inspect",
		"occupants",
		"outcome",
		"preview",
		"selected_cell",
		"selected_entity_id",
		"turn",
		"width",
		"zoom"
	], "Board view-model should expose stable top-level dictionary keys.")
	assert_equal(data.get("width"), 6, "View model should expose board width.")
	assert_equal(data.get("height"), 6, "View model should expose board height.")
	assert_equal(cells.size(), 36, "View model should include one copied cell view per board cell.")
	assert_equal((cells[0] as Dictionary).get("position"), _cell(0, 0), "Cells should be sorted row-major.")
	assert_equal((cells[1] as Dictionary).get("position"), _cell(1, 0), "Cells should be sorted row-major by x within y.")
	assert_equal((cells[6] as Dictionary).get("position"), _cell(0, 1), "Cells should be sorted row-major by y after each row.")
	assert_equal(occupants.size(), 2, "Only currently visible occupants should be summarized.")
	assert_equal((occupants[0] as Dictionary).get("entity_id"), "enemy_iron", "Occupants should be sorted by stable id.")
	assert_equal((occupants[1] as Dictionary).get("entity_id"), "hero", "Occupants should be sorted by stable id.")
	assert_equal((occupants[0] as Dictionary).get("definition_id"), "iron_cultist", "Visible occupants should expose definition ids.")
	assert_equal((occupants[0] as Dictionary).get("current_hp"), 10, "Visible occupants should expose current HP.")
	assert_equal((occupants[0] as Dictionary).get("max_hp"), 10, "Visible occupants should expose max HP.")
	assert_equal((occupants[0] as Dictionary).get("is_alive"), true, "Visible occupants should expose alive state.")
	assert_equal((occupants[0] as Dictionary).get("is_dead"), false, "Visible occupants should expose dead state.")
	assert_equal(data.get("selected_cell"), _cell(0, 2), "Selection cell should be copied for UI use.")
	assert_equal(data.get("selected_entity_id"), "hero", "Selection entity id should be copied for UI use.")
	assert_equal(preview.get("kind"), "move", "Preview slot should preserve copied preview kind.")
	assert_equal(preview.get("available"), true, "Preview slot should preserve copied availability.")
	assert_equal(preview.get("actor_id"), "hero", "Preview slot should preserve copied actor id.")
	assert_equal(preview.get("target_cell"), _cell(1, 2), "Preview slot should preserve copied target cell.")
	assert_equal(preview.get("target_valid"), true, "Preview slot should preserve target validity.")
	assert_equal(preview.get("commit_available"), true, "Preview slot should preserve commit availability.")
	assert_equal(preview.get("commit_reason"), "valid", "Preview slot should preserve commit reason.")
	assert_equal(preview.get("cue_ids"), ["move_preview_valid", "commit_available"], "Preview slot should preserve copied cue ids.")
	assert_equal(preview.get("metadata"), {"path": [_cell(0, 2), _cell(1, 2)]}, "Preview metadata should be deeply copied.")
	assert_equal(data.get("commit_flow"), {}, "Commit flow should default to an empty presenter-safe dictionary.")
	assert_equal(data.get("inspect"), {}, "Inspect should default to an empty presenter-safe dictionary.")
	assert_equal(data.get("zoom"), {}, "Zoom should default to an empty presenter-safe dictionary.")
	assert_equal((availability.get("move", {}) as Dictionary).get("enabled"), true, "Move availability should reflect the move preview.")
	assert_equal((availability.get("attack", {}) as Dictionary).get("enabled"), false, "Attack availability should be stable even without an attack preview.")
	assert_equal((availability.get("confirm", {}) as Dictionary).get("enabled"), true, "Confirm availability should reflect preview commit availability.")
	assert_true(availability.has("inspect"), "Availability should include inspect.")
	assert_true(availability.has("cancel"), "Availability should include cancel.")
	assert_equal(turn.get("turn_number"), 2, "Turn copy should include turn number.")
	assert_equal(turn.get("phase"), "player_planning", "Turn copy should include phase id.")
	assert_equal(turn.get("active_actor_id"), "hero", "Turn copy should include active actor id.")
	assert_equal((data.get("outcome", {}) as Dictionary).get("state_id"), "active", "Outcome state should be copied when supplied.")
	assert_equal((data.get("outcome", {}) as Dictionary).get("metadata"), {"source": "unit_test"}, "Outcome metadata should be copied when supplied.")
	_assert_no_forbidden_references(data, "Presenter-facing board dictionary should not contain raw domain references.")


func _hidden_and_memory_cells_do_not_leak_current_domain_facts() -> void:
	var board: BoardState = _visibility_board()
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var data: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, _view_options()).to_dictionary()
	var hidden_cell: Dictionary = _cell_view(data, Vector2i(5, 0))
	var memory_wall_cell: Dictionary = _cell_view(data, Vector2i(3, 1))
	var memory_enemy_cell: Dictionary = _cell_view(data, Vector2i(1, 5))
	var visible_enemy_cell: Dictionary = _cell_view(data, Vector2i(3, 2))

	assert_equal(hidden_cell.get("visibility_state"), "hidden", "Never-seen cells should be hidden.")
	assert_equal(hidden_cell.size(), 2, "Hidden cells should expose only position and visibility state.")
	assert_false(hidden_cell.has("terrain"), "Hidden cells must not expose terrain.")
	assert_false(hidden_cell.has("occupant_id"), "Hidden cells must not expose current occupant ids.")
	assert_equal(memory_wall_cell.get("visibility_state"), "memory", "Explored unseen cells should expose memory state.")
	assert_equal(memory_wall_cell.get("authoritative"), false, "Memory cells should be non-authoritative.")
	assert_equal(memory_wall_cell.get("terrain"), BoardCell.Terrain.WALL, "Memory cells may expose stable terrain data.")
	assert_false(memory_enemy_cell.has("occupant_id"), "Memory cells must not expose current occupants.")
	assert_false(memory_enemy_cell.has("current_hp"), "Memory cells must not expose current HP.")
	assert_false(memory_enemy_cell.has("faction"), "Memory cells must not expose current factions.")
	assert_equal(visible_enemy_cell.get("visibility_state"), "visible", "Visible cells should expose visible state.")
	assert_equal(visible_enemy_cell.get("authoritative"), true, "Visible cells should be authoritative.")
	assert_equal(visible_enemy_cell.get("occupant_id"), "enemy_iron", "Visible cells may expose current occupant ids.")


func _view_model_dictionary_edits_do_not_mutate_domain_state_or_cached_values() -> void:
	var board: BoardState = _visibility_board()
	var streams: RngStreamSet = RngStreamSet.new(2201)
	var turn_state: TacticalTurnState = TacticalTurnState.new(3, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var event_log: Array[DomainEvent] = []
	var before_snapshot: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, [], event_log)
	var view_model: TacticalBoardViewModel = TacticalBoardViewModel.from_domain(board, turn_state, _view_options())
	var first_dictionary: Dictionary = view_model.to_dictionary()

	(first_dictionary.get("cells", []) as Array)[0]["position"]["x"] = 99
	(first_dictionary.get("occupants", []) as Array)[0]["current_hp"] = 0
	(first_dictionary.get("preview", {}) as Dictionary)["metadata"]["path"][0]["x"] = 99
	(first_dictionary.get("action_availability", {}) as Dictionary)["move"]["reason"] = "presenter_mutation"
	(first_dictionary.get("turn", {}) as Dictionary)["active_actor_id"] = "presenter_mutation"

	var second_dictionary: Dictionary = view_model.to_dictionary()

	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, [], event_log), before_snapshot, "Editing returned view-model dictionaries must not mutate tactical snapshot data.")
	assert_equal(_cell_view(second_dictionary, Vector2i(0, 0)).get("position"), _cell(0, 0), "View model should return fresh cell dictionary copies.")
	assert_equal((second_dictionary.get("occupants", []) as Array)[0].get("current_hp"), 10, "View model should return fresh occupant dictionary copies.")
	assert_equal((second_dictionary.get("preview", {}) as Dictionary).get("metadata"), {"path": [_cell(0, 2), _cell(1, 2)]}, "View model should return fresh preview metadata copies.")
	assert_equal(((second_dictionary.get("action_availability", {}) as Dictionary).get("move", {}) as Dictionary).get("reason"), "valid", "View model should return fresh availability copies.")
	assert_equal((second_dictionary.get("turn", {}) as Dictionary).get("active_actor_id"), "hero", "View model should return fresh turn copies.")


func _view_model_sanitizes_options_and_normalizes_availability() -> void:
	var board: BoardState = _visibility_board()
	var view_model: TacticalBoardViewModel = TacticalBoardViewModel.from_domain(board, null, {
		&"selection": {
			&"selected_cell": {
				&"x": 2,
				&"y": 3
			},
			&"selected_entity_id": &"hero"
		},
		&"preview": {
			&"kind": "move",
			&"available": true,
			&"reason": "valid",
			&"metadata": {
				"raw_cell": board.get_cell(Vector2i(0, 2)),
				"vector_cell": Vector2i(1, 2),
				"path": [
					{
						&"x": 0,
						&"y": 2
					}
				]
			}
		},
		&"commit_flow": {
			&"mode": &"attack_preview",
			&"raw_context": TacticalActionContext.new(board, null, null, []),
			&"target_cell": Vector2i(1, 2)
		},
		&"action_availability": {
			&"move": {
				&"enabled": false,
				&"reason": "presenter_override"
			}
		},
		&"event_log_summary": [
			{
				"event": DomainEvent.enemy_waited(1, &"enemy_iron", &"test")
			}
		]
	})
	var data: Dictionary = view_model.to_dictionary()
	var preview_metadata: Dictionary = (data.get("preview", {}) as Dictionary).get("metadata", {})
	var commit_flow: Dictionary = data.get("commit_flow", {})
	var availability: Dictionary = data.get("action_availability", {})
	var event_summary: Array = data.get("event_log_summary", [])

	assert_equal(data.get("selected_cell"), _cell(2, 3), "Selection should accept StringName-keyed coordinates.")
	assert_equal(preview_metadata.get("raw_cell"), null, "Preview metadata should not expose raw BoardCell references.")
	assert_equal(preview_metadata.get("vector_cell"), _cell(1, 2), "Preview metadata should serialize Vector2i values.")
	assert_equal(((preview_metadata.get("path", []) as Array)[0] as Dictionary), _cell(0, 2), "Nested StringName coordinate keys should serialize.")
	assert_equal(commit_flow.get("raw_context"), null, "Commit flow metadata should not expose raw TacticalActionContext references.")
	assert_equal(commit_flow.get("target_cell"), _cell(1, 2), "Commit flow metadata should serialize Vector2i values.")
	assert_equal((availability.get("move", {}) as Dictionary).get("enabled"), false, "Supplied move availability should be normalized.")
	assert_equal((availability.get("move", {}) as Dictionary).get("reason"), "presenter_override", "Supplied move availability should preserve stable reason.")
	assert_true(availability.has("attack"), "Normalized availability should keep attack key.")
	assert_true(availability.has("inspect"), "Normalized availability should keep inspect key.")
	assert_true(availability.has("confirm"), "Normalized availability should keep confirm key.")
	assert_true(availability.has("cancel"), "Normalized availability should keep cancel key.")
	assert_equal(((event_summary[0] as Dictionary).get("event")), null, "Event log summary should not expose raw DomainEvent references.")
	_assert_no_forbidden_references(data, "Sanitized view-model options should not contain raw domain references.")


func _visibility_board() -> BoardState:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_set_visible(board, Vector2i(0, 2), true, true)
	_set_visible(board, Vector2i(3, 2), true, true)
	_set_visible(board, Vector2i(3, 1), false, true)
	_set_visible(board, Vector2i(1, 5), false, true)
	return board


func _set_visible(board: BoardState, cell: Vector2i, visible: bool, explored: bool) -> void:
	var board_cell: BoardCell = board.get_cell(cell)
	board_cell.visible = visible
	board_cell.explored = explored


func _view_options() -> Dictionary:
	return {
		"selection": {
			"selected_cell": Vector2i(0, 2),
			"selected_entity_id": &"hero"
		},
		"preview": {
			"kind": "move",
			"available": true,
			"reason": "valid",
			"actor_id": "hero",
			"target_cell": Vector2i(1, 2),
			"target_valid": true,
			"commit_available": true,
			"commit_reason": "valid",
			"cue_ids": ["move_preview_valid", "commit_available"],
			"metadata": {
				"path": [_cell(0, 2), _cell(1, 2)]
			}
		},
		"outcome": {
			"state_id": "active",
			"metadata": {
				"source": "legacy_dictionary"
			}
		},
		"outcome_state": CombatOutcomeState.new(CombatOutcomeState.STATE_ACTIVE, {"source": "unit_test"}),
		"event_log_summary": [
			{"event_id": "visibility_updated", "text": "Hero sees the lane."}
		]
	}


func _cell_view(data: Dictionary, cell: Vector2i) -> Dictionary:
	for cell_value: Variant in data.get("cells", []):
		if not cell_value is Dictionary:
			continue
		var cell_data: Dictionary = cell_value
		if cell_data.get("position") == _cell(cell.x, cell.y):
			return cell_data
	return {}


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
			assert_false(value is DomainEvent, message)
			assert_false(value is TacticalActionContext, message)


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
