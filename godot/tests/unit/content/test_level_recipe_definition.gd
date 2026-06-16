extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")

func run() -> Dictionary:
	_baseline_small_combat_recipe_validates()
	_baseline_medium_combat_recipe_validates()
	_definition_exposes_required_recipe_fields()
	_validate_rejects_non_lower_snake_recipe_id()
	_validate_rejects_unknown_size_class()
	_validate_rejects_negative_blocker_budget()
	_validate_rejects_inverted_blocker_budget()
	_validate_rejects_negative_enemy_budget()
	_validate_rejects_inverted_enemy_budget()
	_validate_rejects_blank_tactical_identity()
	_validate_rejects_combat_recipe_with_zero_wrinkles()
	_validate_rejects_unknown_wrinkle_kind()
	_validate_rejects_inverted_reward_count_band()
	_validate_rejects_negative_reward_count()
	_validate_rejects_out_of_band_wall_density()
	return result()


func _small_combat_recipe() -> LevelRecipeDefinition:
	return LevelRecipeDefinition.new(
		&"small_combat_basic",
		LevelRecipeDefinition.SIZE_SMALL,
		true,
		0.25,
		2,
		5,
		2,
		4,
		0,
		1,
		false,
		1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT, LevelRecipeDefinition.WRINKLE_BLOCKER_CLUSTER],
		"Compact early combat arena with a single forced engagement."
	)


func _validates(definition: LevelRecipeDefinition, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.succeeded, "%s Validation error: %s" % [message, validation.metadata])


func _rejects_field(definition: LevelRecipeDefinition, expected_field: StringName, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), message)
	assert_equal(validation.error_code, &"invalid_level_recipe_definition", "%s should use the stable definition error code." % message)
	assert_equal(validation.metadata.get("reason"), "invalid_field", "%s should report an invalid field." % message)
	assert_equal(validation.metadata.get("field"), String(expected_field), "%s should name the offending field." % message)


func _baseline_small_combat_recipe_validates() -> void:
	_validates(_small_combat_recipe(), "Baseline small combat recipe should validate.")


func _baseline_medium_combat_recipe_validates() -> void:
	var definition: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"medium_combat_basic",
		LevelRecipeDefinition.SIZE_MEDIUM,
		true,
		0.30,
		3,
		8,
		3,
		6,
		1,
		2,
		true,
		2,
		[
			LevelRecipeDefinition.WRINKLE_CHOKE_POINT,
			LevelRecipeDefinition.WRINKLE_FLANK_ROUTE,
			LevelRecipeDefinition.WRINKLE_HAZARD
		],
		"Mid-run combat space with flank routes and a hazard pocket."
	)
	_validates(definition, "Baseline medium combat recipe should validate.")


func _definition_exposes_required_recipe_fields() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	assert_equal(definition.recipe_id, &"small_combat_basic", "Recipe should expose its stable id.")
	assert_equal(definition.size_class, LevelRecipeDefinition.SIZE_SMALL, "Recipe should expose its size class.")
	assert_equal(definition.blocker_budget_min, 2, "Recipe should expose its minimum blocker budget.")
	assert_equal(definition.blocker_budget_max, 5, "Recipe should expose its maximum blocker budget.")
	assert_equal(definition.enemy_budget_min, 2, "Recipe should expose its minimum enemy budget.")
	assert_equal(definition.enemy_budget_max, 4, "Recipe should expose its maximum enemy budget.")
	assert_equal(definition.min_tactical_wrinkles, 1, "Recipe should expose the minimum tactical wrinkle requirement.")
	assert_true(definition.is_combat_recipe, "A combat recipe should report itself as combat.")
	assert_equal(definition.allowed_wrinkle_kinds.size(), 2, "Recipe should expose the allowed wrinkle-kind allowlist.")

	var terrain_rules: Dictionary = definition.terrain_rules()
	assert_true(terrain_rules.has("wall_density"), "Recipe terrain rules should expose wall density.")
	assert_true(terrain_rules.has("allow_blockers"), "Recipe terrain rules should expose the blocker flag.")

	var reward_rules: Dictionary = definition.reward_placement_rules()
	assert_true(reward_rules.has("reward_count_min"), "Recipe reward rules should expose the minimum reward count.")
	assert_true(reward_rules.has("reward_count_max"), "Recipe reward rules should expose the maximum reward count.")
	assert_true(reward_rules.has("allow_reward_behind_danger"), "Recipe reward rules should expose the behind-danger flag.")


func _validate_rejects_non_lower_snake_recipe_id() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.recipe_id = &"Small Combat"
	_rejects_field(definition, &"recipe_id", "Recipe with a non-lower-snake id should be rejected.")


func _validate_rejects_unknown_size_class() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.size_class = &"large"
	_rejects_field(definition, &"size_class", "Recipe with a deferred Large size class should be rejected.")


func _validate_rejects_negative_blocker_budget() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.blocker_budget_min = -1
	_rejects_field(definition, &"blocker_budget_min", "Recipe with a negative blocker budget should be rejected.")


func _validate_rejects_inverted_blocker_budget() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.blocker_budget_min = 5
	definition.blocker_budget_max = 2
	_rejects_field(definition, &"blocker_budget_max", "Recipe with min > max blocker budget should be rejected.")


func _validate_rejects_negative_enemy_budget() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.enemy_budget_min = -2
	_rejects_field(definition, &"enemy_budget_min", "Recipe with a negative enemy budget should be rejected.")


func _validate_rejects_inverted_enemy_budget() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.enemy_budget_min = 4
	definition.enemy_budget_max = 2
	_rejects_field(definition, &"enemy_budget_max", "Recipe with min > max enemy budget should be rejected.")


func _validate_rejects_blank_tactical_identity() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.tactical_identity = "   "
	_rejects_field(definition, &"tactical_identity", "Recipe with a blank tactical identity should be rejected.")


func _validate_rejects_combat_recipe_with_zero_wrinkles() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.min_tactical_wrinkles = 0
	_rejects_field(definition, &"min_tactical_wrinkles", "A combat recipe requiring zero tactical wrinkles should be rejected.")


func _validate_rejects_unknown_wrinkle_kind() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.allowed_wrinkle_kinds = [&"teleporter"]
	_rejects_field(definition, &"allowed_wrinkle_kinds", "Recipe with a wrinkle kind outside the allowlist should be rejected.")


func _validate_rejects_inverted_reward_count_band() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.reward_count_min = 2
	definition.reward_count_max = 1
	_rejects_field(definition, &"reward_count_max", "Recipe with min > max reward count should be rejected.")


func _validate_rejects_negative_reward_count() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.reward_count_min = -1
	_rejects_field(definition, &"reward_count_min", "Recipe with a negative reward count should be rejected.")


func _validate_rejects_out_of_band_wall_density() -> void:
	var definition: LevelRecipeDefinition = _small_combat_recipe()
	definition.wall_density = 1.5
	_rejects_field(definition, &"wall_density", "Recipe with an out-of-band wall density should be rejected.")
