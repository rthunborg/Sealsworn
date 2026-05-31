# Sealsworn - Development Epics

**Status:** Express v0 draft
**Created:** 2026-05-31
**Updated:** 2026-05-31

This file holds the detailed development-epic breakdown for the Sealsworn MVP. The GDD carries only the summary table and recommended sequence.

## Epic Rules

- Every epic must end in a playable milestone.
- Every epic must preserve a playable build: the game should still launch, run a small test loop, and validate the main experience after each milestone.
- Mobile readability, input safety, accessibility, and save/resume are not late polish; they are checked throughout the sequence.
- Every player-facing mechanic in the GDD must land in at least one epic.
- Scope is grouped by playable value rather than tidy system categories.

## Epic Sequence

| Sequence | Epic | Playable Outcome |
|---|---|---|
| 1 | Core Tactical Combat Slice | Movement, line of sight, fog, weapon-shaped attacks, enemy turns, damage, death/win state, and mobile preview/confirm input work from the start. |
| 2 | Mobile UX, Accessibility, and Save/Resume Foundation | Portrait/landscape layout tests, zoom/inspect, phone readability, two-step commit, scalable text, colorblind-safe tactical info, and between-level save/resume foundation. |
| 3 | Procedural Level Generation v0 | Small/Medium levels generate with validation, entrance/exit, blockers, tactical wrinkles, and seed stability. |
| 4 | Run Map and Forward Progression | 8-12 node run structure, route choice, node types, forward-only commitment, and boss node work as a playable run shell. |
| 5 | Classes and Starting Kits | Warrior, Pyromancer, and Ranger are playable; Necromancer and Shadeblade appear locked/grayed; each class has a passive and equipment-synergy passive. |
| 6 | Loot, Passives, and Consume/Destroy | 20-30 passives, modal clarity, Destroy outcomes, loot basics, inventory, and consumables shape builds. |
| 7 | Risk Economy and Affinities | Gold, healing, curses/corruption, Scorched, Flooded/Conductive, Cursed, and Darkness create readable tactical risk. |
| 8 | Outpost, Meta Progression, and Run Summary | Oath Shards, Echoes, unlocks, first-death line, run summary, and seed replay warning close the return loop. |
| 9 | Larval Avatar MVP Finale | Boss encounter, victory, first-victory reveal, and post-victory return loop complete the first finale. |
| 10 | Playtest Tuning and MVP Readiness | Success metrics, balance passes, generator soft-lock checks, device checks, and first playable test loop are ready. |

---

## Epic 1 - Core Tactical Combat Slice

**Goal:** Prove that the moment-to-moment tactical board is readable and fun before the surrounding roguelite structure grows around it.

**Includes:**

- Grid movement with Prototype Baseline v0 values: 3-tile movement, 4-tile line of sight, 18 player HP.
- Fog of war: black unexplored tiles and gray explored memory.
- Weapon-shaped basic attacks for the baseline weapon list.
- Iron Cultist, Gate Brute, and Ash Seer as first enemy-pattern tests.
- Enemy turns and level systems advancing after committed player actions.
- Damage, death, simple victory state, combat log or equivalent feedback.
- Mobile tap-to-preview and second-tap/confirm-to-commit attack flow from the start.

**Out of Scope:**

- Full run map.
- Meta progression.
- Large content pools.
- Final art/audio.

**Dependencies:** Existing prototype combat work.

**Playable Deliverable:** A player can launch a small tactical test level, move, inspect, attack, understand enemy response, win or die, and identify why damage occurred.

---

## Epic 2 - Mobile UX, Accessibility, and Save/Resume Foundation

**Goal:** Make the tactical slice mobile-first before major systems depend on desktop-only assumptions.

**Includes:**

- Portrait and landscape layout tests for phone-sized screens.
- Desktop/tablet layout adaptation using the same rules.
- Zoom and inspect controls on all devices and orientations.
- Two-step commit for attacks, with preview/commit sound and visual distinction.
- Scalable text and readable tactical information.
- Colorblind-safe danger communication and non-color-only critical information.
- Between-level save/resume foundation.

**Out of Scope:**

- Cloud saves.
- Accounts.
- Online features.
- Full settings suite beyond essential accessibility/input needs.

**Dependencies:** Epic 1 combat loop.

**Playable Deliverable:** A player can play the tactical slice on a phone-sized viewport, inspect key information, avoid mis-tap commits, rotate orientation without rule changes, and safely resume between levels.

---

## Epic 3 - Procedural Level Generation v0

**Goal:** Generate readable tactical spaces that support line-of-sight play, fog, and at least one tactical wrinkle per combat level.

**Includes:**

- Small levels around 8x8 and Medium levels around 14x12.
- Seed-stable level layouts, affinity assignments, enemy placements, reward categories, and major outcomes.
- Entrance, exit, blockers/cover, and tactical wrinkle placement.
- Generator validation: entrance-to-exit path, no required class/item gates, legal enemy placement, reachable intended rewards, safe first reveal.
- Manual seed entry for replay, debug, sharing, and practice with no meta progression.

**Out of Scope:**

- Large/Huge level polish.
- Full biome variety.
- Deep procedural event chains.

**Dependencies:** Epic 1 combat rules; Epic 2 readability constraints.

**Playable Deliverable:** A player can load multiple seed-stable Small/Medium levels that pass validation and produce readable tactical decisions.

---

## Epic 4 - Run Map and Forward Progression

**Goal:** Turn individual generated levels into a forward-only roguelite descent.

**Includes:**

- 8-12 node run map before the boss.
- Node types: combat, elite, shop, reforge, gambling, risk/reward event, secret/lore, boss.
- Partial route information and visible node clues.
- Forward-only commitment; no backtracking.
- Run pacing: early, mid, late, finale.
- Boss node placeholder for Larval Avatar.

