---
project: Sealsworn
date: 2026-06-04
stepsCompleted:
  - step-01-document-discovery
  - step-02-gdd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
readinessStatus: READY_WITH_GATES
currentAssessmentUpdated: 2026-06-04
currentEpicsFileModified: 2026-06-04 12:47:09
includedFiles:
  gdd: C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md
  gddSourceEpicsContext: C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md
  architecture: C:/Sealsworn/_bmad-output/game-architecture.md
  implementationEpicsStories: C:/Sealsworn/_bmad-output/planning-artifacts/epics.md
  uxDesign: null
---

# Implementation Readiness Assessment Report

**Date:** 2026-06-04
**Project:** Sealsworn

## Step 01: Document Discovery

### Confirmed Assessment Sources

- GDD: `C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md`
- Source GDD epics context only: `C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md`
- Architecture source of truth: `C:/Sealsworn/_bmad-output/game-architecture.md`
- Canonical implementation epics/stories: `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md`
- UX design document: none

### Inventory

#### GDD Files Found

Whole documents:

- None found at `C:/Sealsworn/_bmad-output/planning-artifacts/*gdd*.md`

Sharded / folder documents:

- Folder: `C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/`
- `gdd.md` - 34,268 bytes, modified 2026-06-01 14:20:57
- `epics.md` - 12,011 bytes, modified 2026-06-01 14:20:57
- `decision-log.md` - 21,631 bytes, modified 2026-06-01 14:20:57
- `validation-report.md` - 6,884 bytes, modified 2026-06-01 14:21:44

#### Architecture Files Found

- Configured planning-artifacts search: none found
- Repository-guided source of truth: `C:/Sealsworn/_bmad-output/game-architecture.md` - 64,440 bytes, modified 2026-06-02 15:00:48

#### Epics & Stories Files Found

Whole documents:

- `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md` - 105,016 bytes, modified 2026-06-04 10:46:16

Additional GDD context:

- `C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md` - 12,011 bytes, modified 2026-06-01 14:20:57

#### UX Design Files Found

- None found.

### Discovery Issues

- Resolved: `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md` is the canonical implementation epics/stories file for this assessment.
- Resolved: `C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md` is source GDD context only, not the current implementation breakdown.
- Resolved: `C:/Sealsworn/_bmad-output/game-architecture.md` is the architecture source of truth per `AGENTS.md` and `project-context.md`.
- Non-blocking warning: no standalone UX document exists yet. This is acceptable for the domain-first MVP, but UX-sensitive gaps must be flagged if they affect implementation readiness.

## GDD Analysis

### Functional Requirements

FR1: The MVP must prove the complete rough roguelite loop: start run, choose class, generate map, enter generated levels, fight, collect rewards, make passive choices, die or win, receive summary, and unlock limited meta progression.

FR2: The core gameplay loop must be: choose hero/loadout, choose forward route, enter tactical level, spend turns positioning and fighting, claim rewards or risks, shape the build, exit forward, repeat until death or boss, return to the last outpost, remember, unlock, and descend again.

FR3: The player must control a single hero through seeded, forward-only procedural levels with fog of war, tactical positioning, weapon-shaped basic attacks, risk/reward routing, loot, passive rule-benders, and meta progression.

FR4: MVP run victory must occur by defeating the Larval Avatar at the final node.

FR5: MVP run loss must occur when the hero dies during a level, event, or boss encounter and returns spiritually to the last outpost.

FR6: Tactical combat clarity must be the first gameplay priority, followed by build crafting/synergy, route/risk decisions, and mystery discovery.

FR7: Combat must be turn-based with no real-time pressure; the player can think indefinitely, and pressure comes from turn consequences, enemy behavior, resource attrition, and irreversible routing.

FR8: Every committed player action must advance enemies and level systems.

FR9: Baseline player movement must allow 3 tiles per committed move action.

FR10: Baseline line of sight must be 4 tiles.

FR11: Baseline player HP must be 18.

FR12: Small levels must average around 8x8 tiles.

FR13: Levels must use fog of war where unexplored tiles are black and explored-but-out-of-LoS tiles remain as gray memory.

FR14: The player must have a universal basic attack shaped by the equipped weapon.

FR15: Attacks generally must require straight-line alignment unless a weapon or effect explicitly overrides that rule.

FR16: Starter ranged reach must remain intentionally low, around 4 tiles, so positioning remains important.

FR17: Enemies must not usually reveal exact intent, while major dangerous abilities may be telegraphed.

FR18: Elemental and affinity interactions must be able to affect play, including fire through burning fields, electricity through water, curse tradeoffs, and Darkness effects that alter visibility or memory pressure.

FR19: Sword baseline must be range 1, damage 4, adjacent targeting, and reliable melee damage.

FR20: Dagger baseline must be range 1, damage 2, adjacent targeting, low normal damage, and intended to become the strongest melee hit when Unseen.

FR21: Spear baseline must be range 2, damage 3, line melee targeting, and safer reach with lower damage than sword.

FR22: Axe baseline must be range 1, damage 3, adjacent targeting, and 35 percent chance to apply bleed if the target survives.

FR23: Mace baseline must be range 1, damage 3, adjacent targeting, and 35 percent chance to disorient if the target survives.

FR24: Bow baseline must be range 4, damage 3, line-of-sight targeting, and -30 percent damage against adjacent enemies.

FR25: Crossbow baseline must be range 3, damage 4, line-of-sight targeting, and knockback 1 when space allows.

FR26: Staff baseline must be range 4, damage 4, line-of-sight projectile targeting, with adjacent hits dealing half damage.

FR27: Wand baseline must be range 4, damage 2, instant line targeting, and must ignore walls and enemies.

FR28: Tome support baseline must provide no armor/block and must add +1 damage to staff and wand attacks.

FR29: Shield support baseline must provide 1 armor and a 50 percent chance to block half incoming physical damage.

FR30: Iron Cultist must act as a melee enemy with 10 HP, advancing toward the player and dealing 3 physical damage when adjacent.

FR31: Gate Brute must act as a heavier melee body with 12 HP using the prototype melee behavior.

FR32: Ash Seer must act as a caster with 8 HP that marks the player's tile from range 5 with LoS, then detonates on the next enemy turn for 4 damage if the player remains there.

FR33: Loot, consumables, pickups, gold, shops, reforging, and gambling must be able to shape each descent.

FR34: Passive pickups must open Consume / Destroy choices.

FR35: Risk/reward events must be able to ask the player to risk HP, curses, gold, future safety, secrets, corrupted rewards, sacrificial doors, or elite enemies for stronger outcomes.

FR36: Seeded run generation must reproduce major run structure, and manually entered seed runs must not grant meta progression.

FR37: Mobile movement input must allow the player to tap a visible reachable tile to preview movement cost and move.

FR38: Mobile attack input must allow the player to tap a visible enemy to preview weapon reach, path/line, expected damage, effects, blocker state, and warnings such as adjacency penalties.

FR39: Attacks must use deliberate two-step commit on mobile by default: second tap on the same target or a clear confirm button commits the attack.

FR40: Tap/hold or inspect must reveal tile, terrain, occupant, move cost, attack preview, hazard notes, and telegraphed danger.

FR41: Desktop input must preserve gameplay parity through mouse and keyboard support without changing rules.

FR42: The game must support interruption-friendly sessions and robust save/resume between levels.

FR43: The MVP run map must contain 8-12 nodes before the boss.

FR44: Each run must begin at the last outpost and descend through a node map.

FR45: Each node must lead to a generated level, event, shop, reforge, gambling, elite encounter, or boss.

FR46: Forward-only commitment must be enforced, with doors sealing behind the hero as a containment law.

FR47: Run pacing must distinguish early, mid, late, and finale phases: early teaches basic enemy literacy, mid introduces stronger passives/shops/reforge/gambling/elites, late increases affinity pressure and dangerous rewards, and finale presents the Larval Avatar.

FR48: The player should usually see at least one meaningful build-defining passive by the early-mid run.

FR49: Seeds must reproduce the run map, node structure, level layouts, affinity assignments, enemy placements, reward categories, major event outcomes, and boss/finale setup.

FR50: Manual seed entry must be allowed for replay, debug, sharing, and practice, but must grant no meta progression.

