extends Node

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

var repository: SaveRepository = SaveRepository.new()

func write_run_snapshot(snapshot: RunSnapshot) -> ActionResult:
	return repository.write_run_snapshot(snapshot)


func read_run_snapshot() -> ActionResult:
	return repository.read_run_snapshot()


# Between-level autosave entry point (Story 2.7). Thin delegation to the repository's atomic write;
# returns the repository's structured ActionResult UNCHANGED (error_code + diagnostic metadata
# preserved, never collapsed to a bool). This autoload owns no snapshot schema policy, no tactical
# truth, and no composition logic — the caller composes the RunSnapshot (see
# RunSnapshot.from_between_level) and this method only persists it.
func autosave_between_level(snapshot: RunSnapshot, save_path: String = SaveRepository.DEFAULT_RUN_PATH) -> ActionResult:
	return repository.write_run_snapshot(snapshot, save_path)


# Between-level resume entry point (Story 2.8). Thin delegation to RunResumeService, which composes
# the existing restore primitives and returns the restored domain pieces (run_snapshot,
# tactical_snapshot, board, rng_streams) on success or the first structured error (no partial
# state) on failure. This autoload owns no restore/composition logic and no schema policy; the
# structured ActionResult is returned UNCHANGED for a recovery flow / presenter to consume.
func resume_run(save_path: String = SaveRepository.DEFAULT_RUN_PATH) -> ActionResult:
	return RunResumeService.new().resume(save_path)
