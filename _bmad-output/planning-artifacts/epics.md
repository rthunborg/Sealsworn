---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - "_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md"
  - "_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md"
  - "project-context.md"
  - "_bmad-output/game-architecture.md"
---

# Sealsworn - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Sealsworn, decomposing the requirements from the GDD, existing epics, project context, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: The game must provide an offline-first single-player MVP loop where a player starts a run, chooses a class, descends through levels, fights, collects rewards, makes passive choices, dies or wins, sees a summary, and can begin another descent.

FR2: The player must control one hero in turn-based tactical combat with no real-time pressure.

FR3: Every committed player action must advance enemies and applicable level systems.

FR4: The baseline player movement budget must be 3 tiles per committed move action.

FR5: The baseline line-of-sight radius must be 4 tiles.

FR6: The baseline player HP must be 18.

FR7: Tactical levels must represent unexplored tiles as hidden, explored-but-out-of-line-of-sight tiles as memory, and visible tiles as current tactical truth.

FR8: The tactical board must support movement previews before a move is committed.

FR9: The tactical board must support attack previews before an attack is committed.

FR10: Attack previews must show weapon reach, path or line, expected damage, effects, blockers, and warnings such as adjacent ranged penalties when applicable.

FR11: Mobile attacks must default to a deliberate two-step commit flow through a second tap on the same target or a clear confirm action.

FR12: The game must provide inspect behavior that reveals tile, terrain, occupant, move cost, attack preview, hazard notes, and telegraphed danger.

FR13: Desktop input must preserve rule parity through mouse and keyboard support.

FR14: The player must have a universal basic attack shaped by the equipped weapon.

FR15: Attacks must generally require straight-line alignment unless a weapon or effect explicitly overrides that rule.

FR16: The MVP weapon baseline must support Sword, Dagger, Spear, Axe, Mace, Bow, Crossbow, Staff, and Wand attack identities.

FR17: The MVP support baseline must support None, Tome, and Shield support item identities.

FR18: The tactical slice must support Iron Cultist, Gate Brute, and Ash Seer enemy patterns.

FR19: Iron Cultist must advance toward the player and deal physical damage when adjacent.

FR20: Gate Brute must provide a heavier melee body-blocking pressure pattern.

FR21: Ash Seer must support a telegraphed ranged mark followed by delayed detonation if the player remains on the marked tile.

FR22: Combat must support damage application, death, simple victory state, and feedback explaining why damage occurred.

FR23: Enemy turns must be resolved after committed player actions using valid tactical actions.

FR24: Enemy AI decisions must be constrained by enemy state or phase and produce explainable chosen-action reasons.

FR25: Tactical query services must provide pathfinding, line of sight, threat maps, valid movement, attack previews, and tile scoring.

FR26: Runs must be seeded and forward-only.

FR27: Manual seed entry must be allowed for replay, debug, sharing, and practice.

FR28: Manual seed runs must not grant meta progression.

FR29: Seeded generation must reproduce major run structure, node structure, level layouts, affinity assignments, enemy placements, reward categories, major event outcomes, and boss or finale setup.

FR30: A successful MVP run must target 8-12 nodes before the boss.

FR31: The MVP victory condition must be defeating the Larval Avatar at the final node.

FR32: The MVP loss condition must be hero death during a level, event, or boss encounter followed by return to the last outpost.

FR33: Combat node types must include combat and elite combat.

FR34: Non-combat node types must include shop, reforge, gambling, risk/reward event, secret or lore discovery, and boss.

FR35: Procedural combat levels must include a clear entrance, clear exit, enough blockers or cover for line-of-sight play, and at least one tactical wrinkle.

FR36: Procedural generation validation must check entrance-to-exit pathing, absence of required class or item gates, legal enemy placement, reachable intended rewards, and safe first reveal.

FR37: Small levels must be supported around 8x8 tiles.

FR38: Medium levels must be supported around 14x12 tiles.

FR39: Large and Huge level generation polish must be deferred for MVP unless needed for the boss or a rare special node.

FR40: The MVP must support save/resume between levels.

FR41: Mid-level save/resume should be supported if feasible without destabilizing the MVP architecture.

FR42: The MVP class roster must include selectable Warrior, Pyromancer, and Ranger.

FR43: Necromancer and Shadeblade must appear as locked, grayed-out future classes with clear unlock hints or requirements.

FR44: Each playable class must start with one class passive and one equipment-synergy passive.

FR45: Classes must not start with active class skills at level 1.

FR46: The MVP passive pool must support 20-30 passives, including 3-5 weird rule-benders.

FR47: Passive rewards must present awakened-memory choices with icon, evocative name, short flavor line, exact mechanical effects, Consume choice, and Destroy choice.

FR48: Consume must provide power and build identity.

FR49: Destroy must provide safety, purification, resources, secrets, refusal, or future consequence avoidance and must be a meaningful alternative rather than a dead option.

FR50: Destroy outcomes must support small immediate benefits, progress or hidden flags, and no-obvious-reward outcomes that avoid corruption or future danger.

FR51: The MVP inventory must remain small, likely 6 backpack items with no stacking by default.

FR52: Loot must support weapons, armor, jewelry, support items, consumables, pickups, passives, gold, and later affixes or enhancements through data boundaries.

FR53: Consumables must be semi-rare and worth using.

FR54: MVP economy must support gold, scarce healing, curses or corruption, Oath Shards, passives, and loot.

FR55: Cursed or corrupted rewards must communicate clear downside and clear upside before acceptance.

FR56: MVP affinities must support Scorched, Flooded/Conductive, Cursed, and Darkness.

FR57: Affinities must alter tactical choices rather than only visuals.

FR58: Darkness must create uncertainty through visibility or memory pressure without unavoidable damage from unseen space.

FR59: The outpost loop must support Oath Shards, Echoes, Seal Fragments, class mastery progress, unlock progress, and a shallow MVP meta menu or tree.

FR60: Run summary must show cause of death or victory, nodes cleared, boss or elite progress, passives consumed and destroyed, notable loot, Oath Shards earned, Echoes discovered, unlock progress, and seed.

FR61: First death must be able to show the line "Good. You remembered how to die."

FR62: First victory must be able to show the reveal "It did not die. It learned the way back."

FR63: The Larval Avatar must be implemented as the only required MVP boss. (Numbering note, 2026-07-04: this is the canonical implementation FR63. The design-time GDD separately uses "FR63" for named outpost/meta spaces, which traces to Story 8.6 — see the 2026-06-04 traceability map. Cite the canonical numbering.)

FR64: The game must keep story discovery optional and must not require lore reading to understand the gameplay loop.

FR65: Cutscenes and control-loss narrative moments must be skippable.

FR66: The game must support phone portrait, phone landscape, tablet, and desktop-style wider layouts without changing underlying tactical rules.

FR67: Players must be able to zoom and inspect the level on all supported devices and orientations.

FR68: The MVP must include UI flows for hero select, tactical HUD, tile/attack preview, passive modal, run map, outpost/meta menu, run summary, settings, and save/resume.

FR69: The game must expose enough combat log or equivalent feedback for players to identify why they took damage or died.

FR70: Every epic milestone must preserve a playable build that can launch and validate a small test loop.

### NonFunctional Requirements

NFR1: Production must use Godot 4.6.3 stable standard build and typed GDScript.

NFR2: Production code must live under `godot/`; the React/Vite prototype is validation evidence only and must not be a production dependency.

NFR3: The MVP must target iOS/Android mobile and tablet first, with Windows desktop/laptop parity.

NFR4: Generated level load time should be under 3 seconds for MVP.

NFR5: UI preview and selection response should be under 100ms.

NFR6: The game should target stable 60 FPS where feasible, with 30 FPS acceptable on lower-end mobile if input remains responsive.

NFR7: Combat input and tactical information must remain readable on phone-sized screens.

NFR8: The game must support scalable text.

NFR9: Critical tactical information must be colorblind-safe and must not rely on color alone.

NFR10: The game must have no reflex or timing requirements.

NFR11: MVP must not introduce accounts, multiplayer, cloud saves, leaderboards, or live-service dependencies.

NFR12: The architecture must preserve a native mobile packaging path from the start.

NFR13: Gameplay-affecting systems must be deterministic under seeded execution.

NFR14: Headless simulation must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.

NFR15: Save truth must be versioned domain snapshots, never serialized scene nodes.

NFR16: Gameplay systems must use repositories for definitions and persistence rather than direct gameplay file access.

NFR17: Static content and AI-assisted assets must pass validation and human approval before production use.

NFR18: Placeholder assets must be clearly marked and kept separate from approved production assets.

NFR19: Debug and cheat tools must be disabled or inert in production builds.

NFR20: Target device tiers, measurement methods, memory budget, and battery/performance expectations must be defined before production readiness.

### Additional Requirements

- Initialize a clean custom Godot project rather than a third-party gameplay starter.
- Use a plain typed GDScript domain model as the authoritative owner of tactical truth; Godot scenes mirror state and events.
- Implement gameplay actions as validated commands that return `ActionResult`.
- Successful commands must emit deterministic past-tense `DomainEvent` records.
- Domain state machines must represent app, run, level, turn, and UI mode flow.
- Thin autoloads are allowed for global services such as `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, and diagnostics, but they must not own gameplay decisions.
- Implement named RNG streams derived from a root seed: `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic`.
- Gameplay-affecting randomness must use its assigned stream; cosmetic randomness must not affect outcomes, rewards, achievements, or progression.
- Save files must be versioned local JSON in `user://` for MVP and written through a `SaveRepository`.
- Save snapshots must include schema/content version, root seed, named RNG stream states, route state, revealed route information, manual-seed eligibility, level state, fog memory, entity snapshots, hazards, pending turn state, inventory, equipment, passives, curses/corruption, affinities, currencies, and meta progression where applicable.
- Static content should use JSON/CSV source data plus typed Godot Resource mirrors through repository/import boundaries.
- Runtime-facing definitions should include `EnemyDefinition`, `ItemDefinition`, `PassiveDefinition`, `AffinityDefinition`, `WeaponDefinition`, `SupportItemDefinition`, `LevelRecipe`, and `RewardTable`.
- Procedural generation must run through explicit phases: route node generation, level recipe selection, layout/pathing, entrance/exit/blocker/hazard placement, enemy/reward placement, affinity/special-rule application, validation, and final immutable snapshot.
- Generator validation failures must report seed, phase, reason, and compact debug output.
- The rules kernel must support explicit trigger windows, deterministic resolver queue, conditions, targets, operations, durations, stacking, conflict handling, stable resolution order, and explanation output.
- Rules must prioritize tactical readability over generic systemic completeness.
- Enemy AI must use utility scoring constrained by enemy states/phases and produce decision explanations.
- Adaptive UI must use view models, presenters, layout profiles, and a command bridge so UI observes domain state and submits commands without owning tactical truth.
- Required MVP tests include unit tests for domain rules, commands, RNG streams, rules kernel, and save snapshot migration.
- Required MVP integration tests include generation, validation, save/load, combat resolution, passive interactions, and reward flow.
- Debug tooling should include overlays or viewers for seed, fog, line of sight, pathing, threats, combat previews, enemy utility scores, and generator validation.
- Headless simulation should support seed regression runs, bot playtests, batch difficulty simulations, and future automated E2E flows.
- Production folder mapping must follow the architecture and project context: core commands/results/events under `godot/scripts/core`, tactical board/combat/fog/turns under `godot/scripts/tactical`, rules under `godot/scripts/rules`, generation under `godot/scripts/generation`, AI under `godot/scripts/ai`, content repositories under `godot/scripts/content`, saves under `godot/scripts/save`, UI view models/presenters under `godot/scripts/ui`, and tests under `godot/tests`.
- `scripts/tactical/`, `scripts/rules/`, `scripts/generation/`, `scripts/ai/`, and `scripts/save/` must not depend on Godot scene nodes for authoritative logic.
- `scenes/` and `scripts/ui/` may observe domain state and submit commands but must not mutate tactical state directly.
- `prototype/` must remain reference material only.
- Tests must mirror the domain they cover, and new systems require unit or integration test locations before implementation begins.
- Begin implementation with the domain model, commands/events, RNG streams, tactical board model, and tests before UI-heavy scene work.

### UX Design Requirements

No standalone UX Design document was found during discovery. UX-related requirements were extracted from the GDD, existing epics, project context, and architecture into the Functional, NonFunctional, and Additional Requirements sections above.

Readiness patch note: the missing standalone UX document is non-blocking for Epic 1 domain-first work. Before UI-heavy scene implementation beyond view-model and command-bridge contracts, add a lightweight UX appendix or equivalent notes for tactical HUD, preview/confirm states, inspect panel, passive modal, run map, outpost/meta, run summary, settings, and save/resume recovery.

### FR Coverage Map

FR1: Epic 4 - The full run loop is staged through forward progression once fixed tactical levels and generation exist.

FR2: Epic 1 - Turn-based one-hero tactical combat is the first playable slice.

FR3: Epic 1 - Committed actions advancing enemy and level systems is core combat flow.

FR4: Epic 1 - Baseline 3-tile movement belongs to the tactical board and command slice.

FR5: Epic 1 - Baseline 4-tile line of sight belongs to tactical visibility.

FR6: Epic 1 - Baseline 18 HP belongs to the first combat state model.

FR7: Epic 1 - Fog, explored memory, and visible tactical truth are part of board readability.

FR8: Epic 2 - Movement preview is made usable through mobile-first input and presentation.

FR9: Epic 2 - Attack preview is made usable through mobile-first input and presentation.

FR10: Epic 2 - Detailed attack preview presentation belongs to mobile UX and accessibility.

FR11: Epic 2 - Two-step mobile attack commit belongs to input safety.

FR12: Epic 2 - Inspect behavior belongs to tactical UX and readability.

FR13: Epic 2 - Desktop input parity belongs to cross-device UX.

FR14: Epic 1 - Universal weapon-shaped basic attack is core combat.

FR15: Epic 1 - Straight-line attack legality is core targeting.

FR16: Epic 1 - Baseline weapon attack identities are needed for the tactical slice.

FR17: Epic 1 - Baseline support item identities are needed for the tactical slice.

FR18: Epic 1 - First enemy patterns are part of the combat slice.

FR19: Epic 1 - Iron Cultist behavior validates melee pressure.

FR20: Epic 1 - Gate Brute behavior validates heavier body-blocking pressure.

FR21: Epic 1 - Ash Seer behavior validates telegraphed caster danger.

FR22: Epic 1 - Damage, death, victory, and damage explanation close the combat loop.

FR23: Epic 1 - Enemy turns after committed player actions are core combat flow.

FR24: Epic 1 - Explainable enemy decisions are part of deterministic combat behavior.

FR25: Epic 1 - Tactical query services support movement, targeting, AI, and previews.

FR26: Epic 4 - Seeded forward-only runs are the run-map progression structure.

FR27: Epic 3 - Manual seed entry begins with seed-stable generated level loading.

FR28: Epic 8 - Manual seed no-progression enforcement belongs to meta progression and run completion.

FR29: Epic 3 - Seeded reproduction across generation facts belongs to procedural generation v0.

FR30: Epic 10 - Successful run length target is validated during MVP tuning.

