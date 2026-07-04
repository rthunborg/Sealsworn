extends "res://tests/unit/test_case.gd"

# Story 8.3 Task 1 (AC1, AC2): the versioned cross-run ProfileSnapshot — the FIRST persistent cross-run state. Mirrors
# test_run_snapshot.gd: an exact pinned key set, a JSON round-trip, an unsupported-schema reject (the migration path),
# lenient partial-dict decode, and the 8.4/8.5 homes present + empty/0 in v0.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")

func run() -> Dictionary:
	_supported_schema_parses()
	_unsupported_schema_is_rejected()
	_dictionary_key_set_is_exact_and_pinned()
	_json_round_trip_preserves_every_field()
	_partial_legacy_dict_parses_leniently()
	_future_content_homes_are_present_and_empty_in_v0()
	_fresh_profile_is_a_brand_new_player()
	_to_dictionary_returns_a_fresh_deep_copy()
	_oath_shards_defaults_a_negative_to_zero()
	_last_awarded_run_seed_survives_full_int64_round_trip()
	_copy_is_a_deep_independent_clone()
	_populated_8_4_homes_round_trip_without_a_migration()
	_set_first_death_flag_round_trips_without_a_migration()
	_set_first_victory_flag_round_trips_without_a_migration()
	return result()


func _supported_schema_parses() -> void:
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.oath_shards = 7

	var result_value: ActionResult = ProfileSnapshot.parse(snapshot.to_dictionary())

	assert_true(result_value.succeeded, "ProfileSnapshot should parse the current schema.")
	assert_equal(result_value.metadata.get("snapshot").oath_shards, 7, "ProfileSnapshot should preserve the oath_shards total.")


func _unsupported_schema_is_rejected() -> void:
	var result_value: ActionResult = ProfileSnapshot.parse({
		"schema_version": ProfileSnapshot.SCHEMA_VERSION + 1,
		"content_version": "future"
	})

	assert_true(result_value.is_error(), "ProfileSnapshot should reject an unsupported schema (the migration path).")
	assert_equal(result_value.error_code, &"unsupported_profile_schema", "ProfileSnapshot should explain an unsupported schema.")
	assert_equal(result_value.metadata.get("expected_schema_version"), ProfileSnapshot.SCHEMA_VERSION, "The reject metadata should carry the expected schema version.")
	assert_equal(result_value.metadata.get("actual_schema_version"), ProfileSnapshot.SCHEMA_VERSION + 1, "The reject metadata should carry the actual schema version.")


func _dictionary_key_set_is_exact_and_pinned() -> void:
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	var data: Dictionary = snapshot.to_dictionary()

	var actual_keys: Array = data.keys()
	actual_keys.sort()
	var expected_keys: Array = ProfileSnapshot.DICTIONARY_KEYS.duplicate()
	expected_keys.sort()

	assert_equal(actual_keys, expected_keys, "ProfileSnapshot.to_dictionary() must project EXACTLY the pinned DICTIONARY_KEYS set.")
	assert_equal(data.size(), ProfileSnapshot.DICTIONARY_KEYS.size(), "ProfileSnapshot.to_dictionary() must have no surprise keys.")


