extends "res://tests/unit/test_case.gd"

# Story 4.2 — `map`-seed route regression fixtures (AC2).
#
# Pins a small set of APPROVED root-seed fixtures to a stable route fingerprint. For each seed: generate
# TWICE and assert the two routes are byte-identical (determinism), and assert the fingerprint matches the
# pinned EXPECTED value with the FAILING seed in the assert message (AC2 verbatim style: "route
# fingerprints are stable in tests"). The approved seeds collectively produce >= 2 distinct routes
# (meaningful divergence). The fingerprint helper is also cross-checked against the LIVE built route
# (no second pinning path that can silently diverge — the Epic-3 cross-check discipline).
#
# DELIBERATE-UPDATE CONTRACT: these pinned fingerprints change ONLY with an intentional generator change —
# and the story/PR that makes that change re-pins them here via tools/dump_route_fingerprints.gd. They
# must NEVER be hand-edited to silence a drifting test. The route fingerprint pins the FIXED `map` DRAW
# ORDER (count -> per-column widths -> per-node type+clue -> per-source fan-out); reordering or inserting a
# `map` draw drifts every value here, exactly like the Epic-3 layout draw order.
#
# Change Log:
#   2026-06-18 (Story 4.2): initial pin — seeded 8-12-node route generation, first `map`-stream consumer.
#   2026-07-07 (Story 10.2): sample EXPANDED 8 -> 20 seeds toward the AC2 MVP-readiness route target (20).
#     The original eight seeds (0, 1, 2, 1001, 2002, 7, 42, 123456789) are UNCHANGED (byte-identical pins,
#     NOT a re-pin); twelve additional varied seeds (3, 5, 13, 99, 314, 777, 2026, 8675309, 55555, 271828,
#     161803, 4242) were APPENDED, each regenerated from the live tools/dump_route_fingerprints.gd output
#     (never hand-typed). The consolidated seed-regression suite (tests/integration/test_seed_regression_suite.gd)
#     REUSES this same constant as the single canonical route pin (no second route pinning path).

const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")

