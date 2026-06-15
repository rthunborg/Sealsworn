extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")

# AC2/AC3: the deliberate difficulty NON-GOAL. No settings preference key may scale enemy stats,
# damage, rewards, run length, or expose a selectable difficulty ladder. This is the executable
# form of "no difficulty ladder is present" — a future contributor cannot add one silently.
const FORBIDDEN_DIFFICULTY_KEYS: Array[String] = [
	"difficulty",
	"difficulty_tier",
	"easy",
	"normal",
	"hard",
	"challenge_level",
	"enemy_scaling",
	"damage_multiplier"
]

func run() -> Dictionary:
	_defaults_are_safe_preferences()
	_to_dictionary_exposes_only_documented_preference_keys()
	_difficulty_non_goal_keys_are_absent()
	_text_scale_clamps_via_tactical_text_scale_bounds()
	_text_scale_malformed_falls_back_to_default()
	_master_volume_db_clamps_to_named_range()
	_master_volume_db_malformed_falls_back_to_default()
	_audio_muted_coerces_to_bool()
	_input_scheme_validates_against_allowlist()
	_parse_rejects_only_schema_mismatch()
	_parse_round_trips_through_json()
	_parse_honors_partial_settings_and_defaults_the_rest()
	return result()


func _defaults_are_safe_preferences() -> void:
	var defaults: SettingsSnapshot = SettingsSnapshot.defaults()
	assert_equal(defaults.schema_version, SettingsSnapshot.SCHEMA_VERSION, "defaults() should carry the current schema version.")
	assert_equal(defaults.content_version, "mvp-0", "defaults() should carry the mvp content version.")
	assert_equal(defaults.text_scale, TacticalTextScale.DEFAULT_TEXT_SCALE, "Default text_scale should be the canonical 1.0 baseline.")
	assert_equal(defaults.master_volume_db, SettingsSnapshot.DEFAULT_VOLUME_DB, "Default master_volume_db should be 0 dB (unity gain).")
	assert_false(defaults.audio_muted, "Audio should not be muted by default.")
	assert_equal(defaults.input_scheme, SettingsSnapshot.DEFAULT_INPUT_SCHEME, "Default input_scheme should be 'auto'.")
	assert_false(defaults.colorblind_safe, "colorblind_safe should default off (presentation hint only).")
	assert_false(defaults.high_contrast, "high_contrast should default off (presentation hint only).")


func _to_dictionary_exposes_only_documented_preference_keys() -> void:
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	var keys: Array = snapshot.to_dictionary().keys()
	var expected: Array[String] = [
		"schema_version",
		"content_version",
		"text_scale",
		"master_volume_db",
		"audio_muted",
		"input_scheme",
		"colorblind_safe",
		"high_contrast"
	]
	assert_equal(keys.size(), expected.size(), "to_dictionary() should expose exactly the documented preference keys, got %s." % str(keys))
	for key: String in expected:
		assert_true(keys.has(key), "to_dictionary() should expose the documented preference key '%s'." % key)
	# PREFERENCE_KEYS is the guardrail surface a regression test asserts against.
	for key: String in SettingsSnapshot.PREFERENCE_KEYS:
		assert_true(keys.has(key), "PREFERENCE_KEYS '%s' should be present in to_dictionary()." % key)


# AC2/AC3 executable guardrail: forbidden difficulty keys must be absent from both the
# declared preference key surface and the serialized dictionary.
func _difficulty_non_goal_keys_are_absent() -> void:
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	var serialized: Dictionary = snapshot.to_dictionary()
	for forbidden: String in FORBIDDEN_DIFFICULTY_KEYS:
		assert_false(serialized.has(forbidden), "SettingsSnapshot.to_dictionary() must NOT expose difficulty key '%s' (non-goal)." % forbidden)
		assert_false(SettingsSnapshot.PREFERENCE_KEYS.has(forbidden), "PREFERENCE_KEYS must NOT declare difficulty key '%s' (non-goal)." % forbidden)
	# Even if a stale/malicious file injects a difficulty key, parse() must drop it.
	var injected: Dictionary = snapshot.to_dictionary()
	injected["difficulty_tier"] = "hard"
	injected["enemy_scaling"] = 2.5
	var parse_result: ActionResult = SettingsSnapshot.parse(injected)
	assert_true(parse_result.succeeded, "parse() should accept a dictionary with extra keys (and drop them).")
	if parse_result.succeeded:
		var reparsed: Dictionary = (parse_result.metadata.get("snapshot") as SettingsSnapshot).to_dictionary()
		for forbidden: String in FORBIDDEN_DIFFICULTY_KEYS:
			assert_false(reparsed.has(forbidden), "parse() must drop injected difficulty key '%s'." % forbidden)