func _json_round_trip_preserves_every_field() -> void:
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.content_version = "mvp-1"
	snapshot.profile_id = "player-alpha"
	snapshot.oath_shards = 42
	snapshot.last_awarded_run_seed = "123456789"
	# The 8.4 content homes are OPAQUE dicts (8.3 does not author their shape). Use string values so the JSON round-trip
	# is exact — JSON has no int/float distinction, so an integer dict VALUE decodes as a float (3 -> 3.0). The opaque
	# homes carry whatever 8.4 puts there; here we prove the structure + string values round-trip verbatim.
	snapshot.class_mastery = {"seer": "novice"}
	snapshot.echoes = ["echo_of_salt", "echo_of_tide"]
	snapshot.unlock_progress = {"variety_pool": "tier_1"}
	snapshot.first_death_recorded = true
	snapshot.first_victory_recorded = true

	var json_text: String = JSON.stringify(snapshot.to_dictionary())
	var parsed_variant: Variant = JSON.parse_string(json_text)
	assert_true(parsed_variant is Dictionary, "The profile snapshot should JSON-stringify to a dictionary.")

	var result_value: ActionResult = ProfileSnapshot.parse(parsed_variant)
	assert_true(result_value.succeeded, "The profile snapshot should parse back from JSON.")
	var parsed: ProfileSnapshot = result_value.metadata.get("snapshot")

	assert_equal(parsed.content_version, "mvp-1", "Round-trip must preserve content_version.")
	assert_equal(parsed.profile_id, "player-alpha", "Round-trip must preserve profile_id.")
	assert_equal(parsed.oath_shards, 42, "Round-trip must preserve the oath_shards total.")
	assert_equal(parsed.last_awarded_run_seed, "123456789", "Round-trip must preserve the idempotency marker.")
	assert_equal(parsed.class_mastery, {"seer": "novice"}, "Round-trip must preserve class_mastery.")
	assert_equal(parsed.echoes, ["echo_of_salt", "echo_of_tide"], "Round-trip must preserve echoes.")
	assert_equal(parsed.unlock_progress, {"variety_pool": "tier_1"}, "Round-trip must preserve unlock_progress.")
	assert_true(parsed.first_death_recorded, "Round-trip must preserve first_death_recorded.")
	assert_true(parsed.first_victory_recorded, "Round-trip must preserve first_victory_recorded (Story 9.4).")


func _partial_legacy_dict_parses_leniently() -> void:
	# A partial dict (only the schema version + a subset of fields) must parse cleanly with defaults for the rest.
	var result_value: ActionResult = ProfileSnapshot.parse({
		"schema_version": ProfileSnapshot.SCHEMA_VERSION,
		"oath_shards": 5
	})

	assert_true(result_value.succeeded, "A partial profile dict should parse leniently.")
	var parsed: ProfileSnapshot = result_value.metadata.get("snapshot")
	assert_equal(parsed.oath_shards, 5, "A partial dict should preserve a present field.")
	assert_equal(parsed.profile_id, "default", "A missing profile_id should default to 'default'.")
	assert_equal(parsed.content_version, "mvp-0", "A missing content_version should default to 'mvp-0'.")
	assert_equal(parsed.last_awarded_run_seed, "", "A missing idempotency marker should default to '' (never awarded).")
	assert_equal(parsed.class_mastery, {}, "A missing class_mastery should default to empty.")
	assert_equal(parsed.echoes, [], "A missing echoes should default to empty.")
	assert_equal(parsed.unlock_progress, {}, "A missing unlock_progress should default to empty.")
	assert_false(parsed.first_death_recorded, "A missing first_death_recorded should default to false.")


func _future_content_homes_are_present_and_empty_in_v0() -> void:
	# The 8.4/8.5 homes exist in a fresh v0 profile so 8.4/8.5 merge without a migration, and are all empty/0/false.
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	var data: Dictionary = snapshot.to_dictionary()

	assert_true(data.has("class_mastery"), "The 8.4 class_mastery home must exist in v0.")
	assert_true(data.has("echoes"), "The 8.4 echoes home must exist in v0.")
	assert_true(data.has("unlock_progress"), "The 8.4 unlock_progress home must exist in v0.")
	assert_true(data.has("first_death_recorded"), "The 8.5 first_death_recorded home must exist in v0.")
	assert_true(data.has("first_victory_recorded"), "The 9.4 first_victory_recorded home must exist in v0.")
	assert_equal(data.get("class_mastery"), {}, "class_mastery must be empty in v0 (8.4 fills it).")
	assert_equal(data.get("echoes"), [], "echoes must be empty in v0 (8.4 fills it).")
	assert_equal(data.get("unlock_progress"), {}, "unlock_progress must be empty in v0 (8.4 fills it).")
	assert_equal(data.get("first_death_recorded"), false, "first_death_recorded must be false in v0 (8.5 sets it).")
	assert_equal(data.get("first_victory_recorded"), false, "first_victory_recorded must be false in v0 (9.4 sets it).")
	assert_equal(data.get("oath_shards"), 0, "A fresh profile has 0 Oath Shards.")


