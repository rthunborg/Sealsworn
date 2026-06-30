extends "res://tests/unit/test_case.gd"

# Story 7.4 Task 3 — the deterministic affinity ASSIGNMENT (RunOrchestrator.assign_affinity, AC2). The FIRST 7.x draw
# that is route-structure-level (drawn on the `map` stream). Pins:
#   - ASSIGN SELECTS a deterministic affinity through the RUN-LEVEL RngStreamSet on the named `map` stream
#     (metadata.stream_name == "map"; the selected id is a real baseline affinity id; it is RECORDED on
#     RunState.assigned_affinities keyed by node id);
#   - NAMED-STREAM ISOLATION (the 7.1 retro caution): ONLY the `map` stream advances its draw_index for an assignment —
#     events / rewards / loot / level / combat / cosmetic stay unchanged (the affinity draw must NOT perturb them);
#   - SAME seed + same route position reproduces a byte-identical assignment; re-run twice -> identical;
#   - the affinity is RECORDED in the level snapshot (the run's assigned_affinities + the mirrored top-level
#     RunSnapshot.affinities) and reproducibly readable; a run whose assignment was recorded survives a real-repository
#     route-position resume via the mirror (and is re-derivable from the seed);
#   - the neutral `none` is a selectable assignment outcome; assigned_affinity_for defaults to `none` for an
#     un-assigned node (the AC3 no-affinity default);
#   - fail-closed: a null/empty-id node, an empty repository, an unseated orchestrator.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

const SAVE_PATH := "user://test_affinity_assignment_save.json"
const SEED_SAMPLE: Array[int] = [1, 7, 42, 99, 2026]

func run() -> Dictionary:
	_assign_selects_a_deterministic_affinity_through_the_map_stream()
	_assign_advances_only_the_map_stream()
	_same_seed_same_node_reproduces_an_identical_assignment()
	_assign_records_the_affinity_in_the_snapshot_and_route_position_save()
	_assignment_is_re_derivable_from_the_seed_after_resume()
	_neutral_none_is_a_selectable_outcome()
	_assigned_affinity_for_defaults_to_none_for_an_unassigned_node()
	_assigned_affinity_round_trips_through_the_full_run_dict()
	_populated_affinities_keeps_the_23_key_gate()
	_a_pre_7_4_save_still_restores()
	_invalid_node_fails_closed()
	_empty_repository_fails_closed()
	_unseated_orchestrator_fails_closed()
	_cleanup()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _started(seed_value: int) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(seed_value, false).succeeded, "Seed %d: start should succeed." % seed_value)
	return orchestrator


func _first_node(orchestrator: RunOrchestrator) -> RouteNode:
	var nodes: Array[RouteNode] = orchestrator.run.route.nodes()
	assert_true(nodes.size() >= 1, "A started run must have at least one route node.")
	return nodes[0]


func _write_through_repository(snapshot: RunSnapshot) -> void:
	var write_result: ActionResult = SaveRepository.new().write_run_snapshot(snapshot, SAVE_PATH)
	assert_true(write_result.succeeded, "Writing the route-position snapshot should succeed: %s" % write_result.metadata)


func _draw_index_for(orchestrator: RunOrchestrator, stream_name: String) -> int:
	var snapshot: Dictionary = orchestrator.streams.to_snapshot()
	var stream: Dictionary = (snapshot.get("streams") as Dictionary).get(stream_name)
	return int(stream.get("draw_index"))


# ---- AC2: deterministic assign through the map stream --------------------------------------------

func _assign_selects_a_deterministic_affinity_through_the_map_stream() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	var node: RouteNode = _first_node(orchestrator)
	var assign: ActionResult = orchestrator.assign_affinity(node)
	assert_true(assign.succeeded, "Assigning an affinity should succeed: %s" % assign.metadata)
	# The draw used the named map stream.
	assert_equal(String(assign.metadata.get("stream_name")), "map", "The affinity draw must use the named map stream.")
	# The selected affinity is a real baseline affinity id.
	var assigned_id: StringName = StringName(String(assign.metadata.get("affinity_id")))
	assert_true(AffinityRepository.BASELINE_AFFINITY_IDS.has(assigned_id), "The assigned affinity must be a real baseline affinity id.")
	# It was RECORDED on RunState.assigned_affinities keyed by node id.
	assert_true(orchestrator.run.assigned_affinities.has(String(node.id)), "The assigned affinity must be recorded on the run keyed by node id.")
	assert_equal(String(orchestrator.run.assigned_affinities.get(String(node.id))), String(assigned_id), "The recorded affinity id must match the selected id.")
	# assigned_affinity_for reads it back.
	assert_equal(orchestrator.assigned_affinity_for(String(node.id)), assigned_id, "assigned_affinity_for must read back the recorded affinity.")


