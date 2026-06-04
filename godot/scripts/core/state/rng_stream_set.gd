class_name RngStreamSet
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const STREAM_MAP := &"map"
const STREAM_LEVEL := &"level"
const STREAM_COMBAT := &"combat"
const STREAM_LOOT := &"loot"
const STREAM_REWARDS := &"rewards"
const STREAM_EVENTS := &"events"
const STREAM_COSMETIC := &"cosmetic"

var _root_seed: int = 0
var _streams: Dictionary = {}

func _init(new_root_seed: int = 0) -> void:
	configure(new_root_seed)


static func required_streams() -> Array[StringName]:
	return [
		STREAM_MAP,
		STREAM_LEVEL,
		STREAM_COMBAT,
		STREAM_LOOT,
		STREAM_REWARDS,
		STREAM_EVENTS,
		STREAM_COSMETIC
	]


func configure(new_root_seed: int) -> void:
	_root_seed = new_root_seed
	_streams.clear()
	for stream_name: StringName in required_streams():
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = _derive_seed(_root_seed, stream_name)
		_streams[stream_name] = rng


func has_stream(stream_name: StringName) -> bool:
	return _streams.has(stream_name)


func rand_int(stream_name: StringName, minimum: int, maximum: int) -> ActionResult:
	var rng: RandomNumberGenerator = _get_stream_or_null(stream_name)
	if rng == null:
		return ActionResult.error(&"unknown_rng_stream", {"stream": String(stream_name)})
	return ActionResult.ok([], {"value": rng.randi_range(minimum, maximum)})


func rand_float(stream_name: StringName) -> ActionResult:
	var rng: RandomNumberGenerator = _get_stream_or_null(stream_name)
	if rng == null:
		return ActionResult.error(&"unknown_rng_stream", {"stream": String(stream_name)})
	return ActionResult.ok([], {"value": rng.randf()})


func try_rand_int(stream_name: StringName, minimum: int, maximum: int) -> ActionResult:
	return rand_int(stream_name, minimum, maximum)


func try_rand_float(stream_name: StringName) -> ActionResult:
	return rand_float(stream_name)


func to_snapshot() -> Dictionary:
	var stream_states: Dictionary = {}
	for stream_name: StringName in required_streams():
		var rng: RandomNumberGenerator = _streams[stream_name] as RandomNumberGenerator
		stream_states[String(stream_name)] = {
			"seed": rng.seed,
			"state": rng.state
		}
	return {
		"root_seed": _root_seed,
		"streams": stream_states
	}


func restore(snapshot: Dictionary) -> void:
	_root_seed = int(snapshot.get("root_seed", 0))
	configure(_root_seed)

	var stream_states: Dictionary = snapshot.get("streams", {})
	for stream_name: StringName in required_streams():
		var stream_key: String = String(stream_name)
		if not stream_states.has(stream_key):
			continue
		var rng_state: Dictionary = stream_states[stream_key]
		var rng: RandomNumberGenerator = _streams[stream_name] as RandomNumberGenerator
		rng.seed = int(rng_state.get("seed", rng.seed))
		rng.state = int(rng_state.get("state", rng.state))


func _get_stream_or_null(stream_name: StringName) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		return null
	return _streams[stream_name] as RandomNumberGenerator


static func _derive_seed(base_seed: int, stream_name: StringName) -> int:
	var mixed: int = (base_seed & 0x7fffffff) ^ _stable_stream_hash(stream_name)
	mixed = (mixed * 1103515245 + 12345) & 0x7fffffff
	if mixed == 0:
		return 1
	return mixed


static func _stable_stream_hash(stream_name: StringName) -> int:
	var text: String = String(stream_name)
	var hash_value: int = 2166136261
	for index: int in range(text.length()):
		hash_value = hash_value ^ text.unicode_at(index)
		hash_value = (hash_value * 16777619) & 0x7fffffff
	if hash_value == 0:
		return 1
	return hash_value
