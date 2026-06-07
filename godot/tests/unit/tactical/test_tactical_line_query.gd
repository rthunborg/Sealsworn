extends "res://tests/unit/test_case.gd"

const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalLineQuery = preload("res://scripts/tactical/targeting/tactical_line_query.gd")

func run() -> Dictionary:
	_supercover_line_matches_story_1_7_diagonal_semantics()
	_line_of_sight_allows_blocking_target_cell_but_not_cells_beyond()
	_intermediate_terrain_blockers_are_reported_in_line_order()
	return result()


func _supercover_line_matches_story_1_7_diagonal_semantics() -> void:
	var line: Array[Vector2i] = TacticalLineQuery.supercover_line(Vector2i.ZERO, Vector2i(2, 2))

	assert_equal(line, [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(1, 2),
		Vector2i(2, 2)
	], "Shared line helper should preserve Story 1.7 supercover ordering.")


func _line_of_sight_allows_blocking_target_cell_but_not_cells_beyond() -> void:
	var board: BoardState = BoardFixtureFactory.los_blocker_lane()

	assert_true(
		TacticalLineQuery.has_line_of_sight(board, Vector2i(1, 2), Vector2i(3, 2)),
		"A blocking target cell should still be visible/targetable when the rule allows it."
	)
	assert_false(
		TacticalLineQuery.has_line_of_sight(board, Vector2i(1, 2), Vector2i(4, 2)),
		"Cells behind an intermediate blocker should not have line of sight."
	)


func _intermediate_terrain_blockers_are_reported_in_line_order() -> void:
	var board: BoardState = BoardFixtureFactory.line_of_sight_blockers()
	var blockers: Array[Vector2i] = TacticalLineQuery.blocking_cells(
		board,
		Vector2i(0, 1),
		Vector2i(3, 1),
		false
	)

	assert_equal(blockers, [
		Vector2i(1, 1),
		Vector2i(2, 1)
	], "Line helper should report intermediate terrain blockers without treating the target as its own blocker.")
