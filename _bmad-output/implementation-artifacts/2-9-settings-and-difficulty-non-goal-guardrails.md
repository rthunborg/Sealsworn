---
created: 2026-06-15
source_story_key: 2-9-settings-and-difficulty-non-goal-guardrails
baseline_commit: a0d2b1230063540c583e1376dc8b4d7853e1c1cf
---

# Story 2.9: Settings and Difficulty Non-Goal Guardrails

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want basic settings for readability, input, and audio without hidden difficulty tiers,
so that I can adapt the interface while the MVP challenge remains authored through run systems.

## Acceptance Criteria

1. Given the settings model is initialized, when settings are loaded or changed, then text scale, audio volume or mute, and input preference fields are represented as preferences separate from active run domain state, and settings can be saved and restored without mutating tactical truth, RNG state, rewards, or progression.
2. Given the settings screen or view model exposes gameplay-related options, when options are reviewed for MVP, then no player-selectable difficulty tier, easy/normal/hard selector, or generic difficulty ladder is present, and difficulty remains sourced from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, and boss preparation.
3. Given post-MVP challenge content is discussed or configured, when challenge options are represented in content or UX notes, then they are described as explicit variants, trials, oaths, or special runs, and they are not implemented as a generic selectable difficulty ladder.
4. Given settings are presented on mobile and desktop, when the user changes text, audio, or input preferences, then the changes are visible or audible immediately where practical, and they remain optional presentation/preferences behavior, not an alternate ruleset.

**Readiness traceability:** Addresses readiness report GDD FR90, FR91, FR93, the settings/accessibility gap, and the no-difficulty-ladder acceptance criteria. [Source: epics.md Story 2.9; FR Coverage 2026-06-04 patch — "GDD FR90, FR91, and FR93: no selectable difficulty tiers and post-MVP challenge guardrails -> Story 2.9 and Story 10.6"]

## Tasks / Subtasks

- [x] 2.9.1 Confirm the Epic 2 boundary and write FAILING tests FIRST. (AC: 1-4)
  - [x] Verify in `_bmad-output/implementation-artifacts/sprint-status.yaml` that `epic-1: done`, Stories 2.1-2.8 are `done`, and this story (`2-9-settings-and-difficulty-non-goal-guardrails`) is `ready-for-dev`. If any earlier Epic 1/2 status regressed, STOP and restore the boundary before implementing settings.
  - [x] Confirm the working tree is clean or that dirty files are intentional user work; preserve unrelated changes. The untracked orchestrator-owned `_bmad-output/auto-gds/` directory is expected and is NOT your change.
  - [x] Add focused FAILING tests before any production edit. Recommended new files: `godot/tests/unit/settings/test_settings_snapshot.gd` (model defaults/clamping/round-trip + difficulty non-goal guardrail), `godot/tests/unit/settings/test_settings_repository.gd` (save/restore through `user://settings.json`, structured failures, no-run-mutation), and optionally `godot/tests/unit/settings/test_settings_apply_service.gd` for the AC4 immediate-apply binding. The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry/`.tscn` edit is needed.
  - [x] Reuse existing primitives — `ActionResult` (`scripts/core/results/action_result.gd`), the `RunSnapshot`/`SaveRepository` DTO+repository PATTERN (mirror it; do NOT extend the run save), the JSON write/read transport already proven in `SaveRepository`, `TacticalTextScale` (`scripts/ui/view_models/tactical_text_scale.gd`) for text-scale bounds, and `AudioManager` (`scripts/autoloads/audio_manager.gd`) for the audio apply side. Do NOT invent a new result type, a new test framework, or a parallel JSON layer.
  - [x] Do NOT in this story: add a difficulty/easy-normal-hard selector or any difficulty field; persist settings INTO the run autosave (`user://run_autosave.json`); build polished settings scenes/menus beyond a scene-free view-model/apply contract; touch `MoveCommand`/`AttackCommand`, tactical truth, RNG streams, route/level state, generation, or meta progression; add cloud/account/telemetry. (Run-save resume is Story 2.8 and is done; difficulty is a deliberate NON-GOAL.)
- [x] 2.9.2 Implement the `SettingsSnapshot` preferences DTO (separate from run domain state). (AC: 1, 2, 4)
  - [x] Add `godot/scripts/settings/settings_snapshot.gd` (`SettingsSnapshot extends RefCounted`, data-layer only — NOT a `Node`, NOT an autoload, NO scene nodes). Mirror the `RunSnapshot` shape: `SCHEMA_VERSION: int = 1`, `content_version := "mvp-0"`, typed fields, `to_dictionary()`, a strict-ish `static parse(data) -> ActionResult` (rejects mismatched schema with `unsupported_settings_schema`), a `from_dictionary()` convenience, and `static defaults() -> SettingsSnapshot`.
  - [x] Fields (MVP preferences ONLY): `text_scale: float` (clamp via `TacticalTextScale` bounds: default 1.0, min 0.85, max 2.0; malformed -> default), `master_volume_db: float` (clamp to a named range, e.g. `MIN_VOLUME_DB = -60.0` .. `MAX_VOLUME_DB = 0.0`; malformed -> default 0.0), `audio_muted: bool` (default false), and an input-preference field — recommend `input_scheme: String` from a small fixed allowlist (e.g. `"auto"`, `"touch"`, `"mouse_keyboard"`; unknown -> default `"auto"`). Optionally a `colorblind_safe: bool`/`high_contrast: bool` toggle that maps to the existing accessibility/non-color cue layer (presentation hint only — see Accessibility note). Do NOT add ANY field that scales enemy stats, HP, damage, reward rates, RNG, or run length.
  - [x] `parse()` must SANITIZE every field deterministically: coerce types, clamp numerics to named bounds, fall back to documented defaults for missing/NaN/inf/out-of-range/wrong-type values, and NEVER fail-hard except on schema mismatch (preferences should degrade gracefully so a slightly stale/partial settings file still loads). Reuse `TacticalTextScale.from_value(...).scale-equivalent` clamping for `text_scale` rather than writing a fourth clamp. Keep value sanitization in ONE place per field.
  - [x] Add a guardrail surface the test can assert against: the snapshot/model must expose its known preference keys (e.g. a `const PREFERENCE_KEYS` or the `to_dictionary()` keys) and MUST NOT contain any difficulty/`easy`/`normal`/`hard`/`difficulty_tier`/`enemy_scaling` key. AC2's no-difficulty-ladder is enforced by a test asserting these forbidden keys are absent (see Difficulty Non-Goal Contract).
- [x] 2.9.3 Implement `SettingsRepository` persisting to a SEPARATE `user://settings.json` (never the run autosave). (AC: 1)
  - [x] Add `godot/scripts/settings/settings_repository.gd` (`SettingsRepository extends RefCounted`). Mirror `SaveRepository`'s structured, atomic temp/replace write and the `FileAccess`+`JSON.parse_string` read, but with `const DEFAULT_SETTINGS_PATH := "user://settings.json"` (architecture Configuration table: "Player settings | `user://settings.json` | Safe user preferences only"). `write_settings(snapshot, path := DEFAULT_SETTINGS_PATH) -> ActionResult` and `read_settings(path := DEFAULT_SETTINGS_PATH) -> ActionResult`.
  - [x] Read behavior: `save_not_found` -> return `defaults()` as a successful result (a first launch has no settings file; AC1 "settings can be loaded" must succeed with defaults, NOT error). `save_open_failed`/`save_parse_failed`/`unsupported_settings_schema` -> structured error OR documented fallback-to-defaults; pick ONE policy and test it. Recommended: parse failure or unreadable file returns defaults with a diagnostic note in metadata (preferences must never block the player), while a deliberate schema-version mismatch returns `unsupported_settings_schema`. State the chosen policy in a code comment and the Completion Notes.
  - [x] Write/read MUST round-trip through real JSON (`JSON.stringify` -> `JSON.parse_string`), and the test MUST exercise the real `user://settings.json` write->read path (Epic 2 retro rule: always JSON-round-trip snapshots in tests, not native dicts). `text_scale`/`master_volume_db` are bounded small floats (<= 2.0 / >= -60.0), well within IEEE-754 double precision — the int64-string encoding the run save needs does NOT apply here; plain numeric JSON is correct for these fields. Do not over-engineer string encoding for bounded floats.
  - [x] CRITICAL no-cross-contamination assertion (AC1): a settings save/restore MUST NOT read, write, or mutate `user://run_autosave.json` or any run/tactical/RNG state. Add a test that writes a run autosave, then writes+reads settings, then re-reads the run autosave and asserts it is byte-for-byte / snapshot-equal unchanged. Settings and run saves are independent files.
