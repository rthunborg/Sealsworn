extends "res://tests/unit/test_case.gd"

# Story 11.6 Task 1/2 (AC1/AC2, FR59/FR43/FR95): MetaSpendRules — the pure const-config spend calculator (the
# MetaAwardRules / UnlockProgressRules template). Pins: the two spendable class unlocks (necromancer/shadeblade — the
# two locked baselines, FR43) with their fixed costs + `<class>_unlocked` flag keys; is_class_unlock fail-closed;
# class_unlock_cost / class_unlock_flag_key / class_id_for_unlock; the AC2 seam source unlocked_class_ids_for(profile)
# (an empty profile -> empty set; a flag-set profile -> the class id); the spend-ledger read; and the FR95 STRUCTURAL
# guard — NO produced unlock flag key is a raw-stat unlock key (UnlockProgressRules.is_raw_stat_unlock_key produces
# none), so meta power stays a VARIETY gate, never a raw combat stat ladder.

const MetaSpendRules = preload("res://scripts/save/meta_spend_rules.gd")
const UnlockProgressRules = preload("res://scripts/save/unlock_progress_rules.gd")

func run() -> Dictionary:
	_class_unlocks_are_the_two_locked_baselines_with_fixed_costs()
	_is_class_unlock_is_fail_closed()
	_cost_and_flag_and_class_reads_are_stable()
	_unlocked_class_ids_for_empty_profile_is_empty()
	_unlocked_class_ids_for_reads_the_applied_flags()
	_spend_ledger_read_is_fail_safe()
	_no_produced_unlock_flag_key_is_a_raw_stat_key_fr95()
	return result()


func _class_unlocks_are_the_two_locked_baselines_with_fixed_costs() -> void:
	# v0 declares EXACTLY the two locked baselines as spendable class unlocks (capped/sparse — FR43/FR95).
	var ids: Array = MetaSpendRules.CLASS_UNLOCKS.keys()
	ids.sort()
	assert_equal(ids, ["necromancer", "shadeblade"], "The spendable class unlocks must be exactly the two locked baselines.")
	assert_equal(MetaSpendRules.class_unlock_cost("necromancer"), 3, "Necromancer unlock costs a fixed 3 Oath Shards.")
	assert_equal(MetaSpendRules.class_unlock_cost("shadeblade"), 5, "Shadeblade unlock costs a fixed 5 Oath Shards.")


func _is_class_unlock_is_fail_closed() -> void:
	assert_true(MetaSpendRules.is_class_unlock("necromancer"), "necromancer is a spendable class unlock.")
	assert_true(MetaSpendRules.is_class_unlock("shadeblade"), "shadeblade is a spendable class unlock.")
	assert_false(MetaSpendRules.is_class_unlock("warrior"), "An already-selectable class is NOT a spendable unlock.")
	assert_false(MetaSpendRules.is_class_unlock("buy_max_hp"), "A raw-stat purchase is NOT a spendable unlock (fail-closed).")
	assert_false(MetaSpendRules.is_class_unlock(""), "An empty id is NOT a spendable unlock (fail-closed).")


func _cost_and_flag_and_class_reads_are_stable() -> void:
	assert_equal(MetaSpendRules.class_unlock_cost("does_not_exist"), -1, "An unknown unlock has cost -1 (the fail-closed sentinel).")
	assert_equal(MetaSpendRules.class_unlock_flag_key("necromancer"), "necromancer_unlocked", "The necromancer flag key is stable.")
	assert_equal(MetaSpendRules.class_unlock_flag_key("shadeblade"), "shadeblade_unlocked", "The shadeblade flag key is stable.")
	assert_equal(MetaSpendRules.class_unlock_flag_key("does_not_exist"), "", "An unknown unlock has an empty flag key.")
	assert_equal(MetaSpendRules.class_id_for_unlock("necromancer"), "necromancer", "The necromancer unlock maps to the necromancer class.")
	assert_equal(MetaSpendRules.class_id_for_unlock("does_not_exist"), "", "An unknown unlock maps to no class.")


func _unlocked_class_ids_for_empty_profile_is_empty() -> void:
	# AC2 seam source: an empty unlock_progress yields an EMPTY unlocked set (so a null-profile view model / gate is
	# byte-identical to today's static behavior).
	assert_equal(MetaSpendRules.unlocked_class_ids_for({}).size(), 0, "An empty profile unlocks no classes.")
	# A profile whose flags are false unlocks nothing.
	assert_equal(MetaSpendRules.unlocked_class_ids_for({"necromancer_unlocked": false}).size(), 0, "A false flag unlocks nothing.")


func _unlocked_class_ids_for_reads_the_applied_flags() -> void:
	# AC2 seam source: a set applied-unlock flag surfaces the class id.
	var one: Array[String] = MetaSpendRules.unlocked_class_ids_for({"necromancer_unlocked": true})
	assert_equal(one, ["necromancer"], "A set necromancer flag unlocks necromancer.")
	# Both flags -> both class ids in declaration order (necromancer, shadeblade).
	var both: Array[String] = MetaSpendRules.unlocked_class_ids_for({"necromancer_unlocked": true, "shadeblade_unlocked": true})
	assert_equal(both, ["necromancer", "shadeblade"], "Both flags unlock both classes in declaration order.")
	# An unrelated flag (e.g. a seal-gate threshold flag) does NOT unlock a class.
	var unrelated: Array[String] = MetaSpendRules.unlocked_class_ids_for({"seal_gate_1_unlocked": true})
	assert_equal(unrelated.size(), 0, "An unrelated unlock flag (a seal-gate threshold) unlocks no class.")


func _spend_ledger_read_is_fail_safe() -> void:
	assert_equal(MetaSpendRules.oath_shards_spent_in({}), 0, "An empty profile has spent 0.")
	assert_equal(MetaSpendRules.oath_shards_spent_in({"_oath_shards_spent": 8}), 8, "The ledger read returns the recorded spend.")
	assert_equal(MetaSpendRules.oath_shards_spent_in({"_oath_shards_spent": -4}), 0, "A negative ledger reads as 0 (fail-safe floor).")
	assert_equal(MetaSpendRules.oath_shards_spent_in({"_oath_shards_spent": "garbage"}), 0, "A malformed ledger reads as 0 (fail-safe).")
	# A float-valued ledger (a JSON round-trip could yield a float) coerces to int.
	assert_equal(MetaSpendRules.oath_shards_spent_in({"_oath_shards_spent": 5.0}), 5, "A float ledger coerces to int.")


func _no_produced_unlock_flag_key_is_a_raw_stat_key_fr95() -> void:
	# FR95 STRUCTURAL guard: NONE of the applied-unlock flag keys 11.6 produces is a raw-stat unlock key (the meta power
	# is a VARIETY gate — a class becomes selectable — never a repeatable raw combat stat: damage/max_hp/armor/crit/dodge).
	for unlock_id: String in MetaSpendRules.CLASS_UNLOCKS.keys():
		var flag_key: String = MetaSpendRules.class_unlock_flag_key(unlock_id)
		assert_false(UnlockProgressRules.is_raw_stat_unlock_key(flag_key), "No produced unlock flag key may be a raw-stat key (FR95): %s" % flag_key)
