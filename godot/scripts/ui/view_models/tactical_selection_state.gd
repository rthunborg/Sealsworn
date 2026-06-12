class_name TacticalSelectionState
extends RefCounted

var selected_cell: Variant = null
var selected_entity_id: StringName = &""

func _init(new_selected_cell: Variant = null, new_selected_entity_id: StringName = &"") -> void:
	selected_cell = _copy_cell_or_null(new_selected_cell)
	selected_entity_id = new_selected_entity_id


func to_dictionary() -> Dictionary:
	return {
		"selected_cell": null if selected_cell == null else (selected_cell as Dictionary).duplicate(true),
		"selected_entity_id": String(selected_entity_id)
	}


static func from_options(options: Dictionary) -> TacticalSelectionState:
	var selection: Dictionary = {}
	var selection_value: Variant = _field(options, &"selection") if _has_field(options, &"selection") else {}
	if selection_value is Dictionary:
		selection = selection_value
	var entity_id: StringName = StringName(str(_field(selection, &"selected_entity_id") if _has_field(selection, &"selected_entity_id") else ""))
	return load("res://scripts/ui/view_models/tactical_selection_state.gd").new(
		_field(selection, &"selected_cell") if _has_field(selection, &"selected_cell") else null,
		entity_id
	)


static func _copy_cell_or_null(value: Variant) -> Variant:
	if value == null:
		return null
	if value is Vector2i:
		var cell: Vector2i = value
		return {
			"x": cell.x,
			"y": cell.y
		}
	if value is Dictionary:
		var data: Dictionary = value
		if _has_field(data, &"x") and _has_field(data, &"y"):
			return {
				"x": int(_field(data, &"x")),
				"y": int(_field(data, &"y"))
			}
	return null


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)
