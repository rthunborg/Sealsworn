extends "res://tests/unit/test_case.gd"

# Story 13.1 (Task 4) — the grid-fit seam coverage. Proves the pure TacticalBoardGridFit computes square
# cells that FIT the board region with a CENTERED origin for both a small (8x8) and a Medium (14x12) board,
# and that the geometry it hands to the SHARED TacticalBoardZoomState round-trips cell_rect -> screen_to_cell
# (so the draw and the hit-test can never disagree). An empty board reports available == false (the null
# between-levels board draws nothing, never divides by zero).

const TacticalBoardGridFit = preload("res://scripts/ui/view_models/tactical_board_grid_fit.gd")
const TacticalBoardZoomState = preload("res://scripts/ui/view_models/tactical_board_zoom_state.gd")

func run() -> Dictionary:
	_fits_square_cells_centered_for_small_board()
	_fits_square_cells_centered_for_medium_board()
	_letterboxes_and_centers_when_region_is_not_square()
	_shared_geometry_round_trips_cell_rect_to_screen_to_cell()
	_out_of_bounds_pixel_is_a_safe_no_op()
	_empty_board_is_unavailable_and_yields_no_geometry()
	return result()


func _fits_square_cells_centered_for_small_board() -> void:
	var fit: TacticalBoardGridFit = TacticalBoardGridFit.from_region(8, 8, {"x": 0.0, "y": 0.0, "width": 800.0, "height": 800.0})
	assert_true(fit.available(), "An 8x8 board should fit an 800x800 region.")
	assert_equal(fit.cell_size(), 100.0, "Square cells should divide the region evenly (800/8).")
	assert_equal(fit.origin(), Vector2(0.0, 0.0), "A square grid in a square region should have a zero-offset origin.")
	assert_equal(fit.grid_size(), Vector2(800.0, 800.0), "The grid should span the full region when square.")


func _fits_square_cells_centered_for_medium_board() -> void:
	var fit: TacticalBoardGridFit = TacticalBoardGridFit.from_region(14, 12, {"x": 10.0, "y": 20.0, "width": 700.0, "height": 600.0})
	assert_true(fit.available(), "A 14x12 board should fit a 700x600 region.")
	assert_equal(fit.cell_size(), 50.0, "Medium square cells should be min(700/14, 600/12) == 50.")
	assert_equal(fit.origin(), Vector2(10.0, 20.0), "A perfectly-fitting grid should keep the region origin.")
	assert_equal(fit.grid_size(), Vector2(700.0, 600.0), "The 14x12 grid at cell 50 should span 700x600.")


func _letterboxes_and_centers_when_region_is_not_square() -> void:
	# An 8x8 board in an 800x600 region is height-limited (cell 75); the 600-wide grid centers horizontally.
	var fit: TacticalBoardGridFit = TacticalBoardGridFit.from_region(8, 8, {"x": 0.0, "y": 0.0, "width": 800.0, "height": 600.0})
	assert_true(fit.available(), "An 8x8 board should fit an 800x600 region.")
	assert_equal(fit.cell_size(), 75.0, "Cells should be limited by the shorter axis (600/8).")
	assert_equal(fit.grid_size(), Vector2(600.0, 600.0), "The fitted grid should be 600x600.")
	assert_equal(fit.origin(), Vector2(100.0, 0.0), "The grid should center on the wider axis ((800-600)/2, 0).")


func _shared_geometry_round_trips_cell_rect_to_screen_to_cell() -> void:
	var fit: TacticalBoardGridFit = TacticalBoardGridFit.from_region(14, 12, {"x": 10.0, "y": 20.0, "width": 700.0, "height": 600.0})
	var geometry: TacticalBoardZoomState = fit.to_zoom_state(Vector2(720.0, 640.0))
	assert_true(geometry != null, "An available fit should yield a shared geometry object.")
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(5, 4), Vector2i(13, 11)]:
		var rect: Dictionary = geometry.cell_rect(cell)
		assert_equal(rect.get("available"), true, "cell_rect should be available for in-bounds cell %s." % str(cell))
		var rect_position: Dictionary = rect.get("position", {})
		var rect_size: Dictionary = rect.get("size", {})
		var center: Vector2 = Vector2(
			float(rect_position.get("x", 0.0)) + float(rect_size.get("x", 0.0)) * 0.5,
			float(rect_position.get("y", 0.0)) + float(rect_size.get("y", 0.0)) * 0.5
		)
		var mapping: Dictionary = geometry.screen_to_cell(center)
		assert_equal(mapping.get("available"), true, "screen_to_cell should be available for a cell center at %s." % str(cell))
		assert_equal(mapping.get("cell"), {"x": cell.x, "y": cell.y}, "A cell center must round-trip back to its own cell %s." % str(cell))
	# The cells the fit produced are the promised square size.
	var origin_rect: Dictionary = geometry.cell_rect(Vector2i(0, 0))
	assert_equal(origin_rect.get("size"), {"x": 50.0, "y": 50.0}, "The shared geometry cell size should match the fit cell size.")
	assert_equal(origin_rect.get("position"), {"x": 10.0, "y": 20.0}, "The first cell should draw at the fit origin.")


func _out_of_bounds_pixel_is_a_safe_no_op() -> void:
	var fit: TacticalBoardGridFit = TacticalBoardGridFit.from_region(8, 8, {"x": 0.0, "y": 0.0, "width": 800.0, "height": 800.0})
	var geometry: TacticalBoardZoomState = fit.to_zoom_state()
	var before_origin: Dictionary = geometry.screen_to_cell(Vector2(-25.0, 40.0))
	var beyond_grid: Dictionary = geometry.screen_to_cell(Vector2(10000.0, 10000.0))
	assert_equal(before_origin.get("available"), false, "A pixel left/above the grid should be an unavailable mapping.")
	assert_equal(before_origin.get("reason"), "out_of_bounds", "An off-grid pixel should report out_of_bounds.")
	assert_equal(beyond_grid.get("available"), false, "A pixel beyond the grid should be an unavailable mapping.")


func _empty_board_is_unavailable_and_yields_no_geometry() -> void:
	var empty: TacticalBoardGridFit = TacticalBoardGridFit.from_region(0, 0, {"x": 0.0, "y": 0.0, "width": 800.0, "height": 800.0})
	assert_false(empty.available(), "A 0x0 board (the null between-levels board) should be unavailable.")
	assert_equal(empty.reason(), "empty_board", "An empty board should report the empty_board reason.")
	assert_equal(empty.to_zoom_state(), null, "An unavailable fit should hand back no geometry object.")
	assert_equal(empty.cell_size(), 0.0, "An empty board should compute a zero cell size (no divide-by-zero).")
	var zero_region: TacticalBoardGridFit = TacticalBoardGridFit.from_region(8, 8, {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0})
	assert_false(zero_region.available(), "A zero-size region should be unavailable.")
	assert_equal(zero_region.reason(), "invalid_region", "A zero-size region should report invalid_region.")
