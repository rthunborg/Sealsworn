---
title: Sealsworn
game_type: roguelike
platforms:
  - iOS/Android mobile and tablet
  - Windows desktop/laptop
  - Mobile-first UX with desktop-playable parity
created: 2026-05-31
updated: 2026-08-05
status: Frozen for architecture v0; amended 2026-08-05 by the Epic-16 pre-epic design pass
---

# Sealsworn - Game Design Document

**Author:** Rasmus
**Game Type:** Roguelike
**Target Platform(s):** iOS/Android mobile and tablet, Windows desktop/laptop, mobile-first UX with desktop-playable parity

---

## Executive Summary

### Core Concept

Sealsworn is a mobile-first, desktop-playable, turn-based dark fantasy roguelite RPG where the player controls a single hero through seeded, forward-only procedural levels with fog of war, tactical positioning, weapon-shaped basic attacks, risk/reward routing, loot, passive rule-benders, and meta progression.

The story spine:

> The Labyrinth was not built to keep heroes out. It was built to keep something in.

### Target Audience

Sealsworn is designed for core roguelite and RPG players, roughly ages 18-40, who enjoy tactical choices, build synergies, loot decisions, and repeated runs where knowledge matters. They are comfortable with roguelites, turn-based games, or tactics games, but the game should remain readable enough for curious RPG players who are newer to the genre.

Secondary audiences include dark fantasy lore explorers, tactics players seeking shorter runs, RPG buildcrafters, and mobile players who want meaningful depth without real-time pressure.

### Unique Selling Points (USPs)

- Turn-based, mobile-friendly roguelite runs with tactical positioning as the core pressure system.
- Seeded forward-only run map where node choice, scouting limits, level size clues, and fog of war create fair uncertainty.
- Passive rewards as awakened memories with Consume / Destroy choices that bend combat, movement, damage, healing, visibility, and risk.
- Dark medieval fantasy with a cosmic horror containment mystery, delivered as optional discovery rather than required reading.

---

## Goals and Context

### Project Goals

- Prove a complete rough roguelite loop: start run, choose class, generate map, enter generated levels, fight, collect rewards, make passive choices, die or win, receive summary, and unlock limited meta progression.
- Keep the game loop fun for players who ignore all lore.
- Use meta progression to expand variety and knowledge more than raw power.
- Preserve a narrow MVP scope around Warrior, Pyromancer, Ranger, a limited enemy set, a limited affinity set, and 20-30 passives.

### Background and Rationale

The Labyrinth is a moving containment machine built around the only known portal through which an immortal cosmic being can enter the world. A dream-infected liberation cult has broken the outer seals. Descendants of a forgotten warden order awaken ancestral memories and are spiritually bound to descend, die, return to the last outpost, and remember more with each attempt.

Design guardrails:

- Story is optional discovery, not required reading.
- Cutscenes or control-loss narrative moments must be skippable.
- Ancient containment technology must read as relic-magic or Wardenwork, not science fiction.
- Passives are awakened memories, oaths, scars, relic echoes, forbidden instincts, or broken protocols.
- Affinities are failed containment protocols and safety measures.

---

## Core Gameplay

### Game Pillars

1. **Deliberate Turns, No Real-Time Pressure**
   The player can think forever, but every action advances danger. The game creates pressure through turn consequences, enemy behavior, resource attrition, and irreversible routing rather than timers or reflex demands.

2. **Position Is Power**
   Tile choice, range, line of sight, fog, hazards, armor penalties, and enemy movement decide outcomes. Strong play means reading the board, controlling exposure, and making movement as important as attacking.

3. **Builds Bend the Rules**
   Loot and awakened memories create synergies that change how the player solves fights. Good builds should feel like controlled rule-breaking: altering movement, targeting, risk, visibility, healing, damage, or reward logic.

4. **Risk Is the Run's Currency**
   HP, curses, gold, secrets, corrupted rewards, sacrificial routes, and elite enemies tempt the player into danger. The best decisions are not always safe; the game should repeatedly ask whether a promising run is worth endangering for a stronger future.

Design rules that support these pillars:

- Partial information must create fair tension, not blind punishment.
- Seeded runs should be replayable and debuggable; manually entered seed runs do not grant meta progress.
- Meta progression expands variety, knowledge, and starting options more than raw power.

### Core Gameplay Loop

Choose hero/loadout -> choose forward route -> enter tactical level -> spend turns positioning and fighting -> claim rewards or risks -> shape the build -> exit forward -> repeat until death or boss -> return to the last outpost -> remember, unlock, and descend again.

Priority order for the loop:

1. **Tactical combat clarity.** Moving, attacking, positioning, enemy turns, and board readability are the moment-to-moment foundation. If this is not fun, the rest cannot carry the game.
2. **Build crafting and synergy.** Builds are the main run-to-run excitement and the reason a player remembers a specific descent.
3. **Route and risk decisions.** Routing, danger, curses, elites, secrets, and sacrifices create tension, commitment, and tempting mistakes.
4. **Mystery discovery.** Story and world discovery provide long-term flavor and motivation while staying optional and supportive.