FR51: Level generation must prioritize readable tactical spaces over novelty.

FR52: Small levels must be around 8x8 tiles and appear mostly early or in compact special nodes.

FR53: Medium levels must be around 14x12 tiles and be introduced mid-run.

FR54: Large and Huge levels must be deferred for MVP polish unless needed for the boss or a rare special node.

FR55: Each combat level must have a clear entrance, a clear exit, enough blockers/cover to make line of sight matter, and at least one tactical wrinkle.

FR56: Fog must hide exact future danger without creating unfair instant punishment when new space is revealed.

FR57: Major facts must be seed-stable once generated or revealed; anything the player routes around or makes a strategic decision from must be deterministic and locked once visible.

FR58: Minor runtime variance may remain flexible for small drop rolls, combat proc rolls, or non-critical reward quantities.

FR59: Generator validation must verify entrance-to-exit path, no required class or item gates for mandatory progress, legal enemy placements, intended reachable rewards, and a first revealed area that cannot immediately punish the player without reasonable response.

FR60: Death must end the run and return the hero's spirit to the last outpost.

FR61: Meta progression must represent ancestral remembrance and restoration of lost warden capabilities.

FR62: MVP meta terminology must include Oath Shards as meta currency, Echoes as lore/codex discoveries, Seal Fragments as major seal/story unlocks, and Memory Archive, Hall of Oaths, Seal Table, Gate, or Descent Stair as meta spaces.

FR63: Non-seed-replay runs can grant Oath Shards, Echoes, Seal Fragments, class mastery progress, and unlock progress.

FR64: Manual seed runs must grant no meta progression, while remaining usable for replay, practice, debug, and sharing.

FR65: Meta progression must primarily unlock variety, knowledge, starting options, classes, passives, enemy information, affinity information, shops, scouting tools, and class mastery choices.

FR66: MVP meta progression must stay shallow, using a small unlock tree or menu rather than a deep account-power grind.

FR67: Direct meta power must be capped, scarce, and secondary to variety/knowledge/starting options; broad permanent damage, large HP/armor scaling, permanent crit/dodge stacking, early-level invalidation, and account-wide stat grind are avoided or deferred.

FR68: First death must reveal the loop with the line: "Good. You remembered how to die."

FR69: Run summary must show cause of death or victory, nodes cleared, boss/elite progress, passives consumed and destroyed, notable loot, Oath Shards earned, Echoes discovered, unlock progress, and seed with replay warning if manually used later.

FR70: MVP passive pool must contain 20-30 passives, including 3-5 weird rule-benders.

FR71: Passive rewards must be awakened memories, not generic perks, and should often use 3-choice moments.

FR72: Inventory must stay small, likely 6 backpack items, with no stacking by default.

FR73: Consumables must be semi-rare and should feel worth using.

FR74: Loot must include weapons, armor, jewelry, support items, consumables, pickups, passives, gold, and later affixes/enhancements.

FR75: Items must use character-level requirements rather than minimum run requirements.

FR76: Items must roll ranges, affixes, affinities, and enhancements rather than fixed item levels.

FR77: Every passive must serve at least one pillar: tactical clarity, build synergy, risk, or mystery.

FR78: Passive reward modal must include icon, evocative name, one short flavor line, exact mechanical effects, clear Consume choice, and clear Destroy choice.

FR79: Passive modal flavor may be mysterious, but mechanics must be explicit; Consume downsides, known Destroy benefits, and unknown Destroy consequences must be labeled honestly.

FR80: Consume must be for power and build identity; Destroy must be for safety, purification, resources, secrets, or refusal.

FR81: Destroy must be a meaningful alternative to Consume, not a dead button or default salvage choice.

FR82: MVP Destroy outcomes should use a distribution of 70 percent small immediate benefit, 20 percent progress/unlock/hidden flag, and 10 percent no obvious reward while avoiding corruption or future danger.

FR83: Destroy rewards may include Oath Shards, healing/cleanse, curse reduction, gold, temporary buff, improved future reward odds, class mastery/unlock progress, Echo discovery, hidden refusal path, or sealing a dangerous Labyrinth effect.

FR84: MVP starting classes must be Warrior, Pyromancer, and Ranger.

FR85: Future classes Necromancer and Shadeblade must be visible in hero select as grayed-out locked options.

FR86: Locked class UI must prevent selection, show clear unlock hints or requirements, and avoid implying full near-term content depth beyond MVP scope.

FR87: Classes must not start with active class skills at level 1.

FR88: Each class must start with one class passive and one equipment-synergy passive, nudging builds without forcing them.

FR89: Future class mastery and in-run talents may add active skills and deeper mechanics later.

FR90: Sealsworn must not have player-selectable difficulty tiers.

FR91: MVP difficulty must come from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, and boss preparation.

FR92: Daily challenges, leaderboards, online seeded challenges, and similar competitive or live-service features must be deferred.

FR93: Post-MVP challenge content may exist as explicit variant content, trials, oaths, or special runs, but not as a generic selectable difficulty ladder.

FR94: Progression unlock areas must include classes, loot pools, passives, enemies, secrets, codex entries, starting options, and class mastery.

FR95: Player power must come primarily from in-run buildcraft, while meta power can smooth onboarding only if capped and sparse.

FR96: MVP economy must be simple and readable first, using one or two sharp risk systems rather than making curses, corruption, gambling, reforge, sacrifice, shops, secrets, passive destruction, and affinity manipulation all equally deep.

FR97: MVP economy must include gold, scarce healing, curses/corruption, Oath Shards, passives, and loot as defined economy pillars.

FR98: Curses/corruption must be readable: curses have clear downsides, cursed rewards have clear upsides, and the player understands the trade before accepting.

FR99: Risk examples to support include strong passive for max HP loss, cursed item with future penalty, gold now for future elite chance, cheap reforge with corruption, Destroy to cleanse/reduce curse, and cursed nodes for better reward odds.

FR100: MVP node types must include combat, elite combat, shop, reforge, gambling, risk/reward event, secret or lore discovery, and boss.

FR101: Special nodes may be compact: shop, reforge, gambling, risk event, secret, or lore.

FR102: Combat levels must support positioning decisions, line-of-sight play, and at least one tactical wrinkle.

FR103: Mandatory progress must never require a specific class or item.

FR104: Exits must be clear, while hidden or secret exits may be added later.

FR105: Affinities must alter tactical choices, not just visuals.

FR106: MVP affinity set must include Scorched, Flooded/Conductive, Cursed, and Darkness.

FR107: Scorched affinity must express failed purge protocol through fire hazards, burning terrain, and damage-over-time pressure.

FR108: Flooded/Conductive affinity must express broken ward conduits through water/electric interactions, pathing pressure, and danger zones.

FR109: Cursed affinity must express corrupted oath-law through risk/reward, penalties, and dangerous bargains.

FR110: Darkness affinity must express failed concealment protocol through reduced visibility, hidden threats, uncertainty, and stronger fog/memory pressure.

FR111: Darkness must create uncertainty rather than cheap shots; it may reduce visibility, obscure enemy counts, hide rewards, distort explored memory, or empower enemies, but must not spawn unavoidable damage from unseen space.

FR112: The MVP must include readable asset support for 3 playable class portraits/icons or hero silhouettes, 2 locked class silhouettes/icons, 3 enemy-pattern visuals, 1 boss visual, 4 affinity treatments, Small/Medium Labyrinth tiles/props, baseline weapon/support icons, 20-30 passive icons or placeholder glyphs, tactical/outpost/run UI frames, core SFX, and ambient loops.

FR113: Sound effects must communicate movement, weapon hits, enemy actions, hazards, preview/confirm distinction, passive pickup, Consume, Destroy, curse/corruption, doors sealing, death, reward reveal, and boss victory.

FR114: UI sound must distinguish previews from committed actions.

FR115: Story discovery must be optional and support the loop, not carry it or require reading.

FR116: Every development epic must end in and preserve a playable milestone where the game launches, runs a small test loop, and validates the main experience.

Total FRs: 116

### Non-Functional Requirements

NFR1: Target platforms are iOS/Android mobile and tablet plus Windows desktop/laptop.

NFR2: The game must be mobile-first and desktop-playable, preserving the same rules across mobile, tablet, and desktop/laptop.

