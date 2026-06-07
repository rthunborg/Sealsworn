class_name TacticalCellView
extends RefCounted

var _data: Dictionary = {}

func _init(new_data: Dictionary = {}) -> void:
	_data = new_data.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


static func from_visibility_fact(fact: Dictionary) -> TacticalCellView:
	var visibility_state: String = String(fact.get("visibility_state", "hidden"))
	var data: Dictionary = {
		"position": _copy_cell_dictionary(fact.get("position", {})),
		"visibility_state": visibility_state
	}

	if visibility_state == "memory" or visibility_state == "visible":
		data["authoritative"] = bool(fact.get("authoritative", visibility_state == "visible"))
		data["terrain"] = int(fact.get("terrain", 0))
		data["blocks_line_of_sight"] = bool(fact.get("blocks_line_of_sight", false))
		data["terrain_blocks_occupancy"] = bool(fact.get("terrain_blocks_occupancy", false))

	if visibility_state == "visible" and fact.has("occupant_id"):
		data["occupant_id"] = String(fact.get("occupant_id", ""))

	return load("res://scripts/ui/view_models/tactical_cell_view.gd").new(data)


static func _copy_cell_dictionary(value: Variant) -> Dictionary:
	if value is Vector2i:
		var cell: Vector2i = value
		return {
			"x": cell.x,
			"y": cell.y
		}
	if not value is Dictionary:
		return {
			"x": 0,
			"y": 0
		}
	var data: Dictionary = value
	return {
		"x": int(_field(data, &"x") if _has_field(data, &"x") else 0),
		"y": int(_field(data, &"y") if _has_field(data, &"y") else 0)
	}


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)
