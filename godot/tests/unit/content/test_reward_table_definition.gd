extends "res://tests/unit/test_case.gd"

# Story 6.1 AC2 — RewardTableDefinition (the approved reward pool/table a reward offer draws from). Pins: a valid
# table validates; every validate() branch has a dedicated negative (empty table, out-of-allowlist category,
# non-lower_snake content id, non-positive weight, malformed/non-dict entry, missing keys); the table references
# content BY ID + CATEGORY only and does NOT resolve those refs against the other repositories (the by-id-defer
# precedent — a content_id that does not exist in any repository still validates here).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")

func run() -> Dictionary:
	_valid_table_validates()
	_table_id_must_be_lower_snake()
	_empty_table_rejected()
	_out_of_allowlist_category_rejected()
	_non_lower_snake_content_id_rejected()
	_non_positive_weight_rejected()
	_missing_entry_key_rejected()
	_non_dict_entry_rejected()
	_unresolved_content_id_still_validates_by_id_defer()
	_reward_entries_and_total_weight_expose_clean_view()
	return result()


func _valid_table() -> RewardTableDefinition:
	return RewardTableDefinition.new(&"standard_combat_reward", [
		{"category": RewardTableDefinition.CATEGORY_WEAPON, "content_id": &"sword", "weight": 3},
		{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse", "weight": 5}
	])


func _valid_table_validates() -> void:
	assert_true(_valid_table().validate().succeeded, "A well-formed reward table should validate.")


func _table_id_must_be_lower_snake() -> void:
	var bad: RewardTableDefinition = RewardTableDefinition.new(&"StandardReward", [
		{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse", "weight": 1}
	])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake table id must be rejected.")
	assert_equal(validation.error_code, &"invalid_reward_table_definition", "Use the stable reward-table-definition error code.")
	assert_equal(String(validation.metadata.get("field")), "table_id", "The error should name table_id.")


func _empty_table_rejected() -> void:
	var bad: RewardTableDefinition = RewardTableDefinition.new(&"empty_table", [])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An empty reward table must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "entries", "The error should name entries.")


func _out_of_allowlist_category_rejected() -> void:
	var bad: RewardTableDefinition = RewardTableDefinition.new(&"bad_category_table", [
		{"category": &"relic", "content_id": &"sword", "weight": 1}
	])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An out-of-allowlist category must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "entries", "A bad category should name entries.")


func _non_lower_snake_content_id_rejected() -> void:
	var bad: RewardTableDefinition = RewardTableDefinition.new(&"bad_content_id_table", [
		{"category": RewardTableDefinition.CATEGORY_WEAPON, "content_id": &"Sword", "weight": 1}
	])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake content id must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "entries", "A bad content id should name entries.")


func _non_positive_weight_rejected() -> void:
	var zero_weight: RewardTableDefinition = RewardTableDefinition.new(&"zero_weight_table", [
		{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse", "weight": 0}
	])
	assert_true(zero_weight.validate().is_error(), "A zero weight must be rejected.")
	var negative_weight: RewardTableDefinition = RewardTableDefinition.new(&"negative_weight_table", [
		{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse", "weight": -2}
	])
	assert_true(negative_weight.validate().is_error(), "A negative weight must be rejected.")
	var float_weight: RewardTableDefinition = RewardTableDefinition.new(&"float_weight_table", [
		{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse", "weight": 1.5}
	])
	assert_true(float_weight.validate().is_error(), "A non-int weight must be rejected (no coercion).")


func _missing_entry_key_rejected() -> void:
	var missing_weight: RewardTableDefinition = RewardTableDefinition.new(&"missing_weight_table", [
		{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse"}
	])
	assert_true(missing_weight.validate().is_error(), "An entry missing the weight key must be rejected.")
	var missing_category: RewardTableDefinition = RewardTableDefinition.new(&"missing_category_table", [
		{"content_id": &"small_gold_purse", "weight": 1}
	])
	assert_true(missing_category.validate().is_error(), "An entry missing the category key must be rejected.")


func _non_dict_entry_rejected() -> void:
	var bad: RewardTableDefinition = RewardTableDefinition.new(&"non_dict_entry_table", [&"not_a_dict"])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-dict entry must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "entries", "A malformed entry should name entries.")


func _unresolved_content_id_still_validates_by_id_defer() -> void:
	# By-id-defer precedent (LevelRecipeDefinition): the table references content by id + category WITHOUT
	# resolving it. A content_id that exists in no repository (but is shape-valid lower_snake) still validates —
	# resolution is the Story 6.3 offer flow's job, not validate()'s.
	var table: RewardTableDefinition = RewardTableDefinition.new(&"forward_ref_table", [
		{"category": RewardTableDefinition.CATEGORY_CONSUMABLE, "content_id": &"future_unreleased_elixir", "weight": 1}
	])
	assert_true(table.validate().succeeded, "A shape-valid by-id forward ref should validate (the by-id-defer precedent).")


func _reward_entries_and_total_weight_expose_clean_view() -> void:
	var table: RewardTableDefinition = _valid_table()
	var entries: Array = table.reward_entries()
	assert_equal(entries.size(), 2, "reward_entries should expose every entry.")
	assert_equal(String((entries[0] as Dictionary).get("content_id")), "sword", "reward_entries should carry the content id.")
	assert_equal(table.total_weight(), 8, "total_weight should sum the entry weights (3 + 5).")
	assert_true(RewardTableDefinition.is_valid_category(RewardTableDefinition.CATEGORY_PASSIVE), "passive is a valid category.")
	assert_false(RewardTableDefinition.is_valid_category(&"relic"), "relic is not a valid category.")