NFR3: The game loop must remain fun for players who ignore all lore.

NFR4: Cutscenes or control-loss narrative moments must be skippable.

NFR5: Successful MVP runs should usually land in the 20-35 minute target; failed runs often end around 5-15 minutes, and long/careful/completionist runs can stretch toward 45 minutes.

NFR6: Generated level load target is under 3 seconds for MVP.

NFR7: UI preview/selection response target is under 100ms.

NFR8: Stable 60 FPS is desired where feasible; 30 FPS is acceptable on lower-end mobile if input remains responsive.

NFR9: Combat input and tactical information must remain readable on phone-sized screens.

NFR10: First internal playable milestones may prioritize the fastest development build target, but architecture must preserve a native mobile packaging path from the start.

NFR11: Portrait is likely the main mobile phone play mode because it best supports quick, comfortable, interruption-friendly sessions.

NFR12: Landscape must be supported on mobile phones, tablets, and desktop/laptop screens.

NFR13: Landscape must not be a separate game mode; it must be the same tactical experience with more visible play space where possible.

NFR14: UI must adapt to wider aspect ratios by repositioning panels, controls, tooltips, and combat information so the board remains readable and uncluttered.

NFR15: Players must be able to zoom and inspect the level on all devices and orientations.

NFR16: Orientation changes must improve comfort and visibility without changing underlying rules.

NFR17: Runs must support interruption-friendly play.

NFR18: Save/resume between levels is required.

NFR19: Mid-level save/resume is desirable if feasible.

NFR20: MVP must be offline-first.

NFR21: MVP must have no accounts, multiplayer, cloud saves, leaderboards, or live-service dependency.

NFR22: Accessibility baseline must include scalable text.

NFR23: Accessibility baseline must include colorblind-safe danger communication.

NFR24: Accessibility baseline must include clear icons plus labels where needed.

NFR25: Accessibility baseline must include no reflex or timing requirements.

NFR26: Accessibility baseline must ensure all critical tactical information is available without relying on color alone.

NFR27: Passive and risk-choice mechanics must be explicit enough that mystery flavor does not obscure mechanical consequences.

NFR28: Visual direction must be stylized dark fantasy 2.5D with a top-down or slightly angled orthographic grid.

NFR29: Visuals must prioritize mobile clarity through readable silhouettes, clear tiles, clean effect language, and strong enemy shapes.

NFR30: Cosmic horror must appear as an undercurrent rather than constant spectacle.

NFR31: Wardenwork must read as relic-magic, not science fiction.

NFR32: Animation must be simple but expressive, including readable attacks, enemy movement, impact flashes, passive pickup pulses, doors sealing, and soul-return effects.

NFR33: Audio must prioritize crisp tactical feedback first and subtle horror ambience second.

NFR34: Music and ambience must not overpower tactical readability.

NFR35: MVP assets should prioritize tactical readability and reusable production value over content volume.

NFR36: No generator soft-locks are acceptable; every generated level must have a valid entrance-to-exit path.

NFR37: Players must be able to understand valid movement and attack options after a short first session.

NFR38: Players must be able to identify why they took damage or died.

NFR39: Players must understand the difference between preview and commit on mobile.

NFR40: Players must understand what Consume and Destroy do on passive rewards.

NFR41: Players should report that positioning choices matter.

NFR42: At least one meaningful build-defining passive should appear by early-mid run.

NFR43: Players should encounter at least one tempting risk/reward decision per run.

NFR44: Failed runs should feel like they taught something.

NFR45: Players should be able to name one memorable build, passive, risk, enemy, or moment after a run.

NFR46: A meaningful share of players should start a second run after death.

NFR47: Players should use at least two different weapon types across early sessions.

NFR48: Players should make both safe and risky choices across multiple runs.

NFR49: Players should consume some passives and destroy others rather than always choosing one option.

NFR50: Players should quit and resume successfully without confusion or lost progress.

Total NFRs: 50

### Additional Requirements

- Constraint: Production scope must stay narrow around Warrior, Pyromancer, Ranger, a limited enemy set, a limited affinity set, and 20-30 passives.
- Constraint: Ancient containment technology must read as relic-magic or Wardenwork, not science fiction.
- Constraint: Meta progression must expand variety and knowledge more than raw power.
- Constraint: Passives must be themed as awakened memories, oaths, scars, relic echoes, forbidden instincts, or broken protocols.
- Constraint: Affinities must be themed as failed containment protocols and safety measures.
- Constraint: Prototype Baseline v0 values are official first playable anchors but not final balance.
- Constraint: Larval Avatar is the only required MVP boss; First Sealbreaker is deferred unless later scope explicitly adds it.
- Constraint: No player-selectable difficulty tiers for MVP.
- Constraint: Online seeded challenges, leaderboards, daily challenges, and competitive/live-service features are deferred.
- Constraint: Manual seed runs are practice/sharing/replay/debug only and must not grant progression.
- Constraint: Large/Huge level generation polish is deferred unless needed for the boss or a rare special node.
- Constraint: Full five-class depth, deep class talent trees, hundreds of loot affixes, full elemental matrix, console/web/Mac/Linux targets, final art direction, full boss roster, complex AI intent prediction UI, multiplayer/online features, full lore bible, deep postgame narrative, permanent seal resolution, and science-fiction ancient technology are out of MVP scope.
- Remaining production design details: exact starting passives for Warrior, Pyromancer, and Ranger; first 20-30 passive designs; gold/healing/curse/corruption/shop/reforge/gambling rates; run-map node weighting and reward category frequencies; Larval Avatar encounter design; outpost screen layout and unlock tree/menu shape.
- Validation context: the GDD validation report found no critical or high failures, but warned that technical targets lack device tiers, memory/battery budgets, and measurement methods.
- Validation context: the GDD validation report warned that epics were adequate for architecture but not a final implementation story backlog at the time of the GDD freeze.
- Validation context: the GDD validation report warned that subjective terms such as fun, meaningful, and satisfying should become playtest-observable criteria during tuning and story breakdown.

### GDD Completeness Assessment

The GDD is complete enough to support architecture and implementation-readiness assessment. It contains a clear MVP loop, mechanical baselines, platform expectations, accessibility constraints, content scope, procedural generation rules, progression rules, economy direction, node/affinity scope, asset needs, out-of-scope boundaries, and success metrics.

The main readiness risks are not missing core vision; they are conversion risks. Several design areas are intentionally deferred into implementation stories or tuning work: exact class passives, passive library, economy rates, node weights, reward frequencies, Larval Avatar design, outpost/meta layout, target device tiers, and performance measurement method. These must be covered by implementation epics/stories or flagged before production starts.

## Epic Coverage Validation

### Epic FR Coverage Extracted

The canonical implementation epics/stories file contains its own 70-item FR inventory and a complete `FR Coverage Map`.

- Epic 1 covers epics FR2, FR3, FR4, FR5, FR6, FR7, FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22, FR23, FR24, FR25, and FR69.
- Epic 2 covers epics FR8, FR9, FR10, FR11, FR12, FR13, FR40, FR41, FR66, FR67, and FR68.
- Epic 3 covers epics FR27, FR29, FR35, FR36, FR37, FR38, and FR39.
- Epic 4 covers epics FR1, FR26, FR33, and FR34.
- Epic 5 covers epics FR42, FR43, FR44, and FR45.
- Epic 6 covers epics FR46, FR47, FR48, FR49, FR50, FR51, FR52, and FR53.
- Epic 7 covers epics FR54, FR55, FR56, FR57, and FR58.
- Epic 8 covers epics FR28, FR32, FR59, FR60, FR61, FR64, and FR65.
- Epic 9 covers epics FR31, FR62, and FR63.
- Epic 10 covers epics FR30 and FR70.

Total FRs in epics inventory: 70
Total epics FRs mapped to epics: 70
Epics internal FR coverage: 100 percent

### Coverage Matrix

