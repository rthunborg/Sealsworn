# Sealsworn - Decision Log

**Created:** 2026-05-31
**Updated:** 2026-05-31

## 2026-05-31

### Workspace Created

- Created GDD workspace at `C:\Users\user\Documents\Game\_bmad-output\planning-artifacts\gdds\gdd-Game-2026-05-31`.
- Created `gdd.md`, `epics.md`, and `decision-log.md`.

### Workflow Intent

- Decision: Create a fresh Game Design Document for Sealsworn.
- Source: User confirmation.

### Game Type

- Decision: Primary game type is Roguelike.
- Rationale: User confirmed Roguelike. Existing inputs strongly signal seeded runs, procedural levels, permadeath/run structure, forward-only run routing, and meta progression.
- Secondary influences: RPG and Turn-Based Tactics.

### Working Mode

- Decision: Start in Facilitative mode.
- Rationale: User wants to walk design decisions collaboratively first.
- Note: User may switch to Express mode at any point if little adjustment is needed.

### Source Inputs Registered

- `C:\Users\user\Documents\Game\project-context.md`
- `C:\Users\user\Documents\Game\_bmad-output\brainstorming-game-brief-handoff-2026-05-29.md`

### Imported Design Guardrails

- Game loop first; the game must be fun for players who ignore all lore.
- Story is optional discovery and must not require reading.
- Any cutscene or control-loss narrative moment should be skippable.
- Tone is dark medieval fantasy with a cosmic horror undercurrent.
- Ancient containment technology should read as relic-magic or Wardenwork, not science fiction.
- Meta progression should expand variety and knowledge more than raw power.
- MVP scope should stay narrow and prove the complete rough roguelite loop.

### Game Pillars Locked

- Decision: Final GDD pillars are Deliberate Turns, No Real-Time Pressure; Position Is Power; Builds Bend the Rules; Risk Is the Run's Currency.
- Rationale: User confirmed this four-pillar set as the spine of Sealsworn.
- Note: Fair partial information, seed debuggability, and variety-focused meta progression are design rules supporting the pillars rather than standalone pillars.

### Core Gameplay Loop Locked

- Decision: Core loop is "Choose hero/loadout -> choose forward route -> enter tactical level -> spend turns positioning and fighting -> claim rewards or risks -> shape the build -> exit forward -> repeat until death or boss -> return to the last outpost -> remember, unlock, and descend again."
- Priority order: tactical combat clarity; build crafting and synergy; route/risk decisions; mystery discovery.
- Rationale: Combat must be the moment-to-moment foundation. Build crafting creates memorable runs, route/risk decisions create tension and commitment, and mystery discovery supports long-term flavor without carrying the loop.
- Hundredth-run reason: Each descent can create a different tactical problem, a different build shape, and a different tempting mistake.

### Prototype Baseline v0 Locked

- Decision: Promote current prototype combat values to official **Prototype Baseline v0**.
- Rationale: The prototype needs stable first playable targets without pretending the balance is final.
- Baseline: 3-tile movement budget, 4-tile line-of-sight radius, 18 player HP, small levels around 8x8, fog with black unexplored tiles and gray explored memory.
- Weapon baseline: sword, dagger, spear, axe, mace, bow, crossbow, staff, and wand each use distinct weapon-shaped basic attacks.
- Support baseline: tome gives +1 staff/wand damage; shield gives 1 armor and 50% block for half physical damage.
- Enemy-pattern tests: Iron Cultist, Gate Brute, and Ash Seer cover melee pressure, heavier body blocking, and telegraphed caster danger.
- Note: All values are tuning anchors for first playable tests and may change after playtesting.

### Mobile Attack Commit Rule Locked

- Decision: Mobile attacks use tap to preview, then second tap on the same target or a clear confirm button to commit.
- Rationale: This supports the Deliberate Turns, No Real-Time Pressure pillar. Mis-taps feel especially bad in a turn-based tactical game where every committed action advances danger.
- Preview must show range, path/line, expected damage/effects, blocker state, and warnings such as adjacency penalties.
- Note: Fast single-tap attacks may become an optional setting later, but they are not the default.

### MVP Run Structure Locked

- Decision: Target successful MVP run length is 20-35 minutes.
- Failed runs: often 5-15 minutes.
- Long/careful runs: can stretch toward 45 minutes.
- Map length: 8-12 nodes before boss.
- Finale: Larval Avatar only for MVP.
- Save/resume: required between levels; mid-level save/resume desirable if feasible.
- Pacing: early run uses Small levels, low-risk rewards, and basic enemy literacy; mid run adds Medium levels, stronger passives, shops/reforge/gambling, and first elites; late run raises affinity pressure, dangerous rewards, and elite/boss preparation.
- Rule: The player should usually see at least one meaningful build-defining passive by the early-mid run, so the run has identity before the late phase.
- Rationale: This keeps Sealsworn mobile-friendly while leaving enough room for buildcraft, route tension, and protective investment in a promising run.

