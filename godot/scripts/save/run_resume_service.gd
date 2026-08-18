class_name RunResumeService
extends RefCounted

# Domain-side resume service (Story 2.8). Composes the existing restore primitives into the
# inverse of the Story 2.7 between-level WRITE path, returning the restored domain pieces via a
# structured ActionResult. This is a pure READ: it executes no commands, advances no turns, draws
# no gameplay RNG, and mutates neither the source state nor the save file. try_restore /
# try_from_snapshot build NEW objects.
#
# Restore order (each step propagates the FIRST error verbatim, exposing NO partial state — this
# is AC2's "no partial corrupt state becomes active" guarantee):
#   1. SaveRepository.read_run_snapshot(save_path)
#        -> save_not_found / save_open_failed / save_parse_failed, or RunSnapshot.parse(...)
#           (lenient run-level parse; rejects only unsupported_save_schema)
#   2. RunSnapshot.try_tactical_snapshot()
#        -> STRICT TacticalSnapshot.parse of the embedded payload
#           (invalid_tactical_snapshot / missing_tactical_snapshot)
#   3. BoardState.try_from_snapshot(tactical.board)
#        -> strict board restore (fog flags, occupancy consistency)
#   4. RngStreamSet.new(0).try_restore(run_snapshot.rng_streams)
#        -> invalid_rng_snapshot on malformed input; no mutation on failure
#
# RNG authority decision (Story 2.7 retro): the run-level RunSnapshot.rng_streams is the
# authoritative between-level RNG state on resume; the embedded tactical rng_streams reflects
# in-level stream state at level exit. At a between-level boundary they are EQUAL by construction
# (from_between_level writes both from one streams.to_snapshot() read). This service restores the
# RUN-LEVEL streams as the live gameplay streams. A test asserts run-level == embedded-tactical for
# a between-level save (closes a Story 2.7 deferred item).
#
# AC1 "presentation rebuilds from restored state, not saved scene nodes": the service returns ONLY
# domain objects (RunSnapshot / TacticalSnapshot / BoardState / RngStreamSet). No scene node is
# ever serialized into the save or returned here. A later UI story binds a presenter/view model to
# this restored domain state.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

# Resume the current-run autosave from save_path. On success returns ActionResult.ok with the
# restored domain pieces under metadata keys: run_snapshot, tactical_snapshot, board, rng_streams.
# On any failure returns the FIRST validator's structured error (stable lower-snake error_code +
# diagnostic metadata) carrying NO restored domain objects.
func resume(save_path: String = SaveRepository.DEFAULT_RUN_PATH) -> ActionResult:
	var read_result: ActionResult = SaveRepository.new().read_run_snapshot(save_path)
	if read_result.is_error():
		return read_result
	var run_snapshot: RunSnapshot = read_result.metadata.get("snapshot") as RunSnapshot

	# Route the embedded tactical payload through the STRICT TacticalSnapshot.parse (NOT the lenient
	# run-level parse). The lenient run-level parse is intentionally forward-compat for run fields;
	# trusting it alone could "restore" a corrupt board into a broken shape — exactly what AC2 forbids.
	var tactical_result: ActionResult = run_snapshot.try_tactical_snapshot()
	if tactical_result.is_error():
		return tactical_result
	var tactical: TacticalSnapshot = tactical_result.metadata.get("snapshot") as TacticalSnapshot

	var board_result: ActionResult = BoardState.try_from_snapshot(tactical.board)
	if board_result.is_error():
		return board_result
	var board: BoardState = board_result.metadata.get("board") as BoardState

	# Run-level rng_streams is the between-level authority (Story 2.7 retro decision). try_restore
	# does not mutate on failure and consumes no draws.
	var streams: RngStreamSet = RngStreamSet.new(0)
	var rng_result: ActionResult = streams.try_restore(run_snapshot.rng_streams)
	if rng_result.is_error():
		return rng_result

	return ActionResult.ok([], {
		"run_snapshot": run_snapshot,
		"tactical_snapshot": tactical,
		"board": board,
		"rng_streams": streams
	})