| GDD FR | GDD Requirement | Epic Coverage | Status |
|---|---|---|---|
| FR1 | Complete rough roguelite loop | Epic 4 Stories 4.1-4.6; Epic 10 Story 10.6 | Covered |
| FR2 | Core gameplay loop from hero/loadout through another descent | Epic 4 Stories 4.1-4.6; Epic 8 Stories 8.1-8.6; Epic 10 Story 10.6 | Covered |
| FR3 | Single hero, seeded forward-only procedural levels, fog, tactics, rewards, passives, meta | Epics 1, 3, 4, 6, 7, 8 | Covered |
| FR4 | Defeat Larval Avatar for MVP victory | Epic 9 Stories 9.1-9.4 | Covered |
| FR5 | Hero death returns to last outpost | Epic 8 Story 8.1 | Covered |
| FR6 | Tactical clarity first, then build, route/risk, mystery | Epic 1 Story 1.11; Epic 2 Stories 2.1-2.6; Epic 10 Stories 10.4-10.6 | Covered |
| FR7 | Turn-based combat with no real-time pressure | Epic 1 Stories 1.2, 1.6, 1.9, 1.10 | Covered |
| FR8 | Committed actions advance enemies and level systems | Epic 1 Stories 1.6, 1.10; Epic 2 Story 2.3 | Covered |
| FR9 | Baseline movement budget is 3 tiles | Epic 1 Story 1.6 | Covered |
| FR10 | Baseline line-of-sight radius is 4 tiles | Epic 1 Story 1.7 | Covered |
| FR11 | Baseline player HP is 18 | Epic 1 Stories 1.2, 1.5; Epic 5 Story 5.3 | Covered |
| FR12 | Small levels average around 8x8 tiles | Epic 3 Story 3.2 | Covered |
| FR13 | Fog uses black unexplored and gray explored memory | Epic 1 Story 1.7 | Covered |
| FR14 | Universal basic attack shaped by equipped weapon | Epic 1 Stories 1.8, 1.9 | Covered |
| FR15 | Attacks generally require straight-line alignment unless overridden | Epic 1 Story 1.8 | Covered |
| FR16 | Starter ranged reach remains low around 4 tiles | Epic 1 Story 1.8 | Covered |
| FR17 | Exact enemy intent usually hidden, major dangerous abilities telegraphed | Epic 1 Story 1.10; Epic 9 Story 9.3 | Partial |
| FR18 | Elemental and affinity interactions can affect play | Epic 7 Stories 7.4, 7.5, 7.6 | Covered |
| FR19 | Sword baseline attack identity | Epic 1 Stories 1.8, 1.9 | Covered |
| FR20 | Dagger baseline attack identity | Epic 1 Stories 1.8, 1.9 | Covered |
| FR21 | Spear baseline attack identity | Epic 1 Stories 1.8, 1.9 | Covered |
| FR22 | Axe baseline attack identity and bleed proc | Epic 1 Stories 1.8, 1.9 | Covered |
| FR23 | Mace baseline attack identity and disorient proc | Epic 1 Stories 1.8, 1.9 | Covered |
| FR24 | Bow baseline attack identity and adjacent penalty | Epic 1 Stories 1.8, 1.9 | Covered |
| FR25 | Crossbow baseline attack identity and knockback | Epic 1 Stories 1.8, 1.9 | Covered |
| FR26 | Staff baseline attack identity and adjacent half damage | Epic 1 Stories 1.8, 1.9 | Covered |
| FR27 | Wand baseline ignores walls and enemies | Epic 1 Story 1.8 | Covered |
| FR28 | Tome support adds staff/wand damage | Epic 1 Story 1.9 | Covered |
| FR29 | Shield support grants armor and block | Epic 1 Story 1.9 | Covered |
| FR30 | Iron Cultist behavior | Epic 1 Story 1.10 | Covered |
| FR31 | Gate Brute behavior | Epic 1 Story 1.10 | Covered |
| FR32 | Ash Seer mark and delayed detonation | Epic 1 Story 1.10 | Covered |
| FR33 | Loot, consumables, pickups, gold, shops, reforge, gambling shape descents | Epic 4 Story 4.5; Epic 6 Stories 6.1-6.7; Epic 7 Stories 7.1-7.3 | Covered |
| FR34 | Passive pickups open Consume / Destroy choices | Epic 6 Stories 6.3-6.6 | Covered |
| FR35 | Risk/reward events can risk resources/future safety for stronger outcomes | Epic 7 Stories 7.1-7.3 | Covered |
| FR36 | Seeded run generation reproduces structure; manual seeds grant no meta | Epic 3 Story 3.7; Epic 4 Story 4.2; Epic 8 Story 8.3 | Covered |
| FR37 | Tap reachable tile to preview movement cost and move | Epic 2 Stories 2.2, 2.3 | Covered |
| FR38 | Tap enemy to preview weapon reach, line, damage, effects, blockers, warnings | Epic 2 Story 2.2 | Covered |
| FR39 | Mobile attacks use two-step commit by default | Epic 2 Story 2.3 | Covered |
| FR40 | Tap/hold or inspect reveals tactical information | Epic 2 Story 2.4 | Covered |
| FR41 | Desktop input preserves mouse/keyboard parity | Epic 2 Story 2.5 | Covered |
| FR42 | Interruption-friendly sessions and save/resume between levels | Epic 2 Stories 2.7, 2.8 | Covered |
| FR43 | Run map contains 8-12 nodes before boss | Epic 4 Story 4.2 | Covered |
| FR44 | Each run begins at last outpost and descends through node map | Epic 4 Stories 4.1-4.6; Epic 8 Story 8.6 | Covered |
| FR45 | Nodes lead to generated level/event/shop/reforge/gambling/elite/boss | Epic 4 Stories 4.4, 4.5 | Covered |
| FR46 | Forward-only commitment and doors sealing behind hero | Epic 4 Story 4.3 | Partial |
| FR47 | Run pacing has early, mid, late, and finale phases | Epic 3 Story 3.1; Epic 4 Stories 4.1-4.5; Epic 10 Story 10.1 | Partial |
| FR48 | Meaningful build-defining passive by early-mid run | Epic 6 Story 6.7; Epic 10 Story 10.4 | Partial |
| FR49 | Seeds reproduce run map, levels, affinities, placements, rewards, outcomes, boss setup | Epic 3 Stories 3.1-3.7; Epic 4 Story 4.2; Epic 9 Story 9.1; Epic 10 Story 10.2 | Covered |
| FR50 | Manual seed entry for replay/debug/sharing/practice with no meta | Epic 3 Story 3.7; Epic 8 Stories 8.2-8.4 | Covered |
| FR51 | Level generation prioritizes readable tactical spaces | Epic 3 Stories 3.1-3.7; Epic 10 Story 10.3 | Covered |
| FR52 | Small levels around 8x8 mostly early/compact | Epic 3 Story 3.2 | Covered |
| FR53 | Medium levels around 14x12 introduced mid-run | Epic 3 Story 3.3 | Covered |
| FR54 | Large/Huge deferred unless boss or rare special node needs them | Epic 3 scope and epics FR39 | Covered |
| FR55 | Combat levels have entrance, exit, blockers/cover, tactical wrinkle | Epic 3 Stories 3.1, 3.4, 3.6 | Covered |
| FR56 | Fog avoids unfair instant punishment when revealing space | Epic 3 Story 3.6; Epic 10 Story 10.3 | Covered |
| FR57 | Major strategic facts are seed-stable and locked once visible | Epic 3 Stories 3.1-3.7; Epic 4 Story 4.2; Epic 10 Story 10.2 | Covered |
| FR58 | Minor runtime variance allowed for limited rolls/quantities | Epic 1 Story 1.4; Epic 6 Story 6.1; Epic 7 Story 7.3 | Covered |
| FR59 | Generator validation checks pathing, gates, placements, rewards, safe reveal | Epic 3 Story 3.6; Epic 10 Story 10.3 | Covered |
| FR60 | Death ends run and returns spirit to outpost | Epic 8 Story 8.1 | Covered |
| FR61 | Meta progression represents ancestral remembrance/restoration | Epic 8 Stories 8.3-8.6 | Covered |
| FR62 | Oath Shards, Echoes, Seal Fragments, class mastery, unlock progress | Epic 8 Stories 8.2-8.7 | Covered |
| FR63 | Meta spaces include Memory Archive/Hall of Oaths/Seal Table/Gate/Descent Stair terms | Epic 8 Story 8.6 | Partial |
| FR64 | Eligible non-manual runs grant meta progress | Epic 8 Stories 8.3, 8.4 | Covered |
| FR65 | Meta progression unlocks variety, knowledge, starting options, classes, passives, info, shops, scouting, mastery | Epic 8 Stories 8.3-8.6 | Covered |
| FR66 | MVP meta stays shallow with small unlock tree/menu | Epic 8 Stories 8.3, 8.6 | Covered |
| FR67 | Direct meta power capped/scarce and broad stat grind avoided | Epic 8 Story 8.3 | Partial |
| FR68 | First death line | Epic 8 Story 8.5 | Covered |
| FR69 | Run summary fields | Epic 8 Story 8.2 | Covered |
| FR70 | Passive pool contains 20-30 passives and 3-5 weird rule-benders | Epic 6 Stories 6.1, 6.5, 6.7 | Covered |
| FR71 | Passives are awakened memories and should often use 3-choice moments | Epic 6 Stories 6.3, 6.4 | Partial |
| FR72 | Small inventory, likely 6 backpack items, no stacking by default | Epic 6 Story 6.2 | Covered |
| FR73 | Consumables are semi-rare and worth using | Epic 6 Stories 6.1, 6.7 | Partial |
| FR74 | Loot categories include weapons, armor, jewelry, supports, consumables, pickups, passives, gold, affixes/enhancements later | Epic 6 Story 6.1 | Covered |
| FR75 | Items use character-level requirements, not minimum run requirements | Not found | Missing |
| FR76 | Items roll ranges, affixes, affinities, and enhancements rather than fixed item levels | Epic 6 Story 6.1 mentions later affixes/enhancements through data boundaries | Partial |
| FR77 | Every passive serves at least one pillar | Not found as content-validation rule | Missing |
| FR78 | Passive modal includes icon, name, flavor, exact effects, Consume, Destroy | Epic 6 Story 6.4 | Covered |
| FR79 | Passive modal mechanics explicit and unknown consequences labeled honestly | Epic 6 Story 6.4 | Covered |
| FR80 | Consume means power/build identity; Destroy means safety/resources/secrets/refusal | Epic 6 Stories 6.5, 6.6 | Covered |
| FR81 | Destroy is meaningful alternative, not dead/default salvage button | Epic 6 Story 6.6 | Covered |
| FR82 | Destroy outcomes follow 70/20/10 distribution | Epic 6 Story 6.6 covers categories, not ratio | Partial |
| FR83 | Destroy rewards include cleanse/heal/gold/Oath Shards/reroll/hidden/etc. | Epic 6 Story 6.6; Epic 7 Story 7.2 | Covered |
| FR84 | Playable MVP classes are Warrior, Pyromancer, Ranger | Epic 5 Stories 5.1-5.3 | Covered |
| FR85 | Necromancer and Shadeblade visible locked/grayed | Epic 5 Stories 5.1, 5.2 | Covered |
| FR86 | Locked class UI prevents selection and shows unlock hints | Epic 5 Story 5.2 | Covered |
| FR87 | Classes do not start with active skills at level 1 | Epic 5 Story 5.4 | Covered |
| FR88 | Classes start with class passive and equipment-synergy passive | Epic 5 Stories 5.1, 5.3, 5.4 | Covered |
| FR89 | Future mastery/talents may add active skills later | Epic 5 Story 5.4 scope | Covered |
| FR90 | No player-selectable difficulty tiers | Not found | Missing |
| FR91 | MVP difficulty from run depth, enemies, affinities, elites, risk, attrition, boss prep | Epics 3, 4, 7, 9, 10 | Partial |
| FR92 | Daily challenges, leaderboards, online seeded challenges deferred | Epics NFR11; Epic 10 Stories 10.4, 10.6 | Covered |
| FR93 | Post-MVP challenges only as explicit variants/trials/oaths, not generic difficulty ladder | Not found | Missing |
| FR94 | Unlock areas include classes, loot pools, passives, enemies, secrets, codex, starting options, mastery | Epic 8 Stories 8.3-8.6 | Covered |
| FR95 | Player power primarily from in-run buildcraft; meta power capped/sparse | Epic 6; Epic 8 Story 8.3 | Partial |
| FR96 | MVP economy simple/readable with one or two sharp risk systems | Epic 7 Stories 7.1-7.3 | Covered |
| FR97 | MVP economy pillars are gold, healing, curses/corruption, Oath Shards, passives, loot | Epic 7 Story 7.1 | Covered |
| FR98 | Curses/corruption readable with clear downside/upside before accepting | Epic 7 Story 7.2 | Covered |
| FR99 | Risk examples: max HP loss, cursed item, gold for danger, reforge/corruption, cleanse, cursed node | Epic 7 Stories 7.2, 7.3; Epic 6 Story 6.6 | Covered |
| FR100 | MVP node types include combat, elite, shop, reforge, gambling, risk/reward, secret/lore, boss | Epic 4 Story 4.5 | Covered |
| FR101 | Special nodes can be compact | Epic 4 Story 4.5 | Covered |
| FR102 | Combat levels support positioning, LoS, tactical wrinkle | Epic 3 Stories 3.1-3.7 | Covered |
| FR103 | Mandatory progress never requires specific class/item | Epic 3 Stories 3.4, 3.6 | Covered |
| FR104 | Exits clear, hidden/secret exits later | Epic 3 Stories 3.1-3.6 | Covered |
| FR105 | Affinities alter tactical choices, not just visuals | Epic 7 Stories 7.4, 7.5 | Covered |
| FR106 | MVP affinities: Scorched, Flooded/Conductive, Cursed, Darkness | Epic 7 Story 7.4 | Covered |
| FR107 | Scorched fire hazards/burning/DoT pressure | Epic 7 Story 7.5 | Covered |
| FR108 | Flooded/Conductive water/electric/pathing/danger zones | Epic 7 Story 7.5 | Covered |
| FR109 | Cursed risk/reward penalties/bargains | Epic 7 Stories 7.2, 7.5 | Covered |
| FR110 | Darkness visibility/hidden threats/uncertainty/fog-memory pressure | Epic 7 Story 7.6 | Covered |
| FR111 | Darkness uncertainty without unavoidable unseen damage | Epic 7 Story 7.6; Epic 10 Story 10.3 | Covered |
| FR112 | MVP visual/UI/SFX/ambient asset baseline | Epics 2, 5, 6, 7, 9 mention UI/icon/visual tags only | Partial |
| FR113 | Sound effects for movement, hits, enemy actions, hazards, passive pickup, Consume, Destroy, curse, doors, death, rewards, boss victory | Not found | Missing |
| FR114 | UI sound distinguishes preview from committed actions | Epic 2 Story 2.6 covers distinction where audio is available | Partial |
| FR115 | Story discovery optional and not required for loop | Epic 8 Story 8.5 | Covered |
| FR116 | Every epic preserves playable milestone/build | Epic 10 Story 10.6 and all epic playable outcomes | Covered |

