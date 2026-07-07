class_name OutpostSpendBridge
extends RefCounted

# Story 11.6 (AC1/AC-wide — the spend/apply BRIDGE, mirroring 11.5's RunEndProfileBridge crux) — the scene-free
# RefCounted seam that runs, at the OUTPOST, the load -> spend -> persist -> rebuild sequence the outpost presenter
# drives when the player buys a class unlock. It is the CALLER the SpendOathShardsCommand needs (the command is caller-
# driven by design — it validates + mutates + emits, but does NOT persist itself; this bridge LOADS the profile, RUNS
# the command, PERSISTS, and REBUILDS the OutpostViewModel so the meta readout / class_options / selectable_class_ids
# reflect the spend). It is the SPEND counterpart of RunEndProfileBridge (which records the run-end latch); it mirrors
# that bridge's caller-driven posture VERBATIM (drive ProfileRepository directly — there is NO SaveManager profile
# delegator; the 11.5 posture) and is the SHARED seam a headless test drives end-to-end (the retro H1 discipline: test
# the shared load->spend->persist->rebuild sequencing, NOT just the individual command, so the on-screen order is proven
# correct + never rebuilds the outpost off a stale/un-persisted profile).
#
# ⭐ THE SEQUENCE (all off the LOADED profile — the retro H1 discipline):
#   (1) LOAD the profile fail-closed via ProfileRepository.read_profile:
#         - profile_not_found            -> start ProfileSnapshot.fresh() (a brand-new player has 0 shards -> a spend
#                                           will fail-closed on insufficient_oath_shards; that surfaces honestly).
#         - unsupported_profile_schema / profile_open_failed / profile_parse_failed -> route to the AC3 profile-LOAD
#                                           recovery (do NOT overwrite an incompatible/unreadable profile; build the
#                                           fresh-fallback recovery outpost, spend NOTHING, persist NOTHING).
#         - ok                           -> read the loaded profile verbatim (source truth; never mutated on a reject).
#   (2) RUN the SpendOathShardsCommand off the LOADED profile, threading a UNIQUE sequence_id > 0 from the bridge's own
#       monotonic cursor (a spend at the outpost has NO live run/orchestrator — [Decision] Option: a fresh monotonic
#       source on the bridge, starting at 1, so multiple spends in one session get unique ids, keeping sequence_id > 0).
#       An unaffordable/unknown/already-applied spend REJECTS with ZERO mutation -> the profile is UNCHANGED, persisted
#       AS-IS (a no-op write of the loaded profile is harmless + keeps the read-modify-write shape uniform), and the
#       rebuilt outpost carries the last_spend_result so the presenter surfaces the fail-loud message (insufficient-shards
#       etc.) — NEVER a silent swallow.
#   (3) PERSIST the (possibly mutated) profile via ProfileRepository.write_profile:
#         - ok             -> build the outpost from the mutated + persisted profile.
#         - profile_save_* -> build the outpost via OutpostViewModel.for_recovery(code, loaded_profile) — the REAL totals
#                            behind a retry banner (the profile is intact in memory even though the write failed; the same
#                            recovery posture 11.5 uses — real totals behind a retry, NEVER a silent swallow).
#   (4) BUILD the OutpostViewModel off the loaded/mutated profile (the meta readout / class_options / selectable_class_ids
#       reflect the spend — a formerly-locked class the spend unlocked now reports selectable via the profile-aware
#       HeroSelectViewModel the OutpostViewModel composes).
#
# ⭐ SCOPE: it drives the SPEND (SpendOathShardsCommand) + the profile-aware outpost rebuild; it does NOT drive the
# award/merge (that is RunEndProfileBridge's run-end concern, unchanged) and it does NOT record the first-death/victory
# latch (a spend is not a run-end). It draws ZERO RNG (the spend command is a ZERO-RNG deterministic subtraction + flag
# set; OutpostViewModel is a pure read); it mutates ONLY the profile (never the run, never the streams, never any
# fingerprint). Fail-closed on a null/empty unlock request (a spend of "" is not spendable -> the command rejects
# unknown_unlock, surfaced honestly).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const SpendOathShardsCommand = preload("res://scripts/core/commands/spend_oath_shards_command.gd")

# The structured profile-LOAD failure codes that route to the AC3 profile-LOAD recovery (fresh fallback — NO overwrite of
# an incompatible/unreadable profile). profile_not_found is DISTINCT (it is the fresh-start path — a brand-new player).
const LOAD_FAILURE_CODES: Array[StringName] = [
	&"unsupported_profile_schema",
	&"profile_open_failed",
	&"profile_parse_failed"
]