func _text_scale_clamps_via_tactical_text_scale_bounds() -> void:
	var below: SettingsSnapshot = _parsed_with({"text_scale": 0.1})
	assert_equal(below.text_scale, TacticalTextScale.MIN_TEXT_SCALE, "text_scale below min should clamp to MIN_TEXT_SCALE.")
	var above: SettingsSnapshot = _parsed_with({"text_scale": 99.0})
	assert_equal(above.text_scale, TacticalTextScale.MAX_TEXT_SCALE, "text_scale above max should clamp to MAX_TEXT_SCALE.")
	var inside: SettingsSnapshot = _parsed_with({"text_scale": 1.4})
	assert_equal(inside.text_scale, 1.4, "An in-range text_scale should be preserved.")


func _text_scale_malformed_falls_back_to_default() -> void:
	var nan_scale: SettingsSnapshot = _parsed_with({"text_scale": NAN})
	assert_equal(nan_scale.text_scale, TacticalTextScale.DEFAULT_TEXT_SCALE, "NaN text_scale should fall back to default.")
	var inf_scale: SettingsSnapshot = _parsed_with({"text_scale": INF})
	assert_equal(inf_scale.text_scale, TacticalTextScale.DEFAULT_TEXT_SCALE, "inf text_scale should fall back to default.")
	var wrong_type: SettingsSnapshot = _parsed_with({"text_scale": "huge"})
	assert_equal(wrong_type.text_scale, TacticalTextScale.DEFAULT_TEXT_SCALE, "Non-numeric text_scale should fall back to default.")
	var zero_scale: SettingsSnapshot = _parsed_with({"text_scale": 0.0})
	assert_equal(zero_scale.text_scale, TacticalTextScale.DEFAULT_TEXT_SCALE, "Zero text_scale is malformed and should fall back to default.")


func _master_volume_db_clamps_to_named_range() -> void:
	var too_loud: SettingsSnapshot = _parsed_with({"master_volume_db": 24.0})
	assert_equal(too_loud.master_volume_db, SettingsSnapshot.MAX_VOLUME_DB, "Volume above MAX should clamp to MAX_VOLUME_DB.")
	var too_quiet: SettingsSnapshot = _parsed_with({"master_volume_db": -200.0})
	assert_equal(too_quiet.master_volume_db, SettingsSnapshot.MIN_VOLUME_DB, "Volume below MIN should clamp to MIN_VOLUME_DB.")
	var inside: SettingsSnapshot = _parsed_with({"master_volume_db": -12.0})
	assert_equal(inside.master_volume_db, -12.0, "An in-range volume should be preserved.")


func _master_volume_db_malformed_falls_back_to_default() -> void:
	var nan_volume: SettingsSnapshot = _parsed_with({"master_volume_db": NAN})
	assert_equal(nan_volume.master_volume_db, SettingsSnapshot.DEFAULT_VOLUME_DB, "NaN volume should fall back to default.")
	var inf_volume: SettingsSnapshot = _parsed_with({"master_volume_db": -INF})
	assert_equal(inf_volume.master_volume_db, SettingsSnapshot.DEFAULT_VOLUME_DB, "inf volume should fall back to default.")
	var wrong_type: SettingsSnapshot = _parsed_with({"master_volume_db": "loud"})
	assert_equal(wrong_type.master_volume_db, SettingsSnapshot.DEFAULT_VOLUME_DB, "Non-numeric volume should fall back to default.")


func _audio_muted_coerces_to_bool() -> void:
	var truthy: SettingsSnapshot = _parsed_with({"audio_muted": true})
	assert_true(truthy.audio_muted, "audio_muted true should be honored.")
	var falsy: SettingsSnapshot = _parsed_with({"audio_muted": false})
	assert_false(falsy.audio_muted, "audio_muted false should be honored.")
	var missing: SettingsSnapshot = _parsed_with({})
	assert_false(missing.audio_muted, "Missing audio_muted should default false.")


