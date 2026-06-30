extends "res://tests/unit/test_case.gd"

# Story 7.5 Task 3 — Flooded/Conductive effects (AC2, AC4): DETERMINISTIC conductive danger-zone marking + pathing
# pressure, surfaced non-color-only, with a TRACKED MVP placeholder. These prove:
#   - DETERMINISTIC MARKS (AC2): the same board + Flooded affinity yields identical conductive danger-zone + pathing-
#     pressure cells across runs (no RNG).
#   - DATA-ONLY: the marks are board/preview DATA — they do NOT change the terrain enum (no HAZARD/WALL stamped for
#     Flooded; apply_board_effects leaves a Flooded board's terrain untouched).
#   - NON-COLOR-ONLY (AC2 + the Epic-2 accessibility contract): the conductive danger cue + the pathing cue carry a
#     non-color (shape/icon/label/pattern/text) channel in the canonical TacticalAccessibilityModel cue catalog.
#   - PLACEHOLDER (AC4): the conductive danger cue/visual/explanation ids are DISTINCT-from-final (the `_placeholder`
#     marker) so the Epic-10 readiness pass can tell placeholder from final.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityPreviewQuery = preload("res://scripts/tactical/targeting/affinity_preview_query.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const TacticalAccessibilityModel = preload("res://scripts/ui/view_models/tactical_accessibility_model.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

const NON_COLOR_CHANNELS: Array[String] = ["shape", "icon", "label", "pattern", "text"]

func run() -> Dictionary:
	_flooded_marks_conductive_and_pathing_cells_deterministically()
	_flooded_marks_are_data_only_no_terrain_change()
	_conductive_and_pathing_cells_are_disjoint()
	_conductive_danger_cue_is_non_color_only()
	_pathing_pressure_cue_is_non_color_only()
	_conductive_placeholder_ids_are_distinct_from_final()
	_flooded_cells_are_previewable_with_non_color_cues()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


func _floor_board(width: int = 5, height: int = 4) -> BoardState:
	var board: BoardState = BoardState.new()
	var create: ActionResult = CreateBoardCommand.new(width, height).execute(board)
	assert_true(create.succeeded, "Setup: the fixture board should create.")
	_place(board, _player(&"hero", Vector2i(0, 0)))
	_place(board, _enemy_at(&"enemy_1", Vector2i(width - 1, height - 1)))
	return board


func _place(board: BoardState, entity: TacticalEntityState) -> void:
	var place_result: ActionResult = board.place_entity_for_setup(entity)
	assert_true(place_result.succeeded, "Setup: entity placement should succeed.")


func _player(entity_id: StringName, position: Vector2i) -> TacticalEntityState:
	return TacticalEntityState.new(entity_id, TacticalEntityState.EntityType.PLAYER, &"player", position, 18, 18, true)


func _enemy_at(entity_id: StringName, position: Vector2i) -> TacticalEntityState:
	return TacticalEntityState.new(entity_id, TacticalEntityState.EntityType.ENEMY, &"enemy", position, 10, 10, true)


func _board_terrain_snapshot(board: BoardState) -> Array:
	var result: Array = []
	for board_cell: BoardCell in board.cells():
		result.append([board_cell.position.x, board_cell.position.y, board_cell.terrain])
	return result


func _cue_channels(cue_id: String) -> Array:
	var cues: Dictionary = TacticalAccessibilityModel.from_state().to_dictionary().get("cues", {})
	var entry: Dictionary = cues.get(cue_id, {})
	return entry.get("channels", [])


func _has_non_color_channel(channels: Array) -> bool:
	for channel_value: Variant in channels:
		if NON_COLOR_CHANNELS.has(String(channel_value)):
			return true
	return false


# ---- determinism + data-only --------------------------------------------------------------------

func _flooded_marks_conductive_and_pathing_cells_deterministically() -> void:
	var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
	var first: Dictionary = resolver.resolve_board_plan(_floor_board(), &"flooded_conductive", _repository())
	var second: Dictionary = resolver.resolve_board_plan(_floor_board(), &"flooded_conductive", _repository())
	assert_false((first.get("conductive_danger_cells", []) as Array).is_empty(), "Flooded marks conductive danger cells.")
	assert_false((first.get("pathing_pressure_cells", []) as Array).is_empty(), "Flooded marks pathing-pressure cells.")
	assert_equal(first.get("conductive_danger_cells"), second.get("conductive_danger_cells"), "AC2: conductive danger cells are deterministic (same board -> identical marks).")
	assert_equal(first.get("pathing_pressure_cells"), second.get("pathing_pressure_cells"), "AC2: pathing-pressure cells are deterministic (same board -> identical marks).")


func _flooded_marks_are_data_only_no_terrain_change() -> void:
	var board: BoardState = _floor_board()
	var before: Array = _board_terrain_snapshot(board)
	var apply: ActionResult = AffinityEffectResolver.new().apply_board_effects(board, &"flooded_conductive", _repository())
	assert_true(apply.succeeded, "Flooded apply should succeed.")
	assert_true((apply.metadata.get("stamped_hazard_cells", []) as Array).is_empty(), "Flooded stamps NO hazard terrain (its marks are data-only).")
	assert_equal(_board_terrain_snapshot(board), before, "Flooded leaves the board terrain byte-identical (the conductive/pathing marks are preview DATA, not terrain).")


