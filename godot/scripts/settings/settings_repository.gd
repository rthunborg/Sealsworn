class_name SettingsRepository
extends RefCounted

## Persists player preferences to their OWN user://settings.json (Story 2.9), completely
## independent of the run autosave (user://run_autosave.json, Story 2.7/2.8). Mirrors
## SaveRepository's structured atomic temp/replace write and FileAccess + JSON.parse_string read,
## but with a settings-specific path and a graceful read policy.
##
## Read policy (AC1 — settings must always load to a usable model and never block the player):
##   - missing file (first launch) -> defaults() as a SUCCESS, with metadata {first_launch: true}.
##   - unreadable / malformed JSON  -> defaults() as a SUCCESS, with metadata
##     {recovered: true, recovered_reason: <code>} (preferences are non-critical; degrade, do not
##     block). Godot prints one expected "ERROR: Parse JSON failed" line on the malformed path —
##     that is the cost of exercising the real parse path, not a failure.
##   - schema-version mismatch      -> structured error unsupported_settings_schema (the file is
##     from an incompatible build, not mere corruption; surfaced so the caller can decide).
##
## This repository NEVER reads, writes, truncates, or renames the run autosave or any run/tactical/
## RNG state. Settings and run saves are independent files with independent repositories.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")

const DEFAULT_SETTINGS_PATH := "user://settings.json"

func write_settings(snapshot: SettingsSnapshot, settings_path: String = DEFAULT_SETTINGS_PATH) -> ActionResult:
	var temp_path: String = "%s.tmp" % settings_path
	var backup_path: String = "%s.bak" % settings_path
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return ActionResult.error(&"settings_open_failed", {
			"path": temp_path,
			"open_error": FileAccess.get_open_error()
		})

	file.store_string(JSON.stringify(snapshot.to_dictionary()))
	file.flush()
	file = null

	if FileAccess.file_exists(backup_path):
		var remove_backup_error: Error = DirAccess.remove_absolute(backup_path)
		if remove_backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return ActionResult.error(&"settings_backup_remove_failed", {
				"path": backup_path,
				"remove_error": remove_backup_error
			})

	if FileAccess.file_exists(settings_path):
		var backup_error: Error = DirAccess.rename_absolute(settings_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return ActionResult.error(&"settings_backup_failed", {
				"path": settings_path,
				"backup_path": backup_path,
				"rename_error": backup_error
			})

	var replace_error: Error = DirAccess.rename_absolute(temp_path, settings_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, settings_path)
		DirAccess.remove_absolute(temp_path)
		return ActionResult.error(&"settings_replace_failed", {
			"path": settings_path,
			"temp_path": temp_path,
			"rename_error": replace_error
		})

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	return ActionResult.ok()


func read_settings(settings_path: String = DEFAULT_SETTINGS_PATH) -> ActionResult:
	# First launch: no file -> defaults() as a SUCCESS (loading settings must never hard-fail).
	if not FileAccess.file_exists(settings_path):
		return _defaults_result({"first_launch": true, "path": settings_path})

	var file: FileAccess = FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		# Unreadable file -> graceful fallback to defaults with a diagnostic.
		return _defaults_result({
			"recovered": true,
			"recovered_reason": "settings_open_failed",
			"path": settings_path,
			"open_error": FileAccess.get_open_error()
		})

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		# Malformed JSON -> graceful fallback to defaults with a diagnostic.
		return _defaults_result({
			"recovered": true,
			"recovered_reason": "settings_parse_failed",
			"path": settings_path
		})

	var parse_result: ActionResult = SettingsSnapshot.parse(parsed)
	# A schema-version mismatch is surfaced as a structured error (incompatible build), not
	# silently overwritten. All field-level corruption is already sanitized inside parse().
	if parse_result.is_error():
		return parse_result
	return parse_result


# Build a success result whose snapshot is a fresh defaults() instance plus diagnostic metadata.
func _defaults_result(metadata: Dictionary) -> ActionResult:
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	var combined: Dictionary = metadata.duplicate(true)
	combined["snapshot"] = snapshot
	return ActionResult.ok([], combined)
