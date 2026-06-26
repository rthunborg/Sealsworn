class_name ConsumableRepository
extends RefCounted

# The fail-closed CONSUMABLE content repository (Story 6.1) — a structure-clone of WeaponRepository /
# ArmorRepository. Holds a ContentRepository, registers the approved baseline consumable definitions, and
# resolves a consumable id to its typed ConsumableDefinition via get_consumable(id) — null on a miss
# (fail-closed; collision-free accessor name). A second registration under an already-present id fails loud
# with duplicate_consumable (the central duplicate-id guard, surfaced per-type — Story 6.1 AC6).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const ConsumableDefinition = preload("res://scripts/content/definitions/consumable_definition.gd")

const BASELINE_CONSUMABLE_IDS: Array[StringName] = [
	&"minor_healing_draught",
	&"warding_salve",
	&"ember_flask"
]

var _content_repository: ContentRepository
var _consumable_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> ConsumableRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> ConsumableRepository:
	var validated_definitions: Array[ConsumableDefinition] = []
	for definition_value: Variant in definitions:
		var definition: ConsumableDefinition = definition_value as ConsumableDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: ConsumableRepository = load("res://scripts/content/repositories/consumable_repository.gd").new(content_repository)
	for definition: ConsumableDefinition in validated_definitions:
		var result: ActionResult = repository.register_consumable(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_consumables() -> ActionResult:
	for definition: ConsumableDefinition in _baseline_definitions():
		var result: ActionResult = register_consumable(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_consumable(definition: ConsumableDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_consumable")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(ConsumableDefinition.DEFINITION_TYPE, definition.consumable_id, definition)
	if registration.is_error():
		return _duplicate(definition.consumable_id)
	if not _consumable_order.has(definition.consumable_id):
		_consumable_order.append(definition.consumable_id)
	return ActionResult.ok([], {
		"consumable_id": String(definition.consumable_id)
	})


func get_consumable(consumable_id: StringName) -> ConsumableDefinition:
	return _content_repository.get_definition(ConsumableDefinition.DEFINITION_TYPE, consumable_id) as ConsumableDefinition


func has_consumable(consumable_id: StringName) -> bool:
	return _content_repository.has_definition(ConsumableDefinition.DEFINITION_TYPE, consumable_id)


func consumable_ids() -> Array[StringName]:
	return _consumable_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[ConsumableDefinition]:
	return [
		ConsumableDefinition.new(
			&"minor_healing_draught",
			ConsumableDefinition.RARITY_COMMON,
			10,
			"Restores a little health — the common field draught."
		),
		ConsumableDefinition.new(
			&"warding_salve",
			ConsumableDefinition.RARITY_UNCOMMON,
			25,
			"A semi-rare salve worth saving for a hard fight."
		),
		ConsumableDefinition.new(
			&"ember_flask",
			ConsumableDefinition.RARITY_RARE,
			50,
			"A rare flask of bottled ember — genuinely worth using."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_consumable_repository", {
		"reason": String(reason)
	})


static func _duplicate(consumable_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_consumable", {
		"reason": "duplicate_id",
		"id": String(consumable_id)
	})