# Approved root_seed -> expected route fingerprint. Spans the [8, 12] non-boss band (counts 8/9/10/11/12)
# so the divergence assertion is meaningful. Generated via tools/dump_route_fingerprints.gd.
const APPROVED_FINGERPRINTS: Dictionary = {
	0: "10|node-0-0:combat@0 node-1-0:shop@1 node-1-1:combat@1 node-2-0:combat@2 node-2-1:elite_combat@2 node-3-0:secret@3 node-4-0:elite_combat@4 node-4-1:combat@4 node-5-0:elite_combat@5 node-6-0:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-0,node-1-1 node-1-0>node-2-0,node-2-1 node-1-1>node-2-1 node-2-0>node-3-0 node-2-1>node-3-0 node-3-0>node-4-0,node-4-1 node-4-0>node-5-0 node-4-1>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	1: "8|node-0-0:combat@0 node-1-0:event@1 node-2-0:combat@2 node-3-0:reforge@3 node-4-0:elite_combat@4 node-4-1:secret@4 node-5-0:elite_combat@5 node-6-0:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-0 node-2-0>node-3-0 node-3-0>node-4-0,node-4-1 node-4-0>node-5-0 node-4-1>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	2: "9|node-0-0:combat@0 node-1-0:elite_combat@1 node-2-0:combat@2 node-2-1:combat@2 node-3-0:gambling@3 node-3-1:event@3 node-4-0:elite_combat@4 node-5-0:combat@5 node-6-0:shop@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-0,node-2-1 node-2-0>node-3-0,node-3-1 node-2-1>node-3-0 node-3-0>node-4-0 node-3-1>node-4-0 node-4-0>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	1001: "12|node-0-0:combat@0 node-1-0:combat@1 node-2-0:combat@2 node-2-1:shop@2 node-3-0:combat@3 node-3-1:shop@3 node-4-0:combat@4 node-4-1:combat@4 node-5-0:elite_combat@5 node-5-1:combat@5 node-6-0:combat@6 node-6-1:shop@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-0,node-2-1 node-2-0>node-3-1 node-2-1>node-3-0 node-3-0>node-4-1 node-3-1>node-4-0 node-4-0>node-5-0,node-5-1 node-4-1>node-5-0,node-5-1 node-5-0>node-6-0 node-5-1>node-6-0,node-6-1 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7",
	2002: "8|node-0-0:combat@0 node-1-0:combat@1 node-2-0:combat@2 node-2-1:shop@2 node-3-0:secret@3 node-4-0:shop@4 node-5-0:combat@5 node-6-0:secret@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-0,node-2-1 node-2-0>node-3-0 node-2-1>node-3-0 node-3-0>node-4-0 node-4-0>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	7: "8|node-0-0:combat@0 node-1-0:combat@1 node-1-1:event@1 node-2-0:event@2 node-3-0:secret@3 node-4-0:elite_combat@4 node-5-0:elite_combat@5 node-6-0:combat@6 node-7-0:boss@7|node-0-0>node-1-1,node-1-0 node-1-0>node-2-0 node-1-1>node-2-0 node-2-0>node-3-0 node-3-0>node-4-0 node-4-0>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	42: "12|node-0-0:combat@0 node-1-0:combat@1 node-2-0:combat@2 node-2-1:combat@2 node-3-0:event@3 node-3-1:combat@3 node-4-0:elite_combat@4 node-4-1:combat@4 node-5-0:secret@5 node-5-1:combat@5 node-6-0:shop@6 node-6-1:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-0,node-2-1 node-2-0>node-3-1 node-2-1>node-3-0 node-3-0>node-4-0 node-3-1>node-4-1 node-4-0>node-5-1 node-4-1>node-5-0,node-5-1 node-5-0>node-6-0,node-6-1 node-5-1>node-6-0,node-6-1 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7",
	123456789: "10|node-0-0:combat@0 node-1-0:combat@1 node-1-1:combat@1 node-2-0:elite_combat@2 node-3-0:combat@3 node-4-0:shop@4 node-4-1:shop@4 node-5-0:combat@5 node-5-1:elite_combat@5 node-6-0:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-1,node-1-0 node-1-0>node-2-0 node-1-1>node-2-0 node-2-0>node-3-0 node-3-0>node-4-0,node-4-1 node-4-0>node-5-0,node-5-1 node-4-1>node-5-0,node-5-1 node-5-0>node-6-0 node-5-1>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	# --- Story 10.2 expansion (12 additional seeds; regenerated from tools/dump_route_fingerprints.gd) ---
	3: "10|node-0-0:combat@0 node-1-0:elite_combat@1 node-1-1:event@1 node-2-0:combat@2 node-2-1:elite_combat@2 node-3-0:shop@3 node-4-0:shop@4 node-5-0:elite_combat@5 node-6-0:elite_combat@6 node-6-1:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-0,node-1-1 node-1-0>node-2-0 node-1-1>node-2-1 node-2-0>node-3-0 node-2-1>node-3-0 node-3-0>node-4-0 node-4-0>node-5-0 node-5-0>node-6-0,node-6-1 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7",
	5: "8|node-0-0:combat@0 node-1-0:combat@1 node-2-0:shop@2 node-3-0:gambling@3 node-3-1:shop@3 node-4-0:gambling@4 node-5-0:reforge@5 node-6-0:combat@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-0 node-2-0>node-3-0,node-3-1 node-3-0>node-4-0 node-3-1>node-4-0 node-4-0>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	13: "8|node-0-0:combat@0 node-1-0:combat@1 node-2-0:elite_combat@2 node-3-0:elite_combat@3 node-4-0:event@4 node-5-0:elite_combat@5 node-5-1:reforge@5 node-6-0:reforge@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-0 node-2-0>node-3-0 node-3-0>node-4-0 node-4-0>node-5-0,node-5-1 node-5-0>node-6-0 node-5-1>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	99: "8|node-0-0:combat@0 node-1-0:event@1 node-2-0:combat@2 node-2-1:combat@2 node-3-0:elite_combat@3 node-4-0:secret@4 node-5-0:reforge@5 node-6-0:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-1,node-2-0 node-2-0>node-3-0 node-2-1>node-3-0 node-3-0>node-4-0 node-4-0>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	314: "12|node-0-0:combat@0 node-1-0:event@1 node-2-0:event@2 node-2-1:combat@2 node-3-0:combat@3 node-3-1:secret@3 node-4-0:elite_combat@4 node-4-1:combat@4 node-5-0:shop@5 node-5-1:shop@5 node-6-0:reforge@6 node-6-1:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-0,node-2-1 node-2-0>node-3-0 node-2-1>node-3-1 node-3-0>node-4-0 node-3-1>node-4-1 node-4-0>node-5-0,node-5-1 node-4-1>node-5-0,node-5-1 node-5-0>node-6-0 node-5-1>node-6-1 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7",
	777: "8|node-0-0:combat@0 node-1-0:combat@1 node-1-1:combat@1 node-2-0:combat@2 node-3-0:gambling@3 node-4-0:elite_combat@4 node-5-0:shop@5 node-6-0:combat@6 node-7-0:boss@7|node-0-0>node-1-0,node-1-1 node-1-0>node-2-0 node-1-1>node-2-0 node-2-0>node-3-0 node-3-0>node-4-0 node-4-0>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	2026: "10|node-0-0:combat@0 node-1-0:elite_combat@1 node-2-0:combat@2 node-2-1:combat@2 node-3-0:event@3 node-4-0:combat@4 node-5-0:elite_combat@5 node-5-1:combat@5 node-6-0:elite_combat@6 node-6-1:shop@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-1,node-2-0 node-2-0>node-3-0 node-2-1>node-3-0 node-3-0>node-4-0 node-4-0>node-5-0,node-5-1 node-5-0>node-6-0,node-6-1 node-5-1>node-6-0 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7",
	8675309: "12|node-0-0:combat@0 node-1-0:combat@1 node-1-1:combat@1 node-2-0:event@2 node-2-1:combat@2 node-3-0:reforge@3 node-3-1:combat@3 node-4-0:gambling@4 node-5-0:combat@5 node-5-1:combat@5 node-6-0:elite_combat@6 node-6-1:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-0,node-1-1 node-1-0>node-2-0,node-2-1 node-1-1>node-2-1 node-2-0>node-3-1,node-3-0 node-2-1>node-3-1 node-3-0>node-4-0 node-3-1>node-4-0 node-4-0>node-5-0,node-5-1 node-5-0>node-6-1 node-5-1>node-6-0 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7",
	55555: "9|node-0-0:combat@0 node-1-0:elite_combat@1 node-1-1:event@1 node-2-0:elite_combat@2 node-2-1:shop@2 node-3-0:event@3 node-4-0:shop@4 node-5-0:elite_combat@5 node-6-0:reforge@6 node-7-0:boss@7|node-0-0>node-1-1,node-1-0 node-1-0>node-2-1,node-2-0 node-1-1>node-2-1 node-2-0>node-3-0 node-2-1>node-3-0 node-3-0>node-4-0 node-4-0>node-5-0 node-5-0>node-6-0 node-6-0>node-7-0 node-7-0>|boss7",
	271828: "12|node-0-0:combat@0 node-1-0:combat@1 node-2-0:elite_combat@2 node-2-1:event@2 node-3-0:shop@3 node-3-1:elite_combat@3 node-4-0:reforge@4 node-4-1:combat@4 node-5-0:combat@5 node-5-1:elite_combat@5 node-6-0:elite_combat@6 node-6-1:elite_combat@6 node-7-0:boss@7|node-0-0>node-1-0 node-1-0>node-2-1,node-2-0 node-2-0>node-3-0,node-3-1 node-2-1>node-3-0 node-3-0>node-4-1 node-3-1>node-4-0 node-4-0>node-5-1 node-4-1>node-5-0,node-5-1 node-5-0>node-6-0,node-6-1 node-5-1>node-6-0 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7",
	161803: "11|node-0-0:combat@0 node-1-0:elite_combat@1 node-1-1:combat@1 node-2-0:event@2 node-3-0:combat@3 node-4-0:reforge@4 node-4-1:combat@4 node-5-0:shop@5 node-5-1:secret@5 node-6-0:elite_combat@6 node-6-1:secret@6 node-7-0:boss@7|node-0-0>node-1-1,node-1-0 node-1-0>node-2-0 node-1-1>node-2-0 node-2-0>node-3-0 node-3-0>node-4-0,node-4-1 node-4-0>node-5-1,node-5-0 node-4-1>node-5-1 node-5-0>node-6-0 node-5-1>node-6-1 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7",
	4242: "11|node-0-0:combat@0 node-1-0:event@1 node-1-1:combat@1 node-2-0:event@2 node-3-0:elite_combat@3 node-4-0:elite_combat@4 node-4-1:reforge@4 node-5-0:elite_combat@5 node-5-1:reforge@5 node-6-0:shop@6 node-6-1:combat@6 node-7-0:boss@7|node-0-0>node-1-1,node-1-0 node-1-0>node-2-0 node-1-1>node-2-0 node-2-0>node-3-0 node-3-0>node-4-1,node-4-0 node-4-0>node-5-0,node-5-1 node-4-1>node-5-1 node-5-0>node-6-1,node-6-0 node-5-1>node-6-1 node-6-0>node-7-0 node-6-1>node-7-0 node-7-0>|boss7"
}