### Missing Requirements

No critical blockers were found for starting the domain-first MVP implementation sequence. The missing and partial items below should be added before the affected epics are implemented or before full MVP readiness is claimed.

#### High Priority Missing or Partial FRs

FR47: Run pacing has early, mid, late, and finale phases.
- Impact: Route, generation, reward, affinity, and boss work can be implemented independently without enforcing the intended run arc.
- Recommendation: Add acceptance criteria to Epic 4 and Epic 10 for early/mid/late phase bands, node weighting, reward category frequencies, affinity pressure progression, and boss preparation checks.

FR48: A meaningful build-defining passive should usually appear by early-mid run.
- Impact: Story 6.7 only requires at least one passive or loot offer, which can miss the stronger GDD requirement for build identity.
- Recommendation: Tighten Story 6.7 and Epic 10 playtest checks to require at least one meaningful build-defining passive by early-mid run in eligible generated run configurations.

FR67 / FR95: Direct meta power must be capped/scarce and player power should primarily come from in-run buildcraft.
- Impact: Epic 8 says shallow meta and no stat grind, but lacks concrete validation against broad permanent power inflation.
- Recommendation: Add content validation or readiness-gate criteria to Epic 8 that reject broad permanent damage, large HP/armor scaling, permanent crit/dodge stacking, and early-level invalidation.

FR75: Items use character-level requirements, not minimum run requirements.
- Impact: Item definitions could be implemented without the intended requirement model.
- Recommendation: Add this as an acceptance criterion to Story 6.1 item definition validation.

