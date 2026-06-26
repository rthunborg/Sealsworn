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
# STORY 6.4 EXTENSION (additive — the EXACT pattern Story 6.3 used to extend RewardTableDefinition; this is
# STILL the ONE passive type, NOT a forked "reward passive"): the FR47 passive-reward MODAL data contract +
# the FR77 served-pillar field are added as NEW @export fields + NEW trailing _init params + NEW validate()
# branches, keeping every existing field/validation/call-site unchanged:
#   - icon:                     a lower_snake icon-asset id, OR the ICON_PLACEHOLDER sentinel when no icon art
#                               exists yet (an art-less passive is VALID with the placeholder — never a crash
#                               / empty-icon surprise). The real icon ART + the modal SCENE are a later HUD/
#                               asset story; this field is the icon ID/placeholder STRING only.
#   - flavor:                   one short fiction line (FR47 "one short flavor line") — non-empty.
#   - exact_mechanical_effects: the EXPLICIT player/debug-readable mechanics string (FR47 / GDD line 340 —
#                               "Flavor can be mysterious, but mechanics must be explicit"). REQUIRED non-empty:
#                               a passive can never ship with mysterious mechanics. In v0 this is an AUTHORED
#                               string (passives are EXPLANATION-ONLY); a later operations story MAY make it a
#                               resolver-computed value.
#   - consume_text:             what Consume gives (power / build identity, GDD line 344) — non-empty.
#   - destroy_text:             what Destroy gives (safety / purification / resources / refusal, GDD line 345) —
#                               non-empty.
#   - has_unknown_consequences + consequences_text: the STRUCTURED honest-unknown downside contract (GDD line
#                               340 "If Destroy has unknown consequences, label it honestly as unknown"). When
#                               has_unknown_consequences == false, consequences_text states the KNOWN downside
#                               (or "no downside"); when true, consequences_text is the honest-unknown line.
#                               validate() rejects a BLANK consequences_text regardless — "we forgot to say" is
#                               invalid, but "honestly unknown" is valid + surfaced. This is the difference
#                               between HIDING a downside (invalid) and HONESTLY saying it is unknown (valid).
#   - served_pillars:           the FR77 design-pillar field (GDD line 329) — at least one pillar, EACH from the
#                               FIXED four-pillar allowlist (tactical_clarity / build_synergy / risk / mystery).
#                               A mechanically-complete-but-pillarless passive is INVALID.
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

# Story 6.4 — the icon placeholder sentinel. An art-less passive is VALID with this id (the real icon art is a
# later HUD/asset story; the modal surfaces this stable placeholder string, never an empty/crashing icon).
const ICON_PLACEHOLDER := &"passive_icon_placeholder"

# Story 6.4 (FR77) — the FIXED four design pillars a passive may serve (GDD line 329). A passive's
# served_pillars must be a non-empty subset of these (mirrors the PASSIVE_KINDS allowlist idiom). Do NOT add,
# rename, or renumber these — they are the GDD design vocabulary.
const PILLAR_TACTICAL_CLARITY := &"tactical_clarity"
const PILLAR_BUILD_SYNERGY := &"build_synergy"
const PILLAR_RISK := &"risk"
const PILLAR_MYSTERY := &"mystery"

const SERVED_PILLARS: Array[StringName] = [
	PILLAR_TACTICAL_CLARITY,
	PILLAR_BUILD_SYNERGY,
	PILLAR_RISK,
	PILLAR_MYSTERY
]

@export var passive_id: StringName = &""
@export var display_name: String = ""
@export var passive_kind: StringName = &""
@export var trigger_windows: Array[StringName] = []
@export var explanation: String = ""
# Story 6.4 — the FR47 passive-reward MODAL data contract (additive). See the header for the per-field contract.
@export var icon: StringName = ICON_PLACEHOLDER
@export var flavor: String = ""
@export var exact_mechanical_effects: String = ""
@export var consume_text: String = ""
@export var destroy_text: String = ""
@export var has_unknown_consequences: bool = false
@export var consequences_text: String = ""
# Story 6.4 — the FR77 served-pillar field (at least one, each from SERVED_PILLARS).
@export var served_pillars: Array[StringName] = []

func _init(
	new_passive_id: StringName = &"",
	new_display_name: String = "",
	new_passive_kind: StringName = &"",
	new_trigger_windows: Array = [],
	new_explanation: String = "",
	new_icon: StringName = ICON_PLACEHOLDER,
	new_flavor: String = "",
	new_exact_mechanical_effects: String = "",
	new_consume_text: String = "",
	new_destroy_text: String = "",
	new_has_unknown_consequences: bool = false,
	new_consequences_text: String = "",
	new_served_pillars: Array = []
) -> void:
	passive_id = new_passive_id
	display_name = new_display_name
	passive_kind = new_passive_kind
	trigger_windows = _copy_ids(new_trigger_windows)
	explanation = new_explanation
	icon = new_icon
	flavor = new_flavor
	exact_mechanical_effects = new_exact_mechanical_effects
	consume_text = new_consume_text
	destroy_text = new_destroy_text
	has_unknown_consequences = new_has_unknown_consequences
	consequences_text = new_consequences_text
	served_pillars = _copy_ids(new_served_pillars)


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
	# Story 6.4 — the FR47 modal fields (REJECT, never coerce — a passive can never ship a blank required field).
	# icon must be a lower_snake id (the placeholder sentinel is itself lower_snake, so it passes naturally).
	if not _is_lower_snake_id(icon):
		return _invalid(&"icon")
	if flavor.strip_edges().is_empty():
		return _invalid(&"flavor")
	# Mechanics MUST be explicit even when flavor is mysterious (AC1/AC3; GDD line 340).
	if exact_mechanical_effects.strip_edges().is_empty():
		return _invalid(&"exact_mechanical_effects")
	if consume_text.strip_edges().is_empty():
		return _invalid(&"consume_text")
	if destroy_text.strip_edges().is_empty():
		return _invalid(&"destroy_text")
	# The honest-unknown downside contract: consequences_text is REQUIRED non-empty whether or not the downside
	# is unknown — a passive must EITHER state a known downside OR honestly mark it unknown, never leave it blank
	# (AC3 "unclear downside fields" — "we forgot to say" is invalid; "honestly unknown" is valid + surfaced).
	if consequences_text.strip_edges().is_empty():
		return _invalid(&"consequences_text")
	# Story 6.4 (FR77/AC4) — at least one served pillar, each from the fixed allowlist. A mechanically-complete
	# but pillarless passive is INVALID.
	if served_pillars.is_empty():
		return _invalid(&"served_pillars")
	for pillar_id: StringName in served_pillars:
		if not SERVED_PILLARS.has(pillar_id):
			return _invalid(&"served_pillars")
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
