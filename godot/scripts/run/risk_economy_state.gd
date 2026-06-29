class_name RiskEconomyState
extends RefCounted

# The run-domain RISK-ECONOMY state (Story 7.1) — the scene-free RefCounted value object recorded on RunState
# (alongside starting_kit / inventory / pending_reward_offer) that tracks AC1's five risk-economy categories as
# run-domain TRUTH: gold, healing availability, curse/corruption state, Oath-Shard eligibility, and risk flags.
# It is the live run-economy field the whole Epic-6 loot/reward layer RECORDED against but could not yet APPLY (the
# OUTCOME-RECORD-ONLY posture) — Story 7.1 introduces this field so a gold reward becomes FELT (the wallet rises)
# instead of merely recorded. ApplyEconomyChangeCommand mutates gold/healing through the validate-then-mutate
# run-command idiom; presentation (a later HUD story) OBSERVES this model, never owns it.
#
# IT IS A SMALL BY-VALUE STATE (mirroring StartingKit / InventoryState): gold/healing/curse/corruption are small
# bounded ints (NOT seeds — NO int64/decimal-string encoding; the 5.3/6.2 baseline_hp/capacity precedent). It owns
# no truth beyond the recorded economy, submits no commands, draws NO RNG, and resolves NO content.
#
# SCOPE (Story 7.1 is STATE + COMMANDS + SAVE, not the full risk economy):
#   - It introduces the curse/corruption *state fields + structural setters* (set_curse_count / set_corruption /
#     add_risk_flag) — it does NOT author curse RULES / trigger windows / the cleanse-curse application (Story 7.2)
#     nor the risk/reward event ROLL that populates risk_flags (Story 7.3). risk_flags is EMPTY in v0; 7.3 populates
#     it via the structural setter.
#   - oath_shard_eligible is the run-level ELIGIBILITY gate (whether a finished run MAY award Oath Shards) — NOT the
#     award amount / the meta profile / the outpost (Epic 8). [Decision] It is kept in LOCKSTEP with the run's
#     meta_progression_eligible (the existing source of truth): a MANUAL-SEED run is NEVER eligible (the GDD
#     invariant "Oath Shards: awarded only after run end and only in eligible non-manual-seed runs"). RunState seeds
#     oath_shard_eligible = (not is_manual_seed) at init, consistent with meta_progression_eligible; validate()
#     asserts the invariant against the run's manual-seed flag.
#   - healing is modeled as AVAILABILITY (healing_charges, a resource/charge count, the AC's exact "healing
#     resources OR availability" wording) — NOT a live tactical current-HP the board decrements (v0 has no live
#     tactical play loop; combat auto-resolves). [Decision]
#
# Mirrors InventoryState's exact-key to_dictionary() contract (a key never silently appears/vanishes — the key set
# is pinned by test_risk_economy_state.gd), the lenient try_from_dictionary (a value object, no reject path — a
# partial/legacy dict defaults cleanly), and the deep copy() (the risk_flags list must NOT be shared by reference).
# It rides the FULL RunState.to_dictionary()/try_from_dictionary AND — UNLIKE Epic-6 inventory/offer — the
# route-position save (nested under route_state via RunState.RISK_ECONOMY_KEY; the AC1 "and save snapshots").

const ActionResult = preload("res://scripts/core/results/action_result.gd")

# The stable key set of to_dictionary() (pinned by test). A key never silently appears or vanishes.
const DICTIONARY_KEYS: Array[String] = [
	"gold",
	"healing_charges",
	"curse_count",
	"corruption",
	"oath_shard_eligible",
	"risk_flags"
]