func _assign_advances_only_the_map_stream() -> void:
	# NAMED-STREAM ISOLATION (the 7.1 retro caution): the affinity assignment draws the `map` stream ONLY. The `map`
	# stream was ALREADY advanced by RouteGenerator at run start, so capture its pre-assign index and assert it advances
	# by exactly 1, while every OTHER stream stays unchanged.
	var orchestrator: RunOrchestrator = _started(2026)
	var node: RouteNode = _first_node(orchestrator)
	var map_before: int = _draw_index_for(orchestrator, "map")
	var others_before: Dictionary = {}
	for other_stream: String in ["events", "rewards", "loot", "level", "combat", "cosmetic"]:
		others_before[other_stream] = _draw_index_for(orchestrator, other_stream)
	assert_true(orchestrator.assign_affinity(node).succeeded, "The affinity assign should succeed.")
	# ONLY the map stream advanced (by exactly 1).
	assert_equal(_draw_index_for(orchestrator, "map"), map_before + 1, "The affinity assignment must ADVANCE the map stream by exactly 1.")
	for other_stream: String in ["events", "rewards", "loot", "level", "combat", "cosmetic"]:
		assert_equal(_draw_index_for(orchestrator, other_stream), int(others_before[other_stream]), "The affinity assignment must NOT advance the %s stream (named-stream isolation)." % other_stream)


func _same_seed_same_node_reproduces_an_identical_assignment() -> void:
	for seed_value: int in SEED_SAMPLE:
		var a: RunOrchestrator = _started(seed_value)
		var b: RunOrchestrator = _started(seed_value)
		var node_a: RouteNode = _first_node(a)
		var node_b: RouteNode = _first_node(b)
		# The route is a pure function of the seed, so the first node id matches across the two runs.
		assert_equal(node_a.id, node_b.id, "Seed %d: the first route node id must match across two runs (route is seed-deterministic)." % seed_value)
		var assign_a: ActionResult = a.assign_affinity(node_a)
		var assign_b: ActionResult = b.assign_affinity(node_b)
		assert_true(assign_a.succeeded and assign_b.succeeded, "Seed %d: both assignments should succeed." % seed_value)
		assert_equal(
			String(assign_a.metadata.get("affinity_id")),
			String(assign_b.metadata.get("affinity_id")),
			"Seed %d: the same seed + same route position must reproduce an identical assigned affinity." % seed_value
		)


# ---- AC2: recorded in the level snapshot + the route-position save ---------------------------------

func _assign_records_the_affinity_in_the_snapshot_and_route_position_save() -> void:
	var orchestrator: RunOrchestrator = _started(2026)
	var node: RouteNode = _first_node(orchestrator)
	var assign: ActionResult = orchestrator.assign_affinity(node)
	assert_true(assign.succeeded, "The assign should succeed for the snapshot proof.")
	var assigned_id: String = String(assign.metadata.get("affinity_id"))

	# The composed route-position snapshot MIRRORS the recorded affinity into the top-level affinities placeholder.
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	assert_true(snapshot != null, "compose_route_position_snapshot should return a snapshot after an assignment.")
	assert_true(snapshot.affinities.has(String(node.id)), "AC2: the snapshot's affinities placeholder must carry the assigned affinity keyed by node id.")
	assert_equal(String(snapshot.affinities.get(String(node.id))), assigned_id, "AC2: the mirrored affinity id must match the assigned id.")

	# The mirror survives a real JSON round-trip through the snapshot parse (the affinities placeholder is a top-level key).
	var parsed: ActionResult = RunSnapshot.parse(JSON.parse_string(JSON.stringify(snapshot.to_dictionary())))
	assert_true(parsed.succeeded, "The snapshot with a populated affinities placeholder should parse after JSON: %s" % parsed.metadata)
	var parsed_snapshot: RunSnapshot = parsed.metadata.get("snapshot")
	assert_equal(String(parsed_snapshot.affinities.get(String(node.id))), assigned_id, "AC2: the affinity must be reproducibly readable from the parsed snapshot.")

	# It also survives a write + read through the REAL repository (the route-position save path).
	_write_through_repository(snapshot)
	var read_back: ActionResult = SaveRepository.new().read_run_snapshot(SAVE_PATH)
	assert_true(read_back.succeeded, "Reading the route-position snapshot back should succeed: %s" % read_back.metadata)
	var read_snapshot: RunSnapshot = read_back.metadata.get("snapshot")
	assert_equal(String(read_snapshot.affinities.get(String(node.id))), assigned_id, "AC2: the affinity must round-trip through the real save repository.")


