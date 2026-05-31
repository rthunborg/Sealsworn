# PM Handoff: Fantasy Turn-Based Roguelite

Date: 2026-05-29
Source brainstorming artifact: `C:\Users\user\Documents\Game\_bmad-output\brainstorming\brainstorming-session-2026-05-25-173214.md`
Current prototype: `C:\Users\user\Documents\Game\prototype`

## Purpose

This document closes the brainstorming phase and gives the PM agent a structured starting point for a product/game brief, PRD, and later GDD. The project has enough direction to move out of open-ended ideation and into documentation, scope control, and architectural planning.

## Core Game Pitch

A mobile-first, desktop-playable, turn-based fantasy roguelite RPG where the player controls a single hero through a seeded branching run map. Each node leads to a forward-only procedurally generated level with fog of war, tactical positioning, weapon-shaped basic attacks, risk/reward events, loot, passive rule-benders, and meta progression.

The intended emotional loop is: survive a dangerous level, find loot or a passive that hints at a synergy, take strategic risks to complete the build, and push toward a rare endgame finale where knowledge, positioning, and build decisions matter.

## Design Pillars

1. **Think forever, act carefully.** Real-world time never pressures the player. Turns are the pressure system: moving, attacking, waiting, and using abilities advance enemies and level state.
2. **Positioning matters.** Range, adjacency, line of sight, fog of war, armor penalties, hazards, and enemy movement should all make tile choice meaningful.
3. **Builds should bend rules.** Loot and passive pickups can mutate the rules of combat, movement, damage, healing, visibility, and risk.
4. **Risk is a resource.** HP, curses, gold, time, secrets, gambling, corrupted rewards, elite enemies, and sacrificial doors should create tempting bad ideas that sometimes become brilliant.
5. **Partial information is fair tension.** Players see enough to make strategic choices, but should rarely know exactly what a future level, reward, enemy, or secret contains.
6. **Runs should be replayable and debuggable.** Seeds should reproduce major run structure. Manually entered seed runs should not grant meta progress.
7. **Meta progression expands variety more than raw power.** Unlock classes, loot pools, enemies, passives, secrets, codex entries, starting options, and class mastery without turning the game into mandatory stat grinding.

## Current Key Decisions

## Run Structure

- Full successful runs usually target 10-60 minutes.
- Average successful/full runs should trend around 20-40 minutes, with final-node-reaching runs around 60 minutes.
- Very short death runs are allowed, but meaningful play above a few minutes should grant some meta progression.
- Run maps are seeded at run start.
- The player normally scouts only immediate next node choices.
- Once a node is scouted, its revealed data is locked.
- Future items/talents/passives can reveal more map information or alter future affinity/modifier chances.
- No backtracking is a core design commitment.

## Level Structure

- The term is **level**, not room. A level can contain multiple rooms, doors, branches, objects, hazards, secrets, and exits.
- Level sizes include Small, Medium, Large, and rare Huge.
- Small levels average around 8x8 tiles.
- Movement has been retuned downward. Prototype baseline is 3 movement and 4 line-of-sight tiles.
- Levels use fog of war: unexplored black, explored-but-out-of-LoS gray memory.
- Levels should have clear exits, with possible hidden/secret exits later.
- Levels can include locked/breachable doors. Door solutions must not require a specific class.
- Special compact levels can exist, such as Wheel of Fortune or shop/reforge levels.

## Combat

- Combat is turn-based.
- Every committed player action advances enemies and level systems.
- The player has a universal basic attack shaped by equipped weapon.
- Starter ranged reach is intentionally low, around 4 tiles.
- Ranged weapons have adjacency penalties.
- Staff attacks are ranged projectiles unless adjacent, where they deal reduced melee damage.
- Wands do lower damage but are instant and ignore blockers.
- Elemental/affinity interactions are important, such as fire through burning fields, electricity through water, and thermal shock from fire killing Frozen targets.
- Enemies do not usually reveal exact intent, except major dangerous abilities may be telegraphed.

## Classes

Five starting-class concepts are selected:

- Warrior: melee/heavy armor/breaching.
- Pyromancer: magic/fire/staff-cloth leaning.
- Ranger: ranged/mobile/bow-crossbow leaning.
- Necromancer: summoning/tome-wand leaning.
- Shadeblade: stealth/dagger/medium armor leaning.

Initial unlock plan:

- Warrior, Pyromancer, Ranger available initially.
- Necromancer and Shadeblade unlocked through meta progression.

Class rule:

- Classes do not start with active class skills at level 1.
- Each class starts with one class passive and one equipment-synergy passive.
- These passives should nudge builds, not force them.
- Future class mastery and in-run talents can add active skills and deeper mechanics.

## Equipment

- Two weapon slots are planned.
- Two-handed weapons exist.
- Not all classes can dual-wield.
- Off-hand/non-main items can include shield, tome, throwing weapon, etc.
- Armor slots: body armor, helmet, boots, gloves, pants.
- Jewelry: two rings and one amulet.
- Armor categories: light, medium, heavy.
- Medium armor currently implies -1 movement if any medium item is worn.
- Heavy armor currently implies -2 movement and -5% dodge if any heavy item is worn.
- Warrior Heavy Armor Mastery halves heavy armor movement penalty and gains armor near enemies.
- Items use character-level requirements, not minimum run requirements.
- Items do not have fixed item levels, but roll attribute ranges, affixes, affinities, and enhancements.
- Items can potentially be improved, enhanced, reforged, or converted during a run.

## Loot and Passives

