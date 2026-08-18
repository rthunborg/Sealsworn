extends "res://tests/unit/test_case.gd"

# Story 15.4 (Review D1) — the scene-free MINIMAL OPTIONS projection + PURE MUTATION helpers behind the Options panel
# the shared pause menu opens. This pins: the six editable rows (exact-key, ids == OPTION_IDS); the toggle helpers
# flip the bool preferences; the cycle helpers advance + wrap the stepped/enumerated preferences; an unknown option
# is a no-op; and — critically — a mutation introduces NO new settings key and NO difficulty key (the hard non-goal
# stands). It edits ONLY the six existing SettingsSnapshot preferences over the existing parse/sanitize gate.

const SettingsOptionsViewModel = preload("res://scripts/ui/view_models/settings_options_view_model.gd")
const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")

func run() -> Dictionary:
	_rows_project_the_six_preferences_exact_key()
	_toggle_flips_the_bool_preferences()
	_cycle_advances_and_wraps()
	_apply_introduces_no_new_key_and_no_difficulty_key()
	_unknown_option_is_a_no_op()
	return result()


# rows() projects EXACTLY the six editable preferences (ids == OPTION_IDS, stable order), each row exact-key (ROW_KEYS).
func _rows_project_the_six_preferences_exact_key() -> void:
	var rows: Array[Dictionary] = SettingsOptionsViewModel.rows(SettingsSnapshot.defaults())
	assert_equal(rows.size(), SettingsOptionsViewModel.OPTION_IDS.size(), "rows() must project exactly one row per editable option.")
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		assert_equal(row.keys().size(), SettingsOptionsViewModel.ROW_KEYS.size(), "Each row must carry exactly the pinned ROW_KEYS.")
		for key: String in SettingsOptionsViewModel.ROW_KEYS:
			assert_true(row.has(key), "A row must carry the pinned key %s." % key)
		assert_equal(String(row.get("id")), SettingsOptionsViewModel.OPTION_IDS[index], "The row id/order must match OPTION_IDS.")
		assert_false(String(row.get("value_display")).is_empty(), "Each row must carry a non-empty value display.")


# The three bool preferences (audio_muted / colorblind_safe / high_contrast) flip on apply.
func _toggle_flips_the_bool_preferences() -> void:
	var base: SettingsSnapshot = SettingsSnapshot.defaults()
	assert_false(base.audio_muted, "Setup: audio starts unmuted.")

	var muted: SettingsSnapshot = SettingsOptionsViewModel.apply(base, "audio_muted")
	assert_true(muted.audio_muted, "apply(audio_muted) must flip mute ON.")
	assert_false(SettingsOptionsViewModel.apply(muted, "audio_muted").audio_muted, "apply(audio_muted) again must flip mute back OFF.")

	assert_true(SettingsOptionsViewModel.apply(base, "colorblind_safe").colorblind_safe, "apply(colorblind_safe) must flip it ON.")
	assert_true(SettingsOptionsViewModel.apply(base, "high_contrast").high_contrast, "apply(high_contrast) must flip it ON.")


# The stepped/enumerated preferences advance one step and WRAP at the end.
func _cycle_advances_and_wraps() -> void:
	# text_scale: 1.0 -> 1.25 (advance); 2.0 -> wraps to 1.0.
	var base: SettingsSnapshot = SettingsSnapshot.defaults()
	assert_true(_approx(SettingsOptionsViewModel.apply(base, "text_scale").text_scale, 1.25), "apply(text_scale) must advance 1.0 -> 1.25.")
	var at_max: SettingsSnapshot = SettingsSnapshot.defaults()
	at_max.text_scale = 2.0
	assert_true(_approx(SettingsOptionsViewModel.apply(at_max, "text_scale").text_scale, 1.0), "apply(text_scale) at the max must WRAP to 1.0.")

	# master_volume_db: 0 -> -10 (advance); -60 -> wraps to 0.
	assert_true(_approx(SettingsOptionsViewModel.apply(base, "master_volume_db").master_volume_db, -10.0), "apply(master_volume_db) must advance 0 -> -10 dB.")
	var at_floor: SettingsSnapshot = SettingsSnapshot.defaults()
	at_floor.master_volume_db = -60.0
	assert_true(_approx(SettingsOptionsViewModel.apply(at_floor, "master_volume_db").master_volume_db, 0.0), "apply(master_volume_db) at the floor must WRAP to 0 dB.")

	# input_scheme: auto -> touch -> mouse_keyboard -> auto.
	var touch: SettingsSnapshot = SettingsOptionsViewModel.apply(base, "input_scheme")
	assert_equal(touch.input_scheme, SettingsSnapshot.INPUT_SCHEME_TOUCH, "apply(input_scheme) must advance auto -> touch.")
	var mouse: SettingsSnapshot = SettingsOptionsViewModel.apply(touch, "input_scheme")
	assert_equal(mouse.input_scheme, SettingsSnapshot.INPUT_SCHEME_MOUSE_KEYBOARD, "apply(input_scheme) must advance touch -> mouse_keyboard.")
	assert_equal(SettingsOptionsViewModel.apply(mouse, "input_scheme").input_scheme, SettingsSnapshot.INPUT_SCHEME_AUTO, "apply(input_scheme) must WRAP mouse_keyboard -> auto.")


# A mutation edits ONLY the six existing preferences: the mutated snapshot's serialized key set equals the defaults'
# (no new key appears) and carries NONE of the forbidden difficulty keys (the hard non-goal stands).
func _apply_introduces_no_new_key_and_no_difficulty_key() -> void:
	var mutated: SettingsSnapshot = SettingsOptionsViewModel.apply(SettingsSnapshot.defaults(), "text_scale")
	var mutated_keys: Array = mutated.to_dictionary().keys()
	var default_keys: Array = SettingsSnapshot.defaults().to_dictionary().keys()
	assert_equal(mutated_keys.size(), default_keys.size(), "A mutation must not add or drop a settings key.")
	for key: Variant in default_keys:
		assert_true(mutated_keys.has(key), "The mutated snapshot must still carry the existing key %s." % str(key))
	for forbidden: String in ["difficulty", "difficulty_tier", "difficulty_modifier", "enemy_scaling"]:
		assert_false(mutated_keys.has(forbidden), "A mutation must NEVER introduce the difficulty key %s (the hard non-goal)." % forbidden)


# An unknown option id returns an equivalent (unchanged) snapshot — never a crash, never a new key.
func _unknown_option_is_a_no_op() -> void:
	var base: SettingsSnapshot = SettingsSnapshot.defaults()
	var same: SettingsSnapshot = SettingsOptionsViewModel.apply(base, "not_a_real_option")
	assert_equal(JSON.stringify(same.to_dictionary()), JSON.stringify(base.to_dictionary()), "An unknown option id must return an unchanged snapshot.")


func _approx(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 0.0001
