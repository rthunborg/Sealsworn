class_name CurseDefinition
extends Resource

# A typed, validated CURSE/CORRUPTION EFFECT definition (Story 7.2, AC3) — a RULE SOURCE the RulesResolver resolves
# deterministically ALONGSIDE passives. It is the curse/corruption analogue of PassiveDefinition as a rule source: it
# DECLARES the trigger window(s) it fires in (from the FIXED RuleTrigger vocabulary, EXACTLY like a passive) and
# surfaces an explanation that IDENTIFIES THE CURSE/CORRUPTION SOURCE (AC3 "its explanation identifies the curse or
# corruption source").
#
# [Decision] Option A (the LEANER of the two CRITICAL-DESIGN-DECISION options): a CurseDefinition satisfies the SAME
# fires_in_window(window_id) + explanation shape the resolver already reads off a PassiveDefinition. The resolver keeps
# a SEPARATE Array[CurseDefinition] registry (NOT a broadened Array typing on the existing passive registry — that
# would force an ugly cast and risk the 5.4 typed-passive contract / a re-pin of existing tests) and MERGES curses
# into explain(window) AFTER passives in stable registration order. resolve(window) keeps its strict
# Array[PassiveDefinition] return; resolve_curses(window) returns the matching curses; explain(window) is the unified
# source-identifying surface (passive explanations then curse explanations, stable order). This is the smallest change
# that keeps the resolver a PURE READ and surfaces curses + passives together deterministically.
#
# v0 is EXPLANATION-ONLY (the SAME bar v0 passives meet — Story 5.4): resolving a curse window surfaces the curse + its
# source-identifying explanation; it does NOT mutate a combat HP/damage number (the per-effect OPERATION engine is the
# later operations story — scripts/rules/{conditions,operations} stay EMPTY). The economy-side curse_count/corruption
# increment is applied by AcceptCursedRewardCommand / the cleanse hook, NOT by the resolver (the resolver draws NO RNG,
# runs NO command, mutates nothing).
#
# Mirrors PassiveDefinition's rule-source shape (a DEFINITION_TYPE const, @export id + trigger_windows + explanation,
# _init, validate() -> ActionResult with invalid_*_definition + {reason:"invalid_field", field:...}, fires_in_window,
# the _is_lower_snake_id helper) — keeping ONLY the rule-source members the resolver reads (no Consume/Destroy/pillar
# modal fields; a curse is not an offered passive).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")

const DEFINITION_TYPE := &"curse"

@export var curse_id: StringName = &""
# The SOURCE this curse originates from (AC3) — a lower_snake marker id (e.g. the originating cursed_reward_id, or a
# cleanse marker). The explanation must name this so AC3's "identifies the curse or corruption source" holds; the
# command also carries it into the curse-change event's curse_source field.
@export var curse_source: StringName = &""
@export var display_name: String = ""
@export var trigger_windows: Array[StringName] = []
# The player/debug-readable line the resolver surfaces (the architecture's Readability Rule). REQUIRED non-empty AND
# REQUIRED to NAME the source (validate() asserts the explanation contains the curse_source marker text) so a curse can
# never resolve with a source-anonymous explanation (AC3).
@export var explanation: String = ""

func _init(
	new_curse_id: StringName = &"",
	new_curse_source: StringName = &"",
	new_display_name: String = "",
	new_trigger_windows: Array = [],
	new_explanation: String = ""
) -> void:
	curse_id = new_curse_id
	curse_source = new_curse_source
	display_name = new_display_name
	trigger_windows = _copy_ids(new_trigger_windows)
	explanation = new_explanation


func validate() -> ActionResult:
	if not _is_lower_snake_id(curse_id):
		return _invalid(&"curse_id")
	if not _is_lower_snake_id(curse_source):
		return _invalid(&"curse_source")
	if display_name.strip_edges().is_empty():
		return _invalid(&"display_name")
	if trigger_windows.is_empty():
		return _invalid(&"trigger_windows")
	for window_id: StringName in trigger_windows:
		if not RuleTrigger.is_valid_window(window_id):
			return _invalid(&"trigger_windows")
	if explanation.strip_edges().is_empty():
		return _invalid(&"explanation")
	# AC3: the explanation MUST identify the source. A curse that resolves with an explanation that does not name its
	# source marker would silently violate AC3 — reject it (the source id text must appear in the explanation).
	if not explanation.contains(String(curse_source)):
		return _invalid(&"explanation")
	return ActionResult.ok()


# True when this curse declares `window_id` as one of its trigger windows. The RulesResolver uses this to collect the
# curses that fire in a given window (mirroring PassiveDefinition.fires_in_window).
func fires_in_window(window_id: StringName) -> bool:
	return trigger_windows.has(window_id)


# Build a curse effect for an accepted cursed reward (AC3): the curse_id + the source marker derive from the
# cursed_reward_id, the explanation names the source. It declares the LEVEL_ENTERED window (the curse's bite is felt as
# the run continues — a fixed, valid window from the RuleTrigger vocabulary; v0 is explanation-only, so the window
# choice surfaces the curse without firing a combat operation). A single canonical factory keeps the seated curse
# consistent between AcceptCursedRewardCommand and the tests.
static func for_cursed_reward(cursed_reward_id: StringName, display_name: String) -> CurseDefinition:
	var source: String = String(cursed_reward_id)
	return load("res://scripts/content/definitions/curse_definition.gd").new(
		StringName("curse_" + source),
		cursed_reward_id,
		display_name,
		[RuleTrigger.LEVEL_ENTERED],
		"Curse from %s: its hold tightens when a new level is entered, exacting the price of the cursed reward." % source
	)


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
	return ActionResult.error(&"invalid_curse_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
