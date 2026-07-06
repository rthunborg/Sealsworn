class_name RunEndProfileBridge
extends RefCounted

# Story 11.5 (AC-wide crux — the run-end -> profile BRIDGE the live flow is missing) — the scene-free RefCounted seam
# that runs, AT THE LIVE RUN-END, the load -> record-latch -> persist -> build-summary/outpost sequence the live run flow
# (11.2/11.3) never wired. It is the CALLER the Epic-8/9 run-end command family was always waiting for: the record
# commands are CALLER-DRIVEN by design (the 8.3/8.4/8.5/9.4 posture — "NOT auto-wired into run_to_completion; the caller
# drives them behind the run-end seam"); this bridge IS that caller. The RunOrchestrator is UNCHANGED (it gained ONE
# additive read-only accessor, next_sequence_id(); it drives no profile logic — the caller-driven posture is preserved,
# fingerprint-safe: the default run_to_completion auto-resolve is byte-identical).
#
# ⭐ THE SEQUENCE (all off the REAL terminal RunState — the retro H1 discipline: test the SHARED sequencing seam, not just
# the individual commands, so the on-screen order is proven to match the domain's intended order + never builds the
# outpost off a stale/un-persisted profile):
#   (1) LOAD the profile fail-closed via ProfileRepository.read_profile:
#         - profile_not_found            -> start ProfileSnapshot.fresh() (a brand-new player; AC5/8.6 fresh path).
#         - unsupported_profile_schema   -> route to the AC3 profile-LOAD recovery (do NOT overwrite an incompatible
#                                           profile; build the fresh-fallback recovery outpost, record NO latch, persist
#                                           NOTHING). profile_open_failed / profile_parse_failed likewise -> load recovery.
#         - ok                           -> read the loaded profile verbatim (source truth; never mutated on a reject).
#   (2) RECORD the latch off the REAL terminal phase (AC2), threading a UNIQUE sequence_id > 0 from the run-level cursor
#       (orchestrator.next_sequence_id() — NOT a hardcoded 1 that could collide with an id the run already emitted):
#         - PHASE_FAILED    -> RecordFirstDeathCommand.new(profile, sequence_id).execute(run).
#         - PHASE_COMPLETED -> RecordFirstVictoryCommand.new(profile, sequence_id).execute(run).
#       A subsequent death/victory rejects idempotently (first_death_already_recorded / first_victory_already_recorded)
#       with ZERO mutation — that is EXPECTED, not an error (the beat simply does not re-show). The record is
#       ELIGIBILITY-INDEPENDENT (a manual-seed run STILL records + shows the line — the ratified Option A).
#   (3) PERSIST the (possibly mutated) profile via ProfileRepository.write_profile:
#         - ok            -> build the outpost from the loaded/mutated profile + the terminal-run RunSummary.
#         - profile_save_* -> build the outpost via OutpostViewModel.for_recovery(code, loaded_profile) (AC3 WRITE-failure:
#                            real totals behind a retry banner; the profile is intact in memory even though the write
#                            failed). The RunSummary is NEVER lost (it is a DERIVED read that does not read the profile
#                            file — 8.3's structural guarantee).
#   (4) BUILD the run summary + outpost: RunSummary.build(run, events) + the OutpostViewModel (+ the reveal beats built
#       from the record result, symmetric first-death/first-victory).
#
# ⭐ THE events SOURCE ([Decision] — Option (a), the minimal defensible v0 choice): RunSummary.build(run, events) derives
# its passives/loot/discovery lists from the SUPPLIED ordered events list, but v0 has NO run-level event STORE (the
# orchestrator threads sequence ids + RETURNS events in each ActionResult but does NOT accumulate a run-wide log; the
# run_events/board_events accumulators are LOCAL to the boss auto-play, not run-wide; the 11.3 live flow drives node-by-
# node and DISCARDS intermediate ActionResult.events). The bridge builds with an EMPTY events list: the route/economy
# run-scoped facts (nodes_cleared / boss_cleared / elite_nodes_cleared / gold / curse_count / corruption) derive from the
# terminal RunState regardless; only passives_consumed / passives_destroyed / notable_loot / echoes_discovered /
# unlock_progress come out EMPTY (an honest v0 limitation, NOT a bug — a persisted run-level event store is a later
# save-shape story). It does NOT read a presentation/combat log as source truth (8.2 AC2 forbids it) and does NOT add a
# persisted event-log field to RunState/RunSnapshot (the 23-key gate stays 23).
#
# ⭐ THE G3 COUPLING ([Decision] — Option A, the honest as-is): the AWARDED Oath-Shard total is the PROFILE's
# (profile.oath_shards, surfaced via OutpostViewModel.oath_shards); RunSummary.profile_meta.oath_shards_earned STAYS
# 0/not_yet_supported (the summary reads NO profile — wiring the DTO field non-zero would break the 8.2/8.4
# not_yet_supported pinned contract). No summary->profile coupling. The presenter shows an honest "not yet tallied" note
# on the summary + the AWARDED total at the outpost level.
#
# ⭐ SCOPE (the 11.5 fences): the bridge records the NARRATIVE first-death/victory LATCH (eligibility-independent — a flag,
# not progression currency) and closes the loop; it does NOT drive AwardMetaProgressCommand / MergeRunDiscoveriesCommand
# (the 11.6 meta-SPEND/GRANT concern). It draws ZERO RNG (the record commands are ZERO-RNG deterministic flag sets;
# RunSummary/OutpostViewModel/the beats are pure reads); it mutates ONLY the profile (never the run, never the streams,
# never any fingerprint). Fail-closed on a null/non-terminal run (build_outpost returns null so the presenter branches).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const FirstDeathNarrativeBeat = preload("res://scripts/run/first_death_narrative_beat.gd")
const FirstVictoryRevealBeat = preload("res://scripts/run/first_victory_reveal_beat.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RecordFirstDeathCommand = preload("res://scripts/core/commands/record_first_death_command.gd")
const RecordFirstVictoryCommand = preload("res://scripts/core/commands/record_first_victory_command.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

# The structured profile-LOAD failure codes that route to the AC3 profile-LOAD recovery (fresh fallback — NO overwrite of
# an incompatible/unreadable profile). profile_not_found is DISTINCT (it is the fresh-start path, not a recovery banner).
const LOAD_FAILURE_CODES: Array[StringName] = [
	&"unsupported_profile_schema",
	&"profile_open_failed",
	&"profile_parse_failed"
]

# The ProfileRepository the bridge drives (injectable for tests — the same repository injection posture as the
# orchestrator's; the outpost/run-end bridge is the FIRST live profile caller). A custom save_path lets a test drive a
# throwaway profile file. There is NO SaveManager profile delegator (project-context: Epics 8-9 added none; the caller
# drives ProfileRepository directly — [Decision] recorded in Completion Notes: the bridge calls the repository directly
# rather than adding a thin SaveManager delegator, keeping the autoload thin and avoiding a new autoload surface).
var _repository: ProfileRepository = null
var _save_path: String = ProfileRepository.DEFAULT_PROFILE_PATH

func _init(repository: ProfileRepository = null, save_path: String = ProfileRepository.DEFAULT_PROFILE_PATH) -> void:
	_repository = repository if repository != null else ProfileRepository.new()
	_save_path = save_path


# AC-wide (the bridge): run the full load -> record -> persist -> build sequence off a TERMINAL run + its orchestrator
# (for the sequence-id cursor). Returns the built OutpostViewModel, or null for a null/non-terminal run (fail-closed — the
# caller branches on null: there is no outpost to build off an unfinished run). Draws ZERO RNG; mutates only the profile.
func build_outpost(run: RunState, orchestrator: RunOrchestrator = null) -> OutpostViewModel:
	if run == null or not run.is_terminal():
		return null

	# (1) LOAD the profile fail-closed.
	var load_result: ActionResult = _repository.read_profile(_save_path)
	if load_result.is_error() and LOAD_FAILURE_CODES.has(load_result.error_code):
		# AC3 profile-LOAD failure: build the fresh-fallback recovery outpost (has_profile == false, 0 shards) behind the
		# recovery banner. Record NO latch (there is no valid profile to mutate) + persist NOTHING (do NOT overwrite an
		# incompatible/unreadable profile). Still build the terminal-run summary (a DERIVED read — never lost).
		return OutpostViewModel.for_recovery(
			load_result.error_code,
			null,
			_summary_for(run),
			FirstDeathNarrativeBeat.for_first_death(&""),
			null,
			true,
			FirstVictoryRevealBeat.for_first_victory(&"")
		)

	# profile_not_found -> a brand-new player: start a FRESH profile (the AC5/8.6 fresh path — NOT a recovery banner). A
	# supported loaded profile is read verbatim (source truth).
	var profile: ProfileSnapshot
	if load_result.is_error():
		# The only remaining error at this point is profile_not_found (the LOAD_FAILURE_CODES were handled above).
		profile = ProfileSnapshot.fresh()
	else:
		profile = load_result.metadata.get("snapshot")

	# (2) RECORD the latch off the REAL terminal phase, threading a UNIQUE sequence_id > 0 from the run-level cursor.
	var sequence_id: int = orchestrator.next_sequence_id() if orchestrator != null else 1
	if sequence_id <= 0:
		sequence_id = 1
	var death_beat: FirstDeathNarrativeBeat = FirstDeathNarrativeBeat.for_first_death(&"")
	var victory_beat: FirstVictoryRevealBeat = FirstVictoryRevealBeat.for_first_victory(&"")

	if run.phase == RunState.PHASE_FAILED:
		var death_result: ActionResult = RecordFirstDeathCommand.new(profile, sequence_id).execute(run)
		# On the FIRST death the flag is now set + the result carries the beat data -> build the populated beat. A
		# subsequent death rejects idempotently (first_death_already_recorded) with ZERO mutation -> the beat does not
		# re-show (the empty beat). Either way the profile is in the correct state for persistence.
		if death_result.succeeded:
			death_beat = FirstDeathNarrativeBeat.for_first_death(
				StringName(String(death_result.metadata.get("line_id", ""))),
				bool(death_result.metadata.get("is_skippable", true))
			)
	elif run.phase == RunState.PHASE_COMPLETED:
		var victory_result: ActionResult = RecordFirstVictoryCommand.new(profile, sequence_id).execute(run)
		if victory_result.succeeded:
			victory_beat = FirstVictoryRevealBeat.for_first_victory(
				StringName(String(victory_result.metadata.get("line_id", ""))),
				bool(victory_result.metadata.get("is_skippable", true))
			)

	# (3) PERSIST the (possibly mutated) profile.
	var write_result: ActionResult = _repository.write_profile(profile, _save_path)
	if write_result.is_error():
		# AC3 profile-WRITE failure: the profile was READ fine + the latch is set in memory; only the WRITE failed. Build
		# the outpost via for_recovery(code, loaded_profile) — the REAL totals behind a retry banner (has_profile == true),
		# NOT a misleading 0-shard surface. The reveal beats still render (the record succeeded in memory).
		return OutpostViewModel.for_recovery(
			write_result.error_code,
			profile,
			_summary_for(run),
			death_beat,
			null,
			true,
			victory_beat
		)

	# (4) BUILD the outpost from the mutated + persisted profile + the terminal-run summary + the reveal beats.
	return OutpostViewModel.new(
		profile,
		_summary_for(run),
		death_beat,
		victory_beat
	)


# The terminal-run RunSummary built with an EMPTY events list ([Decision] Option (a) — v0 has no run-level event store;
# the route/economy run-scoped facts derive from the terminal RunState; the passives/loot/discovery lists come out empty,
# an honest v0 limitation). A null/non-terminal run yields the fail-closed empty summary (has_summary == false).
func _summary_for(run: RunState) -> RunSummary:
	return RunSummary.build(run, [])