The player returns for the hundredth run because each descent can create a different tactical problem, a different build shape, and a different tempting mistake.

### Win/Loss Conditions

MVP run victory: defeat the Larval Avatar at the final node.

MVP run loss: the hero dies during a level, event, or boss encounter and returns spiritually to the last outpost.

MVP finale scope: Larval Avatar is the only required MVP boss. The First Sealbreaker is deferred unless later scope explicitly adds it.

First victory reveal:

> It did not die. It learned the way back.

---

## Game Mechanics

### Primary Mechanics

These values are **Prototype Baseline v0**: the official first combat baseline for playable tests, not final balance. They are tuning anchors for the first playable tests and may change after playtesting.

#### Core Turn Rules

- Combat is turn-based.
- Every committed player action advances enemies and level systems.
- Baseline player movement budget is 3 tiles per committed move action.
- Baseline line-of-sight radius is 4 tiles.
- Baseline player HP is 18.
- Tactical floors are multi-room dungeons in one of three size classes (Small ~12x12, Medium ~18x16, Large ~26x28). See Procedural Generation.
- Levels use fog of war: unexplored tiles are black; explored-but-out-of-LoS tiles remain as gray memory.
- The player has a universal basic attack shaped by the equipped weapon.
- Attacks generally require straight-line alignment unless a weapon or effect explicitly overrides that rule.
- Starter ranged reach is intentionally low, around 4 tiles, so positioning remains important.
- Enemies do not usually reveal exact intent; major dangerous abilities may be telegraphed.
- Elemental and affinity interactions can matter, such as fire through burning fields, electricity through water, curse tradeoffs, and Darkness effects that alter visibility or memory pressure.

#### Prototype Weapon Baseline

| Weapon | Range | Damage | Targeting | Tactical Identity |
|---|---:|---:|---|---|
| Sword | 1 | 4 | Adjacent | Reliable melee damage. |
| Dagger | 1 | 2 | Adjacent | Low normal damage; intended to become strongest melee hit when Unseen. |
| Spear | 2 | 3 | Line melee | Reach weapon with safer spacing and lower damage than sword. |
| Axe | 1 | 3 | Adjacent | 35% chance to apply bleed if target survives. |
| Mace | 1 | 3 | Adjacent | 35% chance to disorient if target survives. |
| Bow | 4 | 3 | Line of sight | Ranged attack with -30% damage against adjacent enemies. |
| Crossbow | 3 | 4 | Line of sight | Shorter range, heavier hit, knockback 1 when space allows. |
| Staff | 4 | 4 | Line of sight | Projectile attack; adjacent hits deal half damage. |
| Wand | 4 | 2 | Ignores blockers | Lower damage, instant line, ignores walls and enemies. |

#### Support Item Baseline

| Support | Armor | Block | Tactical Identity |
|---|---:|---:|---|
| None | 0 | 0% | No off-hand modifier. |
| Tome | 0 | 0% | Staff and wand attacks deal +1 damage. |
| Shield | 1 | 50% | Grants armor and can block half incoming physical damage. |

#### Prototype Enemy Baseline

| Enemy | Role | HP | Sight | Baseline Behavior |
|---|---|---:|---:|---|
| Iron Cultist | Melee | 10 | 4 | Advances toward the player; deals 3 physical damage when adjacent. |
| Gate Brute | Melee | 12 | 3 | Heavier melee body; uses the same prototype melee behavior. |
| Ash Seer | Caster | 8 | 6 | Marks the player's tile from range 5 with LoS, then detonates next enemy turn for 4 damage if the player remains there. |

These enemies are the first enemy-pattern tests. They exist to validate melee pressure, heavier body blocking, and telegraphed caster danger before the enemy roster expands.

#### Enemy Awareness

These rules are **Enemy Awareness Baseline v0**. They replace the implicit model in which every enemy on a floor engages from the first turn.

- Enemies begin a floor **dormant**. A dormant enemy takes no turn and applies no pressure.
- An enemy **wakes** when it perceives the hero: within its own **sight range**, along a valid **line of sight**, evaluated through the same visibility model the player is subject to.
- Waking is **permanent** for the encounter. A woken enemy never returns to dormant.
- Waking is **observable**: the player gets a readable cue at the moment an enemy wakes.
- Waking is **explainable**: every activation decision can be stated in plain language ("woke: saw hero at range 3", "dormant: no line of sight").
- A dormant enemy still counts toward the floor's clear condition. Dormancy hides threat; it does not remove it.

**Sight range is a per-enemy property, not a global constant.** It varies by monster type and fighting style, and **ranged and caster enemies generally see further than melee enemies** — a caster's threat is its reach, so its awareness matches it. Baseline v0 bands: melee 3-5, ranged/caster 5-7. Player baseline line-of-sight radius stays 4.

An enemy may therefore notice the hero before the hero can see it. That asymmetry is the intended source of tension, bounded by one rule:

