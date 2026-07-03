class_name BossActionDefinition
extends Resource

# A single ACTION the Larval Avatar boss may take within a phase (Story 9.2, FR63, AC1) — the typed, validated
# sub-resource that unifies AC1's "legal actions", "telegraph definitions", and "damage rules" into ONE per-phase
# entry: a LEGAL action carries the TELEGRAPH the player reads BEFORE it lands + the DAMAGE it applies + a readable
# EXPLANATION. It is the boss-content analogue of EventChoiceDefinition (a typed sub-resource with a per-field
# validate() surface, the story's stated preference) — each action re-validates exactly like a top-level definition.
#
# WHY A DEDICATED ACTION SUB-RESOURCE (not a reused EnemyDefinition behavior): the boss has a MULTI-action set PER
# PHASE (unlike the flat two-behavior EnemyDefinition), each with its own telegraph line + damage — a distinct shape.
# Story 9.2 authors these action/telegraph/damage DEFINITIONS as content; Story 9.3 SELECTS an action (utility scoring)
# and EMITS its telegraph at runtime. 9.2 does NOT select, score, or emit — it only exposes the validated per-phase
# legal-action SET (BossPhaseDefinition.legal_action_ids()) that 9.3's AI scores against.
#
# THE PER-ACTION CONTRACT (a legal boss action with a KNOWN telegraph + a KNOWN damage rule):
#   - action_id:      lower_snake stable id (validated), UNIQUE within its phase (the parent phase enforces uniqueness).
#   - telegraph_text: the readable line the player sees the turn BEFORE the action resolves (non-empty — the GDD
#                     "telegraphs" readability surface; a boss action without a telegraph is not readable). This IS the
#                     AC1 "telegraph definition" carried on the action.
#   - damage:         the damage the action applies (a small bounded NON-NEGATIVE int; default 0). A pure-telegraph /
#                     zero-damage action (e.g. a reposition/summon read) is legal (damage == 0); a negative damage is a
#                     definition error (REJECT, never coerce). This IS the AC1 "damage rule" carried on the action.
#   - damage_type:    the lower_snake damage kind (validated; e.g. physical/corruption) — the damage rule's type half.
#   - explanation:    a readable player/debug explanation of what the action does (non-empty — the architecture
#                     Readability Rule; every rule-driven boss outcome must be explainable).
#
# DIFFICULTY IS A HARD NON-GOAL (project-context): the boss's actions/telegraphs/damage are AUTHORED phase content, NOT
# a difficulty knob — nothing here scales by a selectable difficulty tier. Escalation is authored per-phase content.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DAMAGE_TYPE_PHYSICAL := &"physical"

@export var action_id: StringName = &""
@export var telegraph_text: String = ""
# The damage the action applies (a small bounded NON-NEGATIVE int; 0 == a pure-telegraph/no-damage action). REJECT < 0.
@export var damage: int = 0
@export var damage_type: StringName = DAMAGE_TYPE_PHYSICAL
@export var explanation: String = ""

func _init(
	new_action_id: StringName = &"",
	new_telegraph_text: String = "",
	new_damage: int = 0,
	new_damage_type: StringName = DAMAGE_TYPE_PHYSICAL,
	new_explanation: String = ""
) -> void:
	action_id = new_action_id
	telegraph_text = new_telegraph_text
	damage = new_damage
	damage_type = new_damage_type
	explanation = new_explanation


# Pure read: validate every per-action field. Returns ok or a per-field invalid_boss_definition error (the offending
# field in metadata). The parent BossPhaseDefinition.validate() calls this for each action and prefixes the phase +
# action index. Draws NO RNG, mutates nothing.
func validate() -> ActionResult:
	if not _is_lower_snake_id(action_id):
		return _invalid(&"action_id")
	if telegraph_text.strip_edges().is_empty():
		return _invalid(&"telegraph_text")
	# The damage is NON-NEGATIVE (0 is a legal pure-telegraph action; a negative amount is never valid — REJECT,
	# never coerce; the EnemyDefinition/EventChoiceDefinition discipline).
	if damage < 0:
		return _invalid(&"damage")
	if not _is_lower_snake_id(damage_type):
		return _invalid(&"damage_type")
	if explanation.strip_edges().is_empty():
		return _invalid(&"explanation")
	return ActionResult.ok()


static func _is_lower_snake_id(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	if text != text.to_lower():
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true


static func _invalid(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_boss_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