func run() -> Dictionary:
	_approved_seeds_match_pinned_fingerprints()
	_approved_seeds_are_internally_deterministic()
	_approved_seeds_show_meaningful_divergence()
	_fingerprint_helper_cross_checks_live_route()
	return result()


func _route_for_seed(root_seed: int) -> RouteState:
	var generation_result: GenerationResult = RouteGenerator.generate(root_seed)
	assert_true(generation_result.succeeded, "Approved-seed %d should generate a route. Error: %s" % [root_seed, generation_result.diagnostics])
	return RouteGenerator.route_from_result(generation_result)


func _approved_seeds_match_pinned_fingerprints() -> void:
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		var root_seed: int = int(seed_key)
		var expected: String = String(APPROVED_FINGERPRINTS[seed_key])
		var actual: String = RouteGenerator.fingerprint(_route_for_seed(root_seed))
		# AC2: the failing seed MUST appear in the assert message on a regression.
		assert_equal(actual, expected, "Route fingerprint regression for root_seed=%d. If this change is intentional, re-pin via tools/dump_route_fingerprints.gd and update the change log." % root_seed)


func _approved_seeds_are_internally_deterministic() -> void:
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		var root_seed: int = int(seed_key)
		var first: Dictionary = RouteGenerator.generate(root_seed).payload
		var second: Dictionary = RouteGenerator.generate(root_seed).payload
		# Byte-identical determinism over a REAL JSON round-trip of the serializable payload.
		var first_json: String = JSON.stringify(first)
		var second_json: String = JSON.stringify(second)
		assert_equal(first_json, second_json, "Approved seed %d must reproduce a byte-identical route across two generations." % root_seed)


func _approved_seeds_show_meaningful_divergence() -> void:
	var distinct: Dictionary = {}
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		distinct[String(APPROVED_FINGERPRINTS[seed_key])] = true
	assert_true(distinct.size() >= 2, "Approved fixture seeds must produce at least two distinct routes (AC2 meaningful divergence).")


func _fingerprint_helper_cross_checks_live_route() -> void:
	# Cross-check: the fingerprint helper must agree with the LIVE built route for each approved seed (the
	# same value the pinned dict holds). This guarantees there is no second pinning path that can silently
	# diverge from the live generator output.
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		var root_seed: int = int(seed_key)
		var live_route: RouteState = _route_for_seed(root_seed)
		var live_fingerprint: String = RouteGenerator.fingerprint(live_route)
		assert_equal(live_fingerprint, String(APPROVED_FINGERPRINTS[seed_key]), "Fingerprint helper must agree with the live built route for root_seed=%d." % root_seed)
