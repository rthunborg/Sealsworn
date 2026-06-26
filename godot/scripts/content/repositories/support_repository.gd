class_name SupportRepository
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")

const BASELINE_SUPPORT_IDS: Array[StringName] = [
	&"none",
	&"tome",
	&"shield"
]

var _content_repository: ContentRepository
var _support_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> SupportRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> SupportRepository:
	var validated_definitions: Array[SupportDefinition] = []
	for definition_value: Variant in definitions:
		var definition: SupportDefinition = definition_value as SupportDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: SupportRepository = load("res://scripts/content/repositories/support_repository.gd").new(content_repository)
	for definition: SupportDefinition in validated_definitions:
		var result: ActionResult = repository.register_support(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_supports() -> ActionResult:
	for definition: SupportDefinition in _baseline_definitions():
		var result: ActionResult = register_support(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_support(definition: SupportDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_support")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(SupportDefinition.DEFINITION_TYPE, definition.support_id, definition)
	if registration.is_error():
		return _duplicate(definition.support_id)
	if not _support_order.has(definition.support_id):
		_support_order.append(definition.support_id)
	return ActionResult.ok([], {
		"support_id": String(definition.support_id)
	})


func get_support(support_id: StringName) -> SupportDefinition:
	return _content_repository.get_definition(SupportDefinition.DEFINITION_TYPE, support_id) as SupportDefinition


func has_support(support_id: StringName) -> bool:
	return _content_repository.has_definition(SupportDefinition.DEFINITION_TYPE, support_id)


func support_ids() -> Array[StringName]:
	return _support_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[SupportDefinition]:
	return [
		SupportDefinition.new(
			SupportDefinition.SUPPORT_NONE,
			0,
			0.0,
			0,
			[],
			"No off-hand modifier."
		),
		SupportDefinition.new(
			SupportDefinition.SUPPORT_TOME,
			0,
			0.0,
			1,
			[&"staff", &"wand"],
			"Staff and wand attacks deal +1 damage."
		),
		SupportDefinition.new(
			SupportDefinition.SUPPORT_SHIELD,
			1,
			0.5,
			0,
			[],
			"Armor and a chance to block physical damage."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_support_repository", {
		"reason": String(reason)
	})


static func _duplicate(support_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_support", {
		"reason": "duplicate_id",
		"id": String(support_id)
	})
