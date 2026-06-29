class_name DestroyOutcomeTableDefinition
extends Resource

# A typed, validated DESTROY-OUTCOME table / pool definition (Story 6.6) — the approved 70/20/10 outcome pool a
# DestroyPassiveCommand rolls against when a player Destroys a passive (the SECOND half of the FR82 Consume/Destroy
# split; the Consume half — ConsumePassiveCommand — shipped in Story 6.5). It mirrors RewardTableDefinition's shape
# VERBATIM (DEFINITION_TYPE, @export fields, _init copying entries, validate() -> ActionResult returning per-field
# errors, the lower_snake / positive-int helpers, the visible-tuning-exception-marker precedent).
#
# An entry is a Dictionary {outcome_category, outcome_id, weight, effect, explanation}:
#   - outcome_category: one of the THREE FR50/GDD Destroy outcome categories (DESTROY_OUTCOME_CATEGORIES allowlist
#                       below) — small_immediate_benefit / progress_unlock_hidden_flag /
#                       no_obvious_reward_avoids_danger.
#   - outcome_id:       a lower_snake stable id for the specific outcome (the deterministic-roll target id).
#   - weight:           a positive int relative draw weight (the command weighted-picks by this).
#   - effect:           a non-empty player/debug-readable string describing the deterministic OUTCOME-RECORD effect
#                       (v0 Destroy is OUTCOME-RECORD-ONLY — the effect string describes the intended deterministic
#                       result; the live wallet/heal/cleanse/curse/meta mutation is Epic 7/8 + a later reward-flow
#                       story, wired off the recorded outcome_category/outcome_id).
#   - explanation:      a non-empty player/debug-readable explanation of the known result (the architecture's
#                       Readability Rule — the known result is communicated; an honest-unknown outcome is labeled
#                       honestly in its explanation, the 6.4 honest-unknown contract).
#
# validate() rejects fail-loud (never coerce): a non-lower_snake table_id; an empty table; a malformed/non-dict
# entry; an out-of-allowlist outcome_category; a non-lower_snake outcome_id; a non-positive weight; a blank effect;
# a blank explanation; AND the 70/20/10 distribution check (each category's summed weight as an EXACT integer
# fraction of the total — small * 10 == total * 7 AND progress * 10 == total * 2 AND no_reward * 10 == total * 1)
# UNLESS the explicit mvp_distribution_exception marker is set WITH a non-empty distribution_exception_reason.
#
# AC3 VISIBLE-TUNING-EXCEPTION MARKER (Story 6.6): the baseline create_baseline_table() ships AT EXACTLY 70/20/10
# with NO exception marker. The mvp_distribution_exception + distribution_exception_reason fields exist so a FUTURE
# story can temporarily ship an off-target table WITH a visible, reasoned marker (the 6.1 *_mvp_deferred / 6.3
# mvp_choice_count_exception posture — the exception is SURFACED via this validate() check + a tuning note, never a
# silent reduction). The marker WITHOUT a reason is rejected (distribution_exception_reason field).

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"destroy_outcome_table"

# The THREE fixed FR50/GDD Destroy outcome categories (lower_snake — do NOT add/rename/renumber; they are the GDD
# FR50 vocabulary, GDD lines 351-353). Pinned to match DomainEvent.DESTROY_OUTCOME_CATEGORIES by test.
const OUTCOME_SMALL_IMMEDIATE_BENEFIT := &"small_immediate_benefit"
const OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG := &"progress_unlock_hidden_flag"
const OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER := &"no_obvious_reward_avoids_danger"

const DESTROY_OUTCOME_CATEGORIES: Array[StringName] = [
	OUTCOME_SMALL_IMMEDIATE_BENEFIT,
	OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG,
	OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER
]

@export var table_id: StringName = &""
@export var entries: Array = []
# AC3: the explicit MVP tuning-deviation marker. When true (WITH a reason), a table whose category weight shares do
# NOT sum to the 70/20/10 target is still VALID (a sanctioned temporary tuning deviation). Never a silent deviation.
@export var mvp_distribution_exception: bool = false
# AC3: the required human-readable reason accompanying the exception marker (visible in tuning notes). Non-empty when
# the marker is set.
@export var distribution_exception_reason: String = ""

func _init(
	new_table_id: StringName = &"",
	new_entries: Array = [],
	new_mvp_distribution_exception: bool = false,
	new_distribution_exception_reason: String = ""
) -> void:
	table_id = new_table_id
	entries = _copy_entries(new_entries)
	mvp_distribution_exception = new_mvp_distribution_exception
	distribution_exception_reason = new_distribution_exception_reason