# AC1: the gold wallet. A small bounded NON-NEGATIVE int (default 0). NOT a seed (no decimal-string encoding); NOT a
# difficulty knob (difficulty is a hard non-goal — nothing scales this by run depth/difficulty).
var gold: int = 0
# AC1: the HEALING-AVAILABILITY resource (a charge/resource count, NOT a live current-HP). A small bounded
# non-negative int (default 0).
var healing_charges: int = 0
# AC1: the CURSE tracking count (the curse/corruption state — kept MINIMAL this story: a count container; 7.2 authors
# curse RULES). A small bounded non-negative int (default 0).
var curse_count: int = 0
# AC1: the CORRUPTION tracking count (the second half of the curse/corruption state). A small bounded non-negative
# int (default 0).
var corruption: int = 0
# AC1: the run-level Oath-Shard ELIGIBILITY gate (whether a finished run MAY award shards — Epic 8 owns the award).
# Derived from the run's manual-seed flag at init (a manual-seed run is NEVER eligible), in lockstep with
# RunState.meta_progression_eligible. Default true (a non-manual run is eligible). validate() asserts the invariant.
var oath_shard_eligible: bool = true
# AC1: the RISK-FLAGS container (a list of lower_snake risk-flag ids future systems can query). EMPTY in v0 — Story
# 7.3 (risk/reward event choices) populates it via add_risk_flag. A plain Array[String] of lower_snake ids.
var risk_flags: Array[String] = []

func _init(
	new_gold: int = 0,
	new_healing_charges: int = 0,
	new_curse_count: int = 0,
	new_corruption: int = 0,
	new_oath_shard_eligible: bool = true,
	new_risk_flags: Array = []
) -> void:
	# Each count is a small bounded NON-NEGATIVE int: a negative / non-int value clamps to 0 (lenient value-object
	# construction, mirroring InventoryState's defaulting decode). A wallet/charge/curse count is never negative.
	gold = new_gold if (new_gold is int and new_gold >= 0) else 0
	healing_charges = new_healing_charges if (new_healing_charges is int and new_healing_charges >= 0) else 0
	curse_count = new_curse_count if (new_curse_count is int and new_curse_count >= 0) else 0
	corruption = new_corruption if (new_corruption is int and new_corruption >= 0) else 0
	oath_shard_eligible = new_oath_shard_eligible
	risk_flags = _normalize_risk_flags(new_risk_flags)


# Build a fresh state whose eligibility derives from the run's manual-seed flag (the canonical init RunState uses).
# A manual-seed run is NEVER Oath-Shard eligible (the GDD invariant), in lockstep with meta_progression_eligible.
static func for_run(is_manual_seed: bool) -> RiskEconomyState:
	return load("res://scripts/run/risk_economy_state.gd").new(0, 0, 0, 0, not is_manual_seed, [])


# AC1 invariant: the Oath-Shard eligibility gate must match the run's manual-seed flag (a manual-seed run is NEVER
# eligible — mirroring RunState.validate()'s meta_progression_eligible != not is_manual_seed check). RunState.validate()
# calls this with its own is_manual_seed so the economy eligibility can never silently diverge from the run's. Pure
# read: no mutation, no event, no RNG.
func validate(is_manual_seed: bool) -> ActionResult:
	if oath_shard_eligible != (not is_manual_seed):
		return ActionResult.error(&"invalid_oath_shard_eligibility", {
			"field": "oath_shard_eligible",
			"is_manual_seed": is_manual_seed,
			"oath_shard_eligible": oath_shard_eligible
		})
	return ActionResult.ok()


# AC2 mutation: credit gold (positive) or spend gold (negative). Returns the post-change gold, or -1 WITHOUT mutating
# when the change would drive gold below 0 (the caller validates first — ApplyEconomyChangeCommand checks can_apply_*
# before calling). A pure additive int change (no RNG, no roll — a recorded amount).
func apply_gold_delta(delta: int) -> int:
	if gold + delta < 0:
		return -1
	gold += delta
	return gold


# AC2 mutation: add (positive) or spend (negative) healing availability. Same floor-guarded contract as
# apply_gold_delta (-1 + no mutation when the change would drive healing below 0).
func apply_healing_delta(delta: int) -> int:
	if healing_charges + delta < 0:
		return -1
	healing_charges += delta
	return healing_charges


# Whether a gold change of `delta` is applicable (would not drive gold below 0). The command checks this in
# validate() (a pure read) so a reject leaves the state byte-identical.
func can_apply_gold_delta(delta: int) -> bool:
	return gold + delta >= 0


# Whether a healing change of `delta` is applicable (would not drive healing below 0).
func can_apply_healing_delta(delta: int) -> bool:
	return healing_charges + delta >= 0