func _fresh_profile_is_a_brand_new_player() -> void:
	var snapshot: ProfileSnapshot = ProfileSnapshot.fresh()
	assert_equal(snapshot.oath_shards, 0, "A fresh profile has 0 Oath Shards.")
	assert_equal(snapshot.last_awarded_run_seed, "", "A fresh profile has never awarded.")
	assert_equal(snapshot.profile_id, "default", "A fresh profile defaults to the 'default' profile id.")

	var custom: ProfileSnapshot = ProfileSnapshot.fresh("player-beta")
	assert_equal(custom.profile_id, "player-beta", "A fresh profile should honor an explicit profile id.")


func _to_dictionary_returns_a_fresh_deep_copy() -> void:
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.class_mastery = {"seer": 1}
	snapshot.echoes = ["echo_of_salt"]

	var data: Dictionary = snapshot.to_dictionary()
	# Mutating the returned dict must NOT perturb the snapshot (the deep-copy discipline).
	data["class_mastery"]["seer"] = 999
	data["echoes"].append("injected")
	data["oath_shards"] = 999

	assert_equal(snapshot.class_mastery.get("seer"), 1, "Mutating the returned dict must not perturb class_mastery.")
	assert_equal(snapshot.echoes.size(), 1, "Mutating the returned dict must not perturb echoes.")
	assert_equal(snapshot.oath_shards, 0, "Mutating the returned dict must not perturb oath_shards.")


func _oath_shards_defaults_a_negative_to_zero() -> void:
	# A never-negative count: a negative / non-int value clamps to 0 (leniency + floor).
	var negative_result: ActionResult = ProfileSnapshot.parse({
		"schema_version": ProfileSnapshot.SCHEMA_VERSION,
		"oath_shards": -10
	})
	assert_true(negative_result.succeeded, "A negative oath_shards should still parse leniently.")
	assert_equal(negative_result.metadata.get("snapshot").oath_shards, 0, "A negative oath_shards must clamp to 0.")

	var garbage_result: ActionResult = ProfileSnapshot.parse({
		"schema_version": ProfileSnapshot.SCHEMA_VERSION,
		"oath_shards": "not-a-number"
	})
	assert_true(garbage_result.succeeded, "A non-numeric oath_shards should still parse leniently.")
	assert_equal(garbage_result.metadata.get("snapshot").oath_shards, 0, "A non-numeric oath_shards must default to 0.")


func _last_awarded_run_seed_survives_full_int64_round_trip() -> void:
	# The run identity is a full int64 (root_seed). It must round-trip losslessly through decimal-string encoding + JSON.
	var big_seed_text: String = "9223372036854775000"
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.last_awarded_run_seed = big_seed_text

	var json_text: String = JSON.stringify(snapshot.to_dictionary())
	var parsed_variant: Variant = JSON.parse_string(json_text)
	var result_value: ActionResult = ProfileSnapshot.parse(parsed_variant)

	assert_true(result_value.succeeded, "The big-seed profile should parse back from JSON.")
	assert_equal(result_value.metadata.get("snapshot").last_awarded_run_seed, big_seed_text, "The int64 run-identity marker must survive a JSON round-trip (no double truncation).")


func _copy_is_a_deep_independent_clone() -> void:
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.oath_shards = 9
	snapshot.class_mastery = {"seer": 2}
	snapshot.echoes = ["echo_of_tide"]

	var clone: ProfileSnapshot = snapshot.copy()
	clone.oath_shards = 100
	clone.class_mastery["seer"] = 50
	clone.echoes.append("mutated")

	assert_equal(snapshot.oath_shards, 9, "Mutating the copy must not perturb the source oath_shards.")
	assert_equal(snapshot.class_mastery.get("seer"), 2, "Mutating the copy must not perturb the source class_mastery.")
	assert_equal(snapshot.echoes.size(), 1, "Mutating the copy must not perturb the source echoes.")


