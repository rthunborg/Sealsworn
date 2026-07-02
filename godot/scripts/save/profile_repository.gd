class_name ProfileRepository
extends RefCounted

# Story 8.3 (AC1, AC5) — the cross-run META PROFILE repository. Mirrors SaveRepository VERBATIM (the atomic
# temp→backup→replace write + the structured-error read) but with a SEPARATE save file (user://profile.json — NOT the
# run autosave user://run_autosave.json; the profile is its OWN save file, NOT the RunSnapshot) and the ProfileSnapshot
# schema. The profile is the FIRST persistent CROSS-RUN state: it OUTLIVES a run and accumulates across many descents.
#
# ⭐ AC5 — the structured save-failure recovery: write_profile returns a STRUCTURED ActionResult.error(...) on ANY
# write failure (open / backup / replace) — NEVER a silent swallow, NEVER a crash, NEVER a loss of the current run
# summary. The stable profile-scoped error codes (profile_save_open_failed / profile_save_backup_remove_failed /
# profile_save_backup_failed / profile_save_replace_failed) let a recovery UI (Story 8.6) surface the failure + retry
# ([Decision] — profile-scoped codes, NOT the shared save_* names, so a profile failure is diagnosable distinctly from
# a run-autosave failure). The atomic write leaves any prior valid profile intact on a failed replace (the SaveRepository
# rollback precedent). AC5's "does not silently lose current run summary data" is STRUCTURAL: the RunSummary (Story 8.2)
# is a DERIVED read composed from the terminal run + events — it does NOT read the profile file, so a failed profile
# write leaves the summary fully readable (proven in test_award_meta_progress_command.gd).
#
# read_profile returns the stable profile_not_found when the file is ABSENT — the CALLER starts a FRESH ProfileSnapshot
# on profile_not_found (AC5 recovery + the 8.6 fresh-profile path; ProfileSnapshot.fresh()), profile_open_failed on an
# unreadable file, profile_parse_failed on malformed JSON, else ProfileSnapshot.parse(parsed) (which surfaces
# unsupported_profile_schema for a bad schema — the migration reject).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")

const DEFAULT_PROFILE_PATH := "user://profile.json"

# Atomic temp→backup→replace write (SaveRepository.write_run_snapshot VERBATIM, profile-scoped codes). Returns
# ActionResult.ok() on success, a STRUCTURED error on ANY failure (AC5 — never a silent swallow). A failed write leaves
# any prior valid profile intact (the backup rollback on a failed replace).
func write_profile(snapshot: ProfileSnapshot, save_path: String = DEFAULT_PROFILE_PATH) -> ActionResult:
	var temp_path: String = "%s.tmp" % save_path
	var backup_path: String = "%s.bak" % save_path
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return ActionResult.error(&"profile_save_open_failed", {
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
			return ActionResult.error(&"profile_save_backup_remove_failed", {
				"path": backup_path,
				"remove_error": remove_backup_error
			})

	if FileAccess.file_exists(save_path):
		var backup_error: Error = DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return ActionResult.error(&"profile_save_backup_failed", {
				"path": save_path,
				"backup_path": backup_path,
				"rename_error": backup_error
			})

	var replace_error: Error = DirAccess.rename_absolute(temp_path, save_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, save_path)
		DirAccess.remove_absolute(temp_path)
		return ActionResult.error(&"profile_save_replace_failed", {
			"path": save_path,
			"temp_path": temp_path,
			"rename_error": replace_error
		})

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	return ActionResult.ok()


# Structured read (SaveRepository.read_run_snapshot VERBATIM, profile-scoped codes). Returns profile_not_found when the
# file is absent (the caller starts a FRESH ProfileSnapshot — AC5 recovery), profile_open_failed on an unreadable file,
# profile_parse_failed on malformed JSON, else ProfileSnapshot.parse(parsed) (surfacing unsupported_profile_schema for a
# bad schema).
func read_profile(save_path: String = DEFAULT_PROFILE_PATH) -> ActionResult:
	if not FileAccess.file_exists(save_path):
		return ActionResult.error(&"profile_not_found", {"path": save_path})

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return ActionResult.error(&"profile_open_failed", {
			"path": save_path,
			"open_error": FileAccess.get_open_error()
		})

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return ActionResult.error(&"profile_parse_failed", {"path": save_path})

	return ProfileSnapshot.parse(parsed)
