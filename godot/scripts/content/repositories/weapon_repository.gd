class_name WeaponRepository
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

const BASELINE_WEAPON_IDS: Array[StringName] = [
	&"sword",
	&"dagger",
	&"spear",
	&"axe",
	&"mace",
	&"bow",
	&"crossbow",
	&"staff",
	&"wand"
]

var _content_repository: ContentRepository
var _weapon_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> WeaponRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> WeaponRepository:
	var repository: WeaponRepository = load("res://scripts/content/repositories/weapon_repository.gd").new(content_repository)
	for definition_value: Variant in definitions:
		var definition: WeaponDefinition = definition_value as WeaponDefinition
		var result: ActionResult = repository.register_weapon(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_weapons() -> ActionResult:
	for definition: WeaponDefinition in _baseline_definitions():
		var result: ActionResult = register_weapon(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_weapon(definition: WeaponDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_weapon")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(WeaponDefinition.DEFINITION_TYPE, definition.weapon_id, definition)
	if registration.is_error():
		return _duplicate(definition.weapon_id)
	if not _weapon_order.has(definition.weapon_id):
		_weapon_order.append(definition.weapon_id)
	return ActionResult.ok([], {
		"weapon_id": String(definition.weapon_id)
	})


func get_weapon(weapon_id: StringName) -> WeaponDefinition:
	return _content_repository.get_definition(WeaponDefinition.DEFINITION_TYPE, weapon_id) as WeaponDefinition


func has_weapon(weapon_id: StringName) -> bool:
	return _content_repository.has_definition(WeaponDefinition.DEFINITION_TYPE, weapon_id)


func weapon_ids() -> Array[StringName]:
	return _weapon_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[WeaponDefinition]:
	return [
		WeaponDefinition.new(
			&"sword",
			1,
			4,
			WeaponDefinition.TARGETING_ADJACENT_CARDINAL,
			"Reliable melee damage."
		),
		WeaponDefinition.new(
			&"dagger",
			1,
			2,
			WeaponDefinition.TARGETING_ADJACENT_CARDINAL,
			"Low normal damage; future Unseen synergy.",
			WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
			WeaponDefinition.BLOCKER_STANDARD,
			WeaponDefinition.ADJACENCY_NONE,
			1.0,
			&"",
			[&"future_unseen_synergy"]
		),
		WeaponDefinition.new(
			&"spear",
			2,
			3,
			WeaponDefinition.TARGETING_STRAIGHT_LINE,
			"Reach weapon with safer spacing."
		),
		WeaponDefinition.new(
			&"axe",
			1,
			3,
			WeaponDefinition.TARGETING_ADJACENT_CARDINAL,
			"Bleed pressure if the target survives.",
			WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
			WeaponDefinition.BLOCKER_STANDARD,
			WeaponDefinition.ADJACENCY_NONE,
			1.0,
			&"",
			[&"bleed_if_survives_35"]
		),
		WeaponDefinition.new(
			&"mace",
			1,
			3,
			WeaponDefinition.TARGETING_ADJACENT_CARDINAL,
			"Disorient pressure if the target survives.",
			WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
			WeaponDefinition.BLOCKER_STANDARD,
			WeaponDefinition.ADJACENCY_NONE,
			1.0,
			&"",
			[&"disorient_if_survives_35"]
		),
		WeaponDefinition.new(
			&"bow",
			4,
			3,
			WeaponDefinition.TARGETING_STRAIGHT_LINE,
			"Ranged attack with adjacent penalty.",
			WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
			WeaponDefinition.BLOCKER_STANDARD,
			WeaponDefinition.ADJACENCY_RANGED_70,
			0.7,
			WeaponDefinition.WARNING_ADJACENT_RANGED_PENALTY
		),
		WeaponDefinition.new(
			&"crossbow",
			3,
			4,
			WeaponDefinition.TARGETING_STRAIGHT_LINE,
			"Shorter range, heavier hit, knockback preview.",
			WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
			WeaponDefinition.BLOCKER_STANDARD,
			WeaponDefinition.ADJACENCY_NONE,
			1.0,
			&"",
			[&"knockback_1_if_space_allows"]
		),
		WeaponDefinition.new(
			&"staff",
			4,
			4,
			WeaponDefinition.TARGETING_STRAIGHT_LINE,
			"Projectile attack with adjacent penalty.",
			WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
			WeaponDefinition.BLOCKER_STANDARD,
			WeaponDefinition.ADJACENCY_HALF,
			0.5,
			WeaponDefinition.WARNING_ADJACENT_RANGED_PENALTY
		),
		WeaponDefinition.new(
			&"wand",
			4,
			2,
			WeaponDefinition.TARGETING_STRAIGHT_LINE,
			"Lower damage line that ignores blockers.",
			WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
			WeaponDefinition.BLOCKER_IGNORE_TERRAIN_AND_ENTITIES,
			WeaponDefinition.ADJACENCY_NONE,
			1.0,
			&"",
			[&"ignore_blockers"],
			"Wand force ignores terrain and entity blockers, but still requires a visible target."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_weapon_repository", {
		"reason": String(reason)
	})


static func _duplicate(weapon_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_weapon", {
		"reason": "duplicate_id",
		"id": String(weapon_id)
	})
