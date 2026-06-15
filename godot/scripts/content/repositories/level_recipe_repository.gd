class_name LevelRecipeRepository
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")

const BASELINE_RECIPE_IDS: Array[StringName] = [
	&"small_combat_basic",
	&"medium_combat_basic"
]

var _content_repository: ContentRepository
var _recipe_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> LevelRecipeRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> LevelRecipeRepository:
	var validated_definitions: Array[LevelRecipeDefinition] = []
	for definition_value: Variant in definitions:
		var definition: LevelRecipeDefinition = definition_value as LevelRecipeDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: LevelRecipeRepository = load("res://scripts/content/repositories/level_recipe_repository.gd").new(content_repository)
	for definition: LevelRecipeDefinition in validated_definitions:
		var result: ActionResult = repository.register_recipe(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_recipes() -> ActionResult:
	for definition: LevelRecipeDefinition in _baseline_definitions():
		var result: ActionResult = register_recipe(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_recipe(definition: LevelRecipeDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_recipe")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	_content_repository.register_definition(LevelRecipeDefinition.DEFINITION_TYPE, definition.recipe_id, definition)
	if not _recipe_order.has(definition.recipe_id):
		_recipe_order.append(definition.recipe_id)
	return ActionResult.ok([], {
		"recipe_id": String(definition.recipe_id)
	})


func get_recipe(recipe_id: StringName) -> LevelRecipeDefinition:
	return _content_repository.get_definition(LevelRecipeDefinition.DEFINITION_TYPE, recipe_id) as LevelRecipeDefinition


func has_recipe(recipe_id: StringName) -> bool:
	return _content_repository.has_definition(LevelRecipeDefinition.DEFINITION_TYPE, recipe_id)


func recipe_ids() -> Array[StringName]:
	return _recipe_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[LevelRecipeDefinition]:
	return [
		LevelRecipeDefinition.new(
			&"small_combat_basic",
			LevelRecipeDefinition.SIZE_SMALL,
			true,
			0.22,
			2,
			5,
			2,
			4,
			0,
			1,
			false,
			1,
			[
				LevelRecipeDefinition.WRINKLE_CHOKE_POINT,
				LevelRecipeDefinition.WRINKLE_BLOCKER_CLUSTER
			],
			"Compact early-run combat arena (~8x8) with a forced engagement and light cover."
		),
		LevelRecipeDefinition.new(
			&"medium_combat_basic",
			LevelRecipeDefinition.SIZE_MEDIUM,
			true,
			0.28,
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
				LevelRecipeDefinition.WRINKLE_BLOCKER_CLUSTER,
				LevelRecipeDefinition.WRINKLE_HAZARD,
				LevelRecipeDefinition.WRINKLE_REWARD_BEHIND_DANGER
			],
			"Mid-run combat space (~14x12) with flank routes, a hazard pocket, and a guarded reward."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_level_recipe_repository", {
		"reason": String(reason)
	})
