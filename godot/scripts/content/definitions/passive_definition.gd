class_name PassiveDefinition
extends Resource

# A typed, validated passive rule-bender definition (Story 5.4) — the content-layer truth for a class's
# STARTING passive. It is mirrored from an APPROVED code-constant baseline through the ContentRepository
# boundary, EXACTLY like ClassDefinition / SupportDefinition / EnemyDefinition (same typed-Resource +
# validate() + lower_snake-id discipline). This is the FIRST passive type in the project; it introduces the
# passive system from an empty scaffold.
#
# LEAN v0 SCHEMA ([Decision], per the story AC-interpretation notes): a passive carries only what the
# STARTING-passive seam needs to REGISTER + EXPLAIN + assert no-active-skill:
#   - passive_id:      lower_snake stable id (validated by _is_lower_snake_id).
#   - display_name:    the evocative human-facing name (FR47) — non-empty; feeds the explanation surface.
#   - passive_kind:    a stable lower_snake category distinguishing the two FR44 starting-passive roles
#                      (KIND_CLASS vs KIND_EQUIPMENT_SYNERGY) — validated against a small allowlist.
#   - trigger_windows: one or more trigger-window ids from the FIXED RuleTrigger vocabulary — EACH validated
#                      against RuleTrigger.is_valid_window(...); at least one is required (the "explicit
#                      trigger windows" AC1 demands).
#   - explanation:     the player/debug-readable line the resolver surfaces (the architecture's Readability
#                      Rule) — non-empty.
#
# DELIBERATELY ABSENT (FR45 / AC3 + scope discipline): there is NO active-skill field, NO level/cooldown/
# activation field, NO RNG field, and NO concrete operation/effect-amount model. v0 starting passives are
# PASSIVE + EXPLANATION-ONLY rule-benders; the actual damage/movement OPERATION is deferred to Story 5.5 /
# Epic 6, and AC3 forbids any active-skill concept on this type. Adding any of those would pull in Epic-6
# scope and/or violate AC3.
#
# Mirrors support_definition.gd in shape: a DEFINITION_TYPE const, category consts, @export fields, _init,
# validate() -> ActionResult returning invalid_passive_definition + {reason:"invalid_field", field:...} on a
# bad field, and the shared _is_lower_snake_id helper.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")

const DEFINITION_TYPE := &"passive"

# The two FR44 starting-passive roles: a class passive vs an equipment-synergy passive. A passive's
# passive_kind MUST be one of these (the validate() allowlist).
const KIND_CLASS := &"class"
const KIND_EQUIPMENT_SYNERGY := &"equipment_synergy"

const PASSIVE_KINDS: Array[StringName] = [
	KIND_CLASS,
	KIND_EQUIPMENT_SYNERGY
]

@export var passive_id: StringName = &""
@export var display_name: String = ""
@export var passive_kind: StringName = &""
@export var trigger_windows: Array[StringName] = []
@export var explanation: String = ""

func _init(
	new_passive_id: StringName = &"",
	new_display_name: String = "",
	new_passive_kind: StringName = &"",
	new_trigger_windows: Array = [],
	new_explanation: String = ""
) -> void:
	passive_id = new_passive_id
	display_name = new_display_name
	passive_kind = new_passive_kind
	trigger_windows = _copy_ids(new_trigger_windows)
	explanation = new_explanation


func validate() -> ActionResult:
	if not _is_lower_snake_id(passive_id):
		return _invalid(&"passive_id")
	if display_name.strip_edges().is_empty():
		return _invalid(&"display_name")
	if not PASSIVE_KINDS.has(passive_kind):
		return _invalid(&"passive_kind")
	if trigger_windows.is_empty():
		return _invalid(&"trigger_windows")
	for window_id: StringName in trigger_windows:
		if not RuleTrigger.is_valid_window(window_id):
			return _invalid(&"trigger_windows")
	if explanation.strip_edges().is_empty():
		return _invalid(&"explanation")
	return ActionResult.ok()


# True when this passive declares `window_id` as one of its trigger windows. The RulesResolver uses this to
# collect the passives that fire in a given window.
func fires_in_window(window_id: StringName) -> bool:
	return trigger_windows.has(window_id)


static func _copy_ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(str(value)))
	return result


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
	return ActionResult.error(&"invalid_passive_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
