class_name TacticalOccupantView
extends RefCounted

const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

var _data: Dictionary = {}

func _init(new_data: Dictionary = {}) -> void:
	_data = new_data.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


static func from_entity(entity: TacticalEntityState) -> TacticalOccupantView:
	if entity == null:
		return load("res://scripts/ui/view_models/tactical_occupant_view.gd").new()

	var data: Dictionary = {
		"entity_id": String(entity.entity_id),
		"entity_type": String(TacticalEntityState.id_for_entity_type(entity.entity_type)),
		"faction": String(entity.faction),
		"position": {
			"x": entity.position.x,
			"y": entity.position.y
		},
		"current_hp": entity.current_hp,
		"max_hp": entity.max_hp,
		"is_alive": entity.is_alive(),
		"is_dead": entity.is_dead(),
		"blocks_movement": entity.blocks_movement,
		"definition_id": String(entity.definition_id)
	}
	return load("res://scripts/ui/view_models/tactical_occupant_view.gd").new(data)
