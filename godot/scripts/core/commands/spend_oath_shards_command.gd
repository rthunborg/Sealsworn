class_name SpendOathShardsCommand
extends "res://scripts/core/commands/game_command.gd"

# Story 11.6 (AC1/AC2/AC3, FR59/FR43/FR95) — the META-SPEND command: the run-domain command that SPENDS the cross-run
# Oath-Shard currency the profile ACCUMULATED (8.3's AwardMetaProgressCommand awarded it) to APPLY a class unlock at the
# outpost (FR43 — a formerly-locked class becomes selectable). It is the "spend what you earn and feel meta progress
# apply" half of Epic 11 — the FIRST command to SPEND persistent cross-run state (8.3 was the FIRST to award it). It
# mirrors AwardMetaProgressCommand VERBATIM at the OPPOSITE sign: the award ADDS to profile.oath_shards; this SUBTRACTS.
#
# ⭐ THE 4.3/8.3 RUN-COMMAND IDIOM VERBATIM (mirroring AwardMetaProgressCommand): the PROFILE + the spend inputs (the
# unlock_id) + the sequence_id are supplied via the CONSTRUCTOR; validate(state) rejects sequence_id <= 0 FIRST
# (invalid_event_sequence_id) so a success path can never emit an event its own validator would reject; validate-then-
# mutate with ZERO events + a byte-identical no-mutation profile on ANY reject; the event is built ONLY AFTER the spend
# is applied. It draws ZERO RNG (a spend is a deterministic arithmetic subtraction + a flag set, NOT a roll — no draw
# provenance). ONE stable top-level error code per failure class (the precise reason rides `metadata`). The CALLER
# persists via ProfileRepository.write_profile (the command does NOT persist itself — the load->spend->persist seam is
# the OutpostSpendBridge, mirroring 11.5's RunEndProfileBridge).
#
# ⭐ THE `state` ARG ([Decision] — Option A, the RunStartCommand precedent): a spend fires at the OUTPOST, possibly with
# NO live run (unlike the award/merge/latch, which take the TERMINAL RunState as `state`). So the `state` arg is UNUSED
# (accepts null) — the profile + the unlock_id in the constructor are the real context. This keeps the spend a self-
# contained "spend at the outpost" command whose context is the constructor, exactly like RunStartCommand builds a run
# from its constructor with an unused `state`.
#
# ⭐ FAIL-CLOSED REJECTS (AC1 — ZERO mutation, ZERO event on each):
#   - unknown_unlock: an unlock_id that is NOT a spendable MetaSpendRules.CLASS_UNLOCK (fail-closed — a spend can only
#     buy a declared unlock).
#   - unlock_already_applied: the unlock's applied-unlock flag is ALREADY set (the APPLICATION is idempotent — re-applying
#     an already-applied unlock is a NO-OP, not a double-charge; a class already selectable stays selectable). This is
#     what makes the command RETRY-SAFE: a persist-failure retry re-reads the profile (flag set), re-runs, and rejects
#     idempotently WITHOUT double-charging (AC3). NOTE: this is NOT "block a second legitimate spend" — a spend is a
#     PLAYER-INITIATED REPEATABLE action; but each CLASS unlock is a distinct one-time purchase (there are two, each
#     bought once), so re-buying the SAME already-owned unlock is the no-op case.
#   - insufficient_oath_shards: profile.oath_shards < cost (the shortfall rides metadata). A spend NEVER drives a negative
#     total (fail-closed BEFORE the subtract).
#
# ⭐ FR28 (manual-seed exclusion — where it lives): the exclusion is STRUCTURAL + on the AWARD side. A manual-seed run
# never AWARDED any Oath Shards (AwardMetaProgressCommand's Gate 2 denies it), so there is nothing manual-seed-earned to
# spend. This command does NOT re-gate for manual-seed and does NOT FABRICATE shards — it ONLY subtracts existing
# profile.oath_shards. So a spend can only consume shards an ELIGIBLE run awarded (FR28 held structurally).
#
# ⭐ FR95 (capped/sparse — no raw-stat ladder): the spend applies a VARIETY gate (a class becomes selectable), NEVER a
# raw combat stat. The applied-unlock flag is a `<class>_unlocked` key (MetaSpendRules.class_unlock_flag_key) — NONE is a
# raw-stat key (UnlockProgressRules.is_raw_stat_unlock_key produces none). The cost table is a declared const
# (MetaSpendRules.CLASS_UNLOCKS), NOT scaled by difficulty.
#
# ⭐ THE IDEMPOTENCY MARKERS ([Decision] — the AC3 caller-ordering safety): a spend reads/writes NONE of the FOUR run-end
# markers (award last_awarded_run_seed; merge unlock_progress["_last_merged_run_seed"]; first_death_recorded;
# first_victory_recorded). It touches ONLY the applied-unlock flag + the spend ledger (both inside unlock_progress, both
# namespaced away from those markers), so a spend interleaved with the award/merge/latch commands leaves each independent
# and correct. The spend's own idempotency is the applied-unlock flag (the APPLICATION latch — flag already set -> no-op).
#
# WHAT THIS IS NOT (scope boundaries): it does NOT re-award / re-merge (it SPENDS what 8.3 awarded + APPLIES what the
# unlock config declares — it reads profile.oath_shards/unlock_progress as accumulated state). It authors NO content
# roster (the unlock is tracked BY id — the class-unlock config is the pure MetaSpendRules const, NOT a repository). It
# does NOT bump ProfileSnapshot.SCHEMA_VERSION or add a migration (the applied-unlock flag + the spend ledger merge into
# the EXISTING unlock_progress home at SCHEMA_VERSION == 1 — the seal-fragments/merge-marker precedent). It does NOT
# persist the profile itself (the caller does). It draws ZERO RNG.

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MetaSpendRules = preload("res://scripts/save/meta_spend_rules.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")

