extends "res://tests/unit/test_case.gd"

# Story 6.2 Task 6.1 — InventoryState (the small inventory + equipment model) construct/capacity/no-stacking/
# exact-key/copy/round-trip + equipment structure.
#
# InventoryState is the scene-free RefCounted value object recorded on RunState that tracks the Story-6.1 loot
# items: a fixed-capacity ordered BACKPACK (default 6, one item per slot, NO stacking) + a named EQUIPMENT-slot
# structure. This test pins: the default capacity 6 (DEFAULT_BACKPACK_CAPACITY); is_full()/has_capacity() at the
# boundary; append adds exactly one slot (and a second pickup of the SAME id is a SECOND slot, not a quantity++
# — NO stacking); the exact DICTIONARY_KEYS to_dictionary() key set + the exact per-slot SLOT_KEYS (a key never
# silently appears/vanishes — the StartingKit precedent); copy() is a DEEP copy (mutating the copy's backpack
# does not perturb the source); a lenient try_from_dictionary round-trip (incl. a partial/legacy dict + a
# surplus-key/quantity-coercion guard); and the equipment named-slot structure.

const InventoryState = preload("res://scripts/run/inventory_state.gd")

func run() -> Dictionary:
	_defaults_to_capacity_six_and_empty()
	_is_full_and_has_capacity_track_the_boundary()
	_append_adds_exactly_one_slot()
	_no_stacking_a_repeat_pickup_is_a_second_slot()
	_to_dictionary_emits_exactly_the_pinned_keys()
	_slot_shape_carries_exactly_the_pinned_slot_keys()
	_round_trips_through_real_json()
	_copy_is_a_deep_copy()
	_returned_dictionary_mutation_does_not_perturb_a_fresh_projection()
	_try_from_dictionary_is_lenient_on_partial_and_empty()
	_try_from_dictionary_drops_surplus_slot_keys_and_clamps_quantity()
	_equipment_structure_tracks_named_slots()
	_is_backpack_category_allowlist()
	return result()


func _defaults_to_capacity_six_and_empty() -> void:
	var inventory: InventoryState = InventoryState.new()
	assert_equal(InventoryState.DEFAULT_BACKPACK_CAPACITY, 6, "DEFAULT_BACKPACK_CAPACITY must be 6 (FR51).")
	assert_equal(inventory.capacity, 6, "A fresh inventory defaults to capacity 6.")
	assert_equal(inventory.size(), 0, "A fresh inventory has an empty backpack.")
	assert_false(inventory.is_full(), "A fresh inventory is not full.")
	assert_true(inventory.has_capacity(), "A fresh inventory has capacity.")
	# A non-positive / non-int capacity resolves to the default (lenient value-object construction).
	assert_equal(InventoryState.new(0).capacity, 6, "A zero capacity resolves to the default.")
	assert_equal(InventoryState.new(-3).capacity, 6, "A negative capacity resolves to the default.")


func _is_full_and_has_capacity_track_the_boundary() -> void:
	# A small capacity-2 inventory so the boundary is cheap to exercise.
	var inventory: InventoryState = InventoryState.new(2)
	assert_false(inventory.is_full(), "Empty capacity-2: not full.")
	inventory.append_slot(&"minor_healing_draught", &"consumable")
	assert_false(inventory.is_full(), "1/2 slots: not full.")
	assert_true(inventory.has_capacity(), "1/2 slots: has capacity.")
	inventory.append_slot(&"warding_salve", &"consumable")
	assert_true(inventory.is_full(), "2/2 slots: full (size >= capacity).")
	assert_false(inventory.has_capacity(), "2/2 slots: no capacity.")


func _append_adds_exactly_one_slot() -> void:
	var inventory: InventoryState = InventoryState.new()
	var index: int = inventory.append_slot(&"padded_vest", &"armor")
	assert_equal(index, 0, "The first appended slot has index 0.")
	assert_equal(inventory.size(), 1, "Appending one item increases the slot count by exactly one.")
	var slot: Dictionary = inventory.backpack[0]
	assert_equal(slot.get("item_id"), "padded_vest", "The appended slot records the item id (as a plain String).")
	assert_equal(slot.get("category"), "armor", "The appended slot records the category.")
	assert_equal(slot.get("quantity"), 1, "The appended slot defaults quantity to 1 (no stacking).")
	var second_index: int = inventory.append_slot(&"chain_hauberk", &"armor")
	assert_equal(second_index, 1, "The second appended slot has index 1.")
	assert_equal(inventory.size(), 2, "A second append increases the slot count to two.")


