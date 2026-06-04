extends Node

const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")

signal run_seed_configured(root_seed: int)

var _root_seed: int = 0
var _rng_streams: RngStreamSet = RngStreamSet.new()

func configure_seed(new_root_seed: int) -> void:
	_root_seed = new_root_seed
	_rng_streams.configure(_root_seed)
	run_seed_configured.emit(_root_seed)


func get_root_seed() -> int:
	return _root_seed


func rng_snapshot() -> Dictionary:
	return _rng_streams.to_snapshot()


func restore_rng_snapshot(snapshot: Dictionary) -> void:
	_rng_streams.restore(snapshot)
	_root_seed = int(snapshot.get("root_seed", _root_seed))
