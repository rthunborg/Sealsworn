class_name AttackPreviewQuery
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalLineQuery = preload("res://scripts/tactical/targeting/tactical_line_query.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

func preview_target_cell(
	board: BoardState,
	actor_id: StringName,
	target_cell: Vector2i,
	weapon: WeaponDefinition
) -> ActionResult:
	if board == null:
		return _invalid(&"invalid_board")

	var weapon_validation: ActionResult = _validate_weapon(weapon)
	if weapon_validation.is_error():
		return weapon_validation

	var actor: TacticalEntityState = board.get_entity(actor_id)
	if actor == null or actor_id == &"":
		return _invalid(&"invalid_actor", {"actor_id": String(actor_id), "weapon_id": String(weapon.weapon_id)})
	if actor.is_dead():
		return _invalid(&"dead_actor", {"actor_id": String(actor_id), "weapon_id": String(weapon.weapon_id)})
	if target_cell == actor.position:
		return _invalid(&"same_cell", _target_metadata(target_cell, weapon))
	if not board.in_bounds(target_cell):
		return _invalid(&"out_of_bounds", _target_metadata(target_cell, weapon))

	var target_board_cell: BoardCell = board.get_cell(target_cell)
	if target_board_cell == null:
		return _invalid(&"out_of_bounds", _target_metadata(target_cell, weapon))
	if not target_board_cell.visible:
		return _invalid(&"not_visible", _target_metadata(target_cell, weapon))

	var target_entity_id: StringName = target_board_cell.occupant_id
	if target_entity_id == &"":
		return _invalid(&"missing_target", _target_metadata(target_cell, weapon))

	var target_entity: TacticalEntityState = board.get_entity(target_entity_id)
	if target_entity == null:
		return _invalid(&"missing_target", _target_metadata(target_cell, weapon))
	if target_entity.position != target_cell:
		return _invalid(&"missing_target", _target_metadata(target_cell, weapon))
	if target_entity.is_dead():
		return _invalid(&"dead_target", _visible_target_metadata(target_cell, target_entity, weapon))
	if target_entity.faction == actor.faction:
		return _invalid(&"friendly_target", _visible_target_metadata(target_cell, target_entity, weapon))

	var distance: int = _line_distance(actor.position, target_cell)
	if not _is_aligned(actor.position, target_cell, weapon):
		var alignment_metadata: Dictionary = _visible_target_metadata(target_cell, target_entity, weapon)
		alignment_metadata["distance"] = distance
		alignment_metadata["range"] = weapon.attack_range
		return _invalid(&"not_aligned", alignment_metadata)
	if distance > weapon.attack_range:
		var range_metadata: Dictionary = _visible_target_metadata(target_cell, target_entity, weapon)
		range_metadata["distance"] = distance
		range_metadata["range"] = weapon.attack_range
		return _invalid(&"out_of_range", range_metadata)

	var line_cells: Array[Vector2i] = TacticalLineQuery.supercover_line(actor.position, target_cell)
	var blocker_cells: Array[Vector2i] = TacticalLineQuery.blocking_cells(board, actor.position, target_cell, true, actor_id)
	var blocker_ignored: bool = weapon.ignores_blockers() and not blocker_cells.is_empty()
	if not blocker_cells.is_empty() and not weapon.ignores_blockers():
		var blocker_metadata: Dictionary = _visible_target_metadata(target_cell, target_entity, weapon)
		blocker_metadata["distance"] = distance
		blocker_metadata["range"] = weapon.attack_range
		blocker_metadata["line_cells"] = _serialize_cells(line_cells)
		blocker_metadata["blocker_cells"] = _serialize_cells(blocker_cells)
		blocker_metadata["blocker_ignored"] = false
		return _invalid(&"blocked_line", blocker_metadata)

	var expected_damage: int = _expected_damage(weapon, distance)
	var warnings: Array[Dictionary] = _warning_entries(weapon, distance, expected_damage)
	var effects: Array[Dictionary] = _effect_entries(weapon)

	return ActionResult.ok([], {
		"legal": true,
		"reason": "valid",
		"actor_id": String(actor_id),
		"target_cell": _cell_metadata(target_cell),
		"target_entity_id": String(target_entity_id),
		"weapon_id": String(weapon.weapon_id),
		"targeting_shape": String(weapon.targeting_shape),
		"range": weapon.attack_range,
		"distance": distance,
		"line_cells": _serialize_cells(line_cells),
		"blocker_cells": _serialize_cells(blocker_cells),
		"blocker_ignored": blocker_ignored,
		"expected_base_damage": expected_damage,
		"warnings": warnings,
		"effects": effects,
		"explanation": _explanation(weapon, target_entity_id, expected_damage, blocker_ignored, warnings, effects)
	})


func preview_target_entity(
	board: BoardState,
	actor_id: StringName,
	target_entity_id: StringName,
	weapon: WeaponDefinition
) -> ActionResult:
	if board == null:
		return _invalid(&"invalid_board")

	var weapon_validation: ActionResult = _validate_weapon(weapon)
	if weapon_validation.is_error():
		return weapon_validation

	var actor: TacticalEntityState = board.get_entity(actor_id)
	if actor == null or actor_id == &"":
		return _invalid(&"invalid_actor", {"actor_id": String(actor_id), "weapon_id": String(weapon.weapon_id)})
	if actor.is_dead():
		return _invalid(&"dead_actor", {"actor_id": String(actor_id), "weapon_id": String(weapon.weapon_id)})
	if target_entity_id == &"":
		return _invalid(&"missing_target", {"weapon_id": String(weapon.weapon_id)})

	var visible_target_cell: Vector2i = _visible_cell_for_occupant(board, target_entity_id)
	if visible_target_cell == Vector2i(-1, -1):
		return _invalid(&"missing_target", {
			"weapon_id": String(weapon.weapon_id),
			"target_entity_id": String(target_entity_id)
		})
	return preview_target_cell(board, actor_id, visible_target_cell, weapon)


func _validate_weapon(weapon: WeaponDefinition) -> ActionResult:
	if weapon == null:
		return _invalid(&"invalid_weapon")
	var validation: ActionResult = weapon.validate()
	if validation.is_error():
		return _invalid(&"invalid_weapon", {
			"weapon_id": String(weapon.weapon_id),
			"source_error_code": String(validation.error_code),
			"source_metadata": validation.metadata.duplicate(true)
		})
	return ActionResult.ok()


func _is_aligned(origin: Vector2i, target: Vector2i, weapon: WeaponDefinition) -> bool:
	var same_row_or_column: bool = origin.x == target.x or origin.y == target.y
	match weapon.targeting_shape:
		WeaponDefinition.TARGETING_ADJACENT_CARDINAL:
			return same_row_or_column
		WeaponDefinition.TARGETING_STRAIGHT_LINE:
			return same_row_or_column
		_:
			return false


func _line_distance(origin: Vector2i, target: Vector2i) -> int:
	return abs(target.x - origin.x) + abs(target.y - origin.y)


func _expected_damage(weapon: WeaponDefinition, distance: int) -> int:
	if distance == 1 and weapon.has_adjacency_modifier():
		return max(1, int(floor(float(weapon.base_damage) * weapon.adjacency_damage_multiplier)))
	return weapon.base_damage


func _warning_entries(weapon: WeaponDefinition, distance: int, expected_damage: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if distance != 1 or not weapon.has_adjacency_modifier():
		return result
	result.append({
		"id": String(weapon.adjacency_warning_id),
		"text": "Adjacent target reduces %s damage from %s to %s." % [
			String(weapon.weapon_id),
			weapon.base_damage,
			expected_damage
		]
	})
	return result


func _effect_entries(weapon: WeaponDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect_id: StringName in weapon.preview_effect_ids:
		result.append({
			"id": String(effect_id),
			"text": _effect_text(effect_id)
		})
	return result


func _effect_text(effect_id: StringName) -> String:
	match effect_id:
		&"future_unseen_synergy":
			return "Future Unseen synergy is preview text only."
		&"bleed_if_survives_35":
			return "35% bleed if target survives; no RNG is rolled during preview."
		&"disorient_if_survives_35":
			return "35% disorient if target survives; no RNG is rolled during preview."
		&"knockback_1_if_space_allows":
			return "Knockback 1 if space allows; preview does not move the target."
		&"ignore_blockers":
			return "Ignores terrain and entity blockers; still requires target visibility."
		_:
			return String(effect_id)


func _explanation(
	weapon: WeaponDefinition,
	target_entity_id: StringName,
	expected_damage: int,
	blocker_ignored: bool,
	warnings: Array[Dictionary],
	effects: Array[Dictionary]
) -> String:
	var parts: Array[String] = [
		"%s previews %s damage to %s." % [
			String(weapon.weapon_id),
			expected_damage,
			String(target_entity_id)
		]
	]
	if blocker_ignored:
		parts.append(weapon.blocker_override_explanation)
	for warning: Dictionary in warnings:
		parts.append(String(warning.get("text", "")))
	for effect: Dictionary in effects:
		parts.append(String(effect.get("text", "")))
	return _join_strings(parts, " ")


func _target_metadata(target_cell: Vector2i, weapon: WeaponDefinition) -> Dictionary:
	return {
		"target_cell": _cell_metadata(target_cell),
		"weapon_id": String(weapon.weapon_id)
	}


func _visible_target_metadata(target_cell: Vector2i, target_entity: TacticalEntityState, weapon: WeaponDefinition) -> Dictionary:
	var metadata: Dictionary = _target_metadata(target_cell, weapon)
	metadata["target_entity_id"] = String(target_entity.entity_id)
	return metadata


func _visible_cell_for_occupant(board: BoardState, target_entity_id: StringName) -> Vector2i:
	for board_cell: BoardCell in board.cells():
		if board_cell.visible and board_cell.occupant_id == target_entity_id:
			return board_cell.position
	return Vector2i(-1, -1)


func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _serialize_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector2i in cells:
		result.append(_cell_metadata(cell))
	return result


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {
		"legal": false,
		"reason": String(reason),
		"blocker_ignored": false
	}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_attack_preview", result_metadata)


func _join_strings(parts: Array[String], separator: String) -> String:
	var result: String = ""
	for index: int in range(parts.size()):
		if index > 0:
			result += separator
		result += parts[index]
	return result