- [x] 2.9.4 Implement the immediate-apply binding (AC4) without making settings own gameplay. (AC: 1, 4)
  - [x] Add a thin apply path so changing audio/text/input preferences takes effect immediately where practical. Recommended: a `SettingsApplyService` (`RefCounted`) or thin methods that, given a `SettingsSnapshot`, call `AudioManager.set_master_volume_db(snapshot.master_volume_db)` + `AudioManager.mute_master(snapshot.audio_muted)` and surface the clamped `text_scale` as a presenter hint (via `TacticalTextScale`) for the HUD/inspect panels to consume. The apply path must be presentation/preferences only — it MUST NOT execute commands, draw RNG, mutate tactical truth, or alter run progression.
  - [x] If you add a thin `SettingsManager` autoload to hold the current `SettingsSnapshot` + repository + apply wiring, register it in `godot/project.godot` `[autoload]` (alongside `GameSession`/`SaveManager`/`AudioManager`) and keep it THIN (load/store/apply delegation only; no gameplay decisions, no schema policy — those live in the snapshot/repository). An autoload is OPTIONAL: a `RefCounted` apply service tested directly is acceptable and keeps the footprint smaller. If you DO add the autoload, add a test that it delegates to the repository and returns the structured `ActionResult` unchanged (mirror `test_save_repository.gd::_save_manager_autosave_between_level_delegates_to_repository`).
  - [x] AC4 "immediate where practical, optional presentation behavior, not an alternate ruleset": assert (headlessly) that applying a settings change drives the audio bus (`AudioServer.get_bus_volume_db`/`is_bus_mute` after apply) and yields the expected `text_scale` presenter hint, AND that NOTHING about tactical state changes — reuse a board/RNG fixture, snapshot it, apply every settings field, and assert the board `to_snapshot()` + RNG `to_snapshot()` are byte-identical before/after (AC1's "without mutating tactical truth, RNG state, rewards, or progression"). NOTE: the headless test runner may not register audio buses identically to a full run; if `AudioServer.get_bus_index("Master")` returns `-1` in headless, guard the audio-bus assertion behind that check and still assert the snapshot carried the right `master_volume_db`/`audio_muted` values (the apply call must not crash when the bus is absent — `AudioManager` already guards `bus_index >= 0`).
- [x] 2.9.5 Record the difficulty NON-GOAL + post-MVP challenge framing as documentation (AC: 2, 3)
  - [x] AC3 is largely a DECISION/DOCUMENTATION requirement: confirm in the Dev Agent Record / Completion Notes that NO selectable difficulty ladder exists, that MVP difficulty is sourced from run systems (run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, boss prep), and that post-MVP challenge content is framed as explicit variants/trials/oaths/special runs — NOT a generic difficulty selector. Cite the GDD "Difficulty Modifiers — Difficulty and Challenge Systems Baseline v0" (gdd.md lines 397-405).
  - [x] Enforce the non-goal with a regression test (so a future contributor cannot silently add a difficulty tier): assert the `SettingsSnapshot` preference keys contain NONE of `{difficulty, difficulty_tier, easy, normal, hard, challenge_level, enemy_scaling, damage_multiplier}` and that `to_dictionary()` exposes ONLY the documented preference keys. This is the executable form of AC2/AC3.
  - [x] If you write any UX/content note for settings, keep difficulty out of the settings surface entirely. Do NOT create a new standalone UX doc just for this; a short note in this story's Dev Notes + the guardrail test satisfies AC3. If a post-MVP "challenge/variant/oath/trial" concept is referenced anywhere, label it explicitly as post-MVP variant content, not a difficulty ladder.
- [x] 2.9.6 Run required validation and update story records. (AC: 1-4)
  - [x] Run through PowerShell (the bare `godot` resolves only as `C:\Users\Rasmus\bin\godot.cmd` via PowerShell; the Bash tool PATH cannot find it): `godot --version`, then `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`, then `git diff --check`.
  - [x] Expect: Godot `4.6.3.stable.official...`; the full headless runner exits code `0`; all prior Epic 1 + Story 2.1-2.8 tests stay green (including the save/resume suite: `test_save_repository.gd`, `test_run_snapshot.gd`, `test_run_resume_service.gd`, `test_between_level_save.gd`, `test_resume_flow.gd`, and `test_rng_stream_set.gd`'s int64 round-trip); `git diff --check` reports no whitespace errors.
  - [x] Update this story's Dev Agent Record, Completion Notes, File List, Change Log, and Status. Record the AC3 difficulty-non-goal decision explicitly. Keep `sprint-status.yaml` synchronized with this story's status (and confirm whether epic-2 closeout is in scope — this is the LAST Epic 2 story; the orchestrator owns the epic-2 status flip, do not flip it yourself unless instructed).
  - [x] Clean up every `user://` artifact your tests create (`settings.json`, `*.json.tmp`, `*.json.bak`, any test settings path, and any run-autosave the cross-contamination test wrote). Leave `user://` clean.

## Dev Notes

### Pre-Implementation Gate

This is the **ninth and final Epic 2 implementation story** (Sprint Slice: Settings + difficulty non-goal guardrails). It closes Epic 2's UI/accessibility/save foundation. Story-creation analysis on 2026-06-15 found:

- `epic-1: done`; Stories 2.1-2.8 all `done`; Story 2.9 `backlog` before this file was created (create-story flips it to `ready-for-dev`).
- There is currently **NO settings subsystem anywhere** in `godot/`. A project-wide grep for `settings`/`Settings` finds only the presentation view-models (`tactical_text_scale.gd`, `tactical_accessibility_model.gd`, `tactical_layout_profile.gd`) that explicitly say "NOT a settings store ... Persistence belongs to Story 2.9", plus `test_project_configuration.gd`. The settings store, repository, and apply path are the greenfield deliverable here.
- The save layer (`SaveRepository`, `RunSnapshot`) and audio autoload (`AudioManager`) already exist and are the PATTERN/integration points — mirror the repository pattern and drive the audio bus; do NOT fold settings into the run save.

Before implementing, re-confirm the local tree is clean or that dirty files are intentional user work. If any Story 2.1-2.8 status regressed, stop and restore that boundary first.

### Scope Boundary

This story delivers a **player-preferences subsystem** that is strictly separate from run/tactical domain state: a `SettingsSnapshot` DTO (text scale, audio volume/mute, input preference), a `SettingsRepository` persisting to its OWN `user://settings.json`, an immediate-apply binding to the existing audio bus + text-scale presenter hint, and the **explicit difficulty NON-GOAL guardrail** (no selectable difficulty ladder, enforced by a regression test and recorded as a decision).

In scope:

- A data-layer `SettingsSnapshot` (`RefCounted`) with schema/content version, sanitized/clamped preference fields, `to_dictionary()`/`parse()`/`defaults()`, mirroring the `RunSnapshot` DTO shape.
- A `SettingsRepository` (`RefCounted`) that atomically writes and reads `user://settings.json` through real JSON, returns `defaults()` on first-launch (no file), and surfaces structured failures (or documented graceful fallback) — independent of the run autosave file.
- A thin immediate-apply path (a `RefCounted` apply service and/or a thin `SettingsManager` autoload) that drives `AudioManager` and the `TacticalTextScale` presenter hint, with NO gameplay/RNG/tactical mutation.
- The difficulty non-goal enforced as documentation (Dev Agent Record) AND as a guardrail test asserting forbidden difficulty keys are absent.
- Tests: model defaults/clamping/round-trip, repository save/restore + first-launch defaults + structured failure, the cross-file no-contamination assertion (settings never touches the run save), the immediate-apply + no-tactical-mutation assertion, and the difficulty non-goal regression.

Out of scope (owned elsewhere — do NOT build here):

- **Any difficulty tier / easy-normal-hard selector / difficulty ladder.** This is the deliberate NON-GOAL. MVP difficulty comes only from run systems. Post-MVP challenge is explicit variant/trial/oath/special-run content, never a settings toggle. [Source: gdd.md#Difficulty Modifiers; epics.md Story 2.9 AC2/AC3]
- **Persisting settings into the run autosave.** Settings live in a SEPARATE file (`user://settings.json`). The run autosave (`user://run_autosave.json`) is Story 2.7/2.8 territory and must remain untouched by settings. [Source: game-architecture.md#Data Persistence — "Player settings and profile/meta data in separate files from current-run autosave"; #Configuration table]
- **Profile/meta-progression save files.** Oath Shards, unlocks, mastery, codex, and meta progression are Epic 8 in their own profile file — not settings. Do not create a profile/meta store here.
- **Polished settings scenes/menus and a full options UI.** No standalone UX file exists; Epic 2 keeps UI in testable scene-free view-models/contracts (Story 2.5's deferral). Deliver a scene-free apply/preferences contract a presenter can later bind; do not build the final settings `Control` scene in this domain story. (A later UI story wires the actual screen.)
- **Real audio content / mixing buses beyond Master.** `AudioManager` exposes only a Master bus today; settings drive that. Do not add new buses, audio assets, or an audio subsystem.
- **Localization, key-rebinding UIs, graphics/quality tiers, accessibility features beyond text-scale + the existing non-color cue toggle.** Those are later/out-of-scope. Keep MVP preferences to text scale, audio volume/mute, and a simple input preference.
- Cloud saves, accounts, multiplayer, leaderboards, telemetry, Godot .NET/C#, React/Vite production dependencies, or new test frameworks.

### Current Repository Baseline (READ THIS FIRST — settings is greenfield; mirror the save pattern, integrate with audio + text-scale)

The most important constraint: **settings is a NEW, separate subsystem. Do NOT extend `RunSnapshot`/`SaveRepository` or write into the run autosave.** Mirror their proven shape in a parallel `scripts/settings/` module and integrate with the existing audio + text-scale presentation pieces.

- `godot/scripts/save/save_repository.gd` — `SaveRepository extends RefCounted`. The PATTERN to mirror: atomic temp/replace write (`*.tmp` -> backup `*.bak` -> rename), structured `ActionResult` errors (`save_open_failed`/`save_backup_failed`/`save_replace_failed` on write; `save_not_found`/`save_open_failed`/`save_parse_failed` on read), `JSON.stringify`/`JSON.parse_string` transport, default path constant. Copy this shape for `SettingsRepository` with `DEFAULT_SETTINGS_PATH := "user://settings.json"`. Do NOT add settings methods onto `SaveRepository` (it is run-save only).
- `godot/scripts/save/snapshots/run_snapshot.gd` — `RunSnapshot extends RefCounted`, `SCHEMA_VERSION = 1`, `content_version = "mvp-0"`, typed fields, `to_dictionary()`, lenient `parse(data) -> ActionResult` (rejects only `unsupported_save_schema`), `from_dictionary()`. The DTO PATTERN to mirror for `SettingsSnapshot` — same schema/version/`parse`/`to_dictionary` shape, but with preference fields and a `defaults()` factory. The run save uses int64-string encoding for `root_seed`/RNG `state`; **settings does NOT need that** — its floats are small/bounded (text_scale <= 2.0, volume_db >= -60.0) and round-trip exactly as plain JSON numbers.
- `godot/scripts/core/results/action_result.gd` — `ActionResult` (`succeeded`, `is_error()`, `error_code: StringName`, `metadata: Dictionary` deep-copied). `ok(events, metadata)` / `error(code, metadata)`. Error codes MUST be lower-snake (no spaces/dots/colons/dashes/slashes/quotes) or they collapse to `invalid_error_code`. Reuse for every settings result; pick stable lower-snake codes (`unsupported_settings_schema`, `settings_parse_failed`, etc.).
- `godot/scripts/ui/view_models/tactical_text_scale.gd` — `TacticalTextScale extends RefCounted`. Owns the canonical text-scale bounds: `MIN_TEXT_SCALE = 0.85`, `MAX_TEXT_SCALE = 2.0`, `DEFAULT_TEXT_SCALE = 1.0`, and `from_value(value)` that clamps + flags malformed input (NaN/inf/<=0/non-numeric) to default with stable reason ids. REUSE this for `SettingsSnapshot.text_scale` clamping and for the AC4 presenter hint — do NOT write a second text-scale clamp. Its own doc comment explicitly says "Persistence belongs to Story 2.9" — this story is that persistence + the settings-side source of the requested scale.
- `godot/scripts/ui/view_models/tactical_accessibility_model.gd` — the non-color cue contract (shape/icon/label/pattern/text channels, severity ids, the preview-vs-committed feedback cues). Its doc comment also says "NOT a settings store". If you add a `colorblind_safe`/`high_contrast` preference, it is a presentation HINT a presenter passes to this model's consumers — settings does not own or duplicate the cue catalog. Keep it a boolean preference; do not re-implement accessibility logic here.
- `godot/scripts/autoloads/audio_manager.gd` — thin `Node` autoload: `set_master_volume_db(volume_db)` and `mute_master(is_muted)`, both guarding `AudioServer.get_bus_index("Master") >= 0`. This is the AC4 audio apply target. The settings apply path calls these. Because it already guards a missing bus, the apply call is headless-safe (no crash when no Master bus is registered) — rely on that guard in tests.
- `godot/scripts/autoloads/save_manager.gd` / `game_session.gd` — examples of the THIN autoload posture (delegate to a `RefCounted` service/repository, return the structured `ActionResult` unchanged, own no schema policy or gameplay decisions). If you add a `SettingsManager` autoload, copy this posture exactly.
- `godot/project.godot` — `[autoload]` currently registers `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, `Diagnostics` (all `*res://scripts/autoloads/*.gd`). If you add a `SettingsManager` autoload, register it here in the same form; otherwise leave this file untouched.
- `godot/tests/unit/test_case.gd` — the custom headless harness base. Tests `extends "res://tests/unit/test_case.gd"`, expose `run() -> Dictionary`, call `assert_true/false/equal`, and return `result()`. Do NOT add GUT/GdUnit.
- `godot/tests/unit/save/test_save_repository.gd` — the closest test TEMPLATE: it writes/reads through a test path, asserts structured errors, asserts a failed write preserves the prior file, asserts the thin autoload delegates unchanged, and cleans up `user://` artifacts (`*.json`, `*.json.tmp`, `*.json.bak`). Mirror its structure for `test_settings_repository.gd`, including the `_cleanup()` helper pattern.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/save/save_repository.gd` | Run-save atomic write + structured read. | NO change — it is run-save only; do NOT add settings methods. | Atomic write, structured read errors, backup rollback. |
| `godot/scripts/save/snapshots/run_snapshot.gd` | Run-save DTO with int64-string RNG fields. | NO change — mirror its PATTERN in a new `SettingsSnapshot`; do not add preference fields here. | Run-save schema, int64-string encoding, embedded tactical contract. |
| `godot/scripts/ui/view_models/tactical_text_scale.gd` | Text-scale bounds + clamp + presenter hints (no persistence). | Read-only REUSE for `SettingsSnapshot.text_scale` clamp + AC4 hint. No change. | `MIN/MAX/DEFAULT_TEXT_SCALE`, `from_value` clamp/reason ids. |
| `godot/scripts/ui/view_models/tactical_accessibility_model.gd` | Non-color cue contract (no persistence). | Read-only REUSE if you add a colorblind/high-contrast preference (pass a boolean hint). No change. | Cue catalog, channels, severities, feedback cues. |
| `godot/scripts/autoloads/audio_manager.gd` | Thin Master-bus volume/mute autoload (guards missing bus). | Read-only REUSE as the AC4 audio apply target. No change. | Thin posture, `bus_index >= 0` guard. |
| `godot/scripts/autoloads/save_manager.gd` / `game_session.gd` | Thin save/RNG autoloads. | NO change — copy their thin posture if you add `SettingsManager`. | Thin-autoload posture, unchanged `ActionResult` return. |
| `godot/project.godot` | Registers 5 autoloads. | ONLY if you add a `SettingsManager` autoload: register it here in the same form. Otherwise NO change. | Existing 5 autoload registrations, all other project settings. |
| `godot/tests/unit/save/test_save_repository.gd` | Run-save repository tests. | NO change — mirror its structure in a new `test_settings_repository.gd`. | All existing assertions stay green. |

### Recommended New Files

Use these names unless implementation discovers a clearer local pattern:

- `godot/scripts/settings/settings_snapshot.gd` — `SettingsSnapshot extends RefCounted`. Preferences DTO: `SCHEMA_VERSION = 1`, `content_version = "mvp-0"`, fields (`text_scale`, `master_volume_db`, `audio_muted`, `input_scheme`, optional `colorblind_safe`/`high_contrast`), `to_dictionary()`, strict-on-schema `parse(data) -> ActionResult` with per-field sanitize/clamp/defaults, `from_dictionary()`, `static defaults()`. Data-layer only, `RefCounted`, no scene nodes.
- `godot/scripts/settings/settings_repository.gd` — `SettingsRepository extends RefCounted`. Atomic write + structured read to `DEFAULT_SETTINGS_PATH := "user://settings.json"`, mirroring `SaveRepository`; `read_settings` returns `defaults()` on `save_not_found`; documented failure policy for parse/open errors.
- `godot/scripts/settings/settings_apply_service.gd` (OPTIONAL but recommended) — `RefCounted` apply path: given a `SettingsSnapshot`, drives `AudioManager.set_master_volume_db`/`mute_master` and exposes the `TacticalTextScale` presenter hint. No gameplay/RNG/tactical mutation.
- `godot/scripts/autoloads/settings_manager.gd` (OPTIONAL) — thin `Node` autoload holding the current `SettingsSnapshot` + repository + apply wiring, registered in `project.godot`. Only add if a global current-settings holder is genuinely needed; otherwise test the `RefCounted` service directly.
- `godot/tests/unit/settings/test_settings_snapshot.gd` — defaults, per-field clamp/sanitize (text_scale min/max/malformed, volume range, mute bool, input allowlist), JSON `to_dictionary()`/`parse()` round-trip, schema-mismatch rejection, and the difficulty-non-goal forbidden-keys assertion.
- `godot/tests/unit/settings/test_settings_repository.gd` — write->read round-trip through a test path, first-launch `defaults()` on missing file, structured/graceful failure policy, the cross-file no-contamination assertion (settings never touches `user://run_autosave.json`), and `user://` cleanup.
- `godot/tests/unit/settings/test_settings_apply_service.gd` (if you build the apply service/autoload) — AC4 immediate-apply: audio bus driven (guarded for headless), text-scale hint correct, and no tactical/RNG mutation before/after applying every field; thin-autoload delegation if `SettingsManager` exists.

Avoid: a difficulty/challenge field or selector, a new save FORMAT for the run, extending `RunSnapshot`/`SaveRepository`, a settings UI scene, a profile/meta store, a new test framework, or any direct file access outside the repository.

### Settings Persistence Contract (AC1 — separate file, sanitized, graceful)

The single most important constraint: **settings persist to their OWN `user://settings.json` through a `SettingsRepository`, completely independent of the run autosave, and never mutate run/tactical/RNG/progression state.**

- The settings file is `user://settings.json` (architecture Configuration table). The run autosave is `user://run_autosave.json` (Story 2.7/2.8). They are different files with different repositories and must never read or write each other. Add an explicit test proving a settings save leaves the run autosave byte/snapshot-identical.
- `read_settings` on a first launch (no file) returns `defaults()` as a SUCCESS — loading settings must always yield a usable model, never a hard error that blocks the player (AC1 "settings can be loaded"). Reserve structured errors for genuinely malformed input, and even then prefer graceful fallback-to-defaults with a diagnostic in metadata (preferences are non-critical). Document and test the chosen policy.
- Every field is sanitized in `parse()`: clamp `text_scale` via `TacticalTextScale` bounds, clamp `master_volume_db` to a named range, coerce `audio_muted` to bool, validate `input_scheme` against a fixed allowlist (unknown -> default). Missing/NaN/inf/wrong-type -> documented default. A partial or slightly stale settings file should still load with the present fields honored and the rest defaulted.
- Settings is a pure preferences read/write: it executes no commands, draws no RNG, mutates no tactical truth, no rewards, no progression (AC1). Snapshot a board+RNG fixture, run a full settings save/load/apply cycle, and assert the tactical snapshots are byte-identical.

### Difficulty Non-Goal Contract (AC2 + AC3 — make the call, enforce it, record it)

AC2/AC3 are partly a DECISION/DOCUMENTATION requirement and partly an executable guardrail. This is the headline reason the story exists (readiness report GDD FR90/FR91/FR93).

- The canonical rule (cite it): **"Sealsworn will not have player-selectable difficulty tiers. MVP difficulty comes from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, and boss preparation. Post-MVP challenge content can exist as explicit variant content, trials, oaths, or special runs, but not as a generic selectable difficulty ladder."** [Source: gdd.md#Difficulty Modifiers — "Difficulty and Challenge Systems Baseline v0", lines 397-405]
- Enforce it as a REGRESSION TEST: assert `SettingsSnapshot` exposes ONLY documented preference keys and contains NONE of `{difficulty, difficulty_tier, easy, normal, hard, challenge_level, enemy_scaling, damage_multiplier}` (or similar). This makes it mechanically impossible for a future contributor to slip a difficulty toggle into settings without a failing test. This is the executable form of "no difficulty ladder is present".
- Record the DECISION in the Dev Agent Record / Completion Notes: state plainly that no difficulty selector exists, that difficulty is run-system-sourced, and that post-MVP challenge is variant/trial/oath/special-run content (not a ladder). AC3 is satisfied by this recorded framing + the guardrail test; do NOT create a separate UX document solely for this.
- If ANY challenge/variant concept is referenced in a note, label it explicitly as post-MVP variant content. Never describe a "difficulty option" in the settings surface.

### Immediate-Apply Contract (AC4 — visible/audible now, still just preferences)

AC4 requires that changing text/audio/input preferences takes effect immediately where practical, while remaining presentation/preferences behavior — never an alternate ruleset.

- Audio: applying a settings change calls `AudioManager.set_master_volume_db(...)` + `AudioManager.mute_master(...)`, which drive the `Master` `AudioServer` bus. Assert post-apply `AudioServer.get_bus_volume_db`/`is_bus_mute` reflect the snapshot — but GUARD this assertion behind `AudioServer.get_bus_index("Master") >= 0` because the headless runner may not register the bus; when absent, the apply call must not crash (AudioManager already guards it) and you still assert the snapshot carried the right values.
- Text scale: applying yields the clamped `text_scale` and the `TacticalTextScale` presenter hint a HUD/inspect presenter consumes — there is no scene in this story, so assert the hint VALUE, not a rendered control.
- Input preference: `input_scheme` is a stored preference a later input/presenter layer reads; in this story it is round-tripped and validated, not wired to live input handling (no `InputMap` rebinding here).
- The "not an alternate ruleset" guarantee is the same no-mutation assertion as AC1: applying every settings field must leave board `to_snapshot()` + RNG `to_snapshot()` byte-identical. Text scale changing "no gameplay rule" is exactly the Story 2.6 contract (`TacticalTextScale` doc: "no gameplay rule changes with text scale") — settings persistence must preserve it.

### State / No-Mutation Contract

Settings load/save/apply are pure preferences operations. They must never mutate run/tactical/RNG/progression state or touch the run autosave.

Never during settings load/save/apply:

- Read, write, truncate, or rename `user://run_autosave.json` (or its `.tmp`/`.bak`) — settings uses `user://settings.json` exclusively.
- Execute move/attack commands, the command-bridge execute path, or any tactical mutation.
- Draw gameplay RNG or call `rand_*` (settings has no RNG; the apply path is deterministic).
- Alter rewards, gold, Oath Shards, corruption, affinities, passives, route, or meta progression.
- Activate a half-parsed settings model in a way that crashes the player — degrade to defaults for malformed fields.
- Block loading on a missing settings file — first launch returns `defaults()` successfully.

### Previous Story Intelligence

Story 2.8 (Resume Flow and Mid-Level Save Feasibility) is the immediate predecessor and explicitly carved settings OUT of its scope: *"Settings persistence / profile/meta save files — Story 2.9 owns settings; profile/meta live in separate files (architecture Data Persistence). This story resumes only the current-run autosave."* So the run save/resume path is complete and must NOT be touched by settings. Reuse its DTO+repository PATTERN (mirror, don't extend) and its test rigor (structured errors, no-mutation/no-partial-state assertions, `user://` cleanup).

Story 2.7 (Between-Level Save Snapshot Foundation) established the save transport conventions this story mirrors:

- **The save format / JSON-round-trip rule (carry it forward):** always JSON-round-trip snapshots in tests (write->read through the repository, not native dicts). Settings tests MUST exercise the real `user://settings.json` write->read. HOWEVER, the int64-string encoding Story 2.7 added for `root_seed`/RNG `state` is for full-64-bit fields that lose precision through IEEE-754 doubles — **it does NOT apply to settings' bounded small floats** (`text_scale` <= 2.0, `master_volume_db` >= -60.0). Use plain numeric JSON for those; do not over-engineer string encoding for bounded preference values. (Folding in the Epic 2 retro note about int64-string encoding: it is a deliberate non-application here, stated so the dev does not blindly copy it.)
- **The expected-stderr note (Epic 2 retro, Story 2.8):** if you write a deliberate non-JSON / malformed-parse test for `SettingsRepository`, Godot's `JSON.parse_string` prints one expected `ERROR: Parse JSON failed` line to stderr. The test passes and the runner still exits `0` — reviewers must NOT read that stderr diagnostic as a suite failure; it is the cost of exercising the real parse-failure path. (Same caveat the save tests already carry.)
- Story 2.7/2.8 kept save DTOs `RefCounted` and `SaveManager`/`GameSession` thin, proving no-mutation with before/after snapshot equality. Apply the same posture: `SettingsSnapshot`/`SettingsRepository`/`SettingsApplyService` are `RefCounted`, any `SettingsManager` autoload stays thin, and every load/apply path gets a no-mutation assertion.

Epic 2 UI/accessibility stories (2.5/2.6) are the integration points and explicitly deferred persistence to this story:

- `TacticalTextScale` (Story 2.6) owns text-scale bounds/clamping and says verbatim "Persistence belongs to Story 2.9". This story provides the persisted SOURCE of the requested text scale and reuses `TacticalTextScale.from_value(...)` for clamping — do NOT duplicate the clamp logic.
- `TacticalAccessibilityModel` (Story 2.6) owns the non-color cue contract and says "NOT a settings store". A `colorblind_safe`/`high_contrast` preference (if added) is a boolean hint passed to presenters — settings never re-implements the cue catalog.
- **The Epic 2 view-model layer is presentation-only and is NOT save truth.** Do not serialize any view-model output (`TacticalBoardViewModel` and its 16 keys incl. `layout`/`accessibility`, layout profiles, cues) into settings. Settings stores explicit preference fields ONLY; presenters DERIVE rendering from those preferences. [Epic 2 retro: `TacticalBoardViewModel.to_dictionary()` grew to 16 keys across 2.5/2.6 — irrelevant to settings; do not let it leak in.]

Epic 1 / earlier review lessons that still apply:

- Failed/invalid input paths need structured `ActionResult.error()` with stable lower-snake codes + diagnostic metadata (or, for non-critical preferences, a documented graceful fallback) — never a silent crash or a half-applied state.
- `ActionResult.ok()/error()` deep-copy metadata and normalize codes; reuse, don't reimplement.
- Value sanitization has been tightened repeatedly across reviews — clamp/coerce every numeric and validate every enum-like string field deterministically, in ONE place per field.

### Git Intelligence

Recent commits before this story:

- `a0d2b12 chore(story-2-9): start auto-gds pipeline`
- `dff0c93 Merge pull request #5 from rthunborg/story/2-8-resume-flow-and-mid-level-save-feasibility`
- `6b69dfb chore(story-2-8): finalize (mark done + GDS status)`
- `c04a546 docs(story-2-8): pipeline report`
- `cf04472 feat(story-2-8): run resume service + mid-level save feasibility`

Actionable patterns:

- The project consistently uses narrow typed `RefCounted` DTOs/services under `scripts/<domain>/`, thin autoloads under `scripts/autoloads/`, and tests-first under `tests/unit/<domain>/`. Create a new `scripts/settings/` domain folder + `tests/unit/settings/` to match (mirrors how `scripts/save/` + `tests/unit/save/` are organized).
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry/`.tscn` edit is needed.
- ENVIRONMENT (Epic 2 retro): the bare `godot` resolves only as `C:\Users\Rasmus\bin\godot.cmd` through PowerShell; the Bash tool's PATH/`where` cannot find it. Run `godot --version` and the headless suite through `powershell.exe -NoProfile -Command`.
- Review findings across the project have repeatedly tightened value sanitization, no-mutation/no-partial-state assertions, stable reason/error ids, and structured error metadata. Treat all four as first-class for the settings parse, repository failure, and apply tests.

### Architecture Compliance

- Player settings persist as versioned local JSON in a SEPARATE file from the current-run autosave, written through a repository, not raw file access from gameplay. The file is `user://settings.json`. [Source: game-architecture.md#Data Persistence — "Player settings and profile/meta data in separate files from current-run autosave"; #Configuration table — "Player settings | `user://settings.json` | Safe user preferences only"]
- Settings hold "safe user preferences only" — text scale, audio, input preference. NO gameplay/balance/difficulty values. Balance/content lives in the content pipeline layer; true invariants are code constants; settings is a distinct configuration layer. [Source: game-architecture.md#Configuration layered table]
- Gameplay systems depend on repository contracts, not raw JSON files; settings go through `SettingsRepository`. [Source: game-architecture.md#Data Persistence, #Data Access Pattern; project-context.md "Do not access files directly from gameplay systems; use repositories."]
- Thin autoloads (`AudioManager`, optional `SettingsManager`) may exist but must delegate and own no gameplay decisions or schema policy; the settings DTO/repository/apply service are `RefCounted`. [Source: game-architecture.md autoload rules; project-context.md "Keep autoloads thin"]
- `scripts/settings/` (a presentation/preferences-adjacent domain) must not own or mutate tactical truth, RNG, or progression; settings are not authoritative gameplay state. [Source: game-architecture.md system-location rules; project-context.md "Do not let UI mutate domain state directly", determinism rules]
- Determinism under seeded execution is preserved: settings draw no RNG and changing any preference does not alter tactical outcomes (NFR13, and the Story 2.6 "no gameplay rule changes with text scale" contract). [Source: project-context.md Determinism rules; NFR13; epics.md Story 2.6 AC2]
- The MVP must NOT introduce a difficulty selector; difficulty is emergent from run systems, and post-MVP challenge is explicit variant content. [Source: gdd.md#Difficulty Modifiers; epics.md Story 2.9 AC2/AC3; FR90/FR91/FR93]
- Headless tests run without rendering, audio scenes, UI scenes, presentation nodes, or scene-tree-only state (guard the audio-bus assertion for headless). [Source: project-context.md Testing rules; NFR14]
- Do not add cloud services, accounts, multiplayer, telemetry, Godot .NET/C#, new test frameworks, or React/Vite production dependencies. [Source: project-context.md Critical Don't-Miss rules]
- Scalable text and colorblind-safe (non-color) tactical info are NFRs settings supports via text_scale + the existing non-color cue layer — settings exposes the preference; the cue/readability logic stays in the Story 2.6 view-models. [Source: NFR8, NFR9; epics.md Story 2.6]

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build. Required language: typed GDScript.
- The settings DTO, repository, and apply service are `RefCounted` (NOT `Node`, NOT autoloads). A thin `SettingsManager` autoload is the ONLY optional `Node`, and it stays delegation-only.
- Use `JSON.stringify()` / `JSON.parse_string()` for the settings file transport, inside `SettingsRepository` only (mirror `SaveRepository`). `JSON.parse_string()` returns `null` on parse failure -> surface as a structured `settings_parse_failed` or graceful default per the chosen policy. `user://` is the per-user writable directory and is the settings location (never `res://`, read-only in exported builds). [Source: Godot 4.6 docs — class_json, class_fileaccess, io/data_paths]
- Reuse `TacticalTextScale` (`from_value`, `MIN/MAX/DEFAULT_TEXT_SCALE`) for text-scale clamping/hints; reuse `AudioManager.set_master_volume_db`/`mute_master` for audio apply. Do NOT add `AudioStreamPlayer`/new buses.
- Use `Dictionary.duplicate(true)` for defensive copies in `to_dictionary()`/`parse()` (mirror `RunSnapshot`).
- Use the existing custom headless harness: tests `extends "res://tests/unit/test_case.gd"`, expose `run() -> Dictionary`, return `result()`. Do NOT add GUT, GdUnit, or another testing dependency.

### Latest Technical Information

Official Godot 4.6 sources relevant to reading/writing a small JSON preferences file through a repository (these inform file-I/O / parse correctness, not gameplay):

- `FileAccess.file_exists` / `FileAccess.open(..., READ|WRITE)` and `JSON.stringify`/`JSON.parse_string` are the primitives `SaveRepository` uses and `SettingsRepository` should mirror; `JSON.parse_string` returns `null` on parse failure. Keep all file I/O inside the repository. Source: https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html and https://docs.godotengine.org/en/4.6/classes/class_json.html
- `user://` resolves to the per-user writable data directory and is the settings location (`user://settings.json`); `res://` is read-only in exported builds. Source: https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html
- `AudioServer.get_bus_index("Master")`, `set_bus_volume_db`, `set_bus_mute`, `get_bus_volume_db`, `is_bus_mute` drive the audio apply; in a headless run the Master bus may be present from `default_bus_layout.tres` or absent — guard reads behind `get_bus_index >= 0` (as `AudioManager` already does for writes). Source: https://docs.godotengine.org/en/4.6/classes/class_audioserver.html
- Small bounded floats (text_scale, volume_db) round-trip exactly through `JSON.stringify`/`parse_string` (well within the 52-bit mantissa). The int64-string encoding the run save uses for `root_seed`/RNG `state` is NOT needed for settings. Source: https://docs.godotengine.org/en/4.6/classes/class_json.html

### Project Structure Notes

- The settings subsystem belongs under a NEW `godot/scripts/settings/` folder (`settings_snapshot.gd`, `settings_repository.gd`, optional `settings_apply_service.gd`), mirroring how `scripts/save/` is organized. An optional thin `SettingsManager` autoload goes under `godot/scripts/autoloads/` and is registered in `project.godot`.
- Settings tests belong under a NEW `godot/tests/unit/settings/` folder, mirroring `godot/tests/unit/save/`.
- Settings persist to `user://settings.json`; the run autosave at `user://run_autosave.json` is separate and untouched.
- Tactical truth / command validation stays under `godot/scripts/tactical/` and `scripts/core/`; do not move any gameplay logic into the settings layer.
- Production code stays under `godot/`; no production dependency on `prototype/`.
- Root `project-context.md` is canonical; do not create duplicate project context files under `_bmad-output/`.
- No standalone UX file exists; this is a domain/preferences story and needs no UI scene artifact. The polished settings screen is a later UI story (Epic 2 keeps UI in testable view-models/contracts per Story 2.5's deferral). The AC3 difficulty-non-goal framing is recorded here in Dev Notes + enforced by a test; no new UX doc is created.

### Deferred-Work Ledger Check

A review of `_bmad-output/implementation-artifacts/deferred-work.md` (2026-06-15) found **no open deferred item that overlaps this story's settings/difficulty area, files, or ACs.** All recorded deferrals concern the save/RNG float-tolerance hardening (Story 2.7), the tactical accessibility movement-preview guard test (Story 2.6), the adaptive-layout degenerate-rebalance/profile-classifier branches (Story 2.5), the `save_open_failed` resume path (Story 2.8), and Epic 1 board-snapshot coercion — none touch settings persistence, the audio/text-scale apply path, or the difficulty non-goal. Do NOT reopen or address those here; they belong to their originating domains. (Stated explicitly so the dev agent does not go hunting the ledger for settings work — there is none.)

### Testing Requirements

Run at minimum (through PowerShell — the bare `godot` is not on the Bash tool PATH; it resolves only as `C:\Users\Rasmus\bin\godot.cmd` via PowerShell):

```powershell
godot --version
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
git diff --check
```

If invoking from the Bash tool, wrap the commands, e.g. `powershell.exe -NoProfile -Command "godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10"`.

Expected final result:

- Godot version is `4.6.3.stable.official...` or explicitly compatible with project policy.
- The full headless runner exits with code `0`.
- All existing Epic 1 and Story 2.1-2.8 tests remain green — including the save/resume suite (`test_save_repository.gd`, `test_run_snapshot.gd`, `test_run_resume_service.gd`, `test_between_level_save.gd`, `test_resume_flow.gd`) and `test_rng_stream_set.gd`'s int64 JSON round-trip.
- AC1: a `SettingsSnapshot` saved through `SettingsRepository` to `user://settings.json` (or a test path) reads back equal; a first-launch read (no file) returns `defaults()` successfully; every field is sanitized/clamped on parse (text_scale to [0.85, 2.0] via `TacticalTextScale`, volume_db to its named range, audio_muted bool, input_scheme allowlist; malformed -> documented default); a settings save/load/apply cycle leaves a board+RNG fixture's `to_snapshot()` byte-identical (no tactical/RNG/progression mutation); and a settings save does NOT read/write/mutate `user://run_autosave.json` (cross-file isolation test).
- AC2/AC3: `SettingsSnapshot` exposes ONLY documented preference keys and contains NONE of `{difficulty, difficulty_tier, easy, normal, hard, challenge_level, enemy_scaling, damage_multiplier}` (difficulty-non-goal regression test); the Dev Agent Record records the no-difficulty-ladder decision with the run-system difficulty sourcing and post-MVP variant/trial/oath framing, citing gdd.md#Difficulty Modifiers.
- AC4: applying a `SettingsSnapshot` drives the `Master` audio bus (`get_bus_volume_db`/`is_bus_mute` reflect the snapshot — guarded behind `get_bus_index("Master") >= 0` for headless; the apply call does not crash when the bus is absent) and yields the expected `text_scale` presenter hint; applying every field mutates no tactical/RNG state; if a `SettingsManager` autoload exists, it delegates to the repository and returns the structured `ActionResult` unchanged.
- All settings tests clean up their `user://` temp files (`settings.json`, `*.json.tmp`, `*.json.bak`, any test path, and any run-autosave the isolation test wrote). Leave `user://` clean.
- `git diff --check` reports no whitespace errors.
- NOTE: a deliberate malformed-JSON settings-parse test (if added) prints one expected `ERROR: Parse JSON failed` line to stderr; the test still passes and the runner exits `0` — this stderr diagnostic is NOT a suite failure (same as the save tests).

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes (Data Persistence, Configuration layered table).
- Determinism: settings draw no RNG and change no tactical outcome; named RNG streams remain the only gameplay randomness. Changing text scale, audio, or input preference is presentation/preferences only and "no gameplay rule changes with text scale."
- Repositories, not raw file access: settings go through `SettingsRepository`; gameplay systems never read JSON directly.
- Thin autoloads only: any `SettingsManager` delegates and owns no gameplay decisions or schema policy; the snapshot/repository/apply service are `RefCounted`.
- No difficulty ladder: difficulty is a deliberate MVP non-goal sourced from run systems; post-MVP challenge is explicit variant/trial/oath/special-run content. Enforce with the guardrail test and record the decision.
- No cloud/accounts/multiplayer/telemetry/.NET/new-frameworks/prototype dependencies.
- Naming: `snake_case` files/folders, `PascalCase` classes (`SettingsSnapshot`, `SettingsRepository`), `UPPER_SNAKE_CASE` constants, `*Snapshot`/`*Repository` suffix conventions, `test_*.gd` tests. Stable lower-snake `ActionResult` error codes.

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — model id `claude-opus-4-8[1m]`

### Debug Log References

- Full headless suite (PowerShell): `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` -> exit code `0`, 43 PASS / 0 FAIL, "Headless tests passed." Godot `4.6.3.stable.official.7d41c59c4`.
- `git diff --check` -> exit `0` (only benign LF->CRLF line-ending warnings on the two edited tracked text files; no whitespace errors).
- TDD red phase confirmed before any production edit: the three new settings test files failed to load (`Preload file ... does not exist`) while all 40 prior Epic 1 + Story 2.1-2.8 tests stayed green.
- Expected stderr (NOT failures): two `ERROR: Parse JSON failed` lines — one from the pre-existing `test_run_resume_service.gd` malformed-bytes test, one from the new `test_settings_repository.gd::_read_malformed_file_falls_back_to_defaults_with_diagnostic` (deliberately exercises the real `JSON.parse_string` failure path; the test passes and the runner still exits `0`, per the Epic 2 retro note).

### Completion Notes List

- **Greenfield settings subsystem delivered under a new `scripts/settings/` domain** (mirroring `scripts/save/`), strictly separate from run/tactical domain state. No existing run-save/tactical/RNG file was modified.
  - `settings_snapshot.gd` — `SettingsSnapshot extends RefCounted`, `SCHEMA_VERSION = 1`, `content_version = "mvp-0"`, MVP preference fields ONLY: `text_scale` (clamped via `TacticalTextScale.from_value` — reuses the canonical Story 2.6 clamp, no second clamp written), `master_volume_db` (clamped to named `MIN_VOLUME_DB = -60.0` .. `MAX_VOLUME_DB = 0.0`, default `0.0`), `audio_muted` (bool, default false), `input_scheme` (fixed allowlist `auto`/`touch`/`mouse_keyboard`, unknown -> `auto`), plus presentation-hint toggles `colorblind_safe`/`high_contrast` (booleans passed to the Story 2.6 non-color cue layer at the presenter boundary; settings does NOT own the cue catalog). `to_dictionary()`/`parse()`/`from_dictionary()`/`defaults()` mirror `RunSnapshot`. `parse()` is strict-on-schema (only `unsupported_settings_schema` hard-fails) and sanitizes every field deterministically in ONE place each (missing/NaN/inf/out-of-range/wrong-type -> documented default).
  - `settings_repository.gd` — `SettingsRepository extends RefCounted`, `DEFAULT_SETTINGS_PATH := "user://settings.json"`, mirroring `SaveRepository`'s atomic temp -> backup -> rename write and `FileAccess` + `JSON.parse_string` read with settings-prefixed structured error codes (`settings_open_failed`/`settings_backup_failed`/`settings_replace_failed`/`settings_backup_remove_failed`).
  - `settings_apply_service.gd` — `SettingsApplyService extends RefCounted`, AC4 immediate-apply: drives `AudioManager.set_master_volume_db`/`mute_master` (resolved from the autoload when inside a SceneTree; skipped harmlessly in a bare RefCounted context) and returns a `text_scale` presenter hint (re-clamped through `TacticalTextScale`). Presentation/preferences ONLY — executes no commands, draws no RNG, mutates no tactical truth/rewards/progression.
- **Repository read policy (AC1, chosen + documented + tested):** first launch / missing file -> `defaults()` as a SUCCESS with `{first_launch: true}` metadata; unreadable or malformed-JSON file -> graceful `defaults()` SUCCESS with `{recovered: true, recovered_reason: <code>}` (preferences are non-critical and must never block the player); a deliberate schema-version mismatch -> structured `unsupported_settings_schema` error (the file is from an incompatible build, not mere corruption). Stated in a `settings_repository.gd` header comment and enforced by `test_settings_repository.gd`.
- **Thin `SettingsManager` autoload added** (`scripts/autoloads/settings_manager.gd`, registered in `project.godot` `[autoload]` after `AudioManager`). Holds the current `SettingsSnapshot`, delegates load/save to `SettingsRepository` and apply to `SettingsApplyService`, returns every repository `ActionResult` UNCHANGED (never collapsed to a bool), owns NO schema/failure policy and NO gameplay decisions. On boot `_ready()` loads persisted preferences (defaults on first launch) and applies them so audio/text take effect immediately; a load error is logged and in-memory defaults stay active (player never blocked at boot).
- **Bounded floats use plain numeric JSON (deliberate non-application of the run-save int64-string encoding).** `text_scale` (<= 2.0) and `master_volume_db` (>= -60.0) are well within IEEE-754 double precision and round-trip exactly; the int64-string encoding `RngStreamSet`/`RunSnapshot` need for full-64-bit `root_seed`/`state` is correctly NOT used here.
- **Cross-file isolation proven (AC1):** `test_settings_repository.gd::_settings_save_does_not_touch_the_run_autosave` writes a run autosave (composed from a board + RNG fixture), runs a full settings write+read cycle through the settings file, then asserts the run autosave is BYTE-for-byte AND snapshot-identical, and that settings never created the default `user://run_autosave.json`. `test_settings_apply_service.gd` additionally asserts a board `to_snapshot()` + RNG `to_snapshot()` are byte-identical before/after applying every preference field (the AC1/AC4 no-mutation guarantee; the Story 2.6 "no gameplay rule changes with text scale" contract preserved through persistence).
- **DIFFICULTY NON-GOAL DECISION (AC2/AC3) — recorded explicitly:** Sealsworn has **NO player-selectable difficulty tier, no easy/normal/hard selector, and no generic difficulty ladder.** MVP difficulty is sourced entirely from run systems — run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, and boss preparation. Post-MVP challenge content, if any, is framed as **explicit variant content / trials / oaths / special runs — never a settings toggle and never a difficulty ladder.** No standalone UX doc was created (per scope); the decision is recorded here and enforced mechanically. [Source: gdd.md#Difficulty Modifiers — "Difficulty and Challenge Systems Baseline v0", lines 397-405; epics.md Story 2.9 AC2/AC3; readiness FR90/FR91/FR93]
  - Enforced as a regression test: `SettingsSnapshot.PREFERENCE_KEYS` and `to_dictionary()` are asserted to contain ONLY the documented preference keys and NONE of `{difficulty, difficulty_tier, easy, normal, hard, challenge_level, enemy_scaling, damage_multiplier}`. The test also injects a difficulty key into a parse input and asserts `parse()` drops it — a future contributor cannot slip a difficulty toggle into settings without a failing test.
- **AC4 audio apply, headless-guarded:** the audio-bus assertions are guarded behind `AudioServer.get_bus_index("Master") >= 0`; when the Master bus is absent the apply call still succeeds (AudioManager guards the write) and the test only asserts the snapshot carried the right values. In this run the Master bus WAS present (loaded from `default_bus_layout.tres`), so the live `get_bus_volume_db`/`is_bus_mute` assertions executed and passed; tests restore the bus to 0 dB / unmuted afterward to avoid leaking state.
- **No deferred work.** No findings, no overlap with the deferred-work ledger (confirmed in Dev Notes — all recorded deferrals belong to other domains). Nothing postponed.

### File List

New (production):
- `godot/scripts/settings/settings_snapshot.gd`
- `godot/scripts/settings/settings_repository.gd`
- `godot/scripts/settings/settings_apply_service.gd`
- `godot/scripts/autoloads/settings_manager.gd`

New (tests):
- `godot/tests/unit/settings/test_settings_snapshot.gd`
- `godot/tests/unit/settings/test_settings_repository.gd`
- `godot/tests/unit/settings/test_settings_apply_service.gd`

Modified:
- `godot/project.godot` — registered the `SettingsManager` autoload (after `AudioManager`); no other project settings changed.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story status `ready-for-dev` -> `in-progress` -> `review`.
- `_bmad-output/implementation-artifacts/2-9-settings-and-difficulty-non-goal-guardrails.md` — task checkboxes, Dev Agent Record, Completion Notes, File List, Change Log, Status.

### Change Log

| Date | Change |
|---|---|
| 2026-06-15 | Implemented the player-preferences subsystem (`SettingsSnapshot`/`SettingsRepository`/`SettingsApplyService` + thin `SettingsManager` autoload) persisting to `user://settings.json`, separate from the run autosave; wired immediate audio + text-scale apply; enforced the difficulty NON-GOAL via a regression test and recorded the decision. Added 3 settings test files (defaults/clamp/round-trip, repository + cross-file isolation, apply + no-mutation + autoload delegation). Full headless suite green (43 PASS / 0 FAIL, exit 0). Status -> review. |
| 2026-06-15 | Code review (Round 1): verdict APPROVE. 0 Critical / 0 High / 0 Med / 1 Low. All 4 ACs verified satisfied; full headless suite reproduced green (43 PASS / 0 FAIL, "Headless tests passed."); `git diff --check` clean. One Low deferred (valid-JSON settings file missing `schema_version` takes the hard-error path rather than graceful defaults — untested seam, behavior safe). See Review Findings. |
| 2026-06-15 | Code review (Round 2, independent second reviewer / model-diversity pass): verdict APPROVE (concurrence, re-derived not ratified). 0 Critical / 0 High / 0 Med / 0 NEW Low (prior Round-1 Low independently re-confirmed and already deferred; not re-logged). Full headless suite re-run green (43 PASS / 0 FAIL, exit 0); `git diff --check` clean; post-run `user://` sweep clean. 0 new findings persisted, 0 new deferrals. See Review Findings. |

## Review Findings

Code review of story 2-9-settings-and-difficulty-non-goal-guardrails — Round 1, 2026-06-15. Reviewer: Claude (gds-code-review delegate, Opus 4.8 1M). Scope: branch `story/2-9-settings-and-difficulty-non-goal-guardrails` diff vs base `dff0c93` (godot/ only; `_bmad`/`_bmad-output`/caches/non-code excluded). Method: three adversarial layers (Blind Hunter / Edge Case Hunter / Acceptance Auditor) plus reference-pattern comparison against `SaveRepository`/`RunSnapshot`/`TacticalTextScale`/`AudioManager` and a full headless suite re-run.

**Verdict: Approve.** Counts — Critical: 0, High: 0, Med: 0, Low: 1. Open `[Review][Decision]` items (human call): 0.

- [Review][Decision] Verdict APPROVE. The greenfield settings subsystem is correct, well-tested, and faithfully mirrors the proven save-layer pattern without extending it. Atomic temp -> remove-stale-backup -> backup-original -> replace -> remove-backup write (with replace-failure rollback) matches `SaveRepository` exactly; per-field sanitization is single-sourced and deterministic (text_scale reuses the canonical `TacticalTextScale.from_value` clamp — no second clamp; volume clamped to named `MIN/MAX_VOLUME_DB`; input_scheme allowlisted; bool coercion; NaN/inf/wrong-type/missing -> documented defaults). AC1 cross-file isolation is proven by byte-for-byte AND snapshot equality of the run autosave across a full settings write+read cycle, plus an assertion settings never creates `user://run_autosave.json`. AC1/AC4 no-mutation is proven by board `to_snapshot()` + RNG `to_snapshot()` byte-identity before/after applying every field. AC2/AC3 difficulty non-goal is enforced mechanically (`PREFERENCE_KEYS` + `to_dictionary()` forbidden-key assertions, plus an injected-difficulty-key `parse()` drop test) and recorded as a decision citing gdd.md#Difficulty Modifiers lines 397-405 (citation verified accurate). AC4 audio apply is headless-guarded behind `AudioServer.get_bus_index("Master") >= 0`. The `SettingsManager` autoload has no `class_name` (matching `SaveManager`/`GameSession`) so no global-class collision; it stays thin and returns repository `ActionResult`s unchanged. `test_project_configuration.gd` does not assert an exact autoload set, so the new registration does not regress it. Full headless suite re-run: 43 PASS / 0 FAIL, "Headless tests passed."; the two `ERROR: Parse JSON failed` stderr lines are the expected/documented deliberate malformed-parse diagnostics (one pre-existing in `test_run_resume_service.gd`, one new in `test_settings_repository.gd`), not failures. `git diff --check` clean (no whitespace errors). No human-call items outstanding.

- [Review][Defer] (Low) A syntactically-valid JSON settings file that is a Dictionary but MISSING the `schema_version` key (e.g. an empty `{}`, a minimal hand-written file, or a future "partial" settings file an external tool emits) takes the hard-error `unsupported_settings_schema` path, NOT the documented graceful fallback-to-defaults. Trace: `SettingsRepository.read_settings()` passes the `parsed is Dictionary` guard, calls `SettingsSnapshot.parse({})`, which computes `int(data.get("schema_version", -1)) == -1 != SCHEMA_VERSION(1)` and returns the schema-mismatch error. This collides with the story's stated "preferences must degrade gracefully so a slightly stale/partial settings file still loads" / "unreadable or malformed -> defaults" policy: a valid-JSON-but-schemaless object is treated as an incompatible-build mismatch rather than a recoverable partial. The seam is UNTESTED — `test_settings_snapshot.gd::_parse_honors_partial_settings_and_defaults_the_rest` always supplies `schema_version` in its partial dict, and no repository test feeds a `{}`/schemaless valid-JSON file. Impact is SAFE and NOT blocking: `SettingsManager._ready()` catches the error, logs a `push_warning`, and keeps in-memory defaults (the player is never hard-blocked at boot), no crash, no data corruption, and the repository's own writer always emits `schema_version` so the live round-trip never hits this. It is a policy/coverage gap, not a correctness defect. Fix (when convenient): either (a) in `read_settings`, treat a parsed Dictionary that lacks `schema_version` as the graceful `_defaults_result({recovered:true, recovered_reason:"settings_missing_schema"})` path (reserving `unsupported_settings_schema` for a PRESENT-but-mismatched version), or (b) explicitly document that a schemaless valid-JSON file is intentionally a hard mismatch and add a `read_settings({})`/schemaless regression test pinning whichever policy is chosen. (Originating review: code review of 2-9, Round 1, 2026-06-15.)

---

Code review of story 2-9-settings-and-difficulty-non-goal-guardrails — Round 2 (independent second reviewer / model-diversity pass), 2026-06-15. Reviewer: Claude (gds-code-review delegate, Opus 4.8 1M). Scope: same branch diff vs base `dff0c93` (godot/ only; `_bmad`/`_bmad-output`/caches/non-code excluded). Method: findings re-derived from scratch (Blind Hunter / Edge Case Hunter / Acceptance Auditor) — NOT a ratification of Round 1 — plus byte-level reference-pattern comparison against `SaveRepository`/`RunSnapshot`/`TacticalTextScale`/`AudioManager`/`ActionResult`, a full headless suite re-run, a `git diff --check`, and a post-run `user://` artifact sweep.

**Verdict: Approve.** Counts — Critical: 0, High: 0, Med: 0, Low: 0 NEW (1 prior Low independently re-confirmed and already deferred above; not re-logged). Open `[Review][Decision]` items (human call): 0.

- [Review][Decision] Verdict APPROVE (independent concurrence — re-derived, not ratified). Re-ran the full headless suite: 43/43 PASS, "Headless tests passed.", exit 0 (the two `ERROR: Parse JSON failed` stderr lines are the documented deliberate malformed-parse diagnostics — one pre-existing in `test_run_resume_service.gd`, one new in `test_settings_repository.gd::_read_malformed_file_falls_back_to_defaults_with_diagnostic`). `git diff --check` exit 0 (no whitespace errors). Post-run `user://` sweep: NO leftover `settings.json`/`run_autosave.json`/`test_*` artifacts — the per-test `_cleanup()` helpers leave `user://` clean. The `SettingsRepository` atomic-write sequence is a byte-faithful mirror of the already-shipped `SaveRepository` (temp open -> remove-stale-backup -> backup-original -> replace -> remove-backup, with replace-failure rollback); the DTO mirrors `RunSnapshot`'s strict-on-schema/lenient-on-fields `parse()`; sanitization is single-sourced per field (text_scale via the canonical `TacticalTextScale.from_value` clamp; volume clamped to named `MIN/MAX_VOLUME_DB` with NaN/inf/wrong-type guards; input_scheme allowlisted; bool coercion). AC1 cross-file isolation and AC1/AC4 no-mutation are proven against a NON-TRIVIAL fixture (`deterministic_actor_placement`: 4x3 board + entrance/exit terrain + 3 entities, with the RNG advanced before snapshotting), so the byte-identity assertions are substantive, not vacuous. AC2/AC3 difficulty non-goal is enforced mechanically across 8 forbidden keys plus an injected-key `parse()`-drop test and recorded with an accurate gdd.md#Difficulty Modifiers (lines 397-405) citation. `test_settings_repository.gd` covers a strict SUPERSET of the proven `test_save_repository.gd` branch set. Items I examined and consciously did NOT raise (each consistent with the shipped/already-reviewed reference or below the Low bar): (1) the mid-write rollback branches `settings_backup_failed`/`settings_replace_failed`/`settings_backup_remove_failed` are untested — but this exactly matches the equally-untested `save_*` branches in the already-reviewed `SaveRepository`, the code is byte-identical, and those mid-rename failures are not deterministically reproducible on Windows; raising it would be a finding against the reference, not this story; (2) `content_version` is stored unvalidated (`str(...)`, no mismatch check) — identical to `RunSnapshot`, intentional; (3) `MAX_VOLUME_DB = 0.0` forbids positive gain — a deliberate, documented unity ceiling, not a defect; (4) `SettingsManager._ready()` does not re-apply defaults on the schema-mismatch error path — harmless, because the engine's own audio-bus/text defaults (0 dB / unmuted / scale 1.0) already match the held in-memory defaults, so nothing that differs from default is left un-applied. I independently re-traced the prior Round-1 Low (schemaless `{}` valid-JSON -> hard `unsupported_settings_schema` rather than graceful defaults) and CONFIRM it is real, correctly characterized, safe, and non-blocking; it is already recorded above and in the deferred-work ledger, so it is not re-logged. No new findings; no human-call items outstanding.
