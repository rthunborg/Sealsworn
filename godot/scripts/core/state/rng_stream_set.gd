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
const MAX_CONSUMER_CONTEXT_DEPTH: int = 16

var _root_seed: int = 0
var _streams: Dictionary = {}
var _draw_indexes: Dictionary = {}

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
	_draw_indexes.clear()
	for stream_name: StringName in required_streams():
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = _derive_seed(_root_seed, stream_name)
		_streams[stream_name] = rng
		_draw_indexes[stream_name] = 0


func has_stream(stream_name: StringName) -> bool:
	return _streams.has(stream_name)


func rand_int(stream_name: StringName, minimum: int, maximum: int, consumer_context: Dictionary = {}) -> ActionResult:
	var rng: RandomNumberGenerator = _get_stream_or_null(stream_name)
	if rng == null:
		return ActionResult.error(&"unknown_rng_stream", {"stream": String(stream_name)})
	if minimum > maximum:
		return ActionResult.error(&"invalid_rng_range", {
			"stream": String(stream_name),
			"minimum": minimum,
			"maximum": maximum
		})
	var context_result: ActionResult = _try_copy_serializable_dictionary(consumer_context)
	if context_result.is_error():
		return context_result
	var copied_context: Dictionary = context_result.metadata.get("value")
	var state_before: int = rng.state
	var value: int = rng.randi_range(minimum, maximum)
	var state_after: int = rng.state
	return ActionResult.ok([], _build_draw_metadata(stream_name, &"int", value, state_before, state_after, copied_context))


func rand_float(stream_name: StringName, consumer_context: Dictionary = {}) -> ActionResult:
	var rng: RandomNumberGenerator = _get_stream_or_null(stream_name)
	if rng == null:
		return ActionResult.error(&"unknown_rng_stream", {"stream": String(stream_name)})
	var context_result: ActionResult = _try_copy_serializable_dictionary(consumer_context)
	if context_result.is_error():
		return context_result
	var copied_context: Dictionary = context_result.metadata.get("value")
	var state_before: int = rng.state
	var value: float = rng.randf()
	var state_after: int = rng.state
	return ActionResult.ok([], _build_draw_metadata(stream_name, &"float", value, state_before, state_after, copied_context))


func try_rand_int(stream_name: StringName, minimum: int, maximum: int, consumer_context: Dictionary = {}) -> ActionResult:
	return rand_int(stream_name, minimum, maximum, consumer_context)


func try_rand_float(stream_name: StringName, consumer_context: Dictionary = {}) -> ActionResult:
	return rand_float(stream_name, consumer_context)


func to_snapshot() -> Dictionary:
	# root_seed and per-stream state are full 64-bit integers. JSON numbers are IEEE-754 doubles
	# (52-bit mantissa), so persisting them as raw JSON numbers silently truncates values beyond
	# 2^53 and breaks resume determinism. Encode them as lossless decimal strings instead. The
	# derived per-stream seed is always <= 2^31 (see _derive_seed) so it stays a plain integer.
	var stream_states: Dictionary = {}
	for stream_name: StringName in required_streams():
		var rng: RandomNumberGenerator = _streams[stream_name] as RandomNumberGenerator
		stream_states[String(stream_name)] = {
			"seed": rng.seed,
			"state": str(rng.state),
			"draw_index": int(_draw_indexes.get(stream_name, 0))
		}
	return {
		"root_seed": str(_root_seed),
		"streams": stream_states
	}


func try_restore(snapshot: Dictionary) -> ActionResult:
	# Accept both the int64-safe string encoding (current to_snapshot output, survives JSON) and
	# raw integers (legacy/native dicts and JSON-parsed integral floats). seed/draw_index are
	# small and stay numeric; root_seed/state may be full 64-bit and may arrive as decimal strings.
	if not snapshot.has("root_seed"):
		return _snapshot_error(&"missing_or_invalid_root_seed")
	var root_seed_result: Dictionary = _int64_from_value(snapshot.get("root_seed"))
	if not bool(root_seed_result.get("ok", false)):
		return _snapshot_error(&"missing_or_invalid_root_seed")
	if not snapshot.has("streams") or not snapshot.get("streams") is Dictionary:
		return _snapshot_error(&"missing_or_invalid_streams")

	var restored_streams: Dictionary = {}
	var restored_draw_indexes: Dictionary = {}
	var stream_states: Dictionary = snapshot.get("streams")

	for stream_name: StringName in required_streams():
		var stream_key: String = String(stream_name)
		if not stream_states.has(stream_key):
			return _snapshot_error(&"missing_required_stream", stream_key)

		var stream_state_value: Variant = stream_states[stream_key]
		if not stream_state_value is Dictionary:
			return _snapshot_error(&"invalid_stream_state", stream_key)

		var stream_state: Dictionary = stream_state_value
		if not stream_state.has("seed") or not _is_integral_value(stream_state.get("seed")):
			return _snapshot_error(&"invalid_stream_seed", stream_key)
		if not stream_state.has("state"):
			return _snapshot_error(&"invalid_stream_state_value", stream_key)
		var state_result: Dictionary = _int64_from_value(stream_state.get("state"))
		if not bool(state_result.get("ok", false)):
			return _snapshot_error(&"invalid_stream_state_value", stream_key)
		if not stream_state.has("draw_index") or not _is_integral_value(stream_state.get("draw_index")):
			return _snapshot_error(&"invalid_stream_draw_index", stream_key)

		var draw_index: int = int(stream_state.get("draw_index"))
		if draw_index < 0:
			return _snapshot_error(&"invalid_stream_draw_index", stream_key)

		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(stream_state.get("seed"))
		rng.state = int(state_result.get("value"))
		restored_streams[stream_name] = rng
		restored_draw_indexes[stream_name] = draw_index

	_root_seed = int(root_seed_result.get("value"))
	_streams = restored_streams
	_draw_indexes = restored_draw_indexes
	return ActionResult.ok([], {"root_seed": _root_seed})


