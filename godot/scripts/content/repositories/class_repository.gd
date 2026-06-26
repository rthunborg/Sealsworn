class_name ClassRepository
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")

const BASELINE_CLASS_IDS: Array[StringName] = [
	&"warrior",
	&"pyromancer",
	&"ranger",
	&"necromancer",
	&"shadeblade"
]

var _content_repository: ContentRepository
var _class_order: Array[StringName] = []

func _init(new_content_repository: ContentRepository = null) -> void:
	if new_content_repository == null:
		_content_repository = ContentRepository.new()
	else:
		_content_repository = new_content_repository


static func create_baseline_repository(content_repository: ContentRepository = null) -> ClassRepository:
	return create_repository_from_definitions(_baseline_definitions(), content_repository)


static func create_repository_from_definitions(definitions: Array, content_repository: ContentRepository = null) -> ClassRepository:
	var validated_definitions: Array[ClassDefinition] = []
	for definition_value: Variant in definitions:
		var definition: ClassDefinition = definition_value as ClassDefinition
		if definition == null:
			return null
		var validation: ActionResult = definition.validate()
		if validation.is_error():
			return null
		validated_definitions.append(definition)

	var repository: ClassRepository = load("res://scripts/content/repositories/class_repository.gd").new(content_repository)
	for definition: ClassDefinition in validated_definitions:
		var result: ActionResult = repository.register_class(definition)
		if result.is_error():
			return null
	return repository


func register_baseline_classes() -> ActionResult:
	for definition: ClassDefinition in _baseline_definitions():
		var result: ActionResult = register_class(definition)
		if result.is_error():
			return result
	return ActionResult.ok()


func register_class(definition: ClassDefinition) -> ActionResult:
	if definition == null:
		return _invalid(&"invalid_class")
	var validation: ActionResult = definition.validate()
	if validation.is_error():
		return validation

	var registration: ActionResult = _content_repository.register_definition(ClassDefinition.DEFINITION_TYPE, definition.class_id, definition)
	if registration.is_error():
		return _duplicate(definition.class_id)
	if not _class_order.has(definition.class_id):
		_class_order.append(definition.class_id)
	return ActionResult.ok([], {
		"class_id": String(definition.class_id)
	})


func get_class_definition(class_id: StringName) -> ClassDefinition:
	return _content_repository.get_definition(ClassDefinition.DEFINITION_TYPE, class_id) as ClassDefinition


func has_class(class_id: StringName) -> bool:
	return _content_repository.has_definition(ClassDefinition.DEFINITION_TYPE, class_id)


func class_ids() -> Array[StringName]:
	return _class_order.duplicate()


func content_repository() -> ContentRepository:
	return _content_repository


static func _baseline_definitions() -> Array[ClassDefinition]:
	return [
		ClassDefinition.new(
			&"warrior",
			"Warrior",
			ClassDefinition.LOCK_STATE_SELECTABLE,
			"",
			&"sword",
			&"shield",
			18,
			&"warrior_unbreakable_guard",
			&"warrior_blade_and_board"
		),
		ClassDefinition.new(
			&"pyromancer",
			"Pyromancer",
			ClassDefinition.LOCK_STATE_SELECTABLE,
			"",
			&"staff",
			&"tome",
			18,
			&"pyromancer_kindling_focus",
			&"pyromancer_arcane_conduit"
		),
		ClassDefinition.new(
			&"ranger",
			"Ranger",
			ClassDefinition.LOCK_STATE_SELECTABLE,
			"",
			&"bow",
			&"none",
			18,
			&"ranger_steady_aim",
			&"ranger_hunters_quiver"
		),
		ClassDefinition.new(
			&"necromancer",
			"Necromancer",
			ClassDefinition.LOCK_STATE_LOCKED,
			"Locked for the MVP. A future class unlock — raise the fallen to fight beside you."
		),
		ClassDefinition.new(
			&"shadeblade",
			"Shadeblade",
			ClassDefinition.LOCK_STATE_LOCKED,
			"Locked for the MVP. A future class unlock — strike from the shadows with stealth and guile."
		)
	]


static func _invalid(reason: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_class_repository", {
		"reason": String(reason)
	})


static func _duplicate(class_id: StringName) -> ActionResult:
	return ActionResult.error(&"duplicate_class", {
		"reason": "duplicate_id",
		"id": String(class_id)
	})
