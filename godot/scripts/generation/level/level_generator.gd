class_name LevelGenerator
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")

# Phased generation entry point for Epic 3. Stories 3.2-3.6 extend it into the full pipeline
# (route -> recipe -> layout -> pathing -> blockers -> hazards -> enemies -> rewards -> affinity ->
# validation -> final snapshot). It currently fires:
#   - recipe (Story 3.1): validate the request, resolve the recipe THROUGH the repository boundary
#     (AC3 — no raw file read, no hardcoded source), structured error on failure.
#   - layout (Stories 3.2 + 3.3): for a Small recipe, run the deterministic Small layout phase; for a
#     Medium recipe, run the deterministic Medium layout phase PLUS the AC2 readability validation.
#     Both return a REAL board payload (board snapshot validated through the strict
#     BoardState.try_from_snapshot path). Layout-construction failures report against PHASE_LAYOUT;
#     AC2 readability rejections report against PHASE_VALIDATION.
static func generate(request: GenerationRequest, recipe_repository: LevelRecipeRepository) -> GenerationResult:
	var seed_text: String = _seed_text(request)

	if request == null:
		return GenerationResult.error(
			GenerationResult.PHASE_RECIPE,
			&"invalid_generation_request",
			&"missing_request",
			seed_text,
			{}
		)

	# Request validation is part of the recipe-selection seam this story.
	var validation: ActionResult = request.validate()
	if validation.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_RECIPE,
			validation.error_code,
			&"request_validation_failed",
			seed_text,
			validation.metadata.duplicate(true)
		)

	# AC3: resolve the recipe through the repository boundary, never a raw file read.
	var recipe: LevelRecipeDefinition = null
	if recipe_repository != null:
		recipe = recipe_repository.get_recipe(request.recipe_id)
	if recipe == null:
		return GenerationResult.error(
			GenerationResult.PHASE_RECIPE,
			&"unknown_level_recipe",
			&"recipe_not_registered",
			seed_text,
			{"recipe_id": String(request.recipe_id)}
		)

	# Layout phase (Stories 3.2 + 3.3): dispatch on the resolved recipe size class. Small runs the
	# Small layout phase (Story 3.2); Medium runs the Medium layout phase + AC2 readability validation
	# (Story 3.3). A size class that is neither (NOT reachable for valid requests today — validate()
	# only allows small/medium) returns a clearly-marked structured note rather than crashing.
	if recipe.size_class == LevelRecipeDefinition.SIZE_SMALL:
		return _run_small_layout_phase(request, recipe, seed_text)
	if recipe.size_class == LevelRecipeDefinition.SIZE_MEDIUM:
		return _run_medium_layout_phase(request, recipe, seed_text)

	return GenerationResult.error(
		GenerationResult.PHASE_LAYOUT,
		&"unsupported_size_class_for_layout",
		&"size_class_has_no_layout_phase",
		seed_text,
		{"recipe_id": String(recipe.recipe_id), "size_class": String(recipe.size_class)}
	)


