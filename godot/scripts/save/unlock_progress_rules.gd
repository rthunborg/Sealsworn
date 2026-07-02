class_name UnlockProgressRules
extends RefCounted

# Story 8.4 (AC3, FR95) — the UNLOCK-PROGRESS THRESHOLD rule. A PURE, DETERMINISTIC, ZERO-RNG, CAPPED calculator that,
# given a profile's merged `unlock_progress` state, computes which unlock-track THRESHOLDS are now crossed and what
# unlock STATE results. It is the unlock-progress sibling of MetaAwardRules (the Oath-Shard calculator) — same posture:
# a pure read of the state alone, a DECLARED const config, and a hard "no raw-stat ladder" guarantee. It draws ZERO RNG
# (no randi/randf/RandomNumberGenerator — same merged state -> same crossings; the named-RNG rule + the whole-epic
# determinism invariant), submits NO command, and DOES NOT MUTATE its input (it returns the crossings + the NEW state as
# a fresh dict; the caller applies it).
#
# ⭐ THE v0 UNLOCK MODEL ([Decision] — recorded in the story Completion Notes) satisfies AC3 "capped, sparse, secondary
# to variety; raw-stat ladders REJECTED for MVP":
#   - `unlock_progress` is a deterministic COUNTER/STATE MAP, NOT a raw-stat ladder. It carries:
#       * `seal_fragments`: an Array of unique discovered Seal-Fragment ids (the GDD "major seal/story unlocks" — a
#         COUNT-by-set). The count of seal fragments is the primary unlock-track SIGNAL in v0.
#       * `<track>_unlocked`: a bool STATE flag flipped ONCE when a threshold on a track is crossed (idempotent — an
#         already-flipped flag is never re-crossed). These flags widen VARIETY / knowledge / OPTIONS (a codex tier, a
#         seal-story gate) — NEVER a repeatable raw combat stat.
#   - THRESHOLDS ARE A DECLARED CONST (the MetaAwardRules.BASE_AWARD/MAX_AWARD precedent), test-pinned. v0 declares two
#     seal-fragment-count thresholds (`SEAL_FRAGMENT_THRESHOLDS`) mapping a REQUIRED count to a STATE-flag id + a stable
#     threshold marker id. Crossing a threshold flips its flag deterministically (same state -> same crossings) and is
#     reported (the crossed threshold ids + the resulting state). It is CAPPED: a track flips a FIXED, FINITE set of
#     flags (no unbounded ladder) and each flag flips exactly once.
#   - WHY IT IS NOT A RAW-STAT LADDER (AC3 second half): a crossed threshold sets a VARIETY/knowledge STATE flag; it
#     grants NO damage / max-HP / armor / crit / dodge (the AC3 rejected set). The RAW-STAT KIND ALLOWLIST is empty —
#     `is_raw_stat_unlock_key` classifies a would-be raw-stat unlock key so a test can assert none is ever produced. This
#     story RECORDS the flip; the EFFECT-APPLICATION (spending Oath Shards / applying a class/passive/starting-option
#     from an unlock) is a LATER meta-spend story (8.6+/Epic 9 — the 8.3 defer). AC3 is about the STATE flipping
#     deterministically + being reported, not about applying its effect.
#   - It does NOT scale by DIFFICULTY (a hard non-goal) — the count is a discovery signal, not a difficulty knob, and
#     nothing here reads a difficulty setting.

# The v0 seal-fragment-count thresholds ([Decision], test-pinned). Each entry: the REQUIRED seal-fragment COUNT, the
# stable lower_snake THRESHOLD marker id (reported in the merge event's thresholds_crossed list), and the lower_snake
# STATE-FLAG KEY set in unlock_progress when the threshold is crossed. Sparse + finite (two tiers) — a capped ladder of
# VARIETY gates, never a raw stat. Ordered ascending by required_count.
const SEAL_FRAGMENT_THRESHOLDS: Array[Dictionary] = [
	{
		"required_count": 1,
		"threshold_id": "seal_gate_1",
		"flag_key": "seal_gate_1_unlocked"
	},
	{
		"required_count": 3,
		"threshold_id": "seal_gate_2",
		"flag_key": "seal_gate_2_unlocked"
	}
]

