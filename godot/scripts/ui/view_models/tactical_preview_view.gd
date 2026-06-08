class_name TacticalPreviewView
extends RefCounted

var _data: Dictionary = {}

func _init(new_data: Dictionary = {}) -> void:
	_data = safe_dictionary_copy(new_data)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


static func safe_dictionary_copy(source: Variant) -> Dictionary:
	if not source is Dictionary:
		return {}
	var result: Dictionary = {}
	for key: Variant in source.keys():
		if not (key is String or key is StringName):
			continue
		result[String(key)] = safe_value(source[key])
	return result


static func safe_array_copy(source: Variant) -> Array:
	var result: Array = []
	if not source is Array:
		return result
	for item: Variant in source:
		result.append(safe_value(item))
	return result


static func safe_string_array(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if not source is Array:
		return result
	for item: Variant in source:
		result.append(String(item))
	return result


static func safe_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return null
			return numeric_value
		TYPE_STRING:
			return String(value)
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2I:
			var cell: Vector2i = value
			return cell_metadata(cell)
		TYPE_ARRAY:
			return safe_array_copy(value)
		TYPE_DICTIONARY:
			return safe_dictionary_copy(value)
		_:
			return null
	return null


static func cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


static func has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func field(data: Dictionary, field_name: StringName, fallback: Variant = null) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	if data.has(field_name):
		return data[field_name]
	return fallback
