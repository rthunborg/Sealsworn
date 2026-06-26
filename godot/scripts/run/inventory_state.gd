class_name InventoryState
extends RefCounted

# The small MVP inventory + equipment domain model (Story 6.2) — a scene-free RefCounted value object recorded
# on RunState (alongside starting_kit / rules_resolver) that TRACKS the loot items defined by Story 6.1. It
# delivers FR51's "small MVP inventory (~6 backpack items, no stacking by default)" as run-domain TRUTH: a
# fixed-capacity ordered BACKPACK (default 6, one item per slot — NO stacking in v0) PLUS a fixed set of NAMED
# EQUIPMENT slots (the title's "and Equipment Model"). PickupItemCommand mutates the backpack through the
# validate-then-mutate run-command idiom; presentation (a later HUD story) OBSERVES this model, never owns it.
#
# IT IS BY-ID REFERENCES ONLY (mirroring StartingKit): each backpack slot holds an item id + its category + a
# quantity; each equipment slot holds zero-or-one equipped item id keyed by slot name. It does NOT copy Story
# 6.1's definitions, does NOT roll/resolve a reward (that is the loot ROLL, Story 6.3+), draws NO RNG,
# instantiates NO tactical board entity, and submits NO commands.
#
# NO STACKING (AC1 / FR51): each occupied backpack slot holds EXACTLY ONE item — a second pickup of the same id
# is a SECOND slot, never a quantity++. The slot DOES carry a `quantity` field defaulting to 1 (validated >= 1)
# so a LATER "stackable" item opt-in is a marker flip, not a schema fork (the 6.1 *_mvp_deferred posture) — but
# v0 authors NO stackable item and the model NEVER sets quantity > 1 (the pickup command always appends a fresh
# quantity-1 slot). This mirrors the existing RunSnapshot.inventory placeholder shape {"definition_id": ...,
# "quantity": 1}; this model uses `item_id` (not `definition_id`) so the slot key matches the item_gained event
# payload + the equipment {slot: item_id} shape (recorded as a Story-6.2 [Decision]).
#
# Mirrors StartingKit's exact-key to_dictionary() contract (a key never silently appears/vanishes — the key set
# is pinned by test_inventory_state.gd), the lenient try_from_dictionary (a value object, no reject path — a
# partial/legacy dict defaults cleanly), and the deep copy() (the backpack slot list + equipment dict must NOT
# be shared by reference). It is DELIBERATELY NOT serialized into the route-position RunSnapshot this story (the
# RunSnapshot.inventory/equipment placeholders stay EMPTY — there is no live in-node inventory save yet); it
# rides only the FULL RunState.to_dictionary()/try_from_dictionary, so a copied/round-tripped run preserves it.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

# AC1: the configured small default backpack capacity. A small bounded POSITIVE int content constant — NOT a
# difficulty / run-depth knob (difficulty is a hard non-goal; nothing scales this by run depth/difficulty).
const DEFAULT_BACKPACK_CAPACITY: int = 6

# The default quantity carried by an occupied backpack slot. v0 NEVER sets a quantity above this (no stacking).
const DEFAULT_SLOT_QUANTITY: int = 1

# The fixed set of NAMED equipment slots (the equippable Story-6.1 categories: weapon/armor/jewelry/support).
# Each slot holds zero-or-one equipped item id. consumable/pickup are NON-equippable backpack-only items, so
# they are NOT equipment slots. This mirrors the RunSnapshot.equipment {slot: item_id} forward-shape.
const EQUIPMENT_SLOTS: Array[StringName] = [
	&"weapon",
	&"armor",
	&"jewelry",
	&"support"
]

# The allowlist of item categories a backpack slot may carry (every Story-6.1 loot category). lower_snake.
const BACKPACK_CATEGORIES: Array[StringName] = [
	&"weapon",
	&"armor",
	&"jewelry",
	&"support",
	&"consumable",
	&"pickup"
]

