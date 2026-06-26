class_name GoldRewardDefinition
extends Resource

# A typed, validated GOLD-REWARD loot definition (Story 6.1) — the gold category of the MVP loot/reward set
# (FR52). It declares an inclusive gold AMOUNT band (gold_min..gold_max) a reward offer can roll within; the
# concrete roll + grant is Story 6.3. Mirrors the WeaponDefinition / SupportDefinition shape. NOT equipped /
# consumed — so NO equip gate and NO roll model; the band IS its variation surface.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"gold_reward"

@export var gold_reward_id: StringName = &""
@export var gold_min: int = 0
@export var gold_max: int = 0
@export var tactical_identity: String = ""

func _init(
	new_gold_reward_id: StringName = &"",
	new_gold_min: int = 0,
	new_gold_max: int = 0,
	new_tactical_identity: String = ""
) -> void:
	gold_reward_id = new_gold_reward_id
	gold_min = new_gold_min
	gold_max = new_gold_max
	tactical_identity = new_tactical_identity


func validate() -> ActionResult:
	if not _is_lower_snake_id(gold_reward_id):
		return _invalid(&"gold_reward_id")
	if gold_min < 0:
		return _invalid(&"gold_min")
	if gold_max < gold_min:
		return _invalid(&"gold_max")
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
	return ActionResult.error(&"invalid_gold_reward_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
