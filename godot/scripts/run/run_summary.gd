class_name RunSummary
extends RefCounted

# Story 8.2 (AC1-AC5) — the scene-free RUN-SUMMARY read AGGREGATOR / read surface. It is the "review what happened"
# half of Epic 8: a single, pure-read, serializable DOMAIN DTO that AGGREGATES "what happened during the run" from the
# terminal RunState + the run's ordered DOMAIN EVENT stream into the FR60 field set, so a later outpost/run-summary UI
# (Story 8.6) can PRESENT it and so the later meta-award path (Story 8.3) has a canonical summary to READ.
#
# ⭐ THE SINGLE MOST IMPORTANT ARCHITECTURAL FACT — RunSummary is a PURE READ AGGREGATOR. It builds NO new domain
# state, NO new event, NO new save key, NO command, NO mutation, and NO RNG. It is a read-only projection over data
# that ALREADY EXISTS:
#   - The run-END facts Story 8.1 shipped: run_failed.cause / run_completed.outcome (the events) + the terminal
#     RunState.phase (completed/failed). These are the "cause of death or victory" input.
#   - The accumulated run STATE: route.cleared_node_ids (nodes cleared), route node types (boss/elite progress via
#     RouteNode.TYPE_BOSS / TYPE_ELITE_COMBAT), root_seed (seed), meta_progression_eligible (manual-seed eligibility),
#     risk_economy (gold / curse_count / corruption — run-scoped economy readouts).
#   - The run's DOMAIN EVENT stream: passive_consumed / passive_destroyed (passives consumed & destroyed) and
#     item_gained / reward_resolved (notable loot). ⭐ These lists have NO persisted home in v0 (RunState has no
#     consumed-passive list; RunSnapshot.passives/curses are EMPTY placeholders), so the summary DERIVES them from the
#     event records the run emitted — EXACTLY what AC2 mandates ("domain state and event records rather than
#     presentation logs as source truth").
#
# WHAT IT IS:
#   - RunSummary.build(run, events): a PURE read that takes the terminal RunState + the run's ordered Array of
#     DomainEvent the caller collected across the run, and returns the aggregated summary. to_dictionary() projects the
#     EXACT pinned DICTIONARY_KEYS set (a key never silently appears/vanishes; pinned by test_run_summary.gd), mirroring
#     the RunEndOutcome exact-key discipline VERBATIM. Repeated builds/reads are byte-identical (pure).
#   - The event list is an EXPLICIT PARAMETER ([Decision]): v0 has NO run-level event STORE — commands RETURN their
#     events in ActionResult.events and the RunOrchestrator threads sequence ids but does NOT accumulate a run log. So
#     build ACCEPTS the ordered event list the caller (a test today; a later HUD/run-flow layer tomorrow) supplies. It
#     does NOT read CombatExplanationLog / any presentation log as source truth (AC2 forbids it). It does NOT add a
#     persisted event-log field to RunState / RunSnapshot (a larger save-shape decision — Story 8.7 territory).
#   - The cause/outcome ([Decision]): the unified outcome_or_cause is DERIVED from the terminal run-end event in the
#     supplied list when present (scan for Type.RUN_FAILED -> payload.cause, Type.RUN_COMPLETED -> payload.outcome),
#     mirroring how RunOrchestrator.resolve_run_end captures it from resolved.events — so the summary is self-consistent
#     with the events it aggregates. The terminal phase comes from RunState.phase.
#
# AC3 — EXPLICIT STATE BOUNDARIES; replay/debug cannot grant progress. The summary READS three DISTINCT state kinds and
# keeps them SEPARABLE in the output (run_scoped / profile_meta / content_unlock sub-dicts):
#   1. run_scoped — this run's RunState + its events (cause/nodes-cleared/loot/passives/economy).
#   2. profile_meta — the cross-run profile (Oath Shards AWARDED, mastery). DOES NOT EXIST YET (Story 8.3). The summary
#      reports the AWARDED count as 0 read from NO profile. It creates/mutates/grants NOTHING.
#   3. content_unlock — Echoes / Seal-Fragments / unlock flags. DOES NOT EXIST YET (Story 8.4). Reported empty;
#      read-only; granted NOTHING.
#   The AC3 "replay/debug state cannot accidentally grant profile or unlock progress" is satisfied STRUCTURALLY because
#   the summary is a PURE READ that mutates nothing and awards nothing — a manual-seed (replay/practice) run's summary
#   reports meta_progression_eligible == false and the SAME 0/empty award/unlock fields as any other v0 run, and
#   building it grants nothing regardless of eligibility. The summary is the read seam the 8.3 award path sits IN FRONT
#   of (8.3 reads eligibility + the summary, THEN awards behind the 8.1 idempotency guard); 8.2 itself never awards.
#
# AC1/AC5 — the NOT-YET-SUPPORTED future fields. Several FR60 fields have NO v0 domain source. Each appears as a stable
# zero/empty value that CANNOT be mistaken for a real award AND is named in not_yet_supported (a machine-detectable
# limitation signal) so the Epic-10 readiness pass (Story 10.7, which names Story 8.2) can enumerate them and the
# outpost UI (8.6) can render an honest note:
#   - oath_shards_earned -> 0 (awarding is Story 8.3; RunSnapshot.oath_shards stays the 0 AWARDED-count placeholder).
#   - echoes_discovered -> [] (Story 8.4; no Echo domain content exists yet).
#   - unlock_progress -> [] (Story 8.4; no unlock-progress domain state exists yet).
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO command, draws NO RNG (ZERO randi/randf/RandomNumberGenerator), emits NO
#     event, and mutates nothing — repeated reads are identical (the RunEndOutcome / AffinityViewModel exact-key,
#     no-live-handle, fail-closed discipline). It is NOT a scene/Control/.tscn (the outpost/summary screen is Story 8.6;
#     UI-scene-last). It is NOT a save snapshot (DERIVED on demand, NOT persisted; it adds no RunSnapshot key — the
#     23-key gate stays 23; a save-persist need is Story 8.7).
#   - It does NOT AWARD Oath Shards / build the meta profile (8.3), does NOT author Echo/unlock content (8.4), does NOT
#     build the outpost menu scene (8.6), and does NOT deliver the first-death narrative line (8.5).
#
# A null / non-terminal (not run.is_terminal()) run projects the fail-closed empty fact (has_summary == false + empty/
# zero fields) so a consumer can branch on has_summary without inspecting the empty fields (the RunEndOutcome._empty()
# discipline) — NEVER a crash, NEVER a half-fact.

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The EXACT top-level key set of every projection (the RunEndOutcome.DICTIONARY_KEYS / AffinityViewModel.MODAL_KEYS
# exact-key discipline — a key never silently appears/vanishes; the set is pinned by test_run_summary.gd). has_summary
# gates whether the other fields are meaningful. The three state-boundary sub-dicts (run_scoped / profile_meta /
# content_unlock) keep the AC3 state kinds SEPARABLE. not_yet_supported names the AC1/AC5 tracked placeholder fields.
const DICTIONARY_KEYS: Array[String] = [
	"has_summary",
	"phase",
	"outcome_or_cause",
	"seed",
	"is_manual_seed",
	"meta_progression_eligible",
	"run_scoped",
	"profile_meta",
	"content_unlock",
	"not_yet_supported"
]

# The EXACT key set of the run_scoped sub-dict (this run's RunState + event facts — the REAL v0 fields). Pinned by test.
const RUN_SCOPED_KEYS: Array[String] = [
	"nodes_cleared",
	"boss_cleared",
	"elite_nodes_cleared",
	"passives_consumed",
	"passives_destroyed",
	"notable_loot",
	"gold",
	"curse_count",
	"corruption"
]

# The EXACT key set of the profile_meta sub-dict (the cross-run profile readout — Story 8.3 owns the profile; v0 reads
# NO profile and reports the AWARDED Oath-Shard count as 0). Pinned by test.
const PROFILE_META_KEYS: Array[String] = [
	"oath_shards_earned"
]

# The EXACT key set of the content_unlock sub-dict (the Echoes / unlock readout — Story 8.4 owns the content; v0 reads
# NO unlock state and reports empty lists). Pinned by test.
const CONTENT_UNLOCK_KEYS: Array[String] = [
	"echoes_discovered",
	"unlock_progress"
]

# The stable machine-detectable names of the not-yet-supported placeholder fields (AC1/AC5). The Epic-10 readiness pass
# (Story 10.7) enumerates these; the outpost UI (8.6) renders an honest limitation note from them. A placeholder value
# (0 / []) is structurally impossible to mistake for a real award/unlock, AND is named here so it is TRACKED.
const NOT_YET_SUPPORTED_FIELDS: Array[String] = [
	"oath_shards_earned",
	"echoes_discovered",
	"unlock_progress"
]

# Whether the run actually ended (a terminal phase) and a summary is meaningful. A null / non-terminal source run
# projects has_summary == false + empty/zero fields (fail-closed).
var has_summary: bool = false
# The run's terminal phase (RunState.PHASE_COMPLETED / PHASE_FAILED), or "" for a non-terminal source run.
var phase: StringName = &""
# The unified run-end marker: the run_completed outcome (a completion, e.g. completed / boss_placeholder) OR the
# run_failed cause (a death, e.g. hero_death). "" for a non-terminal source run OR when no terminal run-end event is
# present in the supplied event list.
var outcome_or_cause: StringName = &""
# The run's root seed (a full int64), named for parity with RunState.root_seed (the source field). Decimal-string
# encoded in to_dictionary() under the pinned "seed" key (JSON IEEE-754 doubles truncate beyond 2^53). 0 for an empty
# fact. (Named root_seed rather than `seed` to avoid shadowing GDScript's built-in global seed() RNG function in a
# codebase with a strict named-RNG-streams-only / ZERO-randi/randf discipline.)
var root_seed: int = 0
# Whether the run used a manual/debug seed (a replay/practice readout). false for an empty fact.
var is_manual_seed: bool = false
# The run's Oath-Shard / meta-progression eligibility (READ from run.meta_progression_eligible — lockstep with
# is_manual_seed). REPORTED only (AC2); the summary grants/denies NOTHING (Story 8.3 owns the awarding). false for an
# empty fact.
var meta_progression_eligible: bool = false
# AC3 boundary 1 — the run-scoped facts (this run's RunState + events): nodes_cleared, boss_cleared,
# elite_nodes_cleared, passives_consumed, passives_destroyed, notable_loot, gold, curse_count, corruption.
var run_scoped: Dictionary = {}
# AC3 boundary 2 — the profile/meta readout (Story 8.3 owns the profile): oath_shards_earned (0 AWARDED; read from NO
# profile). The summary reports the AWARDED count; it does NOT award.
var profile_meta: Dictionary = {}
# AC3 boundary 3 — the content-unlock readout (Story 8.4 owns the content): echoes_discovered ([]), unlock_progress
# ([]). Read from NO unlock state; granted NOTHING.
var content_unlock: Dictionary = {}
# AC1/AC5 — the tracked not-yet-supported placeholder field names (a machine-detectable limitation signal).
var not_yet_supported: Array[String] = []

func _init(
	new_has_summary: bool = false,
	new_phase: StringName = &"",
	new_outcome_or_cause: StringName = &"",
	new_seed: int = 0,
	new_is_manual_seed: bool = false,
	new_meta_progression_eligible: bool = false,
	new_run_scoped: Dictionary = {},
	new_profile_meta: Dictionary = {},
	new_content_unlock: Dictionary = {},
	new_not_yet_supported: Array = []
) -> void:
	has_summary = new_has_summary
	phase = new_phase
	outcome_or_cause = new_outcome_or_cause
	root_seed = new_seed
	is_manual_seed = new_is_manual_seed
	meta_progression_eligible = new_meta_progression_eligible
	run_scoped = new_run_scoped.duplicate(true)
	profile_meta = new_profile_meta.duplicate(true)
	content_unlock = new_content_unlock.duplicate(true)
	not_yet_supported = _copy_string_array(new_not_yet_supported)


# Build the run summary (AC1-AC5): AGGREGATE the FR60 field set from the TERMINAL run STATE + the supplied ordered
# DOMAIN EVENT list. A PURE read — draws NO RNG, runs NO command, emits NO event, mutates NOTHING (not the run, not the
# events). A null / non-terminal run projects the fail-closed empty fact (has_summary == false) so a consumer branches
# on has_summary without inspecting empty fields.
#
# `events` is an EXPLICIT ordered Array of DomainEvent the caller collected across the run (v0 has no run-level event
# store). Received as an untyped Array and type-checked per element (the Array[Dictionary]/ActionResult deep-copy
# footgun analogue — be tolerant of the element type; a non-DomainEvent entry is ignored).
static func build(run: RunState, events: Array = []) -> RunSummary:
	if run == null or not run.is_terminal():
		return _empty()

	# ---- cause/outcome (AC1): derive the unified run-end marker from the terminal run-end event in the supplied list.
	# A failed run carries its run_failed.cause; a completed run carries its run_completed.outcome. Mirror how
	# RunOrchestrator.resolve_run_end captures it from resolved.events (self-consistent with the events aggregated).
	var outcome_or_cause_marker: StringName = _derive_outcome_or_cause(run, events)

	# ---- event-derived lists (AC1/AC2): scan the supplied event list ONCE. These have NO persisted home in v0 — the
	# events ARE the source truth (AC2). Read the exact payload field names from domain_event.gd (do NOT guess).
	var passives_consumed: Array[String] = []
	var passives_destroyed: Array[String] = []
	var notable_loot: Array[Dictionary] = []
	for event_value: Variant in events:
		if not (event_value is DomainEvent):
			continue
		var event: DomainEvent = event_value
		var event_payload: Dictionary = event.payload
		match event.event_type:
			DomainEvent.Type.PASSIVE_CONSUMED:
				# passive_consumed -> payload.passive_id (deterministic; no draw provenance).
				passives_consumed.append(String(event_payload.get("passive_id", "")))
			DomainEvent.Type.PASSIVE_DESTROYED:
				# passive_destroyed -> payload.passive_id (the identifying id; a flat id list mirroring passives_consumed).
				passives_destroyed.append(String(event_payload.get("passive_id", "")))
			DomainEvent.Type.ITEM_GAINED:
				# item_gained -> a backpack pickup: payload.item_id + payload.category (∈ ITEM_GAINED_CATEGORIES). This is
				# the SOLE notable-loot source: every backpack item the run gained emits an item_gained (a direct board
				# pickup emits ONLY item_gained; a reward->backpack pickup emits an item_gained via the composed
				# PickupItemCommand). So each gained item is counted EXACTLY once here.
				notable_loot.append({
					"item_id": String(event_payload.get("item_id", "")),
					"category": String(event_payload.get("category", "")),
					"source": "item_gained"
				})
			DomainEvent.Type.REWARD_RESOLVED:
				# reward_resolved -> a resolved reward offer: payload.content_id + payload.category (∈ REWARD_CATEGORIES,
				# which is the backpack set PLUS gold/passive). [Decision, round 1 review] EXCLUDE reward_resolved from
				# notable_loot ENTIRELY (all REWARD_CATEGORIES): gold is an economy readout (surfaced via run_scoped.gold),
				# a passive is consumed/destroyed (already tracked in passives_consumed/passives_destroyed), and a
				# BACKPACK-category reward ALREADY emits a paired item_gained (ResolveRewardCommand composes PickupItemCommand
				# with sequence_id + 1) — so scanning the reward_resolved too would DOUBLE-COUNT the same physical item. The
				# item_gained arm above records every gained item exactly once; a direct board pickup emits only item_gained,
				# so nothing is lost by excluding reward_resolved here. Keeps the list honest (it lists gained ITEMS the
				# events record, not a curated ranking; curation is a later content/UX concern).
				pass
			_:
				# An unrelated event (entity_moved, damage_applied, run_started, ...) is ignored — a mixed event list
				# must not pollute the summary lists.
				pass

	# ---- route-derived facts (AC1): nodes cleared + boss/elite progress from the route cross-referenced with the
	# cleared set. Boss progress = a cleared TYPE_BOSS node; elite progress = the count of cleared TYPE_ELITE_COMBAT
	# nodes. Prefer deriving boss progress from the ROUTE (a cleared boss node) rather than a run_completed payload field
	# (run_completed no longer always carries boss_node_id — it is boss_placeholder-only; the 8.1 BREAKING heads-up).
	var route: RouteState = run.route
	var cleared_ids: Array[String] = []
	if route != null:
		cleared_ids = route.cleared_node_ids
	var nodes_cleared: int = cleared_ids.size()
	var boss_cleared: bool = false
	var elite_nodes_cleared: int = 0
	if route != null:
		for cleared_id: String in cleared_ids:
			var node: RouteNode = route.node_by_id(cleared_id)
			if node == null:
				continue
			if node.type == RouteNode.TYPE_BOSS:
				boss_cleared = true
			elif node.type == RouteNode.TYPE_ELITE_COMBAT:
				elite_nodes_cleared += 1

	# ---- economy readouts (AC1): run-scoped gold / curse_count / corruption (a readout, NOT an award). Read-only.
	var economy: RiskEconomyState = run.risk_economy
	var gold: int = 0
	var curse_count: int = 0
	var corruption: int = 0
	if economy != null:
		gold = economy.gold
		curse_count = economy.curse_count
		corruption = economy.corruption

	# ---- AC3 boundary 1: the run-scoped facts (all REAL v0 fields).
	var run_scoped_data: Dictionary = {
		"nodes_cleared": nodes_cleared,
		"boss_cleared": boss_cleared,
		"elite_nodes_cleared": elite_nodes_cleared,
		"passives_consumed": passives_consumed,
		"passives_destroyed": passives_destroyed,
		"notable_loot": notable_loot,
		"gold": gold,
		"curse_count": curse_count,
		"corruption": corruption
	}

	# ---- AC3 boundary 2: the profile/meta readout. oath_shards_earned is the AWARDED count — 0 in v0 (awarding is
	# Story 8.3; RunSnapshot.oath_shards stays 0). Read from NO profile (none exists). The summary REPORTS the AWARDED
	# count; the ELIGIBILITY is the top-level meta_progression_eligible (AC2). A placeholder field (AC1/AC5).
	var profile_meta_data: Dictionary = {
		"oath_shards_earned": 0
	}

	# ---- AC3 boundary 3: the content-unlock readout. Echoes / unlock progress are Story 8.4 — no domain source exists
	# yet -> empty lists. Read from NO unlock state; granted NOTHING. Placeholder fields (AC1/AC5).
	var empty_echoes: Array[String] = []
	var empty_unlock: Array[String] = []
	var content_unlock_data: Dictionary = {
		"echoes_discovered": empty_echoes,
		"unlock_progress": empty_unlock
	}

	return load("res://scripts/run/run_summary.gd").new(
		true,
		run.phase,
		outcome_or_cause_marker,
		run.root_seed,
		run.is_manual_seed,
		run.meta_progression_eligible,
		run_scoped_data,
		profile_meta_data,
		content_unlock_data,
		NOT_YET_SUPPORTED_FIELDS.duplicate()
	)


# Exact-key projection (the RunEndOutcome exact-key discipline): plain String/bool/int data only (no live RunState /
# DomainEvent handle leaks out). A FRESH dictionary each call (with deep-copied sub-dicts/lists) so a mutation of the
# returned dict never perturbs this DTO. PURE read. seed is decimal-string encoded (full int64 — JSON doubles truncate
# beyond 2^53); the small bounded counts (nodes_cleared, elite_nodes_cleared, gold, curse_count, corruption,
# oath_shards_earned) stay numeric.
func to_dictionary() -> Dictionary:
	return {
		"has_summary": has_summary,
		"phase": String(phase),
		"outcome_or_cause": String(outcome_or_cause),
		# root_seed is a full int64 -> decimal-string encoded (the epic-wide root_seed JSON-doubles rule). The pinned
		# dictionary KEY stays "seed" (the DICTIONARY_KEYS contract); only the backing member field is named root_seed.
		"seed": str(root_seed),
		"is_manual_seed": is_manual_seed,
		"meta_progression_eligible": meta_progression_eligible,
		"run_scoped": run_scoped.duplicate(true),
		"profile_meta": profile_meta.duplicate(true),
		"content_unlock": content_unlock.duplicate(true),
		"not_yet_supported": not_yet_supported.duplicate()
	}


# Derive the unified outcome_or_cause marker (AC1) from the terminal run-end event in the supplied list, scoped to the
# run's terminal phase: a FAILED run reads the FIRST run_failed.cause; a COMPLETED run reads the FIRST run_completed
# .outcome. Scanning for the terminal-phase's matching event keeps the marker self-consistent with the aggregated events
# (mirroring RunOrchestrator.resolve_run_end). [Decision, round 1 review] FIRST-match (break on the first matching
# terminal run-end event) — a run ends exactly ONCE, so the first matching event IS the run-end fact; breaking is
# self-consistent with that reality and avoids a silent last-wins overwrite on a malformed multi-terminal-event list.
# Returns "" when no matching terminal run-end event is present (a fail-safe: the phase still carries the terminal fact;
# the marker is simply unknown without the event). Pure read.
static func _derive_outcome_or_cause(run: RunState, events: Array) -> StringName:
	var marker: StringName = &""
	if run.phase == RunState.PHASE_FAILED:
		for event_value: Variant in events:
			if not (event_value is DomainEvent):
				continue
			var event: DomainEvent = event_value
			if event.event_type == DomainEvent.Type.RUN_FAILED:
				marker = StringName(String(event.payload.get("cause", "")))
				break
	elif run.phase == RunState.PHASE_COMPLETED:
		for event_value: Variant in events:
			if not (event_value is DomainEvent):
				continue
			var event: DomainEvent = event_value
			if event.event_type == DomainEvent.Type.RUN_COMPLETED:
				marker = StringName(String(event.payload.get("outcome", "")))
				break
	return marker


# The fail-closed empty fact (a null / non-terminal source run): has_summary == false + empty/zero fields + the
# structurally-complete-but-empty sub-dicts, so a consumer branches on has_summary without inspecting the empty fields
# (the RunEndOutcome._empty() discipline). The sub-dicts keep their pinned key shape (empty defaults) so the exact-key
# contract holds for an empty projection too. not_yet_supported still names the tracked placeholder fields (they are
# not-yet-supported regardless of whether a run ended).
static func _empty() -> RunSummary:
	var empty_consumed: Array[String] = []
	var empty_destroyed: Array[String] = []
	var empty_loot: Array[Dictionary] = []
	var empty_echoes: Array[String] = []
	var empty_unlock: Array[String] = []
	return load("res://scripts/run/run_summary.gd").new(
		false,
		&"",
		&"",
		0,
		false,
		false,
		{
			"nodes_cleared": 0,
			"boss_cleared": false,
			"elite_nodes_cleared": 0,
			"passives_consumed": empty_consumed,
			"passives_destroyed": empty_destroyed,
			"notable_loot": empty_loot,
			"gold": 0,
			"curse_count": 0,
			"corruption": 0
		},
		{
			"oath_shards_earned": 0
		},
		{
			"echoes_discovered": empty_echoes,
			"unlock_progress": empty_unlock
		},
		NOT_YET_SUPPORTED_FIELDS.duplicate()
	)


static func _copy_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result
