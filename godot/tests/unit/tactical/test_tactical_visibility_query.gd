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
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")

func run() -> Dictionary:
	_baseline_radius_uses_squared_euclidean_from_center_and_edge()
	_blockers_are_visible_and_hide_cells_beyond()
	_diagonal_and_corner_golden_fixtures_match_expected_sets()
	_visibility_recalculation_after_move_preserves_explored_memory()
	_visible_fact_queries_filter_hidden_memory_and_current_truth()
	return result()


func _baseline_radius_uses_squared_euclidean_from_center_and_edge() -> void:
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var open_board: BoardState = BoardFixtureFactory.los_open_radius()
	var edge_board: BoardState = BoardFixtureFactory.los_edge_origin()
	var streams: RngStreamSet = RngStreamSet.new(1701)
	var open_before: Dictionary = open_board.to_snapshot()
	var edge_before: Dictionary = edge_board.to_snapshot()
	var tactical_snapshot_before: Dictionary = _tactical_snapshot_dictionary(open_board, streams)
	var rng_before: Dictionary = streams.to_snapshot()

	var center_result: ActionResult = query.calculate_visible_cells(open_board, Vector2i(4, 4))
	var edge_result: ActionResult = query.calculate_visible_cells(edge_board, Vector2i.ZERO)

	assert_true(center_result.succeeded, "Center visibility calculation should succeed.")
	assert_false(center_result.has_events(), "Pure visibility calculations should not emit events.")
	assert_equal(center_result.metadata.get("radius"), TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS, "Visibility should report the baseline radius.")
	assert_equal(center_result.metadata.get("visible_cells"), _serialize_cells(BoardFixtureFactory.expected_los_open_radius_cells()), "Open center fixture should use squared Euclidean radius 4.")
	assert_true(edge_result.succeeded, "Edge visibility calculation should succeed.")
	assert_equal(edge_result.metadata.get("visible_cells"), _serialize_cells(BoardFixtureFactory.expected_los_edge_origin_cells()), "Edge-origin fixture should clip radius to board bounds.")
	assert_equal(open_board.to_snapshot(), open_before, "Pure visibility calculations must not mutate open-board snapshots.")
	assert_equal(edge_board.to_snapshot(), edge_before, "Pure visibility calculations must not mutate edge-board snapshots.")
	assert_equal(_tactical_snapshot_dictionary(open_board, streams), tactical_snapshot_before, "Pure visibility calculations must not mutate tactical snapshot data.")
	assert_equal(streams.to_snapshot(), rng_before, "Pure visibility calculations must not consume RNG streams.")


func _blockers_are_visible_and_hide_cells_beyond() -> void:
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = BoardFixtureFactory.los_blocker_lane()
	var result_value: ActionResult = query.calculate_visible_cells(board, Vector2i(1, 2))
	var actual: Array = result_value.metadata.get("visible_cells", [])

	assert_true(result_value.succeeded, "Blocker-lane visibility calculation should succeed.")
	assert_equal(actual, _serialize_cells(BoardFixtureFactory.expected_los_blocker_lane_cells()), _fixture_message(
		"los_blocker_lane",
		Vector2i(1, 2),
		BoardFixtureFactory.expected_los_blocker_lane_cells(),
		actual
	))
	assert_true(_has_serialized_cell(actual, Vector2i(3, 2)), "A blocking target cell should remain visible.")
	assert_false(_has_serialized_cell(actual, Vector2i(4, 2)), "Cells behind a blocker should be hidden.")
	assert_false(_has_serialized_cell(actual, Vector2i(5, 2)), "Further cells behind a blocker should be hidden.")


func _diagonal_and_corner_golden_fixtures_match_expected_sets() -> void:
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()

	_assert_visible_fixture(
		query,
		"los_corner_peeking",
		BoardFixtureFactory.los_corner_peeking(),
		Vector2i.ZERO,
		BoardFixtureFactory.expected_los_corner_peeking_cells()
	)
	_assert_visible_fixture(
		query,
		"los_diagonal_line",
		BoardFixtureFactory.los_diagonal_line(),
		Vector2i.ZERO,
		BoardFixtureFactory.expected_los_diagonal_line_cells()
	)


func _visibility_recalculation_after_move_preserves_explored_memory() -> void:
	var board: BoardState = BoardFixtureFactory.los_movement_update_memory()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var streams: RngStreamSet = RngStreamSet.new(44)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var rng_before: Dictionary = streams.to_snapshot()

	var initial_event_result: ActionResult = query.create_visibility_updated_event(board, &"hero")
	var initial_apply_result: ActionResult = board.apply_events(initial_event_result.events)
	var move_result: ActionResult = MoveCommand.new(&"hero", Vector2i(3, 0)).execute(context)
	var recalculation_result: ActionResult = query.create_visibility_updated_event(board, &"hero")
	var recalculation_apply_result: ActionResult = board.apply_events(recalculation_result.events)

	assert_true(initial_event_result.succeeded, "Initial visibility event creation should succeed.")
	assert_true(initial_apply_result.succeeded, "Initial visibility event should apply.")
	assert_true(move_result.succeeded, "MoveCommand should succeed after explicit initial visibility.")
	assert_equal(move_result.events.size(), 1, "MoveCommand must keep emitting exactly one event.")
	assert_equal(move_result.events[0].event_type, DomainEvent.Type.ENTITY_MOVED, "MoveCommand must not fold fog recalculation into movement.")
	assert_equal(move_result.metadata.get("advances_turn"), true, "MoveCommand should preserve turn-advance metadata.")
	assert_true(recalculation_result.succeeded, "Visibility recalculation event creation should succeed.")
	assert_true(recalculation_apply_result.succeeded, "Visibility recalculation should apply after movement.")
	assert_false(board.get_cell(Vector2i(0, 4)).visible, "Previously visible cells outside the new LoS should no longer be current truth.")
	assert_true(board.get_cell(Vector2i(0, 4)).explored, "Previously visible cells should remain explored memory.")
	assert_true(board.get_cell(Vector2i(4, 3)).visible, "Newly seen cells should be current visible truth.")
	assert_true(board.get_cell(Vector2i(4, 3)).explored, "Newly seen cells should become explored.")
	assert_false(board.get_cell(Vector2i(4, 4)).visible, "Never-seen cells outside current LoS should remain hidden.")
	assert_false(board.get_cell(Vector2i(4, 4)).explored, "Never-seen cells should not become explored.")
	assert_equal(streams.to_snapshot(), rng_before, "Visibility recalculation and movement should not consume RNG streams.")