- Random enemies can drop gold, consumables, pickups, and loot with tuned probabilities.
- Special rewards often use 3-choice moments.
- Consumables should be semi-rare and encouraged to use.
- Inventory should be small, likely 6 backpack items, with no stacking by default.
- Pickups can include instant health globes, XP globes, and other temporary effects.
- Passive pickups are central. Moving onto one opens a modal with icon, name, flavor, concrete effects, and choices:
  - Consume it.
  - Destroy it.
- Destroying a passive can sometimes grant a smaller alternative benefit.
- Some passives may appear harmful until a hidden synergy makes them powerful.
- Hidden passives can unlock after unusual behaviors, such as destroying multiple passive pickups in a row.

## Affinities

Level affinities and item affinities are separate taxonomies, though they can overlap.

Starter level affinity concepts include:

- Mirrored
- Scorched
- Flooded
- Overgrown
- Starved
- Timeworn
- Cursed
- Darkness

Item/loot affinity concepts include:

- Scorched
- Conductive
- Frozen
- Radiant
- Legendary
- Thorned
- Regen
- Root
- Fungal
- Arcane
- Void/Abyssal
- Gale/Zephyr
- Maddening
- Hallowed

Class-specific affinity rolls are allowed only when relevant to the current class. Example: Hallowed can roll summon modifiers for Necromancer, but those summon-specific options should not appear for other classes.

## Enemies

MVP enemy families:

- Cultists
- Undead
- Demons

Enemy variants:

- Normal
- Elite
- Affinity-touched
- Rare elite plus affinity, effectively a random mini-boss

Enemy knowledge should reward player learning. Players should learn typical enemy family behavior over time without exact intent being fully exposed every turn.

## Meta Progression

Meta currency working name: diamonds.

Meta systems:

- General meta tree.
- Class mastery tree per class.
- Codex pane.
- Achievements/challenges pane.
- Class mastery/progression pane.
- Unlocks for enemies, loot, passives, items, secrets, bosses, classes, and starting options.

Seed replay rule:

- Manually entered or replayed seed runs should not grant meta currency, achievements, unlocks, or other meta progress.

## Prototype Findings So Far

The current web prototype has validated enough to stop broad prototyping:

- Mobile-first tactical grid is viable.
- Lower movement values make 8x8 Small spaces more tactical.
- Fog of war with LoS 4 reads well enough to pursue.
- Universal weapon-shaped basic attacks produce meaningful differences.
- Seeded Small and Medium level generation is feasible.
- Scroll and zoom are needed for larger levels.
- URL seed/size replay is useful for debugging.

Prototype is not intended as final architecture.

## Proposed MVP Scope

MVP should prove a complete rough roguelite loop:

- Start run.
- Pick class.
- Generate seeded run map.
- Choose next node with visible size clue and limited scouting.
- Enter generated levels.
- Fight turn-based tactical enemies.
- Collect gold, loot, consumables, pickups, and passive rewards.
- Make consume/destroy passive choices.
- Visit simple shop/reforge/gambling levels.
- Exit levels and continue forward.
- Die or reach final node.
- Receive run summary.
- Earn diamonds and unlock limited meta progression only on non-seed-replay runs.

Recommended MVP class set:

- Warrior
- Pyromancer
- Ranger

Recommended locked/deferred classes:

- Necromancer
- Shadeblade

Recommended MVP affinity set:

- Scorched
- Conductive/Flooded
- Cursed
- Darkness or Frozen as the fourth, depending on production scope.

Recommended MVP passive pool:

- Enough to demonstrate rule-bending, not enough to chase balance polish. Target 20-30 initial passives, with 3-5 genuinely weird rule-benders.

## Explicit Non-Goals for MVP

- Full five-class depth.
- Large/Huge level generation polish.
- Deep class talent trees.
- Hundreds of loot affixes.
- Full elemental interaction matrix.
- Native mobile packaging unless architecture makes it cheap.
- Final art direction.
- Full boss roster.
- Complex AI intent prediction UI.
- Multiplayer or online features.

## PM Questions to Resolve

1. What exact player promise should the first public vertical slice make?
2. Is MVP targeting a private prototype, playtest build, demo, or commercial early access foundation?
3. Should the first complete run include a final boss, or only a placeholder finale?
4. Should Necromancer and Shadeblade be locked placeholders in MVP UI, or absent until later?
5. How much meta progression is needed for MVP without creating a grind?
6. What is the minimum acceptable passive pool size for the dopamine/build fantasy?
7. What is the target platform sequence: web first, Android/iOS later, or engine-native from the start?
8. What is the expected art/audio fidelity for first external playtests?
9. What player analytics or debug tools are needed from day one?
10. How deterministic should replays be beyond map/level generation?

## Architect Questions to Resolve

1. What tech stack best serves mobile-first turn-based roguelite development?
2. Should the project remain web-based, move to Godot/Unity, or use another stack?
3. How should deterministic seed generation be isolated from non-deterministic drops/procs?
4. How should data-driven content be represented for items, passives, enemies, affinities, and levels?
5. How should save checkpoints between levels work?
6. How should mid-level fixed seed state prevent save scumming of generated layouts?
7. What automated tests are needed for generator validity, combat rules, and seed reproducibility?
8. What debug mode should support bug reports with run seed and level seed?
9. How should the UI support mobile gestures, scroll/zoom, and desktop pointer/keyboard ergonomics?
10. What content pipeline will let designers add passives and affixes without code edits?

## Recommended Next Step

Invoke the PM agent to create a Game Brief or PRD using this handoff and the full brainstorming artifact as source material. The PM output should define MVP scope, success criteria, documentation structure, and the first implementation roadmap before the architect chooses final technology and architecture.