FR77: Every passive must serve at least one pillar.
- Impact: Passive content can pass mechanical validation while failing design purpose.
- Recommendation: Add passive content metadata and validation in Story 6.4 or Story 6.5 requiring each passive to declare at least one served pillar: tactical clarity, build synergy, risk, or mystery.

FR82: Destroy outcomes should follow 70 percent small immediate benefit, 20 percent progress/unlock/hidden flag, and 10 percent no-obvious-reward avoiding danger.
- Impact: Story 6.6 covers outcome categories but not the target distribution.
- Recommendation: Add distribution configuration/tests to Story 6.6 or clarify that exact percentages are tuning targets handled in Epic 10.

FR112 / FR113 / FR114: MVP asset and audio feedback baseline.
- Impact: Visual placeholders, UI icons, SFX cues, ambient loops, and preview/commit sound distinctions may be left outside implementation planning.
- Recommendation: Add a production asset/audio baseline story, likely after domain/input foundations but before MVP readiness, covering placeholder asset IDs, audio event mapping from domain events, muted-audio fallbacks, provenance/status requirements, and required MVP cue list.

#### Medium Priority Missing or Partial FRs

FR46: Forward-only commitment is covered, but door sealing behind the hero as a containment law is not explicitly covered as presentation/audio feedback.
- Recommendation: Add door sealing feedback to route/node transition presentation or the proposed asset/audio story.

FR63: Meta spaces are covered as generic outpost/meta menu, but named spaces such as Memory Archive, Hall of Oaths, Seal Table, Gate, or Descent Stair are not yet reflected.
- Recommendation: Treat as a UX/content naming task in Epic 8 once outpost layout is designed.

FR71: Passive rewards are covered, but "3-choice moments" are not explicitly enforced.
- Recommendation: Add reward-offer count/configuration criteria to Story 6.3, or explicitly mark 3-choice moments as tuning/content guidance.

FR73: Consumables are implemented, but "semi-rare and worth using" is not measurable.
- Recommendation: Add playtest/tuning checks in Epic 10 for consumable frequency, use rate, and player-perceived value.

FR76: Item affixes/enhancements are mentioned as later data boundaries, but roll ranges/affinities/enhancements versus fixed item levels are not fully specified.
- Recommendation: Add item stat/roll model criteria to Story 6.1 if item rolls are in MVP; otherwise explicitly defer advanced rolls while preserving data boundaries.

FR91: Difficulty sources are distributed across epics, but the no-difficulty-tier model is not explicitly asserted in readiness gates.
- Recommendation: Add a settings/readiness check that no selectable difficulty ladder appears in MVP.

#### Low Priority Missing or Non-Goal Enforcement

FR90: No player-selectable difficulty tiers.
- Impact: This is a non-goal, but the future settings flow could accidentally introduce it.
- Recommendation: Add a negative readiness check in Epic 10.6 or a settings story.

FR93: Post-MVP challenge content must be explicit variants/trials/oaths, not a generic difficulty ladder.
- Impact: This is post-MVP guidance and does not block domain-first MVP implementation.
- Recommendation: Record as deferred post-MVP design guardrail unless a challenge/settings story is created.

### Epics Requirements Not Directly From GDD

The implementation epics add architecture-derived requirements not explicitly labeled as GDD FRs. These are aligned with `project-context.md` and `_bmad-output/game-architecture.md`, not conflicts:

- Production Godot 4.6.3 typed GDScript project under `godot/`.
- Scene-independent domain model as tactical truth.
- Validated commands returning `ActionResult`.
- Deterministic past-tense `DomainEvent` records.
- Named RNG streams.
- Tactical query services for pathfinding, line of sight, threat maps, valid moves, attack previews, and tile scoring.
- Explainable enemy AI decisions.
- Versioned domain snapshots for saves.
- Repository/import boundaries for static content.
- Headless simulation and test harness requirements.

### Coverage Statistics

- Total GDD FRs extracted: 116
- Fully covered GDD FRs: 97
- Partially covered GDD FRs: 14
- Missing GDD FRs: 5
- Full coverage percentage: 83.6 percent
- Traceable coverage including partials: 95.7 percent

## UX Alignment Assessment

### UX Document Status

No standalone UX design document was found.

Searches checked:

- `C:/Sealsworn/_bmad-output/planning-artifacts/*ux*.md`
- `C:/Sealsworn/_bmad-output/planning-artifacts/*ux*/index.md`
- UI/UX-related terms inside GDD, implementation epics, and architecture

UX is clearly implied by the GDD and implementation epics. Required player-facing flows include:

- Hero select with playable and locked classes.
- Tactical HUD.
- Movement preview, attack preview, confirm/cancel, inspect, and zoom.
- Passive reward modal with Consume and Destroy.
- Run map and route choice.
- Shop, reforge, gambling, risk/reward, secret/lore, and boss node placeholder flows.
- Outpost/meta menu.
- Run summary.
- Settings.
- Save/resume and resume recovery.
- Accessibility/readability support for scalable text, colorblind-safe danger communication, no color-only critical information, and no reflex/timing requirements.
- Phone portrait, phone landscape, tablet, and desktop-style layouts.

### UX to GDD Alignment

The GDD contains strong UX requirements even without a standalone UX artifact:

- Mobile-first preview and two-step commit are defined as core input behavior.
- Inspect and zoom are required across devices and orientations.
- Phone-sized readability is a first-order requirement.
- Passive modal content is explicitly specified.
- Locked class presentation rules are explicit.
- Save/resume and interruption-friendly sessions are required.
- Accessibility requirements are explicit.
- UI flows are listed in the asset/UI baseline.

No UX-vs-GDD contradiction was found.

### UX to Architecture Alignment

Architecture support is strong:

- Architecture defines an adaptive UI composition system with view models, presenters, layout profiles, and a command bridge.
- UI observes domain state and submits commands, while domain state remains authoritative.
- `UiMode` explicitly includes neutral, movement preview, attack preview, inspect, inventory, route map, reward choice, and modal confirmation.
- Godot `Control` nodes, containers, themes, and `CanvasLayer` are selected for tactical HUDs, menus, modals, and scalable layouts.
- Layout profiles cover phone portrait, phone landscape, tablet, and desktop.
- Performance targets include under-100ms preview/selection response and phone readability.
- Accessibility is represented in architecture, epics, and readiness gates.
- Save/resume is architected through domain snapshots rather than scene state, supporting interruption-friendly UX.
- `PresentationMapper` maps domain events to animations, UI, audio, and feedback without making presentation authoritative.

No architecture-vs-UX contradiction was found.

### Alignment Issues

- No standalone UX document exists. This is non-blocking for the domain-first MVP start, but it becomes a blocker before heavy UI scene production because several screens need layout decisions, hierarchy, and interaction details.
- Exact tactical HUD layout, route map layout, passive modal layout, settings layout, outpost/meta layout, and run-summary layout are not specified outside story acceptance criteria.
- Exact outpost screen layout and unlock tree/menu shape remain deferred production design details.
- Settings are listed as a required UI flow, but there is no dedicated settings story or acceptance criteria yet.
- Audio feedback is architecturally supported, but the implementation epics do not yet include a full audio/SFX cue story for the GDD-required movement, combat, hazard, passive, curse, door, death, reward, and boss-victory cues.
- Asset and UI frame requirements are architecturally supported through asset pipeline and folder conventions, but implementation epics do not yet plan the full MVP visual/UI/audio asset baseline.
- Technical device tiers, measurement methods, memory budgets, and battery/performance expectations remain a production-readiness gap, which affects UX validation on mobile.

### Warnings

- Warning: Missing UX document is acceptable for starting domain-first implementation, but not for UI-heavy production beyond the early command/view-model contracts.
- Warning: Before implementing polished tactical scenes, create at least lightweight UX artifacts for tactical HUD, preview/confirm states, inspect panel, passive modal, run map, outpost/meta, run summary, settings, and save/resume recovery.
- Warning: UX validation must include rendered checks, not only headless tests, because architecture correctly notes that UI readability, animation quality, player feel, sound timing, and visual polish require rendered playtests.
- Warning: Add a negative settings/readiness criterion that no selectable difficulty ladder appears in MVP.

## Epic Quality Review

