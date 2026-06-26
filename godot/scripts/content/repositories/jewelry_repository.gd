class_name JewelryRepository
extends RefCounted

# The fail-closed JEWELRY content repository (Story 6.1) — a structure-clone of WeaponRepository /
# ArmorRepository. Holds a ContentRepository, registers the approved baseline jewelry definitions, and resolves
# a jewelry id to its typed JewelryDefinition via get_jewelry(id) — null on a miss (fail-closed; collision-free
# accessor name). A second registration under an already-present id fails loud with duplicate_jewelry (the
# central duplicate-id guard, surfaced per-type — Story 6.1 AC6).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const JewelryDefinition = preload("res://scripts/content/definitions/jewelry_definition.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

const BASELINE_JEWELRY_IDS: Array[StringName] = [
	&"copper_band",
	&"jasper_amulet",
	&"sealbearers_signet"
]

var _content_repository: ContentRepository
var _jewelry_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> JewelryRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> JewelryRepository:
	var validated_definitions: Array[JewelryDefinition] = []
	for definition_value: Variant in definitions:
		var definition: JewelryDefinition = definition_value as JewelryDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: JewelryRepository = load("res://scripts/content/repositories/jewelry_repository.gd").new(content_repository)
	for definition: JewelryDefinition in validated_definitions:
		var result: ActionResult = repository.register_jewelry(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_jewelry() -> ActionResult:
	for definition: JewelryDefinition in _baseline_definitions():
		var result: ActionResult = register_jewelry(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_jewelry(definition: JewelryDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_jewelry")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(JewelryDefinition.DEFINITION_TYPE, definition.jewelry_id, definition)
	if registration.is_error():
		return _duplicate(definition.jewelry_id)
	if not _jewelry_order.has(definition.jewelry_id):
		_jewelry_order.append(definition.jewelry_id)
	return ActionResult.ok([], {
		"jewelry_id": String(definition.jewelry_id)
	})


func get_jewelry(jewelry_id: StringName) -> JewelryDefinition:
	return _content_repository.get_definition(JewelryDefinition.DEFINITION_TYPE, jewelry_id) as JewelryDefinition


func has_jewelry(jewelry_id: StringName) -> bool:
	return _content_repository.has_definition(JewelryDefinition.DEFINITION_TYPE, jewelry_id)


func jewelry_ids() -> Array[StringName]:
	return _jewelry_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[JewelryDefinition]:
	return [
		JewelryDefinition.new(
			&"copper_band",
			JewelryDefinition.SLOT_RING,
			1,
			JewelryDefinition.LEVEL_REQUIREMENT_NONE,
			ItemRollModel.new(0, 1),
			"A plain copper ring — equippable from the start (no level gate)."
		),
		JewelryDefinition.new(
			&"jasper_amulet",
			JewelryDefinition.SLOT_AMULET,
			2,
			2,
			ItemRollModel.new(1, 2),
			"A jasper-set amulet (character level 2)."
		),
		JewelryDefinition.new(
			&"sealbearers_signet",
			JewelryDefinition.SLOT_RING,
			3,
			4,
			ItemRollModel.new(2, 4),
			"A sealbearer's signet ring (character level 4)."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_jewelry_repository", {
		"reason": String(reason)
	})


static func _duplicate(jewelry_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_jewelry", {
		"reason": "duplicate_id",
		"id": String(jewelry_id)
	})
