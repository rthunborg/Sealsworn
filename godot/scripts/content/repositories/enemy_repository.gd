class_name EnemyRepository
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const EnemyDefinition = preload("res://scripts/content/definitions/enemy_definition.gd")

const BASELINE_ENEMY_IDS: Array[StringName] = [
	&"iron_cultist",
	&"gate_brute",
	&"ash_seer"
]

var _content_repository: ContentRepository
var _enemy_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> EnemyRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> EnemyRepository:
	var validated_definitions: Array[EnemyDefinition] = []
	for definition_value: Variant in definitions:
		var definition: EnemyDefinition = definition_value as EnemyDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: EnemyRepository = load("res://scripts/content/repositories/enemy_repository.gd").new(content_repository)
	for definition: EnemyDefinition in validated_definitions:
		var result: ActionResult = repository.register_enemy(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_enemies() -> ActionResult:
	for definition: EnemyDefinition in _baseline_definitions():
		var result: ActionResult = register_enemy(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_enemy(definition: EnemyDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_enemy")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(EnemyDefinition.DEFINITION_TYPE, definition.enemy_id, definition)
	if registration.is_error():
		return _duplicate(definition.enemy_id)
	if not _enemy_order.has(definition.enemy_id):
		_enemy_order.append(definition.enemy_id)
	return ActionResult.ok([], {
		"enemy_id": String(definition.enemy_id)
	})


func get_enemy(enemy_id: StringName) -> EnemyDefinition:
	return _content_repository.get_definition(EnemyDefinition.DEFINITION_TYPE, enemy_id) as EnemyDefinition


func has_enemy(enemy_id: StringName) -> bool:
	return _content_repository.has_definition(EnemyDefinition.DEFINITION_TYPE, enemy_id)


func enemy_ids() -> Array[StringName]:
	return _enemy_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[EnemyDefinition]:
	return [
		EnemyDefinition.new(
			&"iron_cultist",
			10,
			EnemyDefinition.BEHAVIOR_MELEE_PRESSURE,
			true,
			1,
			1,
			3,
			EnemyDefinition.DAMAGE_TYPE_PHYSICAL,
			0,
			false,
			0,
			EnemyDefinition.DAMAGE_TYPE_PHYSICAL,
			"Advances toward the player and deals physical damage when adjacent."
		),
		EnemyDefinition.new(
			&"gate_brute",
			12,
			EnemyDefinition.BEHAVIOR_MELEE_PRESSURE,
			true,
			1,
			1,
			3,
			EnemyDefinition.DAMAGE_TYPE_PHYSICAL,
			0,
			false,
			0,
			EnemyDefinition.DAMAGE_TYPE_PHYSICAL,
			"Heavier blocking melee body with the same prototype pressure behavior."
		),
		EnemyDefinition.new(
			&"ash_seer",
			8,
			EnemyDefinition.BEHAVIOR_SEER_MARK,
			true,
			0,
			0,
			0,
			EnemyDefinition.DAMAGE_TYPE_PHYSICAL,
			5,
			true,
			4,
			EnemyDefinition.DAMAGE_TYPE_PHYSICAL,
			"Marks the player's tile from range, then detonates it on a later enemy turn."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_enemy_repository", {
		"reason": String(reason)
	})


static func _duplicate(enemy_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_enemy", {
		"reason": "duplicate_id",
		"id": String(enemy_id)
	})
