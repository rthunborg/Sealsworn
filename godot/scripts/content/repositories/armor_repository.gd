class_name ArmorRepository
extends RefCounted

# The fail-closed ARMOR content repository (Story 6.1) — a structure-clone of WeaponRepository / PassiveRepository.
# It holds a ContentRepository, registers the approved baseline armor definitions through it, and resolves an
# armor id to its typed ArmorDefinition via get_armor(id) — returning null on a miss (fail-closed). The accessor
# name get_armor is collision-free (no reserved Object/Resource/RefCounted method clash — the Epic-5 get_class
# lesson). A second registration under an already-present id fails loud with a duplicate_armor error (the
# central ContentRepository duplicate-id guard, surfaced per-type — Story 6.1 AC6).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const ArmorDefinition = preload("res://scripts/content/definitions/armor_definition.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

const BASELINE_ARMOR_IDS: Array[StringName] = [
	&"padded_vest",
	&"chain_hauberk",
	&"warded_plate"
]

var _content_repository: ContentRepository
var _armor_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> ArmorRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> ArmorRepository:
	var validated_definitions: Array[ArmorDefinition] = []
	for definition_value: Variant in definitions:
		var definition: ArmorDefinition = definition_value as ArmorDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: ArmorRepository = load("res://scripts/content/repositories/armor_repository.gd").new(content_repository)
	for definition: ArmorDefinition in validated_definitions:
		var result: ActionResult = repository.register_armor(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_armor() -> ActionResult:
	for definition: ArmorDefinition in _baseline_definitions():
		var result: ActionResult = register_armor(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_armor(definition: ArmorDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_armor")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(ArmorDefinition.DEFINITION_TYPE, definition.armor_id, definition)
	if registration.is_error():
		return _duplicate(definition.armor_id)
	if not _armor_order.has(definition.armor_id):
		_armor_order.append(definition.armor_id)
	return ActionResult.ok([], {
		"armor_id": String(definition.armor_id)
	})


func get_armor(armor_id: StringName) -> ArmorDefinition:
	return _content_repository.get_definition(ArmorDefinition.DEFINITION_TYPE, armor_id) as ArmorDefinition


func has_armor(armor_id: StringName) -> bool:
	return _content_repository.has_definition(ArmorDefinition.DEFINITION_TYPE, armor_id)


func armor_ids() -> Array[StringName]:
	return _armor_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[ArmorDefinition]:
	return [
		ArmorDefinition.new(
			&"padded_vest",
			1,
			ArmorDefinition.LEVEL_REQUIREMENT_NONE,
			ItemRollModel.new(0, 1),
			"Light padding — equippable from the start (no level gate)."
		),
		ArmorDefinition.new(
			&"chain_hauberk",
			3,
			2,
			ItemRollModel.new(1, 3),
			"Interlocked rings — needs a little seasoning (character level 2)."
		),
		ArmorDefinition.new(
			&"warded_plate",
			5,
			4,
			ItemRollModel.new(2, 5),
			"Heavy warded plate — a veteran's armor (character level 4)."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_armor_repository", {
		"reason": String(reason)
	})


static func _duplicate(armor_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_armor", {
		"reason": "duplicate_id",
		"id": String(armor_id)
	})
