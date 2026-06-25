class_name StartingKit
extends RefCounted

# The APPLIED starting kit (Story 5.3) — the small typed value object that records a confirmed-selectable
# class's resolved starting equipment + baseline HP + the two class/equipment-synergy passive-id references on
# the run's domain state. RunStartCommand RESOLVES the class's starting_weapon_id/starting_support_id through
# WeaponRepository/SupportRepository (fail-closed on a missing item), reads baseline_hp + the two passive ids,
# and records the result here on the started RunState (RunState.starting_kit).
#
# IT IS BY-ID REFERENCES ONLY (the Story 5.1 forward-seam shape — "Story 5.3 applies them into the EXISTING
# RunState without a parallel run format"): it holds the class id, the resolved weapon/support ids, baseline_hp,
# and the two passive ids. It is a scene-free RefCounted DTO that owns no truth beyond the recorded kit, submits
# no commands, draws no RNG, and instantiates NO tactical board player (that is Story 5.5's smoke slice). The two
# passive ids are RECORDED VERBATIM as lower_snake STRING-shape forward references — there is no passive system
# yet (Story 5.4 wires class passives into the rules kernel; Epic 6 authors the passive pool), so StartingKit
# resolves them against NOTHING.
#
# Mirrors the project's typed-DTO discipline + the exact-key to_dictionary() contract (the TacticalBoardViewModel
# precedent — a key never silently appears/vanishes; the key set is pinned by test_starting_kit.gd). The
# weapon_id/support_id stored here are the class's CONFIGURED kit ids (validated to resolve at record time);
# `support_id` may be &"none" (Ranger's real no-op SUPPORT_NONE), which is a VALID resolved support, NOT a
# missing item.

# The stable key set of to_dictionary() (pinned by test). A key never silently appears or vanishes.
const DICTIONARY_KEYS: Array[String] = [
	"class_id",
	"weapon_id",
	"support_id",
	"baseline_hp",
	"class_passive_id",
	"equipment_synergy_passive_id"
]

var class_id: StringName = &""
var weapon_id: StringName = &""
var support_id: StringName = &""
var baseline_hp: int = 0
var class_passive_id: StringName = &""
var equipment_synergy_passive_id: StringName = &""

func _init(
	new_class_id: StringName = &"",
	new_weapon_id: StringName = &"",
	new_support_id: StringName = &"",
	new_baseline_hp: int = 0,
	new_class_passive_id: StringName = &"",
	new_equipment_synergy_passive_id: StringName = &""
) -> void:
	class_id = new_class_id
	weapon_id = new_weapon_id
	support_id = new_support_id
	baseline_hp = new_baseline_hp
	class_passive_id = new_class_passive_id
	equipment_synergy_passive_id = new_equipment_synergy_passive_id


# Exact-key serialization (the TacticalBoardViewModel precedent). The ids are small lower_snake StringNames
# serialized as plain Strings; baseline_hp is a small bounded int (NOT a seed — no int64/decimal-string
# encoding needed). A fresh dictionary is returned each call (no shared mutable state to perturb).
func to_dictionary() -> Dictionary:
	return {
		"class_id": String(class_id),
		"weapon_id": String(weapon_id),
		"support_id": String(support_id),
		"baseline_hp": baseline_hp,
		"class_passive_id": String(class_passive_id),
		"equipment_synergy_passive_id": String(equipment_synergy_passive_id)
	}


# Lenient reconstruction (mirrors the RunState.try_from_dictionary leniency): a missing/non-string id defaults
# to &"" and a missing/non-int baseline_hp defaults to 0, so a partial/pre-5.3 dict still parses. Returns a
# StartingKit (never null) — this is a value object, not a validated domain entity, so it has no reject path.
static func try_from_dictionary(data: Dictionary) -> StartingKit:
	return load("res://scripts/run/starting_kit.gd").new(
		_string_name_or_empty(data.get("class_id", &"")),
		_string_name_or_empty(data.get("weapon_id", &"")),
		_string_name_or_empty(data.get("support_id", &"")),
		_int_or_zero(data.get("baseline_hp", 0)),
		_string_name_or_empty(data.get("class_passive_id", &"")),
		_string_name_or_empty(data.get("equipment_synergy_passive_id", &""))
	)


func copy() -> StartingKit:
	return load("res://scripts/run/starting_kit.gd").new(
		class_id,
		weapon_id,
		support_id,
		baseline_hp,
		class_passive_id,
		equipment_synergy_passive_id
	)


static func _string_name_or_empty(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return &""


static func _int_or_zero(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return 0
			return int(numeric_value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value)
			if text.is_valid_int():
				return text.to_int()
			return 0
		_:
			return 0