func restore(snapshot: Dictionary) -> void:
	var result: ActionResult = try_restore(snapshot)
	if result.is_error():
		push_error("RngStreamSet restore failed: %s" % String(result.error_code))


func _get_stream_or_null(stream_name: StringName) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		return null
	return _streams[stream_name] as RandomNumberGenerator


func _build_draw_metadata(stream_name: StringName, draw_type: StringName, value: Variant, state_before: int, state_after: int, copied_context: Dictionary) -> Dictionary:
	var draw_index: int = int(_draw_indexes.get(stream_name, 0))
	_draw_indexes[stream_name] = draw_index + 1
	return {
		"value": value,
		"stream_name": String(stream_name),
		"draw_index": draw_index,
		"state_before": state_before,
		"state_after": state_after,
		"draw_type": String(draw_type),
		"consumer_context": copied_context
	}


func _snapshot_error(reason: StringName, stream_name: String = "") -> ActionResult:
	var metadata: Dictionary = {"reason": String(reason)}
	if not stream_name.is_empty():
		metadata["stream_name"] = stream_name
	return ActionResult.error(&"invalid_rng_snapshot", metadata)


# Accepts a 64-bit integer encoded as int, integral float, or decimal string. Returns
# {"ok": bool, "value": int}. Non-integral floats, non-integer strings, and other types fail.
static func _int64_from_value(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_INT:
			return {"ok": true, "value": int(value)}
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return {"ok": false}
			if not is_equal_approx(numeric_value, round(numeric_value)):
				return {"ok": false}
			return {"ok": true, "value": int(numeric_value)}
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value)
			if not text.is_valid_int():
				return {"ok": false}
			return {"ok": true, "value": text.to_int()}
		_:
			return {"ok": false}


# Accepts an integer encoded as int or integral float (no string form). Used for small bounded
# fields (per-stream seed, draw_index) that survive JSON as integral floats.
static func _is_integral_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return false
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


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


static func _try_copy_serializable_dictionary(source: Dictionary) -> ActionResult:
	var result: Dictionary = _copy_serializable_dictionary(source, 0)
	if result.get("ok") == false:
		return ActionResult.error(&"invalid_rng_consumer_context", {
			"reason": str(result.get("reason", "invalid_context"))
		})
	return ActionResult.ok([], {"value": result.get("value", {})})


static func _copy_serializable_dictionary(source: Dictionary, depth: int) -> Dictionary:
	if depth > MAX_CONSUMER_CONTEXT_DEPTH:
		return {"ok": false, "reason": "max_depth_exceeded"}

	var result: Dictionary = {}
	for key: Variant in source.keys():
		var copied_key: Variant = _copy_serializable_key(key)
		if copied_key == null:
			continue
		var value: Variant = source[key]
		var copied_value: Dictionary = _copy_serializable_value(value, depth + 1)
		if copied_value.get("ok") == false:
			return copied_value
		if not bool(copied_value.get("accepted", false)):
			continue
		result[copied_key] = copied_value.get("value")
	return {"ok": true, "accepted": true, "value": result}


static func _copy_serializable_array(source: Array, depth: int) -> Dictionary:
	if depth > MAX_CONSUMER_CONTEXT_DEPTH:
		return {"ok": false, "reason": "max_depth_exceeded"}

	var result: Array = []
	for item: Variant in source:
		var copied_item: Dictionary = _copy_serializable_value(item, depth + 1)
		if copied_item.get("ok") == false:
			return copied_item
		if bool(copied_item.get("accepted", false)):
			result.append(copied_item.get("value"))
	return {"ok": true, "accepted": true, "value": result}


static func _copy_serializable_key(key: Variant) -> Variant:
	match typeof(key):
		TYPE_STRING:
			return key
		TYPE_STRING_NAME:
			return String(key)
		TYPE_INT:
			return key
		_:
			return null


static func _copy_serializable_value(value: Variant, depth: int) -> Dictionary:
	if depth > MAX_CONSUMER_CONTEXT_DEPTH:
		return {"ok": false, "reason": "max_depth_exceeded"}

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return {"ok": true, "accepted": true, "value": value}
		TYPE_STRING_NAME:
			return {"ok": true, "accepted": true, "value": String(value)}
		TYPE_ARRAY:
			return _copy_serializable_array(value, depth + 1)
		TYPE_DICTIONARY:
			return _copy_serializable_dictionary(value, depth + 1)
		_:
			return {"ok": true, "accepted": false}
