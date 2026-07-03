class_name BossPhaseTransition
extends RefCounted

# One applied Larval Avatar PHASE TRANSITION (Story 9.2, AC2/AC3) — the pure value object the BossPhaseResolver returns
# for each phase the boss ENTERS as its HP falls past a threshold. It is the resolver's honest, readable record of a
# single forward step (from_phase -> to_phase), carrying the entered phase's id, the trigger marker, and a readable
# explanation. The live-loop caller (9.3) turns each transition into a boss_phase_changed DomainEvent via to_payload().
#
# It is a PURE DTO (a RefCounted, NOT seated on RunState) — 9.2 ships the phase MODEL (definition + resolver + event);
# it does NOT persist phase state or add a RunSnapshot key (the live phase state is 9.3/9.4's live-loop concern). A
# transition is always FORWARD (to_phase == from_phase + 1 — the resolver emits ONE per phase entered, in order, so a
# multi-threshold-in-one-hit crossing produces a CHAIN of adjacent transitions and no phase is skipped in the log).
#
# TRIGGER markers (lower_snake): TRIGGER_HP_THRESHOLD is the only v0 trigger (the boss crossed an HP % threshold). A
# scripted-trigger id would be a distinct marker, but v0's phases are purely HP-threshold gated (FR63 minimal scope).

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const TRIGGER_HP_THRESHOLD := &"hp_threshold"

var boss_id: StringName = &""
var from_phase: int = 0
var to_phase: int = 0
var phase_id: StringName = &""
var trigger: StringName = TRIGGER_HP_THRESHOLD
var explanation: String = ""

func _init(
	new_boss_id: StringName = &"",
	new_from_phase: int = 0,
	new_to_phase: int = 0,
	new_phase_id: StringName = &"",
	new_trigger: StringName = TRIGGER_HP_THRESHOLD,
	new_explanation: String = ""
) -> void:
	boss_id = new_boss_id
	from_phase = new_from_phase
	to_phase = new_to_phase
	phase_id = new_phase_id
	trigger = new_trigger
	explanation = new_explanation


# The boss_phase_changed event payload for this transition (the fields DomainEvent.boss_phase_changed normalizes +
# _validate_boss_phase_changed_payload checks). A plain serializable dict — no live RefCounted, survives a JSON
# round-trip. The forward-only from_phase/to_phase satisfy the event's to_phase > from_phase rule by construction.
func to_payload() -> Dictionary:
	return {
		"boss_entity_id": String(boss_id),
		"from_phase": from_phase,
		"to_phase": to_phase,
		"phase_id": String(phase_id),
		"trigger": String(trigger)
	}
