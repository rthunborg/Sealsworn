extends Node

const ActionResult = preload("res://scripts/core/results/action_result.gd")
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


func restore_rng_snapshot(snapshot: Dictionary) -> ActionResult:
	var result: ActionResult = _rng_streams.try_restore(snapshot)
	if result.succeeded:
		# root_seed is int64-safe and is encoded as a decimal STRING by RngStreamSet.to_snapshot()
		# (Story 2.7). A raw int(...) cast on a >2^53 seed would silently truncate it; try_restore
		# has already validated and decoded the seed losslessly, so read the canonical value it
		# returns rather than re-coercing the raw snapshot field.
		_root_seed = int(result.metadata.get("root_seed", _root_seed))
	return result