func _no_stacking_a_repeat_pickup_is_a_second_slot() -> void:
	# AC1: stacking is OFF. Two pickups of the SAME id are TWO slots (each quantity 1), NOT one slot quantity 2.
	var inventory: InventoryState = InventoryState.new()
	inventory.append_slot(&"health_morsel", &"pickup")
	inventory.append_slot(&"health_morsel", &"pickup")
	assert_equal(inventory.size(), 2, "A repeat pickup of the same id is a SECOND slot (no stacking).")
	assert_equal(inventory.backpack[0].get("quantity"), 1, "The first same-id slot stays quantity 1.")
	assert_equal(inventory.backpack[1].get("quantity"), 1, "The second same-id slot stays quantity 1 (no quantity++).")
	assert_equal(inventory.backpack[0].get("item_id"), "health_morsel", "Both slots carry the same item id.")
	assert_equal(inventory.backpack[1].get("item_id"), "health_morsel", "Both slots carry the same item id.")


func _to_dictionary_emits_exactly_the_pinned_keys() -> void:
	var inventory: InventoryState = InventoryState.new()
	inventory.append_slot(&"ember_flask", &"consumable")
	var data: Dictionary = inventory.to_dictionary()
	# Exact-key contract: the produced key set equals the pinned key set (no missing, no surprise key).
	assert_equal(data.size(), InventoryState.DICTIONARY_KEYS.size(), "to_dictionary() must emit exactly the pinned number of keys.")
	for key: String in InventoryState.DICTIONARY_KEYS:
		assert_true(data.has(key), "to_dictionary() must contain the pinned key '%s'." % key)
	for key: Variant in data.keys():
		assert_true(InventoryState.DICTIONARY_KEYS.has(str(key)), "to_dictionary() must not introduce a surprise key '%s'." % str(key))
	assert_equal(data.get("capacity"), 6, "capacity serializes as a raw int (small bounded value, not a seed).")
	assert_true(data.get("backpack") is Array, "backpack serializes as an Array.")
	assert_true(data.get("equipment") is Dictionary, "equipment serializes as a Dictionary.")


func _slot_shape_carries_exactly_the_pinned_slot_keys() -> void:
	var inventory: InventoryState = InventoryState.new()
	inventory.append_slot(&"focus_ember", &"pickup")
	var slot: Dictionary = inventory.to_dictionary().get("backpack")[0]
	assert_equal(slot.size(), InventoryState.SLOT_KEYS.size(), "A backpack slot must carry exactly the pinned slot key count.")
	for key: String in InventoryState.SLOT_KEYS:
		assert_true(slot.has(key), "A backpack slot must contain the pinned slot key '%s'." % key)
	for key: Variant in slot.keys():
		assert_true(InventoryState.SLOT_KEYS.has(str(key)), "A backpack slot must not introduce a surprise key '%s'." % str(key))


func _round_trips_through_real_json() -> void:
	var inventory: InventoryState = InventoryState.new(4)
	inventory.append_slot(&"padded_vest", &"armor")
	inventory.append_slot(&"minor_healing_draught", &"consumable")
	inventory.equipment = InventoryState._normalize_equipment({"weapon": "practice_blade", "support": "none"})
	# Round-trip through a REAL JSON pass (the small ids + bounded ints survive stringify/parse).
	var json_round_trip: Variant = JSON.parse_string(JSON.stringify(inventory.to_dictionary()))
	assert_true(json_round_trip is Dictionary, "InventoryState.to_dictionary() must survive a JSON round-trip.")
	var restored: InventoryState = InventoryState.try_from_dictionary(json_round_trip)
	assert_equal(restored.capacity, 4, "Round-trip must preserve capacity.")
	assert_equal(restored.size(), 2, "Round-trip must preserve the slot count.")
	assert_equal(restored.backpack[0].get("item_id"), "padded_vest", "Round-trip must preserve slot 0 item id.")
	assert_equal(restored.backpack[0].get("category"), "armor", "Round-trip must preserve slot 0 category.")
	assert_equal(restored.backpack[1].get("item_id"), "minor_healing_draught", "Round-trip must preserve slot 1 item id.")
	assert_equal(restored.equipped_in(&"weapon"), &"practice_blade", "Round-trip must preserve the equipped weapon.")
	assert_equal(restored.equipped_in(&"support"), &"none", "Round-trip must preserve the equipped support (incl. none).")
	# The whole projection is byte-identical across the round-trip.
	assert_equal(JSON.stringify(restored.to_dictionary()), JSON.stringify(inventory.to_dictionary()), "A round-trip must be byte-identical.")


func _copy_is_a_deep_copy() -> void:
	var inventory: InventoryState = InventoryState.new()
	inventory.append_slot(&"warded_plate", &"armor")
	inventory.equipment = InventoryState._normalize_equipment({"armor": "warded_plate"})
	var copied: InventoryState = inventory.copy()
	assert_true(copied != inventory, "copy() must return a distinct instance.")
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(inventory.to_dictionary()), "copy() must reproduce a byte-identical projection.")
	# Mutating the COPY's backpack must NOT perturb the source (deep copy, not a shared reference).
	copied.append_slot(&"chain_hauberk", &"armor")
	assert_equal(inventory.size(), 1, "Mutating the copy's backpack must NOT perturb the source backpack.")
	assert_equal(copied.size(), 2, "The copy's backpack reflects its own mutation.")
	# Mutating the COPY's slot dict in place must NOT perturb the source slot.
	copied.backpack[0]["quantity"] = 99
	assert_equal(inventory.backpack[0].get("quantity"), 1, "Mutating the copy's slot dict must NOT perturb the source slot.")


