class_name RunSeedSource
extends RefCounted

# Story 14.4 (AC1/AC2/AC3) — the PURE, SCENE-FREE per-run seed SOURCE seam. It is the ONE determinism-source
# decision in Epic 14: given the launch-configured seed carrier (GameSession.get_root_seed, 0 == unconfigured)
# and a freshly-read one-time ENTROPY value (INJECTED by the caller — the seam draws NO RNG itself), it decides
# the (root_seed, is_manual_seed) pair the two live new-run callers hand to the AUTHORITATIVE fail-closed
# RunFlowController.start -> RunOrchestrator.start -> RunStartCommand. It changes ONLY which seed is handed in;
# it does NOT touch RunStartCommand, the generation pipeline, any named RngStreamSet stream, any draw site, or the
# save schema — a run stays a PURE deterministic function of its given root_seed (14.4 changes only which seed is
# handed in, never how the seed is consumed).
#
# ⭐ WHY A SEPARATE SEAM (AC3): the manual-vs-entropy DECISION + the non-negative/non-zero normalization is the
# assertable logic, so it lives in a RefCounted testable WITHOUT a SceneTree (the entropy is INJECTED so the
# decision is deterministic and unit-tested). The one IMPURE line — the OS-entropy read — stays in the presenter
# (a local RandomNumberGenerator.randomize(), NOT a named gameplay stream, NOT the global randi()); the seam only
# CONSUMES the injected value. Keeping the read OUT of the seam is what makes the seam pure/testable.
#
# ⭐ THE TWO BRANCHES:
#   - MANUAL (configured_seed != 0): the explicit-seed path (FR27/FR28/FR29). Return the configured seed VERBATIM
#     (no mask, no truncation — a full int64 manual seed round-trips) with is_manual_seed = true, which makes
#     RunSnapshot.meta_progression_eligible false (a manual-seed run earns NO meta progression). The injected
#     entropy is IGNORED (the manual path bypasses the entropy source and reproduces byte-identically).
#   - ENTROPY (configured_seed == 0): the normal-run path (FR26). Normalize the injected entropy to a NON-NEGATIVE,
#     NON-ZERO 31-bit seed and return it with is_manual_seed = false (the run stays meta-eligible). 31 bits because
#     RngStreamSet._derive_seed masks the base seed to 31 bits anyway (so a wider domain wastes no entropy) and
#     RunStartCommand.validate rejects root_seed < 0 (invalid_run_seed); 0 is avoided because it is the GameSession
#     "unconfigured" sentinel the manual branch keys off (a normalized-to-0 seed would be misread as a manual run).
#
# ⭐ NOT A SAVE CHANGE: an entropy seed flows into the EXISTING root_seed field (#5 of the 23-key RunSnapshot),
# exactly like a manual seed — the snapshot shape, the 23-key gate, and SCHEMA_VERSION == 1 are all untouched.

# The pinned result key set — fail loud if a key appears or vanishes (the seam's contract with its two callers).
const RESULT_KEYS: Array[String] = ["root_seed", "is_manual_seed"]

# The 31-bit non-negative mask (mirrors RngStreamSet._derive_seed's base-seed mask). 0x7fffffff == 2^31 - 1.
const SEED_MASK: int = 0x7fffffff


# The pure seed-source decision (AC1/AC2/AC3). Static + side-effect-free: draws ZERO RNG (entropy is INJECTED),
# consults no RngStreamSet, reads no autoload, mutates nothing. Returns the pinned-key dict
# { root_seed: int, is_manual_seed: bool } (keys inserted in RESULT_KEYS order in BOTH branches).
static func resolve(configured_seed: int, entropy: int) -> Dictionary:
	if configured_seed != 0:
		# MANUAL branch (FR27/FR28/FR29): the explicit seed VERBATIM (no mask/truncation), no meta progression.
		# The injected entropy is deliberately ignored — the manual path bypasses the entropy source.
		return {
			"root_seed": configured_seed,
			"is_manual_seed": true
		}
	# ENTROPY branch (FR26): a normalized non-negative, non-zero 31-bit seed; the run stays meta-eligible.
	var normalized: int = entropy & SEED_MASK
	if normalized == 0:
		normalized = 1
	return {
		"root_seed": normalized,
		"is_manual_seed": false
	}
