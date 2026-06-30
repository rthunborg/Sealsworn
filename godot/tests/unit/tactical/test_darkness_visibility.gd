extends "res://tests/unit/test_case.gd"

# Story 7.6 Tasks 1 + 2 — the Darkness visibility/memory-pressure LAYER (the NEW home for Darkness's effect; NOT the 7.5
# hazard resolver). These prove the layer is a deterministic, PURE-DOMAIN reduced-LoS effect over a BoardState given an
# assigned affinity:
#   - REDUCED VISIBILITY (AC1): Darkness exposes a reduced LoS radius (bounded — never 0, >= the fairness floor); the
#     reduced visible set is a STRICT SUBSET of the baseline-radius visible set (reduced visibility is REAL).
#   - DETERMINISM (AC1/AC3): same (board, Darkness) -> identical reduced radius + identical reduced visible set.
#   - NEUTRAL / non-Darkness: the baseline radius (4) + the baseline visible set + no Darkness cue (the 7.4 AC3 carried
#     forward — Scorched/Flooded/Cursed/none/unknown produce NO Darkness effect).
#   - REUSE, not fork: the reduced visibility flows through the EXISTING TacticalVisibilityQuery.calculate_visible_cells
#     (the radius parameter), so the Darkness visible set == the query's set at the reduced radius (no parallel LoS math).
#   - PURE DOMAIN: the layer mutates no board/scene state; it draws ZERO RNG.
#   - ACCESSIBILITY (AC2): the Darkness cue id(s) have a non-color mapping in TacticalAccessibilityModel._CUE_CATALOG.
#   - THE TWO EXISTING DARKNESS-NO-OP TESTS STAY GREEN (verified here too): the hazard resolver + the hazard preview
#     report NO Darkness board effect — Darkness's effect lives in THIS layer, not there.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityPreviewQuery = preload("res://scripts/tactical/targeting/affinity_preview_query.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const TacticalAccessibilityModel = preload("res://scripts/ui/view_models/tactical_accessibility_model.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")

func run() -> Dictionary:
	_darkness_reduces_the_los_radius_bounded()
	_neutral_and_non_darkness_keep_the_baseline_radius()
	_darkness_marker_drop_is_fail_safe()
	_reduced_radius_is_deterministic()
	_reduced_visible_set_is_a_strict_subset_of_baseline()
	_reduced_visible_set_flows_through_the_existing_query()
	_layer_is_a_pure_domain_function_no_mutation()
	_darkness_cues_have_a_non_color_mapping()
	_existing_darkness_no_op_tests_stay_green()
	_invalid_inputs_are_handled()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


# A large open all-FLOOR board so the baseline radius-4 LoS is NOT clipped by the board edges (then the reduced radius is
# genuinely smaller, not edge-limited to the same set). 11x11 with the origin at the centre (5,5) leaves >4 cells of room
# in every direction.
func _open_board(size: int = 11) -> BoardState:
	var board: BoardState = BoardState.new()
	var create: ActionResult = CreateBoardCommand.new(size, size).execute(board)
	assert_true(create.succeeded, "Setup: the fixture board should create.")
	return board


func _board_terrain_snapshot(board: BoardState) -> Array:
	var result: Array = []
	for board_cell: BoardCell in board.cells():
		result.append([board_cell.position.x, board_cell.position.y, board_cell.terrain, board_cell.visible, board_cell.explored])
	return result


# ---- reduced radius (AC1) ------------------------------------------------------------------------

func _darkness_reduces_the_los_radius_bounded() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var reduced: int = layer.reduced_radius_for(&"darkness", _repository())
	assert_true(layer.is_darkness(&"darkness", _repository()), "Darkness affinity is recognized as active by the layer.")
	assert_true(reduced < TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS, "AC1: Darkness reduces the LoS radius below the baseline 4.")
	assert_true(reduced >= DarknessVisibilityLayer.DARKNESS_RADIUS_FLOOR, "AC1: the reduced radius never drops below the fairness floor (>= 1).")
	assert_true(reduced > 0, "AC1: the reduced radius is never 0 (the hero can always see their own neighbourhood).")
	assert_equal(reduced, DarknessVisibilityLayer.DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS, "The reduced radius is the authored value.")


