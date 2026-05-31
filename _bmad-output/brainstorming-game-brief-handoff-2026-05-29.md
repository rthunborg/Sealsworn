# Brainstorming Handoff for Game Brief

Date: 2026-05-29
Target workflow: `gds-create-game-brief`
Project: Game
Working title: **Sealsworn**
Prepared from prior brainstorming and narrative-spine sessions.

## Source Artifacts

The next Game Brief agent should treat this file as the compact handoff and use the following source documents for deeper detail if needed:

- Full mechanics brainstorming: `C:\Users\user\Documents\Game\_bmad-output\brainstorming\brainstorming-session-2026-05-25-173214.md`
- Previous PM handoff: `C:\Users\user\Documents\Game\_bmad-output\brainstorming\pm-handoff-2026-05-29.md`
- Narrative spine brainstorming: `C:\Users\user\Documents\Game\_bmad-output\brainstorming\brainstorming-session-2026-05-29-105557.md`
- Current prototype: `C:\Users\user\Documents\Game\prototype`

This root-level handoff exists because the Game Brief initializer discovers `*brainstorm*.md` files directly under `_bmad-output`.

## High-Level Game Vision

**Sealsworn** is a mobile-first, desktop-playable, turn-based dark fantasy roguelite RPG where the player controls a single hero through a seeded, forward-only run map. Each node leads to a procedurally generated level with fog of war, tactical positioning, weapon-shaped basic attacks, risk/reward events, loot, passive rule-benders, and meta progression.

Updated narrative spine:

> The Labyrinth was not built to keep heroes out. It was built to keep something in.

The game takes place in a dark medieval world where an ancient moving Labyrinth was built as a containment machine around the only known portal where an immortal Cthulhu-like being can enter the world. A dream-infected liberation cult has broken the outer seals. The being is now waking, and the descendants of the forgotten warden order are spiritually bound to descend from the last outpost, recover lost memories, and stop the breach.

## Player Promise

The player should feel clever for creating a strong synergy/build, excited that more story or mystery was uncovered, amazed by lucky run-specific discoveries, and tense because they do not want to ruin a promising run before a risky decision pays off.

The game must remain fun for players who skip all lore. Story supports the dopamine-filled loop; it does not replace it.

## Core Gameplay Pillars from Prior Brainstorming

1. **Think forever, act carefully.** Real-world time never pressures the player. Turns are the pressure system.
2. **Positioning matters.** Range, adjacency, line of sight, fog, armor penalties, hazards, and enemy movement make tile choice meaningful.
3. **Builds should bend rules.** Loot and passives mutate combat, movement, damage, healing, visibility, and risk.
4. **Risk is a resource.** HP, curses, gold, secrets, gambling, corrupted rewards, elite enemies, and sacrificial doors create tempting bad ideas.
5. **Partial information is fair tension.** Players see enough to plan but rarely know exactly what future levels contain.
6. **Runs should be replayable and debuggable.** Seeds reproduce major run structure; manually entered seed runs should not grant meta progress.
7. **Meta progression expands variety more than raw power.** Unlock classes, loot pools, passives, enemies, secrets, codex entries, starting options, and class mastery without mandatory stat grinding.

## Narrative Decisions to Preserve

**Setting and Tone**

- Dark medieval fantasy baseline: steel, stone, candles, bows, armor, ruined keeps, old churches, fearful villages.
- Cosmic horror undercurrent, delivered through mystery and ambiguity.
- Ancient containment technology exists but must read as relic-magic, not science fiction.
- Working term for ancient containment relics and mechanisms: **Wardenwork**.

**The Labyrinth**

- A moving containment machine built around a portal/spawn point for an immortal being.
- Designed to delay, confuse, weaken, and contain the being.
- Also functions as a general prison for lesser evils, corrupted guardians, failed experiments, demons, undead, and minibosses.
- Forward-only progression is a containment law: once a breach path opens, doors seal behind the hero.

**Heroes**

- Playable heroes are descendants of a forgotten warden order.
- When the Labyrinth seals broke, dormant spiritual seals inside the descendants broke too.
- They receive ancestral memories and are bound to the last outpost at the Labyrinth entrance.
- When they die, their spirits return to the last outpost instead of passing into the afterlife.

**Hub**

- The hub is the **last outpost** or **final outpost** at the Labyrinth entrance.
- The memory/meta layer is a **Memory Archive** within or beneath the outpost.
- Possible UI mappings:
  - Codex: Archive
  - Class mastery: Hall of Oaths
  - Meta upgrades: Seal Table
  - Run launch: Gate or Descent Stair

**Cultists**

- Working faction concept: **Dream-Infected Liberation Cult**.
- They believe the being is a god unjustly imprisoned.
- They preach release as mercy, liberation, or cosmic justice.
- In truth, the being has been whispering into dreams and shaping their beliefs.

**Boss and Endgame**

- MVP final boss: **Larval Avatar**, a forming body the immortal being uses to enter the world.
- First victory should feel satisfying but reveal the truth: the being did not truly die; it retreated deeper toward the portal.
- Suggested reveal line: "It did not die. It learned the way back."
- Future boss ideas:
  - First Sealbreaker as major cult boss.
  - Broken Warden as future tragic boss.
