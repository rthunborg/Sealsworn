extends "res://tests/unit/test_case.gd"

# Story 6.6 Task 2 — DestroyOutcomeTableDefinition (the validated 70/20/10 Destroy outcome pool a
# DestroyPassiveCommand rolls against). Pins: the baseline table validates AND hits EXACTLY 70/20/10 (the
# per-category weight shares); every validate() branch has a dedicated negative (non-lower_snake table_id, empty
# table, out-of-allowlist outcome_category, non-lower_snake outcome_id, non-positive weight, blank effect, blank
# explanation, malformed/non-dict entry, missing key); the 70/20/10 distribution check rejects an off-target table
# WITHOUT the exception marker, ACCEPTS the same off-target table WITH the marker + a reason, and REJECTS the marker
# WITHOUT a reason; the local DESTROY_OUTCOME_CATEGORIES allowlist matches DomainEvent's (the no-cross-dependency
# pin). Mirrors test_reward_table_definition.gd.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DestroyOutcomeTableDefinition = preload("res://scripts/content/definitions/destroy_outcome_table_definition.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_baseline_table_validates_and_hits_70_20_10()
	_table_id_must_be_lower_snake()
	_empty_table_rejected()
	_out_of_allowlist_outcome_category_rejected()
	_non_lower_snake_outcome_id_rejected()
	_non_positive_weight_rejected()
	_blank_effect_rejected()
	_blank_explanation_rejected()
	_missing_entry_key_rejected()
	_non_dict_entry_rejected()
	_off_target_distribution_without_marker_rejected()
	_off_target_distribution_with_marker_and_reason_accepted()
	_distribution_marker_without_reason_rejected()
	_total_and_category_weight_expose_clean_view()
	_category_allowlist_matches_domain_event()
	return result()


# A valid OFF-baseline table at exactly 70/20/10 (weights 70/20/10) with NO marker — used by negative-mutation
# tests that need a valid starting point to perturb one field.
func _valid_table() -> DestroyOutcomeTableDefinition:
	return DestroyOutcomeTableDefinition.new(&"destroy_outcome_test", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 70, "effect": "heal a little", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 20, "effect": "advance progress", "explanation": "A step of progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 10, "effect": "seal a danger", "explanation": "Avoids future danger."}
	])


# AC2/AC3: the baseline ships AT exactly 70/20/10 with NO exception marker.
func _baseline_table_validates_and_hits_70_20_10() -> void:
	var table: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.create_baseline_table()
	assert_true(table.validate().succeeded, "The baseline Destroy outcome table should validate.")
	assert_false(table.mvp_distribution_exception, "The baseline table ships with NO exception marker.")
	# The per-category weight shares hit 70/20/10 (exact integer arithmetic: small/total == 7/10, etc.).
	var total: int = table.total_weight()
	assert_true(total > 0, "The baseline table must have a positive total weight.")
	var small: int = table.category_weight(DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT)
	var progress: int = table.category_weight(DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG)
	var no_reward: int = table.category_weight(DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER)
	assert_equal(small * 10, total * 7, "small_immediate_benefit must be 70%% of the total weight.")
	assert_equal(progress * 10, total * 2, "progress_unlock_hidden_flag must be 20%% of the total weight.")
	assert_equal(no_reward * 10, total * 1, "no_obvious_reward_avoids_danger must be 10%% of the total weight.")
	# Every FR50 category is represented (the weighted draw can yield any of the three).
	assert_true(small > 0, "The baseline must hold at least one small_immediate_benefit entry.")
	assert_true(progress > 0, "The baseline must hold at least one progress_unlock_hidden_flag entry.")
	assert_true(no_reward > 0, "The baseline must hold at least one no_obvious_reward_avoids_danger entry.")


func _table_id_must_be_lower_snake() -> void:
	var bad: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"DestroyTable", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 7, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 2, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 1, "effect": "seal", "explanation": "Avoids danger."}
	])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake table id must be rejected.")
	assert_equal(validation.error_code, &"invalid_destroy_outcome_table_definition", "Use the stable destroy-outcome-table-definition error code.")
	assert_equal(String(validation.metadata.get("field")), "table_id", "The error should name table_id.")


func _empty_table_rejected() -> void:
	var bad: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"empty_table", [])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An empty Destroy outcome table must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "entries", "The error should name entries.")


func _out_of_allowlist_outcome_category_rejected() -> void:
	var bad: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"bad_category_table", [
		{"outcome_category": &"jackpot", "outcome_id": &"heal", "weight": 7, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 2, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 1, "effect": "seal", "explanation": "Avoids danger."}
	])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An out-of-allowlist outcome_category must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "entries", "A bad outcome_category should name entries.")


func _non_lower_snake_outcome_id_rejected() -> void:
	var bad: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"bad_outcome_id_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"Heal-Now", "weight": 7, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 2, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 1, "effect": "seal", "explanation": "Avoids danger."}
	])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake outcome_id must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "entries", "A bad outcome_id should name entries.")


func _non_positive_weight_rejected() -> void:
	var zero_weight: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"zero_weight_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 0, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 2, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 1, "effect": "seal", "explanation": "Avoids danger."}
	])
	assert_true(zero_weight.validate().is_error(), "A zero weight must be rejected.")
	var float_weight: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"float_weight_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 7.0, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 2, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 1, "effect": "seal", "explanation": "Avoids danger."}
	])
	assert_true(float_weight.validate().is_error(), "A non-int weight must be rejected (no coercion).")


