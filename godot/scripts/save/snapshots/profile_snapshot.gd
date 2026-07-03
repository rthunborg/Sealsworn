class_name ProfileSnapshot
extends RefCounted

# Story 8.3 (AC1, AC2) — the versioned cross-run META PROFILE snapshot: the FIRST persistent CROSS-RUN state in the
# project. Every save before this persisted only WITHIN a run (RunSnapshot = the run autosave, whose oath_shards /
# meta_progression fields are RUN-scoped 0/empty placeholders). The PROFILE is different: it OUTLIVES a run and
# ACCUMULATES across many descents (Oath Shards earned run after run). Per the Epic-7 §7 Action T2 heads-up (re-stated
# for 8.3), the profile is its OWN snapshot (a SEPARATE ProfileSnapshot + ProfileRepository + save file user://
# profile.json), NOT nested under route_state and NOT the RunSnapshot — with migration coverage from the START (its own
# SCHEMA_VERSION + an unsupported_profile_schema reject path baked in on day one). This keeps run state, profile state,
# and unlock/content state SEPARABLE for save, replay, and tests (AC2).
#
# ⭐ IT MIRRORS RunSnapshot VERBATIM (the versioned-snapshot template): const SCHEMA_VERSION, an exact-key
# to_dictionary() (a key never silently appears/vanishes — pinned by test_profile_snapshot.gd, with deep-copied
# sub-dicts/lists so a mutation of the returned dict never perturbs the snapshot), a static parse(data) -> ActionResult
# that REJECTS a schema_version != SCHEMA_VERSION with the stable unsupported_profile_schema code (the RunSnapshot
# unsupported_save_schema precedent → the v0 migration path; a future schema bump adds a real migrate step, and Story
# 8.7 owns the comprehensive migration matrix), and lenient decode helpers (a missing/invalid field defaults cleanly —
# the RiskEconomyState.try_from_dictionary / RunSnapshot._int64_or_zero leniency).
#
# ⭐ FIELD SET ([Decision] — recorded in the story Completion Notes):
#   - schema_version / content_version / profile_id: the versioned-snapshot header (mirroring RunSnapshot).
#   - oath_shards: the CROSS-RUN AWARDED Oath-Shard TOTAL (a small bounded NON-NEGATIVE int — NOT a seed, so NO
#     decimal-string encoding; the RiskEconomyState.gold / RunSnapshot.gold plain-int precedent). This is the currency
#     Story 8.3 AWARDS; a later unlock-spend story SPENDS it. It is NOT a combat stat (AC3 — Oath Shards are a currency
#     toward variety/options, not a raw-stat ladder).
#   - last_awarded_run_seed: the root_seed (the deterministic run identity in v0 — RunState has no run_id) of the LAST
#     run whose award was applied to this profile. It is the IDEMPOTENCY MARKER (AC1 + the 8.1 seam): the award command
#     re-invoked for a run whose root_seed already equals this is a NO-OP (no double-award). A full int64 → decimal-
#     string encoded (JSON doubles truncate beyond 2^53, the epic-wide root_seed rule; UNLIKE oath_shards which is a
#     small bounded count). "" means no award has ever been applied (a fresh profile).
#   - class_mastery (Dictionary) / echoes (Array[String]) / unlock_progress (Dictionary): EMPTY/0 HOMES for the Story
#     8.4 content (class-mastery points / Echoes / unlock progress) so 8.4 MERGES into an existing shape WITHOUT a
#     migration. 8.3 authors NONE of this content — it only reserves the shape.
#   - first_death_recorded (bool): an EMPTY/false HOME for the Story 8.5 first-death flag so 8.5 merges without a
#     migration. 8.3 does NOT track or set the first-death flag.
#
# It draws NO RNG, submits NO command, resolves NO content — a pure serializable value object.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

