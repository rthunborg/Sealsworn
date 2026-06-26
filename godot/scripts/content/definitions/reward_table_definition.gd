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

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"reward_table"

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

func _init(
	new_table_id: StringName = &"",
	new_entries: Array = []
) -> void:
	table_id = new_table_id
	entries = _copy_entries(new_entries)


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
	return ActionResult.ok()


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
