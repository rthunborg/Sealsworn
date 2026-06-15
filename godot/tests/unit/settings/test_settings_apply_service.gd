extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SettingsApplyService = preload("res://scripts/settings/settings_apply_service.gd")
const SettingsManager = preload("res://scripts/autoloads/settings_manager.gd")
const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")

const TEST_SETTINGS_PATH := "user://test_apply_settings.json"

func run() -> Dictionary:
	_apply_drives_audio_bus_when_present()
	_apply_yields_text_scale_presenter_hint()
	_apply_does_not_crash_without_master_bus()
	_apply_every_field_does_not_mutate_tactical_or_rng_state()
	_settings_manager_delegates_to_repository_unchanged()
	_settings_manager_load_applies_and_holds_current_snapshot()
	_cleanup()
	return result()


# AC4: applying a settings change drives the Master audio bus. GUARDED for headless: when the
# Master bus is absent (get_bus_index < 0), skip the bus reads and only assert the snapshot carried
# the right values + the apply call did not crash.
func _apply_drives_audio_bus_when_present() -> void:
	var service: SettingsApplyService = SettingsApplyService.new()
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	snapshot.master_volume_db = -8.0
	snapshot.audio_muted = true

	var apply_result: ActionResult = service.apply(snapshot)
	assert_true(apply_result.succeeded, "apply() should succeed: %s" % apply_result.metadata)
	assert_equal(apply_result.metadata.get("master_volume_db"), -8.0, "apply() metadata should echo the applied volume.")
	assert_equal(apply_result.metadata.get("audio_muted"), true, "apply() metadata should echo the applied mute state.")

	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		assert_true(is_equal_approx(AudioServer.get_bus_volume_db(bus_index), -8.0), "Applied volume should drive the Master bus when present.")
		assert_true(AudioServer.is_bus_mute(bus_index), "Applied mute should drive the Master bus when present.")
		# Restore the bus so we don't leak mute/volume into other tests.
		AudioServer.set_bus_volume_db(bus_index, 0.0)
		AudioServer.set_bus_mute(bus_index, false)


func _apply_yields_text_scale_presenter_hint() -> void:
	var service: SettingsApplyService = SettingsApplyService.new()
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	snapshot.text_scale = 1.5

	var apply_result: ActionResult = service.apply(snapshot)
	assert_true(apply_result.succeeded, "apply() should succeed for a text-scale change.")
	var hint: Variant = apply_result.metadata.get("text_scale_hint")
	assert_true(hint is Dictionary, "apply() should expose a text_scale presenter hint Dictionary.")
	if hint is Dictionary:
		assert_equal((hint as Dictionary).get("scale"), 1.5, "Presenter hint should carry the clamped text scale value.")

	# A malformed/over-range stored scale must surface as the clamped hint, not the raw value.
	var clamped_snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	clamped_snapshot.text_scale = 99.0
	var clamped_result: ActionResult = service.apply(clamped_snapshot)
	var clamped_hint: Variant = clamped_result.metadata.get("text_scale_hint")
	if clamped_hint is Dictionary:
		assert_equal((clamped_hint as Dictionary).get("scale"), TacticalTextScale.MAX_TEXT_SCALE, "Out-of-range text scale should clamp in the presenter hint.")


func _apply_does_not_crash_without_master_bus() -> void:
	# AudioManager already guards bus_index >= 0; the apply path must not crash when the bus is
	# absent. We assert that apply() simply succeeds regardless of bus presence (covered above for
	# the present case; here we assert the contract that no error is produced by bus absence).
	var service: SettingsApplyService = SettingsApplyService.new()
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	var apply_result: ActionResult = service.apply(snapshot)
	assert_true(apply_result.succeeded, "apply() must succeed even when the Master bus may be absent (headless).")


