class_name ContentRepository
extends RefCounted

var _definitions_by_type: Dictionary = {}

func register_definition(definition_type: StringName, definition_id: StringName, definition: Resource) -> void:
	if not _definitions_by_type.has(definition_type):
		_definitions_by_type[definition_type] = {}

	var typed_bucket: Dictionary = _definitions_by_type[definition_type]
	typed_bucket[definition_id] = definition


func get_definition(definition_type: StringName, definition_id: StringName) -> Resource:
	if not _definitions_by_type.has(definition_type):
		return null

	var typed_bucket: Dictionary = _definitions_by_type[definition_type]
	return typed_bucket.get(definition_id) as Resource


func has_definition(definition_type: StringName, definition_id: StringName) -> bool:
	if not _definitions_by_type.has(definition_type):
		return false

	var typed_bucket: Dictionary = _definitions_by_type[definition_type]
	return typed_bucket.has(definition_id)