func _neutral_and_non_darkness_keep_the_baseline_radius() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	for affinity_id: StringName in [AffinityDefinition.AFFINITY_NONE, &"scorched", &"flooded_conductive", &"cursed", &"not_a_real_affinity"]:
		assert_false(layer.is_darkness(affinity_id, _repository()), "%s is NOT a Darkness effect." % String(affinity_id))
		assert_equal(layer.reduced_radius_for(affinity_id, _repository()), TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS, "%s keeps the baseline radius 4 (no Darkness reduction)." % String(affinity_id))


func _darkness_marker_drop_is_fail_safe() -> void:
	# A Darkness-named affinity whose definition carries NO reduced_visibility marker must fail-SAFE to the baseline (the
	# effect rides off the recorded 7.4 marker; a content drop disables it rather than crashing).
	var markerless: AffinityDefinition = AffinityDefinition.new(
		&"darkness",
		"Darkness",
		[],
		[] as Array[StringName],
		"A Darkness affinity with no recorded markers (fail-safe probe)."
	)
	var repo: AffinityRepository = AffinityRepository.create_repository_from_definitions([markerless])
	assert_true(repo != null, "Setup: the markerless-darkness fixture repo should build.")
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	assert_false(layer.is_darkness(&"darkness", repo), "A Darkness affinity missing the reduced_visibility marker is fail-safe (no effect).")
	assert_equal(layer.reduced_radius_for(&"darkness", repo), TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS, "A markerless Darkness affinity keeps the baseline radius.")


func _reduced_radius_is_deterministic() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var first: int = layer.reduced_radius_for(&"darkness", _repository())
	var second: int = layer.reduced_radius_for(&"darkness", _repository())
	assert_equal(first, second, "AC1/AC3: the Darkness reduced radius is deterministic.")


# ---- reduced visible set (AC1, AC2 reuse) --------------------------------------------------------

func _reduced_visible_set_is_a_strict_subset_of_baseline() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = _open_board()
	var origin: Vector2i = Vector2i(5, 5)

	var baseline: ActionResult = query.calculate_visible_cells(board, origin)
	var darkness: ActionResult = layer.calculate_visible_cells(query, board, origin, &"darkness", _repository())
	assert_true(baseline.succeeded and darkness.succeeded, "Both visible-cell calculations should succeed.")

	var baseline_cells: Array = baseline.metadata.get("visible_cells", [])
	var darkness_cells: Array = darkness.metadata.get("visible_cells", [])
	assert_true(darkness_cells.size() < baseline_cells.size(), "AC1: the Darkness visible set is strictly smaller than the baseline-radius set (reduced visibility is real). Baseline=%s Darkness=%s" % [baseline_cells.size(), darkness_cells.size()])
	assert_true(darkness_cells.size() > 0, "AC1: the Darkness visible set is non-empty (the hero still sees their neighbourhood).")
	# Every Darkness-visible cell is also baseline-visible (a strict subset — Darkness never reveals MORE than baseline).
	for cell_value: Variant in darkness_cells:
		assert_true(baseline_cells.has(cell_value), "AC1: every Darkness-visible cell is also baseline-visible (a strict subset).")
	# The reduced radius is reported on the result.
	assert_equal(int(darkness.metadata.get("radius")), layer.reduced_radius_for(&"darkness", _repository()), "The Darkness visible-cell result reports the reduced radius.")


