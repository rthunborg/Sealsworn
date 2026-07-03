extends "res://tests/unit/test_case.gd"

# Story 9.1 — the boss ENCOUNTER REQUEST + boss ARENA setup (Task 2/3, AC2/AC3). Covers: the BossEncounterRequest
# DTO validate() (the GenerationRequest-shape request boundary); the deterministic BossArenaBuilder arena snapshot
# (entrance / arena bounds / player start / boss-entity slot / finale constraints; a valid board snapshot through
# the STRICT BoardState.try_from_snapshot; a JSON round-trip); determinism (the SAME request -> a byte-identical
# arena); and the structured seed+phase+reason+diagnostics failure that does not corrupt state (AC3 — the
# GenerationResult error shape, NEVER a grid dump).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossArenaBuilder = preload("res://scripts/generation/boss/boss_arena_builder.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")

func run() -> Dictionary:
	_request_validates_a_wellformed_boss_request()
	_request_rejects_malformed_fields()
	_arena_build_succeeds_and_carries_the_required_fields()
	_arena_board_snapshot_is_a_valid_board_state()
	_arena_is_deterministic_for_the_same_request()
	_arena_payload_survives_a_json_round_trip()
	_arena_setup_failure_is_structured_and_carries_seed_phase_reason_diagnostics()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _valid_request(seed_value: int = 4242) -> BossEncounterRequest:
	return BossEncounterRequest.new(seed_value, &"node_7_0", BossEncounterRequest.BOSS_NODE_TYPE, BossEncounterRequest.BOSS_ENTITY_ID)


# ---- BossEncounterRequest.validate() -------------------------------------------------------------

func _request_validates_a_wellformed_boss_request() -> void:
	var request: BossEncounterRequest = _valid_request()
	assert_true(request.validate().succeeded, "A well-formed boss encounter request should validate.")
	assert_equal(request.arena_seed(), 4242, "arena_seed() returns the root seed (v0 identity).")
	assert_equal(String(request.boss_entity_id), "larval_avatar", "The default boss entity id is the reserved Larval Avatar slot.")


func _request_rejects_malformed_fields() -> void:
	# A negative root_seed is rejected.
	var bad_seed: BossEncounterRequest = BossEncounterRequest.new(-1, &"node_7_0")
	var seed_result: ActionResult = bad_seed.validate()
	assert_true(seed_result.is_error(), "A negative root_seed should be rejected.")
	assert_equal(seed_result.error_code, &"invalid_boss_encounter_request", "A bad request should use the stable code.")
	assert_equal(seed_result.metadata.get("field"), "root_seed", "The rejection should name the root_seed field.")

	# A HYPHENATED node id is rejected (the request node id must be lower_snake — the derived form).
	var bad_node: BossEncounterRequest = BossEncounterRequest.new(1, &"node-7-0")
	assert_true(bad_node.validate().is_error(), "A hyphenated node id should be rejected (must be lower_snake).")
	assert_equal(bad_node.validate().metadata.get("field"), "node_id", "The rejection should name the node_id field.")

	# A NON-boss node type is rejected (this request is only for the terminal boss node).
	var bad_type: BossEncounterRequest = BossEncounterRequest.new(1, &"node_7_0", &"combat")
	assert_true(bad_type.validate().is_error(), "A non-boss node type should be rejected.")
	assert_equal(bad_type.validate().metadata.get("field"), "node_type", "The rejection should name the node_type field.")

	# A non-lower_snake boss entity id is rejected.
	var bad_entity: BossEncounterRequest = BossEncounterRequest.new(1, &"node_7_0", BossEncounterRequest.BOSS_NODE_TYPE, &"Larval Avatar")
	assert_true(bad_entity.validate().is_error(), "A non-lower_snake boss entity id should be rejected.")
	assert_equal(bad_entity.validate().metadata.get("field"), "boss_entity_id", "The rejection should name the boss_entity_id field.")


# ---- BossArenaBuilder success (AC2) --------------------------------------------------------------