### Procedural Generation Baseline v0 Locked

- Decision: Seeds reproduce the run map, node structure, level layouts, affinity assignments, enemy placements, reward categories, major event outcomes, and boss/finale setup.
- Manual seed entry is allowed for replay, debug, sharing, and practice, but grants no meta progression.
- Level generation prioritizes readable tactical spaces over novelty.
- Level sizes: Small around 8x8, mostly early and compact special nodes; Medium around 14x12, introduced mid-run; Large/Huge deferred for MVP polish unless needed for boss or rare special node.
- Combat level requirements: clear entrance, clear exit, enough blockers/cover for line of sight to matter, and at least one tactical wrinkle.
- Tactical wrinkle examples: hazard, door, choke point, flank route, blocker/elevation-like obstruction, affinity effect, enemy formation, reward behind danger, optional risky side branch.
- Fog rule: Fog hides exact future danger but must not create unfair instant punishment when new space is revealed.
- Determinism rule: Major facts should be seed-stable once generated or revealed; anything the player routes around or uses for strategic decisions must be deterministic and locked once visible.
- Minor runtime variance may remain flexible for small drop rolls, combat proc rolls, or non-critical reward quantities.
- Generator validation: entrance-to-exit path exists, no required class/item gates, legal enemy placements, intended rewards reachable, and first revealed area cannot immediately punish the player without reasonable response.

### Permadeath and Meta Progression Baseline v0 Locked

- Decision: Death ends the run and returns the hero's spirit to the last outpost.
- Non-seed-replay runs can grant Oath Shards, Echoes, Seal Fragments, class mastery progress, and unlock progress.
- Manual seed runs grant no meta progression, but can still be used for replay, practice, debug, and sharing.
- Primary meta progression unlocks variety, knowledge, starting options, classes, passives, enemy info, affinity info, shops, scouting tools, and class mastery choices.
- Limited direct power is allowed only if capped, scarce, and secondary to variety/knowledge/starting options.
- Rule: Meta progression may give modest starting advantages, but it should primarily widen decisions rather than raise the floor so much that skill stops mattering.
- MVP-safe power examples: alternate starting weapon, starting consumable choice, expanded starting loadout options, class passive variant, limited pre-run scouting, and very sparse capped bonuses such as +1 max HP.
- Avoid/defer: broad permanent damage increases, large HP/armor scaling, permanent crit/dodge stacking, anything that makes early levels irrelevant, and account-wide stat grind as the main progression path.
- First-death line: "Good. You remembered how to die."
- Run summary fields: cause of death or victory, nodes cleared, boss/elite progress, passives consumed/destroyed, notable loot, Oath Shards earned, Echoes discovered, unlock progress, and seed with replay warning if manually used later.

### Item and Passive System Baseline v0 Locked

- Decision: MVP passive pool is 20-30 passives, including 3-5 weird rule-benders.
- Passive rewards are awakened memories, not generic perks.
- Passive modal includes icon, evocative name, one short flavor line, exact mechanical effects, clear Consume choice, and clear Destroy choice.
- Clarity rule: Flavor can be mysterious, but mechanics must be explicit. If Consume has a downside, say so. If Destroy has a known benefit, say so. If Destroy has unknown consequences, label it honestly as unknown.
- Inventory baseline: likely 6 backpack items, no stacking by default.
- Consumables are semi-rare and should feel worth using.
- Loot categories: weapons, armor, jewelry, support items, consumables, pickups, passives, gold, and later affixes/enhancements.
- Item rule: Items use character-level requirements, not minimum run requirements; items roll ranges, affixes, affinities, and enhancements rather than fixed item levels.
- Passive design rule: Every passive should serve at least one pillar. If it does not affect tactical clarity, build synergy, risk, or mystery, it should probably not be in MVP.
- Consume/Destroy rule: Consume is for power and build identity. Destroy is for safety, purification, resources, secrets, or refusal.
- Destroy should usually feel intentional, not like a dead button. It should not always be optimal or always safe.
- Destroy distribution for MVP: 70% small immediate benefit, 20% progress/unlock/hidden flag, 10% no obvious reward but avoids corruption or future danger.
- Destroy reward examples: Oath Shards, healing/cleanse, curse reduction, gold, temporary buff, future reward odds, class mastery/unlock progress, Echo/codex discovery, hidden refusal path, or sealing a dangerous Labyrinth effect.