FR31: Epic 9 - Defeating the Larval Avatar is the MVP finale victory condition.

FR32: Epic 8 - Death returning to the outpost belongs to the roguelite return loop. (As-built note, 2026-07-04: Epic 8/9 prove the death RESOLUTION path with driven deaths; the LIVE hero-death trigger — combat loop detecting hero 0 HP — lands in Epic 11, Story 11.2.)

FR33: Epic 4 - Combat and elite combat node types belong to run-map progression.

FR34: Epic 4 - Non-combat node types belong to the forward route shell.

FR35: Epic 3 - Procedural combat-level requirements belong to generated level v0.

FR36: Epic 3 - Generator validation belongs to procedural generation v0.

FR37: Epic 3 - Small level support belongs to generated level v0.

FR38: Epic 3 - Medium level support belongs to generated level v0.

FR39: Epic 3 - Large/Huge deferral is a procedural generation scope constraint.

FR40: Epic 2 - Between-level save/resume foundation supports interruption-friendly play.

FR41: Epic 2 - Mid-level save/resume feasibility is evaluated with the save/resume foundation.

FR42: Epic 5 - Warrior, Pyromancer, and Ranger belong to class selection.

FR43: Epic 5 - Locked Necromancer and Shadeblade presentation belongs to hero select.

FR44: Epic 5 - Starting class and equipment passives belong to starting kits.

FR45: Epic 5 - No level-1 active class skills is a class-scope constraint.

FR46: Epic 6 - MVP passive pool belongs to loot and passive progression.

FR47: Epic 6 - Passive reward modal content belongs to Consume/Destroy.

FR48: Epic 6 - Consume power and build identity belongs to passive choices.

FR49: Epic 6 - Destroy as meaningful alternative belongs to passive choices.

FR50: Epic 6 - Destroy outcome distribution belongs to passive choice resolution.

FR51: Epic 6 - Small inventory belongs to loot and item handling.

FR52: Epic 6 - Loot categories belong to item and reward systems.

FR53: Epic 6 - Consumable scarcity and value belong to loot balance.

FR54: Epic 7 - Gold, healing, curses/corruption, Oath Shards, passives, and loot form the risk economy.

FR55: Epic 7 - Clear cursed/corrupted reward tradeoffs belong to risk UX.

FR56: Epic 7 - Scorched, Flooded/Conductive, Cursed, and Darkness belong to affinities.

FR57: Epic 7 - Tactical affinity effects belong to risk and affinity pressure.

FR58: Epic 7 - Darkness fairness guardrails belong to affinity design.

FR59: Epic 8 - Oath Shards, Echoes, Seal Fragments, mastery, unlocks, and meta menus belong to outpost progression.

FR60: Epic 8 - Run summary belongs to the return loop.

FR61: Epic 8 - First-death line belongs to death and outpost return.

FR62: Epic 9 - First-victory reveal belongs to the Larval Avatar finale.

FR63: Epic 9 - Larval Avatar as only required MVP boss belongs to finale scope.

FR64: Epic 8 - Optional story discovery belongs to outpost/meta/narrative return loop.

FR65: Epic 8 - Skippable narrative/control-loss moments are enforced in narrative-return flows.

FR66: Epic 2 - Phone, tablet, and desktop layout support belongs to mobile UX.

FR67: Epic 2 - Zoom and inspect across devices belong to tactical UX.

FR68: Epic 2 - Core UI flows are established through mobile UX foundation, then expanded by later epics.

FR69: Epic 1 - Combat log or equivalent damage explanation belongs to tactical combat clarity.

FR70: Epic 10 - Playable-build preservation is validated across MVP readiness gates.

### 2026-06-04 Readiness Backlog Patch Traceability

This supplemental map preserves the existing 70-item implementation FR inventory while tracing targeted backlog patches from `implementation-readiness-report-2026-06-04.md` to the amended stories.

- GDD FR46: door sealing/containment-law feedback -> Story 4.4 and Story 10.7.
- GDD FR47 and NFR5: early/mid/late/finale pacing and run-length targets -> Story 4.6 and Story 10.4.
- GDD FR48 and NFR42: early-mid build-defining passive -> Story 6.7 and Story 10.4.
- GDD FR63: named outpost/meta spaces -> Story 8.6.
- GDD FR71: 3-choice passive moments -> Story 6.3.
- GDD FR73: semi-rare, worth-using consumables -> Story 6.7 and Story 10.4.
- GDD FR75 and FR76: item character-level requirements and item roll model -> Story 6.1.
- GDD FR77: passive pillar validation -> Story 6.4.
- GDD FR82: Destroy outcome 70/20/10 distribution -> Story 6.6.
- GDD FR90, FR91, and FR93: no selectable difficulty tiers and post-MVP challenge guardrails -> Story 2.9 and Story 10.6.
- GDD FR95 and implementation FR67: capped, sparse meta power -> Story 8.3.
- GDD FR112, FR113, and FR114: MVP visual/audio baseline and preview/commit cue mapping -> Story 10.7.
- Placeholder replacement/de-scope checkpoints from the readiness report -> Stories 4.5, 7.5, 8.2, and 10.7.

### 2026-07-04 Sprint Change Traceability (Epic 11 insertion)

Per `sprint-change-proposal-2026-07-04.md` (trigger: `epic-9-retro-2026-07-04.md` §10): Epic 11 (Live Run Flow, HUD, and Outpost) added and sequenced between Epic 9 and Epic 10's Stories 10.4-10.7. It consolidates the deferred live layer recorded across Epics 7-9: live run combat + hero-death source (FR32 loss half) -> Story 11.2; run-flow scenes/HUD -> Story 11.3; live affinity call sites + HUD/VFX -> Story 11.4; outpost scene + reveal renders (FR61/FR62) + summary coupling -> Story 11.5; meta spend/application (FR59) -> Story 11.6; the pre-scene-work UX appendix (also 10.7 AC5's input) -> Story 11.1. Epic numbering of existing epics is unchanged by design (live cross-references preserved).

## Epic List

### Epic 1: Core Tactical Combat Slice

Players can launch a small tactical test level, move, see line of sight and fog, use weapon-shaped attacks, resolve enemy turns, take damage, win or die, and understand why combat outcomes occurred.

**FRs covered:** FR2, FR3, FR4, FR5, FR6, FR7, FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22, FR23, FR24, FR25, FR69.

**Implementation notes:** This epic carries the first vertical slice foundation: scene-independent domain model, `ActionResult`, deterministic `DomainEvent` records, named RNG streams needed by combat, tactical board model, fog/line-of-sight queries, command tests, board tests, and enemy behavior tests. It remains user-value oriented because the deliverable is a playable tactical combat slice, not standalone infrastructure.

### Epic 2: Mobile UX, Accessibility, and Save/Resume Foundation

Players can use the tactical slice safely on phone, tablet, and desktop-style layouts with preview, inspect, two-step commit, readable tactical information, and interruption-friendly save/resume.

**FRs covered:** FR8, FR9, FR10, FR11, FR12, FR13, FR40, FR41, FR66, FR67, FR68.

**Implementation notes:** UI must observe domain state through view models and submit commands through a command bridge. Save/resume must persist domain snapshots, not scene nodes.

### Epic 3: Procedural Level Generation v0

Players can load multiple seed-stable Small and Medium tactical levels that have readable spaces, clear entrances and exits, blockers, tactical wrinkles, legal placements, and validation against unfair or soft-locked layouts.

**FRs covered:** FR27, FR29, FR35, FR36, FR37, FR38, FR39.

**Implementation notes:** Generation uses named RNG streams, explicit phases, validation reports, and seed regression tests.

### Epic 4: Run Map and Forward Progression

Players can move from isolated levels into a forward-only 8-12 node descent, choose routes, enter node types, exit forward, and reach a boss placeholder or run end.

**FRs covered:** FR1, FR26, FR33, FR34.

**Implementation notes:** This epic converts tactical and generated-level capability into a roguelite route shell without yet requiring full classes, loot, meta progression, or final boss content.

### Epic 5: Classes and Starting Kits

Players can choose Warrior, Pyromancer, or Ranger, see future locked classes, and begin a run with class-specific passive/build nudges.

**FRs covered:** FR42, FR43, FR44, FR45.

**Implementation notes:** Class content should be data-driven and routed through repositories. Starting passives must use the rules kernel rather than ad hoc class logic.

### Epic 6: Loot, Passives, and Consume/Destroy

Players can shape a run through loot, passive rewards, a small inventory, consumables, and meaningful Consume/Destroy choices.

**FRs covered:** FR46, FR47, FR48, FR49, FR50, FR51, FR52, FR53.

**Implementation notes:** Passive effects and reward outcomes use the rules kernel with explicit trigger windows, stable ordering, conflict handling, and explanation output.

### Epic 7: Risk Economy and Affinities

Players encounter readable temptation through gold, scarce healing, curses/corruption, risky rewards, and tactical affinity pressure from Scorched, Flooded/Conductive, Cursed, and Darkness.

**FRs covered:** FR54, FR55, FR56, FR57, FR58.

**Implementation notes:** Risk and affinity effects must be explicit enough for player understanding and deterministic enough for replay and save/resume.

### Epic 8: Outpost, Meta Progression, and Run Summary

Players can die or finish a run, return to the last outpost, review what happened, receive eligible progress, see manual-seed warnings, unlock or advance something, and start another descent.

**FRs covered:** FR28, FR32, FR59, FR60, FR61, FR64, FR65.

**Implementation notes:** Manual seed eligibility, Oath Shards, Echoes, Seal Fragments, unlock progress, and narrative flags must live in versioned domain/profile snapshots.

### Epic 9: Larval Avatar MVP Finale

Players can reach and defeat the Larval Avatar, see the first-victory reveal, and return to the open-ended roguelite loop.

**FRs covered:** FR31, FR62, FR63.

**Implementation notes:** The boss should build on existing tactical, rules, AI, generation, save, and summary systems rather than introducing a separate bespoke combat path.

### Epic 10: Playtest Tuning and MVP Readiness

Players receive a stable MVP experience validated against performance, readability, save/resume reliability, generator safety, run length, comprehension, and replay-intent signals.

**FRs covered:** FR30, FR70.

**Implementation notes:** This epic validates cross-cutting NFRs, device tiers, debug tooling, headless seed runs, and milestone gates while preserving a playable build.

### Epic 11: Live Run Flow, HUD, and Outpost

Players can play the full descent hands-on — launch, choose a class, fight generated levels and the Larval Avatar on the live tactical board, win or die for real, see the reveal lines and run summary, spend meta progress at the outpost, and start another descent.

**FRs covered:** live/on-screen delivery of FR1, FR31, FR32 (live loss trigger), FR54-FR58 (felt affinity/risk pressure), FR59 (meta spend/application), FR60, FR61, FR62 (summary and reveal renders), FR64, FR65, and the FR68 flow expansion (run map, outpost/meta menu, run summary). Domain logic for these shipped in Epics 1-9; this epic wires live call sites, scenes, and HUD. Primary FR-to-epic assignments in the FR Coverage Map are unchanged.

**Implementation notes:** Added 2026-07-04 via sprint change proposal (see `sprint-change-proposal-2026-07-04.md`) to consolidate the deliberately deferred live layer from Epics 7-9. **Sequencing: executes between Epic 9 and Epic 10's Stories 10.4-10.7** (10.1-10.3 are independent). UI observes view models through the command bridge and owns no tactical truth; scenes live under `godot/scenes/ui/` and `godot/scenes/game/`. The live wiring must preserve interrupted==uninterrupted determinism, the 23-key `RunSnapshot` gate, `ProfileSnapshot.SCHEMA_VERSION == 1`, the 7 named RNG streams, and every pinned fingerprint. Consumes (does not rebuild): the Epic-2 tactical presentation contracts, 7.4/7.5 affinity effects, 8.5/9.4 narrative beat DTOs, 8.6 `OutpostViewModel`, 9.3 `BossTurnResolver` live loop, 9.5 `resolve_boss_victory()`.

## Epic 1: Core Tactical Combat Slice

Players can launch a small tactical test level, move, see line of sight and fog, use weapon-shaped attacks, resolve enemy turns, take damage, win or die, and understand why combat outcomes occurred.

### Story 1.1: Production Godot Project and Headless Test Harness

As a developer,
I want a production Godot project with domain-first folders and a headless test harness,
So that the tactical slice can be implemented and verified without scene-owned gameplay state.

**Acceptance Criteria:**

**Given** the Sealsworn repository has no required dependency on the React/Vite prototype
**When** the production project is initialized
**Then** a Godot 4.6.3 standard GDScript project exists under `godot/`
**And** production code does not import or depend on `prototype/`.

**Given** the architecture-defined folder rules
**When** the project structure is created
**Then** folders exist for `godot/scripts/core`, `godot/scripts/tactical`, `godot/scripts/rules`, `godot/scripts/generation`, `godot/scripts/ai`, `godot/scripts/content`, `godot/scripts/save`, `godot/scripts/ui`, and `godot/tests`
**And** folder and file naming follows `snake_case`.

**Given** tactical truth must be scene-independent
**When** the first test suite is run headlessly
**Then** at least one passing test executes without rendering, audio, UI scenes, or presentation nodes
**And** the test demonstrates that domain scripts can be loaded independently of gameplay scenes.

**Given** every future command needs valid and invalid/no-mutation tests
**When** the test harness is documented or scripted
**Then** it provides a repeatable command for running relevant Godot tests
**And** the command is recorded in story notes or project documentation.

**Given** native mobile packaging must remain viable from the first production setup
**When** Story 1.1 is completed
**Then** `project.godot` exists or is explicitly created as part of the setup work, and an initial local build/export plan covers Windows desktop and Android
**And** iOS export requirements are recorded as deferred until macOS/Xcode access is available.

**Given** export presets depend on local Godot export templates and platform SDKs
**When** the project setup is committed
**Then** `export_presets.cfg` is either present with non-secret Windows/Android preset scaffolding or a tracked setup note documents the exact prerequisites and next action needed to create it
**And** no cloud service, account, telemetry, or prototype dependency is introduced by build setup.

**Implementation Task Checklist:**

- [ ] 1.1.1 Create or verify `godot/project.godot` for Godot 4.6.3 standard GDScript.
- [ ] 1.1.2 Create architecture folders and one headless smoke test that loads a domain script.
- [ ] 1.1.3 Record the local headless test command and Windows dev-run command.
- [ ] 1.1.4 Add Android export preset scaffolding or a tracked export-preset setup note with Android Studio, SDK, and JDK prerequisites.
- [ ] 1.1.5 Record iOS export as deferred until macOS/Xcode setup, without blocking Epic 1 domain implementation.

### Story 1.2: Tactical Domain State and Board Model

As a player,
I want tactical positions, cells, occupants, and combat state to be represented consistently,
So that every move, attack, and enemy response happens on a reliable board.

**Acceptance Criteria:**

**Given** a new fixed tactical test level is created in domain state
**When** the board is initialized
**Then** it contains a bounded grid, terrain cells, a player entity, and optional enemy entities
**And** the model is stored in scene-independent typed GDScript classes.

**Given** an entity is placed on the board
**When** occupancy is queried for its cell
**Then** the board returns the occupying entity id
**And** no two blocking entities can occupy the same cell.