func _arena_build_succeeds_and_carries_the_required_fields() -> void:
	var result: GenerationResult = BossArenaBuilder.new().build(_valid_request())
	assert_false(result.is_error(), "A valid boss encounter request should build an arena: %s" % result.reason)
	assert_true(result.has_payload(), "A successful arena build should carry a payload.")

	var payload: Dictionary = result.payload
	# AC2: the level snapshot includes entrance, boss arena, player start, boss entity slot, finale constraints.
	assert_true(payload.has("board_snapshot"), "The arena payload must carry the board snapshot (the boss arena).")
	assert_true(payload.has("entrance"), "The arena payload must carry the entrance.")
	assert_true(payload.has("player_start"), "The arena payload must carry the player start.")
	assert_true(payload.has("boss_slot"), "The arena payload must carry the boss-entity slot.")
	assert_true(payload.has("finale_constraints"), "The arena payload must carry the finale constraints.")
	assert_true(payload.has("arena_seed"), "The arena payload must carry the arena seed (provenance).")
	# The arena_seed is DECIMAL-STRING encoded (the int64/JSON rule).
	assert_equal(payload.get("arena_seed"), "4242", "The arena_seed must be decimal-string encoded.")

	# The boss slot reserves the Larval Avatar id and is marked placeholder (9.2 fills the definition).
	var boss_slot: Dictionary = payload.get("boss_slot")
	assert_equal(boss_slot.get("entity_id"), "larval_avatar", "The boss slot must reserve the Larval Avatar entity id.")
	assert_true(bool(boss_slot.get("is_placeholder")), "The boss slot must be marked placeholder.")
	# The boss slot cell is distinct from the entrance/player start (opposite ends of the arena).
	var entrance: Dictionary = payload.get("entrance")
	assert_false(int(boss_slot.get("x")) == int(entrance.get("x")) and int(boss_slot.get("y")) == int(entrance.get("y")), "The boss slot must not sit on the entrance cell.")
	# The player start equals the entrance (the hero enters at the entrance).
	var player_start: Dictionary = payload.get("player_start")
	assert_equal(player_start, entrance, "The player start is the entrance cell.")


func _arena_board_snapshot_is_a_valid_board_state() -> void:
	var result: GenerationResult = BossArenaBuilder.new().build(_valid_request())
	var board_snapshot: Dictionary = result.payload.get("board_snapshot")

	# The board snapshot is a VALID BoardState through the STRICT try_from_snapshot (validate-then-reject).
	var board_result: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	assert_true(board_result.succeeded, "The arena board snapshot must be a valid BoardState: %s" % board_result.metadata)
	var board: BoardState = board_result.metadata.get("board") as BoardState
	assert_equal(board.width, BossArenaBuilder.ARENA_WIDTH, "The arena width should be the fixed footprint.")
	assert_equal(board.height, BossArenaBuilder.ARENA_HEIGHT, "The arena height should be the fixed footprint.")
	# No entities in the arena (the boss is a payload SLOT marker, not a board entity — 9.1 authors NO boss stats).
	assert_equal(board.entity_count(), 0, "The 9.1 boss arena must carry NO board entities (the boss is a slot marker).")

	# The entrance cell IS an ENTRANCE terrain; the border is WALL; the boss slot cell is walkable FLOOR.
	var entrance: Dictionary = result.payload.get("entrance")
	var entrance_cell: BoardCell = board.get_cell(Vector2i(int(entrance.get("x")), int(entrance.get("y"))))
	assert_equal(entrance_cell.terrain, BoardCell.Terrain.ENTRANCE, "The entrance cell must be ENTRANCE terrain.")
	# A corner is WALL (the border).
	var corner: BoardCell = board.get_cell(Vector2i(0, 0))
	assert_equal(corner.terrain, BoardCell.Terrain.WALL, "The arena border must be WALL.")
	var boss_slot: Dictionary = result.payload.get("boss_slot")
	var boss_cell: BoardCell = board.get_cell(Vector2i(int(boss_slot.get("x")), int(boss_slot.get("y"))))
	assert_equal(boss_cell.terrain, BoardCell.Terrain.FLOOR, "The boss slot cell must be walkable FLOOR (the boss is not stamped onto terrain).")


func _arena_is_deterministic_for_the_same_request() -> void:
	# The SAME (root_seed, boss node id) -> a byte-identical arena payload (AC2 determinism).
	var first: GenerationResult = BossArenaBuilder.new().build(_valid_request(2026))
	var second: GenerationResult = BossArenaBuilder.new().build(_valid_request(2026))
	assert_equal(JSON.stringify(first.payload), JSON.stringify(second.payload), "The same request must build a byte-identical arena payload.")