> **Waking may happen unseen; damage may not arrive unannounced.** An enemy waking outside the player's line of sight is fair play. Its first damaging action must still be perceivable in advance — through a telegraph, or by the enemy entering view first. This is the existing Darkness guardrail ("must not spawn unavoidable damage from unseen space") applied to awareness.

**Design intent: the player controls the pace of engagement.** Approach route, sightlines, and positioning decide how many enemies are awake at once. Pulling one room at a time is a legitimate and skillful way to play a large floor; blundering down a long sightline and waking three rooms is a real and self-inflicted mistake. This is the mechanism that keeps "one node = one fight" playable once floors get large — without it, a Large floor is not tense, merely exhausting.

**Darkness cuts both ways.** The Darkness affinity darkens the floor **visually** and **reduces sight range for the player and for monsters alike**, applied through one shared visibility seam rather than two parallel models. Darkness is therefore **mutual concealment**, not a pure player debuff: it hides the player from enemies exactly as it hides enemies from the player, and it makes sneaking past a room a viable option that a lit floor does not offer.

#### Run-Building Mechanics

- Loot, consumables, pickups, gold, shops, reforging, and gambling shape each descent.
- Passive pickups open Consume / Destroy choices.
- Risk/reward events can ask the player to risk HP, curses, gold, future safety, secrets, corrupted rewards, sacrificial doors, or elite enemies for stronger outcomes.
- Seeded run generation reproduces major run structure; manually entered seed runs do not grant meta progression.

### Controls and Input

Mobile-first input must make tactical decisions readable and comfortable:

- Tap a visible reachable tile to preview movement cost and move.
- Tap a visible enemy to preview weapon reach, path/line, expected damage, effects, blocker state, and warnings such as adjacency penalties.
- Attacks use a deliberate two-step commit on mobile by default: second tap on the same target or a clear confirm button commits the attack.
- Fast single-tap attacks may become an optional setting later, but they are not the default.
- Tap/hold or inspect should reveal tile, terrain, occupant, move cost, attack preview, hazard notes, and telegraphed danger.
- Desktop input should preserve parity through mouse and keyboard support without changing the rules.
- The game must support interruption-friendly sessions and robust save/resume between levels.

The two-step attack flow supports the **Deliberate Turns, No Real-Time Pressure** pillar. Mis-taps are especially punishing when every committed action advances enemies and level systems.

---

## Roguelike Specific Elements

### Run Structure

This is the MVP run-structure baseline:

- **Target length of an AVERAGE run: 20-35 minutes.** The target describes the typical run, and the typical run **ends in death** — the expected outcome is the player dying at roughly **70% of nodes completed**, about 5-6 of the ~8 nodes a route traverses before the boss. The budget covers an incomplete run, not a full clear.
- A full clear through the boss legitimately runs longer than 35 minutes. That is the exception the target does not describe.
- Runs that end early — a bad third node — still land around 5-15 minutes.
- Run map length: 8-12 nodes before the boss, arranged roughly 8 tiers deep, one node visited per tier.
- Finale: Larval Avatar only for MVP.
- Save/resume between levels is required.
- Mid-level save/resume is desirable if feasible.
- Runs are seeded and forward-only.
- Each run begins at the last outpost and descends through a node map.
- Each node leads to a generated level, event, shop, reforge, gambling, elite encounter, or boss.
- Doors seal behind the hero as a containment law.

Pacing:

- Early run: Small levels, low-risk rewards, and basic enemy literacy.
- Mid run: Medium levels, stronger passives, shops, reforging, gambling, and first elites.
- Late run: higher affinity pressure, dangerous rewards, and elite/boss preparation.
- Finale: Larval Avatar as the single MVP boss.

The player should usually see at least one meaningful build-defining passive by the early-mid run, so the run has identity before it reaches the late phase.

**Pacing pressure — stated honestly.** Three ratified changes all push node duration in the same direction at once, and none of them is being reversed:

| Pressure | Effect on node duration |
|---|---|
| Hero movement stays **1 tile per turn** at every size class | Crossing a floor costs turns in direct proportion to its size. No move-points model or out-of-combat speed boost offsets it. |
| A Large floor is **~4.3x the area** of the current Medium (728 vs 168 cells) and roughly **2x the linear traversal distance** | Tens of turns of walking before a blow is struck. |
| **Movement animation** gives every turn real wall-clock cost it previously did not have | A direct multiplier on perceived node duration, compounded by a sequenced enemy phase. |

Two things hold the 20-35 minute target against that pressure:

1. **The target covers ~5-6 nodes, not 8.** Death at ~70% of nodes is the expected outcome, so the budget was never buying a full clear.
2. **Size-class mix is the primary pacing lever** — and the only one still free. Large floors are rare by design (see Procedural Generation); if runs measure long in playtest, the mix is the dial to turn, not movement speed and not the number of enemies.

Enemy awareness cuts the other way and partly offsets the cost: a floor fought a room at a time resolves in shorter, more decisive engagements than one where every enemy converges at once. Sight-based activation is a pacing feature, not only a tension feature.

