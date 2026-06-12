extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackCommitFlow = preload("res://scripts/ui/view_models/tactical_attack_commit_flow.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalBoardZoomState = preload("res://scripts/ui/view_models/tactical_board_zoom_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalInspectView = preload("res://scripts/ui/view_models/tactical_inspect_view.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_zoom_state_clamps_to_defined_bounds()
	_coordinate_mapping_stays_aligned_across_viewport_sizes()
	_malformed_zoom_inputs_return_disabled_results()
	_zooming_around_focus_preserves_screen_to_cell_alignment()
	_zoom_during_attack_preview_preserves_flow_without_command()
	_zoom_during_inspect_preserves_target_without_command()
	_board_view_model_carries_sanitized_zoom_data()
	return result()


func _zoom_state_clamps_to_defined_bounds() -> void:
	var min_zoom: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
		"zoom": 0.25
	}))
	var max_zoom: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
		"zoom": 4.0
	}))
	var valid_zoom: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
		"zoom": 1.25
	}))
	var min_data: Dictionary = min_zoom.to_dictionary()
	var max_data: Dictionary = max_zoom.to_dictionary()
	var valid_data: Dictionary = valid_zoom.to_dictionary()

	assert_equal(_sorted_keys(valid_data), [
		"board_size",
		"cell_size",
		"cue_ids",
		"focused_cell",
		"max_zoom",
		"min_zoom",
		"origin",
		"reason",
		"viewport_size",
		"zoom"
	], "Zoom state should expose stable top-level keys.")
	assert_equal(min_data.get("zoom"), 0.75, "Zoom should clamp below the minimum.")
	assert_equal(min_data.get("reason"), "clamped_min", "Minimum clamp should expose stable reason.")
	assert_true((min_data.get("cue_ids", []) as Array).has("zoom_clamped_min"), "Minimum clamp should expose cue id.")
	assert_equal(max_data.get("zoom"), 2.0, "Zoom should clamp above the maximum.")
	assert_equal(max_data.get("reason"), "clamped_max", "Maximum clamp should expose stable reason.")
	assert_true((max_data.get("cue_ids", []) as Array).has("zoom_clamped_max"), "Maximum clamp should expose cue id.")
	assert_equal(valid_data.get("zoom"), 1.25, "Valid zoom should be preserved.")
	assert_equal(valid_data.get("reason"), "valid", "Valid zoom should expose stable reason.")
	assert_true((valid_data.get("cue_ids", []) as Array).has("zoom_valid"), "Valid zoom should expose cue id.")
	_assert_no_forbidden_references(valid_data, "Zoom dictionaries should be presenter-safe.")


func _coordinate_mapping_stays_aligned_across_viewport_sizes() -> void:
	var viewport_cases: Array[Dictionary] = [
		{"id": "phone", "viewport_size": Vector2(390.0, 844.0)},
		{"id": "tablet", "viewport_size": Vector2(834.0, 1194.0)},
		{"id": "desktop", "viewport_size": Vector2(1440.0, 900.0)}
	]
	for case_data: Dictionary in viewport_cases:
		var state: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
			"viewport_size": case_data.get("viewport_size"),
			"zoom": 1.0
		}))
		var screen_result: Dictionary = state.cell_to_screen(Vector2i(2, 3))
		var cell_result: Dictionary = state.screen_to_cell(_vector2_from_dictionary(screen_result.get("screen_position", {})))
		var rect_result: Dictionary = state.cell_rect(Vector2i(2, 3))

		assert_equal(screen_result.get("available"), true, "%s cell_to_screen should be available for in-bounds cells." % String(case_data.get("id", "")))
		assert_equal(screen_result.get("cell"), _cell(2, 3), "%s cell_to_screen should echo copied cell." % String(case_data.get("id", "")))
		assert_equal(cell_result.get("available"), true, "%s screen_to_cell should be available for mapped center." % String(case_data.get("id", "")))
		assert_equal(cell_result.get("cell"), _cell(2, 3), "%s screen_to_cell should map back to the source cell." % String(case_data.get("id", "")))
		assert_equal(rect_result.get("available"), true, "%s cell_rect should be available for in-bounds cells." % String(case_data.get("id", "")))
		assert_equal(rect_result.get("cell"), _cell(2, 3), "%s cell_rect should echo copied cell." % String(case_data.get("id", "")))
		assert_equal((rect_result.get("size", {}) as Dictionary), _point(48.0, 48.0), "%s cell_rect should scale by zoom." % String(case_data.get("id", "")))

	var out_of_bounds_state: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({}))
	assert_equal(out_of_bounds_state.cell_to_screen(Vector2i(9, 9)).get("reason"), "out_of_bounds", "cell_to_screen should return disabled out-of-bounds results.")
	assert_equal(out_of_bounds_state.screen_to_cell(Vector2(-100.0, -100.0)).get("reason"), "out_of_bounds", "screen_to_cell should return disabled out-of-bounds results.")


