class_name ConsumableDefinition
extends Resource

# A typed, validated CONSUMABLE loot definition (Story 6.1) — a single-use item (NOT equipped). Mirrors the
# WeaponDefinition / SupportDefinition shape. Consumables are SEMI-RARE and should feel worth using (FR53 /
# gdd.md line 325): scarcity + value are modeled as DATA on the definition (a rarity tier + a value int), NOT
# as runtime drop-rate logic this story (the live drop-rate/scarcity APPLICATION is Story 6.3+). The Consume
# command itself is Story 6.5.
#
# NO EQUIP GATE: consumables are not equipped, so they carry NO character_level_requirement and NO roll model
# ([Decision]: only the equippable categories — armor/jewelry, and the reused weapon/support — carry the equip
# gate; this keeps the gate cleanly on equippables only, per AC4's interpretation note).

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"consumable"

# Shared rarity vocabulary (FR53 scarcity-as-data). Semi-rare consumables sit at uncommon/rare. The same
# vocabulary is referenced by reward-table entries (RewardTableDefinition) so a table can weight by rarity.
const RARITY_COMMON := &"common"
const RARITY_UNCOMMON := &"uncommon"
const RARITY_RARE := &"rare"

const RARITIES: Array[StringName] = [
	RARITY_COMMON,
	RARITY_UNCOMMON,
	RARITY_RARE
]

@export var consumable_id: StringName = &""
@export var rarity: StringName = &""
@export var value: int = 0
@export var tactical_identity: String = ""
# Story 6.7 ADDITIVE FIELDS (new params LAST so the positional ConsumableDefinition.new(...) baseline calls are
# extended, not reordered — the 6.4 PassiveDefinition additive-extension precedent). They mirror
# DestroyOutcomeTableDefinition's effect/explanation pair: a machine-readable OUTCOME-RECORD effect marker the
# item_consumed event records + a player/debug-readable description of the known result.
#
# outcome_effect: the deterministic OUTCOME-RECORD effect marker (a lower_snake-style stable string describing
# the intended heal/ward/ember effect). v0 is OUTCOME-RECORD-ONLY — there is NO live HP/wallet domain field, so
# UseConsumableCommand RECORDS this effect via the item_consumed event; it does NOT mutate an HP/wallet/curse
# field because none exists (the live heal/cure mutation is Epic 7's risk-economy state, wired off the recorded
# effect). explanation: the Readability-Rule player/debug-readable known result.
@export var outcome_effect: String = ""
@export var explanation: String = ""

func _init(
	new_consumable_id: StringName = &"",
	new_rarity: StringName = &"",
	new_value: int = 0,
	new_tactical_identity: String = "",
	new_outcome_effect: String = "",
	new_explanation: String = ""
) -> void:
	consumable_id = new_consumable_id
	rarity = new_rarity
	value = new_value
	tactical_identity = new_tactical_identity
	outcome_effect = new_outcome_effect
	explanation = new_explanation


func validate() -> ActionResult:
	if not _is_lower_snake_id(consumable_id):
		return _invalid(&"consumable_id")
	if not RARITIES.has(rarity):
		return _invalid(&"rarity")
	# Value is a positive "worth using" measure (FR53) — a non-positive value would mean a worthless consumable.
	if value <= 0:
		return _invalid(&"value")
	if tactical_identity.strip_edges().is_empty():
		return _invalid(&"tactical_identity")
	# Story 6.7: the additive OUTCOME-RECORD fields are required (a dedicated per-field negative each). A blank
	# outcome_effect/explanation would leave the item_consumed event unable to record the effect / known result.
	if outcome_effect.strip_edges().is_empty():
		return _invalid(&"outcome_effect")
	if explanation.strip_edges().is_empty():
		return _invalid(&"explanation")
	return ActionResult.ok()


static func is_valid_rarity(value_to_check: StringName) -> bool:
	return RARITIES.has(value_to_check)


static func _is_lower_snake_id(value_to_check: StringName) -> bool:
	var text: String = String(value_to_check)
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
	return ActionResult.error(&"invalid_consumable_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