# The stable key set of to_dictionary() (pinned by test_profile_snapshot.gd). A key never silently appears or vanishes
# (the RunSnapshot / RiskEconomyState / RunSummary exact-key discipline).
const DICTIONARY_KEYS: Array[String] = [
	"schema_version",
	"content_version",
	"profile_id",
	"oath_shards",
	"last_awarded_run_seed",
	"class_mastery",
	"echoes",
	"unlock_progress",
	"first_death_recorded",
	"first_victory_recorded"
]

const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION
var content_version: String = "mvp-0"
var profile_id: String = "default"
# The CROSS-RUN AWARDED Oath-Shard TOTAL (a small bounded non-negative int; NOT a seed — plain int, no decimal-string
# encoding). AC1: the award adds to this; AC3: it is a capped/sparse currency, not a raw-stat ladder.
var oath_shards: int = 0
# The root_seed (the v0 run identity) of the LAST run whose award was applied — the idempotency marker (AC1 + the 8.1
# seam; a re-award for the same run is a no-op). A full int64 → decimal-string encoded. "" = never awarded.
var last_awarded_run_seed: String = ""
# EMPTY/0 HOMES for Story 8.4 content (class mastery / Echoes / unlock progress) so 8.4 merges without a migration.
var class_mastery: Dictionary = {}
var echoes: Array[String] = []
var unlock_progress: Dictionary = {}
# An EMPTY/false HOME for the Story 8.5 first-death flag so 8.5 merges without a migration. 8.3 does NOT set it.
var first_death_recorded: bool = false
# Story 9.4 (AC2): the FIRST-VICTORY latch (the OPPOSITE-terminal-phase twin of first_death_recorded). Set ONCE by
# RecordFirstVictoryCommand on the FIRST victory across ALL runs (a monotonic per-profile-lifetime marker — the FOURTH
# independent run-end idempotency marker alongside last_awarded_run_seed, unlock_progress["_last_merged_run_seed"], and
# first_death_recorded). Added as a NEW ADDITIVE field at SCHEMA_VERSION == 1 (NO home was pre-reserved for it, so this is
# a lenient additive add — a pre-9.4 dict decodes it to false — NOT a schema bump; the 8.4/8.5 merge-without-bump
# discipline, reconciled with 8.7's migration matrix which pins SCHEMA_VERSION == 1 + schema_version:2 -> unsupported).
var first_victory_recorded: bool = false

# Exact-key serialization (the RunSnapshot / RiskEconomyState precedent). A FRESH dictionary (with deep-copied
# sub-dicts/lists) is returned each call so a mutation of the returned dict never perturbs the snapshot. oath_shards is
# a small bounded int (NOT a seed → plain numeric); last_awarded_run_seed is a full int64 → decimal-string encoded (the
# str() form is already the encoded string, stored verbatim).
func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"content_version": content_version,
		"profile_id": profile_id,
		"oath_shards": oath_shards,
		"last_awarded_run_seed": last_awarded_run_seed,
		"class_mastery": class_mastery.duplicate(true),
		"echoes": echoes.duplicate(),
		"unlock_progress": unlock_progress.duplicate(true),
		"first_death_recorded": first_death_recorded,
		"first_victory_recorded": first_victory_recorded
	}


