class_name BoardCell
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

enum Terrain {
	FLOOR,
	WALL,
	HAZARD,
	ENTRANCE,
	EXIT
}

var position: Vector2i = Vector2i.ZERO
var terrain: int = Terrain.FLOOR
var occupant_id: StringName = &""
var explored: bool = false
var visible: bool = false

func _init(new_position: Vector2i = Vector2i.ZERO, new_terrain: int = Terrain.FLOOR) -> void:
	position = new_position
	terrain = new_terrain


func is_occupied() -> bool:
	return occupant_id != &""


func terrain_blocks_occupancy() -> bool:
	return terrain == Terrain.WALL


func blocks_line_of_sight() -> bool:
	return terrain == Terrain.WALL


func blocks_movement() -> bool:
	return terrain_blocks_occupancy() or is_occupied()


func to_dictionary() -> Dictionary:
	return {
		"position": {
			"x": position.x,
			"y": position.y
		},
		"terrain": terrain,
		"occupant_id": String(occupant_id),
		"explored": explored,
		"visible": visible
	}


static func from_dictionary(data: Dictionary) -> BoardCell:
	var result: ActionResult = try_from_dictionary(data)
	if result.is_error():
		push_error("BoardCell snapshot parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("cell") as BoardCell


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	var position_value: Variant = _field(data, &"position")
	if not position_value is Dictionary:
		return _invalid_cell_data(&"position")

	var position_data: Dictionary = position_value
	if not _has_integral_field(position_data, &"x") or not _has_integral_field(position_data, &"y"):
		return _invalid_cell_data(&"position")
	if not _has_integral_field(data, &"terrain"):
		return _invalid_cell_data(&"terrain")
	if not _has_string_like_field(data, &"occupant_id"):
		return _invalid_cell_data(&"occupant_id")
	if not _has_bool_field(data, &"explored"):
		return _invalid_cell_data(&"explored")
	if not _has_bool_field(data, &"visible"):
		return _invalid_cell_data(&"visible")

	var cell: BoardCell = load("res://scripts/tactical/board/board_cell.gd").new(
		Vector2i(
			int(_field(position_data, &"x")),
			int(_field(position_data, &"y"))
		),
		int(_field(data, &"terrain"))
	)
	cell.occupant_id = StringName(str(_field(data, &"occupant_id")))
	cell.explored = bool(_field(data, &"explored"))
	cell.visible = bool(_field(data, &"visible"))
	return ActionResult.ok([], {"cell": cell})


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _has_string_like_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _is_string_like(_field(data, field_name))


static func _has_integral_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _is_integral_number(_field(data, field_name))


static func _has_bool_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and typeof(_field(data, field_name)) == TYPE_BOOL


static func _is_string_like(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


static func _invalid_cell_data(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_cell_data", {
		"field": String(field_name)
	})