func _populated_8_4_homes_round_trip_without_a_migration() -> void:
	# Story 8.4: the POPULATED echoes / class_mastery / unlock_progress homes round-trip losslessly through
	# to_dictionary()/parse at the SAME SCHEMA_VERSION == 1 (NO migration — 8.4 merges into the existing shape), and the
	# exact DICTIONARY_KEYS set is UNCHANGED (8.4 adds NO new top-level profile key — Seal Fragments + the merge marker
	# live INSIDE unlock_progress).
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.echoes = ["echo_of_salt", "echo_of_tide"]
	snapshot.class_mastery = {"warrior": 3}
	# unlock_progress carries the Seal-Fragment id set + an unlock-state flag + the dedicated merge marker (all INSIDE the
	# existing unlock_progress Dictionary home — no new top-level key).
	snapshot.unlock_progress = {
		"seal_fragments": ["seal_a", "seal_b"],
		"seal_gate_1_unlocked": true,
		"_last_merged_run_seed": "4242"
	}

	var json_text: String = JSON.stringify(snapshot.to_dictionary())
	var parsed_variant: Variant = JSON.parse_string(json_text)
	var parse_result: ActionResult = ProfileSnapshot.parse(parsed_variant)
	assert_true(parse_result.succeeded, "A populated 8.4 profile must parse back at SCHEMA_VERSION == 1 (no migration).")
	var parsed: ProfileSnapshot = parse_result.metadata.get("snapshot")

	# NO migration: the schema version is unchanged.
	assert_equal(parsed.schema_version, ProfileSnapshot.SCHEMA_VERSION, "The populated 8.4 profile must round-trip at the SAME schema version (no bump).")
	# The populated homes survive verbatim.
	assert_equal(parsed.echoes, ["echo_of_salt", "echo_of_tide"], "The populated echoes home must round-trip losslessly.")
	assert_equal(int(parsed.class_mastery.get("warrior")), 3, "The populated class_mastery home must round-trip losslessly.")
	assert_equal((parsed.unlock_progress.get("seal_fragments") as Array), ["seal_a", "seal_b"], "The Seal-Fragment set inside unlock_progress must round-trip losslessly.")
	assert_true(bool(parsed.unlock_progress.get("seal_gate_1_unlocked")), "The unlock-state flag inside unlock_progress must round-trip.")
	assert_equal(String(parsed.unlock_progress.get("_last_merged_run_seed")), "4242", "The dedicated merge marker inside unlock_progress must round-trip.")

	# The exact top-level key set is UNCHANGED (8.4 adds no new top-level profile key).
	var actual_keys: Array = snapshot.to_dictionary().keys()
	actual_keys.sort()
	var expected_keys: Array = ProfileSnapshot.DICTIONARY_KEYS.duplicate()
	expected_keys.sort()
	assert_equal(actual_keys, expected_keys, "A populated 8.4 profile must still project EXACTLY the pinned DICTIONARY_KEYS set (no new top-level key).")


func _set_first_death_flag_round_trips_without_a_migration() -> void:
	# Story 8.5 (Task 4.2): the SET first_death_recorded == true round-trips losslessly through to_dictionary()/parse AND a
	# JSON stringify->parse at the SAME SCHEMA_VERSION == 1 (NO migration — 8.5 SETS the EXISTING reserved home, exactly the
	# 8.4 merge-without-migration precedent), the exact DICTIONARY_KEYS set is UNCHANGED (no new top-level profile key), and a
	# lenient parse still defaults a legacy/missing first-death field to false (a pre-8.5 profile parses cleanly with false).
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.first_death_recorded = true

	var json_text: String = JSON.stringify(snapshot.to_dictionary())
	var parsed_variant: Variant = JSON.parse_string(json_text)
	var parse_result: ActionResult = ProfileSnapshot.parse(parsed_variant)
	assert_true(parse_result.succeeded, "A profile with the SET first-death flag must parse back at SCHEMA_VERSION == 1 (no migration).")
	var parsed: ProfileSnapshot = parse_result.metadata.get("snapshot")

	# NO migration: the schema version is unchanged, and the SET flag survives.
	assert_equal(parsed.schema_version, ProfileSnapshot.SCHEMA_VERSION, "The SET first-death flag must round-trip at the SAME schema version (no bump).")
	assert_true(parsed.first_death_recorded, "The SET first_death_recorded == true must round-trip losslessly.")

	# The exact top-level key set is UNCHANGED (8.5 adds no new top-level profile key — it SETS the existing home).
	var actual_keys: Array = snapshot.to_dictionary().keys()
	actual_keys.sort()
	var expected_keys: Array = ProfileSnapshot.DICTIONARY_KEYS.duplicate()
	expected_keys.sort()
	assert_equal(actual_keys, expected_keys, "A profile with the SET first-death flag must still project EXACTLY the pinned DICTIONARY_KEYS set (no new top-level key).")

	# A legacy profile with NO first-death key parses cleanly to false (a pre-8.5 profile).
	var legacy_result: ActionResult = ProfileSnapshot.parse({
		"schema_version": ProfileSnapshot.SCHEMA_VERSION,
		"oath_shards": 2
	})
	assert_true(legacy_result.succeeded, "A pre-8.5 (no first-death key) profile must parse leniently.")
	assert_false(legacy_result.metadata.get("snapshot").first_death_recorded, "A missing/legacy first_death_recorded must default to false.")


