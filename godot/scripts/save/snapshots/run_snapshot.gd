class_name RunSnapshot
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunState = preload("res://scripts/run/run_state.gd")
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


# Compose a board-FREE ROUTE-POSITION run save from a live RunState + the run-level RngStreamSet (Story
# 4.6 Task 4.1). This is the SEPARATE save path for a between-NODE boundary — the player parked at a route
# CHOICE, NOT mid-level, where there is NO live BoardState (so from_between_level, which REQUIRES a board and
# embeds a strict TacticalSnapshot, does not fit). It COMPOSES the EXISTING RunSnapshot fields (it does NOT
# fork a parallel route-save format):
#   - root_seed / is_manual_seed / meta_progression_eligible / route_state (with nested run_phase) /
#     current_route_node_id / revealed_route_node_ids  <- from run.to_run_snapshot_fields() (the 4.1 bridge);
#   - rng_streams  <- from the passed-in run-level RngStreamSet.to_snapshot() (int64 decimal-string root_seed
#     + per-stream state, JSON-double-safe);
#   - level_state stays EMPTY (no embedded tactical board at a route choice).
# All these fields are ALREADY in the 23-key no-surprise-key gate, so this adds NO new top-level key and the
# gate stays green. It is a PURE READ: it draws no RNG and mutates neither the run nor the streams.
#
# Restore reads these run-level fields back through the EXISTING RunState.try_from_run_snapshot_fields (the
# 4.1/4.4 bridge — nested run_phase + the top-level pointer cross-check + the phaseless->NEW_RUN default) and
# the run-level RngStreamSet via try_restore — see RunResumeService.resume_route_position.
#
# options (all optional): profile_id / run_id: String.
static func from_route_position(
	source_run: RunState,
	streams: RngStreamSet,
	options: Dictionary = {}
) -> ActionResult:
	if source_run == null:
		return ActionResult.error(&"missing_run_state", {"field": "run"})
	if streams == null:
		return ActionResult.error(&"missing_rng_streams", {"field": "rng_streams"})

	# The 4.1 bridge: the existing run/route snapshot fields, with run_phase nested inside route_state.
	var fields: Dictionary = source_run.to_run_snapshot_fields()
	# Single pure read of the run-level RNG snapshot (consumes no draws, mutates nothing). The int64
	# root_seed + each per-stream state are decimal-string encoded by to_snapshot() (JSON-double-safe).
	var rng_snapshot: Dictionary = streams.to_snapshot()

	# The snapshot's run-seed (from the RunState) and RNG-seed (from the RngStreamSet) MUST agree: on restore
	# resume_route_position rebuilds the RunState from the top-level root_seed and the RngStreamSet from
	# rng_streams.root_seed INDEPENDENTLY, so a streams set seeded differently from the run would silently
	# produce a snapshot whose restored run-seed and RNG-seed diverge (a determinism break surfacing only as a
	# subtle wrong downstream draw). The single orchestrator caller always passes matching seeds; reject a
	# mismatch with a structured error (no partial snapshot) so a future mis-wiring fails loud here.
	if str(rng_snapshot.get("root_seed")) != str(source_run.root_seed):
		return ActionResult.error(&"route_position_seed_mismatch", {
			"field": "root_seed",
			"run_root_seed": str(source_run.root_seed),
			"streams_root_seed": str(rng_snapshot.get("root_seed"))
		})

	var snapshot: RunSnapshot = load("res://scripts/save/snapshots/run_snapshot.gd").new()
	snapshot.root_seed = _int64_or_zero(fields.get("root_seed", 0))
	snapshot.is_manual_seed = bool(fields.get("is_manual_seed", false))
	snapshot.meta_progression_eligible = bool(fields.get("meta_progression_eligible", true))
	snapshot.route_state = _dictionary_or_empty(fields.get("route_state", {}))
	snapshot.current_route_node_id = str(fields.get("current_route_node_id", ""))
	snapshot.revealed_route_node_ids = _string_array(fields.get("revealed_route_node_ids", []))
	snapshot.rng_streams = rng_snapshot
	# No board at a route choice: level_state stays empty (NOT a tactical-snapshot embed).
	snapshot.level_state = {}
	snapshot.profile_id = str(options.get("profile_id", "default"))
	snapshot.run_id = str(options.get("run_id", ""))
	# Story 7.1: ALSO populate the EXISTING top-level economy placeholder keys from the run's risk-economy (these were
	# inert 0/[] placeholders through Epic 6). This keeps the snapshot HUMAN-READABLE + lets an Epic-8 run-summary read
	# them WITHOUT a new top-level key (the 23-key gate stays green). The SOURCE OF TRUTH on resume is the NESTED copy
	# inside route_state (try_from_run_snapshot_fields reads that); these top-level fields are a read-only mirror.
	# RiskEconomyState models corruption as a single count + curses as a count (curse_count); the RunSnapshot.curses
	# array placeholder stays EMPTY in v0 (the curse-id LIST is Story 7.2's — 7.1 tracks only the count), so curses
	# is NOT populated here (the curse-id content does not exist yet). Only gold and corruption ARE mirrored.
	# oath_shards is the AWARDED meta count (Epic 8), NOT the eligibility gate, so it is INTENTIONALLY left at its 0
	# default here (v0 awards none); the eligibility gate rides meta_progression_eligible (already a top-level snapshot
	# field) + the nested economy.
	var economy: RiskEconomyState = source_run.risk_economy
	if economy != null:
		snapshot.gold = economy.gold
		snapshot.corruption = economy.corruption
	# Story 7.4 (AC2 — "the affinity is recorded in the level snapshot"): MIRROR the run's assigned affinities (node id ->
	# affinity id) into the EXISTING top-level `affinities` Dictionary placeholder (currently `{}` through Epic 6). This
	# reuses an EXISTING top-level snapshot key (the 7.1 reuse-the-placeholder save discipline — the 23-key gate stays
	# green, COUNT stays 23, NO new top-level key, NO migration). It is a READ-ONLY MIRROR: the SOURCE OF TRUTH is the
	# run's assigned_affinities dict (which rides the full RunState.to_dictionary()); the assignment is also a DETERMINISTIC
	# function of (root_seed, route position), so it is RE-DERIVABLE on resume (re-run assign_affinity for the node) even
	# though the route-position resume path (try_from_run_snapshot_fields) reconstructs the run with an EMPTY
	# assigned_affinities (only the economy + class id are nested route-position state). A normalized String->String copy
	# keeps the placeholder JSON-safe (node ids + affinity ids are short strings, never seeds).
	for node_id_key: Variant in source_run.assigned_affinities.keys():
		if node_id_key is String or node_id_key is StringName:
			snapshot.affinities[String(node_id_key)] = String(source_run.assigned_affinities[node_id_key])
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