If measured runs still overshoot after the mix is tuned, the target is what gets revisited — deliberately and on the record — rather than quietly left to become false.

### Procedural Generation

These rules are **Procedural Generation Baseline v0** for MVP.

- Seeds reproduce the run map, node structure, level layouts, affinity assignments, enemy placements, reward categories, major event outcomes, and boss/finale setup.
- Manual seed entry is allowed for replay, debug, sharing, and practice, but grants no meta progression.
- Level generation prioritizes readable tactical spaces over novelty.
- Each combat level needs a clear entrance, a clear exit, enough blockers/cover to make line of sight matter, and at least one tactical wrinkle.
- Fog hides exact future danger but must not create unfair instant punishment when new space is revealed.

#### Level Structure

A tactical floor is **a place, not an arena**. The single open interior is replaced by:

- **Rooms connected by corridors**, including **dead-ends** that lead nowhere and reward the detour or punish it.
- **Structural filler that is not reachable** — wall mass, rubble, collapsed sections. **Not every cell is a destination.** An unreachable cell is never a legal move target, never a spawn site, and never a reward site.
- A **connected reachable set**: everywhere the player can stand is mutually reachable, and the entrance can always reach the exit.
- Geometry generated **deterministically from the run seed** and validated for connectivity and fightability before use. **Structure never makes a node unwinnable** — a floor too cramped to fight its own encounter is rejected and regenerated, not shipped.

This is a change to what a fight *is*. Before: one open room where every enemy engages at once. After: an approach through structure where threat arrives in waves the player provokes. It is the tactical expression of the **Position Is Power** pillar at a scale where position finally has room to matter.

#### Size Classes

Three size classes replace the previous two:

| Class | Target dimensions | Role |
|---|---|---|
| **Small** | ~12x12 | Tight, quick, legible. Early floors and compact special nodes. |
| **Medium** | ~18x16 | The standard tactical floor. The class most fights happen on. |
| **Large** | ~26x28 | Rare and special. A genuine dungeon level — multiple rooms, real traversal, room to be outflanked. |

Large is **not a hard mode**. It is a different tactical space (see Difficulty Modifiers).

**Size-class mix.** Which class a node draws is **weighted by route depth and never exclusive.** Baseline v0 weighting bands:

| Route depth | Small | Medium | Large |
|---|---:|---:|---:|
| Early (tiers 1-3) | 60 | 35 | 5 |
| Mid (tiers 4-6) | 25 | 60 | 15 |
| Late (tiers 7-8) | 10 | 55 | 35 |

Modifiers: **elite nodes** shift one band toward Large; the **pre-boss node** weights Large heaviest. The boss arena is authored, not drawn from this table. Compact special nodes (shop, reforge, gambling, lore) are not combat floors and take no size class.

**Positive weights only — no zero-probability entries.** Every class remains possible at every depth: a Large floor can appear at tier 2 and a Small floor at tier 8, each rare enough to be a genuine surprise. Depth shifts the odds; it never forecloses an outcome. This follows the same weighting contract as class-relevant reward offers — relevance raises frequency, and nothing is ever excluded.

#### Generation Rules and Validation

Tactical wrinkle examples:

- Hazard.
- Door.
- Choke point.
- Flank route.
- Blocker or elevation-like obstruction.
- Affinity effect.
- Enemy formation.
- Reward placed behind danger.
- Optional risky side branch.

Determinism rules:

- Major facts should be seed-stable once generated or revealed.
- Anything the player routes around or makes a strategic decision from must be deterministic and locked once visible.
- Minor runtime variance can remain flexible if needed, such as small drop rolls, combat proc rolls, or non-critical reward quantities.

Generator validation:

- Entrance-to-exit path exists.
- The reachable set is fully connected — no walkable pocket is sealed off from the rest of the floor.
- Every enemy, reward, and entity sits on a reachable cell; no unreachable cell is ever a move target, spawn site, or reward site.
- The floor affords enough open space for its own encounter to be fought — no node is made unwinnable by cramped geometry.
- No required class or item gates block mandatory progress.
- Enemy placements are legal.
- Rewards are reachable if intended.
- The first revealed area cannot immediately punish the player without a reasonable response.

A layout failing any invariant is **rejected and regenerated with a structured diagnostic** — never coerced into validity.

### Permadeath and Progression

These rules are **Permadeath and Meta Progression Baseline v0** for MVP.

Death ends the run and returns the hero's spirit to the last outpost. Meta progression represents ancestral remembrance and restoration of lost warden capabilities.

Working terms:

- Meta currency: Oath Shards.
- Lore/codex discoveries: Echoes.
- Major seal/story unlocks: Seal Fragments.
- Meta spaces: Memory Archive, Hall of Oaths, Seal Table, Gate or Descent Stair.

Progression rules:

- Non-seed-replay runs can grant Oath Shards, Echoes, Seal Fragments, class mastery progress, and unlock progress.
- Manual seed runs grant no meta progression, but can still be used for replay, practice, debug, and sharing.
- Meta progression should primarily unlock variety, knowledge, starting options, classes, passives, enemy information, affinity information, shops, scouting tools, and class mastery choices.
- MVP meta should stay shallow: a small unlock tree or menu, not a deep account-power grind.
- Meta progression may give modest starting advantages, but it should primarily widen decisions rather than raise the floor so much that skill stops mattering.

Limited direct power is allowed only if capped, scarce, and secondary to variety/knowledge/starting options.

MVP-safe direct-power examples:

- Unlock one alternate starting weapon.
- Unlock one starting consumable choice.
- Slightly expand starting loadout options.
- Unlock a class passive variant.
- Unlock limited pre-run scouting.
- Add a small capped bonus such as +1 max HP, if used very sparingly.

Avoid or defer:

- Broad permanent damage increases.
- Large HP or armor scaling.
- Permanent crit or dodge stacking.
- Anything that makes early levels irrelevant.
- Account-wide stat grind as the main progression path.

First death should reveal the loop with a short line:

> Good. You remembered how to die.

Run summary should show:

- Cause of death or victory.
- Nodes cleared.
- Boss/elite progress.
- Passives consumed and destroyed.
- Notable loot.
- Oath Shards earned.
- Echoes discovered.
- Unlock progress.
- Seed, with replay warning if manually used later.

### Item and Upgrade System

These rules are **Item and Passive System Baseline v0** for MVP.

- MVP passive pool: 20-30 passives.
- Include 3-5 weird rule-benders.
- Passive rewards are awakened memories, not generic perks.
- Rewards should often use 3-choice moments.
- Inventory stays small, likely 6 backpack items, with no stacking by default.
- Consumables are semi-rare and should feel worth using.
- Loot can include weapons, armor, jewelry, support items, consumables, pickups, passives, gold, and later affixes/enhancements.
- Items use character-level requirements, not minimum run requirements.
- Items roll ranges, affixes, affinities, and enhancements rather than fixed item levels.
- Every passive should serve at least one pillar. If it does not affect tactical clarity, build synergy, risk, or mystery, it should probably not be in MVP.

Passive reward modal should include:

- Icon.
- Evocative name.
- One short flavor line.
- Exact mechanical effects.
- Clear Consume choice.
- Clear Destroy choice.

Flavor can be mysterious, but mechanics must be explicit. If Consume has a downside, say so. If Destroy has a known benefit, say so. If Destroy has unknown consequences, label it honestly as unknown.

Consume / Destroy rule:

- Consume is for power and build identity.
- Destroy is for safety, purification, resources, secrets, or refusal.
- Destroy should usually feel intentional, not like a dead button.
- Destroy should not always be optimal or always safe. It is a meaningful alternative to Consume, not a salvage button players press by default when a passive looks weak.

Destroy outcome distribution for MVP:

- 70% small immediate benefit.
- 20% progress, unlock, or hidden flag.
- 10% no obvious reward, but avoids corruption or future danger.

Destroy reward examples:

- Small Oath Shard gain.
- Healing or cleanse.
- Remove or reduce curse.
- Gain gold.
- Gain a temporary buff.
- Reroll or improve future reward odds.
- Class mastery or unlock progress.
- Add an Echo/codex discovery.
- Advance a hidden refusal path.
- Seal a dangerous Labyrinth effect.

Rarely, Destroy can trigger hidden outcomes or strange consequences.

### Character Selection

MVP starting classes:

- Warrior.
- Pyromancer.
- Ranger.

Future classes shown in hero select as grayed-out locked options:

- Necromancer.
- Shadeblade.

Locked class UI rules:

- Future classes should be visible in the hero-selection screen from MVP.
- Locked classes are grayed out and cannot be selected until unlocked through meta progression.
- Each locked class should show a clear unlock hint or requirement.
- Locked class presentation must avoid implying full near-term content depth beyond the MVP scope.

Class rules:

- Classes do not start with active class skills at level 1.
- Each class starts with one class passive and one equipment-synergy passive.
- Starting passives nudge builds but do not force them.
- Future class mastery and in-run talents can add active skills and deeper mechanics.

### Difficulty Modifiers

These rules are **Difficulty and Challenge Systems Baseline v0**.

- Sealsworn will not have player-selectable difficulty tiers.
- MVP difficulty comes from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, and boss preparation.
- Daily challenges, leaderboards, online seeded challenges, and similar competitive or live-service features are deferred.
- Manual seed runs are practice, sharing, replay, and debug tools only; they grant no meta progression.
- Post-MVP challenge content can exist as explicit variant content, trials, oaths, or special runs, but not as a generic selectable difficulty ladder.

**Scale and structure are not difficulty knobs.** This restates the existing non-goal against the size classes and dungeon structure above; nothing in them relaxes it.