func _visible_fact_queries_filter_hidden_memory_and_current_truth() -> void:
	var board: BoardState = BoardFixtureFactory.occupied_cell()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var enemy_cell: Vector2i = Vector2i(1, 1)

	var hidden_result: ActionResult = query.visible_facts_for_cell(board, enemy_cell)
	var hidden_fact: Dictionary = hidden_result.metadata.get("fact", {})
	board.get_cell(enemy_cell).explored = true
	var memory_result: ActionResult = query.visible_facts_for_cell(board, enemy_cell)
	var memory_fact: Dictionary = memory_result.metadata.get("fact", {})
	board.get_cell(enemy_cell).visible = true
	var visible_result: ActionResult = query.visible_facts_for_cell(board, enemy_cell)
	var visible_fact: Dictionary = visible_result.metadata.get("fact", {})

	assert_true(hidden_result.succeeded, "Hidden fact query should succeed for in-bounds cells.")
	assert_equal(hidden_fact.get("visibility_state"), "hidden", "Hidden cells should report hidden state.")
	assert_equal(hidden_fact.size(), 2, "Hidden cells should expose only position and visibility state.")
	assert_false(hidden_fact.has("terrain"), "Hidden cells must not expose terrain.")
	assert_false(hidden_fact.has("occupant_id"), "Hidden cells must not expose occupants.")
	assert_true(memory_result.succeeded, "Memory fact query should succeed for explored cells.")
	assert_equal(memory_fact.get("visibility_state"), "memory", "Explored unseen cells should report memory state.")
	assert_equal(memory_fact.get("authoritative"), false, "Explored memory should be marked non-authoritative.")
	assert_true(memory_fact.has("terrain"), "Explored memory may expose stable terrain display data.")
	assert_false(memory_fact.has("occupant_id"), "Explored memory must not expose current occupants.")
	assert_false(memory_fact.has("current_hp"), "Explored memory must not expose current HP.")
	assert_true(visible_result.succeeded, "Visible fact query should succeed for visible cells.")
	assert_equal(visible_fact.get("visibility_state"), "visible", "Visible cells should report visible state.")
	assert_equal(visible_fact.get("authoritative"), true, "Visible cells should expose authoritative tactical facts.")
	assert_equal(visible_fact.get("occupant_id"), "enemy_1", "Visible cells should expose current occupant id.")
	assert_equal(visible_fact.get("entity_type"), "enemy", "Visible cells should expose current occupant type.")
	assert_equal(visible_fact.get("faction"), "enemy", "Visible cells should expose current occupant faction.")
	assert_equal(visible_fact.get("current_hp"), 10, "Visible cells should expose current occupant HP.")


func _assert_visible_fixture(
	query: TacticalVisibilityQuery,
	fixture_name: String,
	board: BoardState,
	origin: Vector2i,
	expected_cells: Array[Vector2i]
) -> void:
	var result_value: ActionResult = query.calculate_visible_cells(board, origin)
	var actual: Array = result_value.metadata.get("visible_cells", [])

	assert_true(result_value.succeeded, "%s visibility calculation should succeed." % fixture_name)
	assert_equal(actual, _serialize_cells(expected_cells), _fixture_message(fixture_name, origin, expected_cells, actual))


func _fixture_message(fixture_name: String, origin: Vector2i, expected_cells: Array[Vector2i], actual_cells: Array) -> String:
	var expected_serialized: Array[Dictionary] = _serialize_cells(expected_cells)
	return "LoS fixture %s board=%s actor_cell=%s radius=%s blocker_rule=BoardCell.blocks_line_of_sight expected=%s actual=%s missing=%s extra=%s" % [
		fixture_name,
		fixture_name,
		origin,
		TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS,
		expected_serialized,
		actual_cells,
		_missing_cells(expected_serialized, actual_cells),
		_extra_cells(expected_serialized, actual_cells)
	]


func _missing_cells(expected_cells: Array[Dictionary], actual_cells: Array) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	for cell: Dictionary in expected_cells:
		if not actual_cells.has(cell):
			missing.append(cell)
	return missing


func _extra_cells(expected_cells: Array[Dictionary], actual_cells: Array) -> Array:
	var extra: Array = []
	for cell: Variant in actual_cells:
		if not expected_cells.has(cell):
			extra.append(cell)
	return extra


func _has_serialized_cell(cells: Array, cell: Vector2i) -> bool:
	return cells.has(_serialize_cell(cell))


func _serialize_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var result_value: Array[Dictionary] = []
	for cell: Vector2i in cells:
		result_value.append(_serialize_cell(cell))
	return result_value


func _serialize_cell(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _tactical_snapshot_dictionary(board: BoardState, streams: RngStreamSet) -> Dictionary:
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams)
	assert_true(result_value.succeeded, "Test helper should export a top-level tactical snapshot.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()