func _arena_payload_survives_a_json_round_trip() -> void:
	# The payload is PURE serializable data — never a live BoardState/RefCounted. It survives a JSON round-trip as
	# a Dictionary, and the round-tripped board snapshot still validates through the strict path (no data loss / no
	# live handle). NOTE: a raw byte-identity re-stringify comparison is NOT valid across the JSON boundary — nested
	# ints (terrain/x/y/bounds) decode as floats (JSON has one number type), the documented int-coercion footgun; so
	# fidelity is proven by the string keys/values surviving + a strict re-validation, not JSON.stringify equality.
	var result: GenerationResult = BossArenaBuilder.new().build(_valid_request())
	var payload: Dictionary = result.payload
	var round_trip: Variant = JSON.parse_string(JSON.stringify(payload))
	assert_true(round_trip is Dictionary, "The arena payload must survive a JSON round-trip as a Dictionary.")
	var reparsed_payload: Dictionary = round_trip
	# The stable string fields survive verbatim (no truncation / no key loss).
	assert_equal(reparsed_payload.get("arena_seed"), "4242", "The arena_seed string must survive the JSON round-trip.")
	assert_equal(reparsed_payload.get("boss_node_id"), "node_7_0", "The boss_node_id must survive the JSON round-trip.")
	assert_equal((reparsed_payload.get("boss_slot") as Dictionary).get("entity_id"), "larval_avatar", "The boss slot entity id must survive the JSON round-trip.")
	# The round-tripped board snapshot still validates through the strict path (no live handle lost, no int-coercion
	# corruption — try_from_snapshot's integral-field check tolerates the float-encoded ints).
	var reparsed: BoardState = BoardState.from_snapshot(reparsed_payload.get("board_snapshot"))
	assert_true(reparsed != null, "The round-tripped arena board snapshot must still parse into a valid BoardState.")
	assert_equal(reparsed.width, BossArenaBuilder.ARENA_WIDTH, "The round-tripped arena width must survive.")
	assert_equal(reparsed.entity_count(), 0, "The round-tripped arena must still carry no entities.")


# ---- BossArenaBuilder failure (AC3) --------------------------------------------------------------

func _arena_setup_failure_is_structured_and_carries_seed_phase_reason_diagnostics() -> void:
	# A boss setup that fails validation (an invalid request — e.g. a hyphenated node id that slips past a caller)
	# returns a STRUCTURED GenerationResult carrying seed + phase + reason + compact diagnostics (NEVER a grid
	# dump). The builder validates the request BEFORE building anything, so no partial arena is produced.
	var bad_request: BossEncounterRequest = BossEncounterRequest.new(1234, &"node-7-0")  # hyphenated -> invalid
	var result: GenerationResult = BossArenaBuilder.new().build(bad_request)
	assert_true(result.is_error(), "A boss setup with an invalid request must fail loud.")
	# Structured error shape: a known PHASE_*, a stable code, a reason, the seed, and compact diagnostics.
	assert_true(GenerationResult.is_known_phase(result.failed_phase), "The failure must report a known generation phase.")
	assert_equal(result.failed_phase, GenerationResult.PHASE_VALIDATION, "An invalid-request failure reports the VALIDATION phase.")
	assert_equal(result.error_code, &"invalid_boss_encounter_request", "The failure should use the stable boss-request error code.")
	assert_false(String(result.reason).is_empty(), "The failure must carry a reason.")
	assert_equal(result.seed, "1234", "The failure must carry the request seed (string-encoded).")
	# Compact diagnostics — a small dict of counts/coords/fields, NEVER a full terrain grid.
	assert_true(result.diagnostics.has("field"), "The failure diagnostics should name the offending field (compact).")
	assert_false(result.diagnostics.has("terrain_grid"), "The failure diagnostics must NEVER dump the terrain grid.")
	assert_false(result.diagnostics.has("cells"), "The failure diagnostics must NEVER dump the board cells.")
	# The result carries NO payload (no partial arena on failure — the run is not left in a broken boss state).
	assert_false(result.has_payload(), "A failed boss setup must carry NO payload (no partial arena).")

	# A null request also fails structurally (defensive — never a crash).
	var null_result: GenerationResult = BossArenaBuilder.new().build(null)
	assert_true(null_result.is_error(), "A null request must fail structurally, not crash.")
	assert_equal(null_result.failed_phase, GenerationResult.PHASE_VALIDATION, "A null request reports the VALIDATION phase.")
