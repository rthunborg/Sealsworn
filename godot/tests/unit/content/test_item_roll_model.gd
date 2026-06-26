extends "res://tests/unit/test_case.gd"

# Story 6.1 AC5 — ItemRollModel (the item instance-variation shape: a roll RANGE live; affix/enhancement ids +
# affinity tags shape-only-deferred with per-family MVP-deferral markers; NO item_level). Pins: a valid model
# validates; every validate() branch has a dedicated negative; a deferred family validates INERT (shape present,
# empty list) and REJECTS a populated list while deferred; an un-deferred family accepts a lower_snake id list
# and rejects a non-lower_snake one; there is no item_level field (the shape is range + ids/tags only).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

func run() -> Dictionary:
	_valid_default_deferred_model_validates()
	_roll_range_negative_min_rejected()
	_roll_range_max_below_min_rejected()
	_deferred_affix_family_with_ids_rejected()
	_un_deferred_affix_family_accepts_lower_snake_ids()
	_un_deferred_affix_family_rejects_non_lower_snake_id()
	_deferred_enhancement_family_with_ids_rejected()
	_un_deferred_enhancement_family_accepts_ids()
	_deferred_affinity_family_with_tags_rejected()
	_un_deferred_affinity_family_accepts_tags()
	_no_item_level_property_exists()
	_has_roll_range_reflects_band()
	return result()


func _valid_default_deferred_model_validates() -> void:
	# A roll range with all advanced families deferred-and-empty is the realistic MVP shape — it validates inert.
	var model: ItemRollModel = ItemRollModel.new(1, 3)
	assert_true(model.validate().succeeded, "A roll-range model with all advanced families deferred-and-empty should validate.")
	assert_true(model.affixes_mvp_deferred, "Affixes default to MVP-deferred.")
	assert_true(model.enhancements_mvp_deferred, "Enhancements default to MVP-deferred.")
	assert_true(model.affinities_mvp_deferred, "Affinities default to MVP-deferred.")
	# A degenerate single-value band (min == max) is allowed (a fixed roll).
	assert_true(ItemRollModel.new(2, 2).validate().succeeded, "A single-value band (min == max) should validate.")


func _roll_range_negative_min_rejected() -> void:
	var model: ItemRollModel = ItemRollModel.new(-1, 3)
	var validation: ActionResult = model.validate()
	assert_true(validation.is_error(), "A negative roll_min must be rejected.")
	assert_equal(validation.error_code, &"invalid_item_roll_model", "Use the stable roll-model error code.")
	assert_equal(String(validation.metadata.get("field")), "roll_min", "The error should name roll_min.")


func _roll_range_max_below_min_rejected() -> void:
	var model: ItemRollModel = ItemRollModel.new(5, 2)
	var validation: ActionResult = model.validate()
	assert_true(validation.is_error(), "A roll_max below roll_min must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "roll_max", "The error should name roll_max.")


func _deferred_affix_family_with_ids_rejected() -> void:
	# A DEFERRED affix family must carry NO ids (the content is not authored yet — preserve the inert boundary).
	var model: ItemRollModel = ItemRollModel.new(1, 3, true, [&"sharpness"])
	var validation: ActionResult = model.validate()
	assert_true(validation.is_error(), "A deferred affix family populated with ids must be rejected (inert boundary).")
	assert_equal(String(validation.metadata.get("field")), "affix_ids", "The error should name affix_ids.")


func _un_deferred_affix_family_accepts_lower_snake_ids() -> void:
	# Flip the marker false + populate the list = the data boundary lights up WITHOUT a schema fork.
	var model: ItemRollModel = ItemRollModel.new(1, 3, false, [&"sharpness", &"keen_edge"])
	assert_true(model.validate().succeeded, "An un-deferred affix family with lower_snake ids should validate (forward-shape lit).")


func _un_deferred_affix_family_rejects_non_lower_snake_id() -> void:
	var model: ItemRollModel = ItemRollModel.new(1, 3, false, [&"Sharpness"])
	var validation: ActionResult = model.validate()
	assert_true(validation.is_error(), "A non-lower_snake affix id must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "affix_ids", "The error should name affix_ids.")


func _deferred_enhancement_family_with_ids_rejected() -> void:
	var model: ItemRollModel = ItemRollModel.new(1, 3, true, [], true, [&"reinforced"])
	var validation: ActionResult = model.validate()
	assert_true(validation.is_error(), "A deferred enhancement family populated with ids must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "enhancement_ids", "The error should name enhancement_ids.")


func _un_deferred_enhancement_family_accepts_ids() -> void:
	var model: ItemRollModel = ItemRollModel.new(1, 3, true, [], false, [&"reinforced"])
	assert_true(model.validate().succeeded, "An un-deferred enhancement family with lower_snake ids should validate.")


func _deferred_affinity_family_with_tags_rejected() -> void:
	var model: ItemRollModel = ItemRollModel.new(1, 3, true, [], true, [], true, [&"fire"])
	var validation: ActionResult = model.validate()
	assert_true(validation.is_error(), "A deferred affinity family populated with tags must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "affinity_tags", "The error should name affinity_tags.")


func _un_deferred_affinity_family_accepts_tags() -> void:
	var model: ItemRollModel = ItemRollModel.new(1, 3, true, [], true, [], false, [&"fire", &"frost"])
	assert_true(model.validate().succeeded, "An un-deferred affinity family with lower_snake tags should validate.")


func _no_item_level_property_exists() -> void:
	# AC5: variation is driven by ranges/affixes/affinities/enhancements, NEVER a fixed item level. Assert the
	# shape carries no item_level property.
	var model: ItemRollModel = ItemRollModel.new(1, 3)
	var property_names: Array[String] = []
	for property_info: Dictionary in model.get_property_list():
		property_names.append(String(property_info.get("name")))
	assert_false(property_names.has("item_level"), "The roll model must NOT carry an item_level field (AC5).")


func _has_roll_range_reflects_band() -> void:
	assert_true(ItemRollModel.new(1, 3).has_roll_range(), "A min<max band has a roll range.")
	assert_false(ItemRollModel.new(2, 2).has_roll_range(), "A single-value band has no roll range.")