- A Large floor is **not** a hard mode and a Small floor is **not** an easy mode. They are different tactical spaces that reward different play — more room to maneuver and be outflanked, versus less room to do either.
- Size class carries **no stat scaling**. Enemies on a Large floor are not tougher, more numerous per room, or better rewarded for being on a Large floor.
- Enemy awareness is **not** a difficulty setting. Sight ranges are a per-monster identity trait, not a global aggression dial.
- Depth-weighted size mix shifts **variety**, not challenge. A Large floor appearing late is late-run texture, not a late-run penalty.
- No story may introduce a player-selectable difficulty tier or a stat-scaling multiplier under cover of the scale work.

---

## Progression and Balance

### Player Progression

These rules are **Progression and Balance Baseline v0**.

Meta progression should expand variety and knowledge more than raw power.

Unlock areas:

- Classes.
- Loot pools.
- Passives.
- Enemies.
- Secrets.
- Codex entries.
- Starting options.
- Class mastery.

Progression rules:

- Progression should be mostly horizontal: more classes, passives, loot pools, scouting, knowledge, and starting choices.
- Player power should come primarily from in-run buildcraft.
- Meta power can smooth onboarding, but should be capped and sparse.
- Direct power exists only as modest starting advantages, not as the main account progression path.

### Difficulty Curve

- Early run: teach enemy patterns, basic positioning, and low-risk reward reading.
- Mid run: test build identity, route decisions, and first serious risk/reward choices.
- Late run: pressure resources, punish sloppy positioning, increase affinity danger, and test boss readiness.

Short-term survival should compete with long-term build ambition. If the player always chooses safety, rewards are too weak. If the player always chooses greed, danger is too low. If they pause and think, the economy is doing its job.

### Economy and Resources

MVP economy should be simple and readable first, with one or two sharp risk systems integrated deeply enough to prove the fantasy. Do not make curses, corruption, gambling, reforge, sacrifice, shops, secrets, passive destruction, and affinity manipulation all equally deep in MVP.

MVP economy:

- Gold: basic in-run currency for shops, reforge, gambling, and small services.
- Healing: scarce, valuable, and sometimes competing with greed.
- Curses/corruption: one clear risk layer used by dangerous rewards, passive choices, and possibly one affinity or enemy family.
- Oath Shards: meta currency awarded only after run end and only in eligible non-manual-seed runs.
- Passives: main build-shaping reward.
- Loot: tactical/build support, not a flood of stat comparisons.

Risk economy rules:

- MVP includes curses/corruption, but keeps them readable.
- A curse has a clear downside.
- A cursed reward has a clear upside.
- The player understands the trade before accepting.
- Some builds may later exploit curses, but the first version should not require hidden knowledge to evaluate.

MVP risk examples:

- Gain a strong passive, but lose max HP.
- Take a cursed item with higher stats but a future penalty.
- Accept gold now and increase elite chance later.
- Reforge for cheap, but add corruption.
- Destroy a passive to cleanse or reduce curse.
- Enter a cursed node for better reward odds.

---

## Level Design Framework

### Level Types

These rules are **Level Design and Affinity Baseline v0**.

MVP level/node types:

- Combat.
- Elite combat.
- Shop.
- Reforge.
- Gambling.
- Risk/reward event.
- Secret or lore discovery.
- Boss.

Special nodes can be compact: shop, reforge, gambling, risk event, secret, or lore.

### Level Progression

Combat levels must support positioning decisions, line-of-sight play, and at least one tactical wrinkle. Doors and side branches are allowed, but mandatory progress must never require a specific class or item. Exits should be clear. Hidden or secret exits can be added later.

Affinities must alter tactical choices, not just visuals.

MVP affinity set:

- **Scorched:** failed purge protocol; fire hazards, burning terrain, and damage-over-time pressure.
- **Flooded/Conductive:** broken ward conduits; water/electric interactions, pathing pressure, and danger zones.
- **Cursed:** corrupted oath-law; risk/reward, penalties, and dangerous bargains.
- **Darkness:** failed concealment protocol; reduced visibility, hidden threats, uncertainty, and stronger fog/memory pressure. Darkens the floor visually **and reduces sight range for the player and for monsters alike** (see Enemy Awareness).

Darkness guardrail:

- Darkness should create uncertainty, not cheap shots.
- It can reduce visibility, obscure enemy counts, hide rewards, distort explored memory, or empower certain enemies.
- It must not spawn unavoidable damage from unseen space.
- The player should feel cautious and clever, not ambushed unfairly.
- **Darkness is symmetric.** It cuts the player's sight and every monster's sight through **one shared visibility seam**, never two parallel models. A darkened floor is mutual concealment — harder to see threats, and harder to be seen — which makes slipping past a room a real option Darkness uniquely offers. It is never a one-sided player debuff.

---

## Art and Audio Direction

### Art Style

These rules are **Art and Audio Direction Baseline v0**.

Dark medieval fantasy baseline: steel, stone, candles, bows, armor, ruined keeps, old churches, fearful villages. Cosmic horror should sit underneath the medieval surface through ambiguity, ritual distortion, impossible architecture, dreams, and containment failure.

Wardenwork should read as relic-magic, not science fiction.

Visual direction:

