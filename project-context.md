---
project_name: 'Sealsworn'
user_name: 'Rasmus'
date: '2026-06-15'
sections_completed:
  - technology_stack
  - engine_rules
  - performance_rules
  - organization_rules
  - testing_rules
  - platform_rules
  - anti_patterns
  - save_serialization_rules
  - presentation_view_model_rules
  - settings_rules
status: 'complete'
rule_count: 140
optimized_for_llm: true
architecture: '_bmad-output/game-architecture.md'
refreshed_after: 'epic-2'
---

# Project Context for AI Agents

This file contains critical rules and patterns that AI agents must follow when implementing game code in this project. Keep it lean, specific, and focused on mistakes agents might otherwise make.

Canonical location: root `project-context.md`. Do not create duplicate project context files under `_bmad-output/`; duplicate context risks stale or conflicting agent instructions.

---

## Core Direction

Sealsworn is a mobile-first, desktop-playable, turn-based dark fantasy roguelite RPG. The player controls one hero through seeded, forward-only procedural levels with fog of war, tactical positioning, weapon-shaped basic attacks, risk/reward routing, loot, passive rule-benders, and meta progression.

Story spine:

> The Labyrinth was not built to keep heroes out. It was built to keep something in.

Design guardrails:

- Game loop first: the game must be fun for players who ignore all lore.
- Story is optional discovery, not required reading.
- Cutscenes and control-loss narrative moments should be skippable.
- Tone is dark medieval fantasy with a cosmic horror undercurrent.
- Ancient containment technology should read as relic-magic or Wardenwork, not science fiction.
- Meta progression expands variety and knowledge more than raw power.
- Passives are awakened memories, oaths, scars, relic echoes, forbidden instincts, or broken protocols.
- Affinities are failed containment protocols and safety measures.
- MVP scope must prove the complete rough roguelite loop before content sprawl.

## Technology Stack & Versions

- Production engine: Godot 4.6.3 stable standard build.
- Primary language: typed GDScript.
- Production project root: `C:/Sealsworn/godot/`.
- Target platforms: iOS/Android mobile and tablet first; Windows desktop/laptop parity.
- MVP mode: offline-first single-player. No accounts, multiplayer, cloud saves, leaderboards, or live-service dependency.
- Prototype: `prototype/` is React/Vite/TypeScript validation evidence only. Production Godot code must not depend on prototype source.
- AI tooling: GoPeak Godot MCP and Context7 are selected once the Godot project exists; Rasmus also has premium access to Codex, Claude, Claude Design, Google Stitch, Google Gemini, and related tools.
- Do not use Godot .NET/C# for MVP. Use the standard GDScript build unless architecture is explicitly revised.
- Project shape (post-Epic 2): main scene is `res://scenes/app/boot.tscn`; viewport is 1080x1920 portrait; renderer is Mobile; `stretch/mode=canvas_items`, `aspect=expand`.
- Registered autoloads (as of Epic 2): `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, `SettingsManager`, `Diagnostics`. Keep them thin; they delegate gameplay decisions to domain services.
- `godot` is NOT on the Bash/`where` PATH on this machine; it resolves only as `C:\Users\Rasmus\bin\godot.cmd` via PowerShell. Run the headless test command through PowerShell (`powershell.exe -NoProfile -Command ...`), not the Bash tool's PATH lookup.

## Critical Implementation Rules

### Engine-Specific Rules

- Use typed GDScript for gameplay, tooling, UI presenters, and tests.
- Godot scenes, `Control` nodes, audio, VFX, and animation are presentation. They must not own authoritative tactical state.
- The scene-independent domain model owns tactical truth: board state, entities, turns, RNG, rules, saves, and run progression.
- Presentation observes domain state/events and submits commands through a command bridge.
- Use Godot signals for presentation/UI feedback, not for hidden domain control flow.
- Keep autoloads thin. Acceptable autoloads: `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, `SettingsManager`, `Diagnostics`. They delegate gameplay decisions to domain services (e.g. `SaveManager.resume_run()` delegates to `RunResumeService`; `SettingsManager` delegates to `SettingsRepository`/`SettingsApplyService`).
- Do not serialize scene nodes as save-game truth. Save versioned domain snapshots only.
- Use custom Godot `Resource` assets for typed editor/runtime definitions, mirrored from JSON/CSV source data when useful.
- Use the Mobile renderer first; keep Compatibility as fallback if low-end device testing demands it.

