class_name LevelGenerator
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")

# Minimal recipe-selection seam for Epic 3. This is the entry point Stories 3.2-3.6 extend into
# the full phased generator (layout -> pathing -> blockers -> hazards -> enemies -> rewards ->
# affinity -> validation -> final snapshot). This story only fires the `recipe` phase: it
# validates the request, resolves the recipe THROUGH the repository boundary (AC3 — no raw file
# read, no hardcoded source), and returns a clearly-marked placeholder payload or a structured
# GenerationResult.error. NO real layout/snapshot is produced here.
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

	# Placeholder success payload ONLY. Story 3.2 replaces this with a generated/converted level.
	var payload: Dictionary = {
		"placeholder": true,
		"recipe_id": String(recipe.recipe_id),
		"size_class": String(recipe.size_class)
	}
	return GenerationResult.ok(payload, {
		"phase": String(GenerationResult.PHASE_RECIPE),
		"recipe_id": String(recipe.recipe_id)
	})


static func _seed_text(request: GenerationRequest) -> String:
	if request == null:
		return ""
	return str(request.level_seed())
