extends "res://tests/unit/test_case.gd"

# Story 6.1 AC2 / FR52 — GoldRewardDefinition (the gold category; an inclusive gold band). Pins: a valid
# definition validates; every validate() branch has a dedicated negative; the band is non-negative with
# gold_max >= gold_min.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const GoldRewardDefinition = preload("res://scripts/content/definitions/gold_reward_definition.gd")

func run() -> Dictionary:
	_valid_gold_reward_validates()
	_gold_reward_id_must_be_lower_snake()
	_negative_gold_min_rejected()
	_gold_max_below_min_rejected()
	_empty_tactical_identity_rejected()
	return result()


func _valid_gold_reward() -> GoldRewardDefinition:
	return GoldRewardDefinition.new(&"small_gold_purse", 5, 15, "A small purse of gold.")


func _valid_gold_reward_validates() -> void:
	assert_true(_valid_gold_reward().validate().succeeded, "A well-formed gold-reward definition should validate.")
	# A fixed amount (min == max) is allowed.
	assert_true(GoldRewardDefinition.new(&"fixed_purse", 10, 10, "A fixed purse.").validate().succeeded, "A fixed gold amount (min == max) should validate.")
	# A zero floor is allowed (gold_min == 0).
	assert_true(GoldRewardDefinition.new(&"trinket_change", 0, 3, "A trickle of gold.").validate().succeeded, "A zero gold floor should validate.")


func _gold_reward_id_must_be_lower_snake() -> void:
	var bad: GoldRewardDefinition = GoldRewardDefinition.new(&"SmallPurse", 5, 15, "Bad id.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake gold-reward id must be rejected.")
	assert_equal(validation.error_code, &"invalid_gold_reward_definition", "Use the stable gold-reward-definition error code.")
	assert_equal(String(validation.metadata.get("field")), "gold_reward_id", "The error should name gold_reward_id.")


func _negative_gold_min_rejected() -> void:
	var bad: GoldRewardDefinition = GoldRewardDefinition.new(&"small_gold_purse", -1, 15, "Negative floor.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A negative gold_min must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "gold_min", "The error should name gold_min.")


func _gold_max_below_min_rejected() -> void:
	var bad: GoldRewardDefinition = GoldRewardDefinition.new(&"small_gold_purse", 15, 5, "Inverted band.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A gold_max below gold_min must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "gold_max", "The error should name gold_max.")


func _empty_tactical_identity_rejected() -> void:
	var bad: GoldRewardDefinition = GoldRewardDefinition.new(&"small_gold_purse", 5, 15, "   ")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An empty tactical identity must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "tactical_identity", "The error should name tactical_identity.")