# The ProfileRepository the bridge drives (injectable for tests — the RunEndProfileBridge injection posture). A custom
# save_path lets a test drive a throwaway profile file.
var _repository: ProfileRepository = null
var _save_path: String = ProfileRepository.DEFAULT_PROFILE_PATH
# The bridge's own monotonic sequence-id cursor ([Decision] — a spend at the outpost has no live run/orchestrator; a
# fresh monotonic source keeps every spend event's sequence_id unique + > 0 within a session).
var _next_sequence_id: int = 1
# The last spend command result (surfaced so the presenter reads the outcome — the affordable-spend confirmation or the
# fail-loud insufficient/unknown/already-applied message). Fail-closed empty until the first spend.
var _last_spend_result: ActionResult = null

func _init(repository: ProfileRepository = null, save_path: String = ProfileRepository.DEFAULT_PROFILE_PATH) -> void:
	_repository = repository if repository != null else ProfileRepository.new()
	_save_path = save_path


# The last spend result (the presenter reads it to surface the outcome). Null before the first spend.
func last_spend_result() -> ActionResult:
	return _last_spend_result


# AC1/AC-wide (the bridge crux): run the full load -> spend -> persist -> rebuild sequence for a spend of `unlock_id`.
# Returns the rebuilt OutpostViewModel (the meta readout / class options reflect the spend, or the recovery surface on a
# load/write failure). Draws ZERO RNG; mutates only the profile. The presenter calls this on a spend request + re-renders.
func spend(unlock_id: String) -> OutpostViewModel:
	# (1) LOAD the profile fail-closed.
	var load_result: ActionResult = _repository.read_profile(_save_path)
	if load_result.is_error() and LOAD_FAILURE_CODES.has(load_result.error_code):
		# AC3 profile-LOAD failure: build the fresh-fallback recovery outpost (has_profile == false, 0 shards) behind the
		# recovery banner. Spend NOTHING + persist NOTHING (do NOT overwrite an incompatible/unreadable profile).
		_last_spend_result = ActionResult.error(&"profile_load_failed_no_spend", {
			"inner_error_code": String(load_result.error_code)
		})
		return OutpostViewModel.for_recovery(load_result.error_code)

	# profile_not_found -> a brand-new player: start a FRESH profile (0 shards — a spend will fail-closed on affordability,
	# surfaced honestly). A supported loaded profile is read verbatim (source truth).
	var profile: ProfileSnapshot
	if load_result.is_error():
		profile = ProfileSnapshot.fresh()
	else:
		profile = load_result.metadata.get("snapshot")

	# (2) RUN the spend off the LOADED profile, threading a UNIQUE sequence_id > 0 from the bridge cursor. A reject (unknown/
	# already-applied/insufficient) leaves the profile UNCHANGED (the command's no-mutation-on-reject guarantee).
	var sequence_id: int = _next_sequence_id
	_next_sequence_id += 1
	_last_spend_result = SpendOathShardsCommand.new(profile, unlock_id, sequence_id).execute(null)

	# (3) PERSIST the (possibly mutated) profile. On a SUCCESS the mutated profile is written; on a spend REJECT the profile
	# is unchanged and the write is a harmless no-op re-write of the loaded profile (uniform read-modify-write shape).
	var write_result: ActionResult = _repository.write_profile(profile, _save_path)
	if write_result.is_error():
		# AC3 profile-WRITE failure: the profile is intact in memory; only the WRITE failed. Build the outpost via
		# for_recovery(code, loaded_profile) — the REAL totals behind a retry banner (has_profile == true), NOT a
		# misleading 0-shard surface. The spend result (success or reject) is still surfaced via last_spend_result.
		return OutpostViewModel.for_recovery(write_result.error_code, profile)

	# (4) BUILD the outpost from the mutated + persisted profile (the meta readout + the profile-aware class options reflect
	# the spend — a formerly-locked class the spend unlocked reports selectable).
	return _build_outpost(profile)


# Build a plain (non-recovery) OutpostViewModel off a profile. The OutpostViewModel composes a PROFILE-AWARE
# HeroSelectViewModel off its `profile` arg (Story 11.6), so class_options / selectable_class_ids reflect the applied
# unlock — the AC2 flow at the outpost (a formerly-locked class the spend unlocked reports selectable). A fresh session
# with no just-ended run passes a null run summary (the fail-closed empty summary).
func _build_outpost(profile: ProfileSnapshot) -> OutpostViewModel:
	return OutpostViewModel.new(profile)