func _malformed_zoom_inputs_return_disabled_results() -> void:
	var malformed_focus: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
		"focused_cell": {}
	}))
	var non_finite_focus: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
		"focused_cell": {
			"x": NAN,
			"y": 2
		}
	}))
	var state: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({}))
	var nan_screen: Dictionary = state.screen_to_cell(Vector2(NAN, 48.0))
	var inf_screen: Dictionary = state.screen_to_cell(Vector2(INF, 48.0))

	assert_equal(malformed_focus.to_dictionary().get("focused_cell"), {}, "Malformed focused_cell dictionaries should not normalize to valid cells.")
	assert_equal(non_finite_focus.to_dictionary().get("focused_cell"), {}, "Non-finite focused_cell values should not normalize to valid cells.")
	assert_equal(nan_screen.get("available"), false, "NaN screen coordinates should return disabled mapping results.")
	assert_equal(nan_screen.get("reason"), "invalid_input", "NaN screen coordinates should expose a stable invalid-input reason.")
	assert_equal(inf_screen.get("available"), false, "Infinite screen coordinates should return disabled mapping results.")
	assert_equal(inf_screen.get("reason"), "invalid_input", "Infinite screen coordinates should expose a stable invalid-input reason.")


func _zooming_around_focus_preserves_screen_to_cell_alignment() -> void:
	var state: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
		"zoom": 1.0,
		"focused_cell": Vector2i(2, 3)
	}))
	var anchor_result: Dictionary = state.cell_to_screen(Vector2i(2, 3))
	var anchor_screen: Vector2 = _vector2_from_dictionary(anchor_result.get("screen_position", {}))
	var zoomed: TacticalBoardZoomState = state.with_zoom(1.6, anchor_screen, Vector2i(2, 3))
	var zoomed_data: Dictionary = zoomed.to_dictionary()
	var remapped: Dictionary = zoomed.screen_to_cell(anchor_screen)
	var selected_screen: Dictionary = zoomed.cell_to_screen(Vector2i(0, 2))
	var preview_screen: Dictionary = zoomed.cell_to_screen(Vector2i(3, 2))
	var inspect_screen: Dictionary = zoomed.cell_to_screen(Vector2i(1, 2))

	assert_equal(zoomed_data.get("zoom"), 1.6, "with_zoom should apply valid zoom values.")
	assert_equal(zoomed_data.get("focused_cell"), _cell(2, 3), "with_zoom should copy the focused cell.")
	assert_equal(remapped.get("cell"), _cell(2, 3), "The same anchor screen point should map to the same focused cell after zoom.")
	assert_equal(zoomed.screen_to_cell(_vector2_from_dictionary(selected_screen.get("screen_position", {}))).get("cell"), _cell(0, 2), "Selected domain cell should stay aligned after zoom.")
	assert_equal(zoomed.screen_to_cell(_vector2_from_dictionary(preview_screen.get("screen_position", {}))).get("cell"), _cell(3, 2), "Preview target cell should stay aligned after zoom.")
	assert_equal(zoomed.screen_to_cell(_vector2_from_dictionary(inspect_screen.get("screen_position", {}))).get("cell"), _cell(1, 2), "Inspect target cell should stay aligned after zoom.")