**Given** a cell is outside the board or blocked by terrain
**When** movement or placement validation queries that cell
**Then** the board reports it as invalid for occupancy
**And** no domain state is mutated by the query.

**Given** the board model is used by tests
**When** headless tests exercise initialization, occupancy, and blocked-cell rules
**Then** all cases pass without requiring a scene tree.

**Given** later visibility and save systems will depend on tactical state
**When** the board model is defined
**Then** it exposes stable fields or interfaces for visibility state, explored memory state, entity snapshots, terrain snapshots, and board dimensions
**And** those fields are domain data rather than presentation state.

**Given** reusable board fixtures are created
**When** tests load fixture boards
**Then** fixtures cover at least `1x1`, edge/corner movement, blocked cell, occupied cell, disconnected cells, line-of-sight blockers, and deterministic actor placement
**And** those fixtures can be reused by movement, visibility, targeting, and enemy tests.

**Given** board operations are queries or primitive state helpers
**When** movement, attack, enemy, or reward gameplay changes are needed
**Then** they are not performed directly by the board model
**And** future mutations must happen through validated commands and applied domain events.

### Story 1.3: ActionResult and Domain Event Foundation

As a developer,
I want commands to return structured results and deterministic domain events,
So that gameplay outcomes can drive tests, logs, saves, replay, and presentation without hidden side effects.

**Acceptance Criteria:**

**Given** a command succeeds
**When** it executes against valid domain state
**Then** it returns an `ActionResult` marked successful
**And** the result includes an ordered list of past-tense `DomainEvent` records.

**Given** a command is invalid
**When** it fails validation
**Then** it returns an `ActionResult` with a stable error code and no events
**And** the target domain state remains unchanged by snapshot or state-hash comparison.

**Given** an `ActionResult` contains a success or failure reason
**When** tests inspect it
**Then** the reason is machine-testable and stable
**And** player-facing display text can be derived separately without changing command contracts.

**Given** a domain event is emitted
**When** it is serialized for tests or logs
**Then** it includes deterministic fields needed to understand what happened
**And** event names use past-tense naming such as `EntityMovedEvent` or `DamageAppliedEvent`.

**Given** events are applied to domain state
**When** a test replays the same ordered events from the same initial state
**Then** the resulting state matches the original command result.

### Story 1.4: Named RNG Streams for Deterministic Gameplay

As a developer,
I want named RNG streams derived from a root seed,
So that gameplay-affecting randomness remains reproducible and isolated by system.

**Acceptance Criteria:**

**Given** a root seed is provided
**When** the RNG service is initialized
**Then** it creates named streams for `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic`
**And** each gameplay stream produces deterministic values for the same root seed.

**Given** a combat roll uses the `combat` stream
**When** unrelated `cosmetic` rolls are made before the combat roll
**Then** the combat roll result is unchanged
**And** gameplay outcome determinism is preserved.

**Given** an RNG stream advances
**When** its state is snapshotted and restored
**Then** subsequent rolls match the original stream sequence
**And** tests verify at least one stream restoration case.

**Given** gameplay code requests randomness
**When** the requested stream name is missing or invalid
**Then** the RNG service returns a deterministic error path
**And** no fallback global randomness is used for gameplay outcomes.

**Given** a gameplay-affecting RNG draw occurs
**When** the draw result affects combat, rewards, generation, events, or progression
**Then** the stream name, stream state or draw index, and consumer context are available for diagnostics or replay tests
**And** draw auditability does not require presentation state.

**Given** the same root seed, same initial snapshot, and same command sequence are used
**When** the sequence is executed twice
**Then** final domain snapshots, ordered domain events, and gameplay RNG stream states match exactly
**And** cosmetic stream draws do not change that equality.

### Story 1.5: Tactical Snapshot Serialization Boundary

As a developer,
I want the tactical domain state to round-trip through a lightweight snapshot,
So that deterministic combat, save/resume, and replay requirements are protected before UI save flows exist.

**Acceptance Criteria:**

**Given** a tactical domain state contains board dimensions, terrain, visibility fields, entities, HP, turn state, pending telegraphs, and named RNG stream states
**When** a tactical snapshot is exported
**Then** the snapshot contains only serializable domain data
**And** no scene nodes, UI controls, audio, animation, or presentation references are included.

**Given** a tactical snapshot is imported into a fresh domain state
**When** the same command is executed from both original and restored state
**Then** the resulting domain snapshots, ordered events, and gameplay RNG stream states match
**And** the test runs headlessly.

**Given** an invalid, missing-version, or incompatible tactical snapshot is loaded
**When** snapshot validation runs
**Then** it returns a structured load error
**And** no partial tactical state becomes active.

**Given** invalid command tests need no-mutation assertions
**When** a command fails validation
**Then** tests can compare pre-command and post-command tactical snapshots
**And** failed commands emit zero past-tense domain events.

### Story 1.6: MoveCommand with Movement Validation

As a player,
I want to move up to the baseline movement budget through valid cells,
So that tactical positioning is clear, deliberate, and reproducible.

**Acceptance Criteria:**

**Given** the player has the baseline 3-tile movement budget
**When** `MoveCommand` targets a reachable valid cell within 3 tiles
**Then** the command succeeds and emits an `EntityMovedEvent`
**And** the player occupant moves to the target cell.

**Given** a target cell is blocked, occupied by a blocking entity, outside the board, beyond movement budget, selected by an invalid actor id, or requested in the wrong turn phase
**When** `MoveCommand` executes
**Then** the command returns an invalid movement error
**And** player position, turn state, board occupancy, tactical snapshot, RNG state, and event log remain unchanged.

**Given** a successful player move is committed
**When** the command result is returned
**Then** it indicates that enemy and level systems should advance
**And** the result is suitable for turn-flow handling in a later enemy-resolution story.

**Given** movement validation rejects a target
**When** the result is presented through debug or UI-facing data
**Then** it can distinguish blocked, occupied, out-of-bounds, beyond-budget, invalid-actor, wrong-phase, and unseen-or-unreachable reasons
**And** the reason comes from domain validation rather than UI-only logic.

**Given** movement tests run headlessly
**When** valid movement and each invalid/no-mutation case are tested
**Then** every movement command test passes without presentation dependencies.

### Story 1.7: Fog, Line of Sight, and Explored Memory

As a player,
I want visibility to distinguish unseen space, explored memory, and currently visible tiles,
So that partial information creates fair tactical tension.

**Acceptance Criteria:**

**Given** the baseline line-of-sight radius is 4 tiles
**When** visibility is calculated from the player cell
**Then** visible cells within radius and unobstructed line rules are marked currently visible
**And** cells outside current line of sight are not treated as current tactical truth.

**Given** the player moves to a new cell
**When** visibility is recalculated
**Then** newly seen cells become explored
**And** previously explored but currently unseen cells remain marked as explored memory.

**Given** an unexplored tile contains hidden information
**When** a tactical query asks for player-visible facts
**Then** hidden information is not exposed
**And** explored memory exposes only last-known non-authoritative display data.

**Given** fog and line-of-sight tests run headlessly
**When** blockers, radius limits, and movement updates are tested
**Then** the visibility model passes without requiring fog scenes or rendering.

**Given** line-of-sight golden fixtures are loaded
**When** visibility is calculated around corners, blocker tiles, diagonal paths, and edge cells
**Then** each fixture produces the expected visible, explored-memory, and hidden-cell sets
**And** fixture failures identify the board, actor cell, blocker rule, and unexpected cells.

**Given** an enemy or target is hidden by fog
**When** movement, targeting, or attack preview queries player-visible facts
**Then** the target is treated as unavailable or stale according to visibility rules
**And** command validation can reject hidden targets with the same reason shown by preview.

### Story 1.8: Weapon Definitions and Attack Preview Rules

As a player,
I want weapon-shaped attacks to preview legal targets, expected damage, blockers, and warnings,
So that I can choose attacks deliberately before committing.

**Acceptance Criteria:**

**Given** baseline weapon definitions exist for Sword, Dagger, Spear, Axe, Mace, Bow, Crossbow, Staff, and Wand
**When** the content repository or test fixture loads them
**Then** each weapon exposes range, damage, targeting shape, and tactical identity fields
**And** the definitions are accessible without direct gameplay file access.

**Given** a weapon generally requires straight-line alignment
**When** attack preview checks a diagonal or blocked target without an override
**Then** the preview reports the target as illegal
**And** it includes a stable reason such as `not_aligned` or `blocked_line`.

**Given** a weapon has an explicit override such as Wand ignoring blockers
**When** attack preview evaluates the target
**Then** the preview applies the override deterministically
**And** the preview explains the override in debug/player-readable terms.

**Given** ranged weapons have adjacency penalties where specified
**When** the preview targets an adjacent enemy with Bow or Staff
**Then** expected damage and warning text reflect the penalty
**And** the preview does not mutate tactical state.

**Given** any attack preview is requested
**When** the preview is calculated
**Then** it emits no domain events, consumes no gameplay RNG draws, and does not mutate tactical state
**And** repeated previews from the same snapshot return the same result.

**Given** attack preview and `AttackCommand` are evaluated from the same unchanged snapshot
**When** a legal preview is committed
**Then** command legality, target, expected base damage, blocker result, and warning reasons match the preview
**And** illegal previews fail for the same stable reason as command validation.

**Implementation Task Checklist:**

- [ ] 1.8.1 Define baseline weapon content schema and repository lookup for Sword, Dagger, Spear, Axe, Mace, Bow, Crossbow, Staff, and Wand.
- [ ] 1.8.2 Implement pure attack preview queries for range, targeting shape, blockers, visibility, and warnings.
- [ ] 1.8.3 Add fixture cases for line, adjacent, ranged, blocked, override, hidden-target, and adjacency-penalty previews.
- [ ] 1.8.4 Contract-test preview output against later `AttackCommand` validation reasons without consuming gameplay RNG.

### Story 1.9: AttackCommand with Damage Events

As a player,
I want committed attacks to apply deterministic damage through validated commands,
So that combat outcomes are fair, testable, and explainable.

**Acceptance Criteria:**

**Given** an attack preview reports a legal target
**When** `AttackCommand` is executed for that actor and target
**Then** the command succeeds and emits deterministic attack and damage events
**And** the target HP is reduced according to the weapon definition and applicable rules.

**Given** an attack target is out of range, blocked, not aligned, not visible when visibility is required, missing, dead, selected by an invalid actor id, or requested in the wrong turn phase
**When** `AttackCommand` executes
**Then** it returns a stable error code
**And** actor state, target state, tactical snapshot, RNG state, event log, and turn state remain unchanged.

**Given** Axe, Mace, Crossbow, Tome, or Shield support rules are in baseline scope
**When** their simple prototype effects apply
**Then** the resulting events describe bleed, disorient, knockback, bonus damage, armor, or block outcomes as applicable
**And** any gameplay-affecting proc uses the `combat` RNG stream.

**Given** attack command tests run headlessly
**When** valid attacks and invalid/no-mutation cases are tested for baseline weapon shapes
**Then** all tests pass without UI or animation dependencies.

**Given** attack preview and attack execution are contract-tested
**When** fixture cases cover legal, illegal, blocked, adjacent-penalty, override, and hidden-target attacks
**Then** preview reasons and command validation reasons match for every fixture
**And** any expected damage variance is controlled through the `combat` RNG stream.

**Implementation Task Checklist:**

- [ ] 1.9.1 Implement `AttackCommand` validation for actor, target, turn phase, visibility, range, line/blocker, and alive-state cases.
- [ ] 1.9.2 Apply deterministic damage through domain events only after validation succeeds.
- [ ] 1.9.3 Add no-mutation tests covering tactical snapshot, event log, turn state, and RNG state for every invalid branch.
- [ ] 1.9.4 Add proc/effect fixtures for baseline weapon support rules and verify `combat` RNG stream use.

### Story 1.10: Enemy Turn Resolution for Prototype Enemies

As a player,
I want enemies to respond after committed actions with readable prototype behaviors,
So that the tactical slice proves melee pressure, body blocking, and telegraphed danger.

**Acceptance Criteria:**

**Given** the player commits a successful move or attack
**When** enemy turn resolution begins
**Then** each active enemy receives a valid deterministic action opportunity
**And** enemy turns do not resolve after invalid player commands.

**Given** an enemy chooses a move, attack, mark, wait, or detonation action
**When** that action is applied
**Then** it is submitted through the same validated domain command path or a narrow enemy command adapter
**And** enemy logic does not mutate tactical state directly.

**Given** an Iron Cultist can reach or approach the player
**When** its turn resolves
**Then** it advances toward the player or attacks if adjacent
**And** adjacent attacks emit damage events explaining physical damage.

**Given** a Gate Brute occupies the board
**When** its turn resolves
**Then** it uses the same prototype melee behavior with heavier body-blocking presence
**And** occupancy rules prevent it from overlapping other blocking entities.

**Given** an Ash Seer has line of sight within range 5
**When** its turn resolves
**Then** it marks the player's tile before detonating on a later enemy turn if the player remains there
**And** mark and detonation events are logged in readable form.

**Given** enemy AI decisions are tested
**When** the same seed and board state are used
**Then** chosen actions, scores or reasons, and resulting events are reproducible.

**Given** enemy action explanations are produced
**When** the player or debug log inspects the turn
**Then** it can identify whether the enemy moved toward the player, attacked a visible target, marked a tile, detonated a mark, held position, or was blocked
**And** the same board plus same seed produces the same action, events, and explanation payload.

**Implementation Task Checklist:**

- [ ] 1.10.1 Build enemy action opportunity and turn sequencing after successful player commands only.
- [ ] 1.10.2 Implement Iron Cultist and Gate Brute melee decisions through command or adapter paths.
- [ ] 1.10.3 Implement Ash Seer mark and delayed detonation events with readable explanation payloads.
- [ ] 1.10.4 Add deterministic AI decision fixtures for movement, attack, mark, wait, blocked, and detonation cases.

### Story 1.11: Combat Outcome, Death/Victory, and Explanation Log

As a player,
I want the tactical slice to report death, victory, and why key combat outcomes happened,
So that I can understand the result of a small test level.

**Acceptance Criteria:**

**Given** all enemies in the fixed test level are defeated
**When** combat outcome is evaluated
**Then** the level enters a simple victory state
**And** a deterministic victory event is emitted.

**Given** the player's HP reaches zero or below
**When** combat outcome is evaluated
**Then** the level enters a defeat state
**And** a deterministic death or defeat event records the cause.

**Given** movement, attack, enemy actions, damage, marks, and outcomes occur
**When** the combat explanation log is queried
**Then** it returns ordered entries that explain what happened in player/debug-readable terms
**And** entries can be derived from domain events rather than presentation-only state.

**Given** the Epic 1 playable micro-combat scenario is launched
**When** a tester plays it
**Then** it includes one player, 2-3 prototype enemies, obstacles, fog reveal, at least two weapon attack shapes, and win/loss states
**And** the tester can explain why they won or lost without reading debug-only output.

