extends "res://tests/unit/test_case.gd"

# Story 14.4 Task 4 (AC1/AC2/AC3) — RunSeedSource: the pure per-run seed-SOURCE decision seam. Pins the two
# branches (manual explicit-seed bypass vs entropy normal run), the int64 manual-seed preservation (no truncation),
# the non-negative/non-zero 31-bit entropy normalization, the run-to-run variety (the F11 fix), and the pinned
# result key set. The seam draws NO RNG (entropy is INJECTED here as a FIXED value), so every case is deterministic
# — which is exactly why the entropy path never moves a seed-regression fingerprint.
#
# NOTE (14.1 test-honesty retro): assert messages use str(...) (never eager String(nullable), which crashes on a
# null read and would mask the real failure).

const RunSeedSource = preload("res://scripts/ui/flow/run_seed_source.gd")

func run() -> Dictionary:
	_manual_branch_returns_seed_verbatim_and_ignores_entropy()
	_manual_int64_seed_is_preserved_without_truncation()
	_entropy_branch_uses_injected_entropy_and_stays_meta_eligible()
	_entropy_normalization_is_non_negative_and_non_zero()
	_two_distinct_entropy_values_yield_distinct_seeds()
	_result_dict_has_exactly_the_pinned_keys()
	return result()


# AC2 (FR27/FR28): a configured (non-zero) seed takes the MANUAL branch — returned verbatim, is_manual_seed true,
# and the injected entropy is IGNORED (prove the manual path never consults it).
func _manual_branch_returns_seed_verbatim_and_ignores_entropy() -> void:
	var decision: Dictionary = RunSeedSource.resolve(4242, 999999)
	assert_equal(int(decision.get("root_seed", -1)), 4242, "A configured seed is returned verbatim on the manual branch (got %s)." % str(decision.get("root_seed")))
	assert_true(bool(decision.get("is_manual_seed", false)), "A configured seed is a manual seed (is_manual_seed true) — no meta progression.")
	# The injected entropy 999999 must NOT leak into the result (the manual branch bypasses the entropy source).
	assert_false(int(decision.get("root_seed", -1)) == 999999, "The manual branch must ignore the injected entropy, not return it.")


# AC2: a full int64 explicit seed round-trips VERBATIM (no mask, no >2^53 truncation) with is_manual_seed true.
func _manual_int64_seed_is_preserved_without_truncation() -> void:
	var big_seed: int = 9223372036854775807  # INT64_MAX
	var decision: Dictionary = RunSeedSource.resolve(big_seed, 12345)
	assert_equal(int(decision.get("root_seed", 0)), big_seed, "A full int64 manual seed must be preserved verbatim (got %s)." % str(decision.get("root_seed")))
	assert_true(bool(decision.get("is_manual_seed", false)), "A large explicit seed is still a manual seed.")


# AC1 (FR26): an unconfigured carrier (0) takes the ENTROPY branch — the injected entropy is the seed and the run
# stays meta-eligible (is_manual_seed false).
func _entropy_branch_uses_injected_entropy_and_stays_meta_eligible() -> void:
	var decision: Dictionary = RunSeedSource.resolve(0, 12345)
	assert_equal(int(decision.get("root_seed", -1)), 12345, "An in-range entropy value passes through as the root_seed (got %s)." % str(decision.get("root_seed")))
	assert_false(bool(decision.get("is_manual_seed", true)), "A normal entropy run is NOT a manual seed (stays meta-eligible).")


# AC1/AC3: the entropy normalization never yields a seed RunStartCommand would reject (< 0) and never the 0
# sentinel — 0 -> non-zero, a negative or >31-bit entropy -> a non-negative non-zero 31-bit seed, always
# is_manual_seed false.
func _entropy_normalization_is_non_negative_and_non_zero() -> void:
	var zero: Dictionary = RunSeedSource.resolve(0, 0)
	assert_true(int(zero.get("root_seed", 0)) >= 1, "Entropy 0 must normalize to a non-zero seed (got %s)." % str(zero.get("root_seed")))
	assert_false(bool(zero.get("is_manual_seed", true)), "Entropy 0 stays the entropy branch (is_manual_seed false).")

	var negative: Dictionary = RunSeedSource.resolve(0, -1)
	assert_true(int(negative.get("root_seed", -1)) >= 1, "A negative entropy must normalize to a non-negative non-zero seed (never < 0, which RunStartCommand rejects) (got %s)." % str(negative.get("root_seed")))
	assert_false(bool(negative.get("is_manual_seed", true)), "A negative entropy stays the entropy branch (is_manual_seed false).")

	var wide: Dictionary = RunSeedSource.resolve(0, 0x100000000 + 7)  # a >31-bit entropy value (bit 32 set)
	assert_true(int(wide.get("root_seed", -1)) >= 1, "A >31-bit entropy must normalize to a non-negative non-zero seed (got %s)." % str(wide.get("root_seed")))
	assert_true(int(wide.get("root_seed", -1)) <= RunSeedSource.SEED_MASK, "A normalized entropy seed fits the 31-bit domain (got %s)." % str(wide.get("root_seed")))
	assert_false(bool(wide.get("is_manual_seed", true)), "A wide entropy stays the entropy branch (is_manual_seed false).")


# AC1 (variety — the F11 fix): two DISTINCT entropy values yield two DISTINCT seeds (board/route/enemy layout
# varies run to run — two boots, two different rooms).
func _two_distinct_entropy_values_yield_distinct_seeds() -> void:
	var first: Dictionary = RunSeedSource.resolve(0, 12345)
	var second: Dictionary = RunSeedSource.resolve(0, 67890)
	assert_false(int(first.get("root_seed", 0)) == int(second.get("root_seed", 1)), "Two distinct entropy values must yield two distinct seeds (F11 variety).")


# AC3: the result dict has EXACTLY the pinned keys (fail loud if a key appears or vanishes) — the seam's contract
# with both live callers. Both branches insert keys in RESULT_KEYS order.
func _result_dict_has_exactly_the_pinned_keys() -> void:
	assert_equal(RunSeedSource.RESULT_KEYS, ["root_seed", "is_manual_seed"], "The pinned RESULT_KEYS const must be [root_seed, is_manual_seed].")
	var manual_keys: Array = RunSeedSource.resolve(4242, 0).keys()
	var entropy_keys: Array = RunSeedSource.resolve(0, 12345).keys()
	assert_equal(manual_keys, RunSeedSource.RESULT_KEYS, "The manual-branch result dict must have exactly the pinned key set (got %s)." % str(manual_keys))
	assert_equal(entropy_keys, RunSeedSource.RESULT_KEYS, "The entropy-branch result dict must have exactly the pinned key set (got %s)." % str(entropy_keys))
