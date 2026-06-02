---
title: 'Game Architecture'
project: 'Sealsworn'
date: '2026-06-02'
author: 'Rasmus'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'
engine: 'Godot 4.6.3 stable standard'
platform: 'iOS/Android mobile and tablet; Windows desktop/laptop'

# Source Documents
gdd: '_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md'
epics: '_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md'
brief: '_bmad-output/game-brief.md'
---

# Game Architecture

## Document Status

This architecture document was completed through the GDS Architecture Workflow.

**Steps Completed:** 9 of 9 (Complete)

---

## Executive Summary

Sealsworn will be built as a Godot 4.6.3 standard/GDScript mobile-first tactical roguelite with a scene-independent domain model owning all authoritative gameplay state. The architecture prioritizes deterministic commands/events, named RNG streams, versioned saves, validated procedural generation, extensible rules, adaptive UI composition, and headless simulation for tests, bots, and future balance analysis. Godot scenes, UI, audio, and effects mirror domain outcomes through explicit presentation boundaries rather than owning tactical truth.

---

## Project Context

### Game Overview

**Sealsworn** is a mobile-first, desktop-playable, turn-based dark fantasy roguelite RPG where the player controls a single hero through seeded, forward-only procedural levels with fog of war, tactical positioning, weapon-shaped basic attacks, risk/reward routing, loot, passive rule-benders, and meta progression.

The architectural priority is to prove a complete rough roguelite loop while keeping the tactical board clear, deterministic, debuggable, and comfortable on phone-sized screens.

The working story spine remains:

> The Labyrinth was not built to keep heroes out. It was built to keep something in.

### Technical Scope

**Platform:** iOS/Android mobile and tablet first; Windows desktop/laptop with parity.
**Genre:** Turn-based tactical roguelite RPG.
**Project Level:** High systemic complexity; medium-high MVP scope.
**Mode:** Offline-first single-player.
**Networking:** None for MVP.
**Session Model:** Interruption-friendly, with required save/resume between levels and desirable mid-level save/resume.

Architecture must preserve a native mobile packaging path from the start, even if early internal playable milestones use the fastest development target.

### Source Validation Notes

The Project Context was validated against the GDD, epics, decision log, validation report, game brief, root project context, brainstorming handoff, full brainstorming sessions, PM handoff, and current React/Vite prototype.

Important resolved drift from earlier brainstorming:

- "Diamonds" became **Oath Shards**.
- **Darkness** is selected over Frozen for the MVP affinity set.
- Successful MVP runs target **20-35 minutes**.
- Large/Huge level generation polish is deferred unless needed for the boss or a rare special node.
- The current web prototype is validation evidence, not a final architecture commitment.

### AI-Assisted Production Context

Rasmus has premium access to AI-assisted development and creation tools, including Codex, Claude, Claude Design, Google Stitch, Google Gemini, and related tools. Architecture should treat this as a production advantage for a solo-led project, especially for code generation, design review, UI exploration, asset ideation, documentation, testing support, and production planning.

Future asset and content workflows should explicitly evaluate which AI tools to use for:

- Concept art, mood boards, and visual style exploration.
- UI mockups, layout iteration, and design-system references.
- Icon, passive, item, class, enemy, and affinity visual production.
- Sprite/2D asset generation, cleanup, and consistency passes.
- Sound effects, ambience, music sketches, and audio direction.
- Licensing, provenance, reproducibility, export formats, and editing handoff.

These tools should accelerate production, but the architecture should still define stable content formats, source-control boundaries, and review gates so generated assets remain coherent and replaceable.

### Prototype Evidence

The React/Vite prototype validates several early design assumptions:

- 3-tile movement, 4-tile line of sight, and 18 player HP as Prototype Baseline v0.
- Fog of war with black unexplored tiles and gray explored memory.
- Weapon-shaped basic attacks for sword, dagger, spear, axe, mace, bow, crossbow, staff, and wand.
- Support items for none, tome, and shield.
- Seeded Small and Medium level generation with entrance, exit, blockers, hazards, enemies, and validation.
- URL seed/size replay for debugging.
- Scroll and zoom support for larger tactical boards.
- Playtest metrics for turns, movement, attacks, and damage taken.

Prototype caveat: generation is seeded, but several combat/runtime procs currently use non-seeded randomness. Production architecture must define separate RNG streams and persistence boundaries for generation, combat procs, drops, rewards, and debug/manual-seed eligibility.

### Core Systems

| System | Complexity | Source Reference |
|---|---|---|
| Tactical grid combat and turn resolution | High | GDD Core Turn Rules, Epic 1 |
| Mobile-first input, preview, inspect, and two-step commit | High | GDD Controls and Input, Epic 2 |
| Fog of war, line of sight, explored memory, and visibility effects | High | GDD Core Turn Rules, Level Design Framework |
| Weapon-shaped basic attacks and support item rules | Medium | GDD Prototype Weapon Baseline |
| Enemy behavior, telegraphs, damage, death, and readable feedback | Medium | GDD Prototype Enemy Baseline |
| Seeded procedural level generation with validation | High | GDD Procedural Generation, Epic 3 |
| Forward-only run map and node progression | Medium | GDD Run Structure, Epic 4 |
| Map scouting and revealed-information locking | High | PM Handoff, Procedural Generation Baseline |
| Data-driven classes, loot, passives, and Consume/Destroy choices | High | GDD Item and Passive System, Epics 5-6 |
| Equipment, inventory, affixes, and support-item data model | High | GDD Item System, PM Handoff |
| Risk economy, curses/corruption, gold, healing, and affinities | High | GDD Economy and Resources, Epic 7 |
| Outpost, meta progression, run summary, and seed replay rules | Medium | GDD Permadeath and Progression, Epic 8 |
| Boss/finale flow for Larval Avatar | Medium | GDD Win/Loss Conditions, Epic 9 |
| Save/resume and run-state persistence | High | Technical Specifications, Epic 2 |
| Accessibility and scalable tactical information | Medium | Platform-Specific Details, Epic 10 |
| Content pipeline for passives, items, enemies, affinities, and levels | High | PM Architect Questions, GDD Remaining Details |
| Debugging, seeded replay, generator validation, and test tooling | High | Success Metrics, Procedural Generation |

### Technical Requirements

- Generated level load target: under 3 seconds for MVP.
- UI preview and selection response target: under 100ms.
- Stable 60 FPS where feasible; 30 FPS acceptable on lower-end mobile if input remains responsive.
- Phone-sized combat readability is a first-order requirement, not polish.
- Portrait is likely the main phone play mode; landscape is supported across mobile, tablet, and desktop.
- Orientation and layout changes must not change tactical rules.
- Save/resume between levels is required.
- Mid-level save/resume is desirable if feasible.
- MVP must be offline-first with no accounts, multiplayer, cloud saves, leaderboards, or live-service dependency.
- Manual seed runs are allowed for replay, debug, sharing, and practice, but grant no meta progression.
- All critical tactical information must be available without relying on color alone.
- Architecture should define target device classes, measurement methods, memory budget, and battery/performance expectations before production planning.

### Complexity Drivers

**High Complexity:**