# Run the deterministic Small layout phase and assemble the real GenerationResult payload. The
# layout RNG is derived from request.level_seed() via a fresh RngStreamSet — every layout-affecting
# draw routes through the named `level` stream (GenerationRequest.draw_layout_int/float). Any failure
# in the layout or board-conversion phase returns a structured GenerationResult.error against
# PHASE_LAYOUT (AC4 discipline carried from Story 3.1).
static func _run_small_layout_phase(request: GenerationRequest, recipe: LevelRecipeDefinition, seed_text: String) -> GenerationResult:
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()

	var layout_result: ActionResult = generator.generate_layout(request, recipe, streams)
	if layout_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_LAYOUT,
			layout_result.error_code,
			&"layout_generation_failed",
			seed_text,
			layout_result.metadata.duplicate(true)
		)
	var layout: Dictionary = layout_result.metadata.get("layout")

	var board_result: ActionResult = generator.build_board_snapshot(layout)
	if board_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_LAYOUT,
			board_result.error_code,
			&"board_conversion_failed",
			seed_text,
			board_result.metadata.duplicate(true)
		)
	var board_snapshot: Dictionary = board_result.metadata.get("board_snapshot")

	# Pure serializable payload (no BoardState/RefCounted/scene refs): the converted board snapshot
	# plus entrance/exit/size_class/recipe_id and the `level`-seed string for traceability. Survives
	# a JSON.stringify/parse_string round-trip and re-converts via BoardState.try_from_snapshot.
	var payload: Dictionary = {
		"board": board_snapshot,
		"entrance": layout.get("entrance").duplicate(true),
		"exit": layout.get("exit").duplicate(true),
		"blockers": layout.get("blockers").duplicate(true),
		"size_class": String(recipe.size_class),
		"recipe_id": String(recipe.recipe_id),
		"level_seed": seed_text
	}
	return GenerationResult.ok(payload, {
		"phase": String(GenerationResult.PHASE_LAYOUT),
		"recipe_id": String(recipe.recipe_id),
		"size_class": String(recipe.size_class),
		"blocker_count": layout.get("blockers").size()
	})


# Run the deterministic Medium layout phase (Story 3.3): generate the layout, run the AC2 readability
# validation, convert to a board snapshot, and assemble the real GenerationResult payload. The layout
# RNG is derived from request.level_seed() via a fresh RngStreamSet — every layout-affecting draw
# routes through the named `level` stream (GenerationRequest.draw_layout_int/float). Layout-construction
# or board-conversion failures report against PHASE_LAYOUT; AC2 readability rejections report against
# PHASE_VALIDATION (carrying the validator's compact diagnostics).
static func _run_medium_layout_phase(request: GenerationRequest, recipe: LevelRecipeDefinition, seed_text: String) -> GenerationResult:
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()

	var layout_result: ActionResult = generator.generate_layout(request, recipe, streams)
	if layout_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_LAYOUT,
			layout_result.error_code,
			&"layout_generation_failed",
			seed_text,
			layout_result.metadata.duplicate(true)
		)
	var layout: Dictionary = layout_result.metadata.get("layout")

	# AC2 readability validation (excessive blockage / unreachable exit / unreadable first reveal).
	# A rejection is reported against PHASE_VALIDATION with the validator's compact diagnostics.
	var readability_result: ActionResult = generator.validate_readability(layout)
	if readability_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_VALIDATION,
			readability_result.error_code,
			&"readability_validation_failed",
			seed_text,
			readability_result.metadata.duplicate(true)
		)

	var board_result: ActionResult = generator.build_board_snapshot(layout)
	if board_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_LAYOUT,
			board_result.error_code,
			&"board_conversion_failed",
			seed_text,
			board_result.metadata.duplicate(true)
		)
	var board_snapshot: Dictionary = board_result.metadata.get("board_snapshot")

	# Pure serializable payload (no BoardState/RefCounted/scene refs): the converted board snapshot
	# plus entrance/exit/size_class/recipe_id and the `level`-seed string for traceability. Survives a
	# JSON.stringify/parse_string round-trip and re-converts via BoardState.try_from_snapshot. Same
	# shape as the Small payload.
	var payload: Dictionary = {
		"board": board_snapshot,
		"entrance": layout.get("entrance").duplicate(true),
		"exit": layout.get("exit").duplicate(true),
		"blockers": layout.get("blockers").duplicate(true),
		"size_class": String(recipe.size_class),
		"recipe_id": String(recipe.recipe_id),
		"level_seed": seed_text
	}
	# A successful Medium generation passed both the layout phase and the AC2 readability pass; report
	# the validation phase as the best descriptor of a fully-checked Medium level.
	return GenerationResult.ok(payload, {
		"phase": String(GenerationResult.PHASE_VALIDATION),
		"recipe_id": String(recipe.recipe_id),
		"size_class": String(recipe.size_class),
		"blocker_count": layout.get("blockers").size()
	})


static func _seed_text(request: GenerationRequest) -> String:
	if request == null:
		return ""
	return str(request.level_seed())