### Determinism & Simulation Rules

- Gameplay actions are commands. Commands validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense `DomainEvent` records.
- Domain events drive state changes, presentation, replay, logs, saves, tests, and future analytics.
- Use named RNG streams derived from the root seed: `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic`.
- Gameplay-affecting randomness must use its assigned stream. Cosmetic-only randomness cannot affect outcomes, rewards, unlocks, or progression.
- Headless simulation is a first-class target. It must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Manual seed/debug runs may support replay, practice, and debugging, but they must not grant meta progression unless explicitly allowed.

### Rules, AI, and Generation Rules

- Use the Sealsworn rules kernel for passives, items, affinities, curses, classes, bosses, Consume/Destroy choices, and tactical rule-benders.
- Rules use explicit trigger windows, conditions, targets, operations, durations, stacking, conflict handling, and stable resolver ordering.
- Rule-driven outcomes must be explainable in player/debug language.
- Procedural generation runs in phases: route, recipe, layout, pathing, blockers, hazards, enemies, rewards, affinity rules, validation, final snapshot.
- Generator validation failures must report seed, phase, reason, and compact diagnostics.
- Enemy AI uses state/phase-constrained utility scoring over valid tactical actions.
- Every AI decision must be explainable with top score, chosen action, and major reasons.
- Shared tactical query services handle pathfinding, line of sight, threat maps, valid moves, attack previews, and tile scoring.

### Save, Snapshot & Serialization Rules (hardened in Epic 2)

