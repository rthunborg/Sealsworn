class_name ItemRollModel
extends Resource

# The instance-variation data shape for an equippable item (Story 6.1, AC5 / GDD FR76). It models how a
# concrete item instance can VARY from its definition: a single roll RANGE (min/max int band) that ships LIVE
# this story, plus forward-shape lists for affix ids, enhancement ids, and affinity TAGS whose CONTENT is
# MVP-deferred. There is NO `item_level` field — variation is driven by ranges/affixes/affinities/enhancements,
# never a fixed item level.
#
# [Decision c] WHICH ROLL FAMILIES SHIP LIVE vs SHAPE-ONLY-DEFERRED:
#   - roll RANGE (roll_min/roll_max): LIVE. A single inclusive int band the offer-builder can roll a value in.
#     This is the realistic MVP variation surface.
#   - affixes (affix_ids), enhancements (enhancement_ids), affinities (affinity_tags): SHAPE-ONLY-DEFERRED.
#     The field/shape EXISTS and validates INERT (lower_snake id/tag shape only — the referenced CONTENT is
#     Epic 7+/post-MVP, "Hundreds of loot affixes" is explicitly non-MVP per gdd.md line 678). Each advanced
#     family carries a per-family MVP-deferral marker (`affixes_mvp_deferred` / `enhancements_mvp_deferred` /
#     `affinities_mvp_deferred`). While a family is deferred its id/tag list MUST be empty (the family is not
#     yet authored), so the data boundary is preserved for a later epic to light up WITHOUT a schema fork:
#     flip the marker false + populate the list + add the resolution path, no shape change.
#
# validate() SHAPE-CHECKS the range + the id/tag lists; it does NOT resolve any affix/enhancement/affinity id
# against a repository (that content is later — the same by-id-defer precedent as LevelRecipeDefinition /
# ClassDefinition carrying refs without resolving them). It is a value type (a Resource, NOT a Node) embedded
# on the equippable definitions (armor/jewelry).

const ActionResult = preload("res://scripts/core/results/action_result.gd")

@export var roll_min: int = 0
@export var roll_max: int = 0
@export var affixes_mvp_deferred: bool = true
@export var affix_ids: Array[StringName] = []
@export var enhancements_mvp_deferred: bool = true
@export var enhancement_ids: Array[StringName] = []
@export var affinities_mvp_deferred: bool = true
@export var affinity_tags: Array[StringName] = []

func _init(
	new_roll_min: int = 0,
	new_roll_max: int = 0,
	new_affixes_mvp_deferred: bool = true,
	new_affix_ids: Array = [],
	new_enhancements_mvp_deferred: bool = true,
	new_enhancement_ids: Array = [],
	new_affinities_mvp_deferred: bool = true,
	new_affinity_tags: Array = []
) -> void:
	roll_min = new_roll_min
	roll_max = new_roll_max
	affixes_mvp_deferred = new_affixes_mvp_deferred
	affix_ids = _copy_ids(new_affix_ids)
	enhancements_mvp_deferred = new_enhancements_mvp_deferred
	enhancement_ids = _copy_ids(new_enhancement_ids)
	affinities_mvp_deferred = new_affinities_mvp_deferred
	affinity_tags = _copy_ids(new_affinity_tags)


func validate() -> ActionResult:
	if roll_min < 0:
		return _invalid(&"roll_min")
	if roll_max < roll_min:
		return _invalid(&"roll_max")
	# Affixes: forward-shape only. Each id must be lower_snake; a DEFERRED family must carry NO ids yet (the
	# content is not authored — preserve the inert boundary).
	for affix_id: StringName in affix_ids:
		if not _is_lower_snake_id(affix_id):
			return _invalid(&"affix_ids")
	if affixes_mvp_deferred and not affix_ids.is_empty():
		return _invalid(&"affix_ids")
	# Enhancements: same forward-shape-only discipline.
	for enhancement_id: StringName in enhancement_ids:
		if not _is_lower_snake_id(enhancement_id):
			return _invalid(&"enhancement_ids")
	if enhancements_mvp_deferred and not enhancement_ids.is_empty():
		return _invalid(&"enhancement_ids")
	# Affinities: same forward-shape-only discipline (Epic-7 content).
	for affinity_tag: StringName in affinity_tags:
		if not _is_lower_snake_id(affinity_tag):
			return _invalid(&"affinity_tags")
	if affinities_mvp_deferred and not affinity_tags.is_empty():
		return _invalid(&"affinity_tags")
	return ActionResult.ok()


func has_roll_range() -> bool:
	return roll_max > roll_min


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
	return ActionResult.error(&"invalid_item_roll_model", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