# The per-backpack-slot dictionary keys (pinned; a key never silently appears/vanishes — test-asserted).
const SLOT_KEYS: Array[String] = [
	"item_id",
	"category",
	"quantity"
]

# The stable key set of to_dictionary() (pinned by test). A key never silently appears or vanishes.
const DICTIONARY_KEYS: Array[String] = [
	"capacity",
	"backpack",
	"equipment"
]

# A small bounded positive capacity (default 6). The pickup command rejects a pickup once backpack.size() >=
# capacity (is_full()).
var capacity: int = DEFAULT_BACKPACK_CAPACITY
# The ordered backpack: a list of single-item slot dictionaries {item_id, category, quantity}. One item per
# slot (NO stacking in v0).
var backpack: Array[Dictionary] = []
# The named equipment slots {slot_name: item_id}. An ABSENT key (or an empty-string value) is an EMPTY slot —
# this story builds the equipment STRUCTURE only; the equip/unequip commands + the character-level equip-gate
# CHECK are DEFERRED (no hero character-level system exists yet — the run carries starting_kit.baseline_hp, not
# a character level). Recorded as a Story-6.2 deferral.
var equipment: Dictionary = {}

func _init(
	new_capacity: int = DEFAULT_BACKPACK_CAPACITY,
	new_backpack: Array = [],
	new_equipment: Dictionary = {}
) -> void:
	# Capacity is a small bounded positive int: a non-positive / non-int value resolves to the default rather
	# than producing an unusable zero/negative-capacity backpack (lenient value-object construction, mirroring
	# StartingKit's defaulting decode).
	capacity = new_capacity if (new_capacity is int and new_capacity > 0) else DEFAULT_BACKPACK_CAPACITY
	backpack = _normalize_backpack(new_backpack)
	equipment = _normalize_equipment(new_equipment)


# AC1: the backpack is full once it holds `capacity` slots. The pickup command rejects a pickup with
# inventory_full at this point.
func is_full() -> bool:
	return backpack.size() >= capacity


# The inverse of is_full(): there is room for at least one more slot.
func has_capacity() -> bool:
	return backpack.size() < capacity


# The current number of occupied backpack slots (one item per slot).
func size() -> int:
	return backpack.size()


# Build a normalized single-item backpack slot dictionary (item_id + category + quantity). The pickup command
# uses this so the slot shape stays in lockstep with SLOT_KEYS. quantity defaults to 1 and is NEVER above 1 in
# v0 (no stacking); a supplied quantity below 1 clamps to 1.
static func make_slot(item_id: StringName, category: StringName, quantity: int = DEFAULT_SLOT_QUANTITY) -> Dictionary:
	var safe_quantity: int = quantity if quantity >= DEFAULT_SLOT_QUANTITY else DEFAULT_SLOT_QUANTITY
	return {
		"item_id": String(item_id),
		"category": String(category),
		"quantity": safe_quantity
	}


# Whether a category is in the backpack allowlist (lower_snake category check shared with the command).
static func is_backpack_category(category: StringName) -> bool:
	return BACKPACK_CATEGORIES.has(category)


# Append ONE single-item slot to the backpack (the infallible mutation the pickup command runs AFTER it
# validates capacity). The caller is responsible for having validated has_capacity() first; this is a pure
# append (it never overwrites or drops an existing slot — the AC3 "no silent delete" guarantee). Returns the
# new slot index (== the prior backpack size).
func append_slot(item_id: StringName, category: StringName, quantity: int = DEFAULT_SLOT_QUANTITY) -> int:
	var slot_index: int = backpack.size()
	backpack.append(make_slot(item_id, category, quantity))
	return slot_index


# The equipped item id in a named slot, or &"" when the slot is empty/absent. (Equip/unequip is deferred; this
# accessor lets a later story + tests read the equipment structure without poking the dict directly.)
func equipped_in(slot_name: StringName) -> StringName:
	var value: Variant = equipment.get(String(slot_name), "")
	if value is String or value is StringName:
		return StringName(String(value))
	return &""