func _input_scheme_validates_against_allowlist() -> void:
	for allowed: String in SettingsSnapshot.INPUT_SCHEMES:
		var ok: SettingsSnapshot = _parsed_with({"input_scheme": allowed})
		assert_equal(ok.input_scheme, allowed, "Allowed input_scheme '%s' should be preserved." % allowed)
	var unknown: SettingsSnapshot = _parsed_with({"input_scheme": "gamepad_xyz"})
	assert_equal(unknown.input_scheme, SettingsSnapshot.DEFAULT_INPUT_SCHEME, "Unknown input_scheme should fall back to default.")
	var wrong_type: SettingsSnapshot = _parsed_with({"input_scheme": 7})
	assert_equal(wrong_type.input_scheme, SettingsSnapshot.DEFAULT_INPUT_SCHEME, "Non-string input_scheme should fall back to default.")


func _parse_rejects_only_schema_mismatch() -> void:
	var mismatch: Dictionary = SettingsSnapshot.defaults().to_dictionary()
	mismatch["schema_version"] = SettingsSnapshot.SCHEMA_VERSION + 5
	var bad: ActionResult = SettingsSnapshot.parse(mismatch)
	assert_true(bad.is_error(), "parse() should reject a mismatched schema version.")
	assert_equal(bad.error_code, &"unsupported_settings_schema", "parse() should return the stable schema error code.")
	assert_true(bad.metadata.has("expected_schema_version"), "Schema error should include the expected version diagnostic.")
	assert_true(bad.metadata.has("actual_schema_version"), "Schema error should include the actual version diagnostic.")


func _parse_round_trips_through_json() -> void:
	var original: SettingsSnapshot = SettingsSnapshot.defaults()
	original.text_scale = 1.25
	original.master_volume_db = -6.5
	original.audio_muted = true
	original.input_scheme = "touch"
	original.colorblind_safe = true
	original.high_contrast = true

	# JSON-round-trip the dictionary (Epic 2 rule: never assert through native dicts alone).
	var encoded: String = JSON.stringify(original.to_dictionary())
	var decoded: Variant = JSON.parse_string(encoded)
	assert_true(decoded is Dictionary, "Encoded settings should parse back to a Dictionary.")

	var parse_result: ActionResult = SettingsSnapshot.parse(decoded)
	assert_true(parse_result.succeeded, "parse() should accept the round-tripped dictionary: %s" % parse_result.metadata)
	if parse_result.succeeded:
		var restored: SettingsSnapshot = parse_result.metadata.get("snapshot")
		assert_equal(restored.text_scale, 1.25, "text_scale should survive a JSON round-trip exactly.")
		assert_equal(restored.master_volume_db, -6.5, "master_volume_db should survive a JSON round-trip exactly.")
		assert_true(restored.audio_muted, "audio_muted should survive the round-trip.")
		assert_equal(restored.input_scheme, "touch", "input_scheme should survive the round-trip.")
		assert_true(restored.colorblind_safe, "colorblind_safe should survive the round-trip.")
		assert_true(restored.high_contrast, "high_contrast should survive the round-trip.")
		assert_equal(restored.to_dictionary(), original.to_dictionary(), "A full round-trip should be value-identical.")


func _parse_honors_partial_settings_and_defaults_the_rest() -> void:
	# A slightly stale / partial settings file should still load: present fields honored,
	# absent fields defaulted. No hard failure.
	var partial: Dictionary = {
		"schema_version": SettingsSnapshot.SCHEMA_VERSION,
		"text_scale": 1.5
	}
	var parse_result: ActionResult = SettingsSnapshot.parse(partial)
	assert_true(parse_result.succeeded, "parse() should accept a partial settings dictionary.")
	if parse_result.succeeded:
		var snapshot: SettingsSnapshot = parse_result.metadata.get("snapshot")
		assert_equal(snapshot.text_scale, 1.5, "Present field should be honored.")
		assert_equal(snapshot.master_volume_db, SettingsSnapshot.DEFAULT_VOLUME_DB, "Absent volume should default.")
		assert_false(snapshot.audio_muted, "Absent mute should default false.")
		assert_equal(snapshot.input_scheme, SettingsSnapshot.DEFAULT_INPUT_SCHEME, "Absent input_scheme should default.")


func _parsed_with(overrides: Dictionary) -> SettingsSnapshot:
	var data: Dictionary = {"schema_version": SettingsSnapshot.SCHEMA_VERSION}
	for key: Variant in overrides.keys():
		data[key] = overrides[key]
	var parse_result: ActionResult = SettingsSnapshot.parse(data)
	if parse_result.is_error():
		# Surface the failure to the assertion that called this helper rather than crashing.
		assert_true(false, "parse() unexpectedly errored for %s: %s" % [str(overrides), String(parse_result.error_code)])
		return SettingsSnapshot.defaults()
	return parse_result.metadata.get("snapshot")
