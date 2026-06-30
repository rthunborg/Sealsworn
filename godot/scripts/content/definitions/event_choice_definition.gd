class_name EventChoiceDefinition
extends Resource

# A single CHOICE on a risk/reward EventDefinition (Story 7.3, FR54) — the typed, validated sub-resource that carries
# ONE option the player may take at a risk/reward event node: a readable `choice_text`, a REWARD side (gold/healing
# benefit), and a RISK side (curse/corruption increment + an optional resource cost + the risk-flag id(s) the choice
# RAISES). It is the per-choice tradeoff contract the GDD "tempting choices with known risks" / "the player understands
# the trade before accepting" demands (GDD lines 461-471). [Decision] A typed sub-resource (NOT a plain-dict list) is
# used because it gives the cleaner per-field validate() surface (the story's stated preference) — each choice
# re-validates exactly like a top-level definition.
#
# THE PER-CHOICE TRADEOFF CONTRACT:
#   - choice_id:           lower_snake stable id (validated), UNIQUE within its event (the parent enforces uniqueness).
#   - choice_text:         the readable option line (non-empty) — what the player reads BEFORE choosing.
#   - the REWARD side (what the choice GIVES): gold_benefit / healing_benefit (each >= 0; default 0).
#   - the RISK side (what the choice COSTS / records): curse_increment / corruption_increment (the curse/corruption
#                          risk; each >= 0) + an OPTIONAL resource cost gold_cost / healing_cost (each >= 0) +
#                          risk_flags (an Array[String] of lower_snake risk-flag ids the choice RAISES — the AC2
#                          "future systems can query the resulting risk flags" PRODUCER; default empty).
#
# A choice is a GENUINE RISK TRADEOFF when it has BOTH a reward field > 0 AND a risk field > 0 OR a raised risk flag
# (is_genuine_tradeoff()). A "safe / decline / leave" choice (no reward, no risk, no flag) is a VALID additional
# option (the GDD "If the player always chooses safety, rewards are too weak" — safety grants little/nothing and
# raises no risk), but the parent EventDefinition must offer AT LEAST ONE genuine tradeoff (the node must be a real
# decision). is_safe() reports a no-reward-no-risk-no-flag choice.
#
# DIFFICULTY IS A HARD NON-GOAL (project-context): a risk flag is a RECORDED player-facing future-danger marker (e.g.
# `elite_chance` records "the player chose to increase elite chance later") — it is NOT a difficulty knob / multiplier
# (7.3 is the PRODUCER; the system that READS a flag and alters generation is a later story). No choice field scales
# enemy stats/HP/damage/rewards/RNG/run length.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

@export var choice_id: StringName = &""
@export var choice_text: String = ""
# The REWARD side (what the choice GIVES) — the economy-side credit. Each a small bounded NON-NEGATIVE int (default 0).
@export var gold_benefit: int = 0
@export var healing_benefit: int = 0
# The RISK side (what the choice COSTS / records) — the curse/corruption increment + an optional resource cost. Each a
# small bounded NON-NEGATIVE int (default 0).
@export var curse_increment: int = 0
@export var corruption_increment: int = 0
@export var gold_cost: int = 0
@export var healing_cost: int = 0
# The risk-flag id(s) this choice RAISES (the AC2 "future systems can query the resulting risk flags" producer). A
# plain Array[String] of lower_snake ids (default empty). A non-lower_snake / blank / duplicate flag id is rejected by
# validate().
@export var risk_flags: Array[String] = []

func _init(
	new_choice_id: StringName = &"",
	new_choice_text: String = "",
	new_gold_benefit: int = 0,
	new_healing_benefit: int = 0,
	new_curse_increment: int = 0,
	new_corruption_increment: int = 0,
	new_gold_cost: int = 0,
	new_healing_cost: int = 0,
	new_risk_flags: Array = []
) -> void:
	choice_id = new_choice_id
	choice_text = new_choice_text
	gold_benefit = new_gold_benefit
	healing_benefit = new_healing_benefit
	curse_increment = new_curse_increment
	corruption_increment = new_corruption_increment
	gold_cost = new_gold_cost
	healing_cost = new_healing_cost
	# Copy the input into a typed Array[String] (a typed @export array assigned an untyped literal at a call site
	# would otherwise share the reference / mis-type). Keep raw entries verbatim so validate() can REJECT a bad one
	# (do NOT silently drop a malformed flag here — the definition author must fix it).
	var copied_flags: Array[String] = []
	for flag_value: Variant in new_risk_flags:
		copied_flags.append(String(flag_value))
	risk_flags = copied_flags


# Pure read: validate every per-choice field. Returns ok or a per-field invalid_event_definition error (the offending
# field in metadata). The parent EventDefinition.validate() calls this for each choice and prefixes the choice index.
func validate() -> ActionResult:
	if not _is_lower_snake_id(choice_id):
		return _invalid(&"choice_id")
	if choice_text.strip_edges().is_empty():
		return _invalid(&"choice_text")
	# The benefit/cost/increment ints are NON-NEGATIVE (a credit/cost/increment amount is never negative — REJECT,
	# never coerce; the CursedRewardDefinition discipline).
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
	# Each raised risk flag must be a non-blank lower_snake id, and the list must carry no duplicate (a duplicate is a
	# definition error — add_risk_flag is idempotent at runtime, but a duplicate in the AUTHORED list signals a typo).
	var seen: Dictionary = {}
	for flag_value: Variant in risk_flags:
		if not (flag_value is String or flag_value is StringName):
			return _invalid(&"risk_flags")
		var flag_text: String = String(flag_value)
		if not _is_lower_snake_id(flag_text):
			return _invalid(&"risk_flags")
		if seen.has(flag_text):
			return _invalid(&"risk_flags")
		seen[flag_text] = true
	return ActionResult.ok()


# True when this choice grants at least one economy-side reward (the upside half of the tradeoff).
func has_reward() -> bool:
	return gold_benefit > 0 or healing_benefit > 0


# True when this choice imposes at least one risk (a curse/corruption increment, a resource cost, OR a raised risk
# flag) — the downside / recorded-danger half of the tradeoff.
func has_risk() -> bool:
	return curse_increment > 0 or corruption_increment > 0 or gold_cost > 0 or healing_cost > 0 or not risk_flags.is_empty()


# True when this choice is a GENUINE risk tradeoff: it both GIVES a reward AND carries a risk (a curse/corruption
# increment, a resource cost, OR a raised flag). The parent EventDefinition requires >= 1 such choice so the node is a
# real decision (not a free reward or a pure penalty).
func is_genuine_tradeoff() -> bool:
	return has_reward() and has_risk()


# True when this choice is a "safe / decline / leave" option: NO reward AND NO risk AND NO raised flag (it grants
# little/nothing and raises no danger). A safe option is a VALID additional choice but is NOT a genuine tradeoff.
func is_safe() -> bool:
	return not has_reward() and not has_risk()


# True when this choice applies a curse/corruption increment (it carries a curse RISK). The choose command reads this
# to decide whether to emit the curse_applied event half.
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
	return ActionResult.error(&"invalid_event_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
