extends "res://tests/unit/test_case.gd"

const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")

func run() -> Dictionary:
	_known_recipe_resolves_to_success_placeholder()
	_success_payload_is_clearly_marked_placeholder()
	_unknown_recipe_returns_structured_recipe_phase_error()
	_invalid_request_returns_structured_recipe_phase_error()
	_null_repository_returns_structured_error_without_crash()
	_recipe_is_resolved_through_repository_boundary()
	return result()


func _repository() -> LevelRecipeRepository:
	return LevelRecipeRepository.create_baseline_repository()


func _valid_request(recipe_id: StringName = &"small_combat_basic", size_class: StringName = GenerationRequest.SIZE_SMALL) -> GenerationRequest:
	return GenerationRequest.new(
		1234,
		&"node_1",
		&"combat",
		recipe_id,
		size_class,
		GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE,
		{}
	)


func _known_recipe_resolves_to_success_placeholder() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(), _repository())

	assert_true(result_value.succeeded, "A known recipe should resolve to a successful generation result. Error: %s" % result_value.diagnostics)
	assert_true(result_value.has_payload(), "A successful recipe selection should return a placeholder payload.")
	assert_equal(result_value.payload.get("recipe_id"), "small_combat_basic", "Placeholder payload should echo the resolved recipe id.")
	assert_equal(result_value.payload.get("size_class"), "small", "Placeholder payload should echo the resolved size class.")


func _success_payload_is_clearly_marked_placeholder() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(), _repository())
	# 3.1 returns a placeholder ONLY; layout/snapshot conversion belongs to 3.2+.
	assert_true(result_value.payload.get("placeholder", false), "The 3.1 payload must be clearly marked as a placeholder (no real layout yet).")
	assert_false(result_value.payload.has("board"), "The 3.1 placeholder payload must not contain a generated board.")


func _unknown_recipe_returns_structured_recipe_phase_error() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(&"missing_recipe"), _repository())

	assert_true(result_value.is_error(), "An unknown recipe id should produce an error result.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "An unknown recipe should fail in the recipe phase.")
	assert_equal(result_value.error_code, &"unknown_level_recipe", "An unknown recipe should use the stable error code.")
	assert_true(result_value.reason != &"", "An unknown recipe failure should carry a machine-stable reason.")
	assert_equal(result_value.seed, "1234", "An unknown recipe failure should carry the request seed.")
	assert_equal(result_value.diagnostics.get("recipe_id"), "missing_recipe", "An unknown recipe failure should report the requested recipe id in diagnostics.")
	assert_false(result_value.has_payload(), "An unknown recipe failure should not return a payload.")


func _invalid_request_returns_structured_recipe_phase_error() -> void:
	var invalid_request: GenerationRequest = _valid_request()
	invalid_request.size_class = &"large"
	var result_value: GenerationResult = LevelGenerator.generate(invalid_request, _repository())

	assert_true(result_value.is_error(), "An invalid request should produce an error result.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "An invalid request should fail in the recipe phase this story.")
	assert_equal(result_value.error_code, &"invalid_generation_request", "An invalid request should use the request error code.")
	assert_true(result_value.diagnostics.has("field"), "An invalid request failure should report the offending field in diagnostics.")


func _null_repository_returns_structured_error_without_crash() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(), null)
	assert_true(result_value.is_error(), "A null repository should produce a structured error, not a crash.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "A null repository should fail in the recipe phase.")
	assert_equal(result_value.error_code, &"unknown_level_recipe", "A null repository should report the recipe as unresolvable.")


func _recipe_is_resolved_through_repository_boundary() -> void:
	# AC3: the selection seam resolves the recipe through the repository, not a raw file read.
	# A repository whose only registered recipe is custom must resolve THAT recipe (proving lookup
	# goes through the repository boundary, not a hardcoded/baseline source).
	var custom_definition: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"custom_arena",
		LevelRecipeDefinition.SIZE_MEDIUM,
		true,
		0.2,
		1,
		3,
		2,
		4,
		0,
		1,
		false,
		1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT],
		"Custom registered arena used to prove repository-boundary resolution."
	)
	var repository: LevelRecipeRepository = LevelRecipeRepository.create_repository_from_definitions([custom_definition])
	assert_true(repository != null, "Custom recipe repository should build from a valid definition.")

	var resolved: GenerationResult = LevelGenerator.generate(
		_valid_request(&"custom_arena", GenerationRequest.SIZE_MEDIUM),
		repository
	)
	assert_true(resolved.succeeded, "A recipe registered only in this repository should resolve through the repository boundary.")
	assert_equal(resolved.payload.get("recipe_id"), "custom_arena", "Resolution should return the repository-registered recipe.")

	var unresolved: GenerationResult = LevelGenerator.generate(_valid_request(), repository)
	assert_true(unresolved.is_error(), "A baseline recipe not registered in this custom repository must NOT resolve from a raw/hardcoded source.")
