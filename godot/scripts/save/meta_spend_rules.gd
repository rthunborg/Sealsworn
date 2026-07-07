class_name MetaSpendRules
extends RefCounted

# Story 11.6 (AC1/AC2, FR59/FR43/FR95) — the META-SPEND / UNLOCK-APPLICATION rule config. A PURE, DETERMINISTIC,
# ZERO-RNG, CAPPED const-config calculator: the SPEND-side sibling of MetaAwardRules (the award-amount calculator) and
# UnlockProgressRules (the discovery-threshold calculator). Same posture: a DECLARED const config, a pure read of the
# profile state alone, ZERO RNG (no randi/randf/RandomNumberGenerator — same profile -> same spendable set + same cost;
# the named-RNG rule + the whole-epic determinism invariant), submits NO command, mutates NOTHING (it returns fresh
# values; the SpendOathShardsCommand applies them). It does NOT scale by DIFFICULTY (a hard non-goal — nothing here reads
# a difficulty setting).
#
# ⭐ THE v0 SPEND MODEL ([Decision] — recorded in the story Completion Notes) satisfies FR59 (spend what you earn) + FR43
# (locked-class unlock) + FR95 "meta power is capped, sparse, secondary to variety; raw-stat ladders REJECTED for MVP":
#   - A SPEND buys a CLASS UNLOCK: it consumes a FIXED Oath-Shard cost and flips the class's applied-unlock flag in
#     `unlock_progress` (a VARIETY gate — a formerly-locked class becomes selectable). It is CAPPED + SPARSE: there are
#     exactly TWO spendable class unlocks in v0 (necromancer/shadeblade — the two locked baselines, FR43), each with a
#     FIXED cost, each flipping EXACTLY ONE variety flag. There is NO raw combat stat purchase, NO repeatable ladder, NO
#     stacking upgrade.
#   - WHY IT IS NOT A RAW-STAT LADDER (FR95): a spend flips a class-selectability VARIETY flag; it grants NO
#     damage/max-HP/armor/crit/dodge. The applied-unlock flag keys are `<class>_unlocked` — NONE contains a raw-stat
#     token (UnlockProgressRules.is_raw_stat_unlock_key produces none; asserted by test). The spend widens the ROSTER
#     (an option), never a repeatable number.
#   - THE COSTS + THE UNLOCK->CLASS MAPPING ARE DECLARED CONSTs (the MetaAwardRules.BASE_AWARD/MAX_AWARD +
#     UnlockProgressRules.SEAL_FRAGMENT_THRESHOLDS precedent), test-pinned. CLASS_UNLOCKS maps a spendable unlock id to
#     {class_id, cost, flag_key}. A spend id outside this set is NOT spendable (fail-closed).
#
# ⭐ THE AC2 SEAM SOURCE (the crux — the profile -> class-selectability wiring): `unlocked_class_ids_for(profile)` is the
# SINGLE pure helper both the profile-aware HeroSelectViewModel AND the authoritative RunStartCommand class gate read to
# derive the set of class ids a profile has UNLOCKED (a formerly-locked class whose applied-unlock flag is set). The two
# decision sites read THIS one source, so the VM affordance and the authoritative gate AGREE (a mis-enabled confirm
# cannot start a still-locked class; a genuinely-unlocked class is not rejected). It reads ONLY the applied-unlock flags
# in `unlock_progress` — it does NOT mutate the static ClassDefinition (approved static content is selected-from, not
# rewritten) and owns NO scene state. A null/empty profile yields an EMPTY set (byte-identical static behavior).
#
# ⭐ THE SPEND-STATE HOME ([Decision]): the applied-unlock flags + the spend ledger live INSIDE the existing
# `unlock_progress` Dictionary home (NOT a new top-level ProfileSnapshot key — so 11.6 spends WITHOUT a migration and
# WITHOUT touching ProfileSnapshot.DICTIONARY_KEYS, mirroring how Seal Fragments live under
# `unlock_progress["seal_fragments"]` + the merge marker under `unlock_progress["_last_merged_run_seed"]`). The
# `<class>_unlocked` flags are lower_snake unlock-track flags (like the merge's `<track>_unlocked` state flags); the
# spend LEDGER lives under the underscore-namespaced OATH_SHARDS_SPENT_KEY so it can never collide with a lower_snake
# unlock-track/flag key and the UnlockProgressRules threshold calc + the summary derive ignore it (the
# `_last_merged_run_seed` underscore-namespacing precedent).

# The underscore-namespaced key under which the CUMULATIVE Oath-Shard SPEND ledger (a non-negative running total of Oath
# Shards ever spent) lives inside unlock_progress ([Decision] — the SPEND LEDGER HOME: a namespaced key inside
# unlock_progress, NOT a new top-level ProfileSnapshot key — 11.6 merges WITHOUT a migration). Underscore-namespaced (like
# _last_merged_run_seed) so it never collides with a lower_snake unlock-track/flag key and the threshold rule ignores it.
const OATH_SHARDS_SPENT_KEY := "_oath_shards_spent"