# Story 7.2 STRUCTURAL setter (curse rules are 7.2): set the curse count to a non-negative value (a negative clamps
# to 0). 7.1 introduces only the structural setter; 7.2 authors WHEN/WHY a curse applies.
func set_curse_count(value: int) -> void:
	curse_count = value if value >= 0 else 0


# Story 7.2 STRUCTURAL setter: set the corruption count to a non-negative value (a negative clamps to 0).
func set_corruption(value: int) -> void:
	corruption = value if value >= 0 else 0


# Story 7.3 STRUCTURAL setter (the event roll is 7.3): add a lower_snake risk-flag id (idempotent — a duplicate is
# not re-added; a blank/non-lower_snake id is ignored). 7.1 introduces only the container + this setter; 7.3 produces
# the flags via the event-choice roll.
func add_risk_flag(flag_id: StringName) -> void:
	var text: String = String(flag_id)
	if not _is_lower_snake_id(text):
		return
	if not risk_flags.has(text):
		risk_flags.append(text)


# Whether a risk flag id is present (future systems query this).
func has_risk_flag(flag_id: StringName) -> bool:
	return risk_flags.has(String(flag_id))


# Exact-key serialization (the InventoryState / StartingKit precedent). The counts are small bounded ints (NOT seeds
# — no int64/decimal-string encoding). A FRESH dictionary (with a deep-copied risk_flags) is returned each call so a
# mutation of the returned dict never perturbs the model.
func to_dictionary() -> Dictionary:
	return {
		"gold": gold,
		"healing_charges": healing_charges,
		"curse_count": curse_count,
		"corruption": corruption,
		"oath_shard_eligible": oath_shard_eligible,
		"risk_flags": risk_flags.duplicate()
	}


# Lenient reconstruction (mirrors InventoryState.try_from_dictionary leniency): a missing/invalid count defaults to 0,
# a missing/non-bool eligibility defaults to true, a missing/non-array risk_flags defaults to empty — so a
# partial/pre-7.1 dict still parses. Returns a RiskEconomyState (never null) — a value object, not a validated domain
# entity, so it has no reject path.
static func try_from_dictionary(data: Dictionary) -> RiskEconomyState:
	return load("res://scripts/run/risk_economy_state.gd").new(
		_int_or_zero(data.get("gold", 0)),
		_int_or_zero(data.get("healing_charges", 0)),
		_int_or_zero(data.get("curse_count", 0)),
		_int_or_zero(data.get("corruption", 0)),
		_bool_or_true(data.get("oath_shard_eligible", true)),
		data.get("risk_flags", [])
	)


# Deep copy (the risk_flags list is deep-copied so a copy never shares mutable state with the source — mutating the
# copy's flags must not perturb the source).
func copy() -> RiskEconomyState:
	return load("res://scripts/run/risk_economy_state.gd").new(
		gold,
		healing_charges,
		curse_count,
		corruption,
		oath_shard_eligible,
		risk_flags
	)


# Normalize an arbitrary risk_flags input into a clean Array[String] of lower_snake ids (dedup, drop blanks /
# non-strings / non-lower_snake). Deep-copies (no shared reference with the input).
static func _normalize_risk_flags(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if not raw is Array:
		return result
	for entry: Variant in (raw as Array):
		if not (entry is String or entry is StringName):
			continue
		var text: String = String(entry)
		if not _is_lower_snake_id(text):
			continue
		if not result.has(text):
			result.append(text)
	return result


# Lenient int decode (gold / healing / curse / corruption): accept an int / integral-float / decimal-string, clamp a
# negative to 0, else 0. Mirrors InventoryState._int_or_default with a 0 floor.
static func _int_or_zero(value: Variant) -> int:
	var parsed: int = 0
	match typeof(value):
		TYPE_INT:
			parsed = int(value)
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return 0
			parsed = int(numeric_value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value)
			if text.is_valid_int():
				parsed = text.to_int()
			else:
				return 0
		_:
			return 0
	return parsed if parsed >= 0 else 0


static func _bool_or_true(value: Variant) -> bool:
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return true


# Local lower_snake id check (matches DomainEvent._is_lower_snake_id / the content-id shape): non-empty, all
# [a-z0-9_], no hyphens.
static func _is_lower_snake_id(value: String) -> bool:
	if value.is_empty():
		return false
	if value != value.to_lower():
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true
