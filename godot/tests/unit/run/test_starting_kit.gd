extends "res://tests/unit/test_case.gd"

# Story 5.3 Task 5.2 — StartingKit (the applied-kit value object) construct/copy/round-trip + exact-key contract.
#
# StartingKit is the small typed by-id-reference DTO RunStartCommand records on the started RunState when a
# confirmed-selectable class starts a run (the resolved weapon/support ids + baseline_hp + the two string-shape
# passive ids). This test pins: construction stores every field; to_dictionary() emits EXACTLY the pinned key
# set (a key never silently appears/vanishes — the TacticalBoardViewModel precedent); a to_dictionary() ->
# try_from_dictionary() round-trip preserves every field; copy() reproduces every field; a returned-dict
# mutation does not perturb a fresh to_dictionary() (no shared mutable state); try_from_dictionary is lenient
# (a partial/empty dict defaults cleanly, never crashes).

const StartingKit = preload("res://scripts/run/starting_kit.gd")

func run() -> Dictionary:
	_construction_stores_every_field()
	_to_dictionary_emits_exactly_the_pinned_keys()
	_round_trips_through_dictionary()
	_copy_reproduces_every_field()
	_returned_dictionary_mutation_does_not_perturb_a_fresh_projection()
	_try_from_dictionary_is_lenient_on_partial_and_empty()
	_none_support_is_a_valid_recorded_support_id()
	return result()


func _construction_stores_every_field() -> void:
	var kit: StartingKit = StartingKit.new(&"warrior", &"sword", &"shield", 18, &"warrior_unbreakable_guard", &"warrior_blade_and_board")
	assert_equal(kit.class_id, &"warrior", "StartingKit should store the class id.")
	assert_equal(kit.weapon_id, &"sword", "StartingKit should store the weapon id.")
	assert_equal(kit.support_id, &"shield", "StartingKit should store the support id.")
	assert_equal(kit.baseline_hp, 18, "StartingKit should store the baseline HP.")
	assert_equal(kit.class_passive_id, &"warrior_unbreakable_guard", "StartingKit should store the class passive id.")
	assert_equal(kit.equipment_synergy_passive_id, &"warrior_blade_and_board", "StartingKit should store the equipment-synergy passive id.")


func _to_dictionary_emits_exactly_the_pinned_keys() -> void:
	var kit: StartingKit = StartingKit.new(&"pyromancer", &"staff", &"tome", 18, &"pyromancer_kindling_focus", &"pyromancer_arcane_conduit")
	var data: Dictionary = kit.to_dictionary()
	# Exact-key contract: the produced key set equals the pinned key set (no missing, no surprise key).
	assert_equal(data.size(), StartingKit.DICTIONARY_KEYS.size(), "to_dictionary() must emit exactly the pinned number of keys.")
	for key: String in StartingKit.DICTIONARY_KEYS:
		assert_true(data.has(key), "to_dictionary() must contain the pinned key '%s'." % key)
	for key: Variant in data.keys():
		assert_true(StartingKit.DICTIONARY_KEYS.has(str(key)), "to_dictionary() must not introduce a surprise key '%s'." % str(key))
	# The ids serialize as plain Strings; baseline_hp stays a raw int (small bounded value, not a seed).
	assert_equal(data.get("class_id"), "pyromancer", "class_id should serialize as a plain String.")
	assert_equal(data.get("baseline_hp"), 18, "baseline_hp should serialize as a raw int.")
	assert_true(data.get("class_id") is String, "class_id must serialize as a String, not a StringName.")