# The v0 spendable CLASS UNLOCKS ([Decision], test-pinned). Each entry maps a stable lower_snake SPEND id (== the class
# id in v0 — one spend per locked class) to {class_id, cost, flag_key}: the class the spend unlocks, the FIXED Oath-Shard
# cost, and the lower_snake `<class>_unlocked` applied-unlock FLAG set in unlock_progress on a successful spend. Sparse +
# finite (exactly the two locked baselines — necromancer/shadeblade, FR43). NO raw-stat key (is_raw_stat_unlock_key
# produces none — asserted by test). CAPPED: each spend flips EXACTLY ONE variety flag; there is no repeatable ladder.
const CLASS_UNLOCKS: Dictionary = {
	"necromancer": {
		"class_id": "necromancer",
		"cost": 3,
		"flag_key": "necromancer_unlocked"
	},
	"shadeblade": {
		"class_id": "shadeblade",
		"cost": 5,
		"flag_key": "shadeblade_unlocked"
	}
}


# Is this a spendable class-unlock id (a v0 CLASS_UNLOCKS key)? Fail-closed — an unknown id is NOT spendable.
static func is_class_unlock(unlock_id: String) -> bool:
	return CLASS_UNLOCKS.has(unlock_id)


# The Oath-Shard cost of a spendable class unlock, or -1 for an unknown/unspendable id (the caller fail-closes on < 0).
# PURE + DETERMINISTIC + does NOT scale by difficulty. Read directly off the declared const.
static func class_unlock_cost(unlock_id: String) -> int:
	if not CLASS_UNLOCKS.has(unlock_id):
		return -1
	return int((CLASS_UNLOCKS[unlock_id] as Dictionary).get("cost", -1))


# The lower_snake `<class>_unlocked` applied-unlock FLAG key a spend of this unlock sets in unlock_progress, or "" for an
# unknown id. This is the flag the SpendOathShardsCommand flips + the profile-aware selectability seam reads.
static func class_unlock_flag_key(unlock_id: String) -> String:
	if not CLASS_UNLOCKS.has(unlock_id):
		return ""
	return String((CLASS_UNLOCKS[unlock_id] as Dictionary).get("flag_key", ""))


# The class id a spend of this unlock makes selectable, or "" for an unknown id.
static func class_id_for_unlock(unlock_id: String) -> String:
	if not CLASS_UNLOCKS.has(unlock_id):
		return ""
	return String((CLASS_UNLOCKS[unlock_id] as Dictionary).get("class_id", ""))


# ⭐ THE AC2 SEAM SOURCE: the set of class ids a profile's unlock_progress has UNLOCKED via an applied-unlock flag (a
# formerly-locked class whose `<class>_unlocked` flag is set true). PURE + DETERMINISTIC + ZERO RNG. Reads ONLY the
# applied-unlock flags — a null/empty profile (or one with no set flags) yields an EMPTY Array (so a null-profile
# HeroSelectViewModel / RunStartCommand is byte-identical to today's static behavior). Ordered by the CLASS_UNLOCKS
# declaration order (necromancer, shadeblade) for determinism. Returns plain lower_snake String ids (JSON-safe; the
# codebase idiom that projections emit String, not StringName). It does NOT mutate the ClassDefinition and owns no scene
# state — the applied-unlock is a profile-aware OVERLAY read here + consulted at the view-model/gate layer.
static func unlocked_class_ids_for(unlock_progress: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for unlock_id: String in CLASS_UNLOCKS.keys():
		var flag_key: String = String((CLASS_UNLOCKS[unlock_id] as Dictionary).get("flag_key", ""))
		if flag_key.is_empty():
			continue
		if bool(unlock_progress.get(flag_key, false)):
			var class_id: String = String((CLASS_UNLOCKS[unlock_id] as Dictionary).get("class_id", ""))
			if not class_id.is_empty() and not ids.has(class_id):
				ids.append(class_id)
	return ids


# The cumulative Oath-Shard spend total recorded in unlock_progress (a non-negative running total), or 0 if never spent /
# malformed. Read-only. The spend command adds each spend's amount to this ledger.
static func oath_shards_spent_in(unlock_progress: Dictionary) -> int:
	var value: Variant = unlock_progress.get(OATH_SHARDS_SPENT_KEY, 0)
	if typeof(value) == TYPE_INT:
		var parsed: int = int(value)
		return parsed if parsed >= 0 else 0
	if typeof(value) == TYPE_FLOAT:
		var numeric: float = float(value)
		if is_nan(numeric) or is_inf(numeric):
			return 0
		var parsed_float: int = int(numeric)
		return parsed_float if parsed_float >= 0 else 0
	return 0
