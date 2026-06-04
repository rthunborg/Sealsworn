class_name RunSnapshot
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION
var content_version: String = "mvp-0"
var profile_id: String = "default"
var run_id: String = ""
var root_seed: int = 0
var is_manual_seed: bool = false
var meta_progression_eligible: bool = true
var route_state: Dictionary = {}
var current_route_node_id: String = ""
var revealed_route_node_ids: Array[String] = []
var level_state: Dictionary = {}
var turn_state: Dictionary = {}
var rng_streams: Dictionary = {}
var board: Dictionary = {}
var inventory: Array[Dictionary] = []
var equipment: Dictionary = {}
var passives: Array[String] = []
var curses: Array[String] = []
var gold: int = 0
var oath_shards: int = 0
var corruption: int = 0
var affinities: Dictionary = {}
var meta_progression: Dictionary = {}

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"content_version": content_version,
		"profile_id": profile_id,
		"run_id": run_id,
		"root_seed": root_seed,
		"is_manual_seed": is_manual_seed,
		"meta_progression_eligible": meta_progression_eligible,
		"route_state": route_state.duplicate(true),
		"current_route_node_id": current_route_node_id,
		"revealed_route_node_ids": revealed_route_node_ids.duplicate(true),
		"level_state": level_state.duplicate(true),
		"turn_state": turn_state.duplicate(true),
		"rng_streams": rng_streams.duplicate(true),
		"board": board.duplicate(true),
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"passives": passives.duplicate(true),
		"curses": curses.duplicate(true),
		"gold": gold,
		"oath_shards": oath_shards,
		"corruption": corruption,
		"affinities": affinities.duplicate(true),
		"meta_progression": meta_progression.duplicate(true)
	}


static func parse(data: Dictionary) -> ActionResult:
	var schema_value: int = int(data.get("schema_version", -1))
	if schema_value != SCHEMA_VERSION:
		return ActionResult.error(&"unsupported_save_schema", {
			"expected_schema_version": SCHEMA_VERSION,
			"actual_schema_version": schema_value
		})

	var snapshot: RunSnapshot = load("res://scripts/save/snapshots/run_snapshot.gd").new()
	snapshot.schema_version = schema_value
	snapshot.content_version = str(data.get("content_version", "mvp-0"))
	snapshot.profile_id = str(data.get("profile_id", "default"))
	snapshot.run_id = str(data.get("run_id", ""))
	snapshot.root_seed = int(data.get("root_seed", 0))
	snapshot.is_manual_seed = bool(data.get("is_manual_seed", false))
	snapshot.meta_progression_eligible = bool(data.get("meta_progression_eligible", true))
	snapshot.route_state = _dictionary_or_empty(data.get("route_state", {}))
	snapshot.current_route_node_id = str(data.get("current_route_node_id", ""))
	snapshot.revealed_route_node_ids = _string_array(data.get("revealed_route_node_ids", []))
	snapshot.level_state = _dictionary_or_empty(data.get("level_state", {}))
	snapshot.turn_state = _dictionary_or_empty(data.get("turn_state", {}))
	snapshot.rng_streams = _dictionary_or_empty(data.get("rng_streams", {}))
	snapshot.board = _dictionary_or_empty(data.get("board", {}))
	snapshot.inventory = _dictionary_array(data.get("inventory", []))
	snapshot.equipment = _dictionary_or_empty(data.get("equipment", {}))
	snapshot.passives = _string_array(data.get("passives", []))
	snapshot.curses = _string_array(data.get("curses", []))
	snapshot.gold = int(data.get("gold", 0))
	snapshot.oath_shards = int(data.get("oath_shards", 0))
	snapshot.corruption = int(data.get("corruption", 0))
	snapshot.affinities = _dictionary_or_empty(data.get("affinities", {}))
	snapshot.meta_progression = _dictionary_or_empty(data.get("meta_progression", {}))
	return ActionResult.ok([], {"snapshot": snapshot})


static func from_dictionary(data: Dictionary) -> RunSnapshot:
	var result: ActionResult = parse(data)
	if result.is_error():
		push_error("RunSnapshot parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("snapshot")


static func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result

	for item: Variant in value:
		if item is Dictionary:
			result.append(item.duplicate(true))
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result

	for item: Variant in value:
		result.append(str(item))
	return result