- Stylized dark fantasy 2.5D.
- Top-down or slightly angled orthographic grid.
- Mobile clarity first: readable silhouettes, clear tiles, clean effect language, and strong enemy shapes.
- Cosmic horror appears as undercurrent, not constant spectacle: impossible geometry, subtle distortions, dreams, whispers, and containment failure.
- Animation is simple but expressive: readable attacks, enemy movement, impact flashes, passive pickup pulses, doors sealing, and soul-return effects.

### Audio and Music

Audio direction:

- Crisp tactical feedback first, subtle horror ambience second.
- Sound effects should clearly communicate attacks, enemy movement, impacts, hazards, doors sealing, passive pickups, warnings, previews, confirmations, and risk choices.
- Music should use a dark medieval foundation with restrained cosmic unease.
- Music and ambience must not overpower tactical readability.
- UI sound should distinguish previews from committed actions.

---

## Technical Specifications

### Performance Requirements

These rules are **Technical Experience Baseline v0**.

- Generated level load target: under 3 seconds for MVP.
- UI preview/selection response target: under 100ms.
- Stable 60 FPS where feasible.
- 30 FPS is acceptable on lower-end mobile if input remains responsive.
- Combat input must remain readable on phone-sized screens.

### Platform-Specific Details

Sealsworn's MVP target platforms are iOS/Android mobile and tablet plus Windows desktop/laptop. The design is mobile-first and desktop-playable: input, UI density, readability, save/resume, and performance constraints start from phone-sized play, while desktop builds preserve the same rules with mouse/keyboard support and wider layouts.

First internal playable milestones may prioritize the fastest development build target, but game architecture must preserve a native mobile packaging path from the start.

- Portrait is likely the main mobile phone play mode because it best supports quick, comfortable, interruption-friendly sessions.
- Landscape is supported on mobile phones, tablets, and desktop/laptop screens.
- Landscape is not a separate game mode. It is the same tactical experience with more visible play space where possible, similar to zooming out or having a wider viewport.
- The UI adapts to wider aspect ratios by repositioning panels, controls, tooltips, and combat information so the board remains readable and uncluttered.
- Players can zoom and inspect the level on all devices and orientations.
- Orientation changes improve comfort and visibility, but do not change underlying rules.
- Runs must support interruption-friendly play.
- Save/resume between levels is required.
- Mid-level save/resume is desirable if feasible.
- MVP is offline-first.
- MVP has no accounts, multiplayer, cloud saves, leaderboards, or live-service dependency.

Accessibility baseline:

- Scalable text.
- Colorblind-safe danger communication.
- Clear icons plus labels where needed.
- No reflex or timing requirements.
- Skippable narrative/control-loss moments.
- All critical tactical information must be available without relying on color alone.

### Asset Requirements

MVP assets should prioritize tactical readability and reusable production value over content volume. Placeholder or prototype art is acceptable until the core loop is proven.

MVP asset baseline:

- 3 playable class portraits/icons or readable hero silhouettes: Warrior, Pyromancer, Ranger.
- 2 locked class silhouettes/icons: Necromancer, Shadeblade.
- 3 enemy-pattern visuals: Iron Cultist, Gate Brute, Ash Seer.
- 1 boss visual: Larval Avatar.
- 4 affinity visual treatments: Scorched, Flooded/Conductive, Cursed, Darkness.
- Tile and prop set for Small, Medium, and Large dark fantasy Labyrinth levels, including floor, wall, corridor, rubble/blocker, unreachable structural filler, exit, door, hazard, and reward/object tiles.
- A readable dormant-versus-awake enemy state distinction, and a wake cue that reads at a zoomed-out Large-floor camera.
- Core weapon/support icons for the Prototype Baseline v0 weapon and support list.
- 20-30 passive icons or placeholder glyphs with enough visual distinction to support reward choice.
- UI frames and controls for hero select, tactical HUD, tile/attack preview, passive modal, run map, outpost/meta menu, run summary, settings, and save/resume.
- Sound effects for movement, weapon hits, enemy actions, hazards, preview/confirm distinction, passive pickup, Consume, Destroy, curse/corruption, doors sealing, death, reward reveal, and boss victory.
- Ambient audio loops for Labyrinth exploration, outpost/menu, Scorched, Flooded/Conductive, Cursed, Darkness, and boss/finale.

---

## Development Epics

### Epic Structure

Detailed epics are maintained in `epics.md`. Every epic must preserve a playable build. After each milestone, the game should still launch, run a small test loop, and validate the main experience instead of accumulating disconnected systems.

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

Epics 1-10 are the MVP set defined at GDD v0. The epics below were added after MVP close, each via a recorded sprint change proposal, as the design met real play. They are listed here so this table stays the design-side view of the same sequence `epics.md` carries.