func _blank_effect_rejected() -> void:
	var bad: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"blank_effect_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 7, "effect": "   ", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 2, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 1, "effect": "seal", "explanation": "Avoids danger."}
	])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A blank effect must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "effect", "A blank effect should name effect.")


func _blank_explanation_rejected() -> void:
	var bad: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"blank_explanation_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 7, "effect": "heal", "explanation": ""},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 2, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 1, "effect": "seal", "explanation": "Avoids danger."}
	])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A blank explanation must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "explanation", "A blank explanation should name explanation.")


func _missing_entry_key_rejected() -> void:
	var missing_weight: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"missing_weight_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "effect": "heal", "explanation": "A small heal."}
	])
	assert_true(missing_weight.validate().is_error(), "An entry missing the weight key must be rejected.")
	var missing_category: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"missing_category_table", [
		{"outcome_id": &"heal", "weight": 7, "effect": "heal", "explanation": "A small heal."}
	])
	assert_true(missing_category.validate().is_error(), "An entry missing the outcome_category key must be rejected.")


func _non_dict_entry_rejected() -> void:
	var bad: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"non_dict_entry_table", [&"not_a_dict"])
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-dict entry must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "entries", "A malformed entry should name entries.")


# AC3: a table whose category weight shares do NOT sum to 70/20/10 WITHOUT the exception marker is REJECTED (never a
# silent deviation). Weights 5/3/2 = 50/30/20, off target.
func _off_target_distribution_without_marker_rejected() -> void:
	var table: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"off_target_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 5, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 3, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 2, "effect": "seal", "explanation": "Avoids danger."}
	])
	var validation: ActionResult = table.validate()
	assert_true(validation.is_error(), "An off-70/20/10 table WITHOUT the marker must be rejected.")
	assert_equal(validation.error_code, &"invalid_destroy_outcome_table_definition", "An off-target table should use the stable error code.")
	assert_equal(String(validation.metadata.get("field")), "distribution", "The error should name distribution.")
	# A table missing an entire category (so that category's share is 0) is also off-target and rejected.
	var missing_category: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"missing_category_share", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 7, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 3, "effect": "progress", "explanation": "Progress."}
	])
	assert_true(missing_category.validate().is_error(), "A table missing the no_obvious_reward category (off-target) must be rejected without the marker.")


# AC3: the SAME off-target table WITH the explicit exception marker + a non-empty reason is ACCEPTED (a sanctioned
# temporary tuning deviation — the 6.1 *_mvp_deferred posture).
func _off_target_distribution_with_marker_and_reason_accepted() -> void:
	var table: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"off_target_marked_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 5, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 3, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 2, "effect": "seal", "explanation": "Avoids danger."}
	], true, "MVP tuning: temporary 50/30/20 weighting under evaluation; owner dev 6.6, 2026-06-29.")
	assert_true(table.validate().succeeded, "An off-target table WITH the exception marker (and a reason) must validate.")


# AC3: the exception marker MUST carry a non-empty reason (surfaced in tuning notes — never a silent deviation).
func _distribution_marker_without_reason_rejected() -> void:
	var table: DestroyOutcomeTableDefinition = DestroyOutcomeTableDefinition.new(&"off_target_no_reason_table", [
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT, "outcome_id": &"heal", "weight": 5, "effect": "heal", "explanation": "A small heal."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_PROGRESS_UNLOCK_HIDDEN_FLAG, "outcome_id": &"progress", "weight": 3, "effect": "progress", "explanation": "Progress."},
		{"outcome_category": DestroyOutcomeTableDefinition.OUTCOME_NO_OBVIOUS_REWARD_AVOIDS_DANGER, "outcome_id": &"seal", "weight": 2, "effect": "seal", "explanation": "Avoids danger."}
	], true, "   ")
	var validation: ActionResult = table.validate()
	assert_true(validation.is_error(), "An exception marker without a reason must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "distribution_exception_reason", "The error should name distribution_exception_reason.")


func _total_and_category_weight_expose_clean_view() -> void:
	var table: DestroyOutcomeTableDefinition = _valid_table()
	assert_equal(table.total_weight(), 100, "total_weight should sum the entry weights (70 + 20 + 10).")
	assert_equal(table.category_weight(DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT), 70, "category_weight should sum a category's entries.")
	var entries: Array = table.outcome_entries()
	assert_equal(entries.size(), 3, "outcome_entries should expose every entry.")
	assert_equal(String((entries[0] as Dictionary).get("outcome_id")), "heal", "outcome_entries should carry the outcome id.")
	assert_true(DestroyOutcomeTableDefinition.is_valid_category(DestroyOutcomeTableDefinition.OUTCOME_SMALL_IMMEDIATE_BENEFIT), "small_immediate_benefit is a valid category.")
	assert_false(DestroyOutcomeTableDefinition.is_valid_category(&"jackpot"), "jackpot is not a valid category.")


# The local allowlist on the content definition must match the one DomainEvent pins LOCALLY (so the
# passive_destroyed validator has no cross-script dependency — the value sets are pinned to match by THIS test).
func _category_allowlist_matches_domain_event() -> void:
	assert_equal(
		DestroyOutcomeTableDefinition.DESTROY_OUTCOME_CATEGORIES,
		DomainEvent.DESTROY_OUTCOME_CATEGORIES,
		"DestroyOutcomeTableDefinition + DomainEvent must pin the SAME Destroy outcome category allowlist."
	)