func _assignment_is_re_derivable_from_the_seed_after_resume() -> void:
	# The recorded affinity is NOT the route-position resume's source of truth: the resume reconstructs the run with an
	# EMPTY assigned_affinities (only the economy + class id are nested route-position state). The recorded affinity
	# survives ONLY via (a) the top-level RunSnapshot.affinities MIRROR (read-back below) and (b) being RE-DERIVABLE from
	# the seed. RE-DERIVE means: a FRESH run at the SAME seed (which reproduces the run-start `map`-stream state — the
	# pre-assign state S0) re-runs assign_affinity for the same node and gets the SAME id. (Re-running on the RESUMED run
	# would draw from the POST-assign state S1 — the save persists the advanced stream — so a resumer must re-derive from
	# the run-start state, NOT by re-drawing the already-advanced resumed stream. This is the 5.3 re-derive-from-seed
	# class.)
	var orchestrator: RunOrchestrator = _started(99)
	var node: RouteNode = _first_node(orchestrator)
	var original: ActionResult = orchestrator.assign_affinity(node)
	assert_true(original.succeeded, "The original assignment should succeed.")
	var original_id: String = String(original.metadata.get("affinity_id"))

	# Compose + persist the route-position save AFTER the assignment, then resume it.
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	_write_through_repository(snapshot)
	var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(restore.succeeded, "Resuming the post-assignment route position should succeed: %s" % restore.metadata)
	var restored_run = restore.metadata.get("run_state")
	assert_true(restored_run != null, "The route-position resume should return the run_state.")
	# The resumed run carries NO assigned_affinities (it is NOT the route-position resume's source of truth).
	assert_equal(restored_run.assigned_affinities, {}, "The route-position resume reconstructs the run with an empty assigned_affinities (not the resume source of truth).")
	# The recorded affinity DID survive via the top-level mirror in the persisted snapshot.
	assert_equal(String(snapshot.affinities.get(String(node.id))), original_id, "The recorded affinity survives via the top-level RunSnapshot.affinities mirror.")

	# RE-DERIVE from the seed: a FRESH run at the same seed reproduces the run-start map-stream state, so re-running the
	# assignment for the same node yields the SAME id (the assignment is a pure function of (root_seed, route position)).
	var fresh: RunOrchestrator = _started(99)
	var fresh_node: RouteNode = _first_node(fresh)
	assert_equal(fresh_node.id, node.id, "The fresh run's first node id must match (route is seed-deterministic).")
	var re_derived: ActionResult = fresh.assign_affinity(fresh_node)
	assert_true(re_derived.succeeded, "Re-deriving the assignment from a fresh run at the seed should succeed.")
	assert_equal(String(re_derived.metadata.get("affinity_id")), original_id, "The re-derived affinity (fresh run, same seed) must match the original — assignment is reproducible from the seed + route position.")


