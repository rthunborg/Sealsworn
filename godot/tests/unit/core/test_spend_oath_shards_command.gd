extends "res://tests/unit/test_case.gd"

# Story 11.6 Task 1/3 (AC1/AC3, FR59/FR43/FR95): the SpendOathShardsCommand — the meta-SPEND application (the
# AwardMetaProgressCommand counterpart at the OPPOSITE sign). A valid spend subtracts profile.oath_shards by the exact
# cost, sets the applied-unlock VARIETY flag (the class becomes selectable), raises the spend ledger, emits the honest
# oath_shards_spent event (before - amount == after), and the profile round-trips through the repository; an unaffordable
# spend rejects with insufficient_oath_shards + ZERO mutation + ZERO event; an unknown unlock rejects fail-closed; an
# already-applied unlock is an idempotent no-op (ZERO charge — the retry-safety / AC3 idempotency); sequence_id <= 0
# rejects FIRST; on ANY reject the profile is byte-identical; a spend touches NONE of the four run-end idempotency
# markers (AC3 caller-ordering safety); FR28 — a spend cannot increase oath_shards (it only subtracts).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MetaSpendRules = preload("res://scripts/save/meta_spend_rules.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const SpendOathShardsCommand = preload("res://scripts/core/commands/spend_oath_shards_command.gd")

const TEST_PROFILE_PATH := "user://test_spend_profile.json"

func run() -> Dictionary:
	_valid_spend_subtracts_sets_flag_emits_event()
	_valid_spend_round_trips_through_the_repository()
	_unaffordable_spend_rejects_with_zero_mutation()
	_unknown_unlock_rejects_fail_closed()
	_already_applied_unlock_is_an_idempotent_no_op()
	_invalid_sequence_id_is_rejected()
	_null_profile_is_rejected()
	_reject_leaves_profile_byte_identical()
	_spend_touches_none_of_the_four_run_end_markers()
	_spend_cannot_fabricate_shards_fr28()
	_a_second_distinct_class_unlock_is_a_separate_spend()
	_cleanup()
	return result()


func _valid_spend_subtracts_sets_flag_emits_event() -> void:
	# A profile with 10 shards buys necromancer (cost 3): total drops to 7, the flag is set, the ledger records 3, and the
	# honest oath_shards_spent event fires (before - amount == after).
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 10

	var command: SpendOathShardsCommand = SpendOathShardsCommand.new(profile, "necromancer", 1)
	var spend_result: ActionResult = command.execute(null)

	assert_true(spend_result.succeeded, "An affordable spend should succeed: %s" % spend_result.metadata)
	assert_equal(spend_result.metadata.get("amount"), 3, "The result should carry the exact cost (necromancer == 3).")
	assert_equal(profile.oath_shards, 7, "The profile's cross-run total must drop by the exact cost (10 - 3 == 7).")
	assert_equal(spend_result.metadata.get("oath_shards_after"), 7, "oath_shards_after must match the new total.")
	assert_equal(spend_result.metadata.get("class_id"), "necromancer", "The result should carry the unlocked class id.")
	assert_true(bool(profile.unlock_progress.get("necromancer_unlocked", false)), "The applied-unlock VARIETY flag must be set.")
	assert_equal(MetaSpendRules.oath_shards_spent_in(profile.unlock_progress), 3, "The spend ledger must record the spent amount.")

	# The meta-spend event is emitted and self-consistent (before - amount == after).
	assert_equal(spend_result.events.size(), 1, "Exactly one oath_shards_spent event should be emitted.")
	var event: DomainEvent = spend_result.events[0]
	assert_equal(event.event_type, DomainEvent.Type.OATH_SHARDS_SPENT, "The emitted event must be oath_shards_spent.")
	assert_equal(event.payload.get("amount"), 3, "The event must carry the spent amount.")
	assert_equal(event.payload.get("oath_shards_before"), 10, "The event must carry the before total.")
	assert_equal(event.payload.get("oath_shards_after"), 7, "The event must carry the after total.")
	assert_equal(event.payload.get("reason"), "class_unlock", "The event must carry the class-unlock reason.")
	assert_equal(event.payload.get("unlock_id"), "necromancer", "The event must carry the unlock id.")
	# The emitted event is a valid, round-trippable domain event.
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parse_result.succeeded, "The emitted spend event must be a valid round-trippable domain event: %s" % parse_result.metadata)


