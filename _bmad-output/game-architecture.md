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

> **Epic 16 extends this pipeline.** A BSP room/corridor **structure phase** is inserted ahead of blocker
> placement, structural filler makes reachability a *proven* rather than *constructed* property, and three
> size classes replace two. The phase order, the new fixed draws, the connectivity/fightability validator,
> and the re-pin plan are specified in **Dungeon Generation Architecture (Epic 16)** below. Read that
> section before touching `scripts/generation/level/`.

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

**ADR-004: Structural filler reuses `Terrain.WALL`; there is no unreachable terrain kind.**

Accepted because WALL already blocks movement and line of sight, already serializes, and is already honored by every board consumer — so the unreachable-cell invariant is inherited rather than re-implemented across twenty files. See *Dungeon Generation Architecture* §2.

**ADR-005: Exit-based victory requires a new append-only event, not a relaxed `level_victory_reached`.**

Accepted because `remaining_enemy_count == 0` is asserted at three independent enforcement layers, two of which are event-contract validators rather than gameplay branches. Relaxing them would weaken a validated domain contract for every existing consumer. See *Dungeon Generation Architecture* §9.

---

## Dungeon Generation Architecture (Epic 16)

> **Authored:** 2026-08-05 (Game Architect pass) · **Build:** `6b7c4fd` · **Baseline suite:** 205 PASS / 0 FAIL.
> Companions: `planning-artifacts/design-notes/epic-16-generation-architecture.md` (decisions AD-1..AD-7,
> OQ-1..OQ-6), `epic-16-design-brief.md` (ratified Q1–Q6), and the `gdd.md` designer pass of 2026-08-05
> (Enemy Awareness, Level Structure, Size Classes, Run Structure pacing).
>
> This section is the technical design that those ratified decisions call for. It is grounded in the
> shipped generator, not assumed: every claim about current behavior below was read out of
> `godot/scripts/` at the build above.

### 1. The BSP structure phase and the fixed draw order

The room/corridor algorithm enters as a **new structure phase ahead of the existing placer chain**, not as
a rewrite of it. The phase emits its **reachable-floor cell list** as the candidate pool, and phases 2–5
consume that pool through the same shrinking-pool discipline they use today, unchanged.

```
0. structure   (NEW)  BSP split -> room rects -> corridor carve -> dead-end stubs
                      emits: terrain grid + reachable_cells[] (the candidate pool)
1. blockers    (existing, now drawing from reachable_cells minus corridor spine)
2. wrinkles    (existing, TacticalWrinklePlacer — unchanged)
3. enemies     (existing, EntityRewardPlacer — unchanged)
4. rewards     (existing, EntityRewardPlacer — unchanged)
```

Both `SmallLevelLayoutGenerator` and `MediumLevelLayoutGenerator` (and the new Large generator) share the
structure phase as a sibling service — the same pattern `TacticalWrinklePlacer` and `EntityRewardPlacer`
already established. One implementation, three callers.

**The new draws, prepended to the FIXED DRAW ORDER docblock of every generator.** The existing draws keep
their relative order and their semantics; they simply move down. Every draw routes through
`GenerationRequest.draw_layout_int` / `draw_layout_float` → `RngStreamSet.STREAM_LEVEL`. No new stream.

| # | Draw | Count | Notes |
|---|---|---|---|
| **S1** | `split_depth` | 1 | Over the recipe's BSP depth band. **Always drawn**, even when the band collapses to one value, so the stream advances identically across recipes (the shipped always-fire count-draw discipline). |
| **S2** | `split_axis` | 1 per internal node | Fixed **pre-order** traversal of the BSP tree. |
| **S3** | `split_position` | 1 per internal node | Interleaved with S2 per node (axis, then position), not batched. |
| **S4** | `room_inset` | 4 per leaf | Left/top/right/bottom inset, in **leaf pre-order**. Always drawn even when an inset band collapses. |
| **S5** | `corridor_bend` | 1 per corridor | Horizontal-first vs vertical-first for the L-carve. Corridors are cut between sibling rooms while **unwinding** the recursion (fixed post-order), so the corridor set is a pure function of the tree. |
| **S6** | `dead_end_count` | 1 | Over the recipe's dead-end budget band. Always drawn. |
| **S7** | `dead_end_origin`, `dead_end_length` | 2 per stub | In draw order of S6. |

