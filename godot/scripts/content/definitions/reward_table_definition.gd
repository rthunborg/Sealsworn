class_name RewardTableDefinition
extends Resource

# A typed, validated REWARD-TABLE / reward-pool definition (Story 6.1) — the approved table a reward offer
# draws from. It is the content the AC3 deterministic offer-fixture (RewardOfferBuilder) reads + draws against.
# Mirrors the WeaponDefinition / LevelRecipeDefinition shape (DEFINITION_TYPE, @export fields, _init, validate()
# -> ActionResult). It references content BY ID + CATEGORY only — it does NOT resolve the referenced
# weapon/armor/consumable/etc. against their repositories in validate() (resolution is the offer flow's job,
# Story 6.3 — the same by-id-defer precedent as LevelRecipeDefinition carrying reward/wrinkle refs).
#
# An entry is a Dictionary {category, content_id, weight}:
#   - category:   one of the MVP loot categories (REWARD_CATEGORIES allowlist below) — weapon/armor/jewelry/
#                 support/consumable/pickup/passive/gold.
#   - content_id: a lower_snake stable id referencing a definition in that category's repository (shape only).
#   - weight:     a positive int relative draw weight (the offer-builder weighted-picks by this).
#
# validate() rejects an empty table, an out-of-allowlist category, a non-lower_snake content id, a malformed
# entry, or a non-positive weight (REJECT, never coerce — every branch has a dedicated negative test).
#
# AC4 3-CHOICE-PASSIVE EXCEPTION MARKER (Story 6.3): `choice_count` declares how many DISTINCT choices a generated
# offer from this table draws (default 1 — a normal single-pick reward table; 3 for a passive "3-choice moment").
# A without-replacement draw of `choice_count` distinct entries needs at least `choice_count` distinct content ids
# in the table — so validate() REJECTS a table whose declared `choice_count` exceeds its distinct-content-id count
# UNLESS the explicit `mvp_choice_count_exception` marker is set WITH a non-empty `choice_count_exception_reason`
# (mirroring the 6.1 *_mvp_deferred posture — the marker makes a sub-`choice_count`-distinct table VALID + VISIBLE;
# without it a passive 3-choice table with fewer than three distinct entries is invalid_reward_table_definition).
# The exception is surfaced (this validate() check + a tuning note in the consuming story's Completion Notes),
# never a silent reduction.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"reward_table"

# The default declared choice count (a normal single-pick reward table draws ONE entry).
const DEFAULT_CHOICE_COUNT := 1

# The eight MVP loot/reward categories (AC1 / FR52). A reward-table entry's category MUST be one of these. The
# string values match each category definition's DEFINITION_TYPE (weapon/armor/jewelry/support/consumable/
# pickup/passive) plus `gold` for the gold-reward category.
const CATEGORY_WEAPON := &"weapon"
const CATEGORY_ARMOR := &"armor"
const CATEGORY_JEWELRY := &"jewelry"
const CATEGORY_SUPPORT := &"support"
const CATEGORY_CONSUMABLE := &"consumable"
const CATEGORY_PICKUP := &"pickup"
const CATEGORY_PASSIVE := &"passive"
const CATEGORY_GOLD := &"gold"

const REWARD_CATEGORIES: Array[StringName] = [
	CATEGORY_WEAPON,
	CATEGORY_ARMOR,
	CATEGORY_JEWELRY,
	CATEGORY_SUPPORT,
	CATEGORY_CONSUMABLE,
	CATEGORY_PICKUP,
	CATEGORY_PASSIVE,
	CATEGORY_GOLD
]

@export var table_id: StringName = &""
@export var entries: Array = []
# AC4: how many DISTINCT choices a generated offer from this table draws (default 1; 3 for a passive 3-choice
# moment). Must be a positive int.
@export var choice_count: int = DEFAULT_CHOICE_COUNT
# AC4: the explicit MVP test-scope exception marker. When true (WITH a reason), a table whose distinct-content-id
# count is below `choice_count` is still VALID (a sanctioned reduced-density table). Never a silent reduction.
@export var mvp_choice_count_exception: bool = false
# AC4: the required human-readable reason accompanying the exception marker (visible in tuning notes). Non-empty
# when the marker is set.
@export var choice_count_exception_reason: String = ""