**Given** the micro-combat scenario is evaluated for player feel
**When** the tester completes or loses the encounter
**Then** it demonstrates deliberate turns, at least one meaningful position/line-of-sight choice, distinct weapon-shape behavior, and at least one tactical risk such as stepping toward fog for a better attack position
**And** findings are recorded as local playtest notes before Epic 2 begins.

**Given** the Epic 1 headless test suite runs
**When** board, snapshot, movement, visibility, preview, attack, enemy, RNG, event-log, and outcome tests execute
**Then** all Epic 1 tests pass
**And** no test depends on rendering, audio, UI scenes, or scene-tree-only state.

**Given** lightweight development instrumentation is enabled
**When** the micro-combat scenario runs
**Then** it can record local timings for board queries, line-of-sight updates, command execution, and enemy turns
**And** the instrumentation is build-profile gated and does not introduce telemetry dependencies.

## Epic 2: Mobile UX, Accessibility, and Save/Resume Foundation

Players can use the tactical slice safely on phone, tablet, and desktop-style layouts with preview, inspect, two-step commit, readable tactical information, and interruption-friendly save/resume.

### Story 2.1: Tactical View Models and Command Bridge

As a player,
I want UI interactions to reflect tactical state without directly changing it,
So that previews and commands remain reliable across phone, tablet, and desktop layouts.

**Acceptance Criteria:**

**Given** the tactical domain state from Epic 1 exists
**When** a board view model is built
**Then** it exposes read-only cell, occupant, visibility, selected entity, preview, and action availability data
**And** it does not expose mutable domain internals to UI presenters.

**Given** a player selects a move or attack from UI
**When** the command bridge converts that intent
**Then** it creates a typed domain command
**And** only the command execution path can mutate tactical state.

**Given** the command bridge receives an invalid UI intent
**When** it attempts conversion
**Then** it returns a stable error or disabled action state
**And** no domain command is executed.

### Story 2.2: Movement and Attack Preview Presentation Contracts

As a player,
I want movement and attack previews to show valid options, warnings, and expected outcomes,
So that I can decide before spending a turn.

**Acceptance Criteria:**

**Given** a visible reachable tile is selected
**When** movement preview is requested
**Then** the view model reports path, cost, target validity, and commit availability
**And** the preview does not mutate turn or board state.

**Given** a visible enemy is selected
**When** attack preview is requested
**Then** the view model reports weapon reach, line or path, expected damage, effects, blocker state, and warnings
**And** warnings include adjacency penalties where applicable.

**Given** an invalid target is selected
**When** preview is requested
**Then** the preview reports a clear invalid reason
**And** the commit action remains unavailable.

### Story 2.3: Mobile Two-Step Commit and Cancel Flow

As a mobile player,
I want attacks to require deliberate confirmation by default,
So that mis-taps do not accidentally advance enemies and level systems.

**Acceptance Criteria:**

**Given** the player taps a visible enemy for the first time
**When** attack preview is available
**Then** the UI enters attack preview mode
**And** no attack command is submitted yet.

**Given** the same target is tapped again or a clear confirm action is pressed
**When** the preview remains valid
**Then** an `AttackCommand` is submitted through the command bridge
**And** enemy and level systems advance only after command success.

**Given** the player taps a different tile, presses cancel, or the target becomes invalid
**When** the preview mode is cleared
**Then** no attack command is submitted
**And** tactical state remains unchanged.

### Story 2.4: Inspect and Zoom Tactical Information

As a player,
I want to zoom and inspect cells, occupants, hazards, and telegraphs,
So that tactical information stays readable on every supported device.

**Acceptance Criteria:**

**Given** the player tap-holds or uses inspect input on a visible or explored cell
**When** inspect data is requested
**Then** the UI shows available tile, terrain, occupant, move cost, attack preview, hazard, and telegraphed danger information
**And** hidden unexplored facts remain hidden.

**Given** the board is displayed on phone, tablet, or desktop
**When** zoom controls are used
**Then** the board scales within defined minimum and maximum limits
**And** selection, preview, and inspect targets remain aligned with domain cells.

**Given** the player changes zoom during a preview
**When** the view refreshes
**Then** preview state remains coherent
**And** no command is committed by zooming.

### Story 2.5: Adaptive Layout Profiles

As a player,
I want tactical controls to adapt to portrait, landscape, tablet, and desktop layouts,
So that the same rules remain comfortable across target devices.

**Acceptance Criteria:**

**Given** a phone portrait viewport is active
**When** the tactical HUD is displayed
**Then** primary preview, confirm, cancel, inspect, and status controls are reachable and readable
**And** the board remains the first visual priority.

**Given** phone landscape, tablet, or desktop-style viewport profiles are active
**When** layout recalculates
**Then** panels and controls reposition without changing tactical rules
**And** the same command bridge and view models are reused.

**Given** orientation or viewport size changes during play
**When** the layout profile changes
**Then** current selection and preview state persist
**And** no gameplay command is submitted by the layout change.

### Story 2.6: Accessibility and Tactical Readability Baseline

As a player,
I want critical tactical information to be readable without relying on color or small text,
So that combat decisions remain clear on phone-sized screens.

**Acceptance Criteria:**

**Given** danger, valid movement, attack range, blocked line, and telegraphed damage indicators are displayed
**When** color is removed or altered
**Then** shape, icon, label, pattern, or text still communicates the critical meaning
**And** no critical tactical information depends on color alone.

**Given** scalable text settings are changed within supported bounds
**When** tactical HUD, previews, and inspect panels render
**Then** essential labels remain readable and do not overlap controls
**And** no gameplay rule changes with text scale.

**Given** preview and commit feedback are displayed
**When** the player compares them
**Then** preview state and committed action state are visually and audibly distinguishable where audio is available
**And** the distinction is also available without audio.

### Story 2.7: Between-Level Save Snapshot Foundation

As a player,
I want the run to save between levels,
So that interruption-friendly sessions do not lose progress.

**Acceptance Criteria:**

**Given** a level is completed or exited to a between-level boundary
**When** autosave is requested
**Then** a versioned domain snapshot is written through `SaveRepository`
**And** no scene nodes are serialized as save truth.

**Given** a save snapshot is created
**When** its contents are inspected in tests
**Then** it includes schema version, content version, root seed, RNG stream states, route or current-node state where available, player state, inventory placeholder fields, and manual-seed eligibility
**And** unsupported future fields are absent or explicitly nullable.

**Given** tactical snapshot boundaries were established in Epic 1
**When** between-level save data is assembled
**Then** the save repository reuses or composes those domain snapshot structures
**And** save/resume does not invent a parallel scene-owned state format.

**Given** save writing fails
**When** the repository reports the error
**Then** the game receives a structured save result
**And** domain state is not corrupted by the failed write.

### Story 2.8: Resume Flow and Mid-Level Save Feasibility

As a player,
I want saved progress to resume reliably,
So that quitting between levels or during a feasibility-tested mid-level point is safe.

**Acceptance Criteria:**

**Given** a valid between-level save exists
**When** resume is selected
**Then** domain state is restored from the snapshot
**And** presentation rebuilds from restored state rather than saved scene nodes.

**Given** an incompatible or corrupted save is loaded
**When** the save repository validates it
**Then** the load fails with a structured error and recovery path
**And** no partial corrupt state becomes active.

**Given** mid-level save/resume is desirable but optional for MVP
**When** feasibility is evaluated against current domain snapshots
**Then** the story records whether mid-level save is implemented, deferred, or limited
**And** any implemented mid-level save path has at least one restore test for fog, entities, pending turn state, and RNG stream state.

**Given** resume tests compare interrupted and uninterrupted play
**When** a run is saved, restored, and then given the same command sequence
**Then** final domain snapshots, event logs, and gameplay RNG stream states match the uninterrupted path
**And** mismatches identify the first divergent event or stream.

### Story 2.9: Settings and Difficulty Non-Goal Guardrails

As a player,
I want basic settings for readability, input, and audio without hidden difficulty tiers,
So that I can adapt the interface while the MVP challenge remains authored through run systems.

**Acceptance Criteria:**

**Given** the settings model is initialized
**When** settings are loaded or changed
**Then** text scale, audio volume or mute, and input preference fields are represented as preferences separate from active run domain state
**And** settings can be saved and restored without mutating tactical truth, RNG state, rewards, or progression.

**Given** the settings screen or view model exposes gameplay-related options
**When** options are reviewed for MVP
**Then** no player-selectable difficulty tier, easy/normal/hard selector, or generic difficulty ladder is present
**And** difficulty remains sourced from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, and boss preparation.

**Given** post-MVP challenge content is discussed or configured
**When** challenge options are represented in content or UX notes
**Then** they are described as explicit variants, trials, oaths, or special runs
**And** they are not implemented as a generic selectable difficulty ladder.

**Given** settings are presented on mobile and desktop
**When** the user changes text, audio, or input preferences
**Then** the changes are visible or audible immediately where practical
**And** they remain optional presentation/preferences behavior, not an alternate ruleset.

**Readiness traceability:** Addresses readiness report GDD FR90, FR91, FR93, settings/accessibility gap, and no-difficulty-ladder acceptance criteria.

## Epic 3: Procedural Level Generation v0

Players can load multiple seed-stable Small and Medium tactical levels that have readable spaces, clear entrances and exits, blockers, tactical wrinkles, legal placements, and validation against unfair or soft-locked layouts.

### Story 3.1: Generation Requests, Results, and Level Recipes

As a player,
I want generated levels to come from explicit recipes and seeds,
So that each level can be reproduced, tested, and debugged.

**Acceptance Criteria:**

**Given** a generation request is created
**When** it is initialized
**Then** it includes root seed or level seed, node context, level size, difficulty band, affinity placeholder, and constraints
**And** it uses the named `level` RNG stream for layout-affecting randomness.

**Given** a level recipe is loaded
**When** generation begins
**Then** the recipe defines size class, terrain rules, blocker budget, enemy budget, reward placement rules, and tactical wrinkle requirements
**And** gameplay systems access it through repository or fixture boundaries.

**Given** a generator needs enemy, reward, affinity, or recipe definitions
**When** generation phases run
**Then** definitions are selected through approved repository/import boundaries
**And** the generator does not read arbitrary JSON or CSV files directly in the hot path.

**Given** generation succeeds or fails
**When** a result is returned
**Then** it uses a structured `GenerationResult`
**And** failures include phase, seed, reason, and compact diagnostics.

### Story 3.2: Seed-Stable Small Level Layouts

As a player,
I want Small levels to generate as readable tactical spaces,
So that early combat stays compact and fair.

**Acceptance Criteria:**

**Given** a Small level recipe around 8x8 tiles
**When** generation runs for a fixed seed
**Then** it produces the same entrance, exit, floor, wall, and blocker layout every time
**And** different seeds can produce meaningfully different layouts.

**Given** a generated Small level is converted to a level snapshot
**When** the snapshot is loaded into the tactical domain model
**Then** board bounds, blockers, entrance, and exit are represented correctly
**And** no scene nodes are required to understand the layout.

**Given** Small level seed regression tests are run
**When** approved fixture seeds generate levels
**Then** output remains stable or changes only with explicit fixture updates
**And** regressions include the failing seed in test output.

### Story 3.3: Seed-Stable Medium Level Layouts

As a player,
I want Medium levels to generate with more space while remaining readable,
So that mid-run tactical problems can grow without becoming unfair.

**Acceptance Criteria:**

**Given** a Medium level recipe around 14x12 tiles
**When** generation runs for a fixed seed
**Then** it produces a deterministic layout with entrance, exit, blockers, and enough open space for movement
**And** the layout supports line-of-sight play.

**Given** Medium levels are larger than Small levels
**When** validation checks readability constraints
**Then** it rejects layouts with excessive blockage, unreachable exits, or unreadable first reveal
**And** rejected results include compact diagnostics.

**Given** Medium level seed regression tests are run
**When** approved fixture seeds generate levels
**Then** output remains stable or changes only with explicit fixture updates
**And** the tests do not depend on rendering.

### Story 3.4: Tactical Wrinkles, Blockers, and Hazards

As a player,
I want generated combat levels to include at least one readable tactical wrinkle,
So that generated spaces create decisions rather than empty rooms.

**Acceptance Criteria:**

**Given** a combat level recipe requires a tactical wrinkle
**When** generation runs
**Then** it places at least one wrinkle such as hazard, door, choke point, flank route, blocker cluster, affinity placeholder, enemy formation, reward behind danger, or risky side branch
**And** the wrinkle type is recorded in generation diagnostics.

**Given** blockers or hazards are placed
**When** pathing validation runs
**Then** mandatory entrance-to-exit progress remains possible
**And** no required progress depends on a specific class, weapon, or item.

**Given** a hazard is included in a generated snapshot
**When** the tactical board loads the snapshot
**Then** the hazard is represented as domain data
**And** future presentation can mirror it without owning hazard truth.

### Story 3.5: Enemy and Reward Placement

As a player,
I want generated levels to place enemies and rewards legally,
So that each seed creates fair tactical pressure and reachable rewards.

**Acceptance Criteria:**

**Given** a generated level has legal floor cells
**When** enemy placement runs
**Then** enemies are placed on valid unoccupied cells according to recipe budgets
**And** no enemy starts on the entrance, exit, wall, blocker, or unreachable required cell.

**Given** intended rewards are placed
**When** reward reachability validation runs
**Then** reachable rewards pass and unreachable intended rewards fail validation
**And** optional risky rewards are marked as optional if placed behind danger.

**Given** enemy and reward placement uses randomness
**When** the same seed and recipe are used
**Then** placements are reproducible
**And** placement rolls use the assigned generation stream rather than global randomness.

**Given** enemy or reward placement applies a candidate to the level
**When** placement succeeds
**Then** it updates the generation candidate or final snapshot through generation phase outputs
**And** it does not bypass validation by mutating active tactical state directly.

### Story 3.6: Generator Validation and Bounded Retry

As a player,
I want generated levels to reject soft-locks and unfair starts,
So that seeded generation creates fair uncertainty rather than unavoidable punishment.

**Acceptance Criteria:**

**Given** generation produces a candidate level
**When** validation runs
**Then** it checks entrance-to-exit reachability, no soft-locks, legal enemy placement, reachable intended rewards, fog/readability constraints, and safe first reveal
**And** validation emits a pass/fail report.

**Given** validation fails and retries are allowed
**When** bounded retry runs
**Then** generation attempts a limited number of deterministic retries
**And** final failure returns a structured `GenerationResult` error with seed, phase, reason, and diagnostics.

**Given** validation tests run headlessly
**When** known bad fixture layouts are tested
**Then** each bad layout fails for the expected reason
**And** known good fixture layouts pass.

**Given** generation phase fixtures are tested
**When** route context, recipe selection, layout/pathing, blocker placement, enemy placement, reward placement, and final validation run
**Then** each phase has at least one focused regression assertion
**And** phase failures are reported separately from final-map fingerprint failures.

**Implementation Task Checklist:**

- [ ] 3.6.1 Implement reachability, no-soft-lock, no-required-class/item-gate, enemy placement, intended reward reachability, fog/readability, and safe-first-reveal validators as separate checks.
- [ ] 3.6.2 Implement bounded deterministic retry with seed, attempt, phase, reason, and compact diagnostic output.
- [ ] 3.6.3 Add bad-layout and good-layout fixtures for every validator category.
- [ ] 3.6.4 Add phase-level fixture assertions so recipe, layout/pathing, blockers, enemies, rewards, and final validation failures are diagnosable without rendering.

