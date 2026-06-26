class_name PickupRepository
extends RefCounted

# The fail-closed PICKUP content repository (Story 6.1) — a structure-clone of WeaponRepository / ArmorRepository.
# Holds a ContentRepository, registers the approved baseline pickup definitions, and resolves a pickup id to its
# typed PickupDefinition via get_pickup(id) — null on a miss (fail-closed; collision-free accessor name). A
# second registration under an already-present id fails loud with duplicate_pickup (the central duplicate-id
# guard, surfaced per-type — Story 6.1 AC6).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const PickupDefinition = preload("res://scripts/content/definitions/pickup_definition.gd")

const BASELINE_PICKUP_IDS: Array[StringName] = [
	&"health_morsel",
	&"focus_ember"
]

var _content_repository: ContentRepository
var _pickup_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> PickupRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> PickupRepository:
	var validated_definitions: Array[PickupDefinition] = []
	for definition_value: Variant in definitions:
		var definition: PickupDefinition = definition_value as PickupDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: PickupRepository = load("res://scripts/content/repositories/pickup_repository.gd").new(content_repository)
	for definition: PickupDefinition in validated_definitions:
		var result: ActionResult = repository.register_pickup(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_pickups() -> ActionResult:
	for definition: PickupDefinition in _baseline_definitions():
		var result: ActionResult = register_pickup(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_pickup(definition: PickupDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_pickup")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(PickupDefinition.DEFINITION_TYPE, definition.pickup_id, definition)
	if registration.is_error():
		return _duplicate(definition.pickup_id)
	if not _pickup_order.has(definition.pickup_id):
		_pickup_order.append(definition.pickup_id)
	return ActionResult.ok([], {
		"pickup_id": String(definition.pickup_id)
	})


func get_pickup(pickup_id: StringName) -> PickupDefinition:
	return _content_repository.get_definition(PickupDefinition.DEFINITION_TYPE, pickup_id) as PickupDefinition


func has_pickup(pickup_id: StringName) -> bool:
	return _content_repository.has_definition(PickupDefinition.DEFINITION_TYPE, pickup_id)


func pickup_ids() -> Array[StringName]:
	return _pickup_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[PickupDefinition]:
	return [
		PickupDefinition.new(
			&"health_morsel",
			&"restore_small_health",
			"A small morsel that restores a little health on pickup."
		),
		PickupDefinition.new(
			&"focus_ember",
			&"restore_small_focus",
			"A stray ember that restores a little focus on pickup."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_pickup_repository", {
		"reason": String(reason)
	})


static func _duplicate(pickup_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_pickup", {
		"reason": "duplicate_id",
		"id": String(pickup_id)
	})
