class_name RewardTableRepository
extends RefCounted

# The fail-closed REWARD-TABLE content repository (Story 6.1) — a structure-clone of WeaponRepository /
# ArmorRepository. Holds a ContentRepository, registers the approved baseline reward-table definitions, and
# resolves a table id to its typed RewardTableDefinition via get_reward_table(id) — null on a miss (fail-closed;
# collision-free accessor name). A second registration under an already-present id fails loud with
# duplicate_reward_table (the central duplicate-id guard, surfaced per-type — Story 6.1 AC6).
#
# The baseline table references REAL content ids across the categories: real WeaponRepository / SupportRepository
# baseline ids + the new armor/jewelry/consumable/pickup/gold-reward baseline ids THIS story authors. The
# references are by-id + category only (RewardTableDefinition.validate() does NOT resolve them against the other
# repositories — resolution is the Story 6.3 offer flow's job); they are kept real so the AC3 offer fixture
# draws a genuine, varied offer.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")

const BASELINE_REWARD_TABLE_IDS: Array[StringName] = [
	&"standard_combat_reward",
	&"elite_combat_reward"
]

var _content_repository: ContentRepository
var _reward_table_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> RewardTableRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> RewardTableRepository:
	var validated_definitions: Array[RewardTableDefinition] = []
	for definition_value: Variant in definitions:
		var definition: RewardTableDefinition = definition_value as RewardTableDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: RewardTableRepository = load("res://scripts/content/repositories/reward_table_repository.gd").new(content_repository)
	for definition: RewardTableDefinition in validated_definitions:
		var result: ActionResult = repository.register_reward_table(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_reward_tables() -> ActionResult:
	for definition: RewardTableDefinition in _baseline_definitions():
		var result: ActionResult = register_reward_table(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_reward_table(definition: RewardTableDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_reward_table")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(RewardTableDefinition.DEFINITION_TYPE, definition.table_id, definition)
	if registration.is_error():
		return _duplicate(definition.table_id)
	if not _reward_table_order.has(definition.table_id):
		_reward_table_order.append(definition.table_id)
	return ActionResult.ok([], {
		"table_id": String(definition.table_id)
	})


func get_reward_table(table_id: StringName) -> RewardTableDefinition:
	return _content_repository.get_definition(RewardTableDefinition.DEFINITION_TYPE, table_id) as RewardTableDefinition


func has_reward_table(table_id: StringName) -> bool:
	return _content_repository.has_definition(RewardTableDefinition.DEFINITION_TYPE, table_id)


func reward_table_ids() -> Array[StringName]:
	return _reward_table_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[RewardTableDefinition]:
	return [
		RewardTableDefinition.new(
			&"standard_combat_reward",
			[
				{"category": RewardTableDefinition.CATEGORY_WEAPON, "content_id": &"sword", "weight": 3},
				{"category": RewardTableDefinition.CATEGORY_ARMOR, "content_id": &"padded_vest", "weight": 3},
				{"category": RewardTableDefinition.CATEGORY_SUPPORT, "content_id": &"shield", "weight": 2},
				{"category": RewardTableDefinition.CATEGORY_CONSUMABLE, "content_id": &"minor_healing_draught", "weight": 4},
				{"category": RewardTableDefinition.CATEGORY_PICKUP, "content_id": &"health_morsel", "weight": 2},
				{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse", "weight": 5}
			]
		),
		RewardTableDefinition.new(
			&"elite_combat_reward",
			[
				{"category": RewardTableDefinition.CATEGORY_WEAPON, "content_id": &"crossbow", "weight": 2},
				{"category": RewardTableDefinition.CATEGORY_ARMOR, "content_id": &"warded_plate", "weight": 2},
				{"category": RewardTableDefinition.CATEGORY_JEWELRY, "content_id": &"sealbearers_signet", "weight": 2},
				{"category": RewardTableDefinition.CATEGORY_CONSUMABLE, "content_id": &"ember_flask", "weight": 3},
				{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"large_gold_purse", "weight": 3}
			]
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_reward_table_repository", {
		"reason": String(reason)
	})


static func _duplicate(table_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_reward_table", {
		"reason": "duplicate_id",
		"id": String(table_id)
	})
