class_name MetaAwardRules
extends RefCounted

# Story 8.3 (AC1, AC3) — the Oath-Shard award CALCULATION from approved rules. A PURE, DETERMINISTIC, CAPPED, SPARSE
# calculator: it reads the terminal RunState (its terminal phase) + the RunSummary (a bounded, non-difficulty run
# signal — nodes_cleared) and returns the Oath-Shard amount an ELIGIBLE run's award APPLICATION would grant. It draws
# ZERO RNG (no randi/randf/RandomNumberGenerator — same terminal run → same award; the named-RNG rule + the whole-epic
# determinism invariant), submits NO command, mutates NOTHING.
#
# ⭐ THE v0 AWARD RULE ([Decision] — recorded in the story Completion Notes) satisfies AC3 "capped, sparse, secondary;
# raw-stat ladders REJECTED":
#   - A COMPLETED run (RunState.PHASE_COMPLETED — the hero finished/won): a small linear-in-nodes-cleared grant with a
#     HARD CAP: min(BASE_AWARD + PER_NODE_AWARD * nodes_cleared, MAX_AWARD). nodes_cleared is a BOUNDED run signal
#     (Story 8.2's RunSummary.run_scoped.nodes_cleared — a route has a bounded node count), and the MAX_AWARD cap makes
#     the award UNCONDITIONALLY bounded regardless of the signal (AC3 "capped"). A short run trickles a little; a long
#     run trickles a little more, up to the cap — SPARSE, a shallow trickle that expands OPTIONS over time (the user
#     story "without becoming a stat grind"; AC3 "sparse + secondary to variety").
#   - A FAILED run (RunState.PHASE_FAILED — the hero died): 0 ([Decision] — a death awards NOTHING this story; the
#     currency rewards finishing/reaching an ending, not dying. A future story MAY grant a small consolation, but v0
#     keeps the currency tied to completion so the trickle stays sparse). A death is a terminal run but yields 0 here.
#   - WHY IT IS NOT A RAW-STAT LADDER (AC3 second half): Oath Shards are a CURRENCY toward variety/knowledge/options
#     (spent in a later unlock story on classes/loot-pools/passives/secrets/codex/starting-options), NOT a direct
#     combat stat. 8.3 AWARDS the currency; it applies NO damage/max-HP/armor/crit/dodge upgrade and builds NO
#     unlock-spend tree. The award is a bounded currency grant, so the "broad raw-stat ladders rejected for MVP" rule
#     is satisfied structurally.
#   - It does NOT scale by DIFFICULTY (difficulty is a hard non-goal) — nodes_cleared is a progress signal, not a
#     difficulty knob, and nothing here reads a difficulty setting.
#
# The APPLICATION gate (AwardMetaProgressCommand) decides WHETHER to apply this amount (a manual-seed run is denied at
# the eligibility gate — the calculator is a pure amount; the gate decides whether to apply it). A manual-seed run's
# amount is NEVER applied regardless of what this returns (Gate 2, FR28/AC4).

const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

# The base grant for reaching an ending (a completed run). A small sparse floor.
const BASE_AWARD: int = 1
# The per-cleared-node grant (a bounded run signal — nodes_cleared). Small: the award is a trickle, not a grind.
const PER_NODE_AWARD: int = 1
# The HARD CAP per run (AC3 "capped"): the award can NEVER exceed this regardless of the run signal. A shallow ceiling
# keeps meta power sparse + secondary.
const MAX_AWARD: int = 5

# The Oath-Shard amount an eligible run's award would grant. PURE + DETERMINISTIC + CAPPED. A COMPLETED run yields
# min(BASE + PER_NODE * nodes_cleared, MAX_AWARD); a FAILED (death) run yields 0; a non-terminal / null run yields 0
# (there is no ended run to reward). This is the AMOUNT ONLY — the APPLICATION gate (AwardMetaProgressCommand) enforces
# eligibility (a manual-seed run is denied) + idempotency (no double-award). Draws ZERO RNG.
static func oath_shard_award_for(run: RunState, summary: RunSummary) -> int:
	if run == null or not run.is_terminal():
		return 0
	# A death (PHASE_FAILED) awards nothing this story ([Decision]).
	if run.phase != RunState.PHASE_COMPLETED:
		return 0

	var nodes_cleared: int = _nodes_cleared_from(summary)
	var raw_award: int = BASE_AWARD + PER_NODE_AWARD * nodes_cleared
	return _clamp_to_cap(raw_award)


# Read the bounded nodes-cleared signal off the summary's run_scoped sub-dict (Story 8.2). A null/malformed summary
# yields 0 nodes (a fail-safe floor — the award is then just the BASE grant for a completed run). A non-negative int.
static func _nodes_cleared_from(summary: RunSummary) -> int:
	if summary == null:
		return 0
	var run_scoped: Dictionary = summary.run_scoped
	var value: Variant = run_scoped.get("nodes_cleared", 0)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	var nodes: int = int(value)
	return nodes if nodes >= 0 else 0


# Clamp an award to [0, MAX_AWARD] (AC3 cap enforcement). A negative floors to 0 (defensive; the rule never produces a
# negative), an over-cap clamps to MAX_AWARD.
static func _clamp_to_cap(amount: int) -> int:
	if amount < 0:
		return 0
	if amount > MAX_AWARD:
		return MAX_AWARD
	return amount