func _round_trips_through_dictionary() -> void:
	var kit: StartingKit = StartingKit.new(&"ranger", &"bow", &"none", 18, &"ranger_steady_aim", &"ranger_hunters_quiver")
	# Round-trip through a REAL JSON pass (the small ids + bounded hp survive stringify/parse).
	var json_round_trip: Variant = JSON.parse_string(JSON.stringify(kit.to_dictionary()))
	assert_true(json_round_trip is Dictionary, "StartingKit.to_dictionary() must survive a JSON round-trip.")
	var restored: StartingKit = StartingKit.try_from_dictionary(json_round_trip)
	assert_equal(restored.class_id, kit.class_id, "Round-trip must preserve class_id.")
	assert_equal(restored.weapon_id, kit.weapon_id, "Round-trip must preserve weapon_id.")
	assert_equal(restored.support_id, kit.support_id, "Round-trip must preserve support_id (incl. none).")
	assert_equal(restored.baseline_hp, kit.baseline_hp, "Round-trip must preserve baseline_hp.")
	assert_equal(restored.class_passive_id, kit.class_passive_id, "Round-trip must preserve class_passive_id.")
	assert_equal(restored.equipment_synergy_passive_id, kit.equipment_synergy_passive_id, "Round-trip must preserve equipment_synergy_passive_id.")


func _copy_reproduces_every_field() -> void:
	var kit: StartingKit = StartingKit.new(&"warrior", &"sword", &"shield", 18, &"warrior_unbreakable_guard", &"warrior_blade_and_board")
	var copied: StartingKit = kit.copy()
	assert_true(copied != kit, "copy() must return a distinct instance.")
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(kit.to_dictionary()), "copy() must reproduce a byte-identical projection.")


func _returned_dictionary_mutation_does_not_perturb_a_fresh_projection() -> void:
	var kit: StartingKit = StartingKit.new(&"warrior", &"sword", &"shield", 18, &"warrior_unbreakable_guard", &"warrior_blade_and_board")
	var data: Dictionary = kit.to_dictionary()
	data["weapon_id"] = "tampered"
	data["baseline_hp"] = 999
	var fresh: Dictionary = kit.to_dictionary()
	assert_equal(fresh.get("weapon_id"), "sword", "A mutation of a returned dict must NOT perturb a fresh to_dictionary().")
	assert_equal(fresh.get("baseline_hp"), 18, "A mutation of a returned dict must NOT perturb a fresh to_dictionary() (hp).")


func _try_from_dictionary_is_lenient_on_partial_and_empty() -> void:
	# An EMPTY dict defaults every field cleanly (never crashes / never null).
	var empty: StartingKit = StartingKit.try_from_dictionary({})
	assert_true(empty != null, "try_from_dictionary({}) must return a kit (lenient, never null).")
	assert_equal(empty.class_id, &"", "An empty dict defaults class_id to &\"\".")
	assert_equal(empty.baseline_hp, 0, "An empty dict defaults baseline_hp to 0.")
	# A PARTIAL dict fills present fields + defaults absent ones.
	var partial: StartingKit = StartingKit.try_from_dictionary({"class_id": "ranger", "weapon_id": "bow"})
	assert_equal(partial.class_id, &"ranger", "A partial dict fills the present class_id.")
	assert_equal(partial.weapon_id, &"bow", "A partial dict fills the present weapon_id.")
	assert_equal(partial.support_id, &"", "A partial dict defaults the absent support_id to &\"\".")
	assert_equal(partial.baseline_hp, 0, "A partial dict defaults the absent baseline_hp to 0.")


func _none_support_is_a_valid_recorded_support_id() -> void:
	# Ranger's recorded support id is &"none" (the real SUPPORT_NONE). It is stored + round-tripped as a normal
	# id — NOT a sentinel for "no support" and NOT special-cased away.
	var kit: StartingKit = StartingKit.new(&"ranger", &"bow", &"none", 18, &"ranger_steady_aim", &"ranger_hunters_quiver")
	assert_equal(kit.support_id, &"none", "Ranger's kit records the real &\"none\" support id verbatim.")
	var restored: StartingKit = StartingKit.try_from_dictionary(kit.to_dictionary())
	assert_equal(restored.support_id, &"none", "A round-tripped Ranger kit preserves the &\"none\" support id.")
