extends "res://tests/unit/test_case.gd"

# Story 6.3 Task 2.2 — RewardOffer (the serializable PENDING reward-offer value object recorded on RunState). Pins
# the exact-key to_dictionary() contract (a key never silently appears/vanishes), the lenient try_from_dictionary
# (a partial/legacy dict defaults cleanly — no reject path), the deep copy() (the offered-entries list + selected
# dict are not shared by reference), the pending/resolved status allowlist (anything else defaults to pending),
# the has_offered_entry() membership check, and the int64-safe state_after decimal-string round-trip.
#
# Mirrors test_inventory_state.gd (the exact-key value-object discipline).

const RewardOffer = preload("res://scripts/run/reward_offer.gd")

func run() -> Dictionary:
	_to_dictionary_pins_the_exact_key_set()
	_round_trips_through_real_json()
	_lenient_decode_defaults_a_partial_dict()
	_status_allowlist_defaults_to_pending()
	_copy_is_a_distinct_deep_instance()
	_has_offered_entry_matches_offered_pairs_only()
	_state_after_survives_full_int64_round_trip()
	return result()


func _sample_offer() -> RewardOffer:
	return RewardOffer.new(
		&"standard_combat_reward",
		RewardOffer.STATUS_PENDING,
		[
			{"category": "weapon", "content_id": "sword"},
			{"category": "gold", "content_id": "small_gold_purse"}
		],
		{},
		"rewards",
		3,
		0,
		123456789,
		# Story 7.1: the rolled concrete gold amount (a small bounded int).
		11
	)


func _to_dictionary_pins_the_exact_key_set() -> void:
	var data: Dictionary = _sample_offer().to_dictionary()
	# Exactly the pinned key set (no surprise keys, none missing).
	var keys: Array = data.keys()
	assert_equal(keys.size(), RewardOffer.DICTIONARY_KEYS.size(), "to_dictionary() must expose exactly the pinned key count.")
	for key: String in RewardOffer.DICTIONARY_KEYS:
		assert_true(data.has(key), "to_dictionary() must carry the pinned key '%s'." % key)
	assert_equal(data.get("table_id"), "standard_combat_reward", "to_dictionary() carries the table id.")
	assert_equal(data.get("status"), "pending", "to_dictionary() carries the status.")
	assert_equal((data.get("offered_entries") as Array).size(), 2, "to_dictionary() carries the offered entries.")
	assert_equal(data.get("state_after"), "123456789", "state_after is decimal-string encoded (int64-safe).")


func _round_trips_through_real_json() -> void:
	var offer: RewardOffer = _sample_offer()
	var round_trip: Variant = JSON.parse_string(JSON.stringify(offer.to_dictionary()))
	assert_true(round_trip is Dictionary, "The offer dict must survive a JSON round-trip.")
	var restored: RewardOffer = RewardOffer.try_from_dictionary(round_trip)
	assert_equal(restored.table_id, &"standard_combat_reward", "The table id must survive JSON.")
	assert_equal(restored.status, RewardOffer.STATUS_PENDING, "The status must survive JSON.")
	assert_equal(restored.offered_entries.size(), 2, "The offered entries must survive JSON.")
	assert_equal(String((restored.offered_entries[0] as Dictionary).get("content_id")), "sword", "Offered entry 0 must survive JSON.")
	assert_equal(restored.roll, 3, "The roll must survive JSON.")
	assert_equal(restored.draw_index, 0, "The draw index must survive JSON.")
	assert_equal(restored.state_after, 123456789, "state_after must survive JSON (decoded back to int).")
	# Story 7.1: the rolled gold amount survives JSON (a small bounded int, stays numeric).
	assert_equal(restored.gold_amount, 11, "Story 7.1: the rolled gold_amount must survive JSON (small bounded int, numeric).")
	# A pre-7.1 offer dict (no gold_amount key) decodes gold_amount to 0 (lenient).
	var legacy_dict: Dictionary = offer.to_dictionary()
	legacy_dict.erase("gold_amount")
	assert_equal(RewardOffer.try_from_dictionary(legacy_dict).gold_amount, 0, "A pre-7.1 offer dict (no gold_amount) decodes to 0.")
	# A round-tripped offer re-serializes byte-identically.
	assert_equal(JSON.stringify(restored.to_dictionary()), JSON.stringify(offer.to_dictionary()), "A round-tripped offer must re-serialize byte-identically.")