### Story 3.7: Manual Seed Level Loader and Regression Tests

As a player,
I want to enter or reuse seeds for replay, practice, sharing, and debugging,
So that generated levels can be reproduced without granting meta progression.

**Acceptance Criteria:**

**Given** a manual seed is entered for a level-generation test
**When** the level loads
**Then** the same seed and recipe produce the same generated level
**And** the generated level reports that the run is manual-seed ineligible for meta progression.

**Given** a seed is invalid or malformed
**When** the loader parses it
**Then** it returns a clear validation error
**And** no generation starts from ambiguous seed input.

**Given** seed regression tests are run
**When** approved seeds are generated in batch
**Then** their validation status and compact fingerprints are stable
**And** failures report seed, recipe, phase, and reason.

**Given** an internal tester loads generated Small and Medium levels from approved seeds
**When** they complete a short tactical pass
**Then** they record whether each level has at least one meaningful movement, line-of-sight, or risk-positioning decision
**And** bland or unfair seeds are preserved for tuning rather than silently discarded.

## Epic 4: Run Map and Forward Progression

Players can move from isolated levels into a forward-only 8-12 node descent, choose routes, enter node types, exit forward, and reach a boss placeholder or run end.

### Story 4.1: Run State and Route Node Model

As a player,
I want a run to track route position, current node, and forward progress,
So that individual levels become a coherent descent.

**Acceptance Criteria:**

**Given** a new run starts
**When** run state is initialized
**Then** it records root seed, manual-seed eligibility, current phase, current node pointer, cleared nodes, and available route choices
**And** the state exists independently of UI scenes.

**Given** route nodes are defined
**When** the route model is loaded
**Then** each node has id, type, depth, reveal state, outgoing links, and optional clue fields
**And** node ids are stable for save/resume and test references.

**Given** run state transitions are requested
**When** an invalid transition occurs
**Then** it returns a structured error
**And** route state remains unchanged.

### Story 4.2: Seeded 8-12 Node Route Generation

As a player,
I want each run to generate a reproducible forward route,
So that route choice creates fair commitment and replayable structure.

**Acceptance Criteria:**

**Given** a non-manual root seed
**When** route generation runs
**Then** it creates an 8-12 node route before the boss placeholder
**And** generation uses the named `map` RNG stream.

**Given** the same seed is used
**When** route generation runs again
**Then** node count, node ids, node types, links, and boss placeholder position match
**And** route fingerprints are stable in tests.

**Given** route generation creates branches
**When** validation runs
**Then** every visible choice leads forward
**And** no route edge allows backtracking to a cleared node.

**Given** route generation creates a player-facing choice
**When** available nodes are revealed
**Then** at least some choices expose tradeoff clues such as safer combat, stronger reward, unknown risk, recovery, elite pressure, or mystery
**And** route choice is not reduced to a purely decorative level-select list.

### Story 4.3: Route Choice and Forward Commitment

As a player,
I want to choose one available route node and commit forward,
So that the Labyrinth descent has irreversible tactical stakes.

**Acceptance Criteria:**

**Given** the player is at a route choice
**When** available nodes are queried
**Then** only legal forward nodes are selectable
**And** hidden or unreachable future nodes cannot be selected.

**Given** the player commits to a legal next node
**When** the route command executes
**Then** run state advances to that node and emits a route-advanced event
**And** previous nodes are marked unavailable for backtracking.

**Given** the player attempts to select a cleared, hidden, or non-linked node
**When** the route command executes
**Then** it returns a stable error
**And** route state remains unchanged.

### Story 4.4: Node Entry and Exit Resolution

As a player,
I want entering and exiting nodes to transition cleanly between route and level flow,
So that a run can progress through multiple encounters.

**Acceptance Criteria:**

**Given** a combat node is selected
**When** node entry resolves
**Then** the run creates or loads the corresponding level request
**And** level state becomes active for tactical play.

**Given** the active node is completed
**When** node exit resolves
**Then** the node is marked cleared, rewards placeholder state is recorded if applicable, and route choice state becomes active
**And** a between-level autosave can be requested.

**Given** node exit seals the completed path behind the player
**When** the exit transition resolves
**Then** a deterministic door-sealed or route-sealed domain event is emitted with a stable cue id such as `door_sealed_placeholder`
**And** future presentation/audio can mirror the containment-law feedback without owning route state.

**Given** node entry or exit is requested in the wrong run phase
**When** the command executes
**Then** it fails with a structured error
**And** run and level state remain unchanged.

### Story 4.5: MVP Node Types and Boss Placeholder

As a player,
I want the run map to include MVP node types even before every system is fully deep,
So that the route shell reflects the intended roguelite structure.

**Acceptance Criteria:**

**Given** route generation assigns node types
**When** an MVP route is created
**Then** it can include combat, elite combat, shop, reforge, gambling, risk/reward event, secret/lore, and boss placeholder nodes
**And** unsupported node implementations route to safe placeholder resolution rather than broken gameplay.

**Given** a placeholder non-combat node is entered
**When** it resolves
**Then** it communicates placeholder completion in domain/debug terms
**And** the player can continue forward without soft-locking the run.

**Given** the boss placeholder is reached
**When** it resolves before Epic 9 content exists
**Then** the run can end with a placeholder completion event
**And** future Larval Avatar implementation can replace the placeholder through the same node boundary.

**Given** placeholder node or boss behavior remains after the route shell is playable
**When** Epic 7, Epic 9, or Epic 10 readiness work begins
**Then** each placeholder is either replaced, explicitly de-scoped with an approved MVP limitation, or treated as blocking full MVP readiness
**And** placeholder ids and affected node types are listed in readiness notes.

### Story 4.6: Playable Run Shell from Start to End

As a player,
I want to start a run, clear nodes, and reach an endpoint,
So that the rough roguelite descent exists before classes, loot, and meta progression deepen it.

**Acceptance Criteria:**

**Given** the player starts a new MVP shell run
**When** the route and first node are generated
**Then** the player can enter at least one combat level from the route
**And** route state, level state, and RNG stream state are tracked together.

**Given** the player clears multiple nodes
**When** the run advances between nodes
**Then** cleared nodes, current node, available choices, and manual-seed eligibility persist in run state
**And** between-level save/resume can restore the route position.

**Given** the run reaches boss placeholder or shell end
**When** completion resolves
**Then** a deterministic run-ended event is emitted
**And** later meta progression can consume that event without changing earlier route logic.

**Given** an internal tester plays the route shell
**When** they choose across multiple route nodes
**Then** they record at least one moment where route information changed their decision
**And** missing tradeoffs are captured as route tuning notes before loot/meta systems deepen the run.

**Given** MVP run pacing is evaluated from the playable shell
**When** route length, node resolution time, reward cadence, and endpoint timing are measured
**Then** successful MVP runs target 20-35 minutes, failed runs commonly target 5-15 minutes, and 45 minutes is treated as an upper stretch for careful or completionist runs
**And** pacing failures produce tuning notes for node count, encounter length, reward frequency, or boss approach rather than untracked scope expansion.

## Epic 5: Classes and Starting Kits

Players can choose Warrior, Pyromancer, or Ranger, see future locked classes, and begin a run with class-specific passive/build nudges.

### Story 5.1: Class Definition Content and Repository

As a player,
I want each class to have clear starting identity data,
So that class selection can create different tactical openings.

**Acceptance Criteria:**

**Given** class definitions are authored for Warrior, Pyromancer, Ranger, Necromancer, and Shadeblade
**When** the content repository loads them
**Then** each definition exposes id, display name, lock state, unlock hint, starting equipment, class passive id, and equipment-synergy passive id
**And** gameplay systems do not read class files directly.

**Given** a class id is missing or invalid
**When** the repository is queried
**Then** it returns a structured lookup error
**And** no run starts from unknown class data.

**Given** class content validation runs
**When** definitions are checked
**Then** selectable classes require complete starting kit and passive references
**And** locked classes require a clear unlock hint.

### Story 5.2: Hero Select with Playable and Locked Classes

As a player,
I want to choose from MVP classes and see future locked classes,
So that I understand current options and future goals.

**Acceptance Criteria:**

**Given** the hero select flow opens
**When** class definitions are loaded
**Then** Warrior, Pyromancer, and Ranger are selectable
**And** Necromancer and Shadeblade are visible as locked, grayed-out future classes.

**Given** a locked class is selected or tapped
**When** the UI responds
**Then** it shows the unlock hint or requirement
**And** no run can start with the locked class.

**Given** a playable class is selected
**When** the player confirms
**Then** a new run request is created with that class id
**And** route/run startup receives class selection through domain state rather than UI-only state.

### Story 5.3: Starting Kit Application

As a player,
I want my selected class to begin with the correct starting equipment and baseline stats,
So that each run starts consistently from class identity.

**Acceptance Criteria:**

**Given** a run starts with Warrior, Pyromancer, or Ranger
**When** starting kit application runs
**Then** the hero receives the configured starting weapon, support item, baseline HP, class passive reference, and equipment-synergy passive reference
**And** the result is represented in domain state.

**Given** a starting kit references missing equipment or passive data
**When** validation runs
**Then** run start fails with a structured content error
**And** no partial run state becomes active.

**Given** class start tests run headlessly
**When** each playable class starts a run
**Then** starting equipment and passives match the class definition
**And** locked classes cannot start runs.

### Story 5.4: Starting Passive Rule Integration

As a player,
I want class passives to nudge builds without requiring active skills at level 1,
So that class identity appears early while MVP combat stays focused.

**Acceptance Criteria:**

**Given** a playable class starts a run
**When** its class passive and equipment-synergy passive are registered
**Then** they are available to the rules kernel through explicit trigger windows
**And** they do not bypass command/result/event flow.

**Given** a starting passive modifies movement, targeting, damage, healing, or preview output
**When** its trigger resolves
**Then** the outcome emits deterministic events or explanation entries as appropriate
**And** the passive effect is testable without UI scenes.

> **v0 scope clarification (Epic 5 as-built, re-synced from the Epic 5 retrospective 2026-06-26):** Epic 5 starting passives are **EXPLANATION-ONLY** — they register against explicit trigger windows and emit player-readable explanation entries; the felt per-effect *mutation* of movement/targeting/damage/healing/preview (the effect-operation + combat-hook side) is intentionally deferred to **Epic 6**. The "modifies ... output" wording above describes the eventual capability, not Epic 5's deliverable. The `scripts/rules/{conditions,operations}` kernel slots ship empty in Epic 5 and are filled in Epic 6.

**Given** level-1 class active skills are out of scope
**When** class definitions are validated
**Then** active skill fields are absent, empty, or disabled for MVP starting classes
**And** no class can start with an active skill at level 1.

### Story 5.5: Class Start Playable Smoke Slice

As a player,
I want each MVP class to start a tactical run and immediately feel a different nudge,
So that class choice matters before deeper talent systems exist.

**Acceptance Criteria:**

**Given** Warrior, Pyromancer, or Ranger is selected
**When** a run starts and enters the first tactical level
**Then** the hero has the correct starting kit and visible class identity data
**And** the level remains playable with movement, attack, enemy turns, and outcomes from earlier epics.

**Given** class-specific passive effects are active
**When** preview or combat events occur
**Then** relevant passive explanations appear in debug/player-readable output
**And** unrelated classes do not receive those effects.

**Given** class smoke tests run
**When** each playable class completes the first tactical test loop
**Then** the run remains deterministic under the same seed
**And** the build remains playable after the class story is complete.

> **Relocated to Epic 10 — Playtest Tuning (moved 2026-06-26):** the original human-felt acceptance check for this story — an internal tester playing Warrior/Pyromancer/Ranger and confirming each class changes at least one combat decision (i.e. is not a stat-only reskin) — was **moved to Story 10.4 (Gameplay Comprehension and Playtest Checklist)** so it runs during the dedicated MVP playtest phase rather than gating the Epic 5 smoke slice. Epic 5 proves the class start is *playable, deterministic, and surfaces class identity data + passive explanations*; the subjective "does class choice change a felt decision?" judgment belongs to the cross-class MVP playtest. The headless smoke ACs above remain Epic 5's bar.

## Epic 6: Loot, Passives, and Consume/Destroy

Players can shape a run through loot, passive rewards, a small inventory, consumables, and meaningful Consume/Destroy choices.

### Story 6.1: Item, Loot, and Reward Definitions

As a player,
I want loot and reward options to come from approved definitions,
So that runs can offer readable build choices without hardcoded item logic.

**Acceptance Criteria:**

**Given** MVP loot definitions are authored
**When** the content repository loads them
**Then** weapons, armor, jewelry, support items, consumables, pickups, passives, and gold reward definitions are available through typed lookups
**And** gameplay systems do not read source files directly.

**Given** a definition references a missing id, invalid value range, or unsupported category
**When** content validation runs
**Then** validation fails with a structured content error
**And** invalid content is not available to gameplay.

**Given** reward selection uses randomness
**When** reward offers are generated
**Then** rolls use the named `rewards` or `loot` stream as appropriate
**And** the same seed and state reproduce the same reward offer.

**Given** equippable item definitions are authored
**When** content validation runs
**Then** each item declares a character-level requirement or an explicit `none` requirement
**And** minimum run-depth requirements are not used as the item equip gate.

**Given** MVP item instances can vary
**When** item stat, affix, affinity, or enhancement data is defined
**Then** the data model uses roll ranges, affix/enhancement ids, and affinity tags rather than fixed item levels
**And** any advanced roll family not implemented for MVP is explicitly deferred while preserving the repository/data boundary for later rollout.

**Given** two content definitions are registered under the same id in ANY content repository (carried cross-cutting hardening item from Epic 5 — see `deferred-work.md`)
**When** the repository ingests them
**Then** registration fails loud with a structured `duplicate_*` error instead of silently last-write-wins (where the id list keeps the first and the lookup returns the second)
**And** the guard is applied uniformly, retrofitting the six existing repositories that currently accept duplicates (class, enemy, level-recipe, weapon, support, passive) as well as the new Epic 6 loot/reward repositories — done before/with the first new data-pipeline content so a duplicate id can never silently shadow another.

**Implementation Task Checklist:**

- [ ] 6.1.1 Define loot, reward, consumable, passive, gold, pickup, and equipment definition schemas.
- [ ] 6.1.2 Add repository lookup and validation errors for missing ids, unsupported categories, invalid ranges, and invalid character-level requirement fields.
- [ ] 6.1.3 Add item roll model data for ranges, affixes, affinities, and enhancements, or explicit MVP deferral markers for each advanced roll family.
- [ ] 6.1.4 Add deterministic reward offer fixtures that prove `rewards`/`loot` stream use and reproduce offers from the same seed and state.
- [ ] 6.1.5 Retrofit duplicate-id fail-loud rejection across ALL content repositories — the six existing ones (class, enemy, level-recipe, weapon, support, passive) plus the new Epic 6 loot/reward repositories — with negative tests; closes the cross-cutting duplicate-id hardening item carried from Epic 5 (`deferred-work.md`). Sequence this before/with the first new data-pipeline content so duplicates cannot silently shadow.