func _valid_spend_round_trips_through_the_repository() -> void:
	# The spent profile persists + reads back with the lowered total + the applied-unlock flag + the ledger (AC1/AC3).
	_cleanup()
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 8

	var spend_result: ActionResult = SpendOathShardsCommand.new(profile, "shadeblade", 1).execute(null)
	assert_true(spend_result.succeeded, "The spend should succeed before persisting.")

	var repository: ProfileRepository = ProfileRepository.new()
	var write_result: ActionResult = repository.write_profile(profile, TEST_PROFILE_PATH)
	assert_true(write_result.succeeded, "The spent profile should persist: %s" % write_result.metadata)

	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "The spent profile should read back.")
	var restored: ProfileSnapshot = read_result.metadata.get("snapshot")
	assert_equal(restored.oath_shards, 3, "The persisted profile must retain the lowered total (8 - 5 == 3).")
	assert_true(bool(restored.unlock_progress.get("shadeblade_unlocked", false)), "The persisted profile must retain the applied-unlock flag.")
	assert_equal(MetaSpendRules.oath_shards_spent_in(restored.unlock_progress), 5, "The persisted profile must retain the spend ledger.")
	_cleanup()


func _unaffordable_spend_rejects_with_zero_mutation() -> void:
	# AC1: profile.oath_shards < cost -> insufficient_oath_shards with the shortfall in metadata, ZERO mutation, ZERO event.
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 2  # necromancer costs 3 -> short by 1.
	var profile_before: Dictionary = profile.to_dictionary()

	var spend_result: ActionResult = SpendOathShardsCommand.new(profile, "necromancer", 1).execute(null)

	assert_true(spend_result.is_error(), "An unaffordable spend must be rejected.")
	assert_equal(spend_result.error_code, &"insufficient_oath_shards", "An unaffordable spend must reject with the stable code.")
	assert_equal(spend_result.metadata.get("shortfall"), 1, "The reject must carry the shortfall.")
	assert_equal(spend_result.metadata.get("cost"), 3, "The reject must carry the cost.")
	assert_false(spend_result.has_events(), "An unaffordable spend must emit NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "An unaffordable spend must leave the profile byte-identical (ZERO charge).")


func _unknown_unlock_rejects_fail_closed() -> void:
	# An unlock_id that is not a declared spendable class unlock is rejected fail-closed (ZERO mutation).
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 100
	var profile_before: Dictionary = profile.to_dictionary()

	var spend_result: ActionResult = SpendOathShardsCommand.new(profile, "buy_max_hp", 1).execute(null)

	assert_true(spend_result.is_error(), "An unknown unlock must be rejected fail-closed.")
	assert_equal(spend_result.error_code, &"unknown_unlock", "An unknown unlock must reject with the stable code.")
	assert_false(spend_result.has_events(), "An unknown unlock must emit NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "An unknown unlock must leave the profile byte-identical.")


func _already_applied_unlock_is_an_idempotent_no_op() -> void:
	# AC3 (the idempotency crux): re-applying an ALREADY-applied unlock is a NO-OP — ZERO second charge, ZERO event. This
	# is the retry-safety (a persist-failure retry re-reads the profile with the flag set + rejects here without double-
	# charging).
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 10

	var first: ActionResult = SpendOathShardsCommand.new(profile, "necromancer", 1).execute(null)
	assert_true(first.succeeded, "The first spend should succeed.")
	var total_after_first: int = profile.oath_shards
	var profile_after_first: Dictionary = profile.to_dictionary()

	# Re-apply the SAME unlock (the flag is now set).
	var second: ActionResult = SpendOathShardsCommand.new(profile, "necromancer", 2).execute(null)
	assert_true(second.is_error(), "Re-applying an already-applied unlock must be rejected (no double-unlock, no double-charge).")
	assert_equal(second.error_code, &"unlock_already_applied", "A re-apply must reject with the stable idempotency code.")
	assert_false(second.has_events(), "A re-apply must emit NO second event.")
	assert_equal(profile.oath_shards, total_after_first, "A re-apply must NOT charge again.")
	assert_equal(profile.to_dictionary(), profile_after_first, "A re-apply must leave the profile byte-identical (no double-mutation).")


func _invalid_sequence_id_is_rejected() -> void:
	# The 4.3/8.3 self-consistency gate: sequence_id <= 0 is rejected FIRST (before any mutation).
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 10
	var profile_before: Dictionary = profile.to_dictionary()

	var spend_result: ActionResult = SpendOathShardsCommand.new(profile, "necromancer", 0).execute(null)
	assert_true(spend_result.is_error(), "A non-positive sequence id must be rejected.")
	assert_equal(spend_result.error_code, &"invalid_event_sequence_id", "A non-positive sequence id must reject with the stable code.")
	assert_equal(profile.to_dictionary(), profile_before, "A sequence-id reject must leave the profile byte-identical.")


func _null_profile_is_rejected() -> void:
	# A null profile rejects with invalid_context (ZERO mutation — there is nothing to mutate).
	var spend_result: ActionResult = SpendOathShardsCommand.new(null, "necromancer", 1).execute(null)
	assert_true(spend_result.is_error(), "A null profile must be rejected.")
	assert_equal(spend_result.error_code, &"invalid_context", "A null profile must reject with invalid_context.")
	assert_false(spend_result.has_events(), "A null-profile reject must emit NO event.")


func _reject_leaves_profile_byte_identical() -> void:
	# The 4.3 no-mutation-on-reject guarantee across every reject path: the profile is byte-identical.
	# (Insufficient shards path — a distinct reject class from the already-applied one above.)
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 0
	var profile_before: Dictionary = profile.to_dictionary()

	var spend_result: ActionResult = SpendOathShardsCommand.new(profile, "shadeblade", 1).execute(null)
	assert_true(spend_result.is_error(), "A 0-shard profile cannot afford any spend.")
	assert_equal(profile.to_dictionary(), profile_before, "A reject must leave the ProfileSnapshot byte-identical.")


func _spend_touches_none_of_the_four_run_end_markers() -> void:
	# AC3 (caller-ordering safety): a spend reads/writes NONE of the four run-end idempotency markers — award
	# last_awarded_run_seed; merge unlock_progress["_last_merged_run_seed"]; first_death_recorded; first_victory_recorded.
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 10
	profile.last_awarded_run_seed = "4242"
	profile.first_death_recorded = true
	profile.first_victory_recorded = true
	profile.unlock_progress["_last_merged_run_seed"] = "4242"

	var spend_result: ActionResult = SpendOathShardsCommand.new(profile, "necromancer", 1).execute(null)
	assert_true(spend_result.succeeded, "The spend should succeed (the markers do not block it).")

	# The four markers are UNTOUCHED by the spend.
	assert_equal(profile.last_awarded_run_seed, "4242", "The award marker must be untouched by a spend.")
	assert_true(profile.first_death_recorded, "The first-death latch must be untouched by a spend.")
	assert_true(profile.first_victory_recorded, "The first-victory latch must be untouched by a spend.")
	assert_equal(String(profile.unlock_progress.get("_last_merged_run_seed", "")), "4242", "The merge marker must be untouched by a spend.")


func _spend_cannot_fabricate_shards_fr28() -> void:
	# FR28 (structural): a spend can only DECREASE oath_shards — it can NEVER increase them (a spend cannot fabricate or
	# award shards; the exclusion of manual-seed progress happened at AWARD time). Every valid spend lowers the total.
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 5
	var before: int = profile.oath_shards

	var spend_result: ActionResult = SpendOathShardsCommand.new(profile, "necromancer", 1).execute(null)
	assert_true(spend_result.succeeded, "The spend should succeed.")
	assert_true(profile.oath_shards < before, "A spend must strictly DECREASE the Oath-Shard total (it can never fabricate shards — FR28).")
	assert_equal(profile.oath_shards, before - 3, "A spend decreases the total by exactly the cost.")


func _a_second_distinct_class_unlock_is_a_separate_spend() -> void:
	# A spend is a PLAYER-INITIATED REPEATABLE action: buying a DIFFERENT class unlock after one already applied is a
	# SEPARATE legitimate spend (the idempotency is per-unlock-flag, not a global lock).
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 10

	var first: ActionResult = SpendOathShardsCommand.new(profile, "necromancer", 1).execute(null)
	assert_true(first.succeeded, "The first (necromancer) spend should succeed.")
	assert_equal(profile.oath_shards, 7, "After necromancer (3): 10 - 3 == 7.")

	var second: ActionResult = SpendOathShardsCommand.new(profile, "shadeblade", 2).execute(null)
	assert_true(second.succeeded, "A DIFFERENT class unlock (shadeblade) should be a separate legitimate spend.")
	assert_equal(profile.oath_shards, 2, "After shadeblade (5): 7 - 5 == 2.")
	assert_true(bool(profile.unlock_progress.get("necromancer_unlocked", false)), "necromancer stays unlocked.")
	assert_true(bool(profile.unlock_progress.get("shadeblade_unlocked", false)), "shadeblade is now unlocked.")
	assert_equal(MetaSpendRules.oath_shards_spent_in(profile.unlock_progress), 8, "The ledger accumulates both spends (3 + 5 == 8).")


func _cleanup() -> void:
	for path: String in [TEST_PROFILE_PATH, "%s.tmp" % TEST_PROFILE_PATH, "%s.bak" % TEST_PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
