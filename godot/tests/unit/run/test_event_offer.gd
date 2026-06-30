extends "res://tests/unit/test_case.gd"

# Story 7.3 Task 3 — EventOffer (the serializable PENDING event-offer value object recorded on RunState). Pins the
# exact-key to_dictionary() contract (a key never silently appears/vanishes), the lenient try_from_dictionary (a
# partial/legacy dict defaults cleanly — no reject path), the deep copy() (the offered-choice-ids list is not shared by
# reference), the pending/resolved status allowlist (anything else defaults to pending), the has_offered_choice()
# membership check, and the int64-safe state_after decimal-string round-trip. Mirrors test_reward_offer.gd.

const EventOffer = preload("res://scripts/run/event_offer.gd")

func run() -> Dictionary:
	_to_dictionary_pins_the_exact_key_set()
	_round_trips_through_real_json()
	_lenient_decode_defaults_a_partial_dict()
	_status_allowlist_defaults_to_pending()
	_copy_is_a_distinct_deep_instance()
	_has_offered_choice_matches_offered_ids_only()
	_state_after_survives_full_int64_round_trip()
	return result()


func _sample_offer() -> EventOffer:
	return EventOffer.new(
		&"smugglers_cache",
		EventOffer.STATUS_PENDING,
		["take_the_gold", "leave_the_cache"],
		&"",
		"events",
		1,
		1,
		123456789
	)


func _to_dictionary_pins_the_exact_key_set() -> void:
	var data: Dictionary = _sample_offer().to_dictionary()
	var keys: Array = data.keys()
	assert_equal(keys.size(), EventOffer.DICTIONARY_KEYS.size(), "to_dictionary() must expose exactly the pinned key count.")
	for key: String in EventOffer.DICTIONARY_KEYS:
		assert_true(data.has(key), "to_dictionary() must carry the pinned key '%s'." % key)
	assert_equal(data.get("event_id"), "smugglers_cache", "to_dictionary() carries the event id.")
	assert_equal(data.get("status"), "pending", "to_dictionary() carries the status.")
	assert_equal((data.get("offered_choice_ids") as Array).size(), 2, "to_dictionary() carries the offered choice ids.")
	assert_equal(data.get("stream_name"), "events", "to_dictionary() carries the events stream name.")
	assert_equal(data.get("state_after"), "123456789", "state_after is decimal-string encoded (int64-safe).")


func _round_trips_through_real_json() -> void:
	var offer: EventOffer = _sample_offer()
	var round_trip: Variant = JSON.parse_string(JSON.stringify(offer.to_dictionary()))
	assert_true(round_trip is Dictionary, "The offer dict must survive a JSON round-trip.")
	var restored: EventOffer = EventOffer.try_from_dictionary(round_trip)
	assert_equal(restored.event_id, &"smugglers_cache", "The event id must survive JSON.")
	assert_equal(restored.status, EventOffer.STATUS_PENDING, "The status must survive JSON.")
	assert_equal(restored.offered_choice_ids.size(), 2, "The offered choice ids must survive JSON.")
	assert_equal(String(restored.offered_choice_ids[0]), "take_the_gold", "Offered choice id 0 must survive JSON.")
	assert_equal(restored.roll, 1, "The roll must survive JSON.")
	assert_equal(restored.draw_index, 1, "The draw index must survive JSON.")
	assert_equal(restored.state_after, 123456789, "state_after must survive JSON (decoded back to int).")
	# A round-tripped offer re-serializes byte-identically.
	assert_equal(JSON.stringify(restored.to_dictionary()), JSON.stringify(offer.to_dictionary()), "A round-tripped offer must re-serialize byte-identically.")


func _lenient_decode_defaults_a_partial_dict() -> void:
	var partial: EventOffer = EventOffer.try_from_dictionary({"event_id": "corrupting_reforge"})
	assert_equal(partial.event_id, &"corrupting_reforge", "A partial dict keeps the event id.")
	assert_equal(partial.status, EventOffer.STATUS_PENDING, "A partial dict defaults status to pending.")
	assert_equal(partial.offered_choice_ids.size(), 0, "A partial dict defaults to no offered choice ids.")
	assert_equal(String(partial.selected_choice_id), "", "A partial dict defaults to an empty selected choice id.")
	# An entirely empty dict still parses.
	var empty: EventOffer = EventOffer.try_from_dictionary({})
	assert_equal(empty.event_id, &"", "An empty dict defaults to an empty event id.")
	assert_true(empty.is_pending(), "An empty dict defaults to pending.")
	# A malformed offered-choice-ids list (non-string entries) drops the bad entries.
	var malformed: EventOffer = EventOffer.try_from_dictionary({
		"event_id": "e", "offered_choice_ids": [42, "take_the_gold", ""]
	})
	assert_equal(malformed.offered_choice_ids.size(), 1, "A malformed offered choice id is dropped (only the valid string survives).")


func _status_allowlist_defaults_to_pending() -> void:
	var bad_status: EventOffer = EventOffer.new(&"e", &"garbage", ["take_the_gold"])
	assert_equal(bad_status.status, EventOffer.STATUS_PENDING, "An off-allowlist status defaults to pending.")
	var resolved: EventOffer = EventOffer.new(&"e", EventOffer.STATUS_RESOLVED, ["take_the_gold"])
	assert_true(resolved.is_resolved(), "A resolved status is accepted.")
	assert_false(resolved.is_pending(), "A resolved offer is not pending.")


func _copy_is_a_distinct_deep_instance() -> void:
	var offer: EventOffer = _sample_offer()
	var copied: EventOffer = offer.copy()
	assert_true(copied != offer, "copy() must produce a distinct instance.")
	assert_equal(JSON.stringify(copied.to_dictionary()), JSON.stringify(offer.to_dictionary()), "copy() must preserve the offer byte-for-byte.")
	# Mutating the copy's offered-choice-ids list must NOT perturb the source (deep copy).
	copied.offered_choice_ids.append("a_new_choice")
	assert_equal(offer.offered_choice_ids.size(), 2, "Mutating the copy's choice ids must not perturb the source.")


func _has_offered_choice_matches_offered_ids_only() -> void:
	var offer: EventOffer = _sample_offer()
	assert_true(offer.has_offered_choice(&"take_the_gold"), "An offered choice id must match.")
	assert_true(offer.has_offered_choice(&"leave_the_cache"), "The second offered choice id must match.")
	assert_false(offer.has_offered_choice(&"does_not_exist"), "A non-offered choice id must not match.")
	assert_false(offer.has_offered_choice(&""), "An empty choice id must not match.")


func _state_after_survives_full_int64_round_trip() -> void:
	var offer: EventOffer = EventOffer.new(&"e", EventOffer.STATUS_PENDING, ["take_the_gold"], &"", "events", 0, 0, 9223372036854775000)
	var round_trip: Variant = JSON.parse_string(JSON.stringify(offer.to_dictionary()))
	var restored: EventOffer = EventOffer.try_from_dictionary(round_trip)
	assert_equal(restored.state_after, 9223372036854775000, "Full int64 state_after must not lose precision through JSON (decimal-string encoded).")