**The load-bearing property: every draw count must be derivable from earlier draws alone.** S1 fixes the
tree shape, which fixes the internal-node and leaf counts, which fixes the S2–S5 counts. S6 fixes the S7
count. No draw count may ever depend on a validation result, a rejection, or a retry — that is what keeps a
layout a pure function of `(root seed, recipe, starting stream state)`.

**Entrance and exit stay zero-draw.** Today they are fixed coordinates on a reserved central corridor row.
After the structure phase they become **derived** coordinates: entrance = the room of the first leaf in
traversal order; exit = the room whose centroid maximizes BFS distance from the entrance over the reachable
set. Deterministic, no draws, and it maximizes traversal — which is the point of the size classes. The
reserved-corridor fairness trick disappears with it, which is precisely why §3's validator must now *prove*
what construction used to *guarantee*.

**Recipe parameters** (OQ-5, ratified additive): `room_count_band`, `corridor_width`, `dead_end_budget`,
and `bsp_depth_band` are added to `LevelRecipeDefinition` alongside 16.2, as a content-schema change through
the existing repository boundary.

### 2. The unreachable-cell invariant and the real consumer audit

Filler reuses `BoardCell.Terrain.WALL` (AD-3 / OQ-3 / ADR-004). The invariant — *an unreachable cell is
never a move target, never a spawn site, never a reward site, never a valid path node* — is therefore
**enforced at the seam that already exists**: `BoardCell.terrain_blocks_occupancy()` /
`blocks_movement()` / `blocks_line_of_sight()`, consumed through `BoardState`. No new predicate, no new
terrain value, no per-consumer patching.

**The audit list in the design note names five consumers. The real production surface is twenty files.**
Grouped by what 16.2 actually has to do:

**(a) Inherits the invariant for free — no change required.** These already branch on WALL and will treat
filler correctly the day it appears:

- `tactical_movement_query.gd`, `tactical_path_query.gd` — never route through or land on it
- `tactical_visibility_query.gd`, `tactical_line_query.gd` — LoS already blocked by WALL
- `board_state.gd`, `board_cell.gd`, `tactical_entity_state.gd` — occupancy and serialization

> `tactical_line_query.gd` (targeting) is **missing from the design note's audit list** and is a real
> consumer. It is in group (a), so it needs no work — but it belongs on the list.

**(b) Requires a decision or a change in 16.2:**

| File | What changes |
|---|---|
| `entity_reward_placer.gd` | Candidate pool now arrives from the structure phase instead of an open-interior scan. Behavior unchanged; **source** changed. |
| `tactical_wrinkle_placer.gd` | Same — pool source only. |
| `level_validator.gd` | **See §3 — two shipped checks break on room/corridor geometry.** |
| `medium_level_layout_generator.gd` | Owns `validate_readability` and both bounds below. |
| `darkness_fairness_query.gd` | Fairness math counts WALL cells; filler will inflate the count. Needs re-basing onto the reachable set. |
| `tactical_board_tap_router.gd` | A tap on filler must resolve as "not a destination" with a cue, not a silent reject. |
| `tactical_cell_view.gd`, `tactical_occupant_view.gd`, `tactical_board_presenter.gd` | Render filler as structure, not as unexplored dark floor. |

**(c) Excluded by ratified decision:** `boss_arena_builder.gd` (OQ-4 — the arena stays hand-shaped),
`epic_1_micro_combat_scenario.gd` (fixed Epic-1 fixture), `enemy_definition.gd` (definition data only).

#### ⚠️ Two shipped validators reject BSP layouts by construction

This is the highest-value finding of this pass, and it sits inside the very check the design note describes
as reusable.

**`MAX_INTERIOR_WALL_RATIO = 0.35`** (`medium_level_layout_generator.gd:116`) rejects any candidate where
more than 35% of interior cells are WALL. In the open-interior model, interior WALL means **blockers
scattered in the arena**, so the check reads "do not over-clutter the fight" — a sound bound and a
well-chosen number. Once structural filler exists, interior WALL means blockers **plus the dungeon itself**.
The metric conflates two unrelated things: clutter you placed, and space you never carved.