| Sequence | Epic | Playable Outcome |
|---|---|---|
| 11 | Live Run Flow, HUD, and Outpost | The full descent is playable hands-on: launch, choose a class, fight generated levels and the Larval Avatar on the live board, win or die for real, see the reveal lines and run summary, spend meta progress at the outpost, and descend again. |
| 12 | Interactive Tactical Combat | Players drive moment-to-moment combat by hand — tap to move, preview and confirm attacks, inspect tiles — with a class loadout that makes generated fights winnable and classes tactically distinct. |
| 13 | Human-Playable Board | The board draws as a real tile grid — terrain, occupants, fog, affinity treatments — taps resolve to board cells and drive the interactive-combat seams, and post-fight reward and passive choices are clickable on screen. |
| 14 | Playable & Presentable | The loop is genuinely finishable and readable (no soft-lock, visible previews, feedback for every action, a run-end summary, seed variety, a route map), then made to look intentional across hero select, outpost, HUD, and a shared UI theme. |
| 15 | Playtest Response | The loop becomes readable and correct: the HUD stops clipping, the attack-preview number matches the damage dealt, a run can be quit and resumed, threats telegraph before they detonate, event nodes and the run summary report real outcomes, and movement animates instead of teleporting. |
| 16 | Dungeon Generation, Scale & Awareness | Tactical floors become large multi-room dungeons — rooms, corridors, dead-ends, unreachable structural filler — across three size classes, viewed at a camera that defaults further out, with enemies that wake on their own line of sight instead of activating all at once. |

---

## Success Metrics

### Technical Metrics

These rules are **MVP Success Metrics v0**.

The most important success signal is replay intent: after death, victory, or unlock, does the player want one more descent?

Technical success signals:

- Generated level loads in under 3 seconds.
- Preview/selection interactions respond in under 100ms.
- Stable 60 FPS where feasible; 30 FPS acceptable on lower-end mobile if input remains responsive.
- Save/resume between levels works reliably.
- No critical tactical information depends on color alone.
- No generator soft-locks: every generated level has a valid entrance-to-exit path.

### Gameplay Metrics

Gameplay and comprehension success signals:

- Players understand valid movement and attack options after a short first session.
- Players can identify why they took damage or died.
- Players can tell a dormant enemy from an awake one, and can say what woke it.
- Players understand the difference between preview and commit on mobile.
- Players understand what Consume and Destroy do on passive rewards.
- Players report that positioning choices matter.

Run-quality success signals:

- At least one meaningful build-defining passive appears by early-mid run.
- Players encounter at least one tempting risk/reward decision per run.
- Failed runs feel like they taught something.
- Average runs land in the 20-35 minute target most of the time, measured across all runs rather than clears only. The typical measured run ends in death around 70% of the way through the route.
- Players can name one memorable build, passive, risk, enemy, or moment after a run.

Behavioral success signals:

- A meaningful share of players start a second run after death.
- Players use at least two different weapon types across early sessions.
- Players make both safe and risky choices across multiple runs.
- Players consume some passives and destroy others, rather than always choosing one option.
- Players quit and resume successfully without confusion or lost progress.

---

## Out of Scope

MVP non-goals:

- Full five-class depth.
- Huge level generation polish. (Large is in scope — it is a supported size class; see Procedural Generation.)
- Deep class talent trees.
- Hundreds of loot affixes.
- Full elemental interaction matrix.
- Console and web targets.
- Mac and Linux targets unless architecture makes them cheap.
- Final art direction.
- Full boss roster.
- Complex AI intent prediction UI.
- Multiplayer or online features.
- Full lore bible.
- Deep postgame narrative.
- Permanent seal resolution.
- Common ancient technology layer or science-fiction presentation.

---

## Assumptions and Dependencies

Current source inputs:

- `project-context.md`
- `_bmad-output/game-brief.md`
- `_bmad-output/brainstorming-game-brief-handoff-2026-05-29.md`
- `_bmad-output/planning-artifacts/design-notes/epic-16-design-brief.md` (Q1-Q6 ratified 2026-07-24)

**Amendment 2026-08-05 — Epic-16 pre-epic design pass.** Applied the ratified Epic-16 brief to this GDD: multi-room level structure with unreachable structural filler; three size classes (Small ~12x12, Medium ~18x16, Large ~26x28) with depth-weighted, never-exclusive mix; the new Enemy Awareness subsection (dormant-until-seen activation, per-enemy sight ranges, symmetric Darkness); the run-length target restated as an average run ending in death at ~70% of nodes, with the pacing pressures named; and the difficulty non-goal restated against scale and structure. Sections touched: Core Turn Rules, Prototype Enemy Baseline, Enemy Awareness (new), Run Structure, Procedural Generation, Difficulty Modifiers, Level Design Framework, Asset Requirements, Success Metrics, Out of Scope. Also reconciled the Development Epics table, which had gone stale at Epic 10 while `epics.md` had reached Epic 16.

No phase-blocking design decisions remain for GDD v0.

Remaining production design details:

- Exact starting passives for Warrior, Pyromancer, and Ranger.
- Exact first 20-30 passive designs.
- Exact gold, healing, curse/corruption, shop, reforge, and gambling rates.
- Exact run-map node weighting and reward category frequencies.
- Exact Larval Avatar encounter design.
- Exact outpost screen layout and unlock tree/menu shape.
