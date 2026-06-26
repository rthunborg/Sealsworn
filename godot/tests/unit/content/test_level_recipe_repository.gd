extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")

const EXPECTED_RECIPES: Dictionary = {
	&"small_combat_basic": {
		"size_class": &"small",
		"is_combat_recipe": true
	},
	&"medium_combat_basic": {
		"size_class": &"medium",
		"is_combat_recipe": true
	}
}

func run() -> Dictionary:
	_baseline_recipes_are_registered_by_stable_id()
	_baseline_recipes_validate_size_classes()
	_baseline_includes_small_and_medium_combat_recipes()
	_recipe_repository_keeps_generic_content_registration_intact()
	_recipe_repository_factory_fails_closed_on_invalid_definitions()
	_register_recipe_rejects_null_definition()
	_recipe_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_recipes_are_registered_by_stable_id() -> void:
	var repository: LevelRecipeRepository = LevelRecipeRepository.create_baseline_repository()
	var actual_ids: Array[StringName] = repository.recipe_ids()

	assert_equal(actual_ids, EXPECTED_RECIPES.keys(), "Baseline recipe ids should be stable and ordered.")
	assert_equal(actual_ids, LevelRecipeRepository.BASELINE_RECIPE_IDS, "Baseline recipe ids should match the named constant order.")
	for recipe_id: StringName in EXPECTED_RECIPES.keys():
		var definition: LevelRecipeDefinition = repository.get_recipe(recipe_id)
		assert_true(definition != null, "Baseline recipe %s should be available through the repository." % String(recipe_id))
		assert_true(repository.has_recipe(recipe_id), "Repository should report having baseline recipe %s." % String(recipe_id))


func _baseline_recipes_validate_size_classes() -> void:
	var repository: LevelRecipeRepository = LevelRecipeRepository.create_baseline_repository()

	for recipe_id: StringName in EXPECTED_RECIPES.keys():
		var definition: LevelRecipeDefinition = repository.get_recipe(recipe_id)
		var expected: Dictionary = EXPECTED_RECIPES[recipe_id]
		var validation: ActionResult = definition.validate()

		assert_true(validation.succeeded, "Baseline recipe %s should validate." % String(recipe_id))
		assert_equal(definition.recipe_id, recipe_id, "Recipe ids should use lower snake StringName values.")
		assert_equal(definition.size_class, expected.get("size_class"), "Recipe %s should expose its size class." % String(recipe_id))
		assert_equal(definition.is_combat_recipe, expected.get("is_combat_recipe"), "Recipe %s should expose its combat flag." % String(recipe_id))
		assert_true(definition.min_tactical_wrinkles >= 1, "Combat recipe %s should require at least one tactical wrinkle." % String(recipe_id))


func _baseline_includes_small_and_medium_combat_recipes() -> void:
	var repository: LevelRecipeRepository = LevelRecipeRepository.create_baseline_repository()
	var size_classes: Array[StringName] = []
	for recipe_id: StringName in repository.recipe_ids():
		size_classes.append(repository.get_recipe(recipe_id).size_class)

	assert_true(size_classes.has(LevelRecipeDefinition.SIZE_SMALL), "Baseline recipes should include at least one Small combat recipe for Story 3.2.")
	assert_true(size_classes.has(LevelRecipeDefinition.SIZE_MEDIUM), "Baseline recipes should include at least one Medium combat recipe for Story 3.3.")


func _recipe_repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: LevelRecipeRepository = LevelRecipeRepository.create_baseline_repository(content_repository)

	for recipe_id: StringName in EXPECTED_RECIPES.keys():
		assert_true(
			content_repository.has_definition(LevelRecipeDefinition.DEFINITION_TYPE, recipe_id),
			"Recipe %s should be registered through the generic content repository boundary." % String(recipe_id)
		)
		assert_equal(
			content_repository.get_definition(LevelRecipeDefinition.DEFINITION_TYPE, recipe_id),
			repository.get_recipe(recipe_id),
			"Recipe %s should not require direct gameplay file access." % String(recipe_id)
		)
	assert_equal(repository.content_repository(), content_repository, "Repository should expose the shared content repository boundary.")


func _recipe_repository_factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: LevelRecipeDefinition = LevelRecipeDefinition.new()
	var repository: LevelRecipeRepository = LevelRecipeRepository.create_repository_from_definitions([invalid_definition])

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: LevelRecipeDefinition = LevelRecipeRepository._baseline_definitions()[0]
	var partial_repository: LevelRecipeRepository = LevelRecipeRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition],
		shared_content_repository
	)

	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered recipe content.")
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(LevelRecipeDefinition.DEFINITION_TYPE, valid_definition.recipe_id),
		"Failed recipe repository creation must not mutate a provided content repository."
	)


func _register_recipe_rejects_null_definition() -> void:
	var repository: LevelRecipeRepository = LevelRecipeRepository.new()
	var result_value: ActionResult = repository.register_recipe(null)
	assert_true(result_value.is_error(), "Registering a null recipe should fail.")
	assert_equal(result_value.error_code, &"invalid_level_recipe_repository", "Null recipe registration should use the stable repository error code.")
	assert_true(repository.recipe_ids().is_empty(), "A failed registration should not add a recipe id.")


# Story 6.1 AC6 — a SECOND registration under an already-present recipe id fails loud with a structured
# duplicate_level_recipe error, leaving recipe_ids() + get_recipe consistent. A duplicate in a batch fails
# closed.
func _recipe_repository_rejects_duplicate_id_fail_loud() -> void:
	var first: LevelRecipeDefinition = _minimal_recipe(0.22)
	var duplicate: LevelRecipeDefinition = _minimal_recipe(0.40)
	var repository: LevelRecipeRepository = LevelRecipeRepository.new()
	assert_true(repository.register_recipe(first).succeeded, "The first recipe registration should succeed.")
	var duplicate_result: ActionResult = repository.register_recipe(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same recipe id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_level_recipe", "A duplicate id should use the stable duplicate_level_recipe code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "small_combat_basic", "The duplicate error should carry the offending id.")
	assert_equal(repository.recipe_ids(), [&"small_combat_basic"] as Array[StringName], "recipe_ids() must keep the id exactly once after a rejected duplicate.")
	assert_true(is_equal_approx(repository.get_recipe(&"small_combat_basic").wall_density, 0.22), "get_recipe must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: LevelRecipeRepository = LevelRecipeRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")


func _minimal_recipe(wall_density: float) -> LevelRecipeDefinition:
	return LevelRecipeDefinition.new(
		&"small_combat_basic",
		LevelRecipeDefinition.SIZE_SMALL,
		true,
		wall_density,
		2,
		5,
		2,
		4,
		0,
		1,
		false,
		1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT],
		"Minimal valid combat recipe for the duplicate-id negative."
	)
