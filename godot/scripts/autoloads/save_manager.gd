extends Node

const ActionResult = preload("res://scripts/core/results/action_result.gd")
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