### Story 6.2: Small Inventory and Equipment Model

As a player,
I want a small inventory and equipped items to be tracked clearly,
So that loot choices remain tactical rather than a flood of comparisons.

**Acceptance Criteria:**

**Given** the hero has an MVP backpack
**When** inventory is initialized
**Then** it supports the configured small capacity, defaulting to 6 backpack items
**And** item stacking is disabled unless a specific item definition allows it later.

**Given** an item is picked up
**When** there is capacity
**Then** the inventory records the item instance or item id according to the domain model
**And** an item-gained event is emitted.

**Given** the backpack is full
**When** another backpack item is picked up
**Then** the command returns a stable inventory-full error or replacement choice state
**And** no existing item is silently deleted.

### Story 6.3: Reward Offer Flow

As a player,
I want rewards to appear as clear offers after eligible encounters or nodes,
So that each run can begin developing a build identity.

**Acceptance Criteria:**

**Given** a combat or reward node completes
**When** reward generation runs
**Then** it creates a deterministic reward offer from approved reward tables
**And** the offer is stored in domain state until resolved.

**Given** the player selects a reward
**When** the reward command executes
**Then** the selected reward is applied through domain events
**And** unselected rewards are discarded or marked resolved.

**Given** a reward offer is already resolved
**When** a duplicate selection command is submitted
**Then** it fails with a stable error
**And** inventory, currency, passive, and RNG state remain unchanged.

**Given** a passive reward table is configured for a 3-choice moment
**When** a passive offer is generated
**Then** the offer contains three distinct passive choices unless the table explicitly records an MVP test-scope exception
**And** exceptions are visible to content validation and tuning notes rather than silently reducing choice density.

### Story 6.4: Passive Reward Modal Data Contract

As a player,
I want passive choices to show exact mechanics and fiction flavor,
So that Consume and Destroy decisions are deliberate.

**Acceptance Criteria:**

**Given** a passive reward is offered
**When** the passive modal view model is built
**Then** it exposes icon id or placeholder, evocative name, one short flavor line, exact mechanical effects, Consume text, and Destroy text
**And** hidden consequences are labeled honestly when unknown.

**Given** the passive choice is presented on mobile
**When** the player taps Consume or Destroy
**Then** destructive or irreversible choices require clear confirmation or a two-step commit
**And** canceling confirmation leaves reward state unchanged.

**Given** a passive definition has missing mechanics, missing choice text, or unclear downside fields
**When** content validation runs
**Then** the passive fails validation
**And** it cannot be included in approved MVP reward tables.

**Given** passive definitions are validated for design purpose
**When** content validation runs
**Then** each passive declares at least one served pillar from tactical clarity, build synergy, risk, or mystery
**And** passives with no served pillar fail validation even if their mechanics are technically valid.

**Given** a passive modal is dismissed without choosing
**When** the reward remains unresolved
**Then** no Consume or Destroy command is executed
**And** the offer can be reopened from domain state.

### Story 6.5: Consume Passive Command

As a player,
I want to Consume a passive for power and build identity,
So that awakened memories can change how I solve fights.

**Acceptance Criteria:**

**Given** a passive reward offer is unresolved
**When** the player chooses Consume
**Then** `ConsumePassiveCommand` validates the offer and adds the passive to active run state
**And** a deterministic passive-consumed event is emitted.

**Given** the consumed passive has rules
**When** the relevant trigger window occurs
**Then** the rules kernel resolves the passive through stable ordering
**And** generated outcomes include player/debug-readable explanations.

**Given** passive trigger-order fixtures exist
**When** multiple starting, item, affinity, or consumed-passive rules can trigger in the same window
**Then** tests verify trigger timing, resolver order, stacking, conflict handling, and explanation output
**And** new passive content cannot bypass those fixtures.

**Given** the passive was already consumed, destroyed, or is not in the current offer
**When** Consume is submitted
**Then** the command fails with a stable error
**And** passive state, reward state, and RNG state remain unchanged.

### Story 6.6: Destroy Passive Command and Outcome Distribution

As a player,
I want to Destroy a passive for safety, resources, refusal, or hidden progress,
So that Destroy is a meaningful alternative to Consume.

**Acceptance Criteria:**

**Given** a passive reward offer is unresolved
**When** the player chooses Destroy
**Then** `DestroyPassiveCommand` validates the offer and resolves a deterministic Destroy outcome
**And** a passive-destroyed event records the passive id and outcome category.

**Given** MVP Destroy outcomes are configured
**When** outcome selection runs
**Then** it supports small immediate benefits, progress/unlock or hidden flags, and no-obvious-reward outcomes that avoid future danger
**And** outcome rolls use the assigned `rewards` or `events` RNG stream.

**Given** the MVP Destroy outcome table is validated
**When** configured outcome weights are checked
**Then** the target distribution is 70 percent small immediate benefit, 20 percent progress/unlock/hidden flag, and 10 percent no obvious reward that avoids corruption or future danger
**And** any temporary tuning deviation records the reason, date, and owner in content or tuning notes.

**Given** a Destroy outcome cleanses, heals, grants gold, grants Oath Shards placeholder progress, rerolls future rewards, or advances a hidden flag
**When** it resolves
**Then** domain events record the exact mechanical effect
**And** the explanation log communicates the known result.

**Given** the player compares Consume and Destroy
**When** the modal presents both choices
**Then** the text communicates what is gained, what is refused or sacrificed, and whether known consequences exist
**And** Destroy does not read like a generic salvage button when it has meaningful narrative or risk implications.

### Story 6.7: Loot and Passive Build Smoke Run

As a player,
I want a short run to include loot, inventory, consumables, and passive choices,
So that the MVP can prove early build identity before deeper balance work.

**Acceptance Criteria:**

**Given** a shell run clears eligible nodes
**When** rewards are generated
**Then** at least one passive or loot offer can appear by early-mid run configuration
**And** the offer can be consumed, destroyed, picked up, or skipped according to its type.

**Given** the route reaches the early-mid run band
**When** reward pacing checks run across approved smoke seeds
**Then** at least one build-defining passive offer is available by the configured node or depth target
**And** failures point to reward table weights, passive pool coverage, or node pacing rather than hidden hand-authored fixes.

**Given** the player uses a consumable
**When** the consumable command executes
**Then** the item effect resolves through domain events
**And** the consumable is removed or reduced according to inventory rules.

**Given** consumables appear in MVP reward tables
**When** smoke runs or playtest notes are reviewed
**Then** each consumable has an explicit intended use case and target frequency band showing it is semi-rare
**And** at least one observed or simulated use demonstrates player-perceived value before expanding the consumable pool.

**Given** a loot/passive smoke test run executes headlessly
**When** reward, inventory, Consume, Destroy, and consumable flows run
**Then** the run remains deterministic for the same seed
**And** invalid/no-mutation cases are covered by tests.

**Given** an internal tester reaches at least two passive choices
**When** they choose Consume once and Destroy once
**Then** they can explain what they gained and what they gave up in both cases
**And** unclear or emotionally flat choice text is flagged before the passive pool expands.

## Epic 7: Risk Economy and Affinities

Players encounter readable temptation through gold, scarce healing, curses/corruption, risky rewards, and tactical affinity pressure from Scorched, Flooded/Conductive, Cursed, and Darkness.

### Story 7.1: Risk Economy State

As a player,
I want gold, healing pressure, curses/corruption, and Oath Shard eligibility to be tracked clearly,
So that risk choices have visible consequences.

**Acceptance Criteria:**

**Given** a run starts
**When** risk economy state is initialized
**Then** it tracks gold, healing resources or availability, curse/corruption state, Oath Shard eligibility, and risk flags
**And** the fields are part of domain state and save snapshots.

**Given** gold or healing changes
**When** an economy command or reward outcome resolves
**Then** deterministic currency or healing events are emitted
**And** the explanation log records the reason.

**Given** invalid economy changes are requested
**When** validation fails
**Then** the command returns a stable error
**And** currency, health, curse, and reward state remain unchanged.

### Story 7.2: Curse and Corruption Rules

As a player,
I want cursed or corrupted choices to show clear upside and downside,
So that risky rewards feel tempting but readable.

**Acceptance Criteria:**

**Given** a cursed or corrupted reward is offered
**When** the offer view model is built
**Then** it exposes the clear upside and clear downside before acceptance
**And** hidden or delayed consequences are labeled honestly.

**Given** the player accepts a cursed or corrupted reward
**When** the command resolves
**Then** the benefit and penalty are both applied through domain events
**And** curse/corruption state is updated in the run snapshot.

**Given** a curse or corruption effect has a trigger
**When** the trigger window occurs
**Then** the rules kernel resolves the effect deterministically
**And** its explanation identifies the curse or corruption source.

### Story 7.3: Risk/Reward Event Choices

As a player,
I want events to offer tempting choices with known risks,
So that greed and safety compete during a run.

**Acceptance Criteria:**

**Given** a risk/reward node is entered
**When** event generation runs
**Then** it offers a deterministic event choice using approved event definitions
**And** the event uses the named `events` RNG stream.

**Given** the player chooses a risk option such as gold now for future danger, strong passive for max HP loss, or cheap reforge with corruption
**When** the event command resolves
**Then** both the reward and the risk are recorded through domain events
**And** future systems can query the resulting risk flags.

**Given** the event is already resolved or the choice is invalid
**When** another event command is submitted
**Then** it fails with a stable error
**And** no extra reward or penalty is applied.

### Story 7.4: Affinity Definitions and Assignment

As a player,
I want levels to carry readable affinity identities,
So that Scorched, Flooded/Conductive, Cursed, and Darkness change tactical expectations.

**Acceptance Criteria:**

**Given** MVP affinity definitions are authored
**When** the content repository loads them
**Then** Scorched, Flooded/Conductive, Cursed, and Darkness definitions expose id, display name, tactical rules, visual tags, and explanation text
**And** invalid affinity content fails validation.

**Given** a generated or selected level receives an affinity
**When** assignment runs
**Then** the affinity is recorded in the level snapshot
**And** assignment is deterministic for the same seed and route state.

**Given** a level has no affinity
**When** tactical systems query affinity rules
**Then** they receive an empty or neutral rule set
**And** no affinity side effects occur.

### Story 7.5: Tactical Affinity Effects

As a player,
I want affinities to alter tactical decisions instead of acting only as visuals,
So that each affected level creates distinct pressure.

**Acceptance Criteria:**

**Given** Scorched affinity is active
**When** fire hazards or burning terrain rules trigger
**Then** damage-over-time or hazard pressure resolves through domain events
**And** affected cells are explainable in previews and logs.

**Given** Flooded/Conductive affinity is active
**When** water or conductive danger zones are evaluated
**Then** pathing pressure or electric interaction placeholders resolve deterministically
**And** critical danger information is not color-only.

**Given** Cursed affinity is active
**When** risk/reward or penalty hooks trigger
**Then** the rules kernel applies the configured cursed pressure
**And** the result is clear before or when it affects the player.

**Given** Flooded/Conductive uses placeholder interactions during MVP implementation
**When** Epic 10 readiness reviews affinity content
**Then** each placeholder effect is either replaced with a concrete water/electric interaction, explicitly de-scoped as non-production MVP behavior, or blocks readiness
**And** placeholder cue ids, visual ids, and explanation text remain distinct from final production identifiers.

**Implementation Task Checklist:**

- [ ] 7.5.1 Implement Scorched hazard/burning terrain rules, preview warnings, damage events, and fairness fixtures.
- [ ] 7.5.2 Implement Flooded/Conductive pathing pressure or deterministic water/electric placeholders with non-color-only danger communication.
- [ ] 7.5.3 Implement Cursed affinity hooks through risk/reward or penalty rules with pre-effect or on-effect clarity.
- [ ] 7.5.4 Add per-affinity fixtures proving tactical choice impact, event output, explanation text, and no direct scene-state mutation.

### Story 7.6: Darkness Fairness and Memory Pressure

As a player,
I want Darkness to create uncertainty without cheap unseen damage,
So that caution and inspection feel rewarding rather than unfair.

**Acceptance Criteria:**

**Given** Darkness affinity is active
**When** visibility rules are applied
**Then** it may reduce visibility, obscure counts, hide rewards, distort explored memory, or empower specific enemies according to definition
**And** it does not spawn unavoidable damage from unseen space.

**Given** Darkness modifies explored memory
**When** inspect or preview data is requested
**Then** the UI can communicate uncertainty or stale memory state
**And** current visible tactical truth remains reliable.

**Given** Darkness fairness tests run
**When** seeded Darkness levels are generated and simulated
**Then** first reveal and unseen-space checks pass
**And** failures report seed, phase, and fairness reason.

## Epic 8: Outpost, Meta Progression, and Run Summary

Players can die or finish a run, return to the last outpost, review what happened, receive eligible progress, see manual-seed warnings, unlock or advance something, and start another descent.

### Story 8.1: Run Completion and Return-to-Outpost Flow

As a player,
I want death or completion to return me to the last outpost,
So that each run clearly closes and the next descent can begin.

**Acceptance Criteria:**

**Given** the hero dies during a level, event, or boss encounter
**When** run completion resolves
**Then** the run enters failed state and emits a run-failed event with cause
**And** the next app flow destination is the outpost.

**Given** the run reaches a completion or victory path
**When** run completion resolves
**Then** the run enters completed state and emits a run-completed event
**And** the next app flow destination is the outpost.

**Given** a run has already completed or failed
**When** completion is requested again
**Then** it returns a stable error or idempotent result
**And** rewards or progression are not granted twice.

### Story 8.2: Run Summary Snapshot

As a player,
I want a summary of what happened during the run,
So that death, victory, rewards, and mistakes are understandable.

**Acceptance Criteria:**

**Given** a run ends
**When** the run summary snapshot is built
**Then** it includes cause of death or victory, nodes cleared, boss or elite progress, consumed and destroyed passives, notable loot, Oath Shards earned, Echoes discovered, unlock progress, and seed where available
**And** unavailable future fields are represented as zero, empty, or not-yet-supported without breaking the summary.

**Given** domain events exist for the run
**When** summary data is derived
**Then** it uses domain state and event records rather than presentation logs as source truth
**And** manual-seed eligibility is included.

**Given** run-scoped state, profile/meta state, and content unlock state are summarized
**When** the run summary is built
**Then** the summary reads from explicit boundaries between those state types
**And** replay/debug state cannot accidentally grant profile or unlock progress.

**Given** summary tests run
**When** fixture runs end in death, shell completion, and manual-seed ineligible paths
**Then** the summary fields match expected values.

**Given** unavailable future summary fields remain represented as zero, empty, or not-yet-supported
**When** Epic 10 readiness reviews the run summary
**Then** each placeholder field is either replaced, explicitly de-scoped for MVP, or kept with a visible limitation note
**And** no placeholder summary value grants rewards, unlocks, or profile progress.

### Story 8.3: Meta Profile and Oath Shard Awards

As a player,
I want eligible runs to award shallow meta progress,
So that repeated descents expand options without becoming a stat grind.

**Acceptance Criteria:**