# Exact-key serialization (the StartingKit / TacticalBoardViewModel precedent). capacity is a small bounded int
# (NOT a seed — no int64/decimal-string encoding). A FRESH dictionary (with deep-copied backpack/equipment) is
# returned each call so a mutation of the returned dict never perturbs the model.
func to_dictionary() -> Dictionary:
	var backpack_copy: Array[Dictionary] = []
	for slot: Dictionary in backpack:
		backpack_copy.append(slot.duplicate(true))
	return {
		"capacity": capacity,
		"backpack": backpack_copy,
		"equipment": equipment.duplicate(true)
	}


# Lenient reconstruction (mirrors StartingKit.try_from_dictionary leniency): a missing/invalid capacity defaults
# to DEFAULT_BACKPACK_CAPACITY, a missing/non-array backpack defaults to empty, a missing/non-dict equipment
# defaults to empty — so a partial/pre-6.2 dict still parses. Returns an InventoryState (never null) — a value
# object, not a validated domain entity, so it has no reject path.
static func try_from_dictionary(data: Dictionary) -> InventoryState:
	return load("res://scripts/run/inventory_state.gd").new(
		_int_or_default(data.get("capacity", DEFAULT_BACKPACK_CAPACITY), DEFAULT_BACKPACK_CAPACITY),
		data.get("backpack", []),
		data.get("equipment", {})
	)


# Deep copy (the backpack slot list + equipment dict are deep-copied so a copy never shares mutable state with
# the source — mutating the copy's backpack must not perturb the source).
func copy() -> InventoryState:
	return load("res://scripts/run/inventory_state.gd").new(
		capacity,
		backpack,
		equipment
	)


# Normalize an arbitrary backpack input (from a constructor / lenient decode) into a clean Array[Dictionary] of
# single-item slots. Each entry that is a Dictionary is reshaped to EXACTLY the pinned slot keys (item_id +
# category as plain Strings, quantity as a clamped >= 1 int); a non-dict entry is skipped. This both deep-copies
# (no shared reference with the input) and guarantees the slot shape so a round-tripped/legacy dict can never
# inject a surprise slot key or a quantity < 1.
static func _normalize_backpack(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw is Array:
		return result
	for entry: Variant in (raw as Array):
		if not entry is Dictionary:
			continue
		var slot: Dictionary = entry as Dictionary
		var item_id: String = String(slot.get("item_id", ""))
		var category: String = String(slot.get("category", ""))
		var quantity: int = _int_or_default(slot.get("quantity", DEFAULT_SLOT_QUANTITY), DEFAULT_SLOT_QUANTITY)
		if quantity < DEFAULT_SLOT_QUANTITY:
			quantity = DEFAULT_SLOT_QUANTITY
		result.append({
			"item_id": item_id,
			"category": category,
			"quantity": quantity
		})
	return result


# Normalize an arbitrary equipment input into a clean {slot_name: item_id} dictionary over the known slots only.
# Only the EQUIPMENT_SLOTS keys are carried; a non-string id or an unknown slot key is dropped; an empty id is
# omitted (an absent key is an empty slot). Deep-copies (no shared reference with the input).
static func _normalize_equipment(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary:
		return result
	var source: Dictionary = raw as Dictionary
	for slot_name: StringName in EQUIPMENT_SLOTS:
		var key: String = String(slot_name)
		if not source.has(key):
			continue
		var value: Variant = source.get(key)
		if not (value is String or value is StringName):
			continue
		var item_id: String = String(value)
		if item_id.is_empty():
			continue
		result[key] = item_id
	return result


# Lenient int decode (capacity / quantity): accept an int / integral-float / decimal-string, else the supplied
# default. Mirrors StartingKit._int_or_zero with a caller-supplied default.
static func _int_or_default(value: Variant, default_value: int) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return default_value
			return int(numeric_value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value)
			if text.is_valid_int():
				return text.to_int()
			return default_value
		_:
			return default_value
