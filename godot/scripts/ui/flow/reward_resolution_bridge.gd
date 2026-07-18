class_name RewardResolutionBridge
extends RefCounted

# Story 13.2 — the scene-free REWARD-RESOLUTION bridge (AC1/AC2). It is the CALLER-DRIVEN run-command seam the
# reward/passive resolution commands were always waiting for (the Epic-6 commands are pure caller-driven commands
# with NO orchestrator convenience method — project-context.md:191): it takes a resolution intent from a click and
# CONSTRUCTS + EXECUTES the EXACTLY-ONE run-domain command that resolves the run's pending offer, threading the
# monotonic run-level sequence_id from the orchestrator. It mirrors RunEndProfileBridge's construct+execute+
# sequence_id idiom (a run command executed against RunState with next_sequence_id()); it is NOT a
# TacticalCommandBridge intent (that bridge handles only move/attack/inspect against a TacticalActionContext).
#
# THE EXACTLY-ONE-COMMAND CONTRACT (project-context.md:195/446 — a pending offer is resolved by exactly one of
# {ResolveRewardCommand | DeclineRewardCommand | ConsumePassiveCommand | DestroyPassiveCommand}, never two, never a
# double-record):
#   - action == resolve_generic -> ResolveRewardCommand (a NON-passive single-pick offer: backpack item / gold /
#     outcome-only passive). Draws ZERO new RNG (the offer was rolled at GENERATE). A full backpack surfaces the
#     pickup's inventory_full VERBATIM and leaves the offer `pending` (no silent advance — the caller re-renders).
#   - action == decline_generic -> DeclineRewardCommand (Story 14.7 — the full-backpack escape hatch): clears the
#     pending offer WITHOUT applying it (never touches the backpack, so it can never hit inventory_full) and flips
#     the offer `resolved` so the run advances. Draws ZERO RNG. Generic-path only (a passive offer never routes here).
#   - action == commit_passive + choice == consume -> ConsumePassiveCommand (adopts the passive into the run's
#     RulesResolver). Draws ZERO RNG.
#   - action == commit_passive + choice == destroy -> DestroyPassiveCommand (rolls the 70/20/10 outcome through the
#     run-level `streams` on STREAM_REWARDS — ONE draw — with the baseline DestroyOutcomeTableDefinition).
#   - a NON-committed intent (cancel/dismiss, committed == false) runs NO command -> the RunState is byte-identical
#     (AC2 no-mutation). The two-step arm/confirm/cancel lives in PassiveRewardCommitFlow (the presenter owns it);
#     this bridge only executes the CONFIRMED intent.
#
# PURE run-command execution: it holds NO RunState, draws no RNG of its own, and adds no domain command/event/stream.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ConsumePassiveCommand = preload("res://scripts/core/commands/consume_passive_command.gd")
const DeclineRewardCommand = preload("res://scripts/core/commands/decline_reward_command.gd")
const DestroyOutcomeTableDefinition = preload("res://scripts/content/definitions/destroy_outcome_table_definition.gd")
const DestroyPassiveCommand = preload("res://scripts/core/commands/destroy_passive_command.gd")
const PassiveRewardCommitFlow = preload("res://scripts/ui/view_models/passive_reward_commit_flow.gd")
const ResolveRewardCommand = preload("res://scripts/core/commands/resolve_reward_command.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

const ACTION_RESOLVE_GENERIC := "resolve_generic"
const ACTION_COMMIT_PASSIVE := "commit_passive"
# Story 14.7: the generic-overlay DECLINE/skip action — clears the pending offer WITHOUT applying it (the
# full-backpack escape hatch), executing EXACTLY ONE DeclineRewardCommand. Generic-path only (a passive offer never
# routes here — it always resolves via Consume/Destroy), so the exactly-one-command contract is preserved.
const ACTION_DECLINE_GENERIC := "decline_generic"

# Resolve the pending offer from a click intent. `resolution` carries `action` (resolve_generic / commit_passive)
# plus the per-action fields. Returns the executed command's ActionResult VERBATIM (so the caller reads
# inventory_full / a destroy outcome / a consume record), a no-command ok for a non-committed intent (AC2), or a
# structured error for a malformed context/action. Executes EXACTLY ONE run command (never two).
func resolve(run: RunState, orchestrator: RunOrchestrator, resolution: Dictionary) -> ActionResult:
	if run == null or orchestrator == null:
		return ActionResult.error(&"invalid_reward_resolution_context", {
			"command": "reward_resolution_bridge"
		})
	var action: String = String(resolution.get("action", ""))
	match action:
		ACTION_RESOLVE_GENERIC:
			return _resolve_generic(run, orchestrator, resolution)
		ACTION_DECLINE_GENERIC:
			return _decline_generic(run, orchestrator)
		ACTION_COMMIT_PASSIVE:
			return _commit_passive(run, orchestrator, resolution)
		_:
			return ActionResult.error(&"unsupported_reward_resolution", {
				"command": "reward_resolution_bridge",
				"action": action
			})


# The generic (non-passive) resolve path: construct + execute ResolveRewardCommand against RunState, threading the
# monotonic run-level sequence_id. The command applies the selected offered entry by category and flips the offer to
# `resolved` (or surfaces inventory_full and leaves it pending). Draws ZERO new RNG.
func _resolve_generic(run: RunState, orchestrator: RunOrchestrator, resolution: Dictionary) -> ActionResult:
	var category: StringName = StringName(String(resolution.get("category", "")))
	var content_id: StringName = StringName(String(resolution.get("content_id", "")))
	return ResolveRewardCommand.new(category, content_id, orchestrator.next_sequence_id()).execute(run)


# The generic (non-passive) DECLINE path (Story 14.7): construct + execute EXACTLY ONE DeclineRewardCommand against
# RunState, threading the monotonic run-level sequence_id. The command clears the pending offer WITHOUT applying it
# (never touches the backpack, so it can never hit inventory_full — the full-backpack escape hatch) and flips the
# offer to `resolved` so the run can advance. Draws ZERO RNG. A decline picks NO entry, so the intent carries no
# category/content_id.
func _decline_generic(run: RunState, orchestrator: RunOrchestrator) -> ActionResult:
	return DeclineRewardCommand.new(orchestrator.next_sequence_id()).execute(run)


# The passive Consume/Destroy path: route the CONFIRMED commit-intent to EXACTLY ONE of Consume/Destroy. A
# non-committed intent (cancel/dismiss) runs NO command -> byte-identical RunState (AC2).
func _commit_passive(run: RunState, orchestrator: RunOrchestrator, resolution: Dictionary) -> ActionResult:
	if not bool(resolution.get("committed", false)):
		# AC2 — a non-committed intent produces no command; the run is unmutated.
		return ActionResult.ok([], {
			"reward_resolution": "no_command",
			"reason": "not_committed"
		})
	var choice: String = String(resolution.get("choice", ""))
	var passive_content_id: StringName = StringName(String(resolution.get("passive_content_id", "")))
	var table_id: StringName = StringName(String(resolution.get("table_id", "")))
	match choice:
		PassiveRewardCommitFlow.CHOICE_CONSUME:
			# Consume -> adopt the passive into the run's RulesResolver. ZERO RNG.
			return ConsumePassiveCommand.new(
				passive_content_id,
				table_id,
				orchestrator.next_sequence_id()
			).execute(run)
		PassiveRewardCommitFlow.CHOICE_DESTROY:
			# Destroy -> roll the 70/20/10 outcome through the run-level `streams` on STREAM_REWARDS (ONE draw). The
			# run-level streams are MANDATORY (never a fresh RandomNumberGenerator) so a route-position resume round-trips.
			return DestroyPassiveCommand.new(
				passive_content_id,
				table_id,
				orchestrator.next_sequence_id(),
				orchestrator.streams,
				DestroyOutcomeTableDefinition.create_baseline_table()
			).execute(run)
		_:
			return ActionResult.error(&"unsupported_passive_choice", {
				"command": "reward_resolution_bridge",
				"choice": choice
			})