# AC1/AC4: applying every settings field must leave a board+RNG fixture's snapshot byte-identical.
# Settings is presentation/preferences only — no tactical truth, RNG, rewards, or progression change.
func _apply_every_field_does_not_mutate_tactical_or_rng_state() -> void:
	var service: SettingsApplyService = SettingsApplyService.new()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(7777)
	# Advance the RNG a little so the snapshot is non-trivial.
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 20, {"system": "combat"})
	streams.rand_float(RngStreamSet.STREAM_LOOT, {"system": "loot"})

	var board_before: Dictionary = board.to_snapshot()
	var rng_before: Dictionary = streams.to_snapshot()

	# Apply a snapshot exercising every preference field.
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	snapshot.text_scale = 1.8
	snapshot.master_volume_db = -15.0
	snapshot.audio_muted = true
	snapshot.input_scheme = "mouse_keyboard"
	snapshot.colorblind_safe = true
	snapshot.high_contrast = true
	var apply_result: ActionResult = service.apply(snapshot)
	assert_true(apply_result.succeeded, "apply() should succeed for a full-field snapshot.")

	assert_equal(board.to_snapshot(), board_before, "Applying settings must NOT mutate tactical board state.")
	assert_equal(streams.to_snapshot(), rng_before, "Applying settings must NOT draw RNG or mutate RNG state.")

	# Restore the bus in case it was present.
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, 0.0)
		AudioServer.set_bus_mute(bus_index, false)


# AC4: if a SettingsManager autoload exists, it delegates to the repository and returns the
# structured ActionResult UNCHANGED (mirror test_save_repository delegation).
func _settings_manager_delegates_to_repository_unchanged() -> void:
	var manager: Node = SettingsManager.new()
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	snapshot.text_scale = 1.2

	# Happy-path delegation writes through the repository.
	var save_result: ActionResult = manager.save_settings(snapshot, TEST_SETTINGS_PATH)
	assert_true(save_result is ActionResult, "SettingsManager must return the repository ActionResult, not a bool.")
	assert_true(save_result.succeeded, "SettingsManager.save_settings should delegate a successful write: %s" % save_result.metadata)

	# A forced failure must be returned UNCHANGED (structured error preserved).
	var failure_result: ActionResult = manager.save_settings(snapshot, "user://__test_missing_settings_dir__/settings.json")
	assert_true(failure_result is ActionResult, "SettingsManager must return the repository ActionResult on failure.")
	assert_true(failure_result.is_error(), "SettingsManager must surface the repository failure.")
	assert_equal(failure_result.error_code, &"settings_open_failed", "SettingsManager must preserve the repository's structured error code.")
	assert_true(failure_result.metadata.has("path"), "SettingsManager must preserve the repository's diagnostic metadata.")

	manager.free()
	_cleanup()


# The manager holds the current snapshot and applies it on load (thin orchestration only).
func _settings_manager_load_applies_and_holds_current_snapshot() -> void:
	_cleanup()
	var manager: Node = SettingsManager.new()

	# First load with no file should yield defaults and hold them as current.
	var load_result: ActionResult = manager.load_settings(TEST_SETTINGS_PATH)
	assert_true(load_result.succeeded, "SettingsManager.load_settings should succeed on first launch.")
	assert_true(manager.current() is SettingsSnapshot, "SettingsManager.current() should hold a SettingsSnapshot after load.")
	assert_equal(manager.current().to_dictionary(), SettingsSnapshot.defaults().to_dictionary(), "First-launch current() should equal defaults().")

	# Persist a custom snapshot, then load it back and confirm it becomes current.
	var custom: SettingsSnapshot = SettingsSnapshot.defaults()
	custom.text_scale = 1.45
	custom.input_scheme = "touch"
	var save_result: ActionResult = manager.save_settings(custom, TEST_SETTINGS_PATH)
	assert_true(save_result.succeeded, "SettingsManager.save_settings should persist a custom snapshot.")

	var reload_result: ActionResult = manager.load_settings(TEST_SETTINGS_PATH)
	assert_true(reload_result.succeeded, "SettingsManager.load_settings should read the persisted snapshot.")
	assert_equal(manager.current().text_scale, 1.45, "Reloaded current() should reflect the persisted text_scale.")
	assert_equal(manager.current().input_scheme, "touch", "Reloaded current() should reflect the persisted input_scheme.")

	# Restore the bus in case load applied a change.
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, 0.0)
		AudioServer.set_bus_mute(bus_index, false)

	manager.free()
	_cleanup()


func _cleanup() -> void:
	for path: String in [TEST_SETTINGS_PATH, "%s.tmp" % TEST_SETTINGS_PATH, "%s.bak" % TEST_SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