**The consequence, stated precisely.** To pass 0.35 on a Large floor, the interior (24×26 = 624 cells) may
hold at most 218 WALL — so **≥65% of the interior must be carved floor**. A conventional BSP dungeon carves
35–55%. Clearing 65% requires rooms so large and dividers so thin that the floor is effectively open again.

So the bound does not merely reject BSP output — **it exerts continuous pressure back toward the open room
Epic 16 exists to replace.** Two failure modes follow, and the second is the dangerous one:

- **Visible:** a node burns all eight retry attempts and fails. A generator outage, not a tuning miss.
- **Invisible:** someone tuning room density upward in 16.2 until the check goes green, and quietly shipping
  an open plan with dividers.

> *Estimate, not measurement:* 35–55% is a general property of BSP generation, not of Sealsworn output —
> no BSP generator exists here yet. The direction is certain and the bound is certainly exceeded at
> conventional parameterizations; the exact fraction is for 16.2 to measure.

#### ✅ Ratified resolution (Project Lead, 2026-08-05): re-base the metric onto the carved set

**Redefine the ratio as `placed blockers + wrinkles ÷ carved floor cells`.** Raising the number was
rejected — a bound of ~0.70 would pass a room stuffed with blockers at 68% filler and become a rubber stamp.

- **Both numbers are already available.** AD-2 requires the structure phase to emit its reachable-floor cell
  list as the candidate pool, so it lands in the layout dict beside the `blocker_cells` already there. No
  geometric inference, and no ambiguity about whether a room's perimeter wall counts as clutter.
- **No signature change.** `validate_readability(layout: Dictionary)` already receives the whole layout dict,
  and its only two production call sites (`level_generator.gd:187`, `level_validator.gd:260`) already pass it.
  The change is one function body plus its diagnostic payload.
- **Keep `0.35`.** The semantics are preserved exactly — *at most 35% of the walkable space you carved may be
  filled in*. Do not invent a new number; verify this one against the fairness batch in 16.2 and move it only
  with evidence.
- **Absent-key fallback protects 16.1.** When the carved-set key is missing — every 16.1 layout, since the
  open-interior algorithm is unchanged there — the check falls back to the current interior computation.
  **16.1 behavior is byte-identical.** This is purely a 16.2 concern and does not block starting the epic.

