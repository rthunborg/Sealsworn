extends "res://tests/unit/test_case.gd"

# Story 10.4 (AC6 — the consumable-frequency readiness FACT) — the warding_salve reward-table-absence tripwire.
#
# The MVP playtest comprehension checklist (§8.2,
# _bmad-output/planning-artifacts/mvp-playtest-comprehension-checklist.md) FLAGS warding_salve for the
# frequency-tuning pass because it is weighted into NO reward table, so a real run can NEVER roll it from a reward
# offer — the exact AC6 trigger "never appears across the approved sample" (obtainable only via a direct
# PickupItemCommand). This test PROVES that fact LIVE from RewardTableRepository (not a hard-coded expectation), so:
#   - the checklist's §8.2 finding is objectively backed by a headless assertion, and
#   - it is a DELIBERATE-UPDATE TRIPWIRE: if a future story WEIGHTS warding_salve into a reward table (one of the two
#     dispositions §8.2 hands the tuning pass), THIS assertion FAILS LOUD, forcing the checklist finding to be updated.
#
# It asserts a readiness FACT (which content ids are reachable via reward tables), NOT new gameplay behavior. It reads
# the shipped repositories read-only and mutates nothing — the reward tables are UNCHANGED by Story 10.4.

const ConsumableRepository = preload("res://scripts/content/repositories/consumable_repository.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")
const RewardTableRepository = preload("res://scripts/content/repositories/reward_table_repository.gd")

const WARDING_SALVE := &"warding_salve"
const MINOR_HEALING_DRAUGHT := &"minor_healing_draught"
const EMBER_FLASK := &"ember_flask"

func run() -> Dictionary:
	_warding_salve_is_a_real_baseline_consumable()
	_warding_salve_is_absent_from_every_reward_table()
	_the_other_two_consumables_are_present_in_a_reward_table()
	return result()


# Setup: warding_salve is a genuine baseline consumable (so its reward-table absence is a real gap, not a typo).
func _warding_salve_is_a_real_baseline_consumable() -> void:
	var consumables: ConsumableRepository = ConsumableRepository.create_baseline_repository()
	assert_true(consumables.has_consumable(WARDING_SALVE), "warding_salve should be a registered baseline consumable (the finding is about a REAL item).")
	assert_true(ConsumableRepository.BASELINE_CONSUMABLE_IDS.has(WARDING_SALVE), "warding_salve should be in the baseline consumable ids.")


# THE AC6 FINDING (tripwire): warding_salve appears in NO reward-table entry's content_id set — read LIVE from the
# repository. A future story that weights it into a table makes this FAIL LOUD (the deliberate-update tripwire).
func _warding_salve_is_absent_from_every_reward_table() -> void:
	var reward_ids: Array[StringName] = _all_reward_table_content_ids()
	assert_false(
		reward_ids.has(WARDING_SALVE),
		"warding_salve must be absent from EVERY reward table (the AC6 'never appears across the approved sample' finding). If a future story weights it in, UPDATE the checklist §8.2 finding — this tripwire fired by design."
	)


# Positive control: the two consumables that ARE weighted in resolve (so the test proves the ABSENCE is specific to
# warding_salve, not a broken query that finds nothing).
func _the_other_two_consumables_are_present_in_a_reward_table() -> void:
	var reward_ids: Array[StringName] = _all_reward_table_content_ids()
	assert_true(reward_ids.has(MINOR_HEALING_DRAUGHT), "minor_healing_draught IS weighted into standard_combat_reward (positive control — the query finds present consumables).")
	assert_true(reward_ids.has(EMBER_FLASK), "ember_flask IS weighted into elite_combat_reward (positive control).")


# Every content_id referenced by any baseline reward-table entry (across all categories), read live from the repo.
func _all_reward_table_content_ids() -> Array[StringName]:
	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository()
	var ids: Array[StringName] = []
	for table_id: StringName in repository.reward_table_ids():
		var definition: RewardTableDefinition = repository.get_reward_table(table_id)
		for entry_value: Variant in definition.reward_entries():
			var entry: Dictionary = entry_value
			var content_id: StringName = StringName(str(entry.get("content_id")))
			if not ids.has(content_id):
				ids.append(content_id)
	return ids
