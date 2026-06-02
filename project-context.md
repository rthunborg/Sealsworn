---
project_name: 'Sealsworn'
user_name: 'Rasmus'
date: '2026-06-02'
sections_completed:
  - technology_stack
  - engine_rules
  - performance_rules
  - organization_rules
  - testing_rules
  - platform_rules
  - anti_patterns
status: 'complete'
rule_count: 118
optimized_for_llm: true
architecture: '_bmad-output/game-architecture.md'
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

## Critical Implementation Rules

### Engine-Specific Rules

- Use typed GDScript for gameplay, tooling, UI presenters, and tests.
- Godot scenes, `Control` nodes, audio, VFX, and animation are presentation. They must not own authoritative tactical state.
- The scene-independent domain model owns tactical truth: board state, entities, turns, RNG, rules, saves, and run progression.
- Presentation observes domain state/events and submits commands through a command bridge.
- Use Godot signals for presentation/UI feedback, not for hidden domain control flow.
- Keep autoloads thin. Acceptable autoloads: `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, `Diagnostics`. They delegate gameplay decisions to domain services.
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
- Organize scripts by domain: `core`, `tactical`, `rules`, `generation`, `ai`, `content`, `save`, `ui`, `platform`, `diagnostics`, `utils`.
- Keep `scripts/tactical/`, `scripts/rules/`, `scripts/generation/`, `scripts/ai/`, and `scripts/save/` independent of scene nodes for authoritative logic.
- UI logic lives in `scripts/ui/view_models/` and `scripts/ui/presenters/`; layout scenes live in `scenes/ui/layouts/`.
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

Last Updated: 2026-06-02