### Character Selection Baseline v0 Locked

- Decision: MVP available classes are Warrior, Pyromancer, and Ranger.
- Decision: Future classes Necromancer and Shadeblade appear in hero select as grayed-out locked options.
- Locked class UI rules: locked classes cannot be selected, should show a clear unlock hint or requirement, and must avoid implying full near-term content depth beyond MVP scope.
- Class rule: Classes do not start with active class skills at level 1.
- Starting class kit: one class passive and one equipment-synergy passive.
- Starting passives nudge builds but do not force them.
- Future class mastery and in-run talents can add active skills and deeper mechanics.

### Difficulty and Challenge Systems Baseline v0 Locked

- Decision: Sealsworn will not have player-selectable difficulty tiers.
- MVP difficulty comes from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition, and boss preparation.
- Daily challenges, leaderboards, online seeded challenges, and similar competitive/live-service features are deferred.
- Manual seed runs are practice, sharing, replay, and debug tools only; they grant no meta progression.
- Post-MVP challenge content can exist as explicit variant content, trials, oaths, or special runs, but not as a generic selectable difficulty ladder.

### Progression and Balance Baseline v0 Locked

- Decision: Progression should be mostly horizontal: more classes, passives, loot pools, scouting, knowledge, and starting choices.
- Player power should come primarily from in-run buildcraft.
- Meta power can smooth onboarding, but should be capped and sparse.
- Difficulty curve: early teaches enemy patterns and basic positioning; mid tests build identity and route decisions; late pressures resources, punishes sloppy positioning, raises affinity danger, and tests boss readiness.
- MVP economy should be simple and readable first, with one or two sharp risk systems integrated deeply enough to prove the fantasy.
- Do not make curses, corruption, gambling, reforge, sacrifice, shops, secrets, passive destruction, and affinity manipulation all equally deep in MVP.
- MVP economy: gold for shops/reforge/gambling/small services; scarce healing; curses/corruption as one clear risk layer; Oath Shards as post-run meta currency for eligible runs; passives as main build-shaping reward; loot as tactical/build support.
- Risk economy rule: curses/corruption must be readable; curses have clear downsides, cursed rewards have clear upsides, and the player understands the trade before accepting.
- MVP risk examples: strong passive with max HP loss, cursed item with higher stats and future penalty, gold now for increased elite chance later, cheap reforge with corruption, Destroy passive to cleanse/reduce curse, cursed node for better reward odds.
- Balance rule: Short-term survival should compete with long-term build ambition. If the player always chooses safety, rewards are too weak. If the player always chooses greed, danger is too low. If they pause and think, the economy is doing its job.

### Level Design and Affinity Baseline v0 Locked

- Decision: MVP affinity set is Scorched, Flooded/Conductive, Cursed, and Darkness.
- Scorched: failed purge protocol; fire hazards, burning terrain, and damage-over-time pressure.
- Flooded/Conductive: broken ward conduits; water/electric interactions, pathing pressure, and danger zones.
- Cursed: corrupted oath-law; risk/reward, penalties, and dangerous bargains.
- Darkness: failed concealment protocol; reduced visibility, hidden threats, uncertainty, and stronger fog/memory pressure.
- Rationale: Darkness is more identity-rich than Frozen for MVP and aligns with broken concealment systems, uncertainty, cosmic pressure, and the feeling that the Labyrinth is hiding things from the player.
- Level rule: Combat levels must support positioning decisions, line-of-sight play, and at least one tactical wrinkle.
- Special nodes can be compact: shop, reforge, gambling, risk event, secret, or lore.
- Doors and side branches are allowed, but mandatory progress must never require a specific class or item.
- Exits should be clear; hidden/secret exits can be added later.
- Affinities must alter tactical choices, not just visuals.
- Darkness guardrail: Darkness should create uncertainty, not cheap shots. It can reduce visibility, obscure enemy counts, hide rewards, distort explored memory, or empower certain enemies, but must not spawn unavoidable damage from unseen space.

### Art and Audio Direction Baseline v0 Locked

