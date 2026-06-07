extends "res://tests/unit/test_case.gd"

const CombatExplanationLog = preload("res://scripts/tactical/outcomes/combat_explanation_log.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_entries_are_sorted_and_derived_from_domain_events()
	_entries_cover_enemy_turn_and_outcome_events()
	_unknown_events_produce_stable_generic_entries()
	_entries_are_reproducible_from_same_event_log()
	return result()


func _entries_are_sorted_and_derived_from_domain_events() -> void:
	var events: Array[DomainEvent] = [
		DomainEvent.damage_applied(4, &"hero", &"enemy_iron", 4, 10, 6, 10, _damage_payload("sword", 4)),
		DomainEvent.entity_moved(2, &"hero", Vector2i(0, 2), Vector2i(1, 2), 1, 3),
		DomainEvent.visibility_updated(1, &"hero", Vector2i(0, 2), 4, [Vector2i(0, 2), Vector2i(1, 2)], [Vector2i(0, 2), Vector2i(1, 2)]),
		DomainEvent.entity_attacked(3, &"hero", &"enemy_iron", Vector2i(2, 2), &"sword", _attack_payload("sword", 4)),
		DomainEvent.status_effect_applied(5, &"hero", &"enemy_iron", &"bleed", {"weapon_id": "axe"}),
		DomainEvent.entity_knocked_back(6, &"hero", &"enemy_iron", Vector2i(2, 2), Vector2i(3, 2), &"crossbow", {"source_cell": {"x": 1, "y": 2}})
	]

	var entries: Array[Dictionary] = CombatExplanationLog.new().build_entries(events)

	assert_equal(_entry_ids(entries), [
		"visibility_updated:1",
		"entity_moved:2",
		"entity_attacked:3",
		"damage_applied:4",
		"status_effect_applied:5",
		"entity_knocked_back:6"
	], "Explanation entries should sort by domain event sequence id.")
	assert_equal(entries[1].get("actor_id"), "hero", "Movement entries should carry actor ids from events.")
	assert_true(String(entries[2].get("summary", "")).contains("sword"), "Attack summaries should derive weapon ids from event payloads.")
	assert_equal(entries[3].get("details", {}).get("target_entity_id"), "enemy_iron", "Damage details should preserve event payload data.")


func _entries_cover_enemy_turn_and_outcome_events() -> void:
	var events: Array[DomainEvent] = [
		DomainEvent.tile_marked(7, &"enemy_seer", &"hero", Vector2i(1, 2), "ash_seer_mark:enemy_seer:7", _mark_payload()),
		DomainEvent.marked_tile_detonated(8, &"enemy_seer", &"hero", Vector2i(1, 2), "ash_seer_mark:enemy_seer:7", &"hit", _detonation_payload()),
		DomainEvent.enemy_waited(9, &"enemy_iron", &"blocked", _wait_payload()),
		DomainEvent.level_victory_reached(10, 1, 0, ["enemy_iron", "enemy_seer"], 8, "All enemies were defeated."),
		DomainEvent.level_defeat_reached(11, &"hero", 8, &"damage_applied", &"enemy_seer", &"physical", 4, "Hero fell to Ash Seer detonation.")
	]

	var entries: Array[Dictionary] = CombatExplanationLog.new().build_entries(events)

	assert_equal(entries.size(), 5, "Enemy and outcome events should all map to explanation entries.")
	assert_true(String(entries[0].get("summary", "")).contains("marked"), "Mark entries should be readable.")
	assert_true(String(entries[1].get("summary", "")).contains("detonated"), "Detonation entries should be readable.")
	assert_true(String(entries[2].get("summary", "")).contains("blocked"), "Wait entries should include wait reasons.")
	assert_equal(entries[3].get("event_id"), "level_victory_reached", "Victory entries should preserve outcome event ids.")
	assert_equal(entries[4].get("event_id"), "level_defeat_reached", "Defeat entries should preserve outcome event ids.")


func _unknown_events_produce_stable_generic_entries() -> void:
	var event: DomainEvent = DomainEvent.new(DomainEvent.Type.UNKNOWN, 99, &"future_actor", {"future": "value"})

	var entries: Array[Dictionary] = CombatExplanationLog.new().build_entries([event])

	assert_equal(entries.size(), 1, "Unknown events should still produce generic entries.")
	assert_equal(entries[0].get("entry_id"), "unknown:99", "Unknown entries should have stable ids.")
	assert_true(String(entries[0].get("summary", "")).contains("unknown"), "Unknown entries should explain that a generic event occurred.")
	assert_equal(entries[0].get("details", {}).get("future"), "value", "Unknown entries should preserve event payload details.")


func _entries_are_reproducible_from_same_event_log() -> void:
	var events: Array[DomainEvent] = [
		DomainEvent.entity_moved(2, &"hero", Vector2i(0, 2), Vector2i(1, 2), 1, 3),
		DomainEvent.damage_applied(3, &"enemy_iron", &"hero", 3, 18, 15, 18, _damage_payload("iron_cultist_melee", 3))
	]
	var first_entries: Array[Dictionary] = CombatExplanationLog.new().build_entries(events)
	var second_entries: Array[Dictionary] = CombatExplanationLog.new().build_entries(events)

	assert_equal(first_entries, second_entries, "Explanation logs should be deterministic for the same event log.")


func _entry_ids(entries: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in entries:
		result.append(String(entry.get("entry_id", "")))
	return result


func _attack_payload(weapon_id: String, damage: int) -> Dictionary:
	return {
		"actor_id": "hero",
		"expected_base_damage": damage,
		"range": 1,
		"distance": 1,
		"line_cells": [{"x": 1, "y": 2}, {"x": 2, "y": 2}],
		"blocker_cells": [],
		"blocker_ignored": false,
		"warnings": [],
		"effects": [],
		"explanation": "%s previews %s damage." % [weapon_id, damage]
	}


func _damage_payload(weapon_id: String, damage: int) -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"base_damage": damage,
		"support_bonus_damage": 0,
		"armor_reduction": 0,
		"block_succeeded": false,
		"final_damage": damage,
		"damage_type": "physical",
		"rng_draws": []
	}


func _mark_payload() -> Dictionary:
	return {
		"kind": "ash_seer_mark",
		"source_entity_id": "enemy_seer",
		"enemy_definition_id": "ash_seer",
		"created_turn_number": 1,
		"due_turn_number": 2,
		"damage": 4,
		"damage_type": "physical",
		"status": "pending",
		"explanation": "Ash Seer marked hero at (1,2)."
	}


func _detonation_payload() -> Dictionary:
	return {
		"damage": 4,
		"damage_type": "physical",
		"action_id": "detonate",
		"score": 120,
		"reasons": ["due_mark"],
		"explanation": "Ash Seer mark detonated at (1,2)."
	}


func _wait_payload() -> Dictionary:
	return {
		"enemy_definition_id": "iron_cultist",
		"action_id": "wait",
		"score": 0,
		"reasons": ["no_legal_approach"],
		"explanation": "enemy_iron waited: blocked."
	}
