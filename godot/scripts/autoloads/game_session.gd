extends Node

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")

signal run_seed_configured(root_seed: int)

var _root_seed: int = 0
var _rng_streams: RngStreamSet = RngStreamSet.new()

# Story 11.3: the live RUN-FLOW controller handle, held across scene changes (the app-flow walks separate scenes:
# hero select -> route map -> tactical board -> run end, each a fresh scene tree, so the sequencer that owns the
# live run must outlive an individual scene). This is a HANDLE, not a gameplay decision — GameSession stays thin
# (it owns no run truth; the RunFlowController sequences the RunOrchestrator, which owns the run state). A
# presenter reads/sets it via run_flow()/set_run_flow(); it is null before a run starts. Typed loosely
# (RefCounted) to avoid a preload cycle (RunFlowController preloads run/ui types this thin autoload should not
# pull into its own load graph).
var _run_flow: RefCounted = null

func configure_seed(new_root_seed: int) -> void:
	_root_seed = new_root_seed
	_rng_streams.configure(_root_seed)
	run_seed_configured.emit(_root_seed)


func get_root_seed() -> int:
	return _root_seed


func rng_snapshot() -> Dictionary:
	return _rng_streams.to_snapshot()


func restore_rng_snapshot(snapshot: Dictionary) -> ActionResult:
	var result: ActionResult = _rng_streams.try_restore(snapshot)
	if result.succeeded:
		# root_seed is int64-safe and is encoded as a decimal STRING by RngStreamSet.to_snapshot()
		# (Story 2.7). A raw int(...) cast on a >2^53 seed would silently truncate it; try_restore
		# has already validated and decoded the seed losslessly, so read the canonical value it
		# returns rather than re-coercing the raw snapshot field.
		_root_seed = int(result.metadata.get("root_seed", _root_seed))
	return result


# Story 11.3: the live RunFlowController handle (or null before a run starts). A pure read — a presenter reads it
# to drive the flow; GameSession owns no run truth.
func run_flow() -> RefCounted:
	return _run_flow


# Story 11.3: set/clear the live RunFlowController handle (set by the hero-select confirm when a run starts;
# cleared at a run-end return). A HANDLE assignment — no gameplay decision.
func set_run_flow(run_flow_controller: RefCounted) -> void:
	_run_flow = run_flow_controller


# Story 11.3: clear the live run-flow handle (a run-end return resets it so a fresh descent starts clean).
func clear_run_flow() -> void:
	_run_flow = null