func _neutral_none_is_a_selectable_outcome() -> void:
	# AC3 / neutral-selectability proof — the neutral `none` is a REAL selectable assignment outcome, like any other
	# affinity. Proven two ways, NEITHER relying on the incidental hit rate of the live route-gen sequence (the Round-1
	# review fold-in: a probabilistic "does `none` land within a fixed 20-seed sample" check passes only by a 2/20 margin
	# and a future legitimate map-stream / candidate-count change could drop both hits and fail the suite for an unrelated
	# reason). Both proofs here are DIRECT + deterministic and fail LOUD with a correctly-attributed message on a miss.
	#
	# PROOF 1 (direct, seed-independent) — a single-candidate (`none`-only) affinity repository. With exactly one candidate
	# the assignment draws rand_int(map, 0, 0, ...) == 0 and MUST select `none` for EVERY seed (the only thing it can pick).
	# This proves `none` is a fully selectable outcome of assign_affinity with NO dependence on the route-gen draw value.
	var none_only_repository: AffinityRepository = AffinityRepository.create_repository_from_definitions(
		[AffinityDefinition.neutral()]
	)
	assert_true(none_only_repository != null, "Setup: the single-candidate `none`-only repository should build.")
	for seed_value: int in SEED_SAMPLE:
		var orchestrator: RunOrchestrator = RunOrchestrator.new(null, null, null, null, null, none_only_repository)
		assert_true(orchestrator.start(seed_value, false).succeeded, "Seed %d: start with the `none`-only repo should succeed." % seed_value)
		var node: RouteNode = _first_node(orchestrator)
		var assign: ActionResult = orchestrator.assign_affinity(node)
		assert_true(assign.succeeded, "Seed %d: assigning from the `none`-only repo should succeed: %s" % [seed_value, assign.metadata])
		assert_equal(
			String(assign.metadata.get("affinity_id")),
			String(AffinityDefinition.AFFINITY_NONE),
			"Seed %d: a single-candidate `none`-only repository MUST select the neutral `none` (proving `none` is a selectable outcome)." % seed_value
		)
		assert_true(bool(assign.metadata.get("is_neutral")), "Seed %d: an assigned `none` must report is_neutral == true." % seed_value)
		assert_equal(String(orchestrator.run.assigned_affinities.get(String(node.id))), String(AffinityDefinition.AFFINITY_NONE), "Seed %d: the recorded id must be `none`." % seed_value)

	# PROOF 2 (bounded-seed search over the REAL baseline, fail-LOUD on miss) — `none` is one of the FULL baseline
	# candidates, so it is reachable from the default repository via the route-gen-driven draw too. Search a bounded seed
	# range for the FIRST seed whose assignment lands on `none` and STOP at the first hit; if the whole bounded range
	# misses, FAIL with a clear message that names the real cause (none-unreachable-in-range) rather than passing by luck
	# (the 6.7 bounded-seed-search pattern). This preserves the original test's intent — neutral is selectable from the
	# full baseline alongside the other affinities — without the brittle 2/20-margin coupling.
	var none_seen_from_baseline: bool = false
	for seed_value: int in range(1, 201):
		var orchestrator: RunOrchestrator = _started(seed_value)
		var node: RouteNode = _first_node(orchestrator)
		var assign: ActionResult = orchestrator.assign_affinity(node)
		assert_true(assign.succeeded, "Seed %d: assign from the full baseline should succeed." % seed_value)
		if String(assign.metadata.get("affinity_id")) == String(AffinityDefinition.AFFINITY_NONE):
			assert_true(bool(assign.metadata.get("is_neutral")), "Seed %d: an assigned `none` must report is_neutral == true." % seed_value)
			none_seen_from_baseline = true
			break
	assert_true(none_seen_from_baseline, "The neutral `none` must be a selectable assignment outcome from the full baseline within seeds 1..200 (it is one of the %d baseline candidates); a miss here means `none` is NOT reachable in range, NOT that the test is flaky." % AffinityRepository.BASELINE_AFFINITY_IDS.size())


func _assigned_affinity_for_defaults_to_none_for_an_unassigned_node() -> void:
	# AC3 no-affinity default: a node with NO assigned affinity reads back as the neutral `none` id.
	var orchestrator: RunOrchestrator = _started(42)
	assert_equal(orchestrator.assigned_affinity_for("node-never-assigned"), AffinityDefinition.AFFINITY_NONE, "An unassigned node reads back as the neutral none id (AC3 no-affinity default).")


func _assigned_affinity_round_trips_through_the_full_run_dict() -> void:
	# The assigned_affinities record rides the FULL RunState.to_dictionary()/try_from_dictionary (lenient back-compat).
	var orchestrator: RunOrchestrator = _started(7)
	var node: RouteNode = _first_node(orchestrator)
	assert_true(orchestrator.assign_affinity(node).succeeded, "The assign should succeed for the run-dict round-trip.")
	var assigned_id: String = String(orchestrator.run.assigned_affinities.get(String(node.id)))

	var round_tripped = orchestrator.run.from_dictionary(JSON.parse_string(JSON.stringify(orchestrator.run.to_dictionary())))
	assert_true(round_tripped != null, "The run dict with assigned affinities should parse after JSON.")
	assert_equal(String(round_tripped.assigned_affinities.get(String(node.id))), assigned_id, "The assigned affinity must round-trip through the full run dict.")

	# A pre-7.4 run dict (no assigned_affinities key) still parses to a fresh empty dict (lenient back-compat).
	var legacy_dict: Dictionary = orchestrator.run.to_dictionary()
	legacy_dict.erase("assigned_affinities")
	var legacy_run = orchestrator.run.from_dictionary(legacy_dict)
	assert_true(legacy_run != null, "A pre-7.4 run dict with no assigned_affinities key must still parse (lenient back-compat).")
	assert_equal(legacy_run.assigned_affinities, {}, "A pre-7.4 run dict parses to an empty assigned_affinities dict.")