**Out of Scope:**

- Deep event writing.
- Final run-map art.
- Online seed challenge features.

**Dependencies:** Epic 3 level generation.

**Playable Deliverable:** A player can choose routes, enter nodes, exit forward, and reach a boss placeholder or run end.

---

## Epic 5 - Classes and Starting Kits

**Goal:** Make the initial hero choices create distinct tactical openings without overwhelming the MVP.

**Includes:**

- Warrior, Pyromancer, and Ranger selectable.
- Necromancer and Shadeblade visible as grayed-out locked classes with clear unlock hints.
- Each playable class starts with one class passive and one equipment-synergy passive.
- Starting kits nudge builds but do not force them.
- Basic class identity in hero select and run start.

**Out of Scope:**

- Active class skills at level 1.
- Deep class talent trees.
- Full Necromancer and Shadeblade implementation.

**Dependencies:** Epic 1 combat; Epic 4 run start flow.

**Playable Deliverable:** A player can choose one of three classes, start a run, and feel a different tactical/build nudge immediately.

---

## Epic 6 - Loot, Passives, and Consume/Destroy

**Goal:** Prove that runs develop memorable build identity through loot and awakened-memory choices.

**Includes:**

- 20-30 MVP passives, including 3-5 weird rule-benders.
- Passive modal with icon, evocative name, flavor line, exact mechanical effects, Consume, and Destroy.
- Destroy outcomes: small immediate rewards, progress/unlock/hidden flags, or avoiding corruption/future danger.
- Basic loot categories: weapons, armor, jewelry, support items, consumables, pickups, passives, gold.
- Small inventory, likely 6 backpack items with no stacking by default.
- Semi-rare consumables that feel worth using.

**Out of Scope:**

- Hundreds of affixes.
- Deep item-level economy.
- Full passive library beyond MVP.

**Dependencies:** Epic 5 class starts; Epic 4 run progression.

**Playable Deliverable:** A run can develop a recognizable build through passive choices, loot, and Consume/Destroy decisions.

---

## Epic 7 - Risk Economy and Affinities

**Goal:** Add readable danger and temptation without drowning MVP balance in too many economies.

**Includes:**

- Gold, healing, curses/corruption, Oath Shard eligibility, passives, and loot as MVP economy pillars.
- Curses/corruption as the primary risk layer.
- Risk examples: strong passive for max HP loss, cursed item with future penalty, gold now for elite chance later, cheap reforge with corruption, Destroy to cleanse/reduce curse.
- Affinities: Scorched, Flooded/Conductive, Cursed, Darkness.
- Darkness guardrail: uncertainty, not cheap shots.

**Out of Scope:**

- Full elemental interaction matrix.
- Deep affinity manipulation.
- Full sacrifice/secrets/gambling depth.

**Dependencies:** Epic 6 rewards; Epic 3 level generation.

**Playable Deliverable:** A player encounters readable affinity pressure and at least one tempting risk/reward decision per run.

---

## Epic 8 - Outpost, Meta Progression, and Run Summary

**Goal:** Close the roguelite return loop and make death, discovery, and unlocks feel meaningful.

**Includes:**

- Last outpost flow.
- Oath Shards, Echoes, Seal Fragments, class mastery progress, and unlock progress.
- Limited, shallow MVP meta menu or tree.
- First-death line: "Good. You remembered how to die."
- Run summary with cause of death/victory, nodes cleared, boss/elite progress, passives consumed/destroyed, notable loot, Oath Shards earned, Echoes discovered, unlock progress, and seed.
- Manual seed replay warning and no-meta-progression rule.

**Out of Scope:**

- Full lore bible.
- Deep hub embodiment.
- Large account-power progression.

**Dependencies:** Epic 4 run completion; Epic 6 passives; Epic 7 risk economy.

**Playable Deliverable:** A player can die or finish a run, review what happened, earn eligible progress, unlock or advance something, and start another descent.

---

## Epic 9 - Larval Avatar MVP Finale

**Goal:** Give MVP runs a satisfying first endpoint that reinforces the containment mystery.

**Includes:**

- Larval Avatar boss encounter.
- Boss node setup and run transition.
- Victory state and post-victory return loop.
- First-victory reveal: "It did not die. It learned the way back."
- Boss tuning against the 20-35 minute successful run target.

**Out of Scope:**

- First Sealbreaker boss.
- Full boss roster.
- Permanent seal resolution.
- Deep postgame narrative.

**Dependencies:** Epic 4 run map; Epic 7 affinity/risk pressure; Epic 8 return loop.

**Playable Deliverable:** A player can reach and defeat the Larval Avatar, receive the reveal, and return to the outpost with the loop still open.

---

## Epic 10 - Playtest Tuning and MVP Readiness

**Goal:** Validate the MVP against the success metrics and prepare the first serious playtest loop.

**Includes:**

- Technical checks: load time, UI response, FPS, save/resume, no color-only critical info, no generator soft-locks.
- Gameplay checks: movement/attack comprehension, preview/commit clarity, Consume/Destroy clarity, damage/death readability.
- Run-quality checks: build-defining passive by early-mid run, risk/reward temptation, failed-run learning, 20-35 minute successful runs.
- Behavioral checks: second-run starts, weapon variety, safe/risky choice mix, Consume/Destroy mix, quit/resume success.
- Device checks across phone portrait, phone landscape, tablet/desktop-style wider view.

**Out of Scope:**

- Live-service telemetry.
- Leaderboards or daily challenges.
- Commercial launch polish.

**Dependencies:** Epics 1-9.

**Playable Deliverable:** A stable MVP build is ready for first meaningful playtests, with known metrics and failure points to tune.
