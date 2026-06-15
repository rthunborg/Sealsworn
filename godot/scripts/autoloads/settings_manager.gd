extends Node

## Thin settings autoload (Story 2.9). Holds the current SettingsSnapshot and delegates load/save
## to SettingsRepository and apply to SettingsApplyService. It owns NO schema policy (that lives in
## SettingsSnapshot), NO failure policy (that lives in SettingsRepository), and NO gameplay
## decisions. Save/load return the repository/service structured ActionResult UNCHANGED (never
## collapsed to a bool). Mirrors the SaveManager/GameSession thin-autoload posture.
##
## Settings are SAFE preferences only and never touch the run autosave or any run/tactical/RNG/
## progression state (AC1). The difficulty NON-GOAL is enforced in SettingsSnapshot.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const SettingsApplyService = preload("res://scripts/settings/settings_apply_service.gd")
const SettingsRepository = preload("res://scripts/settings/settings_repository.gd")
const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")

var repository: SettingsRepository = SettingsRepository.new()
var apply_service: SettingsApplyService = SettingsApplyService.new()

var _current: SettingsSnapshot = SettingsSnapshot.defaults()

func _ready() -> void:
	# On boot, load persisted preferences (defaults on first launch) and apply them so audio/text
	# preferences take effect immediately. Errors (e.g. an incompatible schema) are logged and the
	# in-memory defaults remain active; the player is never blocked at boot by a settings problem.
	var load_result: ActionResult = load_settings()
	if load_result.is_error():
		push_warning("SettingsManager boot load failed (%s); using defaults." % String(load_result.error_code))


func current() -> SettingsSnapshot:
	return _current


# Load preferences through the repository, hold them as current, and apply them. Returns the
# repository's structured ActionResult unchanged. On a structured error the current snapshot is
# left intact (no partial activation).
func load_settings(settings_path: String = SettingsRepository.DEFAULT_SETTINGS_PATH) -> ActionResult:
	var read_result: ActionResult = repository.read_settings(settings_path)
	if read_result.is_error():
		return read_result
	var snapshot: SettingsSnapshot = read_result.metadata.get("snapshot")
	if snapshot == null:
		return ActionResult.error(&"settings_load_missing_snapshot", {"path": settings_path})
	_current = snapshot
	apply_service.apply(_current)
	return read_result


# Persist preferences through the repository and, on success, hold + apply them. Returns the
# repository's structured ActionResult unchanged (error_code + diagnostic metadata preserved).
func save_settings(snapshot: SettingsSnapshot, settings_path: String = SettingsRepository.DEFAULT_SETTINGS_PATH) -> ActionResult:
	var write_result: ActionResult = repository.write_settings(snapshot, settings_path)
	if write_result.is_error():
		return write_result
	_current = snapshot
	apply_service.apply(_current)
	return write_result


# Re-apply the current snapshot (e.g. after a presenter rebinds). Pure preferences apply.
func apply_current() -> ActionResult:
	return apply_service.apply(_current)