- Deterministic run generation across map, levels, rewards, affinities, enemy placement, and major outcomes.
- RNG stream ownership across generation, combat procs, drops, rewards, and non-critical runtime variance.
- Save/resume interacting with seeded generation, revealed information, fog memory, route state, inventory, passives, and run eligibility.
- Mobile-first tactical preview/commit UX where mis-taps have gameplay consequences.
- Data-driven passives and rule-benders that can affect movement, targeting, damage, healing, visibility, risk, and rewards.
- Generator validation for no soft-locks, reachable rewards, legal enemy placement, safe first reveal, and entrance-to-exit pathing.
- Content authoring pipeline that allows passives, items, enemies, affinities, rewards, and level recipes to evolve without brittle code edits.

**Novel Concepts:**

- Consume/Destroy passive choices as both mechanical build shaping and fiction delivery.
- Affinities as failed containment protocols that affect tactical rules rather than only visuals.
- Darkness affecting visibility and memory pressure while preserving fairness.
- Forward-only Labyrinth route commitment as both roguelite structure and world law.
- Manual seed replay with debug/share/practice value but no meta progression.

### Technical Risks

- Mobile UI may become cramped unless board scale, preview language, tooltips, and modal layout are architected early.
- Seed determinism and save/resume can become fragile if random streams and run-state ownership are not defined up front.
- Procedural levels may feel unfair or bland without validation, tactical wrinkle rules, and debugging tools.
- Passive rule-benders can become hard to balance or implement consistently unless effects are data-driven with explicit trigger timing.
- Combat clarity can collapse if fog, enemy intent, hazards, affinities, and damage feedback do not share a single readable presentation model.
- Scope can expand quickly because classes, enemies, passives, affinities, loot, meta progression, and narrative all invite content growth.
- Technical targets currently lack device tiers, memory/battery budgets, and measurement method; architecture should carry this as an explicit production-readiness gap.
- Epics are adequate for architecture but do not yet contain high-level story slices; story backlog detail belongs in the later epic/story workflow.

---

## Engine & Framework

### Selected Engine

**Godot 4.6.3 stable, standard build, GDScript-first.**

**Verification date:** 2026-06-01.

The production architecture will use the standard Godot editor/runtime rather than the .NET build. Godot's official 4.6.3 archive identifies **Godot 4.6.3-stable** as the current stable release dated 2026-05-20. The stable Godot 4.6 Android and iOS export documentation says C# mobile export exists, but remains experimental with limitations, so GDScript is the lower-risk default for a mobile-first game.

**Rationale:**

- Godot fits Sealsworn's mobile-first, offline, turn-based tactical roguelite scope without imposing Unity-scale project overhead.
- The scene tree and `Control` UI stack are a good match for tactical boards, modal inspection, preview/commit input, HUDs, menus, and scalable phone/tablet/desktop layouts.
- Custom `Resource` files and typed GDScript support data-driven content definitions for weapons, passives, enemies, affinities, item affixes, rewards, and level recipes.
- The MIT license avoids engine royalties, revenue thresholds, and per-seat constraints.
- Phaser remains valuable prototype lineage, but not the production foundation. Unity remains the strongest fallback if mobile SDK, monetization, asset-store, or platform-service pressure becomes dominant.

### Project Initialization

**Starter decision:** clean custom Godot project, not a third-party gameplay starter.

The production project should be initialized from the Godot 4.6.3 standard editor and committed as a minimal custom skeleton. Third-party templates can be inspected later for ideas, but they should not define the initial architecture because Sealsworn's main risk is deterministic tactical state, not generic menus or boilerplate.

```bash
# Create with Godot 4.6.3 stable standard editor.
# Recommended production folder name: godot/ or game-godot/
# Commit project.godot, export presets, source folders, and baseline scenes after creation.
```

Recommended initial structure:

```text
godot/
  addons/
  assets/
    audio/
    fonts/
    sprites/
  data/
    affinities/
    enemies/
    items/
    levels/
    passives/
  scenes/
    game/
    levels/
    ui/
  scripts/
    autoloads/
    core/
    presentation/
    resources/
    systems/
    ui/
  tests/
    integration/
    unit/
```

### Engine-Provided Architecture

| Component | Solution | Notes |
|---|---|---|
| Rendering | Godot 2D/2.5D rendering, starting with the Mobile renderer | Validate phone readability and device tiers early; Compatibility renderer remains the fallback if low-end support demands it. |
| Physics and collision | Godot 2D collision, `Area2D`, collision layers, and ray/shape queries | Useful for targeting and presentation, but tactical legality must come from deterministic game rules, not physics side effects. |
| Audio | Godot audio buses and `AudioStreamPlayer` nodes | Sufficient for MVP music, SFX, ambience, and mix groups unless adaptive music complexity grows. |
| Input | Godot `InputMap`, touch/mouse events, and custom gesture/commit handling | The engine handles device events; Sealsworn owns preview, inspect, confirm, cancel, and mis-tap prevention. |
| UI | Godot `Control` nodes, containers, themes, and `CanvasLayer` | The responsive tactical HUD and inventory/routing screens should be authored as first-class Godot UI, not rendered inside gameplay nodes. |
| Scene management | Scene tree, `PackedScene`, instancing, and selective autoloads | Use scenes for composition and presentation; keep deterministic run state in plain model objects/resources. |
| Data definitions | Custom `Resource` types plus text assets where useful | Strong default for editor-friendly content; final choice between `.tres`, JSON, CSV, or hybrid belongs in Step 4. |
| Build and export | Godot export presets for Android, iOS, Windows, macOS, and Linux | Android requires Java/Android SDK setup; iOS export requires macOS and Xcode. |
| Scripting | Typed GDScript | Default language for MVP. C# can be revisited only if a proven performance or ecosystem need beats mobile export risk. |
| AI editor integration | GoPeak Godot MCP and Context7 | Included as optional-but-recommended AI-assisted development infrastructure. |

### Remaining Architectural Decisions

The following decisions must be made explicitly in Step 4:

- Simulation/presentation boundary: where tactical state lives and how scene nodes mirror it.
- State management model for app flow, run flow, level flow, tactical turn flow, and UI mode flow.
- RNG stream ownership for map generation, level generation, combat procs, drops, rewards, events, and non-critical presentation variance.
- Save/resume schema, file format, versioning, migration policy, and manual seed eligibility rules.
- Data authoring format for classes, weapons, support items, enemies, passives, affinities, affixes, rewards, levels, and outpost progression.
- Procedural generation pipeline, validation passes, debug visualization, and replay tooling.
- Passive/effect system timing, triggers, stacking, conflict resolution, and content validation.
- UI architecture for phone/tablet/desktop layout, portrait/landscape support, inspect panels, inventory, route map, and accessibility.
- Asset pipeline for AI-assisted visual/audio generation, provenance, licensing, source files, export formats, and replacement rules.
- Test architecture for deterministic rules, generators, saves, tactical UI flows, and performance budgets.
- Device tiers, renderer fallback criteria, memory/battery budget, and measurement method.
- Export/build workflow for Android and iOS, including when to introduce CI or signed release builds.

### AI-Assisted Development Tools

The architecture includes AI tooling as a production accelerator, with the same review discipline as code and assets.

| Tool | Role | Notes |
|---|---|---|
| GoPeak Godot MCP | Editor/project bridge for AI-assisted Godot work | Current repo exposes Godot project control, scene/script/resource workflows, logs, LSP/DAP hooks, runtime inspection, screenshots, and input tooling. Requirements: Godot 4.x and Node.js 18+. |
| Context7 | Current documentation lookup | Use for Godot, GDScript, export, plugin, and supporting library docs so agents do not rely on stale API memory. |
| Codex, Claude, Claude Design, Google Stitch, Google Gemini | Premium AI production tools available to Rasmus | Use per workflow for code, implementation review, UI exploration, visual direction, asset ideation, documentation, and test planning. |