func _set_first_victory_flag_round_trips_without_a_migration() -> void:
	# Story 9.4 (Task 8 — the SCHEMA [Decision]): the SET first_victory_recorded == true round-trips losslessly through
	# to_dictionary()/parse AND a JSON stringify->parse at the SAME SCHEMA_VERSION == 1 (NO migration — 9.4 adds the field as
	# a NEW ADDITIVE field at v1, the 8.4/8.5 merge-without-bump discipline; NO home was pre-reserved for it, but a lenient
	# additive add still needs no bump). The exact DICTIONARY_KEYS set now INCLUDES first_victory_recorded (a new key REQUIRES
	# updating the pin, but this is NOT a schema bump — 8.7's matrix pins SCHEMA_VERSION == 1 + schema_version:2 -> unsupported,
	# both of which stay green). A lenient parse still defaults a legacy/missing first-victory field to false (a pre-9.4
	# profile parses cleanly with false).
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.first_victory_recorded = true

	var json_text: String = JSON.stringify(snapshot.to_dictionary())
	var parsed_variant: Variant = JSON.parse_string(json_text)
	var parse_result: ActionResult = ProfileSnapshot.parse(parsed_variant)
	assert_true(parse_result.succeeded, "A profile with the SET first-victory flag must parse back at SCHEMA_VERSION == 1 (no migration).")
	var parsed: ProfileSnapshot = parse_result.metadata.get("snapshot")

	# NO migration: the schema version is unchanged, and the SET flag survives.
	assert_equal(parsed.schema_version, ProfileSnapshot.SCHEMA_VERSION, "The SET first-victory flag must round-trip at the SAME schema version (no bump).")
	assert_equal(ProfileSnapshot.SCHEMA_VERSION, 1, "SCHEMA_VERSION stays 1 (8.7's migration matrix pins it — a bump would break test 2.5).")
	assert_true(parsed.first_victory_recorded, "The SET first_victory_recorded == true must round-trip losslessly.")

	# The exact top-level key set now INCLUDES first_victory_recorded (the DICTIONARY_KEYS pin is updated — NOT a schema bump).
	var actual_keys: Array = snapshot.to_dictionary().keys()
	actual_keys.sort()
	var expected_keys: Array = ProfileSnapshot.DICTIONARY_KEYS.duplicate()
	expected_keys.sort()
	assert_equal(actual_keys, expected_keys, "A profile with the SET first-victory flag must project EXACTLY the pinned DICTIONARY_KEYS set (incl. the new key).")

	# A legacy profile with NO first-victory key parses cleanly to false (a pre-9.4 profile — the 8.7 migration matrix's
	# schema_version:1 lenient-parse stays green).
	var legacy_result: ActionResult = ProfileSnapshot.parse({
		"schema_version": ProfileSnapshot.SCHEMA_VERSION,
		"oath_shards": 4
	})
	assert_true(legacy_result.succeeded, "A pre-9.4 (no first-victory key) profile must parse leniently.")
	assert_false(legacy_result.metadata.get("snapshot").first_victory_recorded, "A missing/legacy first_victory_recorded must default to false.")
