class_name SaveRepository
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")

const DEFAULT_RUN_PATH := "user://run_autosave.json"

func write_run_snapshot(snapshot: RunSnapshot, save_path: String = DEFAULT_RUN_PATH) -> ActionResult:
	var temp_path: String = "%s.tmp" % save_path
	var backup_path: String = "%s.bak" % save_path
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return ActionResult.error(&"save_open_failed", {
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
			return ActionResult.error(&"save_backup_remove_failed", {
				"path": backup_path,
				"remove_error": remove_backup_error
			})

	if FileAccess.file_exists(save_path):
		var backup_error: Error = DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return ActionResult.error(&"save_backup_failed", {
				"path": save_path,
				"backup_path": backup_path,
				"rename_error": backup_error
			})

	var replace_error: Error = DirAccess.rename_absolute(temp_path, save_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, save_path)
		DirAccess.remove_absolute(temp_path)
		return ActionResult.error(&"save_replace_failed", {
			"path": save_path,
			"temp_path": temp_path,
			"rename_error": replace_error
		})

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	return ActionResult.ok()


func read_run_snapshot(save_path: String = DEFAULT_RUN_PATH) -> ActionResult:
	if not FileAccess.file_exists(save_path):
		return ActionResult.error(&"save_not_found", {"path": save_path})

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return ActionResult.error(&"save_open_failed", {
			"path": save_path,
			"open_error": FileAccess.get_open_error()
		})

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return ActionResult.error(&"save_parse_failed", {"path": save_path})

	return RunSnapshot.parse(parsed)