### Review Scope

- Canonical implementation epics/stories reviewed: `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md`
- Epics reviewed: 10
- Stories reviewed: 68
- Stories with acceptance criteria sections: 68
- Explicit FR coverage map present: yes
- Forward dependency violations found: none
- Critical technical-epic violations found: none

### Epic Structure Validation

| Epic | Player/User Value | Independence | Story Sizing | Acceptance Criteria | Result |
|---|---|---|---|---|---|
| Epic 1: Core Tactical Combat Slice | Strong player outcome, but includes technical enabler stories | Stands alone as first playable slice | Mixed | Strong | Pass with concerns |
| Epic 2: Mobile UX, Accessibility, and Save/Resume Foundation | Strong player outcome | Uses only Epic 1 output | Good | Strong | Pass |
| Epic 3: Procedural Level Generation v0 | Strong player outcome | Uses prior combat/UX constraints | Mixed | Strong | Pass with concerns |
| Epic 4: Run Map and Forward Progression | Strong player outcome | Uses generated levels from Epic 3 | Good | Good | Pass |
| Epic 5: Classes and Starting Kits | Strong player outcome | Uses combat/run start output | Good | Strong | Pass |
| Epic 6: Loot, Passives, and Consume/Destroy | Strong player outcome | Uses class/run outputs | Mixed | Good | Pass with concerns |
| Epic 7: Risk Economy and Affinities | Strong player outcome | Uses reward/generation outputs | Mixed | Good | Pass with concerns |
| Epic 8: Outpost, Meta Progression, and Run Summary | Strong player outcome | Uses run completion/reward outputs | Good | Strong | Pass |
| Epic 9: Larval Avatar MVP Finale | Strong player outcome | Uses prior tactical/run/risk systems | Mixed | Strong | Pass with concerns |
| Epic 10: Playtest Tuning and MVP Readiness | Indirect player outcome through stability/readiness | Depends on Epics 1-9 as final validation | Mixed | Good | Pass with concerns |

### Critical Violations

None found.

No epic is a purely technical milestone with no player/user value. Epic 1 contains several technical foundation stories, but the epic itself delivers a playable tactical combat slice and the greenfield Godot project requires initial setup. This is acceptable as long as those enabler stories remain tied to the playable slice.

No forward dependencies were found. Stories use prior stories or prior epics; none require a later story to be complete before they can function.

### Major Issues

#### M1: Early Build/Export Pipeline Is Not Planned Early Enough

Finding: Story 1.1 initializes the Godot project and headless test harness, but it does not include local build/export preset setup. Architecture and project-context expect native mobile packaging to be preserved from the start, and the greenfield checklist expects build pipeline setup early.

Impact: Mobile-first constraints can drift if export presets, platform build assumptions, and pre-export checks are postponed until Epic 10.

Recommendation: Add an early story, or extend Story 1.1, to create baseline `project.godot`, architecture folders, test command, and initial local export/build scaffolding or documented export preset plan for Android/Windows, with iOS deferred until macOS/Xcode is available.

#### M2: Several Stories Are Large Enough To Hide Implementation Risk

Finding: These stories combine multiple substantial behaviors or test obligations:

- Story 1.8: nine weapon definitions, targeting legality, blocker overrides, adjacency penalties, preview purity, and preview/command contract tests.
- Story 1.9: attack command, damage events, invalid/no-mutation cases, weapon proc effects, support effects, and contract tests.
- Story 1.10: enemy turn loop, enemy command adapter, three prototype enemy behaviors, utility explanations, and deterministic tests.
- Story 3.6: validation, bounded retry, good/bad fixtures, phase-level regression, and diagnostics.
- Story 6.1: item, loot, reward definitions, repository validation, deterministic reward rolls, and category coverage.
- Story 7.5: Scorched, Flooded/Conductive, and Cursed tactical effects in one story.
- Story 9.3: boss telegraphs, action resolution, AI decisions, reproducibility, and damage explanations.
- Story 10.6: full MVP readiness gate, test-suite gate, pre-export validation, offline-first/no-cloud checks, and debug/cheat gating.

Impact: These may be valid epic-level story placeholders, but they are likely too broad for implementation sprint execution without splitting into sub-stories/tasks.

Recommendation: Before sprint execution, split these into smaller implementation stories or task checklists while preserving the current traceability. Keep the current stories as parent stories if needed.

#### M3: Placeholder Language Risks Becoming Accepted MVP Scope

Finding: Some acceptance criteria intentionally use placeholder paths:

- Story 4.5 allows unsupported node implementations to route to safe placeholder resolution.
- Story 4.5 allows boss placeholder completion before Epic 9.
- Story 7.5 allows Flooded/Conductive electric interaction placeholders.
- Story 8.2 allows unavailable future summary fields as zero/empty/not-yet-supported.

Impact: Placeholders are useful for preserving playable builds, but they need explicit replacement or de-scoping checkpoints so MVP readiness is not claimed with placeholder gameplay in required systems.

Recommendation: Add "placeholder allowed until" notes or Epic 10 readiness checks that verify required MVP placeholders have been replaced, intentionally deferred, or documented as acceptable MVP limitations.

#### M4: Tuning and Player-Experience Criteria Need Concrete Thresholds

Finding: Several acceptance criteria use qualitative terms without thresholds or decision rules: "meaningful", "worth using", "accepted thresholds", "playable", "readable", "stable", "fair culmination", and "wants another descent".

Impact: These are appropriate playtest goals but weak implementation gates unless each has an observable measure or review method.

Recommendation: Add story notes or Epic 10 criteria that define measurement method, target device tiers, seed sample sizes, failure thresholds, playtest observation format, and who can approve subjective feel findings.

### Minor Concerns

#### m1: Developer-Framed Stories Are Acceptable But Should Stay Tied To Player Value

Stories 1.1, 1.3, 1.4, and 1.5 are written as developer stories. This is acceptable for the greenfield domain-first foundation, but they should not expand into infrastructure work disconnected from the playable tactical slice.

Recommendation: Keep their playable/testable outcomes mandatory and avoid adding broad framework work to them.

#### m2: Epic 10 Is A Readiness Epic, Not A Direct Gameplay Feature

Epic 10 is justified by the GDD and delivers player value through stability, readability, and playtest readiness. Its title and some stories are production-facing rather than player-action-facing.

Recommendation: Keep Epic 10, but treat it as a readiness gate epic. Avoid adding new gameplay scope there unless it fixes a measured readiness failure.

#### m3: Settings Flow Is Under-Specified

The requirements inventory includes settings, and UX alignment identified difficulty-tier non-goal enforcement. No dedicated settings story exists.

Recommendation: Add a small settings/accessibility story or extend Epic 2/Epic 10 with settings acceptance criteria for text scale, audio/mute, input preferences, and no selectable difficulty tiers.

#### m4: Asset And Audio Stories Are Missing From The Story Set

This overlaps with FR coverage findings. The architecture has an asset pipeline and audio mapping concept, but the story set does not plan the MVP asset/audio cue baseline.

Recommendation: Add an asset/audio implementation story or explicitly defer production audio/art while defining placeholder IDs and source/provenance metadata requirements.

### Dependency Analysis

Within-epic dependencies are sequential and acceptable:

- Epic 1 builds from project/test harness to board state, commands/events, RNG, snapshots, movement, visibility, attack, enemies, and outcome feedback.
- Epic 2 builds on Epic 1 domain state through view models, command bridge, preview presentation, two-step commit, inspect/zoom, layout, accessibility, and save/resume.
- Epic 3 builds generation requests, Small/Medium layouts, wrinkles, placement, validation, and seed regression without depending on future run-map or reward depth.
- Epic 4 turns prior generated/tactical capability into a route shell with safe placeholders, then later epics replace placeholders.
- Epics 5-9 add classes, loot/passives, risk/affinity, meta/outpost, and finale in dependency order.
- Epic 10 explicitly depends on Epics 1-9 because it is a final validation/readiness gate.

No circular dependencies were found.

### Data/Entity Creation Timing

Data creation timing is mostly correct:

