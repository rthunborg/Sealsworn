class_name CursedRewardDefinition
extends Resource

# A typed, validated CURSED-REWARD definition (Story 7.2, FR55) — the content-layer truth for a risky reward that
# carries a CLEAR upside AND a CLEAR downside (the AC1 tradeoff contract; GDD lines 459-462). It mirrors
# GoldRewardDefinition / DestroyOutcomeTableDefinition / PassiveDefinition VERBATIM in shape: a DEFINITION_TYPE const,
# @export fields, an _init copying inputs, validate() -> ActionResult returning invalid_cursed_reward_definition +
# {reason:"invalid_field", field:...} per field, and the shared _is_lower_snake_id helper. It is mirrored from an
# APPROVED code-constant baseline through the CursedRewardRepository boundary (NO JSON pipeline — data/source and
# data/resources stay empty; the Epic-6 content-as-code-constant posture).
#
# THE AC1 TRADEOFF CONTRACT (a cursed reward is a GENUINE tradeoff, never a free reward or a pure penalty):
#   - cursed_reward_id:        lower_snake stable id (validated).
#   - display_name:            the evocative human-facing name (non-empty) — feeds the view model.
#   - upside_text:             the CLEAR UPSIDE the player gains (non-empty — AC1 "clear upside ... before acceptance";
#                              GDD line 460 "A cursed reward has a clear upside").
#   - downside_text:           the CLEAR DOWNSIDE the player pays (non-empty — AC1 "clear downside"; GDD line 459 "A
#                              curse has a clear downside").
#   - the BENEFIT (what accept GIVES): gold_benefit / healing_benefit (each >= 0). The benefit is modeled as the
#                              ECONOMY side (gold/healing) in v0 — a "strong passive" benefit is OUT of scope as a
#                              literal passive grant (it would couple to the 6.5 Consume flow; a later reward-flow
#                              concern). [Decision] recorded in the story.
#   - the PENALTY (what accept COSTS): curse_increment / corruption_increment (the headline curse/corruption cost) +
#                              optionally gold_cost / healing_cost (a resource cost). Each >= 0.
#   - the HONEST hidden/delayed-consequence contract (AC1 "hidden or delayed consequences are labeled honestly"):
#                              has_delayed_consequences (default false) + consequences_text. Mirrors PassiveDefinition.
#                              has_unknown_consequences/consequences_text VERBATIM: consequences_text is REQUIRED
#                              non-empty whether or not there is a delayed consequence — a blank is INVALID ("we forgot
#                              to say"), but a stated KNOWN-downside line OR an honest "a future penalty, exact form
#                              unknown" line is VALID + surfaced. This is the difference between HIDING a consequence
#                              (invalid) and HONESTLY labeling it (valid).
#
# validate() rejects fail-loud (never coerce): a non-lower_snake cursed_reward_id; a blank display_name / upside_text /
# downside_text / consequences_text; a negative benefit/penalty/cost int; AND a NO-TRADEOFF definition (a cursed reward
# with no benefit AND no penalty is meaningless — it requires at least one benefit field > 0 AND at least one penalty
# field > 0, so it is a genuine tradeoff). The no-tradeoff rule is explicit + tested.
#
# DIFFICULTY IS A HARD NON-GOAL (project-context): a curse/corruption value is NOT a difficulty knob — nothing here
# scales enemy stats/HP/damage/rewards/RNG/run length. A cursed reward is a readable player-facing tradeoff.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"cursed_reward"

@export var cursed_reward_id: StringName = &""
@export var display_name: String = ""
@export var upside_text: String = ""
@export var downside_text: String = ""
# The BENEFIT (what accept GIVES) — the economy-side credit. Each a small bounded NON-NEGATIVE int (default 0).
@export var gold_benefit: int = 0
@export var healing_benefit: int = 0
# The PENALTY (what accept COSTS) — the curse/corruption increment (the headline) + an optional resource cost. Each a
# small bounded NON-NEGATIVE int (default 0).
@export var curse_increment: int = 0
@export var corruption_increment: int = 0
@export var gold_cost: int = 0
@export var healing_cost: int = 0
# The HONEST hidden/delayed-consequence contract (mirrors PassiveDefinition.has_unknown_consequences/consequences_text).
@export var has_delayed_consequences: bool = false
@export var consequences_text: String = ""