- Snapshots are pure reads. Composing or restoring a snapshot (`RunSnapshot.from_between_level`, `RunResumeService.resume`, `*.to_snapshot`, `try_restore`) must consume NO RNG draws, execute NO commands, advance NO turns, and mutate neither the source domain state nor the save file.
- JSON numbers are IEEE-754 doubles (52-bit mantissa). Any save field that can exceed 2^53 — notably the RNG `root_seed` and each per-stream `state` — MUST be string-encoded (decimal string) in `to_snapshot()`, or `JSON.stringify`/`parse_string` silently truncates it and breaks resume determinism. Restore must read-tolerate the legacy numeric form (int or integral float) AND the string form. Small bounded fields (per-stream `seed` <= 2^31, `draw_index`) may stay numeric.
- ALWAYS JSON-round-trip snapshots in tests (`JSON.stringify` then `parse_string`), never assert only on native dictionaries. A latent int64 precision/resume bug survived Epic 1 precisely because tests round-tripped native dicts instead of real JSON.
- Restore exposes NO partial corrupt state. Each restore step propagates the FIRST validator's structured error verbatim and returns ZERO restored domain objects on failure (the "no partial corrupt state becomes active" guarantee). Restore order for a run: read repository -> strict embedded `TacticalSnapshot.parse` -> `BoardState.try_from_snapshot` -> `RngStreamSet.try_restore`.
- Route an embedded tactical payload through the STRICT `TacticalSnapshot.parse`, never the lenient run-level `RunSnapshot.parse`. Run-level parse is intentionally forward-compatible for run fields; trusting it for the tactical payload could "restore" a corrupt board into a broken shape.
- Compose, do not fork. The between-level save embeds the Epic 1 `TacticalSnapshot` under `level_state["tactical_snapshot"]` (`RunSnapshot.TACTICAL_SNAPSHOT_KEY`). Do NOT flatten tactical board/turn/telegraph/event fields onto the run save or invent a parallel scene-owned tactical save format.
- RNG authority on resume is the run-level `RunSnapshot.rng_streams`. At a between-level boundary it equals the embedded tactical `rng_streams` by construction (both written from one `streams.to_snapshot()` read); a test asserts that equality. Restore the run-level streams as the live gameplay streams.
- Repositories own atomic writes: write to `<path>.tmp`, then backup/replace via `DirAccess.rename_absolute` with `<path>.bak` rollback. Run autosave is `user://run_autosave.json` (`SaveRepository`); settings are `user://settings.json` (`SettingsRepository`). The two files and their repositories are strictly independent — neither reads, writes, truncates, or renames the other.
- Read errors are structured `ActionResult` codes (`save_not_found`, `save_open_failed`, `save_parse_failed`, `unsupported_save_schema`, `invalid_tactical_snapshot`, `invalid_rng_snapshot`), not exceptions. Schema-version changes need migration tests.
- Exercising the real parse-failure path emits one expected `ERROR: Parse JSON failed` line to stderr (Godot's `JSON.parse_string` on deliberate non-JSON bytes). The test still passes and the runner exits 0 — do NOT read that stderr diagnostic as a suite failure.

### Presentation, View-Model & Accessibility Rules (Epic 2)

- Presentation reads domain via semantic view models and submits commands through the command bridge (`scripts/ui/command_bridge/`). View models never own domain truth; they project it.
- `TacticalBoardViewModel.to_dictionary()` has an EXACT sorted-key contract pinned by `test_tactical_board_view_model.gd` (16 keys post-Epic-2, including `layout` and `accessibility`, each defaulting to `{}`). Adding a slot must intentionally bump that assertion — never let a key appear or vanish silently.
- Adaptive layout is a testable SEMANTIC profile first: `TacticalLayoutProfile` plus the sanitized `TacticalBoardViewModel.layout` slot prove the contract scene-free. Build the `Control`/scene presenter (`scripts/ui/presenters/`, `scenes/ui/layouts/<profile>/`) only in a later HUD story. Touch targets stay >= 44px; slots that cannot fit honestly report `reachable: false` rather than overflowing.
- Accessibility is color-INDEPENDENT and audio-absent-equivalent: every committed-action cue must have a visual + textual equivalent that holds with audio off. Preserve the `feedback_preview` (pre-commit, attack-only) vs `feedback_committed` (post-result) distinction; do not collapse them. `AttackPreviewContractMatrix` (`tests/fixtures/tactical/`) is the canonical driver for the color-independence / cue audit — extend it when adding cue vocabulary so no preview ships without an accessibility mapping.
- `TacticalAccessibilityModel` is NOT a settings store; it derives cues from tactical state. Settings holds only the boolean preference (`colorblind_safe`, `high_contrast`) and hands it to this layer at the presenter boundary.

### Settings & Preferences Rules (Epic 2)

- Settings are SAFE preferences only: text scale, master volume / mute, an input-scheme preference, and presentation-hint accessibility toggles. They persist to their own `user://settings.json` via `SettingsRepository` and are NEVER folded into the run autosave or any tactical/RNG/progression state. Future preference work belongs in `scripts/settings/`.
- Loading settings must NEVER hard-block the player at boot. Read policy: missing file (first launch) -> `defaults()` as SUCCESS; unreadable/malformed JSON -> `defaults()` as SUCCESS with a `recovered` diagnostic; schema-version mismatch -> structured `unsupported_settings_schema` error (incompatible build, surfaced not silently overwritten). `SettingsManager._ready()` catches errors and keeps in-memory defaults.
- `SettingsSnapshot.parse` is strict-on-schema, lenient-on-fields: every field is coerced/clamped to named bounds/defaulted; each field's sanitization lives in exactly one helper. Reuse the canonical `TacticalTextScale` clamp rather than writing a second one. Small bounded floats (volume dB) round-trip exactly through JSON; no int64-string encoding needed there.
- Immediate-apply is presentation-only (`SettingsApplyService`): it drives the audio Master bus and surfaces a clamped text-scale presenter hint. Applying ANY preference must leave board/RNG snapshots byte-identical — no command, no RNG draw, no tactical/reward/progression mutation. Guard a missing audio Master bus so headless apply never crashes.
- DIFFICULTY IS A HARD NON-GOAL. Sealsworn has NO player-selectable difficulty tiers. No setting (and nothing in `PREFERENCE_KEYS`) may scale enemy stats, HP, damage, reward rates, RNG, or run length. MVP difficulty comes from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, attrition, and boss prep; post-MVP challenge is explicit variant/trial/oath content, never a generic difficulty ladder. A regression test enforces the absence of difficulty keys — do not add one.

### Performance Rules

- Generated level load target: under 3 seconds for MVP.
- UI preview and selection response target: under 100ms.
- Target stable 60 FPS where feasible; 30 FPS is acceptable on lower-end mobile if input remains responsive.
- Phone-sized combat readability is a first-order requirement, not polish.
- Avoid per-frame work in nodes that can update through events, signals, or explicit refresh calls.
- Cache node references with `@onready`; do not call `get_node()` in hot loops.
- Use static typing in GDScript hot paths.
- Preload only critical shared assets. Load screens/levels by scene boundary. Add threaded loading for heavier art/audio later.
- Define and measure low/mid/high mobile device tiers before production planning.

### Code Organization Rules

- Production Godot files live under `godot/`. Do not mix production implementation into `prototype/`.
- Use the architecture-defined roots: `scripts/`, `scenes/`, `assets/`, `data/`, `tests/`, `tools/`.
- Organize scripts by domain: `core`, `tactical`, `rules`, `generation`, `ai`, `content`, `save`, `settings`, `ui`, `platform`, `diagnostics`, `utils`. Autoload scripts live in `scripts/autoloads/`.
- Keep `scripts/tactical/`, `scripts/rules/`, `scripts/generation/`, `scripts/ai/`, `scripts/save/`, and `scripts/settings/` independent of scene nodes for authoritative/data logic (they are `RefCounted` services + DTOs, not Nodes).
- UI logic lives in `scripts/ui/view_models/` (semantic view models like `TacticalBoardViewModel`, `TacticalLayoutProfile`, `TacticalAccessibilityModel`), `scripts/ui/command_bridge/`, and `scripts/ui/presenters/`; layout scenes live in `scenes/ui/layouts/`.
- Player-preference code lives in `scripts/settings/` (`SettingsSnapshot`, `SettingsRepository`, `SettingsApplyService`). NEVER fold preferences into the run snapshot or any tactical/save state.
- Static content source lives in `data/source/`; typed Godot resource mirrors live in `data/resources/`.
- Editable asset source files, prompts, provenance, and reviews live in `asset_sources/`, not `godot/assets/`.
- Runtime-ready art/audio/fonts/shaders live in `godot/assets/`.

### Naming Rules

- Folders and files use `snake_case`.
- GDScript files use `snake_case.gd`: `attack_command.gd`.
- Scene files use `snake_case.tscn`: `gameplay_shell.tscn`.
- Resource files use `snake_case.tres`: `shadow_ambusher_enemy.tres`.
- Test files use `test_*.gd`: `test_attack_command.gd`.
- Classes use `PascalCase`: `AttackCommand`, `EnemyDefinition`.
- Functions and variables use `snake_case`.
- Constants use `UPPER_SNAKE_CASE`.
- Signals use past-tense/event-style `snake_case`: `damage_applied`, `passive_triggered`.
- Commands use imperative names: `MoveCommand`, `AttackCommand`, `ConsumePassiveCommand`.
- Events use past-tense names: `DamageAppliedEvent`, `TileRevealedEvent`.
- Definitions use `*Definition`; snapshots use `*Snapshot`; results use `*Result`.
- Stable content IDs use lower snake case: `shadow_ambusher`, `iron_sword`, `darkness_affinity`.

### Testing Rules

- Every command needs a unit test for valid execution and invalid/no-mutation cases.
- Rules resolver behavior needs tests for trigger timing, ordering, stacking, conflict handling, and explanation output.
- Generator phases need fixtures or seed regression tests.
- Save snapshots need migration tests for every schema change.
- AI behavior families need tests that verify chosen action and explanation reasons.
- Repository layers need tests or checks preventing direct gameplay file access.
- UI command integration tests should verify view models and command bridge behavior without making UI own domain truth.
- Headless simulation tests must run without rendering, audio, UI scenes, or presentation nodes.
- The headless runner (`tests/headless/test_runner.gd`) auto-discovers and sorts `test_*.gd` under `res://tests/unit` and `res://tests/integration` only; it exits with the failure count. Put new tests there (mirroring the domain), not under `tests/headless` or `tests/fixtures`. Run the full suite via PowerShell: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- Save/snapshot tests MUST exercise a real JSON round-trip (`JSON.stringify` -> `parse_string`), not just native-dict equality; assert that restored RNG streams reproduce the exact next draw. Cover malformed-input rejection paths and assert no partial state is exposed on failure.
- Human playtests remain required for feel, readability, frustration, and excitement.

### Platform & Build Rules

- Preserve native mobile packaging path from the start.
- Android exports require Android Studio, Android SDK, and JDK setup.
- iOS exports require macOS and Xcode when iOS packaging begins.
- Commit `project.godot` and `export_presets.cfg` once the Godot project exists.
- Use versioned export presets and local scripted builds early; add CI after vertical slice.
- Use build-profile flags plus pre-export validation and manual release checklist.
- Debug/cheat tools must be disabled or inert in production builds.
- Test content and experimental assets cannot ship unless explicitly approved for production.
- Platform services stay local/no-op for MVP behind interfaces such as `TelemetrySink`, `SaveSyncProvider`, `AchievementProvider`, and `CrashReporter`.

### Static Content & Asset Rules

- Content may be human-authored or AI-assisted during development, but never dynamically generated by AI at runtime.
- Procedural generation may only select from approved static definitions during play.
- Static content must pass schema validation, semantic validation, applicable simulation/rules smoke tests, and final human approval before production use.
- Human review decides whether an item, passive, enemy, affinity, level recipe, or reward table belongs in Sealsworn.
- Track AI-assisted assets with tool, prompt, date, source references, license/provenance notes, editable source path, runtime export path, and approval status.
- Asset statuses: `exploration`, `placeholder`, `approved_reference`, `production`, `deprecated`.
- Placeholder assets include `_placeholder` in filenames.

### Critical Don't-Miss Rules

- Do not make Godot scene nodes authoritative for tactical state.
- Do not use one global RNG for gameplay.
- Do not call non-seeded randomness for combat, loot, rewards, map, level, event, unlock, or progression outcomes.
- Do not serialize scene nodes into saves.
- Do not access files directly from gameplay systems; use repositories.
- Do not put gameplay decision logic in autoloads.
- Do not let UI mutate domain state directly.
- Do not use the React prototype as production architecture.
- Do not add cloud services, accounts, multiplayer, or telemetry dependencies to MVP gameplay.
- Do not accept generated/AI-assisted content into production without validation and human approval.
- Do not let debug/manual-seed actions grant progression unless explicitly approved by release policy.
- Do not start implementation with UI-heavy scenes before the domain model, commands/events, RNG streams, and tactical board tests exist.
- Do not persist a full-64-bit save field (RNG `root_seed`/`state`) as a raw JSON number; string-encode it or lose precision beyond 2^53.
- Do not fold player preferences into the run save, and do not let `SettingsRepository` touch the run autosave (or vice versa).
- Do not add any player-selectable difficulty tier or any setting that scales enemy stats/HP/damage/rewards/RNG/run length (hard non-goal).
- Do not let a snapshot compose/restore consume RNG draws or mutate source state; keep it a pure read.
- Do not activate partial restored state on a validation failure; propagate the first error and return nothing.
- Do not change `TacticalBoardViewModel.to_dictionary()`'s key set without intentionally updating its exact sorted-key assertion.

---

## Usage Guidelines

For AI agents:

- Read this file before implementing any Sealsworn game code.
- Read `_bmad-output/game-architecture.md` before touching architecture-sensitive systems.
- Treat root `project-context.md` as the only canonical project-context file.
- Follow all rules exactly. When in doubt, choose the more restrictive interpretation.
- If a task conflicts with this file, surface the conflict before implementing.
- Update this file only when the project architecture or implementation conventions intentionally change.

For humans:

- Keep this file lean and focused on rules agents might miss.
- Update when the engine, folder structure, patterns, or platform targets change.
- Remove rules that become obvious or obsolete.
- Treat `_bmad-output/game-architecture.md` as the full source of truth and this file as the compact agent handoff.

Last Updated: 2026-06-15 (refreshed after Epic 2: presentation/view-model contracts, between-level save + resume serialization hardening, settings/preferences isolation, difficulty non-goal)