- Board structures appear when tactical state needs them.
- Commands/events appear before movement/attack/enemy actions use them.
- RNG streams appear before gameplay randomness is required.
- Weapon/support definitions appear with attack previews and commands.
- Class definitions appear when hero select and starting kits need them.
- Item/passive/reward definitions appear when loot/passive flows begin.
- Affinity definitions appear when affinity assignment and effects begin.
- Boss definitions appear when Larval Avatar implementation begins.

No "create all data upfront" violation was found.

### Best Practices Compliance Checklist

| Check | Result |
|---|---|
| Epics deliver player/user value | Pass with technical-enabler exceptions in Epic 1 |
| Epic independence / no future-epic dependency | Pass |
| Stories appropriately sized | Mixed |
| No forward dependencies | Pass |
| Data structures created when needed | Pass |
| Clear acceptance criteria | Pass with threshold concerns |
| Traceability to FRs maintained | Pass with coverage gaps documented in Step 03 |

## Summary and Recommendations

### Overall Readiness Status

NEEDS WORK.

Sealsworn is conditionally ready to begin domain-first implementation for the earliest foundation work: Godot project initialization, folder scaffolding, headless test harness, domain model, commands/events, named RNG streams, tactical board model, movement, fog, attack previews, and initial combat tests.

It is not yet ready to claim full MVP implementation readiness without backlog cleanup. The core vision, architecture, and epic sequence are coherent, but the implementation story set has missing/partial GDD coverage, missing standalone UX artifacts, broad stories that should be split before sprint execution, and a few production-readiness gaps.

### Critical Issues Requiring Immediate Action

No critical blockers were found for starting domain-first Epic 1 work.

Immediate action is still required before broad MVP implementation:

1. Add or amend stories for missing/partial GDD coverage: item character-level requirements, item roll model, passive pillar validation, Destroy outcome ratio, no selectable difficulty tiers, post-MVP challenge guardrails, MVP asset/audio baseline, run pacing, early-mid build-defining passive, and meta power caps.
2. Add early build/export scaffolding or explicit export preset planning to Story 1.1 or a new early setup story.
3. Split oversized implementation stories before sprint execution, especially weapon/attack/enemy/generator/reward/affinity/boss/readiness stories.
4. Define lightweight UX artifacts before UI-heavy scene work: tactical HUD, preview/confirm states, inspect panel, passive modal, run map, outpost/meta, run summary, settings, and save/resume recovery.
5. Define target device tiers, measurement methods, seed sample sizes, memory/battery expectations, and qualitative playtest approval rules.

### Consolidated Issue Areas

1. Missing FR coverage: 5 GDD FRs have no implementation story coverage.
2. Partial FR coverage: 14 GDD FRs are only partially covered.
3. UX documentation: no standalone UX document exists despite substantial player-facing UI requirements.
4. Asset/audio planning: architecture supports assets/audio, but implementation stories do not yet plan the required MVP visual/UI/SFX/ambient baseline.
5. Settings/non-goal enforcement: settings are implied, but no story verifies text scale/audio/input options or no selectable difficulty ladder.
6. Build/export setup: native mobile packaging path is required, but early export/build scaffolding is not in the initial setup story.
7. Story sizing: several stories are too broad for low-risk sprint execution.
8. Placeholder control: placeholder node, boss, affinity, and summary behavior needs explicit replacement/de-scope checkpoints.
9. Tuning thresholds: qualitative criteria need measurement rules or review methods.
10. Production detail deferrals: class passives, passive library, economy rates, node weights, reward frequencies, boss design, and outpost layout remain deferred.
11. Mobile validation: device tiers, memory/battery budgets, and measurement methods are not yet defined.
12. UI timing: domain-first work can proceed, but UI-heavy scene production should wait for UX artifacts or explicit layout decisions.

### Recommended Next Steps

1. Amend `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md` with a small backlog patch covering missing/partial FRs identified in this report.
2. Add a lightweight UX design artifact or UX appendix before implementing UI-heavy scenes.
3. Split the broadest stories into implementation-ready child stories or task checklists while preserving the current parent-story traceability.
4. Add an early Godot setup/build/export story that preserves the native mobile packaging path from the start.
5. Add an asset/audio baseline story or explicitly defer production assets/audio while defining placeholder IDs, metadata, and provenance rules.
6. Define Epic 10 readiness thresholds: device tiers, performance measurement methods, memory/battery expectations, seed sample sizes, playtest checklist format, and acceptable failure thresholds.
7. Proceed with Epic 1 domain-first implementation only after confirming these gaps are accepted as follow-up backlog work, not hidden scope.

### Final Note

This assessment identified 12 consolidated issue areas across document discovery, GDD-to-epic coverage, UX alignment, and epic quality. The artifacts are strong enough to start the first domain-first implementation slice, but they need targeted backlog and UX/readiness cleanup before full MVP production can be considered implementation-ready.

Assessor: Codex using `gds-check-implementation-readiness`
Assessment date: 2026-06-04

## Current Reassessment Against Updated Epics

Assessment update: 2026-06-04, against `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md` modified 2026-06-04 12:47:09.

This section supersedes the earlier readiness summary where it conflicts with the current epics file. The earlier sections remain as audit history for the findings that drove the backlog patch.

### Updated Document State

- Canonical GDD remains `C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md`.
- Canonical architecture remains `C:/Sealsworn/_bmad-output/game-architecture.md`.
- Canonical implementation epics/stories remain `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md`.
- No standalone UX document exists.
- Current implementation epics contain 10 epics, 70 stories, and 70 acceptance-criteria sections.

### Updated Coverage Findings

The current `epics.md` includes a `2026-06-04 Readiness Backlog Patch Traceability` section mapping the prior missing or partial GDD items to amended stories:

- Door sealing / containment-law feedback: Story 4.4 and Story 10.7.
- Early/mid/late/finale pacing and run-length targets: Story 4.6 and Story 10.4.
- Early-mid build-defining passive: Story 6.7 and Story 10.4.
- Named outpost/meta spaces: Story 8.6.
- Passive 3-choice moments: Story 6.3.
- Semi-rare, worth-using consumables: Story 6.7 and Story 10.4.
- Item character-level requirements and item roll model: Story 6.1.
- Passive pillar validation: Story 6.4.
- Destroy outcome 70/20/10 distribution: Story 6.6.
- No selectable difficulty tiers and post-MVP challenge guardrails: Story 2.9 and Story 10.6.
- Capped, sparse meta power: Story 8.3.
- MVP visual/audio baseline and preview/commit cue mapping: Story 10.7.

No remaining GDD coverage gap blocks domain-first implementation.

### Updated Quality Findings

Critical violations: none.

Major blockers to starting Epic 1 domain-first work: none.

Remaining non-blocking controls:

- No standalone UX document exists. This is acceptable for Epic 1 domain-first work and view-model/command-bridge contracts, but Story 10.7 now makes a lightweight UX appendix or equivalent notes mandatory before UI-heavy scene production.
- Several broad stories should be split or task-managed before sprint execution, especially weapon/attack preview, prototype enemy resolution, generator validation, tactical affinity effects, boss action/telegraph logic, and asset/audio readiness.
- Final MVP readiness still depends on executing the Epic 10 gates: device tiers, performance/memory/battery checks, seed regression sample sizes, playtest thresholds, accessibility audits, placeholder replacement/de-scope, and pre-export validation.

### Updated Overall Readiness Status

READY_WITH_GATES.

Sealsworn is ready to begin the domain-first implementation sequence: Godot project setup, folder scaffolding, headless test harness, domain state, commands/results/events, named RNG streams, tactical board model, movement, fog/LoS, attack previews, initial combat, and related tests.

It is not ready to skip the planning gates. UI-heavy scene production must wait for the UX appendix or equivalent notes, and full MVP readiness must wait for the Epic 10 validation gates to be executed.

### Updated Recommended Next Steps

1. Proceed with Epic 1 domain-first implementation.
2. Split broad stories into sprint-sized child stories or concrete task checklists before assigning them for implementation.
3. Create lightweight UX notes before UI-heavy scene work begins.
4. Preserve the native mobile packaging path through Story 1.1 export/build planning.
5. Treat Epic 10 readiness gates as mandatory before claiming MVP implementation readiness.

### Updated Final Note

The updated epics/stories now account for the previous critical readiness gaps. The project should move into implementation carefully, starting with the model, command/event flow, RNG streams, tactical board, and headless tests before presentation-heavy work.