func _zoom_during_attack_preview_preserves_flow_without_command() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var streams: RngStreamSet = RngStreamSet.new(2407)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()
	var first_tap_result: Variant = flow.tap_attack_target(context, &"hero", Vector2i(3, 2), _weapon(&"bow"), _support(&"none"), null)
	var before_zoom: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var flow_data: Dictionary = flow.to_dictionary()
	var zoomed: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
		"focused_cell": Vector2i(3, 2),
		"zoom": 1.4
	}))
	var data: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"preview": flow_data.get("preview", {}),
		"commit_flow": flow_data,
		"zoom": zoomed.to_dictionary()
	}).to_dictionary()
	var availability: Dictionary = data.get("action_availability", {})

	assert_false(first_tap_result.submitted, "First tap setup should be preview-only.")
	assert_equal((data.get("preview", {}) as Dictionary).get("target_cell"), _cell(3, 2), "Zoom refresh should preserve preview target cell.")
	assert_equal((data.get("commit_flow", {}) as Dictionary).get("target_cell"), _cell(3, 2), "Zoom refresh should preserve commit-flow target cell.")
	assert_equal((data.get("zoom", {}) as Dictionary).get("focused_cell"), _cell(3, 2), "Board VM should carry zoom focused cell.")
	assert_equal((availability.get("confirm", {}) as Dictionary).get("enabled"), true, "Zoom should not clear a valid matching attack commit flow.")
	assert_equal(flow.to_dictionary().get("mode"), "attack_preview", "Zooming should not submit or clear the attack flow.")
	assert_equal(board.get_entity(&"enemy_iron").current_hp, 10, "Zooming during preview must not damage the target.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before_zoom, "Zooming during preview must not mutate board, turn, RNG, telegraphs, or event log.")
	_assert_no_forbidden_references(data, "Board VM zoom/preview data should stay presenter-safe.")


func _zoom_during_inspect_preserves_target_without_command() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var streams: RngStreamSet = RngStreamSet.new(2408)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var event_log: Array[DomainEvent] = []
	var before_zoom: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log)
	var inspect: Dictionary = TacticalInspectView.from_context(context, Vector2i(1, 2), {
		"actor_id": &"hero"
	}).to_dictionary()
	var zoomed: TacticalBoardZoomState = TacticalBoardZoomState.from_options(_zoom_options({
		"focused_cell": Vector2i(1, 2),
		"zoom": 1.5
	}))
	var data: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"inspect": inspect,
		"zoom_state": zoomed.to_dictionary()
	}).to_dictionary()

	assert_equal((data.get("inspect", {}) as Dictionary).get("target_cell"), _cell(1, 2), "Zooming with inspect active should preserve inspect target.")
	assert_equal((data.get("zoom", {}) as Dictionary).get("focused_cell"), _cell(1, 2), "Board VM should normalize zoom_state alias into zoom.")
	assert_equal(board.get_entity(&"enemy_iron").current_hp, 10, "Zooming during inspect must not submit commands.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, context.pending_telegraphs, event_log), before_zoom, "Zooming during inspect must not mutate tactical snapshot data.")


func _board_view_model_carries_sanitized_zoom_data() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	_reveal_all(board)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var zoom: Dictionary = TacticalBoardZoomState.from_options(_zoom_options({
		"focused_cell": Vector2i(3, 2),
		"zoom": 1.25
	})).to_dictionary()
	zoom["raw_board"] = board
	zoom["metadata"] = {
		"raw_entity": board.get_entity(&"enemy_iron")
	}

	var data: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {
		"zoom": zoom
	}).to_dictionary()
	var carried_zoom: Dictionary = data.get("zoom", {})

	assert_equal(carried_zoom.get("zoom"), 1.25, "Board VM should carry sanitized zoom dictionaries.")
	assert_equal(carried_zoom.get("focused_cell"), _cell(3, 2), "Board VM should preserve copied zoom focused cell.")
	assert_equal(carried_zoom.get("raw_board"), null, "Board VM zoom slot should strip raw BoardState references.")
	assert_equal((carried_zoom.get("metadata", {}) as Dictionary).get("raw_entity"), null, "Board VM zoom metadata should strip raw entity references.")
	_assert_no_forbidden_references(data, "Board VM zoom integration should stay presenter-safe.")


func _zoom_options(overrides: Dictionary) -> Dictionary:
	var options: Dictionary = {
		"board_size": Vector2i(6, 6),
		"cell_size": Vector2(48.0, 48.0),
		"viewport_size": Vector2(390.0, 844.0),
		"origin": Vector2(16.0, 24.0),
		"zoom": 1.0,
		"min_zoom": 0.75,
		"max_zoom": 2.0
	}
	for key: Variant in overrides.keys():
		options[key] = overrides[key]
	return options


func _reveal_all(board: BoardState) -> void:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _support(support_id: StringName) -> Variant:
	return SupportRepository.create_baseline_repository().get_support(support_id)


func _vector2_from_dictionary(value: Variant) -> Vector2:
	if not value is Dictionary:
		return Vector2.ZERO
	var data: Dictionary = value
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))


func _cell(x: int, y: int) -> Dictionary:
	return {
		"x": x,
		"y": y
	}


func _point(x: float, y: float) -> Dictionary:
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
			assert_false(value is AttackCommand, message)
			assert_false(value is WeaponDefinition, message)
			assert_false(value is SupportDefinition, message)
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
