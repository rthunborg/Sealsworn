class_name RunSnapshot
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

const SCHEMA_VERSION: int = 1

# Stable key under which the composed Epic 1 tactical snapshot lives inside level_state.
# AC3: the between-level save composes TacticalSnapshot here rather than forking a parallel
# scene-owned tactical save format.
const TACTICAL_SNAPSHOT_KEY: String = "tactical_snapshot"

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
		"root_seed": str(root_seed),
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
	snapshot.root_seed = _int64_or_zero(data.get("root_seed", 0))
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


# Compose a between-level run save from existing domain state. AC1/AC3: the authoritative
# tactical/level payload is the Epic 1 TacticalSnapshot, embedded under TACTICAL_SNAPSHOT_KEY in
# level_state; tactical board/turn/telegraph/event fields are NOT flattened onto the run save.
# This is a pure read of domain state: it consumes no RNG draws and mutates nothing.
#
# options (all optional):
#   is_manual_seed: bool           - manual-seed runs grant no meta progression
#   current_route_node_id: String  - between-level boundary node, when available
#   profile_id / run_id: String
#   turn_state: Dictionary         - tactical turn state at the boundary
#   pending_telegraphs: Array[Dictionary]
#   event_log: Array[DomainEvent]
static func from_between_level(
	board_state: BoardState,
	streams: RngStreamSet,
	options: Dictionary = {}
) -> ActionResult:
	if board_state == null:
		return ActionResult.error(&"missing_board_state", {"field": "board_state"})
	if streams == null:
		return ActionResult.error(&"missing_rng_streams", {"field": "rng_streams"})

	var turn_state_value: Dictionary = _dictionary_or_empty(options.get("turn_state", {}))
	var pending_telegraphs: Array[Dictionary] = _dictionary_array(options.get("pending_telegraphs", []))
	var event_log: Array[DomainEvent] = _domain_event_array(options.get("event_log", []))

	# Build the authoritative tactical snapshot through the strict Epic 1 boundary. If the source
	# domain state is inconsistent, fail here and expose no partial run snapshot.
	var tactical_result: ActionResult = TacticalSnapshot.from_domain(
		board_state,
		streams,
		turn_state_value,
		pending_telegraphs,
		event_log
	)
	if tactical_result.is_error():
		return tactical_result
	var tactical: TacticalSnapshot = tactical_result.metadata.get("snapshot") as TacticalSnapshot

	# Single pure read of the RNG snapshot at the boundary (consumes no draws, mutates nothing).
	# The run-level rng_streams is the between-level authority; it coincides with the embedded
	# tactical rng_streams because the save is taken at the level boundary.
	var rng_snapshot: Dictionary = streams.to_snapshot()

	var snapshot: RunSnapshot = load("res://scripts/save/snapshots/run_snapshot.gd").new()
	snapshot.root_seed = _int64_or_zero(rng_snapshot.get("root_seed", 0))
	snapshot.rng_streams = rng_snapshot
	snapshot.is_manual_seed = bool(options.get("is_manual_seed", false))
	# Manual-seed runs are allowed for replay/practice/share but grant no meta progression.
	snapshot.meta_progression_eligible = not snapshot.is_manual_seed
	snapshot.current_route_node_id = str(options.get("current_route_node_id", ""))
	snapshot.profile_id = str(options.get("profile_id", "default"))
	snapshot.run_id = str(options.get("run_id", ""))
	# Embed (do not flatten) the tactical snapshot as the between-level level payload.
	snapshot.level_state = {TACTICAL_SNAPSHOT_KEY: tactical.to_dictionary()}
	return ActionResult.ok([], {"snapshot": snapshot})


# Strictly extract and validate the embedded tactical snapshot. The run-save parse() is lenient
# for run-level forward-compat, but the embedded tactical payload must always pass the strict
# Epic 1 TacticalSnapshot.parse() (AC3) so corrupt tactical data is rejected with structure and
# never activated as partial state.
func try_tactical_snapshot() -> ActionResult:
	if not level_state.has(TACTICAL_SNAPSHOT_KEY):
		return ActionResult.error(&"missing_tactical_snapshot", {"key": TACTICAL_SNAPSHOT_KEY})
	var embedded_value: Variant = level_state.get(TACTICAL_SNAPSHOT_KEY)
	if not embedded_value is Dictionary:
		return ActionResult.error(&"missing_tactical_snapshot", {
			"key": TACTICAL_SNAPSHOT_KEY,
			"reason": "embedded_tactical_snapshot_not_a_dictionary"
		})
	return TacticalSnapshot.parse(embedded_value)


func has_tactical_snapshot() -> bool:
	return level_state.has(TACTICAL_SNAPSHOT_KEY) and level_state.get(TACTICAL_SNAPSHOT_KEY) is Dictionary


static func _domain_event_array(value: Variant) -> Array[DomainEvent]:
	var result: Array[DomainEvent] = []
	if not value is Array:
		return result
	for item: Variant in value:
		if item is DomainEvent:
			result.append(item)
	return result


static func _int64_or_zero(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return 0
			return int(numeric_value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value)
			if text.is_valid_int():
				return text.to_int()
			return 0
		_:
			return 0
