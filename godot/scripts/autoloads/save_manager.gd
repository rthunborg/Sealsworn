extends Node

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

var repository: SaveRepository = SaveRepository.new()

func write_run_snapshot(snapshot: RunSnapshot) -> ActionResult:
	return repository.write_run_snapshot(snapshot)


func read_run_snapshot() -> ActionResult:
	return repository.read_run_snapshot()