**Rider — add `insufficient_reachable_fraction` (new check).** Once filler exists, nothing bounds it from
the other direction. A floor must carve at least a minimum share of its grid, so a degenerate BSP cannot put
three tiny rooms in a 26×28 board. The GDD implies this ("a genuine dungeon level — multiple rooms, real
traversal") and nothing enforces it today. It becomes violable only in 16.2, so it belongs in that story.

**Rejected alternative worth recording:** giving filler its own `Terrain` value would make the metric work
untouched, but it reopens AD-3/ADR-004 and trades inheritance across ~20 consumers to fix a metric in one.
Only three consumers care about the structure/clutter distinction — this check, `darkness_fairness_query`,
and presentation — and presentation can already distinguish, because `blocker_cells` is in the layout dict.

#### The second collision, and the third consumer to re-base

**`MIN_FIRST_REVEAL_CELLS = 8` within `FIRST_REVEAL_RADIUS = 4`** is marginal rather than fatal: an entrance
opening into a room passes comfortably; an entrance opening into a 1-wide corridor yields roughly 4–9 cells
and will fail intermittently. Placing the entrance in a room (§1) largely resolves it. **Verify against real
BSP output in 16.2 rather than assuming.**

**`darkness_fairness_query.gd`** counts WALL for its fairness math and will be inflated by filler exactly as
`excessive_blockage` is. Re-base it onto the carved set in the same pass.

Both bounds are test-pinned. Changing `excessive_blockage`'s measured set is a **deliberate behavior change
to a shipped validator** and must be a named acceptance criterion in 16.2 with recorded justification — not
slipped in as a refactor. Note the re-pin interaction: the validator alters no terrain, but flipping a
candidate from reject to accept changes which layout the retry loop returns, so **layout fingerprints move**.
16.2 is already re-pinning those, which is precisely why the work belongs there and not in 16.1.

### 3. The connectivity and fightability validator (AD-4)

The validator extends `LevelValidator`'s existing shape: separate named checks, a fixed documented
`CHECK_ORDER`, first-failure short-circuit, compact diagnostics (counts and coordinates, never a grid dump),
and structured rejection through `GenerationResult` — validate-then-reject, never coerce. It stays a **pure
query**: no RNG, no commands, no mutation, so the `_layout_draws_only_from_level_stream` assertions stay
green.

Four checks, appended after the shipped set:

| Code | Proves | Method |
|---|---|---|
| `disconnected_reachable_set` | The reachable floor set is **one** component | Single 4-neighbour flood from the entrance; compare the flooded count against the total non-WALL count. A mismatch means a sealed pocket. |
| `unreachable_exit` | entrance → exit | **Already shipped** (check (a)); no new code, it simply stops being true by construction. |
| `entity_off_reachable_set` | Every enemy, reward, and entity sits on a reachable cell | Set membership against the §3 flood. Strengthens the shipped `illegal_enemy_placement`, which asserts legality but not reachable-set membership. |
| `insufficient_fightable_space` | The floor affords its own encounter | See below. |

**Fightable space, defined concretely** — the design note names the requirement but not the measure. A
floor passes when **at least one room** in the reachable set satisfies both:

- open-cell count ≥ `(enemy_count + 1) × 3`, and
- a bounding box of at least 3×3.

with per-class floors of **Small ≥ 12, Medium ≥ 20, Large ≥ 30** open cells in that room. The intent is
narrow and worth stating: this rejects *an encounter jammed into a corridor*. It is **not** a difficulty
knob and must never become one — it is a geometry guard, and the difficulty non-goal is unaffected.

### 4. Enemy activation on the tactical entity and turn seam

Dormant/awake is tactical truth — it changes whose turn resolves — so it lives on the entity, flows through
the turn resolver, and is never read from or written to a scene node (AD-5).

- **`TacticalEntityState` gains `awake: bool`, defaulting to `true`.** The default is deliberate: every
  existing fixture, the Epic-1 scenario, and the boss arena keep their current behavior untouched, and the
  **generator** is what sets `awake = false` on enemies it places on room/corridor floors. This keeps the
  16.3 re-pin surface as small as it can be.
- **`enemy_turn_resolver.gd` skips dormant units** and states why, in the existing AI-explanation language
  ("dormant: no line of sight"), covered by explanation tests.
- **Waking emits an append-only tail domain event** (`enemy_awakened`), growing `DomainEvent.Type` by
  exactly one tail member: **`Type.size()` 44 → 45**, tail `enemy_awakened` at index 44.
- **Serialization:** `awake` rides `TacticalEntityState.to_dictionary()`, which sits inside the `board` key.
  `try_from_dictionary` must **default `awake` to `true` when the key is absent**, so pre-16.3 saves and
  fixtures load unchanged. The entity key-set is pinned by test and that pin moves once, deliberately.
- **The 23-key `RunSnapshot` gate stays 23** and `SCHEMA_VERSION` stays 1. The in-node fight remains
  ephemeral; nothing here creates a mid-fight save, which stays out of scope as it has since Epic 11.
- **No deadlock when every survivor is dormant:** the shipped `WaitCommand` (14.1) lets the player always
  pass the turn. 16.3 must test it rather than assume it.

> **Sequencing dependency — flag for the Project Lead.** The GDD's awareness guardrail is *"waking may
> happen unseen; damage may not arrive unannounced."* The second half is satisfied by **Story 15.3 threat
> telegraphs**, which is still `backlog` in Epic 15 Band 2. If 15.3 slips past 16.3, the guardrail is
> unenforced and dormant enemies can deliver a first strike from outside the player's line of sight with no
> telegraph. **16.3 depends on 15.3**; either 15.3 lands first or 16.3 carries a temporary in-story
> telegraph.

### 5. OQ-2 — the Story 3.6 bounded-retry seam is reusable as-is

**Confirmed: reuse it. No structural change is required.** Story 3.6 shipped
`_run_layout_phase_with_retry` with `MAX_GENERATION_ATTEMPTS = 8`, and it already does everything Epic 16
needs: it retries any *recoverable* layout, readability, board-build, or validation failure; it
short-circuits *unrecoverable* ones; and it stamps `attempts` into every diagnostic.

**One correction to OQ-2's stated premise, and it makes the picture better rather than worse.** OQ-2 says
*"retries consume `STREAM_LEVEL` draws, so the attempt count must stay fixed and documented in the FIXED
DRAW ORDER."* The shipped implementation does not work that way. Each attempt constructs a **fresh
`RngStreamSet.new(attempt_seed)`** (`level_generator.gd:149`); a failed attempt's draws are discarded with
its stream set, and `_attempt_seed(base, 0) == base` so attempt 0 reproduces the unperturbed layout exactly.

Consequences:

- **Level generation is hermetic.** Retries cannot perturb any other system's stream state, because the
  generator never touches the run-level stream set at all.
- **The attempt count does not belong in the fixed draw order** for determinism of downstream systems. What
  must be documented instead is that the structure draws live *inside* the per-attempt stream, and that
  attempt 0 must remain byte-identical to the unperturbed seed. That invariant is the fingerprint anchor.
- The determinism goal OQ-2 was protecting is already achieved, by a stronger mechanism than the one it
  assumed.

**What 16.2 must actually do to the seam — two small things, neither structural:**

1. **Classify the new validator codes.** `_is_unrecoverable_layout_error` decides what is worth retrying.
   All four §3 codes are **recoverable** (a different seed produces different geometry). Missing recipe
   parameters are **unrecoverable**. Misclassifying a recoverable failure burns all eight attempts on a
   hopeless candidate; misclassifying an unrecoverable one hides a content bug behind a retry.
2. **Re-derive the attempt bound from measurement, not from a guess.** Eight attempts was sized against a
   generator whose candidates passed on attempt 0. BSP plus four new invariants has a genuinely non-zero
   rejection rate. 16.2 should **measure** the rejection rate across the fairness batch and set the bound so
   the worst case stays inside the NFR4 `< 3s` load budget. Keep it a **fixed, documented constant** either
   way.

### 6. OQ-6 — round tracking, answered

**The split is confirmed, in three parts.** These are independent and must not be collapsed into one
another.

**(a) No player-facing turn limit — anywhere, ever.** `interactive_combat_session.gd` imposes no cap today
and must not gain one. 16.1 should add an explicit regression test asserting the *absence* of a cap, so the
guarantee is enforced rather than merely intended. This is the ratified Q2 answer and nothing below
qualifies it.

**(b) `MAX_ROUNDS` becomes a per-size-class harness guard.** It binds only `live_combat_resolver.gd`
(auto-resolve) and `reference_combat_driver.gd` (the winnability proof), where a `while` loop must
terminate, and on the cap both fail loud rather than fabricate an outcome. The constant becomes a function
of size class:

| Class | Cells | Provisional guard | Basis |
|---|---:|---:|---|
| Small (~12×12) | 144 | **160** | |
| Medium (~18×16) | 288 | **256** | Today's Medium (14×12) worst measured proof run is **~39 rounds** against a guard of 64 — only 1.6× headroom, which is why it is fragile. |
| Large (~26×28) | 728 | **512** | ~2× the linear traversal of Medium at 1 tile/turn, plus room-by-room engagement. |

The governing rule matters more than the numbers: **the guard must be ≥ 4× the worst measured proof run for
that class**, re-derived in 16.1 and again in 16.2 from the re-proven catalog. Hitting it must always mean
"this board is broken", never "this fight was long". `64` survives nowhere.

**(c) A real round counter in domain state.** Verified gap: `tactical_turn_state.gd` carries `turn_number`
but no round counter; the resolvers' `rounds` is a local loop variable, discarded at the end of the fight.

- **`TacticalTurnState` gains `round_number: int`, defaulting to 1**, incremented at the round boundary by
  the turn resolver, and exposed to the board view model and the combat log so it is addressable by later
  content (secrets gated on acting before round N, round-keyed unlocks).
- **A correction to AD-7's cost claim.** AD-7 states the counter does not persist and therefore costs
  nothing at the save boundary. The 23-key gate is indeed untouched — but `TacticalTurnState.to_dictionary()`
  is **exact-key pinned by test** and rides the `turn_state` key of `RunSnapshot`. So the counter *is*
  serializable, the pinned key-set moves once, and `try_from_dictionary` must default `round_number` to 1
  when the key is absent. Small, but real, and it should be in the story rather than discovered in review.
  Nothing here creates a mid-fight save; the counter simply does not survive a quit, which is correct.

### 7. The two-phase re-pin and the winnability re-proof

| Story | What moves | What must NOT move |
|---|---|---|
| **16.1** | Layout fingerprints (Small/Medium dimensions) + new Large entries; the round-guard constants | The draw order; the algorithm; finale fingerprints |
| **16.2** | Layout fingerprints (algorithm) + geometry-dependent combat-replay composites; the `excessive_blockage` measured set | Route/finale fingerprints; save schema; the seven named streams |

Each re-pin is re-derived through the existing `tools/dump_*` path **in the same PR**, with the
justification recorded. Never a hand-edit to make a drifting test pass. This is the project rule and the
14.1 precedent.

**The schedule is exactly two, as ratified.** Size-class selection (§8) was briefly thought to force a third
— it does not, provided its draws are appended at the tail of the route draw order. Route fingerprints stay
in the "must NOT move" column above.

#### ⚠️ The reference driver's hero policies will not survive corridors unassisted

`APPROVED_LIVE_COMBAT_SEED_CATALOG` must be re-derived from live runs for every class at every size class
after **each** re-pin. That cost is understood. The cost that is routinely underestimated is that the
**driver itself** needs work, and it should be budgeted inside 16.2 rather than discovered when the catalog
fails.

The precedent is exact and recent: Story 14.1's corpse-clearing — a far smaller geometry change than this
one — made Medium seed 512 unwinnable *by the reference kite heuristic*, a legitimate deterministic
consequence rather than a bug. The driver's policies each encode open-room assumptions:

- **Ranger kiting** assumes a retreat cell always exists that increases distance. In a corridor there is
  often no such cell; in a dead-end stub the policy retreats *into* the trap and oscillates until the guard
  fires.
- **Melee one-at-a-time commit** is arguably *helped* by chokepoints, but its target selection will thrash
  when pathing through a doorway repeatedly re-orders candidates at equal distance.
- **Seer-detonation dodging** assumes lateral space to step out of the marked tile. A 1-wide corridor
  frequently has none.

**Budget "reference driver policy v2" as explicit scope inside 16.2**, with two rules that make every policy
terminate: a retreat cell must both increase distance *and* not be a dead-end; and when no policy move
improves the position, the driver **commits to attack** rather than passing. A driver that always makes
progress is what turns the round guard back into a genuine "broken board" signal.

### 8. Size-class selection — a new weighted draw

The designer pass created this; the design brief did not cover it. Q5 is now concrete depth-weighted bands
(early 60/35/5, mid 25/60/15, late 10/55/35), with elite nodes shifting one band toward Large and the
pre-boss node weighting Large heaviest — **positive weights only, never exclusive**.

**What exists today:** size class is not drawn at all. `NodeEnterCommand` reads it from a static
`NODE_TYPE_SIZE_CLASS` table (combat → Small, elite → Medium), and the command's docblock states it "draws
ZERO RNG". The value already rides the `node_entered` event payload, so **no event-schema change is needed**.

**Ratified placement (Project Lead, 2026-08-05): appended at the TAIL of `RouteGenerator`'s fixed draw
order, on the `map` stream, stored on `RouteNode`. This costs ZERO fingerprint movement — see below.**

- **`map`, not `STREAM_LEVEL`.** Size class is a property of the **node**, not of the layout. It must be
  known *before* `LevelGenerator.generate` is called, because it selects the recipe. And `STREAM_LEVEL` is
  structurally wrong here: the generator mints its own stream set from `request.level_seed()` on every call,
  so a `STREAM_LEVEL` draw would return the **same** size class for every node in the run.
- **Inside `RouteGenerator`, not the orchestrator.** Size class is route-structure truth — the GDD groups
  affinity assignments with the run map and node structure, and size class is more structural still.
  `RouteGenerator` already owns node type, depth, links, and clues; this is the same kind of fact.
- **Appended as step (5), after the shipped (1) non-boss count → (2) column widths → (3) node type + clue →
  (4) fan-out.** One weighted draw per **size-class-bearing node** (combat and elite only), in ascending
  `(depth, index)` order. The boss node draws nothing (the arena is authored, OQ-4); compact special nodes
  (shop, reforge, gambling, event, secret) draw nothing, because they are not combat floors.
- **The draw count stays derivable from earlier draws.** Node types are fixed by draw (3a), which runs
  before (5), so *which* nodes draw a size class is a pure function of earlier draws. That is the rule that
  keeps route generation a pure function of `root_seed`.
- **`RouteNode` gains an optional `size_class` field.** `try_from_dictionary` already treats
  `outgoing_link_ids` and `clues` as optional with defaults, so an optional field with a default follows the
  shipped pattern and **loads old saves unchanged**. It rides `route_state`, so the **23-key gate stays 23**
  and the value is recorded — a resume reads it back instead of re-drawing. `RunOrchestrator.assign_affinity`
  remains the precedent for *recording a per-node draw result keyed by node id*.
- **Recipe lookup becomes `(node_type, size_class) → recipe`**, and a `large_combat_basic` recipe joins the
  two shipped ones.

**Interaction with §5 (bounded retry): provably none, in both directions.** Size class is fixed before
`LevelGenerator.generate` is entered. The retry loop mints a fresh `RngStreamSet` from
`request.level_seed()` and never touches the run-level set or the `map` stream. So retries cannot perturb
the drawn size class, and the size-class draw cannot be perturbed by how many retries a node consumed. This
is a structural guarantee, not a convention to be maintained.

#### ✅ Why this moves no fingerprint — the two facts that make it free

An earlier draft of this section escalated size-class selection as a **third re-pin** colliding with the
ratified two-re-pin schedule. **That escalation was withdrawn on 2026-08-05 after verification. It was
wrong, and the schedule survives intact.** Two facts, both read out of the shipped code:

1. **There are two independent `map` stream-set instances, not one.** `RouteGenerator.generate()` mints its
   own `RngStreamSet.new(root_seed)` internally (`route_generator.gd:100`), uses it, and discards it.
   `RunOrchestrator.start()` separately mints `RngStreamSet.new(root_seed)` (`run_orchestrator.gd:203`) for
   the run-level set that `assign_affinity` draws on. These are the **only two `map` consumers in the
   codebase**. So a draw added inside route generation **cannot** perturb affinity, and vice versa — the two
   fixture families are decoupled.
2. **The route fingerprint does not cover the field being added.** `RouteGenerator.fingerprint()` is
   `count|<id:type@depth …>|<links>|boss<depth>` — node count, id, type, depth, outgoing links, boss depth.
   It does not cover `clues`, and it does not cover a new `size_class` field. The seed-regression suite's
   route fixture calls that function directly (verified), so there is no second, broader pinning path.

**Therefore:** appending the draws at the tail means draws (1)–(4) run from an identical starting state in
an identical order, every field the fingerprint covers is byte-identical, and the fingerprint does not move.
Affinity draws on a different instance over an unchanged node set, so it does not move either.
**Route fingerprints stay in the "must NOT move" column of §7's table, exactly as ratified.**

#### The coverage this costs, and how to pay for it properly

Keeping `size_class` out of the route fingerprint means a size-class regression is not caught by it. **Do
not fix that by folding the field into the fingerprint.** That would cost the re-pin this design just
avoided, and buy weak coverage: a single-route hash barely tests a weighted distribution.

**Add a separate size-class distribution fixture instead**, asserting across a batch of seeds that:

- the depth-weighted bands hold (early 60/35/5, mid 25/60/15, late 10/55/35, within a stated tolerance);
- elite nodes shift one band toward Large and the pre-boss node weights Large heaviest;
- **no class is ever zero-probability at any depth** — the positive-weights-only contract (ratified D3),
  which is the property most likely to be broken silently by a refactor and is invisible to a per-route hash.

That is the contract Q5 actually ratified, and it is better tested here than it ever would have been inside
the fingerprint.

### 9. Shaping Epic 16 for Epic 17 — and the finding that changes Epic 17's shape

**The designer's lean is confirmed: extend AD-4's validator, do not duplicate it — with one exception that
must be named now.**

Build AD-4 as a **reachability oracle plus a registered list of satisfiability predicates**, rather than as
four hard-coded checks. Epic 16 registers exactly one predicate (`encounter_is_engageable`, §3's fightable
space). Epic 17 registers `none`, `slay_boss`, and `cull_fraction` against the same oracle. The oracle — one
flood-fill, one reachable set, one membership test — is written once and never rewritten. **The cost today
is a parameter and an array; the saving in Epic 17 is a rewrite avoided.** That is the single most valuable
shaping decision available, and it should land in 16.2.

**The exception, and it is a real refinement of the designer's framing.** The three objective kinds are not
the same species of question. "Is the exit reachable?" and "does a boss exist on this floor?" are geometry.
"Can ≥50% of this floor's enemies be **defeated** by this class?" is combat — AD-4's flood fill has no model
of damage, HP, or class kit, so it cannot decide it at any level of extension.

**Ratified split (Project Lead, 2026-08-05): necessary vs. sufficient.**

| | Condition | Owner | Method |
|---|---|---|---|
| **Necessary** | ≥2 living enemies (so a 50% threshold is meaningful in whole units); every enemy on the reachable set; `ceil(0.5 × enemy_count)` enemies sit in rooms with fightable space; the exit stays reachable once the threshold is met | **Story 17.1** | AD-4's oracle — pure geometry and counting |
| **Sufficient** | A class can actually reach the threshold *and then* reach the exit | **Story 17.5** | Reference driver only |

`none` and `slay_boss` are fully satisfiable by the extended AD-4 in 17.1, as the designer scoped them.
Only `cull_fraction` splits.

This keeps each story's acceptance criteria provable by the tool that story owns. Leaving the whole question
in 17.1 would put an unanswerable AC inside the validator; moving it wholly to 17.5 would leave no
generation-time guard at all, permitting degenerate floors — a `cull_fraction` objective on a one-enemy
floor, or on enemies sealed where the threshold cannot be met. **Neither the "extend, don't duplicate"
principle nor AD-4's shape changes; only the story boundary does.**

**AD-5 (activation) is the second decision that should be shaped now.** Direction A makes stealth a complete
strategy, which only works if "unseen" is a real, queryable board property. AD-5's `awake` flag on the
entity — rather than a presenter-side wake cue — is exactly what a future stealth objective reads. Keeping
it on the entity seam costs nothing extra today.

#### ⚠️ The exit-victory win condition does not live where the stub says it does

The Epic-17 stub, and the design note's §5b, both locate the win condition at
`combat_outcome_evaluator.gd` (`living_enemy_count == 0 → victory`). That is where the *branch* is. It is
not where the *contract* is. `remaining_enemy_count == 0` is asserted at **three independent layers**:

1. **`CombatOutcomeEvaluator.evaluate`** — the gameplay branch (the known one).
2. **`DomainEvent._validate_level_victory_reached_payload`** — a static event-payload validator that
   **rejects any `level_victory_reached` payload with `remaining_enemy_count != 0`**.
3. **`BoardState._validate_level_victory_reached_event`** — an apply-time validator that rejects the event
   unless the board has **zero living enemies** *and* the payload's `defeated_enemy_ids` equals the board's
   complete defeated list exactly.

A fourth constraint sits alongside them: `CombatOutcomeState.apply_outcome_event` accepts only
`LEVEL_VICTORY_REACHED` and `LEVEL_DEFEAT_REACHED` and returns `unsupported_event` for anything else.

**Consequence for Epic 17 (ADR-005):** exit-victory cannot be expressed by flipping a branch. Emitting
`level_victory_reached` with enemies still alive is rejected twice before it reaches the outcome state.
The correct shape is a **new append-only tail event** — `level_exit_reached` — with its own payload
validator and its own `BoardState` apply-time validator, leaving `level_victory_reached`'s meaning and every
existing consumer untouched. `CombatOutcomeState` then maps the new event to `STATE_VICTORY`. This grows
`DomainEvent.Type` by one tail member on top of §4's, and it is a materially different (and safer) piece of
work from what "change the win condition" implies.

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
