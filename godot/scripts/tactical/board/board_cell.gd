class_name BoardCell
extends RefCounted

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


func blocks_movement() -> bool:
	return terrain == Terrain.WALL or is_occupied()


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
	var position_data: Dictionary = data.get("position", {})
	var cell: BoardCell = load("res://scripts/tactical/board/board_cell.gd").new(
		Vector2i(
			int(position_data.get("x", 0)),
			int(position_data.get("y", 0))
		),
		int(data.get("terrain", Terrain.FLOOR))
	)
	cell.occupant_id = StringName(str(data.get("occupant_id", "")))
	cell.explored = bool(data.get("explored", false))
	cell.visible = bool(data.get("visible", false))
	return cell