func _init(
	new_table_id: StringName = &"",
	new_entries: Array = [],
	new_choice_count: int = DEFAULT_CHOICE_COUNT,
	new_mvp_choice_count_exception: bool = false,
	new_choice_count_exception_reason: String = ""
) -> void:
	table_id = new_table_id
	entries = _copy_entries(new_entries)
	choice_count = new_choice_count
	mvp_choice_count_exception = new_mvp_choice_count_exception
	choice_count_exception_reason = new_choice_count_exception_reason


func validate() -> ActionResult:
	if not _is_lower_snake_id(table_id):
		return _invalid(&"table_id")
	if entries.is_empty():
		return _invalid(&"entries")
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			return _invalid(&"entries")
		var entry: Dictionary = entry_value
		if not entry.has("category") or not entry.has("content_id") or not entry.has("weight"):
			return _invalid(&"entries")
		var category: StringName = StringName(str(entry.get("category")))
		if not REWARD_CATEGORIES.has(category):
			return _invalid(&"entries")
		var content_id: StringName = StringName(str(entry.get("content_id")))
		if not _is_lower_snake_id(content_id):
			return _invalid(&"entries")
		if not _is_positive_int(entry.get("weight")):
			return _invalid(&"entries")
	# AC4: the declared choice count must be a positive int.
	if choice_count < 1:
		return _invalid(&"choice_count")
	# AC4: a without-replacement draw of `choice_count` distinct entries needs at least `choice_count` distinct
	# content ids — UNLESS the explicit MVP exception marker (WITH a reason) sanctions a reduced-density table.
	if choice_count > distinct_content_id_count():
		if not mvp_choice_count_exception:
			# A passive 3-choice (or any multi-choice) table with fewer than `choice_count` distinct entries is
			# only valid with the explicit, visible exception marker (the 6.1 *_mvp_deferred posture).
			return _invalid(&"choice_count")
		if choice_count_exception_reason.strip_edges().is_empty():
			# The exception marker MUST carry a reason (visible in tuning notes — never a silent reduction).
			return _invalid(&"choice_count_exception_reason")
	return ActionResult.ok()


# AC4: the number of DISTINCT content ids across the table entries (a without-replacement multi-choice draw can
# yield at most this many distinct offered entries). Counts only shape-valid (Dictionary) entries' content ids.
func distinct_content_id_count() -> int:
	var seen: Dictionary = {}
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var content_id: String = String((entry_value as Dictionary).get("content_id", ""))
		if not content_id.is_empty():
			seen[content_id] = true
	return seen.size()


# A copy of the entries as plain {category, content_id, weight} dicts (lower_snake StringName ids, int weights),
# stable order preserved. Used by the offer-builder so it reads a clean, immutable view.
func reward_entries() -> Array:
	return _copy_entries(entries)


func total_weight() -> int:
	var total: int = 0
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			var weight_value: Variant = (entry_value as Dictionary).get("weight")
			if _is_positive_int(weight_value):
				total += int(weight_value)
	return total


static func is_valid_category(category: StringName) -> bool:
	return REWARD_CATEGORIES.has(category)


static func _copy_entries(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		if not value is Dictionary:
			# Preserve the malformed entry verbatim so validate() can reject it (never coerce it away).
			result.append(value)
			continue
		var entry: Dictionary = value
		result.append({
			"category": StringName(str(entry.get("category", &""))),
			"content_id": StringName(str(entry.get("content_id", &""))),
			"weight": entry.get("weight", 0)
		})
	return result


static func _is_positive_int(value: Variant) -> bool:
	if typeof(value) != TYPE_INT:
		return false
	return int(value) > 0


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
	return ActionResult.error(&"invalid_reward_table_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