# ---- the 23-key gate + back-compat ---------------------------------------------------------------

func _populated_affinities_keeps_the_23_key_gate() -> void:
	# AC2 / Task 6 fence: populating the EXISTING top-level `affinities` placeholder adds NO new top-level key — the
	# 23-key RunSnapshot no-surprise-key COUNT stays exactly 23 (the `affinities` key already exists; populating it is
	# not adding one).
	var orchestrator: RunOrchestrator = _started(42)
	var node: RouteNode = _first_node(orchestrator)
	assert_true(orchestrator.assign_affinity(node).succeeded, "The assign should succeed for the 23-key gate proof.")
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	assert_false(snapshot.affinities.is_empty(), "Setup: the snapshot's affinities placeholder must be populated.")
	var data: Dictionary = snapshot.to_dictionary()
	assert_equal(data.keys().size(), 23, "AC2: a RunSnapshot with a POPULATED affinities placeholder must still have exactly 23 top-level keys (no new key).")
	assert_true(data.has("affinities"), "The populated affinities placeholder rides the EXISTING top-level affinities key.")


func _a_pre_7_4_save_still_restores() -> void:
	# Back-compat: a pre-7.4 save with affinities == {} (the inert placeholder through Epic 6) still parses + restores
	# cleanly — NO migration step (the lenient-decode discipline).
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.root_seed = 4242
	assert_equal(snapshot.affinities, {}, "Setup: a fresh snapshot's affinities placeholder defaults to {}.")
	var data: Dictionary = snapshot.to_dictionary()
	# Simulate a pre-7.4 save: the affinities key is present-but-empty (the historical inert placeholder).
	var parsed: ActionResult = RunSnapshot.parse(JSON.parse_string(JSON.stringify(data)))
	assert_true(parsed.succeeded, "A pre-7.4 save (affinities == {}) must still parse: %s" % parsed.metadata)
	assert_equal((parsed.metadata.get("snapshot") as RunSnapshot).affinities, {}, "A pre-7.4 save restores with an empty affinities placeholder (no migration).")


# ---- fail-closed ---------------------------------------------------------------------------------

func _invalid_node_fails_closed() -> void:
	var orchestrator: RunOrchestrator = _started(42)
	var map_before: int = _draw_index_for(orchestrator, "map")
	var null_node: ActionResult = orchestrator.assign_affinity(null)
	assert_true(null_node.is_error(), "Assigning to a null node must fail closed.")
	assert_equal(null_node.error_code, &"invalid_affinity_node", "A null node should use the stable invalid_affinity_node code.")
	# An empty-id node also fails closed.
	var empty_node: RouteNode = RouteNode.new()
	var empty_result: ActionResult = orchestrator.assign_affinity(empty_node)
	assert_true(empty_result.is_error(), "Assigning to an empty-id node must fail closed.")
	assert_equal(empty_result.error_code, &"invalid_affinity_node", "An empty-id node should use the stable invalid_affinity_node code.")
	# A failed assign (pre-draw reject) draws NO RNG (the map stream stays put).
	assert_equal(_draw_index_for(orchestrator, "map"), map_before, "A failed assign (invalid node, pre-draw reject) draws NO RNG.")


func _empty_repository_fails_closed() -> void:
	# An empty affinity repository (no candidates) fails closed with no_affinities_available.
	var empty_repository: AffinityRepository = AffinityRepository.new()
	var orchestrator: RunOrchestrator = RunOrchestrator.new(null, null, null, null, null, empty_repository)
	assert_true(orchestrator.start(42, false).succeeded, "Start with an injected empty affinity repo should succeed.")
	var node: RouteNode = _first_node(orchestrator)
	var rejected: ActionResult = orchestrator.assign_affinity(node)
	assert_true(rejected.is_error(), "Assigning from an empty affinity repository must fail closed.")
	assert_equal(rejected.error_code, &"no_affinities_available", "An empty repository should use the stable no_affinities_available code.")
	assert_false(orchestrator.run.assigned_affinities.has(String(node.id)), "A failed assign must record NO affinity (no fabricated default).")


func _unseated_orchestrator_fails_closed() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var node: RouteNode = RouteNode.new()
	var rejected: ActionResult = orchestrator.assign_affinity(node)
	assert_true(rejected.is_error(), "Assigning on an unseated orchestrator must fail closed.")
	assert_equal(rejected.error_code, &"no_active_run", "An unseated orchestrator should use the stable no_active_run code.")


func _cleanup() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