func validate() -> ActionResult:
	if not _is_lower_snake_id(table_id):
		return _invalid(&"table_id")
	if entries.is_empty():
		return _invalid(&"entries")
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			return _invalid(&"entries")
		var entry: Dictionary = entry_value
		if not entry.has("outcome_category") \
				or not entry.has("outcome_id") \
				or not entry.has("weight") \
				or not entry.has("effect") \
				or not entry.has("explanation"):
			return _invalid(&"entries")
		var outcome_category: StringName = StringName(str(entry.get("outcome_category")))
		if not DESTROY_OUTCOME_CATEGORIES.has(outcome_category):
			return _invalid(&"entries")
		var outcome_id: StringName = StringName(str(entry.get("outcome_id")))
		if not _is_lower_snake_id(outcome_id):
			return _invalid(&"entries")
		if not _is_positive_int(entry.get("weight")):
			return _invalid(&"entries")
		if not _is_nonempty_string(entry.get("effect")):
			return _invalid(&"effect")
		if not _is_nonempty_string(entry.get("explanation")):
			return _invalid(&"explanation")
	# AC3: the 70/20/10 distribution check. Each category's summed weight must be an EXACT fraction of the total
	# (integer arithmetic — no float drift): small = 7/10, progress = 2/10, no_reward = 1/10 of the total weight.
	# UNLESS the explicit MVP exception marker (WITH a reason) sanctions a temporary off-target tuning deviation.
	if not _distribution_hits_target():
		if not mvp_distribution_exception:
			# An off-70/20/10 table is only valid with the explicit, visible exception marker (the 6.1 *_mvp_deferred
			# posture). Surfaced, never a silent deviation.
			return _invalid(&"distribution")
		if distribution_exception_reason.strip_edges().is_empty():
			# The exception marker MUST carry a reason (visible in tuning notes — never a silent deviation).
			return _invalid(&"distribution_exception_reason")
	return ActionResult.ok()


# A copy of the entries as plain {outcome_category, outcome_id, weight, effect, explanation} dicts (lower_snake
# StringName ids, int weights, String effect/explanation), stable order preserved. The command reads this clean view.
func outcome_entries() -> Array:
	return _copy_entries(entries)


func total_weight() -> int:
	var total: int = 0
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			var weight_value: Variant = (entry_value as Dictionary).get("weight")
			if _is_positive_int(weight_value):
				total += int(weight_value)
	return total


# The summed positive-int weight of every shape-valid entry in the given category. Used by the command (the
# cumulative-weight walk) + validate() (the distribution check) + the tests (the 70/20/10 assertion).
func category_weight(category: StringName) -> int:
	var total: int = 0
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if StringName(str(entry.get("outcome_category"))) != category:
			continue
		var weight_value: Variant = entry.get("weight")
		if _is_positive_int(weight_value):
			total += int(weight_value)
	return total


static func is_valid_category(category: StringName) -> bool:
	return DESTROY_OUTCOME_CATEGORIES.has(category)


# The MVP Destroy outcome table at EXACTLY 70/20/10 with NO exception marker. One entry per FR50 category, weights
# 7/2/1 (= 70%/20%/10% of total weight 10). Each effect/explanation is drawn from the GDD Destroy reward examples
# (GDD lines 355-368). v0 OUTCOME-RECORD-ONLY: the effect string describes the intended deterministic effect — the
# live mutation (wallet/heal/cleanse/curse/meta/reroll) is wired by the later Epic-7/8 stories off the recorded
# outcome_category/outcome_id. The command defaults its outcome table to this baseline.
static func create_baseline_table() -> DestroyOutcomeTableDefinition:
	return load("res://scripts/content/definitions/destroy_outcome_table_definition.gd").new(
		&"destroy_outcome_baseline",
		[
			{
				"outcome_category": OUTCOME_SMALL_IMMEDIATE_BENEFIT,
				"outcome_id": &"minor_restoration",
				"weight": 7,
				"effect": "destroy_outcome_small_immediate_benefit",
				"explanation": "Destroying the passive releases its bound energy as a small immediate benefit: a measure of healing, a cleansed wound, or a handful of recovered gold."
			},
			{
				"outcome_category": OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG,
				"outcome_id": &"quiet_progress",
				"weight": 2,
				"effect": "destroy_outcome_progress_unlock_hidden_flag",
				"explanation": "Destroying the passive advances quiet progress: a step of class mastery or unlock progress, or an Echo/codex discovery that sets a hidden flag."
			},
			{
				"outcome_category": OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER,
				"outcome_id": &"sealed_danger",
				"weight": 1,
				"effect": "destroy_outcome_no_obvious_reward_avoids_danger",
				"explanation": "Destroying the passive yields no obvious reward, but it seals away a dangerous Labyrinth effect and advances a hidden refusal path, avoiding corruption or future danger."
			}
		]
	)


# Whether the configured per-category weight shares hit the 70/20/10 target via EXACT integer arithmetic (no float
# drift): small / total == 7/10, progress / total == 2/10, no_reward / total == 1/10. A total of 0 (no shape-valid
# weighted entry) never hits the target (and an empty table is already rejected upstream).
func _distribution_hits_target() -> bool:
	var total: int = total_weight()
	if total <= 0:
		return false
	var small_weight: int = category_weight(OUTCOME_SMALL_IMMEDIATE_BENEFIT)
	var progress_weight: int = category_weight(OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG)
	var no_reward_weight: int = category_weight(OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER)
	return small_weight * 10 == total * 7 \
			and progress_weight * 10 == total * 2 \
			and no_reward_weight * 10 == total * 1


static func _copy_entries(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		if not value is Dictionary:
			# Preserve the malformed entry verbatim so validate() can reject it (never coerce it away).
			result.append(value)
			continue
		var entry: Dictionary = value
		result.append({
			"outcome_category": StringName(str(entry.get("outcome_category", &""))),
			"outcome_id": StringName(str(entry.get("outcome_id", &""))),
			"weight": entry.get("weight", 0),
			"effect": String(entry.get("effect", "")),
			"explanation": String(entry.get("explanation", ""))
		})
	return result


static func _is_positive_int(value: Variant) -> bool:
	if typeof(value) != TYPE_INT:
		return false
	return int(value) > 0


static func _is_nonempty_string(value: Variant) -> bool:
	if not (value is String or value is StringName):
		return false
	return not String(value).strip_edges().is_empty()


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
	return ActionResult.error(&"invalid_destroy_outcome_table_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