func _reduced_visible_set_flows_through_the_existing_query() -> void:
	# The Darkness visible set MUST equal the existing query's set computed at the reduced radius (reuse, not a fork).
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = _open_board()
	var origin: Vector2i = Vector2i(5, 5)
	var reduced_radius: int = layer.reduced_radius_for(&"darkness", _repository())

	var via_layer: ActionResult = layer.calculate_visible_cells(query, board, origin, &"darkness", _repository())
	var via_query_directly: ActionResult = query.calculate_visible_cells(board, origin, reduced_radius)
	assert_equal(via_layer.metadata.get("visible_cells"), via_query_directly.metadata.get("visible_cells"), "The Darkness visible set reuses the existing LoS query at the reduced radius (no parallel algorithm).")

	# And neutral routes through the query at the baseline radius (byte-identical to a plain baseline query).
	var neutral_via_layer: ActionResult = layer.calculate_visible_cells(query, board, origin, AffinityDefinition.AFFINITY_NONE, _repository())
	var baseline_query: ActionResult = query.calculate_visible_cells(board, origin)
	assert_equal(neutral_via_layer.metadata.get("visible_cells"), baseline_query.metadata.get("visible_cells"), "Neutral routes the layer through the baseline-radius query (byte-identical).")


# ---- purity --------------------------------------------------------------------------------------

func _layer_is_a_pure_domain_function_no_mutation() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	var board: BoardState = _open_board()
	var origin: Vector2i = Vector2i(5, 5)
	var before: Array = _board_terrain_snapshot(board)

	# Run reduced-radius + visible-cell calculations twice; the board must be untouched and the results identical.
	var first: ActionResult = layer.calculate_visible_cells(query, board, origin, &"darkness", _repository())
	var second: ActionResult = layer.calculate_visible_cells(query, board, origin, &"darkness", _repository())
	assert_equal(first.metadata.get("visible_cells"), second.metadata.get("visible_cells"), "The layer is a pure function (same inputs -> identical visible set).")
	assert_false(first.has_events(), "The layer emits ZERO events (pure read).")
	assert_equal(_board_terrain_snapshot(board), before, "The layer mutates NO board/visibility state (pure domain).")


# ---- accessibility (AC2) -------------------------------------------------------------------------

func _darkness_cues_have_a_non_color_mapping() -> void:
	for cue_id: String in [DarknessVisibilityLayer.CUE_DARKNESS_REDUCED_VISIBILITY, DarknessVisibilityLayer.CUE_DARKNESS_MEMORY_UNCERTAIN]:
		assert_true(TacticalAccessibilityModel.has_non_color_channel(cue_id), "AC2: the Darkness cue '%s' must have a non-color accessibility mapping." % cue_id)


# ---- the two existing Darkness-no-op tests stay green (verified here too) -------------------------

func _existing_darkness_no_op_tests_stay_green() -> void:
	# The 7.5 hazard resolver + hazard preview MUST still report NO Darkness board effect — Darkness's effect is a
	# visibility/memory layer, NOT a hazard-cell effect. (These mirror the two pinned tests the story flags.)
	var board: BoardState = _open_board(5)
	var resolver_plan: Dictionary = AffinityEffectResolver.new().resolve_board_plan(board, &"darkness", _repository())
	assert_false(bool(resolver_plan.get("has_effects")), "Darkness still produces NO hazard board effect (the 7.5 resolver no-op stays green).")
	assert_true((resolver_plan.get("cues", []) as Array).is_empty(), "Darkness surfaces no hazard-resolver cues.")
	var preview: ActionResult = AffinityPreviewQuery.new().preview_board(board, &"darkness", _repository())
	assert_true(preview.succeeded, "The Darkness hazard preview is a legal empty-effect preview.")
	assert_false(bool(preview.metadata.get("has_effects")), "Darkness reports NO hazard preview effect (the 7.5 preview no-op stays green).")
	assert_true((preview.metadata.get("cue_ids", []) as Array).is_empty(), "Darkness surfaces no hazard preview cue ids.")


func _invalid_inputs_are_handled() -> void:
	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	var board: BoardState = _open_board(5)
	# A null query fails closed (the layer cannot route to a missing query).
	var null_query: ActionResult = layer.calculate_visible_cells(null, board, Vector2i(2, 2), &"darkness", _repository())
	assert_true(null_query.is_error(), "A null visibility query fails closed.")
	# A null repository fails-safe to neutral (no markers -> not Darkness -> baseline radius).
	assert_false(layer.is_darkness(&"darkness", null), "A null repository fails-safe to NOT Darkness.")
	assert_equal(layer.reduced_radius_for(&"darkness", null), TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS, "A null repository keeps the baseline radius (fail-safe).")
