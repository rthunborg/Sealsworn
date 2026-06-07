class_name CombatExplanationLog
extends RefCounted

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func build_entries(events: Array[DomainEvent]) -> Array[Dictionary]:
	var sorted_events: Array[DomainEvent] = events.duplicate()
	sorted_events.sort_custom(_sort_events)

	var entries: Array[Dictionary] = []
	for event: DomainEvent in sorted_events:
		if event == null:
			continue
		entries.append(_entry_for_event(event))
	return entries


func _entry_for_event(event: DomainEvent) -> Dictionary:
	match event.event_type:
		DomainEvent.Type.ENTITY_MOVED:
			return _entry(event, "%s moved from %s to %s." % [
				String(event.actor_id),
				_cell_text(event.payload.get("from", {})),
				_cell_text(event.payload.get("to", {}))
			])
		DomainEvent.Type.VISIBILITY_UPDATED:
			return _entry(event, "%s revealed %s visible cells from %s." % [
				String(event.actor_id),
				(event.payload.get("visible_cells", []) as Array).size() if event.payload.get("visible_cells", []) is Array else 0,
				_cell_text(event.payload.get("origin", {}))
			])
		DomainEvent.Type.ENTITY_ATTACKED:
			return _entry(event, "%s attacked %s with %s." % [
				String(event.actor_id),
				String(event.payload.get("target_entity_id", "")),
				String(event.payload.get("weapon_id", "unknown"))
			])
		DomainEvent.Type.DAMAGE_APPLIED:
			return _entry(event, "%s took %s %s damage from %s." % [
				String(event.payload.get("target_entity_id", "")),
				int(event.payload.get("final_damage", event.payload.get("amount", 0))),
				String(event.payload.get("damage_type", "unknown")),
				String(event.actor_id)
			])
		DomainEvent.Type.STATUS_EFFECT_APPLIED:
			return _entry(event, "%s applied %s to %s." % [
				String(event.actor_id),
				String(event.payload.get("effect_id", "unknown")),
				String(event.payload.get("target_entity_id", ""))
			])
		DomainEvent.Type.ENTITY_KNOCKED_BACK:
			return _entry(event, "%s knocked %s from %s to %s." % [
				String(event.actor_id),
				String(event.payload.get("target_entity_id", "")),
				_cell_text(event.payload.get("from", {})),
				_cell_text(event.payload.get("to", {}))
			])
		DomainEvent.Type.TILE_MARKED:
			return _entry(event, "%s marked %s at %s." % [
				String(event.actor_id),
				String(event.payload.get("target_entity_id", "")),
				_cell_text(event.payload.get("marked_cell", {}))
			])
		DomainEvent.Type.MARKED_TILE_DETONATED:
			return _entry(event, "%s mark detonated at %s with outcome %s." % [
				String(event.actor_id),
				_cell_text(event.payload.get("marked_cell", {})),
				String(event.payload.get("outcome", "unknown"))
			])
		DomainEvent.Type.ENEMY_WAITED:
			return _entry(event, "%s waited: %s." % [
				String(event.actor_id),
				String(event.payload.get("reason", "unknown"))
			])
		DomainEvent.Type.LEVEL_VICTORY_REACHED:
			return _entry(event, String(event.payload.get("explanation", "Victory reached.")))
		DomainEvent.Type.LEVEL_DEFEAT_REACHED:
			return _entry(event, String(event.payload.get("explanation", "Defeat reached.")))
		_:
			return _entry(event, "unknown event %s occurred." % String(DomainEvent.id_for_type(event.event_type)))


func _entry(event: DomainEvent, summary: String) -> Dictionary:
	var event_id: String = String(DomainEvent.id_for_type(event.event_type))
	return {
		"entry_id": "%s:%s" % [event_id, event.sequence_id],
		"sequence_id": event.sequence_id,
		"event_id": event_id,
		"actor_id": String(event.actor_id),
		"summary": summary,
		"details": event.payload.duplicate(true)
	}


func _cell_text(value: Variant) -> String:
	if not value is Dictionary:
		return "(?,?)"
	var cell: Dictionary = value
	return "(%s,%s)" % [int(cell.get("x", 0)), int(cell.get("y", 0))]


func _sort_events(first: DomainEvent, second: DomainEvent) -> bool:
	if first.sequence_id == second.sequence_id:
		return String(DomainEvent.id_for_type(first.event_type)) < String(DomainEvent.id_for_type(second.event_type))
	return first.sequence_id < second.sequence_id