**Given** a non-manual eligible run ends
**When** meta award calculation runs
**Then** Oath Shards and eligible progress are calculated from approved rules
**And** the profile snapshot is updated through a versioned repository.

**Given** meta awards are applied
**When** profile state changes
**Then** changes are recorded through deterministic profile/meta events or repository results
**And** run state, profile state, and unlock/content state remain separable for save, replay, and tests.

**Given** meta progression awards or unlocks can affect future runs
**When** meta content validation runs
**Then** direct power gains are capped, sparse, and secondary to variety, knowledge, classes, loot pools, passives, secrets, codex entries, starting options, or class mastery
**And** broad raw-stat ladders such as repeatable damage, max HP, armor, crit, or dodge upgrades are rejected for MVP unless explicitly approved as capped onboarding smoothing.

**Given** a manual seed run ends
**When** meta award calculation runs
**Then** Oath Shards, class mastery, unlock progress, and other meta rewards are not granted
**And** the summary shows a replay/practice warning.

**Given** profile save fails
**When** the repository reports the failure
**Then** the system exposes a structured recovery path
**And** it does not silently lose current run summary data.

### Story 8.4: Echoes, Seal Fragments, and Unlock Progress

As a player,
I want discoveries and unlock progress to be tracked,
So that meta progression expands knowledge, variety, and starting options.

**Acceptance Criteria:**

**Given** a run discovers an Echo, Seal Fragment, class mastery point, or unlock flag
**When** the run ends
**Then** eligible progress is merged into the profile snapshot
**And** duplicate discoveries do not grant duplicate unique unlocks.

**Given** a manual seed run discovers progress-bearing content
**When** progression is evaluated
**Then** the content may appear in the run summary as discovered during replay
**And** it does not grant permanent meta progress unless explicitly allowed by policy.

**Given** unlock progress reaches a configured threshold
**When** the profile updates
**Then** the unlock state changes deterministically
**And** the run summary reports the unlock or progress change.

### Story 8.5: First-Death Line and Optional Narrative Delivery

As a player,
I want short narrative beats to support the loop without blocking play,
So that story flavor remains optional and skippable.

**Acceptance Criteria:**

**Given** the player dies for the first time
**When** the outpost return flow displays narrative text
**Then** it can show "Good. You remembered how to die."
**And** the line is tracked so it is not repeated as a first-death event.

**Given** a narrative or control-loss moment appears
**When** the player skips or dismisses it
**Then** gameplay flow continues to the outpost or next menu
**And** skipping does not change rewards, unlocks, or tactical state.

**Given** a player ignores lore
**When** they view run summary and outpost options
**Then** required gameplay choices remain understandable
**And** lore reading is not required to start another descent.

### Story 8.6: Outpost Menu and Start Another Descent

As a player,
I want the outpost to show summary, progress, and start options,
So that I can quickly begin another run after death or victory.

**Acceptance Criteria:**

**Given** the player returns to the outpost
**When** the outpost view model is built
**Then** it exposes run summary, current Oath Shards, discovered Echoes, unlock progress, class options, and start-run actions
**And** domain/profile snapshots remain source truth.

**Given** the outpost is represented in UI/view-model data
**When** named space metadata is built
**Then** it includes stable ids or explicit deferred placeholders for Memory Archive, Hall of Oaths, Seal Table, and Gate/Descent Stair
**And** those names support navigation, unlock affordances, or future layout notes without making UI state authoritative.

**Given** the player starts another descent
**When** start-run is selected
**Then** a new run request is created with selected class and seed eligibility settings
**And** prior completed run state is not reused as active state.

**Given** outpost data is missing or incompatible
**When** the outpost loads
**Then** it uses a structured recovery or fresh-profile path
**And** it does not crash or create invalid meta state.

### Story 8.7: Meta and Summary Save/Load Tests

As a player,
I want outpost and profile progress to survive app restarts,
So that earned knowledge and unlocks are reliable.

**Acceptance Criteria:**

**Given** a profile snapshot is saved
**When** the game reloads it
**Then** Oath Shards, Echoes, Seal Fragments, unlock progress, first-death flags, and class unlock states restore correctly
**And** current-run autosave remains separate from profile/meta data.

**Given** a schema version changes
**When** migration tests run
**Then** older supported profile snapshots migrate or fail with a clear unsupported-version result
**And** migration does not grant unintended progress.

**Given** summary and meta tests run headlessly
**When** eligible, manual-seed, death, and completion cases execute
**Then** progression grants and denials match expected rules
**And** no scene nodes are serialized.

## Epic 9: Larval Avatar MVP Finale

Players can reach and defeat the Larval Avatar, see the first-victory reveal, and return to the open-ended roguelite loop.

### Story 9.1: Boss Node Transition and Finale Setup

As a player,
I want the final route node to transition into the Larval Avatar encounter,
So that the MVP run has a real endpoint.

**Acceptance Criteria:**

**Given** the player reaches the boss node
**When** node entry resolves
**Then** it creates a Larval Avatar boss encounter request
**And** it uses existing run, level, save, and RNG boundaries.

**Given** the boss encounter is generated or loaded
**When** setup completes
**Then** the level snapshot includes entrance, boss arena, player start, boss entity, and any finale constraints
**And** setup is deterministic for the same seed and run state.

**Given** boss setup fails validation
**When** the failure is reported
**Then** it includes seed, phase, reason, and compact diagnostics
**And** the run does not enter a broken boss state.

### Story 9.2: Larval Avatar Definition and Phases

As a player,
I want the Larval Avatar to have readable boss phases,
So that the finale tests preparation without requiring a full boss roster.

**Acceptance Criteria:**

**Given** the Larval Avatar definition is loaded
**When** content validation runs
**Then** it includes HP, phase thresholds or triggers, legal actions, telegraph definitions, damage rules, and explanation text
**And** invalid boss content fails validation.

**Given** the boss changes phase
**When** the phase transition trigger resolves
**Then** a deterministic phase-change event is emitted
**And** future AI choices are constrained by the active phase.

**Given** boss phase tests run
**When** HP thresholds or scripted triggers are reached
**Then** phase transitions occur in stable order
**And** repeated triggers do not duplicate phase changes.

### Story 9.3: Boss Actions, Telegraphs, and AI Decisions

As a player,
I want the boss to telegraph major danger and choose explainable actions,
So that the finale is dangerous but readable.

**Acceptance Criteria:**

**Given** the boss has a major dangerous ability
**When** it selects that ability
**Then** a telegraph event is emitted before damage resolves
**And** the player has a reasonable response window.

**Given** the boss chooses a movement, attack, telegraph, phase, or effect action
**When** the action resolves
**Then** it uses existing commands, rules-kernel operations, or a narrow boss command adapter
**And** boss logic does not mutate tactical state directly.

**Given** the boss chooses among valid actions
**When** utility scoring runs
**Then** the selected action includes score or reason output
**And** the choice is reproducible for the same seed and state.

**Given** a telegraphed boss attack resolves
**When** the player remains in danger
**Then** damage or effect events apply deterministically
**And** the explanation log identifies the boss ability.

**Implementation Task Checklist:**

- [ ] 9.3.1 Implement boss telegraph event selection and response-window state before damaging effects resolve.
- [ ] 9.3.2 Route boss movement, attacks, phase changes, and effects through existing commands, rules-kernel operations, or narrow boss adapters.
- [ ] 9.3.3 Implement utility scoring with reproducible chosen action, top score, and major reason output.
- [ ] 9.3.4 Add fixtures for telegraph-only, telegraph-then-hit, phase action, invalid action rejection, and same-seed reproducibility.

### Story 9.4: Boss Victory and First-Victory Reveal

As a player,
I want defeating the Larval Avatar to resolve victory and reveal the MVP story beat,
So that a successful run lands as a complete first endpoint.

**Acceptance Criteria:**

**Given** the Larval Avatar reaches zero HP
**When** combat outcome evaluates
**Then** a boss-defeated event and run-victory event are emitted
**And** the run transitions to post-victory return flow.

**Given** the player wins for the first time
**When** the victory reveal is displayed
**Then** it can show "It did not die. It learned the way back."
**And** the reveal is tracked so first-victory state is persisted.

**Given** the reveal is skipped or dismissed
**When** the player continues
**Then** the run summary and outpost return still occur
**And** skipping does not alter rewards or progression.

### Story 9.5: Finale Regression and Run-Length Tuning Hooks

As a player,
I want the finale to work within the target run arc,
So that reaching the boss feels like a fair culmination of the MVP run.

**Acceptance Criteria:**

**Given** boss encounter seed regression tests run
**When** approved boss seeds are executed
**Then** setup, phases, telegraphs, victory, and defeat paths remain deterministic
**And** failures report seed and phase.

**Given** a full run reaches the boss through the run shell
**When** the boss is defeated or the player dies
**Then** run summary records boss progress and outcome
**And** outpost/meta flow receives the correct completion event.

**Given** tuning diagnostics are enabled for development builds
**When** boss attempts complete
**Then** diagnostics capture turn count, damage taken, major telegraphs, and outcome
**And** diagnostics remain local/offline and do not introduce telemetry dependencies.

## Epic 10: Playtest Tuning and MVP Readiness

Players receive a stable MVP experience validated against performance, readability, save/resume reliability, generator safety, run length, comprehension, and replay-intent signals.

> **Sequencing note (2026-07-04, sprint change):** Stories 10.4, 10.5, 10.6, and 10.7 require **Epic 11 (Live Run Flow, HUD, and Outpost)** to land first — their playtest sessions, screen audits, loop gate, and UX gate assume a hands-off-playable loop that Epic 11 wires. Stories 10.1-10.3 are independent of Epic 11.

### Story 10.1: Device Tiers and Performance Budgets

As a player,
I want the MVP to remain responsive on target devices,
So that tactical decisions feel deliberate rather than sluggish.

**Acceptance Criteria:**

**Given** production readiness planning begins
**When** device tiers are defined
**Then** low, mid, and high mobile target tiers plus Windows desktop parity expectations are documented
**And** measurement method, memory expectations, and battery/performance notes are recorded.

**Given** target tiers are documented
**When** the readiness plan is reviewed
**Then** low tier includes a budget Android-class phone/tablet with roughly 4 GB RAM, mid tier includes a current-minus-two-years Android or iOS-class device with roughly 6 GB RAM, high tier includes a current flagship phone/tablet class device, and Windows parity includes an integrated-GPU laptop/desktop target
**And** each tier names the physical device, emulator/simulator, or explicit availability gap used for measurement.

**Given** performance budgets are measured
**When** generated level load, preview response, selection response, and combat frame stability are tested
**Then** results are compared against under-3-second level load, under-100ms preview/selection response, and 60 FPS where feasible or 30 FPS acceptable lower-end targets
**And** failures produce actionable diagnostics.

**Given** memory, battery, and thermal expectations are measured
**When** a 20-minute representative run or scripted simulation is exercised on each available target tier
**Then** the build must avoid OS memory warnings or termination, stay below the recorded per-tier peak-memory budget, and avoid sustained thermal throttling or input degradation
**And** battery drain is recorded with an initial planning target of no more than 15 percent over 30 minutes on a comparable physical mobile device when measurement is available.

**Given** performance tests run
**When** debug overlays or instrumentation are enabled
**Then** they remain build-profile gated
**And** production builds do not expose cheat/debug tools.

### Story 10.2: Headless Seed Regression Suite

As a player,
I want common seeds and tactical flows to remain stable,
So that fixes do not break determinism or core gameplay.

**Acceptance Criteria:**

**Given** approved seed fixtures exist for tactical, generation, route, reward, affinity, and boss flows
**When** the headless seed regression suite runs
**Then** each fixture reports deterministic fingerprints and pass/fail status
**And** failures include seed, system, phase, and reason.

**Given** final MVP readiness seed coverage is selected
**When** seed sample sizes are reviewed
**Then** the suite includes at least 25 tactical command/board fixtures, 50 Small level seeds, 50 Medium level seeds, 20 route seeds, 20 reward/passive seeds, 10 seeds per implemented affinity, and 10 boss/finale seeds
**And** any smaller pre-MVP sample is marked as temporary and cannot pass final MVP readiness without approved de-scope.

**Given** RNG stream state is snapshotted during tests
**When** a run is paused and resumed in simulation
**Then** subsequent outcomes match the uninterrupted run
**And** cosmetic stream usage does not change gameplay outcomes.

**Given** the suite is run in development
**When** any deterministic fixture changes intentionally
**Then** fixture updates require an explicit expected-output update
**And** accidental drift is visible.

### Story 10.3: Generator Soft-Lock and Fairness Batch Checks

As a player,
I want generated levels to avoid soft-locks and unfair first reveals,
So that procedural variety remains trustworthy.

**Acceptance Criteria:**

**Given** a batch of Small and Medium level seeds is selected
**When** generator validation runs headlessly
**Then** every generated level has entrance-to-exit reachability, legal enemy placement, reachable intended rewards, and safe first reveal
**And** failures include compact diagnostics.

**Given** Darkness or other affinity pressure is active
**When** fairness validation runs
**Then** it checks that unseen-space damage is avoidable and critical danger is inspectable or telegraphed
**And** failures are tagged by affinity.

**Given** generator failure rates exceed accepted thresholds
**When** the report is reviewed
**Then** the relevant recipes, validation rules, or retry limits are flagged for tuning
**And** failing seeds are preserved for reproduction.

**Given** final generator and fairness batches are evaluated
**When** pass/fail thresholds are applied
**Then** zero soft-locks, zero mandatory class/item gates, zero unreachable mandatory exits, zero unreachable intended mandatory rewards, and zero unavoidable untelegraphed first-reveal punishments are acceptable
**And** bounded retry exhaustion must stay at or below 1 percent per recipe batch, with every failing seed preserved and tagged before readiness can pass.

### Story 10.4: Gameplay Comprehension and Playtest Checklist

**Prerequisite (2026-07-04):** Epic 11 — observed sessions require the live playable loop (fight, die or win, reveal, outpost, another descent).

As a player,
I want the first MVP playtest to reveal whether the core loop is understandable,
So that tuning focuses on real friction rather than guesswork.

**Acceptance Criteria:**

**Given** a playtest checklist is prepared
**When** it is reviewed
**Then** it covers movement comprehension, attack preview clarity, preview/commit distinction, damage/death explanation, Consume/Destroy clarity, positioning importance, and quit/resume success
**And** it does not require live-service telemetry.

**Given** MVP playtest sessions are scheduled
**When** the checklist format is prepared
**Then** it records tester id or alias, date, device/form factor, build id, seed, class, session length, run outcome, nodes cleared, notable confusion, memorable moment, desire for another descent, and any blocked action
**And** at least five observed sessions across available mobile and desktop form factors are targeted before final readiness, with fewer sessions treated as a documented readiness limitation.

**Given** a playtester completes death, victory, or run end
**When** feedback is captured
**Then** the checklist records whether the player wants another descent, what confused them, and what moment they remember
**And** feedback can be stored as local playtest notes.

**Given** repeated feedback identifies the same issue
**When** tuning tasks are created
**Then** they reference the relevant epic/story, seed if applicable, and observed player impact
**And** scope remains focused on MVP readiness.