# The stable key under which the discovered Seal-Fragment id SET lives inside unlock_progress ([Decision] — the SEAL
# FRAGMENTS HOME DECISION: Seal Fragments are UNLOCK PROGRESS, so they live in unlock_progress, NOT a new top-level
# ProfileSnapshot key — 8.4 merges WITHOUT a migration). MergeRunDiscoveriesCommand + this rule reference it so both stay
# in lockstep on the shape.
const SEAL_FRAGMENTS_KEY := "seal_fragments"

# The RAW-STAT unlock-key vocabulary that AC3/FR95 REJECTS for MVP (damage/max-HP/armor/crit/dodge — a repeatable raw
# combat stat). This rule produces NONE of these; is_raw_stat_unlock_key lets a test assert the produced state carries no
# raw-stat unlock key (the AC3 structural guarantee). A key is a raw-stat key if it CONTAINS one of these tokens.
const RAW_STAT_UNLOCK_TOKENS: Array[String] = [
	"damage",
	"max_hp",
	"maxhp",
	"armor",
	"crit",
	"dodge"
]


# Given a profile's merged unlock_progress state, compute the unlock-track thresholds now crossed + the resulting NEW
# unlock_progress state. PURE + DETERMINISTIC + CAPPED + IDEMPOTENT (a threshold whose flag is ALREADY set is NOT
# re-crossed). Draws ZERO RNG. Returns a fresh Dictionary:
#   {
#     "thresholds_crossed": Array[String]  # the stable threshold marker ids crossed by THIS call (empty if none),
#     "state": Dictionary                  # the NEW unlock_progress (a deep copy of the input + the newly-set flags)
#   }
# The input is NOT mutated (a deep copy is taken). The caller (MergeRunDiscoveriesCommand) applies `state` back onto the
# profile and reports `thresholds_crossed` in the merge event (AC3).
static func evaluate(unlock_progress: Dictionary) -> Dictionary:
	var state: Dictionary = unlock_progress.duplicate(true)
	var thresholds_crossed: Array[String] = []

	var seal_fragment_count: int = _seal_fragment_count(state)
	for threshold: Dictionary in SEAL_FRAGMENT_THRESHOLDS:
		var required_count: int = int(threshold.get("required_count", 0))
		var flag_key: String = String(threshold.get("flag_key", ""))
		var threshold_id: String = String(threshold.get("threshold_id", ""))
		# Idempotent: a threshold whose flag is already set is NOT re-crossed (re-crossing an already-flipped threshold is
		# a no-op — the AC3 "flips ONCE" guarantee).
		if bool(state.get(flag_key, false)):
			continue
		if seal_fragment_count >= required_count:
			state[flag_key] = true
			thresholds_crossed.append(threshold_id)

	return {
		"thresholds_crossed": thresholds_crossed,
		"state": state
	}


# The count of discovered Seal Fragments in the state (the seal_fragments id SET's size). A missing/malformed
# seal_fragments entry counts as 0 (fail-safe). Non-negative.
static func _seal_fragment_count(state: Dictionary) -> int:
	var value: Variant = state.get(SEAL_FRAGMENTS_KEY, [])
	if not value is Array:
		return 0
	return (value as Array).size()


# Classify a would-be unlock key as a REJECTED raw-stat unlock (AC3/FR95). Returns true if the key contains a raw-stat
# token (damage/max-HP/armor/crit/dodge). Used by tests to assert this rule produces NO raw-stat unlock key — the AC3
# "meta power widens variety/options, never a repeatable raw stat" structural guarantee. Case-insensitive.
static func is_raw_stat_unlock_key(key: String) -> bool:
	var lowered: String = key.to_lower()
	for token: String in RAW_STAT_UNLOCK_TOKENS:
		if lowered.contains(token):
			return true
	return false