- Long-term victory model: temporary banishment now; rediscovering the permanent seal later.

## System Fiction

**Meta Progression**

- Meta progression is ancestral remembrance and restoration of lost warden capabilities.
- Working names:
  - Meta currency: **Oath Shards**
  - Lore/codex discoveries: **Echoes**
  - Major seal/story unlocks: **Seal Fragments**
  - Player order placeholder: **The Wardens**

**Passives**

- Passives are awakened memories, old oath techniques, scars, relic echoes, forbidden instincts, cult-tainted dreams, broken protocols, or ancestor failures.
- "Awakened memory" is the metaphysical category, not the repeated visible naming formula.
- Passive modal should include:
  - Evocative name
  - One short flavor line
  - Exact mechanical effects
  - Clear Consume / Destroy choices
- Consume means integrating the memory into body/spirit.
- Destroy means rejecting, purging, sealing, or breaking the memory before it binds.

**Affinities**

- Affinities are failed safety measures and malfunctioning containment protocols.
- Examples:
  - Scorched: purge fire protocol leaking through the level.
  - Flooded/Conductive: broken ward conduits flooding and arcing.
  - Cursed: oath-law inverted or corrupted.
  - Darkness: concealment veil malfunctioning.
  - Frozen: stasis protocol overcorrecting.
  - Mirrored: identity-confusion defense breaking loose.
  - Timeworn: delay field causing time rot.
  - Overgrown: living seal-growth spreading beyond control.

## MVP Scope Recommendations

MVP should prove a complete rough roguelite loop:

- Start run.
- Pick class.
- Generate seeded run map.
- Choose next node with visible size clue and limited scouting.
- Enter generated levels.
- Fight turn-based tactical enemies.
- Collect gold, loot, consumables, pickups, and passive rewards.
- Make Consume / Destroy passive choices.
- Visit simple shop/reforge/gambling levels.
- Exit levels and continue forward.
- Die or reach final node.
- Receive run summary.
- Earn Oath Shards and unlock limited meta progression only on non-seed-replay runs.

Recommended MVP class set:

- Warrior
- Pyromancer
- Ranger

Recommended locked/deferred classes:

- Necromancer
- Shadeblade

Recommended MVP enemy families:

- Cultists
- Undead
- Demons

Recommended MVP affinity set:

- Scorched
- Flooded/Conductive
- Cursed
- Darkness or Frozen

Current recommendation: choose **Darkness** for story and atmosphere unless production clarity favors Frozen.

Recommended MVP passive pool:

- 20-30 passives.
- Include 3-5 genuinely weird rule-benders.
- Ensure each passive has a distinct universe-specific name and flavor identity.

## Narrative Delivery Guardrails

- Story unfolds across runs through mystery, fragments, codex discoveries, environmental hints, boss implications, class memories, and ambiguous revelations.
- Intro should be one paragraph or equivalent.
- Any cutscene, intro, death recap, boss reveal, or post-victory scene that removes control must be skippable.
- The player should not need to read or care about lore to enjoy the game.
- Preserve ambiguity. Do not over-explain the immortal being, the old order, the cult's dreams, or the true cost of sealing.
- Avoid lore bloat in MVP.

Possible opening paragraph:

> The Labyrinth was not built to keep heroes out. It was built to keep something in. Now its seals are broken, and the forgotten bloodlines of its wardens have begun to remember.

Possible first-death line:

> Good. You remembered how to die.

Possible first-victory reveal:

> It did not die. It learned the way back.

## Explicit MVP Non-Goals

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
- Full lore bible.
- Deep postgame narrative.
- Permanent seal resolution.
- Common ancient technology layer or sci-fi presentation.

## Open Questions for Game Brief Agent

1. What exact one-sentence player promise should the Game Brief use?
2. Is the first public target a private prototype, playtest build, demo, or commercial early access foundation?
3. Should the MVP include both the First Sealbreaker and Larval Avatar, or keep only the Larval Avatar as the first finale?
4. Should Necromancer and Shadeblade appear as locked placeholders or stay absent until later?
5. How much hub/UI embodiment is needed for the last outpost in MVP?
6. Should the fourth MVP affinity be Darkness for story/atmosphere or Frozen for clearer tactical teaching?
7. What minimum passive flavor/content standard is required for the first 20-30 passives?
8. How should the brief phrase the balance between dark medieval fantasy, cosmic horror, and Wardenwork relic-magic?
9. What player-facing name should eventually replace placeholder terms like The Wardens if needed?
10. What is the minimum satisfying first-victory reveal?

## Handoff Recommendation

The Game Brief agent should use this handoff as the primary compact context, consult the three source artifacts for detail, and create a Game Brief that preserves:

- Game-loop-first priority.
- Dark medieval fantasy baseline.
- Failing containment Labyrinth story spine.
- Optional, mysterious, skippable narrative delivery.
- MVP scope discipline.
- The relationship between mechanics and fiction: passives as memories, affinities as containment failures, death/meta progression as ancestral remembrance.