**Given** playtest acceptance thresholds are reviewed
**When** final MVP readiness is assessed
**Then** no more than one of five observed sessions may fail to understand basic movement/attack commit after the first encounter, no more than one of five may be unable to explain the main cause of death or major damage, and at least three of five should name a memorable build, passive, risk, enemy, or moment
**And** any repeated blocker in two or more sessions creates a tuning or UX task before readiness can pass.

**Given** consumables appear during playtest or smoke runs
**When** frequency, use rate, and player-perceived value are reviewed
**Then** consumables are flagged for tuning if they appear too often, never appear across the approved sample, are ignored in three or more relevant sessions, or are described as not worth using by repeated testers
**And** tuning notes reference reward tables, consumable definitions, and observed context.

**Given** a playtester plays the first tactical loop with each MVP class — Warrior, Pyromancer, and Ranger — and (once Epic 6+ ships them) any additional class/build content (relocated from Story 5.5, 2026-06-26)
**When** they compare the class starts
**Then** each class must change at least one combat decision through equipment, passive, or preview behavior
**And** any class that feels like a stat-only reskin is flagged for tuning before more class content is added, referencing the relevant class definition, starting kit, and passive explanation surface.

### Story 10.5: Accessibility and Readability Audit

**Prerequisite (2026-07-04):** Epic 11 — the audited surfaces (tactical HUD in-run, route map, outpost, run summary, reveal beats) must exist as screens first.

As a player,
I want critical tactical information to remain accessible in the MVP build,
So that readability problems are caught before broader testing.

**Acceptance Criteria:**

**Given** tactical HUD, previews, hazards, affinities, telegraphs, passive modal, route map, outpost, and run summary are available
**When** accessibility audit runs
**Then** critical information is checked for colorblind-safe communication, scalable text, non-overlap, and no color-only meaning
**And** failures are recorded with screen, state, and issue.

**Given** phone portrait and landscape viewports are tested
**When** core combat and reward flows are exercised
**Then** primary actions remain reachable and readable
**And** orientation changes do not alter tactical rules.

**Given** audio is muted or unavailable
**When** preview, confirm, warning, damage, and reward feedback occur
**Then** visual or textual equivalents communicate critical meaning
**And** no required information is audio-only.

### Story 10.6: MVP Readiness Gate and Playable Build Preservation

**Prerequisite (2026-07-04):** Epic 11 — the loop gate's steps (fight, die or win, view summary, start another descent) must be live, not driven/test-resolved.

As a player,
I want each milestone and the final MVP candidate to remain playable,
So that the project does not accumulate disconnected systems.

**Acceptance Criteria:**

**Given** all MVP epics have implementation marked complete
**When** the readiness gate runs
**Then** it verifies launch, start run, choose class, generate or enter levels, fight, collect rewards, make passive choices, die or win, view summary, and start another descent
**And** any missing loop step blocks MVP readiness.

**Given** relevant tests are available
**When** the final validation suite runs
**Then** command, RNG, board, fog, combat, generation, save/load, passive, risk, meta, boss, and headless seed tests pass or have documented exceptions
**And** exceptions include risk and owner notes.

**Given** the MVP build candidate is prepared
**When** pre-export validation runs
**Then** debug/cheat tools are disabled or inert, prototype dependencies are absent, scene nodes are not save truth, and no cloud/live-service dependency is introduced
**And** the build remains offline-first single-player.

**Given** MVP readiness includes settings and challenge scope
**When** the readiness checklist is reviewed
**Then** it verifies settings contain no selectable difficulty ladder and no easy/normal/hard tier
**And** post-MVP challenge ideas remain explicit variants, trials, oaths, or special runs rather than generic difficulty tiers.

**Implementation Task Checklist:**

- [ ] 10.6.1 Run the full rough-loop smoke path: launch, start run, choose class, generate/enter levels, fight, collect rewards, make passive choices, die or win, view summary, and start another descent.
- [ ] 10.6.2 Run command, RNG, board, fog, combat, generation, save/load, passive, risk, meta, boss, and headless seed suites or record approved exceptions.
- [ ] 10.6.3 Run pre-export validation for debug/cheat gating, prototype independence, save-truth boundaries, offline-first mode, and no cloud/live-service dependency.
- [ ] 10.6.4 Review Epic 10 device, performance, memory, battery, seed, playtest, settings, placeholder, asset, and audio thresholds before marking MVP ready.
- [ ] 10.6.5 Preserve a playable build candidate with build id, test result summary, known limitations, and de-scope notes.

### Story 10.7: Asset, Audio, Placeholder, and UX Readiness Gate

**Prerequisite (2026-07-04):** Epic 11 — the UX appendix (Story 11.1) and the screen surfaces (11.3/11.5) are inputs to this gate.

As a player,
I want the MVP build to use readable visuals and feedback even where production assets are deferred,
So that placeholders do not hide missing gameplay communication or readiness risk.

**Acceptance Criteria:**

**Given** production art or audio is not yet final
**When** MVP asset planning is reviewed
**Then** production assets/audio may be deferred only if placeholder ids exist for 3 playable class portraits/icons or hero silhouettes, 2 locked class silhouettes/icons, 3 enemy-pattern visuals, 1 boss visual, 4 affinity treatments, Small/Medium Labyrinth tiles/props, baseline weapon/support icons, 20-30 passive icons or placeholder glyphs, tactical/outpost/run UI frames, core SFX, and ambient loops
**And** each placeholder is readable enough to support tactical, reward, route, outpost, and summary decisions.

**Given** audio feedback is mapped from domain outcomes
**When** the event-to-audio cue map is reviewed
**Then** it includes movement, weapon hits, enemy actions, hazards, preview/confirm distinction, passive pickup, Consume, Destroy, curse/corruption, door sealing, death, reward reveal, and boss victory
**And** muting audio never removes required information because visual/textual equivalents remain available.

**Given** placeholder or AI-assisted assets are used
**When** asset metadata is validated
**Then** each entry records stable id, status, tool or source, prompt if applicable, date, source reference, license/provenance notes, editable source path, runtime export path, and approval status
**And** unapproved placeholder or exploration assets cannot be silently treated as production assets.

**Given** placeholder behavior exists in Story 4.5, Story 7.5, Story 8.2, or asset/audio mappings
**When** final MVP readiness is assessed
**Then** each placeholder is replaced, explicitly de-scoped with an approved limitation, or listed as blocking readiness
**And** the readiness notes identify the affected story, player-facing risk, owner, and target replacement path.

**Given** UI-heavy scene production is about to begin
**When** UX prerequisites are checked
**Then** a lightweight UX appendix or equivalent implementation notes exist for tactical HUD, preview/confirm, inspect, passive modal, run map, outpost/meta, run summary, settings, and save/resume recovery
**And** the absence of a standalone UX document remains non-blocking only for domain-first Epic 1 work and view-model/command-bridge contracts.

## Epic 11: Live Run Flow, HUD, and Outpost

Players can play the full descent hands-on — launch, choose a class, fight generated levels and the Larval Avatar on the live tactical board, win or die for real, see the reveal lines and run summary, spend meta progress at the outpost, and start another descent.

> **Sequencing:** inserted 2026-07-04 via sprint change proposal; executes between Epic 9 and Epic 10's Stories 10.4-10.7. See the Epic List entry for FR coverage and implementation notes.

### Story 11.1: Run-Flow UX Appendix and Screen Contracts

As a player,
I want the MVP's screens to follow deliberate, readable designs,
So that the run flow communicates tactical and meta information clearly on phone and desktop.

**Prerequisite discharge:** this story delivers the "lightweight UX appendix" required by the UX Design Requirements readiness patch note before UI-heavy scene implementation, and consumed by Story 10.7's UX prerequisite check.

**Acceptance Criteria:**

**Given** UI-heavy scene implementation is about to begin
**When** the lightweight UX appendix is authored under planning artifacts
**Then** it covers tactical HUD, preview/confirm states, inspect panel, passive modal, run map, outpost/meta menu, run summary, settings, and save/resume recovery states
**And** it additionally covers the first-death and first-victory reveal moments with their skip/dismiss affordances and the manual-seed no-progression warning surface.

**Given** the appendix is authored
**When** each screen section is reviewed
**Then** it maps to the existing view-model/command-bridge contracts (tactical view models, reward/passive modal contract, `HeroSelectViewModel`, `OutpostViewModel`, `RunSummary`, narrative beat DTOs) without inventing new domain surfaces
**And** any contract gap it identifies is recorded as an explicit note for the owning story rather than silently expanded scope.

**Given** the appendix exists
**When** layout coverage is reviewed
**Then** phone portrait, phone landscape, tablet, and desktop-style layouts are addressed for each screen (FR66)
**And** critical information avoids color-only meaning and supports scalable text (NFR8, NFR9).

### Story 11.2: Live Combat Loop and Hero Death Source

As a player,
I want fights to be played out for real and death to actually end a run,
So that a descent can be won or lost by what happens on the board.

**Acceptance Criteria:**

**Given** a run enters a combat, elite combat, or boss node
**When** the node resolves in the live run flow
**Then** resolution comes from live tactical play on the board state — player commands through the command bridge, enemy and boss turns through the existing turn resolvers
**And** the v0 auto-resolve-to-success placeholder no longer decides live combat outcomes (it may remain for explicitly non-live simulation paths).

**Given** the hero reaches 0 HP during any live encounter (level or boss)
**When** the combat loop detects hero death
**Then** it auto-fires the run-end resolution (`CompleteRunCommand` with the appropriate failure cause from `RUN_FAILED_CAUSES`) driving `PHASE_FAILED` and `next_destination == outpost`
**And** FR32's loss condition is triggerable live, with the first-death latch recordable off the real terminal state.

**Given** the Larval Avatar reaches 0 HP in the live flow
**When** the boss victory resolves
**Then** `RunOrchestrator.resolve_boss_victory()` gains its production call site (boss route node cleared, `resolve_run_end(victory)` driven, first-victory latch recorded via `RecordFirstVictoryCommand`)
**And** `run_to_completion` can auto-play the full boss fight headlessly (both sides simulated) for seed-batch and simulation use.

**Given** the live wiring lands
**When** the headless suite and seed regressions run
**Then** interrupted==uninterrupted determinism, the 23-key `RunSnapshot` gate, `ProfileSnapshot.SCHEMA_VERSION == 1`, the 7 named RNG streams, and every pinned fingerprint hold
**And** forcing tests are added for defensive branches the live path makes reachable (the `_resolve_completed` step-2 restore; the `NodeResolvePlaceholderCommand._resolve_boss` atomicity twin if its branch is driven).

### Story 11.3: Run Flow Scene Navigation and In-Run HUD

As a player,
I want to move through a whole descent on screen — from launch to class select to levels to the run's end,
So that the roguelite loop is something I play rather than something tests prove.

**Acceptance Criteria:**

**Given** the game launches
**When** I start a run
**Then** `SceneManager` drives launch -> hero select -> route map -> tactical board per node -> run-end return
**And** navigation follows `RunEndOutcome.next_destination` and the existing view-model contracts, with no scene owning tactical truth.

**Given** I play a combat node
**When** the tactical board hosts a generated level in-run
**Then** movement/attack previews, two-step commit, inspect, the passive reward modal, and reward pickup flows work through the existing Epic 2/6 presentation contracts
**And** the in-run HUD presents run context (HP, node progress, gold, inventory/passives access) per the 11.1 appendix.

**Given** I quit and resume mid-run
**When** the resume flow runs at a between-level boundary
**Then** the run continues from the persisted snapshot with save/resume recovery states reachable through real screens
**And** resumed outcomes match uninterrupted play (NFR13).

**Given** phone portrait and desktop layouts
**When** the full flow is exercised on both
**Then** primary actions remain reachable and readable (FR66, NFR7)
**And** layout changes never alter tactical rules.

### Story 11.4: Live Affinity Pressure On Screen

As a player,
I want affinity levels to feel different and dangerous in real play,
So that Scorched, Flooded, Cursed, and Darkness change my tactical choices, not just visuals.

**Acceptance Criteria:**

**Given** a run level carries an affinity
**When** the level is played live
**Then** the Epic-7 affinity effects receive their first live call sites (Darkness visibility/memory pressure, Scorched damage-over-time, Cursed rule-source, Flooded per its ratified MVP placeholder posture)
**And** live effects match the headless-proven deterministic behavior (FR57).

**Given** an affinity is active
**When** the board and HUD present it
**Then** the approved affinity treatments and readability cues make the affinity and its rule visible before and during play (FR55)
**And** telegraphed danger remains inspectable through the existing inspect flow (FR12, FR58).

**Given** Darkness is active in live play
**When** fairness invariants are exercised on the live path
**Then** the 7.6 fairness guardrails hold (no unavoidable damage from unseen space)
**And** the darkness fairness queries remain the single authority the HUD reflects.

### Story 11.5: Outpost Scene, Reveal Renders, and Another Descent

As a player,
I want to return to a real outpost after a run — see what happened, read the line, and descend again,
So that the return loop and its story beats are experienced, not implied.

**Acceptance Criteria:**

**Given** a run ends in death or victory
**When** I return to the outpost
**Then** an outpost scene renders the `OutpostViewModel` contract (currency totals, named spaces, run summary, unlock progress)
**And** starting another descent works through the `start_run_request`/`is_startable` seam (FR1 loop closure).

**Given** the profile's first death or first victory has just been recorded
**When** the outpost presents the narrative beat
**Then** "Good. You remembered how to die." / "It did not die. It learned the way back." render as optional, skippable/dismissible beats (FR61, FR62, FR64, FR65)
**And** skipping or dismissing is a pure presentation no-op that never blocks the outpost surface or a new descent.

**Given** a profile load or write failure occurred
**When** the outpost renders recovery
**Then** the write-failure path uses the loaded-profile `_init` representation (real totals behind a retry banner) and the load-failure path uses the fresh-profile fallback
**And** the previously untested loaded-profile + recovery combination gains its scene-level test (carried Epic-8 T4).

**Given** the run summary displays
**When** "Oath Shards earned" is shown
**Then** the summary-to-profile coupling decision (carried Epic-8 T5 / Epic-9 T4) is made and implemented — display the awarded total on the summary or surface it via the outpost
**And** manual-seed runs show their no-progression warning (FR28 surface).

### Story 11.6: Meta Spend and Unlock Application

As a player,
I want to spend what I earn and feel meta progress apply,
So that descents feed a shallow but real progression loop.

**Acceptance Criteria:**

**Given** the profile holds Oath Shards and unlock progress
**When** I spend at the outpost's shallow meta menu (FR59)
**Then** spend operations run as validated commands that emit deterministic domain events and persist through `ProfileRepository`
**And** manual-seed-earned progress remains excluded end-to-end (FR28).

**Given** an unlock's requirements are met and its effect applied
**When** hero select next renders
**Then** the applied unlock is reflected (locked-class hint -> actual selectability path per FR43), with meta power staying capped and sparse per the ratified GDD FR95 posture
**And** the application flows profile -> class selectability through repositories/view models, never through scene-owned state.

**Given** spends and applications exist
**When** save/load and migration tests run
**Then** profile round-trips cover the new spend state additively (no schema bump unless justified against the 8.7 migration matrix)
**And** idempotency and caller-ordering safety match the run-end command family's standards.
