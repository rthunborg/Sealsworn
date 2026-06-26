class_name GoldRewardRepository
extends RefCounted

# The fail-closed GOLD-REWARD content repository (Story 6.1) — a structure-clone of WeaponRepository /
# ArmorRepository. Holds a ContentRepository, registers the approved baseline gold-reward definitions, and
# resolves a gold-reward id to its typed GoldRewardDefinition via get_gold_reward(id) — null on a miss
# (fail-closed; collision-free accessor name). A second registration under an already-present id fails loud
# with duplicate_gold_reward (the central duplicate-id guard, surfaced per-type — Story 6.1 AC6).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const GoldRewardDefinition = preload("res://scripts/content/definitions/gold_reward_definition.gd")

const BASELINE_GOLD_REWARD_IDS: Array[StringName] = [
	&"small_gold_purse",
	&"large_gold_purse"
]

var _content_repository: ContentRepository
var _gold_reward_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> GoldRewardRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> GoldRewardRepository:
	var validated_definitions: Array[GoldRewardDefinition] = []
	for definition_value: Variant in definitions:
		var definition: GoldRewardDefinition = definition_value as GoldRewardDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: GoldRewardRepository = load("res://scripts/content/repositories/gold_reward_repository.gd").new(content_repository)
	for definition: GoldRewardDefinition in validated_definitions:
		var result: ActionResult = repository.register_gold_reward(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_gold_rewards() -> ActionResult:
	for definition: GoldRewardDefinition in _baseline_definitions():
		var result: ActionResult = register_gold_reward(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_gold_reward(definition: GoldRewardDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_gold_reward")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(GoldRewardDefinition.DEFINITION_TYPE, definition.gold_reward_id, definition)
	if registration.is_error():
		return _duplicate(definition.gold_reward_id)
	if not _gold_reward_order.has(definition.gold_reward_id):
		_gold_reward_order.append(definition.gold_reward_id)
	return ActionResult.ok([], {
		"gold_reward_id": String(definition.gold_reward_id)
	})


func get_gold_reward(gold_reward_id: StringName) -> GoldRewardDefinition:
	return _content_repository.get_definition(GoldRewardDefinition.DEFINITION_TYPE, gold_reward_id) as GoldRewardDefinition


func has_gold_reward(gold_reward_id: StringName) -> bool:
	return _content_repository.has_definition(GoldRewardDefinition.DEFINITION_TYPE, gold_reward_id)


func gold_reward_ids() -> Array[StringName]:
	return _gold_reward_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[GoldRewardDefinition]:
	return [
		GoldRewardDefinition.new(
			&"small_gold_purse",
			5,
			15,
			"A small purse of gold."
		),
		GoldRewardDefinition.new(
			&"large_gold_purse",
			20,
			50,
			"A heavy purse of gold."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_gold_reward_repository", {
		"reason": String(reason)
	})


static func _duplicate(gold_reward_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_gold_reward", {
		"reason": "duplicate_id",
		"id": String(gold_reward_id)
	})