func _init(
	new_cursed_reward_id: StringName = &"",
	new_display_name: String = "",
	new_upside_text: String = "",
	new_downside_text: String = "",
	new_gold_benefit: int = 0,
	new_healing_benefit: int = 0,
	new_curse_increment: int = 0,
	new_corruption_increment: int = 0,
	new_gold_cost: int = 0,
	new_healing_cost: int = 0,
	new_has_delayed_consequences: bool = false,
	new_consequences_text: String = ""
) -> void:
	cursed_reward_id = new_cursed_reward_id
	display_name = new_display_name
	upside_text = new_upside_text
	downside_text = new_downside_text
	gold_benefit = new_gold_benefit
	healing_benefit = new_healing_benefit
	curse_increment = new_curse_increment
	corruption_increment = new_corruption_increment
	gold_cost = new_gold_cost
	healing_cost = new_healing_cost
	has_delayed_consequences = new_has_delayed_consequences
	consequences_text = new_consequences_text


func validate() -> ActionResult:
	if not _is_lower_snake_id(cursed_reward_id):
		return _invalid(&"cursed_reward_id")
	if display_name.strip_edges().is_empty():
		return _invalid(&"display_name")
	# AC1: the clear upside + clear downside text are REQUIRED non-empty (a cursed reward must be readable before
	# acceptance — GDD lines 459-460).
	if upside_text.strip_edges().is_empty():
		return _invalid(&"upside_text")
	if downside_text.strip_edges().is_empty():
		return _invalid(&"downside_text")
	# The benefit/penalty/cost ints are NON-NEGATIVE (a credit/cost amount is never negative — REJECT, never coerce).
	if gold_benefit < 0:
		return _invalid(&"gold_benefit")
	if healing_benefit < 0:
		return _invalid(&"healing_benefit")
	if curse_increment < 0:
		return _invalid(&"curse_increment")
	if corruption_increment < 0:
		return _invalid(&"corruption_increment")
	if gold_cost < 0:
		return _invalid(&"gold_cost")
	if healing_cost < 0:
		return _invalid(&"healing_cost")
	# The honest hidden/delayed-consequence contract: consequences_text is REQUIRED non-empty whether or not the
	# consequence is delayed — a cursed reward must EITHER state a known downside OR honestly mark a future one, never
	# leave it blank (AC1 "hidden or delayed consequences are labeled honestly" — "we forgot to say" is invalid;
	# "honestly unknown" is valid + surfaced).
	if consequences_text.strip_edges().is_empty():
		return _invalid(&"consequences_text")
	# The NO-TRADEOFF reject: a cursed reward must be a GENUINE tradeoff — at least one benefit field > 0 AND at least
	# one penalty field > 0. A reward with no upside is a pure penalty; a reward with no downside is a free reward;
	# neither is a "cursed reward" (AC1 "clear upside AND clear downside").
	if not _has_benefit():
		return _invalid(&"gold_benefit")
	if not _has_penalty():
		return _invalid(&"curse_increment")
	return ActionResult.ok()


# True when this cursed reward grants at least one economy-side benefit (the upside half of the tradeoff).
func _has_benefit() -> bool:
	return gold_benefit > 0 or healing_benefit > 0


# True when this cursed reward imposes at least one penalty (a curse/corruption increment and/or a resource cost) —
# the downside half of the tradeoff.
func _has_penalty() -> bool:
	return curse_increment > 0 or corruption_increment > 0 or gold_cost > 0 or healing_cost > 0


# True when accepting this cursed reward applies a curse/corruption increment (i.e. it carries a curse EFFECT). The
# accept command + the rules-kernel seating read this to decide whether to seat a curse rule source on the resolver.
func applies_curse() -> bool:
	return curse_increment > 0 or corruption_increment > 0


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
	return ActionResult.error(&"invalid_cursed_reward_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