func _lenient_decode_defaults_a_partial_dict() -> void:
	# A partial dict (only a table id) parses cleanly with defaults — a value object has no reject path.
	var partial: RewardOffer = RewardOffer.try_from_dictionary({"table_id": "elite_combat_reward"})
	assert_equal(partial.table_id, &"elite_combat_reward", "A partial dict keeps the table id.")
	assert_equal(partial.status, RewardOffer.STATUS_PENDING, "A partial dict defaults status to pending.")
	assert_equal(partial.offered_entries.size(), 0, "A partial dict defaults to no offered entries.")
	assert_equal(partial.selected_entry.size(), 0, "A partial dict defaults to an empty selected entry.")
	# An entirely empty dict still parses.
	var empty: RewardOffer = RewardOffer.try_from_dictionary({})
	assert_equal(empty.table_id, &"", "An empty dict defaults to an empty table id.")
	assert_true(empty.is_pending(), "An empty dict defaults to pending.")
	# A malformed offered-entries list (non-dict entries) drops the bad entries.
	var malformed: RewardOffer = RewardOffer.try_from_dictionary({
		"table_id": "t", "offered_entries": ["not_a_dict", {"category": "weapon", "content_id": "sword"}]
	})
	assert_equal(malformed.offered_entries.size(), 1, "A malformed offered entry is dropped (only the valid dict survives).")


func _status_allowlist_defaults_to_pending() -> void:
	var bad_status: RewardOffer = RewardOffer.new(&"t", &"garbage", [{"category": "weapon", "content_id": "sword"}])
	assert_equal(bad_status.status, RewardOffer.STATUS_PENDING, "An off-allowlist status defaults to pending.")
	var resolved: RewardOffer = RewardOffer.new(&"t", RewardOffer.STATUS_RESOLVED, [{"category": "weapon", "content_id": "sword"}])
	assert_true(resolved.is_resolved(), "A resolved status is accepted.")
	assert_false(resolved.is_pending(), "A resolved offer is not pending.")


func _copy_is_a_distinct_deep_instance() -> void:
	var offer: RewardOffer = _sample_offer()
	var copied: RewardOffer = offer.copy()
	assert_true(copied != offer, "copy() must produce a distinct instance.")
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(offer.to_dictionary()), "copy() must preserve the offer byte-for-byte.")
	# Mutating the copy's offered-entries list must NOT perturb the source (deep copy).
	copied.offered_entries.append({"category": "armor", "content_id": "padded_vest"})
	assert_equal(offer.offered_entries.size(), 2, "Mutating the copy's entries must not perturb the source.")
	# Mutating a copied entry dict must not perturb the source entry.
	var source_offer: RewardOffer = _sample_offer()
	var deep: RewardOffer = source_offer.copy()
	(deep.offered_entries[0] as Dictionary)["content_id"] = "mutated"
	assert_equal(String((source_offer.offered_entries[0] as Dictionary).get("content_id")), "sword", "Mutating a copied entry must not perturb the source entry (deep copy).")


func _has_offered_entry_matches_offered_pairs_only() -> void:
	var offer: RewardOffer = _sample_offer()
	assert_true(offer.has_offered_entry(&"weapon", &"sword"), "An offered pair must match.")
	assert_true(offer.has_offered_entry(&"gold", &"small_gold_purse"), "The second offered pair must match.")
	assert_false(offer.has_offered_entry(&"weapon", &"crossbow"), "A non-offered content id must not match.")
	assert_false(offer.has_offered_entry(&"armor", &"sword"), "A right-id wrong-category pair must not match.")
	assert_false(offer.has_offered_entry(&"passive", &"warrior_unbreakable_guard"), "An entry from a different offer must not match.")


func _state_after_survives_full_int64_round_trip() -> void:
	var offer: RewardOffer = RewardOffer.new(&"t", RewardOffer.STATUS_PENDING, [{"category": "weapon", "content_id": "sword"}], {}, "rewards", 0, 0, 9223372036854775000)
	var round_trip: Variant = JSON.parse_string(JSON.stringify(offer.to_dictionary()))
	var restored: RewardOffer = RewardOffer.try_from_dictionary(round_trip)
	assert_equal(restored.state_after, 9223372036854775000, "Full int64 state_after must not lose precision through JSON (decimal-string encoded).")
