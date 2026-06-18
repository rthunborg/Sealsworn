extends SceneTree

# One-shot dev tool: dump approved-seed route fingerprints (Story 4.2) so the route seed-regression test
# (tests/unit/generation/test_route_generation_seed_regression.gd) can pin them. NOT a test (lives under
# tools/, not auto-discovered). Mirrors tools/dump_small_layout_fingerprints.gd. Run via:
#   godot --headless --path C:\Sealsworn\godot --script res://tools/dump_route_fingerprints.gd
#
# RE-PIN DISCIPLINE: when an INTENTIONAL generator change drifts the route fingerprints, regenerate them
# HERE in the SAME PR and paste the printed values into APPROVED_FINGERPRINTS — NEVER hand-edit a pinned
# value to silence a drifting test. The fingerprint is the tripwire.

const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")

func _init() -> void:
	# Approved route seeds. Chosen to span the [8, 12] non-boss band and to produce >= 2 distinct routes
	# (divergence). Bland/edge seeds are KEPT, not deleted, if a generator change makes one degenerate —
	# annotate instead.
	var seeds: Array[int] = [0, 1, 2, 1001, 2002, 7, 42, 123456789]
	for seed_value: int in seeds:
		var generation_result := RouteGenerator.generate(seed_value)
		if generation_result.is_error():
			print("SEED %d => ERROR phase=%s code=%s reason=%s diag=%s" % [
				seed_value,
				generation_result.failed_phase,
				generation_result.error_code,
				generation_result.reason,
				generation_result.diagnostics
			])
			continue
		var route := RouteGenerator.route_from_result(generation_result)
		print("%d: \"%s\"," % [seed_value, RouteGenerator.fingerprint(route)])
	quit()