- Decision: Visual style is stylized dark fantasy 2.5D with a top-down or slightly angled orthographic grid.
- Mobile clarity comes first: readable silhouettes, clear tiles, clean effect language, and strong enemy shapes.
- Medieval baseline: steel, stone, candles, bows, armor, ruined keeps, old churches, and fearful villages.
- Cosmic horror is an undercurrent through impossible geometry, subtle distortions, dreams, whispers, and containment failure.
- Wardenwork must read as relic-magic, not science fiction.
- Animation should be simple but expressive: readable attacks, enemy movement, impact flashes, passive pickup pulses, doors sealing, and soul-return effects.
- Audio priority: crisp tactical feedback first, subtle horror ambience second.
- Music uses a dark medieval foundation with restrained cosmic unease and must not overpower tactical readability.
- UI sound should distinguish previews from committed actions and reinforce warnings, reward reveals, and risk choices.

### Technical Experience Baseline v0 Locked

- Decision: Sealsworn is mobile-first and desktop-playable.
- Portrait is likely the main mobile phone play mode because it best supports quick, comfortable, interruption-friendly sessions.
- Landscape is supported on mobile phones, tablets, and desktop/laptop screens.
- Landscape is not a separate game mode; it is the same tactical experience with more visible play space where possible and adaptive UI layout.
- Zoom and inspection controls are available on all devices and orientations.
- Orientation changes improve comfort and visibility, but do not change underlying rules.
- Runs must support interruption-friendly play.
- Save/resume between levels is required; mid-level save/resume is desirable if feasible.
- Combat input must remain readable on phone-sized screens.
- Generated level load target: under 3 seconds for MVP.
- UI preview/selection response target: under 100ms.
- Stable 60 FPS where feasible; 30 FPS acceptable on lower-end mobile if input remains responsive.
- MVP is offline-first with no accounts, multiplayer, cloud saves, leaderboards, or live-service dependency.
- Accessibility baseline: scalable text, colorblind-safe danger communication, clear icons plus labels where needed, no reflex/timing requirements, skippable narrative/control-loss moments, and all critical tactical information available without relying on color alone.

### MVP Success Metrics v0 Locked

- Decision: The top-line success signal is replay intent: after death, victory, or unlock, does the player want one more descent?
- Technical metrics: generated level loads under 3 seconds; preview/selection under 100ms; stable 60 FPS where feasible; 30 FPS acceptable on lower-end mobile if input remains responsive; save/resume between levels works reliably; no critical tactical information depends on color alone; no generator soft-locks.
- Gameplay/comprehension metrics: players understand valid movement and attack options after a short first session; can identify why they took damage or died; understand preview versus commit on mobile; understand Consume and Destroy; and report that positioning choices matter.
- Run-quality metrics: at least one meaningful build-defining passive appears by early-mid run; players encounter at least one tempting risk/reward decision per run; failed runs feel like they taught something; successful MVP runs usually land in the 20-35 minute target; players can name one memorable build, passive, risk, enemy, or moment after a run.
- Behavioral metrics: a meaningful share of players start a second run after death; players use at least two weapon types across early sessions; players make both safe and risky choices across multiple runs; players consume some passives and destroy others; players quit and resume successfully without confusion or lost progress.

### Development Epic Sequence v0 Locked

- Decision: Mobile UX, accessibility, and save/resume move early and thread through every epic rather than being treated as late polish.
- Rule: Every epic must preserve a playable build. After each milestone, the game should still launch, run a small test loop, and validate the main experience.
- Epic sequence: Core Tactical Combat Slice; Mobile UX, Accessibility, and Save/Resume Foundation; Procedural Level Generation v0; Run Map and Forward Progression; Classes and Starting Kits; Loot, Passives, and Consume/Destroy; Risk Economy and Affinities; Outpost, Meta Progression, and Run Summary; Larval Avatar MVP Finale; Playtest Tuning and MVP Readiness.
- Rationale: Since Sealsworn is mobile-first, mobile readability and input cannot be validated only after a desktop-first tactical slice.

### Express Mode Pass

- Decision: Switch from Facilitative mode to Express mode for cleanup and v0 drafting.
- Changes: Promoted GDD status to Express v0 draft, removed resolved designer notes, confirmed Larval Avatar as only required MVP boss, removed the resolved Darkness/Frozen open decision, and added remaining production design details.
- Changes: Rewrote `epics.md` from a provisional table into a detailed v0 epic plan with goals, includes, out-of-scope notes, dependencies, and playable deliverables.

### MVP Asset Baseline v0 Added

- Decision: MVP assets prioritize tactical readability and reusable production value over content volume.
- Baseline: 3 playable class portraits/icons, 2 locked class silhouettes/icons, 3 enemy-pattern visuals, 1 boss visual, 4 affinity treatments, Small/Medium Labyrinth tile/prop set, baseline weapon/support icons, 20-30 passive icons or glyphs, tactical/outpost/run UI frames, core SFX, and ambient loops.
- Note: Placeholder or prototype art is acceptable until the core loop is proven.
