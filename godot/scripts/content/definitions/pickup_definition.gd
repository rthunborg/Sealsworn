class_name PickupDefinition
extends Resource

# A typed, validated PICKUP loot definition (Story 6.1) — a small immediate-effect pickup (one of the MVP loot
# categories, FR52). A pickup is neither equipped nor stored as a consumable; it is granted on acquisition.
# Mirrors the WeaponDefinition / SupportDefinition shape. 6.1 only DEFINES it (the live grant/effect is a later
# story).
#
# It references its granted effect BY ID ONLY (a lower_snake `effect_id`) — shape-validated, NOT resolved
# against any repository in validate() (the effect CONTENT/resolution is later — the same by-id-defer precedent
# as LevelRecipeDefinition's refs and the roll model's affix ids). NO equip gate (not equipped), NO roll model.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"pickup"

@export var pickup_id: StringName = &""
@export var effect_id: StringName = &""
@export var tactical_identity: String = ""

func _init(
	new_pickup_id: StringName = &"",
	new_effect_id: StringName = &"",
	new_tactical_identity: String = ""
) -> void:
	pickup_id = new_pickup_id
	effect_id = new_effect_id
	tactical_identity = new_tactical_identity


func validate() -> ActionResult:
	if not _is_lower_snake_id(pickup_id):
		return _invalid(&"pickup_id")
	# The granted effect is referenced by id (lower_snake shape only — resolution is a later story).
	if not _is_lower_snake_id(effect_id):
		return _invalid(&"effect_id")
	if tactical_identity.strip_edges().is_empty():
		return _invalid(&"tactical_identity")
	return ActionResult.ok()


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
	return ActionResult.error(&"invalid_pickup_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