func _conductive_and_pathing_cells_are_disjoint() -> void:
	var plan: Dictionary = AffinityEffectResolver.new().resolve_board_plan(_floor_board(), &"flooded_conductive", _repository())
	var conductive: Dictionary = {}
	for cell_data: Variant in plan.get("conductive_danger_cells", []):
		conductive["%s,%s" % [int((cell_data as Dictionary).get("x")), int((cell_data as Dictionary).get("y"))]] = true
	for cell_data: Variant in plan.get("pathing_pressure_cells", []):
		var key: String = "%s,%s" % [int((cell_data as Dictionary).get("x")), int((cell_data as Dictionary).get("y"))]
		assert_false(conductive.has(key), "A cell is never BOTH a conductive danger cell AND a pathing-pressure cell (distinct deterministic partitions).")


# ---- non-color-only cues (AC2) -------------------------------------------------------------------

func _conductive_danger_cue_is_non_color_only() -> void:
	var channels: Array = _cue_channels("affinity_conductive_danger_placeholder")
	assert_false(channels.is_empty(), "The conductive danger cue must be registered in the accessibility cue catalog.")
	assert_true(_has_non_color_channel(channels), "AC2: the conductive danger cue carries a non-color (shape/icon/label/pattern/text) channel.")
	assert_false(channels.has("color"), "AC2: the conductive danger cue must not rely on a color channel.")


func _pathing_pressure_cue_is_non_color_only() -> void:
	var channels: Array = _cue_channels("affinity_pathing_pressure")
	assert_false(channels.is_empty(), "The pathing-pressure cue must be registered in the accessibility cue catalog.")
	assert_true(_has_non_color_channel(channels), "AC2: the pathing-pressure cue carries a non-color channel.")
	assert_false(channels.has("color"), "AC2: the pathing-pressure cue must not rely on a color channel.")


# ---- placeholder tracking (AC4) ------------------------------------------------------------------

func _conductive_placeholder_ids_are_distinct_from_final() -> void:
	# The conductive cue id, visual id, and explanation are DISTINCT-from-final: they carry the `_placeholder` marker so
	# the Epic-10 readiness pass can tell placeholder from final.
	assert_true(AffinityEffectResolver.CUE_CONDUCTIVE_DANGER_PLACEHOLDER.contains("placeholder"), "AC4: the conductive cue id carries the placeholder marker.")
	assert_true(AffinityEffectResolver.VISUAL_CONDUCTIVE_DANGER_PLACEHOLDER.contains("placeholder"), "AC4: the conductive visual id carries the placeholder marker.")
	assert_true(AffinityEffectResolver.EXPLANATION_CONDUCTIVE_DANGER_PLACEHOLDER.to_lower().contains("placeholder"), "AC4: the conductive explanation marks itself a placeholder.")
	# The Scorched + pathing cue ids are FINAL (no placeholder marker) — only the electric interaction is a placeholder.
	assert_false(AffinityEffectResolver.CUE_SCORCHED_HAZARD.contains("placeholder"), "The Scorched hazard cue is a FINAL id (not a placeholder).")
	assert_false(AffinityEffectResolver.CUE_PATHING_PRESSURE.contains("placeholder"), "The pathing-pressure cue is a FINAL id (not a placeholder).")
	# The cue surfaced in a plan is flagged is_placeholder == true for conductive.
	var plan: Dictionary = AffinityEffectResolver.new().resolve_board_plan(_floor_board(), &"flooded_conductive", _repository())
	var saw_placeholder_flag: bool = false
	for cue_value: Variant in plan.get("cues", []):
		var cue: Dictionary = cue_value
		if String(cue.get("cue_id")) == AffinityEffectResolver.CUE_CONDUCTIVE_DANGER_PLACEHOLDER:
			assert_true(bool(cue.get("is_placeholder")), "AC4: the conductive danger cue is flagged is_placeholder.")
			saw_placeholder_flag = true
	assert_true(saw_placeholder_flag, "AC4: the Flooded plan surfaces the conductive placeholder cue.")


# ---- preview explainability ----------------------------------------------------------------------

func _flooded_cells_are_previewable_with_non_color_cues() -> void:
	var board: BoardState = _floor_board()
	var preview: ActionResult = AffinityPreviewQuery.new().preview_board(board, &"flooded_conductive", _repository())
	assert_true(preview.succeeded, "The Flooded preview should succeed.")
	assert_true(bool(preview.metadata.get("has_effects")), "The Flooded preview reports effects.")
	assert_false((preview.metadata.get("conductive_danger_cells", []) as Array).is_empty(), "AC2: the preview lists the conductive danger cells.")
	assert_false((preview.metadata.get("pathing_pressure_cells", []) as Array).is_empty(), "AC2: the preview lists the pathing-pressure cells.")
	var cue_ids: Array = preview.metadata.get("cue_ids", [])
	assert_true(cue_ids.has("affinity_conductive_danger_placeholder"), "AC2: the preview surfaces the conductive danger cue id.")
	assert_true(cue_ids.has("affinity_pathing_pressure"), "AC2: the preview surfaces the pathing-pressure cue id.")
	# Every surfaced cue id has a non-color accessibility mapping (the Epic-2 contract — no preview cue without one).
	for cue_id_value: Variant in cue_ids:
		assert_true(TacticalAccessibilityModel.has_non_color_channel(String(cue_id_value)), "AC2: preview cue '%s' must have a non-color accessibility mapping." % String(cue_id_value))