# Resume a board-FREE ROUTE-POSITION save (Story 4.6 Task 4.2) — the inverse of
# RunSnapshot.from_route_position. This is the resume path for a between-NODE boundary (the player parked at a
# route CHOICE), which has NO embedded tactical snapshot (so the board-centric resume() above does not fit).
# It does NOT require a TacticalSnapshot; it rebuilds the run-progression state directly.
#
# Restore order (each step propagates the FIRST error verbatim, exposing NO partial state — the same Epic-2
# no-partial-corrupt-state discipline as resume()):
#   1. SaveRepository.read_run_snapshot(save_path)  -> save_not_found / save_open_failed / save_parse_failed,
#        or RunSnapshot.parse(...) (lenient run-level parse; rejects only unsupported_save_schema)
#   2. RunState.try_from_run_snapshot_fields(...)    -> rebuild a RunState from the run/route fields (nested
#        run_phase + the top-level pointer cross-check + the phaseless->NEW_RUN default; structural validate())
#   3. RngStreamSet.new(0).try_restore(run_snapshot.rng_streams) -> invalid_rng_snapshot on malformed input;
#        no mutation on failure
#   4. Symmetric seed cross-check -> route_position_seed_mismatch when the top-level root_seed diverges from
#        rng_streams.root_seed (mirrors the compose-side from_route_position guard; rejects a hand-edited save)
#
# On success returns ok with the restored domain pieces under metadata keys: run_snapshot, run_state,
# rng_streams. On any failure returns the FIRST validator's structured error carrying NO restored objects.
# This is a pure read: it executes no commands, advances no turns, draws no gameplay RNG, and mutates neither
# the source state nor the save file.
func resume_route_position(save_path: String = SaveRepository.DEFAULT_RUN_PATH) -> ActionResult:
	var read_result: ActionResult = SaveRepository.new().read_run_snapshot(save_path)
	if read_result.is_error():
		return read_result
	var run_snapshot: RunSnapshot = read_result.metadata.get("snapshot") as RunSnapshot

	# Rebuild the RunState from the run/route snapshot fields (the existing 4.1/4.4 bridge — it reads the
	# nested run_phase, cross-checks the canonical top-level current_route_node_id, and validates structure).
	# The parsed RunSnapshot exposes exactly the fields to_run_snapshot_fields() produces.
	var run_fields: Dictionary = {
		"root_seed": run_snapshot.root_seed,
		"is_manual_seed": run_snapshot.is_manual_seed,
		"meta_progression_eligible": run_snapshot.meta_progression_eligible,
		"route_state": run_snapshot.route_state,
		"current_route_node_id": run_snapshot.current_route_node_id,
		"revealed_route_node_ids": run_snapshot.revealed_route_node_ids
	}
	var run_result: ActionResult = RunState.try_from_run_snapshot_fields(run_fields)
	if run_result.is_error():
		return run_result
	var run_state: RunState = run_result.metadata.get("run_state") as RunState

	# Story 15.4 (Review D2) — RESTORE the entered node's ASSIGNED AFFINITY from the snapshot's top-level `affinities`
	# mirror (RunSnapshot.from_route_position writes it; run_snapshot.gd:281-283). try_from_run_snapshot_fields
	# rebuilds the run with an EMPTY assigned_affinities (only the class id + economy nest under route_state), so
	# WITHOUT this a mid-fight quit -> resume -> re-enter re-runs assign_affinity — a SECOND `map`-stream draw that
	# can REROLL the un-cleared room's hazard (quit-scum across scorched/flooded_conductive/cursed/darkness/none) AND
	# drifts the `map` stream one draw ahead of an uninterrupted run. Restoring the recorded assignment makes the
	# assign-if-absent guard (run_orchestrator.gd:1008/1167) SKIP the draw for the recorded room, so resume re-enters
	# the SAME room and the `map` stream takes NO extra draw. FINGERPRINT-SAFE: the hands-off auto-resolve driver
	# NEVER assigns affinity (run_orchestrator.gd:701-705 — assign_affinity is off _resolve_combat/run_to_completion),
	# so no pinned fingerprint reads assigned_affinities. A pure read; ZERO RNG. Story 15.4 Review D4 completed that guard
	# to a PRESENCE check (`not run.assigned_affinities.has(...)`), so a node whose recorded affinity is the neutral `none`
	# is now RESTORED and recognised as ALREADY ASSIGNED: re-entry reads the recorded `none` back and takes NO extra `map`
	# draw (no reroll), exactly like the four hazard affinities — a restored `none` entry now behaves DIFFERENTLY from an
	# absent one (present -> skip; absent -> assign). The in-node fight stays ephemeral, the mid-encounter-save defer is
	# NOT reopened, and the 23-key gate stays 23 — `affinities` is an existing key.
	run_state.assigned_affinities = _restored_assigned_affinities(run_snapshot.affinities)

	# Run-level rng_streams is the resume RNG authority. try_restore does not mutate on failure and consumes
	# no draws.
	var streams: RngStreamSet = RngStreamSet.new(0)
	var rng_result: ActionResult = streams.try_restore(run_snapshot.rng_streams)
	if rng_result.is_error():
		return rng_result

	# Symmetric READ-side seed cross-check (mirrors the compose-side guard in RunSnapshot.from_route_position).
	# The RunState was rebuilt from the top-level root_seed and the RngStreamSet from rng_streams.root_seed
	# INDEPENDENTLY (try_from_run_snapshot_fields never sees rng_streams), so a hand-edited / corrupted save
	# whose top-level root_seed diverges from rng_streams.root_seed would otherwise restore SILENTLY (a subtle
	# determinism divergence on the first post-resume draw, no crash). The compose side now guarantees the game
	# never writes such a save; reject one here with a structured error (NO partial state) so the resume seam
	# fails loud rather than trusting two independently-sourced seeds.
	if str(run_snapshot.root_seed) != str(streams.to_snapshot().get("root_seed")):
		return ActionResult.error(&"route_position_seed_mismatch", {
			"field": "root_seed",
			"run_root_seed": str(run_snapshot.root_seed),
			"streams_root_seed": str(streams.to_snapshot().get("root_seed"))
		})

	return ActionResult.ok([], {
		"run_snapshot": run_snapshot,
		"run_state": run_state,
		"rng_streams": streams
	})


# Story 15.4 (Review D2) — normalize the snapshot's top-level `affinities` mirror (node id -> affinity id) into a
# fresh String->String dict for RunState.assigned_affinities on resume. Defensive against a hand-edited save: only
# string-like keys survive, values are coerced to String. Anything not a Dictionary -> an empty dict (a pre-7.4 /
# affinity-less save restores no assignments, unchanged). Draws no RNG, mutates nothing.
static func _restored_assigned_affinities(affinities: Variant) -> Dictionary:
	var result: Dictionary = {}
	if affinities is Dictionary:
		for key: Variant in (affinities as Dictionary).keys():
			if key is String or key is StringName:
				result[String(key)] = String((affinities as Dictionary)[key])
	return result