Initial GoPeak command reference:

```bash
npx -y gopeak
```

Source references:

- [Godot 4.6.3 stable archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Godot Android export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot iOS export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [GoPeak Godot MCP repository](https://github.com/HaD0Yun/godot-mcp)
- [Context7 MCP registry entry](https://github.com/mcp/upstash/context7)

---

## Architectural Decisions

### Decision Summary

| Category | Decision | Version | Rationale |
|---|---|---|---|
| Simulation ownership | Plain GDScript domain model owns tactical state; Godot scenes mirror it | N/A | Supports determinism, saves, seeded replay, testing, headless simulation, and future tooling. |
| State management | Domain state machines plus command/event records | N/A | Keeps app, run, level, turn, and UI flow explicit and debuggable. |
| RNG | Separate named RNG streams | N/A | Prevents one extra roll from breaking replay determinism. |
| Save system | MVP: versioned local JSON in `user://` | N/A | Readable and testable now; repository and snapshot boundaries preserve future upgrade paths. |
| Static content | Hybrid JSON/CSV source data plus typed Godot `Resource` assets | N/A | Supports AI-assisted bulk authoring, validation, and editor/runtime use. |
| Procedural generation | Deterministic pipeline with validation passes | N/A | Supports fairness, replay, debugging, and future authored templates. |
| Rules/effects | Extensible Sealsworn rules kernel | N/A | Enables future passives, classes, affinities, items, curses, and bosses without building a generic card-game engine. |
| UI | Adaptive UI composition system | N/A | Phone portrait ships first, while future device layouts reuse state contracts and shared components. |
| AI asset pipeline | AI-assisted asset production with review gates | N/A | Uses premium AI tools without losing style, provenance, licensing, or replacement discipline. |
| Runtime asset loading | Hybrid loading | N/A | Preload critical shared assets, load scenes by boundary, add threaded loading as content grows. |
| Testing/debug | Unit, integration, and debug tooling now; headless bot/E2E/ML path later | N/A | Protects deterministic systems and enables future batch playtesting and balance simulation. |
| Performance | Define target device tiers and measure early | N/A | Keeps mobile constraints visible before late-stage optimization. |
| Build/export | Versioned export presets plus local scripted builds; CI after vertical slice | N/A | Gives reproducible early builds without premature CI overhead. |
| Enemy AI | Utility scoring constrained by enemy states/phases | N/A | Enables tunable enemies and bosses while keeping behavior deterministic and explainable. |
| Platform services | Offline-only MVP behind thin service interfaces | N/A | Avoids live-service scope while preserving future cloud saves, telemetry, achievements, and crash reporting. |

### Core Runtime Architecture

Authoritative gameplay state lives in a plain typed GDScript domain model. Godot scene nodes handle presentation, input capture, animation, feedback, and UI composition, but they do not own tactical truth.

Player and enemy actions are submitted as validated commands. Successful commands produce event records that can drive presentation, logs, saves, replay, tests, bot playtesting, and future analytics.

Mandatory boundary rules:

- Scene nodes must not be serialized as save-game truth.
- Tactical rules must be executable without rendering a Godot scene.
- Commands must separate validation, execution, and event output.
- Presentation systems observe model state and event records; they do not mutate tactical truth directly.

### State Management

**Approach:** domain state machines plus command/event records.

The architecture uses explicit state machines for:

- `AppState`: boot, title, loading, gameplay, menus, errors.
- `RunState`: new run, active route, node resolution, completed, failed.
- `LevelState`: generation, active level, victory, defeat, reward, exit.
- `TurnState`: player planning, player resolving, enemy planning, enemy resolving, environment resolving.
- `UiMode`: neutral, movement preview, attack preview, inspect, inventory, route map, reward choice, modal confirmation.

Thin Godot autoloads are allowed only for true global services, such as `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, and possibly a diagnostics service. They must delegate gameplay decisions to the domain model.

### RNG And Determinism

**Approach:** separate named RNG streams derived from a root seed.

Required streams include:

- `map`: forward-only route structure.
- `level`: tactical layout, blockers, hazards, entrances, exits.
- `combat`: gameplay-affecting combat procs and damage variance if used.
- `loot`: item and drop rolls.
- `rewards`: post-combat and node reward offers.
- `events`: run events, curses, affinity incidents, and similar systems.
- `cosmetic`: non-authoritative presentation variance.

Gameplay-affecting random calls must use their assigned stream. Cosmetic-only randomness may be non-authoritative, but it cannot change tactical outcomes, rewards, achievements, or meta progression.

### Data Persistence

**Save system:** versioned local JSON saves in `user://` for MVP.

Save files are written through a `SaveRepository` and versioned domain snapshot DTOs. MVP save data should include:

- Schema version and content version.
- Root seed and named RNG stream states.
- Route state, current node, revealed route information, and manual-seed eligibility.
- Level state, fog memory, discovered tiles, entity snapshots, hazards, and pending turn state.
- Inventory, equipment, passives, curses/corruption, affinities, Oath Shards, gold, and meta progression.
- Player settings and profile/meta data in separate files from current-run autosave.

Future commercial upgrades may add compressed snapshots, tamper checks, platform cloud sync, profile backup/export, or hybrid storage. Gameplay systems must depend on repository contracts, not on raw JSON files, so this can evolve without rewriting core mechanics.

### Static Content

**Approach:** hybrid JSON/CSV source data plus typed Godot `Resource` assets.

Source-of-truth data can start as JSON/CSV for bulk editing, validation, diffability, AI-assisted content generation, and spreadsheet workflows. Runtime/editor-facing definitions should be mirrored or imported into typed Godot Resources such as:

- `EnemyDefinition`
- `ItemDefinition`
- `PassiveDefinition`
- `AffinityDefinition`
- `WeaponDefinition`
- `SupportItemDefinition`
- `LevelRecipe`
- `RewardTable`

All gameplay systems should query definitions through a `ContentRepository` or import layer. If content volume later justifies a database, the repository/import boundary should absorb that change.

### Procedural Generation

**Approach:** deterministic generation pipeline with validation passes.

Generation should run through explicit phases:

1. Route node generation.
2. Level recipe selection.
3. Layout and pathing.
4. Entrance, exit, blocker, and hazard placement.
5. Enemy and reward placement.
6. Affinity and special-rule application.
7. Validation.
8. Final immutable level snapshot.

Validation must check at least:

- Entrance-to-exit reachability.
- No soft-locks.
- Safe first reveal.
- Legal enemy placement.
- Reachable required rewards or objectives.
- Fog/readability constraints.
- Boss/finale-specific constraints when applicable.

Generator validation failures must produce seed, phase, reason, and compact debug output. Future authored templates can feed the same pipeline as constrained inputs.

### Rules And Effects

**Approach:** extensible Sealsworn rules kernel.

The rules system is scoped to Sealsworn's tactical roguelite needs. It is not a generic trading-card-game engine, but it must be deep enough to support future passives, classes, affinities, items, curses, bosses, Consume/Destroy choices, and tactical rule-benders without rebuilding the core.

Required concepts:

- Explicit trigger windows, such as `run_started`, `level_entered`, `turn_started`, `before_move`, `after_move`, `before_attack`, `damage_calculated`, `enemy_killed`, `reward_offered`, and `level_completed`.
- Deterministic resolver queue.
- Data-driven conditions, targets, operations, durations, stacking, and conflict handling.
- Named built-in operations for complex effects.
- Stable resolution order.
- Test coverage for timing and interactions.

Tactical readability comes first, systemic expressiveness second, and generic card-game completeness third.

### Enemy AI And Pathfinding

**Approach:** utility scoring constrained by enemy states/phases.

Enemy AI uses shared deterministic tactical services:

- Grid pathfinding and reachability.
- Line of sight and fog queries.
- Valid move and attack generation.
- Threat maps and attack previews.
- Tile scoring and objective scoring.

Each enemy has named states or phases that constrain which actions can be scored. Examples include `Hidden`, `Triggered`, `Guarding`, `Retreating`, `Enraged`, `PhaseOne`, `PhaseTwo`, and `Finale`.

Utility scoring is then applied only to valid actions for the current state or phase. Debug output must show why an enemy chose an action, including top candidate scores and major bonuses/penalties. Enemy behavior must remain deterministic, explainable, and readable to players.

### UI Architecture

**Approach:** adaptive UI composition system.

MVP ships phone portrait first, but phone portrait is treated as the first layout profile, not the only UI. The UI architecture has separate layers:

- Domain model: tactical, run, inventory, and progression state.
- UI view models: board selection, previews, action availability, tooltips, panels, and modal state.
- Shared Godot `Control` components: buttons, stat rows, item cards, inspectors, combat previews, route nodes, reward choices.
- Layout profiles/scenes: phone portrait, phone landscape, tablet, desktop.
- Command bridge: UI sends validated commands back to the domain model.

Device-specific layout scenes are allowed where needed, but they must reuse the same state contracts, view models, and command layer.

### Asset Pipeline And Runtime Loading

**AI-assisted asset pipeline:** AI-assisted production with review gates.

AI tools may be used for concept art, mood boards, UI mockups, icons, item/passive/enemy/affinity visuals, sprites, SFX, ambience, and music sketches. Production assets require metadata and review.

Track at least:

- Tool, prompt, date, and source references.
- License/provenance notes.
- Editable source file path.
- Exported runtime asset path.
- Approval status, such as `exploration`, `placeholder`, `approved_reference`, `production`, or `deprecated`.

Editable source files must stay separate from exported runtime assets. Runtime paths should be stable so placeholders can be replaced without breaking scenes or content definitions.

**Runtime loading:** hybrid loading.

Preload critical shared assets only. Load screens and levels by scene boundary. Add threaded loading for heavier art/audio once content size justifies it. Do not build a full streaming or content-bundle system for MVP, but keep asset IDs and folder conventions clean enough to add one later.

### Testing, Debugging, And Headless Simulation

**Approach:** unit/integration/debug tooling for MVP, with an explicit headless simulation path.

Required MVP testing:

- Unit tests for domain rules, commands, RNG streams, rules kernel, and save snapshot migration.
- Integration tests for generation, validation, save/load, combat resolution, passive interactions, and reward flow.
- Debug overlays for seed, fog, line of sight, pathing, threats, combat previews, enemy utility scores, and generator validation.

Headless simulation is an explicit architecture target. The domain model should be runnable without a rendered Godot scene so future tools can execute:

- Seed regression runs.
- Bot playtests.
- Batch difficulty simulations.
- Automated E2E flows after the Godot project exists.
- ML-assisted or search-based balance analysis for drop rates, values, percentages, enemy tuning, reward weights, and run pacing.

ML and bot outputs are balance intelligence, not automatic design authority. Human playtests remain required for feel, readability, frustration, and excitement.

### Performance, Platform Services, And Build Workflow

**Performance:** define target device tiers and measure early.

The architecture should define low/mid/high mobile target tiers, desktop parity expectations, FPS/input/load budgets, memory and battery expectations, and profiling checkpoints at vertical-slice milestones.

**Platform services:** offline-only MVP behind thin service interfaces.

The MVP has no accounts, multiplayer, cloud saves, leaderboards, or live-service dependency. Define local/no-op implementations behind thin interfaces such as:

- `PlatformServices`
- `SaveSyncProvider`
- `TelemetrySink`
- `AchievementProvider`
- `CrashReporter`

This preserves future cloud sync, platform achievements, crash reports, and balance telemetry without pulling those systems into MVP scope.

**Build/export:** versioned export presets plus local scripted builds, CI after vertical slice.

Godot export presets should be committed. Local scripted exports should be introduced early for Android and Windows. CI builds should wait until the vertical slice clarifies project structure, tests, platform requirements, and signing needs.

### Architecture Decision Records

**ADR-001: Domain model owns tactical truth.**  
Accepted because Sealsworn's determinism, saves, replay, AI, bot testing, and UI flexibility all depend on scene-independent game state.

**ADR-002: MVP remains future-facing, not throwaway.**  
Accepted because the MVP should prove the core game while preserving deeper future systems through repository boundaries, rule-kernel extensibility, adaptive UI composition, and service interfaces.

**ADR-003: Automation helps balance, but does not replace design judgment.**  
Accepted because headless simulation, bot playtests, and ML-assisted analysis can expose difficulty curves and exploits, while human playtesting remains necessary for game feel.

---

## Cross-cutting Concerns

These patterns apply to all systems and must be followed by every implementation.

### Error Handling

**Strategy:** hybrid error handling.

Domain gameplay logic returns structured results. System-level failures go through diagnostics/global handling. Logs and events make failures visible without corrupting deterministic state.

**Error Levels:**

| Level | Meaning | Required Behavior |
|---|---|---|
| Invariant | A condition that must never be false | Fail fast in dev/test; production blocks action or returns to safe menu with diagnostic |
| Recoverable | Unexpected but handled condition | Log warning, continue through declared fallback |
| Command Error | Illegal player/enemy/system command | Return `ActionResult.error`, no mutation |
| Generation Failure | Invalid generated content/level | Retry within bounded attempts, then fail with seed/phase/reason |
| Save Failure | Bad save/migration/load issue | Preserve original file, report clearly, enter recovery flow |

**Example:**

```gdscript
var result: ActionResult = combat_service.try_attack(state, command)

if result.is_error():
    Diagnostics.warn("command", result.error_code, {
        "seed": state.root_seed,
        "actor_id": command.actor_id,
        "target": command.target_cell
    })
    return result

event_log.append_all(result.events)
presentation_queue.enqueue_all(result.events)
return result
```

### Logging

**Strategy:** dual-mode logging.

Readable structured logs are used during normal development. Headless simulation, bot runs, and future balance analysis can export JSONL records.

**Required Categories:** `rules`, `command`, `rng`, `save`, `generation`, `ai`, `ui`, `assets`, `performance`, `platform`, `telemetry`.

**Example:**

```gdscript
Diagnostics.info("generation", "level_validated", {
    "seed": run.seed,
    "level_id": level.id,
    "attempt": attempt,
    "enemy_count": level.enemies.size()
})
```

### Configuration

**Approach:** layered configuration management.

| Layer | Source | Rule |
|---|---|---|
| Code constants | GDScript constants | True invariants only |
| Content/balance | JSON/CSV + Godot Resources | Validated through content pipeline |
| Player settings | `user://settings.json` | Safe user preferences only |
| Platform overrides | Device/platform config | Mobile/desktop/device-tier tuning |
| Debug flags | Build-profile gated config | Inert or unavailable in production unless explicitly allowed |

### Event System

**Pattern:** typed domain events plus Godot signals for presentation.

Domain systems emit deterministic event records such as `DamageApplied`, `EnemyKilled`, `TileRevealed`, and `PassiveTriggered`. Godot presentation maps those records to animation, audio, UI, and feedback signals.

**Example:**

```gdscript
for event in action_result.events:
    event_log.append(event)
    match event.type:
        DomainEvent.Type.DAMAGE_APPLIED:
            damage_applied.emit(event.actor_id, event.amount)
        DomainEvent.Type.PASSIVE_TRIGGERED:
            passive_triggered.emit(event.passive_id, event.actor_id)
```

### Debug Tools

**Strategy:** phased full debug toolkit.

**MVP Debug Tools:**

- Seed display and seed loader.
- Fog, line-of-sight, pathing, threat, and combat-preview overlays.
- Generator validation report viewer.
- Enemy utility-score inspector.
- Dev commands for jump node, spawn enemy, grant item/passive, reveal map, force reward.
- Structured command/event log viewer.

**Future Debug Tools:**

- Headless seed runner.
- Bot playtest runner.
- Batch difficulty simulation reports.
- Automated E2E flows.
- ML/search-assisted balance tooling.

Debug features are gated by build profile and must mark progression as debug/manual-seed when used.

### Static Content Validation

**Strategy:** schema + semantic validation + simulation smoke tests + mandatory human approval.

Pipeline:

1. Draft content, whether human-authored or AI-assisted.
2. Schema validation.
3. Semantic validation.
4. Simulation/rules smoke tests where applicable.
5. Human design review for fun, theme, readability, balance intent, and quality.
6. Approval status changes to production-ready.

Automated validation answers whether content is structurally safe and technically legal. Human review decides whether it belongs in Sealsworn.

### Privacy, Telemetry, And Balance Data

**Strategy:** local-only analytics now, interface for opt-in telemetry later.

MVP records local-only run summaries, seed outcomes, death causes, item picks, passive triggers, win/loss, run length, and bot/debug metrics. A `TelemetrySink` interface can later support opt-in production telemetry without changing gameplay systems.

### Release And Build Safety Gates

**Strategy:** build-profile flags + automated pre-export validation + manual release checklist.

Required gates:

- Debug/cheat tools disabled or inert in production.
- Test content excluded unless explicitly marked for release.
- Experimental assets cannot ship without production approval.
- Content validation passes.
- Export profile matches intended platform/build type.
- Save schema/content versions are current.
- Manual release checklist completed.

---

## Project Structure

### Organization Pattern

**Pattern:** hybrid structure with domain-driven subfolders.

The repository keeps Godot-friendly top-level folders such as `scripts/`, `scenes/`, `assets/`, `data/`, and `tests/`, then organizes each area by Sealsworn domains. This preserves normal Godot workflows while giving AI agents and future contributors clear boundaries for tactical simulation, generation, rules, AI, UI, saves, content, diagnostics, platform services, and tooling.

The existing React prototype remains as prototype evidence and should not become a production dependency.

### Repository Structure

```text
C:/Sealsworn/
  godot/
    project.godot
    export_presets.cfg
    addons/
    assets/
    data/
    scenes/
    scripts/
    tests/
    tools/
  asset_sources/
    visual/
    audio/
    metadata/
    reviews/
  prototype/
  docs/
    architecture/
    decisions/
    asset_pipeline/
    playtesting/
  _bmad/
  _bmad-output/
```

### Godot Project Structure

```text
godot/
  addons/
    gut/
    mcp/
  assets/
    art/
      characters/
        hero/
        enemies/
      hazards/
      items/
      passives/
      affinities/
      tiles/
      effects/
      ui/
        icons/
        panels/
        buttons/
    audio/
      music/
      sfx/
        combat/
        ui/
        rewards/
      ambience/
    fonts/
    shaders/
  data/
    source/
      affinities/
      classes/
      enemies/
      items/
      level_recipes/
      passives/
      reward_tables/
      weapons/
      support_items/
    resources/
      affinities/
      classes/
      enemies/
      items/
      level_recipes/
      passives/
      reward_tables/
      weapons/
      support_items/
    schemas/
    localization/
  scenes/
    app/
      boot.tscn
      main.tscn
    game/
      gameplay_shell.tscn
      tactical_board.tscn
    entities/
      hero/
      enemies/
      hazards/
      pickups/
    ui/
      layouts/
        phone_portrait/
        phone_landscape/
        tablet/
        desktop/
      components/
      panels/
      modals/
    effects/
      combat/
      fog/
      rewards/
    debug/
  scripts/
    autoloads/
    core/
      commands/
      events/
      results/
      state/
    tactical/
      board/
      combat/
      fog/
      targeting/
      turns/
    rules/
      conditions/
      operations/
      triggers/
      resolver/
    generation/
      route/
      level/
      validation/
    ai/
      pathfinding/
      utility/
      states/
    content/
      repositories/
      importers/
      validation/
    save/
      snapshots/
      migrations/
    ui/
      view_models/
      presenters/
    platform/
    diagnostics/
    utils/
  tests/
    unit/
      core/
      tactical/
      rules/
      generation/
      ai/
      save/
      content/
    integration/
      generation_save_load/
      combat_rules/
      reward_flow/
      ui_commands/
    headless/
      seed_runs/
      bot_runs/
    fixtures/
      seeds/
      saves/
      content/
  tools/
    content/
      import/
      validate/
    simulation/
      seed_runner/
      bot_runner/
      reports/
    export/
    diagnostics/
```

### Asset Source Structure

Editable source files, prompts, provenance notes, and review records live outside the Godot runtime asset tree so they can be managed without accidentally importing every working file into the game.

```text
asset_sources/
  visual/
    concepts/
    moodboards/
    icons/
    sprites/
    ui_mockups/
    effects/
  audio/
    music_sketches/
    sfx_sketches/
    ambience_sketches/
  metadata/
    asset_manifest.csv
    prompts/
    tool_runs/
    provenance/
  reviews/
    approved_reference/
    rejected/
    production_ready/
```

Runtime-ready exports go into `godot/assets/`. Source files and AI-generation records remain in `asset_sources/`.

### System Location Mapping

| System | Location | Responsibility |
|---|---|---|
| App boot and global flow | `scripts/core/state/`, `scenes/app/` | Boot, title/loading flow, app-level state transitions. |
| Autoload services | `scripts/autoloads/` | Thin global services only: session, scene manager, save manager, audio manager, diagnostics. |
| Commands and results | `scripts/core/commands/`, `scripts/core/results/` | Validated player/enemy/system commands and structured success/error results. |
| Domain events | `scripts/core/events/` | Deterministic event records for presentation, replay, saves, logs, tests, and analytics. |
| Tactical board | `scripts/tactical/board/`, `scenes/game/tactical_board.tscn` | Grid, cells, occupancy, board queries, and presentation bridge. |
| Combat and targeting | `scripts/tactical/combat/`, `scripts/tactical/targeting/` | Attack previews, legality checks, damage application, target shapes. |
| Fog and visibility | `scripts/tactical/fog/`, `scenes/effects/fog/` | Line of sight, explored memory, visibility events, fog presentation. |
| Turn flow | `scripts/tactical/turns/` | Player/enemy/environment turn states and command sequencing. |
| Rules kernel | `scripts/rules/` | Trigger windows, conditions, operations, resolver queue, stacking and conflicts. |
| Procedural route generation | `scripts/generation/route/` | Forward-only route map and node structure. |
| Procedural level generation | `scripts/generation/level/`, `scripts/generation/validation/` | Layout, blockers, hazards, enemies, rewards, validation reports. |
| Enemy AI | `scripts/ai/` | Pathfinding, tactical queries, utility scoring, state/phase logic, decision explanations. |
| Static content repositories | `scripts/content/repositories/`, `data/source/`, `data/resources/` | Definition lookup for enemies, items, passives, affinities, rewards, levels. |
| Content import and validation | `scripts/content/importers/`, `scripts/content/validation/`, `tools/content/` | Schema validation, semantic validation, resource generation, smoke tests. |
| Save/load | `scripts/save/` | Snapshot DTOs, migrations, local JSON repository, recovery flows. |
| UI view models | `scripts/ui/view_models/` | Selection state, preview data, panel state, action availability. |
| UI presenters | `scripts/ui/presenters/`, `scenes/ui/` | Godot `Control` bindings, adaptive layout profiles, command bridge. |
| Runtime assets | `godot/assets/` | Production-ready art, audio, fonts, shaders, UI assets. |
| Asset source/provenance | `asset_sources/` | Editable files, prompts, metadata, review status, provenance. |
| Diagnostics and logging | `scripts/diagnostics/`, `tools/diagnostics/` | Structured logs, JSONL export, error reporting, debug viewers. |
| Platform interfaces | `scripts/platform/` | Local/no-op services for telemetry, achievements, cloud sync, crash reporting. |
| Tests | `tests/unit/`, `tests/integration/`, `tests/headless/` | Domain tests, integration tests, seed runs, bot runs, fixtures. |
| Build/export tools | `tools/export/` | Local scripted exports, pre-export validation, release gates. |
| Documentation | `docs/`, `_bmad-output/` | Architecture, decisions, asset pipeline notes, playtest reports, generated planning artifacts. |

### Naming Conventions

#### Files And Folders

- Folders use `snake_case`: `level_recipes/`, `reward_tables/`, `phone_portrait/`.
- GDScript files use `snake_case.gd`: `attack_command.gd`, `damage_applied_event.gd`.
- Scene files use `snake_case.tscn`: `gameplay_shell.tscn`, `tactical_board.tscn`.
- Resource files use `snake_case.tres`: `shadow_ambusher_enemy.tres`, `oath_shard_item.tres`.
- Test files use `test_*.gd`: `test_attack_command.gd`, `test_level_validation.gd`.
- Data files use plural domain names when they contain many records: `passives.json`, `enemy_rewards.csv`.
- Stable content IDs use lower snake case: `shadow_ambusher`, `iron_sword`, `darkness_affinity`.

#### Code Elements

| Element | Convention | Example |
|---|---|---|
| Classes | `PascalCase` | `AttackCommand`, `LevelGenerator`, `EnemyDefinition` |
| Functions | `snake_case` | `try_attack`, `validate_level`, `score_actions` |
| Variables | `snake_case` | `root_seed`, `current_turn`, `actor_id` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_GENERATION_ATTEMPTS` |
| Enums | `PascalCase` type, `UPPER_SNAKE_CASE` values | `TurnPhase.PLAYER_PLANNING` |
| Signals | `snake_case` past-tense/event names | `damage_applied`, `passive_triggered` |
| Private members | Leading underscore | `_resolve_trigger_queue` |
| Domain events | Past-tense class/type names | `DamageAppliedEvent`, `TileRevealedEvent` |
| Commands | Imperative noun names | `MoveCommand`, `AttackCommand`, `ConsumePassiveCommand` |
| Result types | `*Result` suffix | `ActionResult`, `GenerationResult` |
| Definitions | `*Definition` suffix | `EnemyDefinition`, `PassiveDefinition` |
| Snapshots | `*Snapshot` suffix | `RunSnapshot`, `LevelSnapshot` |

#### Game Assets

- Runtime assets use descriptive lower snake case with category prefixes where helpful.
- Recommended pattern: `{category}_{subject}_{variant}_{state}_{index}`.
- Examples:
  - `enemy_shadow_ambusher_idle_01.png`
  - `icon_passive_blood_oath_01.png`
  - `sfx_combat_hit_blunt_01.wav`
  - `music_labyrinth_loop_01.ogg`
  - `tile_darkness_floor_cracked_01.png`
- Placeholder assets include `_placeholder`: `enemy_brute_placeholder_01.png`.
- Approved production assets must have matching provenance/review metadata in `asset_sources/metadata/`.

### Architectural Boundaries

- `scripts/tactical/`, `scripts/rules/`, `scripts/generation/`, `scripts/ai/`, and `scripts/save/` must not depend on Godot scene nodes for authoritative logic.
- `scenes/` and `scripts/ui/` can observe domain state and submit commands, but cannot mutate tactical state directly.
- `scripts/autoloads/` must remain thin service wiring, not gameplay decision containers.
- `data/source/` is the authoring source; `data/resources/` is the typed Godot resource mirror/runtime editor layer.
- `godot/assets/` contains runtime-ready files only. Editable source files, prompts, and provenance records stay in `asset_sources/`.
- `prototype/` is reference material only. Production Godot code must not import or depend on prototype source.
- Tests mirror the domain they cover. New systems require unit or integration test locations before implementation begins.
- Debug and tooling code must be build-profile gated and must not grant production progression unless explicitly allowed by the release policy.
- Platform service interfaces must have local/no-op MVP implementations before any cloud or external service integration is introduced.

---

## Implementation Patterns

These patterns ensure consistent implementation across all AI agents.

### Novel Patterns

#### Command/Event Simulation Pattern

**Purpose:** keep gameplay deterministic, testable, saveable, replayable, and usable by headless simulation.

**Components:**

- `Command`: describes an intended player, enemy, debug, bot, or system action.
- `ActionResult`: returns success or error without ambiguous side effects.
- `DomainEvent`: records what actually happened in deterministic past-tense form.
- `DomainState`: owns tactical truth and applies events.
- `PresentationMapper`: turns domain events into animations, UI, audio, and feedback.

**Data Flow:**

```text
Input / AI / Bot / Debug
  -> Command
  -> validate
  -> execute against domain state
  -> DomainEvents
  -> apply events to state
  -> presentation/log/save/replay consumers
```

**Implementation Guide:**

```gdscript
class_name AttackCommand
extends RefCounted

var actor_id: String
var target_cell: Vector2i

func execute(state: LevelState, rules: RulesResolver) -> ActionResult:
    if not state.can_actor_attack(actor_id, target_cell):
        return ActionResult.error("target_out_of_range")

    var events: Array[DomainEvent] = rules.resolve_attack(state, actor_id, target_cell)
    state.apply_events(events)
    return ActionResult.ok(events)
```

**Use When:**

- Movement, attack, reward selection, inventory change, passive Consume/Destroy, enemy action, debug action, bot action.

**Do Not Use When:**

- Pure presentation state such as button hover, animation timing, particle variation, panel open/close animation, or audio fade.

#### Rules Kernel Pattern

**Purpose:** support passives, items, affinities, curses, classes, bosses, and Consume/Destroy choices without hardcoding every interaction.

**Components:**

- `RuleTrigger`: explicit timing window.
- `RuleCondition`: test that decides whether a rule applies.
- `RuleTarget`: target selection.
- `RuleOperation`: deterministic effect operation.
- `RulesResolver`: stable queue and ordering.
- `RuleContext`: snapshot of relevant state for the current trigger.

**Data Flow:**

```text
Domain event or command phase
  -> RuleTrigger
  -> collect matching rules
  -> evaluate conditions
  -> resolve operations in stable order
  -> emit DomainEvents
```

**Implementation Guide:**

```gdscript
var context := RuleContext.from_attack(state, actor_id, target_cell)

var events: Array[DomainEvent] = rules_resolver.resolve(
    RuleTrigger.BEFORE_ATTACK,
    context
)
```

**Use When:**

- Passive effects, affinity effects, combat modifiers, reward modifiers, curse effects, class rules, boss mechanics.

**Do Not Use When:**

- Simple fixed UI presentation, one-off debug display, or static content lookup that has no gameplay timing or trigger behavior.

**Readability Rule:** every rule-driven gameplay outcome must be expressible in player/debug language, such as "Blood Oath triggered after kill and added 2 damage next turn."

#### Generation Pipeline Pattern

**Purpose:** make procedural generation deterministic, inspectable, and fair.

**Components:**

- `GenerationRequest`: seed, route node, level recipe, difficulty, constraints.
- `GenerationPhase`: route, layout, pathing, blockers, hazards, enemies, rewards, affinity rules.
- `ValidationReport`: pass/fail checks with seed, phase, reason, and compact diagnostics.
- `GenerationResult`: final immutable snapshot or error.

**Data Flow:**

```text
GenerationRequest
  -> phased generator
  -> validation report
  -> retry if bounded retry allowed
  -> LevelSnapshot or GenerationResult.error
```

**Implementation Guide:**

```gdscript
var result: GenerationResult = level_generator.generate(request)

if result.is_error():
    Diagnostics.error("generation", result.error_code, {
        "seed": request.seed,
        "phase": result.failed_phase,
        "reason": result.reason
    })
    return result
```

**Use When:**

- Route maps, tactical level layouts, blockers, hazards, enemy placement, rewards, boss/finale levels.

**Do Not Use When:**

- Hand-authored static content definitions, UI layout composition, or runtime presentation effects that do not affect level legality.

#### State/Phase Utility AI Pattern

**Purpose:** make enemies tunable and explainable while preserving readable tactics.

**Components:**

- `EnemyState` / `EnemyPhase`: constrains possible behavior.
- `TacticalQueryService`: pathing, line of sight, threat, valid action, and target queries.
- `AiAction`: candidate action.
- `UtilityScorer`: scores valid candidates.
- `AiDecision`: chosen action plus score and explanation.

**Data Flow:**

```text
Enemy state/phase
  -> valid action set
  -> tactical queries
  -> utility scores
  -> chosen command
  -> command/event simulation
```

**Implementation Guide:**

```gdscript
var options: Array[AiAction] = ai_state.get_valid_actions(enemy, state)
var decision: AiDecision = utility_scorer.choose_best(options, state)

Diagnostics.debug("ai", "decision", {
    "enemy_id": enemy.id,
    "state": ai_state.name,
    "chosen": decision.action_id,
    "score": decision.score,
    "reasons": decision.reasons
})
```

**Use When:**

- Enemy actions, boss phases, ambushers, guards, affinity enemies, bot policies.

**Do Not Use When:**

- Deterministic forced actions with no meaningful choice, such as a scripted tutorial step or a required post-death cleanup.

**Readability Rule:** AI choices must be explainable. If the system cannot say why an enemy waited, retreated, attacked, or blocked a route, the implementation is incomplete.

#### Adaptive UI Composition Pattern

**Purpose:** ship phone portrait first without rebuilding UI for tablet/desktop later.

**Components:**

- `ViewModel`: read-only UI-facing state.
- `Presenter`: binds a Godot scene/control to a view model.
- `LayoutProfile`: phone portrait, phone landscape, tablet, desktop.
- `CommandBridge`: converts player UI intent into domain commands.

**Data Flow:**

```text
Domain state/events
  -> view model
  -> presenter/layout profile
  -> user intent
  -> command bridge
  -> command/event simulation
```

**Implementation Guide:**

```gdscript
func bind(model: BoardViewModel) -> void:
    move_preview.visible = model.has_move_preview
    attack_button.disabled = not model.can_attack

func _on_attack_pressed() -> void:
    command_submitted.emit(model.create_attack_command())
```

**Use When:**

- Tactical HUD, inventory, combat previews, route map, reward panels, modal confirmations, adaptive device layouts.

**Do Not Use When:**

- Non-gameplay decorative animation or purely local visual transitions that do not need domain state.

#### Headless Simulation Pattern

**Purpose:** enable unit tests, seed regression, bot playtests, batch difficulty analysis, and future ML/search-assisted tuning.

**Components:**

- `RunSimulation`: domain-only simulation coordinator.
- `BotPolicy`: player decision policy for automated play.
- `SimulationReport`: run outcome, turn counts, deaths, rewards, item picks, passive triggers, timing.
- `ContentRepository`: static definitions.
- `RulesResolver`: rules and effects.

**Data Flow:**

```text
Seed + content + bot policy
  -> RunSimulation
  -> command/event loop
  -> SimulationReport
  -> logs/reports/balance analysis
```

**Implementation Guide:**

```gdscript
var simulation := RunSimulation.new(content_repository, rules_resolver)
var report: SimulationReport = simulation.run_seed(seed, BotPolicy.greedy())

assert_that(report.turns_completed).is_greater(0)
```

**Use When:**

- Unit tests, seed regression, bot playtests, balance analysis, replay verification, later CI and ML/search-assisted tuning.

**Do Not Use When:**

- Measuring animation quality, UI readability, player feel, sound timing, or visual polish. Those require rendered playtests.

**Dependency Rule:** headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.

### Standard Implementation Patterns

#### Communication Pattern

**Pattern:** explicit dependencies inside domain systems; typed domain events outward; Godot signals for presentation.

```gdscript
var result := attack_command.execute(level_state, rules_resolver)

for event in result.events:
    presentation_mapper.dispatch(event)
```

Use direct calls for known dependencies, domain events for gameplay outcomes, and signals for scene/UI feedback. Avoid broad global event buses for domain control flow.

#### Entity Creation Pattern

**Pattern:** factories create domain entities from content definitions; scenes instantiate presentation views separately.

```gdscript
var definition: EnemyDefinition = content.get_enemy("shadow_ambusher")
var enemy: EnemyState = enemy_factory.create(definition, spawn_cell, rng_stream)
var view: Node2D = enemy_scene.instantiate()
view.bind(enemy.id)
```

Domain entity creation and scene instantiation must stay separate.

#### State Transition Pattern

**Pattern:** explicit state machines with validated transitions.

```gdscript
if turn_state.can_transition_to(TurnPhase.ENEMY_PLANNING):
    turn_state.transition_to(TurnPhase.ENEMY_PLANNING)
else:
    return ActionResult.error("invalid_turn_transition")
```

Use this for app, run, level, turn, UI mode, and enemy state/phase. Avoid untracked boolean flag piles for major flow.

#### Data Access Pattern

**Pattern:** repositories, not direct file access from gameplay systems.

```gdscript
var passive: PassiveDefinition = content_repository.get_passive(passive_id)
var save_result: SaveResult = save_repository.write_run_snapshot(snapshot)
```

Gameplay systems ask repositories for definitions and persistence. Only importer/repository layers touch files.

#### Presentation Binding Pattern

**Pattern:** scene nodes bind to IDs/view models, not raw mutable domain internals.

```gdscript
func bind_unit(unit_id: String, board_vm: BoardViewModel) -> void:
    self.unit_id = unit_id
    refresh(board_vm.get_unit_view(unit_id))
```

Scene nodes may cache local visual state, but cannot own tactical truth.

### Consistency Rules

| Pattern | Convention | Enforcement |
|---|---|---|
| Commands | Validate before mutation; return `ActionResult` | Unit test for every command |
| Events | Past-tense deterministic domain events | Event schema tests and replay checks |
| Rules | Trigger/condition/operation model | Rules resolver tests and player-readable explanation checks |
| Generation | Phase outputs plus validation report | Seed regression tests and generator fixtures |
| AI | State/phase constraints plus score explanations | AI decision tests and debug logs |
| UI | View models plus command bridge | UI command integration tests |
| Data | Repository access only | Code review and no-direct-file-access checks |
| Saves | Snapshot DTOs only | Migration tests for every schema change |
| Headless simulation | No rendering/audio/UI dependencies | Headless test suite |
| Debug | Build-profile gated | Pre-export validation |

---

## Architecture Validation

### Validation Summary

| Check | Result | Notes |
|---|---|---|
| Decision Compatibility | PASS | Godot, domain model, commands/events, rules, UI, saves, testing, and tooling align. |
| GDD Coverage | PASS | Core systems and epics have architectural support. |
| Pattern Completeness | PASS | Six novel patterns and five standard patterns are documented with concrete examples. |
| Epic Mapping | PASS | Every epic maps to structure, patterns, and implementation locations. |
| Document Completeness | PASS | Required sections are present; no unresolved TODO, TBD, or template placeholders found. |

### Coverage Report

**Systems Covered:** 17/17 core systems identified in Project Context.  
**Epics Covered:** 10/10 GDD epics.  
**Patterns Defined:** 11 total: six novel Sealsworn patterns and five standard implementation patterns.  
**Decisions Made:** 15 architectural decisions in the decision summary table.

### Epic Mapping

| Epic | Architecture Support | Status |
|---|---|---|
| Epic 1 - Core Tactical Combat Slice | `scripts/tactical/`, commands/events, rules kernel, combat/targeting patterns | PASS |
| Epic 2 - Mobile UX, Accessibility, and Save/Resume Foundation | adaptive UI composition, `scripts/save/`, view models, accessibility-aware UI structure | PASS |
| Epic 3 - Procedural Level Generation v0 | generation pipeline, validation reports, RNG streams, seed regression tests | PASS |
| Epic 4 - Run Map and Forward Progression | route generation, run state, route UI panels, save snapshots | PASS |
| Epic 5 - Classes and Starting Kits | class definitions, content repository, rules hooks, starting kit content | PASS |
| Epic 6 - Loot, Passives, and Consume/Destroy | item/passive data, reward tables, rules kernel, content validation | PASS |
| Epic 7 - Risk Economy and Affinities | affinity data, risk/currency hooks, rules effects, generation modifiers | PASS |
| Epic 8 - Outpost, Meta Progression, and Run Summary | progression snapshots, outpost/menu UI, run summary telemetry, save schema | PASS |
| Epic 9 - Larval Avatar MVP Finale | boss content, AI phases, rules/generation support, finale constraints | PASS |
| Epic 10 - Playtest Tuning and MVP Readiness | tests, diagnostics, headless simulation, performance tiers, release gates | PASS |

### Issues Resolved

- Added a short Executive Summary section to satisfy the architecture checklist's document-structure requirement.
- Confirmed checklist items for authentication, APIs, remote services, database, and cloud infrastructure are intentionally not applicable to the offline-only MVP. Future-facing service interfaces are documented without pulling these systems into MVP scope.

### Validation Date

2026-06-02

---

## Development Environment

### Prerequisites

- Godot 4.6.3 stable standard editor and export templates.
- Git for source control.
- Node.js 18+ for GoPeak Godot MCP and Context7 MCP.
- Android Studio, Android SDK, and JDK for Android exports.
- macOS with Xcode for iOS exports when iOS packaging begins.
- GUT or equivalent Godot test addon for unit/integration testing after the Godot project is initialized.
- Optional: spreadsheet/document tooling for JSON/CSV content authoring and validation workflows.

### AI Tooling

The following AI tooling was selected or recorded during architecture:

| Tool | Purpose | Install Type |
|---|---|---|
| GoPeak Godot MCP | Direct AI-assisted Godot project/editor workflow, diagnostics, scene/script/resource tooling | Node.js MCP server via `npx` |
| Context7 | Current Godot/GDScript/library documentation lookup | Node.js MCP server via `npx` |
| Codex, Claude, Claude Design, Google Stitch, Google Gemini | Premium AI-assisted code, design, asset, documentation, and test-planning tools available to Rasmus | External tools/workflows |

Suggested MCP setup references:

```powershell
npx -y gopeak
npx -y @upstash/context7-mcp
```

Exact MCP client configuration should be created when the Godot project exists and the local Godot executable path is known.

### Setup Commands

```powershell
New-Item -ItemType Directory -Force -Path .\godot, .\asset_sources, .\docs\architecture, .\docs\decisions, .\docs\asset_pipeline, .\docs\playtesting

# Create the Godot project with Godot 4.6.3 stable standard editor:
# 1. Open Godot.
# 2. Create/import project at C:\Sealsworn\godot.
# 3. Commit project.godot, export_presets.cfg when created, and the architecture-defined folders.
```

### First Steps

1. Initialize the Godot project at `C:/Sealsworn/godot/`.
2. Create the architecture-defined folder structure.
3. Configure GoPeak and Context7 MCP once the Godot executable path is known.
4. Add the test framework and create initial domain/unit test scaffolding.
5. Start implementation from the command/event simulation core, RNG streams, and tactical board model before presentation-heavy scenes.

---

## Completion Handoff

The Game Architecture workflow is complete.

### Architecture Summary

- **Engine:** Godot 4.6.3 stable standard, GDScript-first.
- **Platform:** iOS/Android mobile and tablet first; Windows desktop/laptop parity.
- **Organization:** hybrid Godot structure with domain-driven subfolders.
- **Decisions Made:** 15 architectural decisions.
- **Patterns Defined:** 11 implementation patterns.
- **Validation Status:** PASS.

### Sections Completed

1. Project Context
2. Engine & Framework
3. Architectural Decisions
4. Cross-cutting Concerns
5. Project Structure
6. Implementation Patterns
7. Validation
8. Development Environment
9. Completion Handoff

### Recommended Next Steps

1. Update or regenerate `project-context.md` so implementation agents inherit the new Godot architecture decisions.
2. Initialize the Godot project and folder structure.
3. Run the epic/story workflow against the GDD and completed architecture.
4. Begin implementation with domain model, commands/events, RNG streams, and tactical board tests before UI-heavy scene work.

### Workflow Status

No `_bmad-output/gds-workflow-status.yaml` file was present, so no external workflow-status file was updated. This document is the authoritative completion record for the Game Architecture workflow.
