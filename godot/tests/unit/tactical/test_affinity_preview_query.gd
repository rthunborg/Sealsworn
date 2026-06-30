extends "res://tests/unit/test_case.gd"

# Story 7.5 Task 5 — affinity preview explainability + accessibility (AC1, AC2). These prove the AffinityPreviewQuery is
# the PURE, explainable, color-independent preview surface for affinity tactical pressure:
#   - PURE: repeated previews from the same board are byte-identical; building a preview mutates NO board state and
#     emits NO events (the Epic-1 attack-preview contract).
#   - EXPLAINABLE (AC1): the preview surfaces the affinity-affected cells + a readable explanation + the cue ids.
#   - NON-COLOR-ONLY (AC2): every cue id the preview surfaces has a non-color accessibility mapping in the canonical
#     TacticalAccessibilityModel cue catalog (the color-independence audit driver).
#   - NEUTRAL: a neutral / unknown / Cursed affinity preview is a legal EMPTY-effect preview (a valid, readable answer
#     — there is no affinity pressure to show).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityPreviewQuery = preload("res://scripts/tactical/targeting/affinity_preview_query.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const TacticalAccessibilityModel = preload("res://scripts/ui/view_models/tactical_accessibility_model.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

func run() -> Dictionary:
	_repeated_previews_are_identical()
	_preview_does_not_mutate_the_board()
	_preview_emits_no_events()
	_scorched_preview_is_explainable()
	_every_surfaced_cue_has_a_non_color_mapping()
	_neutral_preview_is_a_legal_empty_effect_preview()
	_invalid_board_is_rejected()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


func _floor_board(width: int = 5, height: int = 4) -> BoardState:
	var board: BoardState = BoardState.new()
	var create: ActionResult = CreateBoardCommand.new(width, height).execute(board)
	assert_true(create.succeeded, "Setup: the fixture board should create.")
	_place(board, _player(&"hero", Vector2i(0, 1)))
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


# ---- purity --------------------------------------------------------------------------------------

func _repeated_previews_are_identical() -> void:
	var board: BoardState = _floor_board()
	var query: AffinityPreviewQuery = AffinityPreviewQuery.new()
	var first: Dictionary = query.preview_board(board, &"scorched", _repository()).metadata
	var second: Dictionary = query.preview_board(board, &"scorched", _repository()).metadata
	assert_equal(first, second, "Repeated previews from the same board are byte-identical (preview is pure).")


func _preview_does_not_mutate_the_board() -> void:
	var board: BoardState = _floor_board()
	var before: Array = _board_terrain_snapshot(board)
	# Preview both a board-mutating affinity (Scorched) and a data-only one (Flooded). Neither must change the board.
	AffinityPreviewQuery.new().preview_board(board, &"scorched", _repository())
	AffinityPreviewQuery.new().preview_board(board, &"flooded_conductive", _repository())
	assert_equal(_board_terrain_snapshot(board), before, "Building an affinity preview must NOT mutate the board (no hazard stamped — preview is pure).")


func _preview_emits_no_events() -> void:
	var board: BoardState = _floor_board()
	var result_value: ActionResult = AffinityPreviewQuery.new().preview_board(board, &"scorched", _repository())
	assert_true(result_value.succeeded, "The preview should succeed.")
	assert_false(result_value.has_events(), "Building an affinity preview must emit ZERO events (preview is pure).")


# ---- explainability (AC1) ------------------------------------------------------------------------

func _scorched_preview_is_explainable() -> void:
	var board: BoardState = _floor_board()
	var metadata: Dictionary = AffinityPreviewQuery.new().preview_board(board, &"scorched", _repository()).metadata
	assert_equal(String(metadata.get("kind")), "affinity_preview", "The preview identifies its kind.")
	assert_true(bool(metadata.get("has_effects")), "AC1: the Scorched preview reports effects.")
	assert_false((metadata.get("hazard_cells", []) as Array).is_empty(), "AC1: the preview lists the affected hazard cells.")
	assert_false(String(metadata.get("explanation", "")).is_empty(), "AC1: the preview surfaces a readable explanation.")
	assert_false((metadata.get("warnings", []) as Array).is_empty(), "AC1: the preview surfaces a readable warning.")


func _every_surfaced_cue_has_a_non_color_mapping() -> void:
	for affinity_id: StringName in [&"scorched", &"flooded_conductive"]:
		var metadata: Dictionary = AffinityPreviewQuery.new().preview_board(_floor_board(), affinity_id, _repository()).metadata
		var cue_ids: Array = metadata.get("cue_ids", [])
		assert_false(cue_ids.is_empty(), "%s should surface at least one cue id." % String(affinity_id))
		for cue_id_value: Variant in cue_ids:
			assert_true(TacticalAccessibilityModel.has_non_color_channel(String(cue_id_value)), "AC2: %s cue '%s' must have a non-color accessibility mapping." % [String(affinity_id), String(cue_id_value)])


# ---- neutral / invalid ---------------------------------------------------------------------------

func _neutral_preview_is_a_legal_empty_effect_preview() -> void:
	for affinity_id: StringName in [AffinityDefinition.AFFINITY_NONE, &"cursed", &"darkness", &"unknown_id"]:
		var result_value: ActionResult = AffinityPreviewQuery.new().preview_board(_floor_board(), affinity_id, _repository())
		assert_true(result_value.succeeded, "%s preview is a legal (succeeded) preview." % String(affinity_id))
		assert_false(bool(result_value.metadata.get("has_effects")), "%s preview reports NO effects (a valid empty-effect answer)." % String(affinity_id))
		assert_true((result_value.metadata.get("cue_ids", []) as Array).is_empty(), "%s preview surfaces no cue ids." % String(affinity_id))


func _invalid_board_is_rejected() -> void:
	var result_value: ActionResult = AffinityPreviewQuery.new().preview_board(null, &"scorched", _repository())
	assert_true(result_value.is_error(), "A null board is rejected.")
	assert_equal(String(result_value.metadata.get("reason")), "invalid_board", "The reject names the invalid-board reason.")
