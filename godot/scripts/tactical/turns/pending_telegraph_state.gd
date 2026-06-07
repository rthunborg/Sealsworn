class_name PendingTelegraphState
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

const KIND_ASH_SEER_MARK := "ash_seer_mark"
const STATUS_PENDING := "pending"

static func validate_events(pending_telegraphs: Array[Dictionary], events: Array[DomainEvent]) -> ActionResult:
	var staged: Array[Dictionary] = _copy_pending(pending_telegraphs)
	return _apply_to_staged(staged, events)


static func apply_events(pending_telegraphs: Array[Dictionary], events: Array[DomainEvent]) -> ActionResult:
	var staged: Array[Dictionary] = _copy_pending(pending_telegraphs)
	var result: ActionResult = _apply_to_staged(staged, events)
	if result.is_error():
		return result

	pending_telegraphs.clear()
	for telegraph: Dictionary in staged:
		pending_telegraphs.append(telegraph.duplicate(true))
	return ActionResult.ok([], {
		"pending_telegraphs": pending_telegraphs.duplicate(true)
	})


static func pending_mark_index(pending_telegraphs: Array[Dictionary], telegraph_id: String) -> int:
	for index: int in range(pending_telegraphs.size()):
		if String(pending_telegraphs[index].get("telegraph_id", "")) == telegraph_id:
			return index
	return -1


static func _apply_to_staged(staged: Array[Dictionary], events: Array[DomainEvent]) -> ActionResult:
	for event: DomainEvent in events:
		if event == null:
			return _invalid(&"invalid_event")
		match event.event_type:
			DomainEvent.Type.TILE_MARKED:
				var mark_result: ActionResult = _apply_tile_marked(staged, event)
				if mark_result.is_error():
					return mark_result
			DomainEvent.Type.MARKED_TILE_DETONATED:
				var detonation_result: ActionResult = _apply_marked_tile_detonated(staged, event)
				if detonation_result.is_error():
					return detonation_result
			_:
				pass
	return ActionResult.ok()


static func _apply_tile_marked(staged: Array[Dictionary], event: DomainEvent) -> ActionResult:
	var telegraph_id: String = String(event.payload.get("telegraph_id", ""))
	if telegraph_id.is_empty():
		return _invalid(&"missing_telegraph_id")
	if pending_mark_index(staged, telegraph_id) >= 0:
		return _invalid(&"duplicate_telegraph", {"telegraph_id": telegraph_id})
	if not event.payload.has("marked_cell") or not event.payload.get("marked_cell") is Dictionary:
		return _invalid(&"invalid_marked_cell")

	var marked_cell: Dictionary = event.payload.get("marked_cell")
	var pending_mark: Dictionary = {
		"telegraph_id": telegraph_id,
		"kind": KIND_ASH_SEER_MARK,
		"source_entity_id": String(event.actor_id),
		"target_entity_id": String(event.payload.get("target_entity_id", "")),
		"marked_cell": {
			"x": int(marked_cell.get("x", -1)),
			"y": int(marked_cell.get("y", -1))
		},
		"created_turn_number": int(event.payload.get("created_turn_number", 0)),
		"due_turn_number": int(event.payload.get("due_turn_number", 0)),
		"damage": int(event.payload.get("damage", 0)),
		"damage_type": String(event.payload.get("damage_type", "")),
		"status": STATUS_PENDING
	}
	var validation: ActionResult = validate_pending_mark(pending_mark)
	if validation.is_error():
		return validation
	staged.append(pending_mark)
	return ActionResult.ok()


static func _apply_marked_tile_detonated(staged: Array[Dictionary], event: DomainEvent) -> ActionResult:
	var telegraph_id: String = String(event.payload.get("telegraph_id", ""))
	var mark_index: int = pending_mark_index(staged, telegraph_id)
	if mark_index < 0:
		return _invalid(&"missing_telegraph", {"telegraph_id": telegraph_id})

	var mark: Dictionary = staged[mark_index]
	var validation: ActionResult = validate_pending_mark(mark)
	if validation.is_error():
		return validation
	if String(mark.get("source_entity_id", "")) != String(event.actor_id):
		return _invalid(&"source_mismatch", {"telegraph_id": telegraph_id})
	if String(mark.get("target_entity_id", "")) != String(event.payload.get("target_entity_id", "")):
		return _invalid(&"target_mismatch", {"telegraph_id": telegraph_id})
	if mark.get("marked_cell", {}) != event.payload.get("marked_cell", {}):
		return _invalid(&"marked_cell_mismatch", {"telegraph_id": telegraph_id})

	staged.remove_at(mark_index)
	return ActionResult.ok()


static func validate_pending_mark(mark: Dictionary) -> ActionResult:
	if String(mark.get("telegraph_id", "")).is_empty():
		return _invalid(&"missing_telegraph_id")
	if String(mark.get("kind", "")) != KIND_ASH_SEER_MARK:
		return _invalid(&"invalid_kind")
	if String(mark.get("source_entity_id", "")).is_empty():
		return _invalid(&"missing_source")
	if String(mark.get("target_entity_id", "")).is_empty():
		return _invalid(&"missing_target")
	if not mark.has("marked_cell") or not mark.get("marked_cell") is Dictionary:
		return _invalid(&"invalid_marked_cell")
	var marked_cell: Dictionary = mark.get("marked_cell")
	if not _is_integral_number(marked_cell.get("x")) or not _is_integral_number(marked_cell.get("y")):
		return _invalid(&"invalid_marked_cell")
	if not _is_positive_integral(mark.get("created_turn_number")):
		return _invalid(&"invalid_created_turn")
	if not _is_positive_integral(mark.get("due_turn_number")):
		return _invalid(&"invalid_due_turn")
	if int(mark.get("due_turn_number")) <= int(mark.get("created_turn_number")):
		return _invalid(&"invalid_due_turn")
	if not _is_positive_integral(mark.get("damage")):
		return _invalid(&"invalid_damage")
	if String(mark.get("damage_type", "")).is_empty():
		return _invalid(&"invalid_damage_type")
	if String(mark.get("status", STATUS_PENDING)) != STATUS_PENDING:
		return _invalid(&"invalid_status")
	return ActionResult.ok()


static func _copy_pending(pending_telegraphs: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for telegraph: Dictionary in pending_telegraphs:
		result.append(telegraph.duplicate(true))
	return result


static func _is_positive_integral(value: Variant) -> bool:
	return _is_integral_number(value) and int(value) > 0


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


static func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_pending_telegraph_state", result_metadata)