# Versioned parse (mirrors RunSnapshot.parse VERBATIM): REJECT an unsupported schema_version with the stable
# unsupported_profile_schema code + {expected_schema_version, actual_schema_version} metadata (the v0 migration path —
# a future schema bump adds a real migrate step). On a supported schema, decode each field LENIENTLY (a missing/invalid
# value defaults cleanly — the RiskEconomyState leniency), so a partial/legacy dict still parses. Returns
# ActionResult.ok([], {"snapshot": ProfileSnapshot}).
static func parse(data: Dictionary) -> ActionResult:
	var schema_value: int = int(data.get("schema_version", -1))
	if schema_value != SCHEMA_VERSION:
		return ActionResult.error(&"unsupported_profile_schema", {
			"expected_schema_version": SCHEMA_VERSION,
			"actual_schema_version": schema_value
		})

	var snapshot: ProfileSnapshot = load("res://scripts/save/snapshots/profile_snapshot.gd").new()
	snapshot.schema_version = schema_value
	snapshot.content_version = str(data.get("content_version", "mvp-0"))
	snapshot.profile_id = str(data.get("profile_id", "default"))
	# oath_shards is a small bounded NON-NEGATIVE count — a negative / non-int defaults to 0 (leniency + the never-negative
	# floor, the RiskEconomyState._int_or_zero precedent).
	snapshot.oath_shards = _nonnegative_int_or_zero(data.get("oath_shards", 0))
	# last_awarded_run_seed is the decimal-string-encoded run identity; keep it as a normalized decimal string (a missing/
	# invalid value → "", meaning never awarded).
	snapshot.last_awarded_run_seed = _decimal_string_or_empty(data.get("last_awarded_run_seed", ""))
	snapshot.class_mastery = _dictionary_or_empty(data.get("class_mastery", {}))
	snapshot.echoes = _string_array(data.get("echoes", []))
	snapshot.unlock_progress = _dictionary_or_empty(data.get("unlock_progress", {}))
	snapshot.first_death_recorded = bool(data.get("first_death_recorded", false))
	# Story 9.4: lenient additive decode — a pre-9.4 profile (no first_victory_recorded key) defaults to false (NO
	# migration; the field rides at SCHEMA_VERSION == 1, exactly the 8.5 first_death_recorded leniency).
	snapshot.first_victory_recorded = bool(data.get("first_victory_recorded", false))
	return ActionResult.ok([], {"snapshot": snapshot})


static func from_dictionary(data: Dictionary) -> ProfileSnapshot:
	var result: ActionResult = parse(data)
	if result.is_error():
		push_error("ProfileSnapshot parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("snapshot")


# A fresh default profile (the AC5 recovery path: on a profile_not_found read, the caller starts THIS). A brand-new
# player with 0 Oath Shards, no awards applied, empty 8.4/8.5 homes.
static func fresh(new_profile_id: String = "default") -> ProfileSnapshot:
	var snapshot: ProfileSnapshot = load("res://scripts/save/snapshots/profile_snapshot.gd").new()
	snapshot.profile_id = new_profile_id
	return snapshot


# Deep copy (the sub-dicts/lists are deep-copied so a copy never shares mutable state with the source — the
# RiskEconomyState.copy() precedent). Used by the award command to leave the input profile byte-identical on a reject.
func copy() -> ProfileSnapshot:
	var snapshot: ProfileSnapshot = load("res://scripts/save/snapshots/profile_snapshot.gd").new()
	snapshot.schema_version = schema_version
	snapshot.content_version = content_version
	snapshot.profile_id = profile_id
	snapshot.oath_shards = oath_shards
	snapshot.last_awarded_run_seed = last_awarded_run_seed
	snapshot.class_mastery = class_mastery.duplicate(true)
	snapshot.echoes = echoes.duplicate()
	snapshot.unlock_progress = unlock_progress.duplicate(true)
	snapshot.first_death_recorded = first_death_recorded
	snapshot.first_victory_recorded = first_victory_recorded
	return snapshot


static func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value:
		result.append(str(item))
	return result


# Lenient non-negative int decode (oath_shards): accept an int / integral-float / decimal-string, clamp a negative to 0,
# else 0. Mirrors RiskEconomyState._int_or_zero (a count is never negative).
static func _nonnegative_int_or_zero(value: Variant) -> int:
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


# Lenient decimal-string decode for the int64 run-identity marker (last_awarded_run_seed): a valid int-or-decimal-string
# is normalized to its canonical decimal string via str(int); anything else (or a blank) → "" (never awarded). Storing
# the decimal string (not the raw int) keeps the full int64 JSON-double-safe.
static func _decimal_string_or_empty(value: Variant) -> String:
	match typeof(value):
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return ""
			return str(int(numeric_value))
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value)
			if text.is_valid_int():
				return str(text.to_int())
			return ""
		_:
			return ""