func _returned_dictionary_mutation_does_not_perturb_a_fresh_projection() -> void:
	var inventory: InventoryState = InventoryState.new()
	inventory.append_slot(&"padded_vest", &"armor")
	var data: Dictionary = inventory.to_dictionary()
	data["capacity"] = 999
	data["backpack"][0]["item_id"] = "tampered"
	data["equipment"]["weapon"] = "tampered"
	var fresh: Dictionary = inventory.to_dictionary()
	assert_equal(fresh.get("capacity"), 6, "A mutation of a returned dict must NOT perturb a fresh to_dictionary() (capacity).")
	assert_equal(fresh.get("backpack")[0].get("item_id"), "padded_vest", "A mutation of a returned dict's slot must NOT perturb a fresh to_dictionary().")
	assert_false((fresh.get("equipment") as Dictionary).has("weapon"), "A mutation of a returned dict's equipment must NOT perturb a fresh to_dictionary().")


func _try_from_dictionary_is_lenient_on_partial_and_empty() -> void:
	# An EMPTY dict defaults every field cleanly (never crashes / never null).
	var empty: InventoryState = InventoryState.try_from_dictionary({})
	assert_true(empty != null, "try_from_dictionary({}) must return an inventory (lenient, never null).")
	assert_equal(empty.capacity, 6, "An empty dict defaults capacity to 6.")
	assert_equal(empty.size(), 0, "An empty dict defaults to an empty backpack.")
	# A PARTIAL dict fills present fields + defaults absent ones.
	var partial: InventoryState = InventoryState.try_from_dictionary({"capacity": 3})
	assert_equal(partial.capacity, 3, "A partial dict fills the present capacity.")
	assert_equal(partial.size(), 0, "A partial dict defaults the absent backpack to empty.")


func _try_from_dictionary_drops_surplus_slot_keys_and_clamps_quantity() -> void:
	# A legacy/foreign slot with a surplus key + a quantity < 1 is normalized to EXACTLY the pinned slot shape
	# with quantity clamped to >= 1 (reject-don't-silently-keep — the slot shape can never carry a surprise key).
	var dirty: Dictionary = {
		"capacity": 6,
		"backpack": [
			{"item_id": "padded_vest", "category": "armor", "quantity": 0, "surprise": "x"},
			"not-a-dict"
		],
		"equipment": {}
	}
	var restored: InventoryState = InventoryState.try_from_dictionary(dirty)
	assert_equal(restored.size(), 1, "A non-dict backpack entry is dropped (only the valid slot survives).")
	var slot: Dictionary = restored.backpack[0]
	assert_equal(slot.size(), InventoryState.SLOT_KEYS.size(), "A normalized slot carries exactly the pinned slot keys (the surprise key is dropped).")
	assert_false(slot.has("surprise"), "A normalized slot drops a surplus key.")
	assert_equal(slot.get("quantity"), 1, "A quantity below 1 clamps to 1 (no zero/negative quantities).")


func _equipment_structure_tracks_named_slots() -> void:
	# The equipment structure tracks the four equippable named slots; an empty slot reads &"". Unknown slot keys
	# + non-string ids are dropped (only the known weapon/armor/jewelry/support slots are carried).
	var inventory: InventoryState = InventoryState.new()
	assert_equal(inventory.equipped_in(&"weapon"), &"", "An empty equipment slot reads &\"\".")
	inventory.equipment = InventoryState._normalize_equipment({
		"weapon": "practice_blade",
		"jewelry": "",
		"unknown_slot": "x",
		"armor": 123
	})
	assert_equal(inventory.equipped_in(&"weapon"), &"practice_blade", "A populated weapon slot reads its item id.")
	assert_equal(inventory.equipped_in(&"jewelry"), &"", "An empty-string equipped id is omitted (empty slot).")
	assert_equal(inventory.equipped_in(&"armor"), &"", "A non-string equipped id is dropped.")
	assert_false(inventory.equipment.has("unknown_slot"), "An unknown equipment slot key is dropped.")
	assert_equal(InventoryState.EQUIPMENT_SLOTS, [&"weapon", &"armor", &"jewelry", &"support"] as Array[StringName], "The named equipment slots are the four equippable categories.")


func _is_backpack_category_allowlist() -> void:
	for category: StringName in [&"weapon", &"armor", &"jewelry", &"support", &"consumable", &"pickup"]:
		assert_true(InventoryState.is_backpack_category(category), "%s is an allowed backpack category." % String(category))
	assert_false(InventoryState.is_backpack_category(&"gold_reward"), "gold_reward is NOT a backpack item category.")
	assert_false(InventoryState.is_backpack_category(&"bogus"), "An unknown category is rejected.")