# The reason marker recorded on the spend event (in DomainEvent.OATH_SHARDS_SPENT_REASONS — the validator pins the
# allowlist). Referenced from the event const so the command + validator stay in lockstep.
const SPEND_REASON := &"class_unlock"

# The profile the spend lands on (supplied via the constructor). MUTATED on success (oath_shards down + the applied-
# unlock flag set + the spend ledger raised).
var profile: ProfileSnapshot = null
# The spendable unlock id (a MetaSpendRules.CLASS_UNLOCKS key — the class-unlock the player is buying). Read-only.
var unlock_id: String = ""
var sequence_id: int = 1

func _init(new_profile: ProfileSnapshot = null, new_unlock_id: String = "", new_sequence_id: int = 1) -> void:
	command_id = &"spend_oath_shards"
	profile = new_profile
	unlock_id = new_unlock_id
	sequence_id = new_sequence_id


# Pure read: validate the event sequence id, the context (a profile), the unlock (spendable + not already applied), and
# affordability (enough Oath Shards). No mutation, no event, no RNG. The `state` arg is UNUSED (Option A — a spend at the
# outpost has no live run; the RunStartCommand precedent); it accepts null.
func validate(_state: Variant) -> ActionResult:
	# Self-consistency gate (the 4.3/8.3 idiom): execute() builds oath_shards_spent(sequence_id), and
	# DomainEvent.try_from_dictionary requires sequence_id > 0. Gate it BEFORE any state is read or mutated.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if profile == null:
		return _invalid_context()

	# The unlock must be a declared spendable class unlock (fail-closed — a spend can only buy a declared unlock).
	if not MetaSpendRules.is_class_unlock(unlock_id):
		return ActionResult.error(&"unknown_unlock", {
			"command": String(command_id),
			"unlock_id": unlock_id
		})

	# The APPLICATION is idempotent: an unlock whose applied-unlock flag is ALREADY set is a no-op (re-applying does not
	# double-unlock + does not double-charge). This also makes the command RETRY-SAFE (a persist-failure retry re-reads
	# the profile with the flag set + rejects here WITHOUT double-charging — AC3).
	var flag_key: String = MetaSpendRules.class_unlock_flag_key(unlock_id)
	if bool(profile.unlock_progress.get(flag_key, false)):
		return ActionResult.error(&"unlock_already_applied", {
			"command": String(command_id),
			"unlock_id": unlock_id,
			"flag_key": flag_key
		})

	# Affordability (AC1): profile.oath_shards >= cost. An unaffordable spend fails closed with the shortfall in metadata,
	# ZERO mutation, ZERO event, ZERO charge. A spend NEVER drives a negative total (this gate runs BEFORE the subtract).
	var cost: int = MetaSpendRules.class_unlock_cost(unlock_id)
	if profile.oath_shards < cost:
		return ActionResult.error(&"insufficient_oath_shards", {
			"command": String(command_id),
			"unlock_id": unlock_id,
			"cost": cost,
			"available": profile.oath_shards,
			"shortfall": cost - profile.oath_shards
		})

	return ActionResult.ok()


# Validate-then-mutate: subtract the cost from the profile's cross-run oath_shards, set the applied-unlock flag (the
# variety gate — the class becomes selectable), raise the spend ledger, build the oath_shards_spent event, and return
# ok([event], {spend fields}). On ANY reject: ZERO events, ZERO mutation (the profile byte-identical). Draws ZERO RNG;
# builds the event ONLY after the spend is applied.
func execute(_state: Variant) -> ActionResult:
	var validation: ActionResult = validate(_state)
	if validation.is_error():
		return validation

	var cost: int = MetaSpendRules.class_unlock_cost(unlock_id)
	var flag_key: String = MetaSpendRules.class_unlock_flag_key(unlock_id)
	var class_id: String = MetaSpendRules.class_id_for_unlock(unlock_id)
	var before: int = profile.oath_shards
	var after: int = before - cost

	# Apply the spend to the profile (the cross-run total drops; the applied-unlock VARIETY flag is set — a formerly-locked
	# class becomes selectable; the cumulative spend ledger rises). All inside unlock_progress (no new ProfileSnapshot key,
	# no schema bump — the seal-fragments/merge-marker home precedent). Draws ZERO RNG.
	profile.oath_shards = after
	profile.unlock_progress[flag_key] = true
	profile.unlock_progress[MetaSpendRules.OATH_SHARDS_SPENT_KEY] = MetaSpendRules.oath_shards_spent_in(profile.unlock_progress) + cost

	var event: DomainEvent = DomainEvent.oath_shards_spent(sequence_id, {
		"amount": cost,
		"oath_shards_before": before,
		"oath_shards_after": after,
		"reason": String(SPEND_REASON),
		"unlock_id": unlock_id,
		"profile_id": profile.profile_id
	})

	return ActionResult.ok([event], {
		"oath_shards_spent": true,
		"amount": cost,
		"oath_shards_before": before,
		"oath_shards_after": after,
		"unlock_id": unlock_id,
		"class_id": class_id,
		"flag_key": flag_key,
		"reason": String(SPEND_REASON),
		"profile_id": profile.profile_id
	})


# A single stable top-level code (invalid_context) holds the null-profile case, surfacing the inner error for diagnosis
# (mirroring AwardMetaProgressCommand).
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
