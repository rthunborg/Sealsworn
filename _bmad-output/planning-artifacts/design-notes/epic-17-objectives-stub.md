# Epic 17 — Objectives, Exit Victory & Reward Restructure (STUB)

> **Status:** ⚠️ **STUB — designer pass COMPLETE, architect pass COMPLETE. Awaiting Project Lead
> ratification.** Drafted 2026-07-24 to capture two ratified design directions too large for Epic 15
> or 16. Reviewed and corrected by the Game Designer on **2026-08-05** (§6.1 actions 1-6; see §7) and
> by the Game Architect on **2026-08-05** (§6.2 actions 1-6; see §8).
> Still **not** a ratified epic: no story is registered in `sprint-status.yaml` or `epics.md`, and
> nothing here is ready for `auto-gds`. **It remains a stub deliberately** — the architect pass did
> not register it anywhere.
>
> **✅ PROJECT LEAD RATIFICATION — 2026-08-05. All four items decided.**
>
> | # | Item | **Ratified decision** |
> |---|---|---|
> | 1 | **Container** (§6.1a) | **SPLIT APPROVED.** Direction A → **Epic 17 "Exit Victory and Level Objectives"** (after Epic 16, its pacing release valve). Direction B → **Epic 18 "Destroy-All Outcomes"** (independent; any time after Story 15.6). Both passes recommended this; the Project Lead concurs. |
> | 2 | **Objective kinds** (E17-Q2) | **RATIFIED as designed** — exactly three: `none` / `slay_boss` / `cull_fraction`. |
> | 3 | **Exit visibility** (E17-Q3) | **RATIFIED: locked, not hidden.** Consistent with the GDD's existing "exits should be clear"; fog already supplies concealment. |
> | 4 | **FR75 character-level debt** (§2.3) | **RATIFIED: option (ii) — retire the character-level gate**, keeping FR75's surviving rule ("never gate equipment on run depth") explicit in the GDD. **Recorded as pre-existing debt with its own owner — it belongs to neither Epic 16 nor 17** and is NOT to be absorbed into either. See the ledger entry in `implementation-artifacts/deferred-work.md`. Revisit in-run levelling post-MVP if it is ever wanted; retiring the gate does not foreclose that. |
>
> **Ratification does NOT register these epics.** Epics 17 and 18 enter `epics.md` and
> `sprint-status.yaml` only when Epic 15 is complete and Epic 16 is underway — deliberately, so the
> backlog reflects what is actually next rather than everything that is eventually true.
>
> **⚠️ ARCHITECT FINDING THAT CHANGES DIRECTION A'S SHAPE.** The win condition is **not** a single
> branch in `combat_outcome_evaluator.gd`. `remaining_enemy_count == 0` is enforced at **three
> independent layers**, two of them event-contract validators. Exit-victory therefore needs a **new
> append-only event**, not a relaxed existing one. See **E17-Q6** in §5 and the corrected §2.2.
>
> **Companions:** `epic-16-design-brief.md` (designer pass) · `epic-16-generation-architecture.md`
> (architect pass) · `../../game-architecture.md` §"Dungeon Generation Architecture (Epic 16)" (the
> technical design, incl. §9 which shapes this epic) · `../sprint-change-proposal-2026-07-24.md`
> (Epics 15–16 of record).
> **Build:** `a78653c` · **Designer pass build:** `6b7c4fd` · **Architect pass build:** `6b7c4fd`
> (working tree; suite 205 PASS / 0 FAIL)

---

## 1. Why this epic exists

Two design directions were ratified by the Project Lead on 2026-07-24 while settling Epic 16's
open questions. Both are **genuinely good design** and both are **larger than the stories they were
raised against**, so folding them into Epic 15 or 16 would silently blow those epics' scope:

1. **Exit-based victory with per-level objectives** (raised as Epic-16 question Q3) — deferred out
   of Epic 16 so that geometry, scale, and aggro ship first, and objectives are then designed
   against **real** multi-room floors rather than hypothetical ones.
2. **Reward-choice restructure with a single Destroy-All disposition** (raised from the 2026-07-20
   playtest) — the *structural* half stays in Epic 15 (Story 15.6); the **rich destroy-outcome
   content** lands here, because it needs content design plus a meta/achievement layer that does not
   yet exist.

**Dependency:** Direction A executes **after Epic 16**. The objective system's most interesting cases
(a locked exit behind a boss room, a 50%-cull gate, sneaking past a dormant patrol) are only
meaningful once rooms, corridors, and sight-based aggro exist. **Direction B has no Epic-16
dependency at all** — see §6.1a.

---

## 2. Direction A — Exit victory and level objectives

### 2.1 The ratified design

- **Reaching the exit is the ONLY win condition for any level.**
- The exit may be **hidden** or **locked** until a per-level **objective** is satisfied. Examples
  given: slay the boss; kill ≥50% of the monsters; no objective at all.
- Therefore **stealth or speed is sometimes a complete strategy** — a player may legitimately reach
  the exit without clearing the floor.
- **Skipping has a cost:** enemies and rooms left behind are rewards forfeited.

> **Designer note (2026-08-05):** the "hidden **or** locked" ambiguity is resolved in **E17-Q3**
> below — **locked, not hidden**, for v1.

### 2.2 Why it is epic-scale (the honest impact)

**It changes domain truth.** The shipped condition is `living_enemy_count == 0 → victory`
(`combat_outcome_evaluator.gd`, in `scripts/tactical/outcomes/` — path corrected 2026-08-05) — an
Epic-1 seam. This is not a presentation change.

#### ✅ Consumer trace VERIFIED against the code (architect pass, 2026-08-05)

> §6.2 action 2 asked for a full trace, because the original list was compiled from targeted greps.
> **The trace was run. The original list was wrong in both directions** — it named a consumer that
> does not exist and missed the most important one that does.

**Production consumers of `CombatOutcomeEvaluator` — the complete list (4):**

| Consumer | Role | In the original list? |
|---|---|---|
| `run/interactive_combat_session.gd:453` | **The live on-screen tap loop** — the path a human actually plays | ❌ **MISSED.** The single most important consumer. |
| `run/live_combat_resolver.gd:482` | Headless auto-resolve | ✅ |
| `run/reference_combat_driver.gd:540` | The winnability proof driver | ✅ |
| `tactical/scenarios/epic_1_micro_combat_scenario.gd:108` | The Epic-1 scenario harness | ❌ Missed |

**The finale path is NOT a consumer.** The original list named it; the trace shows no boss file
references `CombatOutcomeEvaluator` at all. The Larval Avatar resolves through its own seam —
`BossPhaseResolver` / `BossTurnResolver` / `RunOrchestrator.resolve_boss_victory()` /
`RecordFirstVictoryCommand`. **This is good news for E17-Q5's architect half** and is answered there.

**Test consumers (5 files):** `test_combat_outcome_evaluator.gd`, `test_class_start_smoke_slice.gd`,
`test_interactive_combat_session.gd`, `test_live_combat_resolver.gd`, `test_reference_combat_driver.gd`.

#### ⚠️ The seam the trace found that no grep would have: three enforcement layers

**The win condition is not one branch. `remaining_enemy_count == 0` is asserted independently at
three layers, two of which are event-contract validators rather than gameplay logic:**

1. `CombatOutcomeEvaluator.evaluate` — the gameplay branch (the one everyone knows about).
2. `DomainEvent._validate_level_victory_reached_payload` — a **static payload validator** that
   rejects any `level_victory_reached` payload where `remaining_enemy_count != 0`.
3. `BoardState._validate_level_victory_reached_event` — an **apply-time validator** that rejects the
   event unless the board holds zero living enemies *and* the payload's `defeated_enemy_ids` matches
   the board's complete defeated list exactly.

Plus a fourth constraint: `CombatOutcomeState.apply_outcome_event` accepts only
`LEVEL_VICTORY_REACHED` / `LEVEL_DEFEAT_REACHED` and returns `unsupported_event` for anything else.

**Consequence: exit-victory cannot be shipped by flipping a branch.** See **E17-Q6**.

Consequences to plan for:

| Impact | Detail |
|---|---|
| **New content concept** | Level objectives need a definition type, a repository, validation, and `LevelRecipeDefinition` wiring — the Epic-3 content-boundary pattern |
| **Winnability proof changes meaning** | "Can this class kill everything?" becomes "Can this class reach the exit?" — a different question needing a different driver policy, and a re-derived seed catalog. **Note (2026-08-05): this is a WEAKER condition than the current one** — a class that can kill everything can certainly walk to the exit — so most catalog seeds should survive. The expensive case is `cull_fraction`, which is nearly as strong as the old condition. |
| **Exit reachability becomes load-bearing** | Epic 16's connectivity validator proves the exit is *reachable*; Epic 17 additionally needs it *satisfiable* (an objective must be completable on the generated floor) |
| **Fingerprint risk** | Combat-replay composites almost certainly move; layout fingerprints should not. Plan one justified re-pin, per the 14.1 / 16.1 / 16.2 discipline. **Architect note (2026-08-05): substantially confirmed, with one addition — if objective KIND is a weighted draw, it hits the `map` stream and moves route/affinity fixtures too. See E17-Q8.** |
| **Event contract, not just logic** | **Added 2026-08-05.** Victory is guarded by two event-payload validators on top of the gameplay branch. Direction A needs a **new append-only event**, not a relaxed existing one — see E17-Q6. This is a different (and safer) shape of work than "change the win condition" implies. |
| **Reward forfeiture must be real** | Skipping only costs something if unclaimed rewards are actually withheld — which touches the reward/loot flow. **This is the balance keystone, not a side effect** — see §2.4 story 17.4 |

### 2.3 ✅ RESOLVED: the XP gap (E17-Q1)

> **Answered by the designer pass, 2026-08-05.** The stub's original two-branch framing was built on
> an incomplete verification. Both branches are superseded by the finding below; the obsolete
> branch text has been deleted per §6.1 action 1.

**The ratified Q3 wording says a skipping player "misses out on XP and loot."**

**Answer: "XP" means the existing currencies.** For Direction A's purposes, what a skipping player
forfeits is **gold, loot, passive offers, and the Oath Shards / Echoes / class-mastery progress that
flow from a deeper, richer run**. All of these exist and are shipped. **Direction A requires no new
progression system**, and its scope stands as described in §2.2.

**But the verification that produced the original question was incomplete, and the real finding is
larger.** Re-verified against the working tree on 2026-08-05:

| Claim | Verdict |
|---|---|
| No XP concept in `godot/scripts/` | **TRUE** — no experience points, no earning, no curve |
| No character-*level* concept | **FALSE — and this matters** |

`character_level_requirement` is a **shipped, validated, content-populated field** on
`ArmorDefinition` and `JewelryDefinition` (`scripts/content/definitions/`), with a
`LEVEL_REQUIREMENT_NONE = 0` sentinel and a `requires_character_level()` accessor. It is backed by
**ratified GDD FR75** — *"Items must use character-level requirements rather than minimum run
requirements"* — and `gdd.md` ("Items use character-level requirements, not minimum run
requirements"), traced to **Story 6.1** in the epics.md readiness-patch map.

**Four shipped baseline items carry non-zero gates:**

| Item | Gate |
|---|---:|
| `chain_hauberk` | character level 2 |
| `warded_plate` | character level 4 |
| `jasper_amulet` | character level 2 |
| `sealbearers_signet` | character level 4 |

**Nothing can ever satisfy them.** `requires_character_level()` has no production consumer outside
its own unit tests, because no character level exists anywhere in run state, profile state, or the
save snapshot. Epic 6 shipped the **demand side** of character progression; the **supply side** has
never existed.

#### ⚠️ Escalation to the Project Lead

**GDD FR75 is currently unsatisfiable, and this is pre-existing debt that belongs to neither Epic 16
nor Epic 17.** It was surfaced by this pass, not caused by it. It needs its own decision:

- **(i) Build in-run character levels.** Its own epic, post-Epic-17. Makes FR75 true, brings four
  dead baseline items to life, and gives "skipping enemies costs XP" literal teeth.
- **(ii) Retire the character-level gate.** Drop the field; keep FR75's *actual* intent — **never
  gate equipment on run depth** — as the surviving rule. Cheap, honest, removes dead content.
- **(iii) Leave it.** Not recommended: four of six baseline armour/jewellery items keep a gate
  nothing can satisfy, which is either dead content or a silently ignored field.

**Designer recommendation: (ii) for MVP, revisit (i) post-MVP.** FR75's protective intent was
"don't gate on run depth"; character level was the *alternative named*, not necessarily a commitment
to build a levelling system. Retiring the gate preserves the intent at near-zero cost.

#### 🏛️ Architect assessment of option (ii) — §6.2 action 6

**Option (ii) has ZERO save-migration cost and a small, fully-enumerated content-boundary cost.
"Near-zero" is confirmed by trace, not assumed.**

**Save migration: none.** `InventoryState` serializes backpack slots as `{item_id, category,
quantity}` and equipment as `{slot: item_id}` — **item IDs only, never definition fields**. No
snapshot anywhere carries `character_level_requirement`. So retiring the field cannot invalidate a
save, needs no migration step, no `SCHEMA_VERSION` bump, and no migration test. The 23-key
`RunSnapshot` gate is untouched.

**Content boundary: 5 production files, all definition-layer.**

| File | What it holds |
|---|---|
| `content/definitions/armor_definition.gd` | The field, `LEVEL_REQUIREMENT_NONE = 0`, `requires_character_level()`, validation |
| `content/definitions/jewelry_definition.gd` | Same |
| `content/repositories/armor_repository.gd` | Baseline values: `chain_hauberk` 2, `warded_plate` 4 |
| `content/repositories/jewelry_repository.gd` | Baseline values: `jasper_amulet` 2, `sealbearers_signet` 4 |
| `content/definitions/consumable_definition.gd` | **A comment only** — "NO EQUIP GATE: consumables are not equipped, so they carry NO `character_level_requirement`". Documentation, not code. |

**No production consumer outside the definition layer.** No command, no equip path, no view model,
and no repository query reads `requires_character_level()`. The designer's finding — that Epic 6
shipped the demand side and the supply side never existed — is confirmed exactly.

**Test surface: ~13 references across 6 test files** (`test_armor_definition.gd`,
`test_jewelry_definition.gd`, `test_armor_repository.gd`, `test_jewelry_repository.gd`,
`test_consumable_definition.gd`, `test_pickup_definition.gd`). Several assert the *absence* of a gate
on non-equippable categories; those assertions survive retirement unchanged in intent.

**One thing retirement would cost that is worth naming:** `requires_character_level()` is currently
the only place the codebase records that *equipment gating is a concept the design cares about*.
Retiring it silently loses that. **If (ii) is chosen, keep FR75's surviving rule explicit in
`epics.md` and `gdd.md` — "equipment is never gated on run depth" — so the protective intent outlives
the field.**

**Architect recommendation: (ii), and it is genuinely cheap.** No blocker to either epic. It is
independent of Direction A and Direction B and can be executed in any order relative to them —
**it should not be attached to Epic 17**, which is exactly what the escalation says.

#### Correction to the original branch (b)

The stub previously argued a real XP system would collide with *"the GDD's deliberately shallow
meta-power stance."* **That objection is mistaken and is withdrawn.** The GDD's anti-grind language
("Account-wide stat grind as the main progression path", "Broad permanent damage increases") governs
**meta / account** progression. An **in-run** character level that resets every run is not account
power — it is in-run buildcraft, which the GDD explicitly names as the primary power source
("Player power should come primarily from in-run buildcraft"). It is also precisely the
Shattered-Pixel-Dungeon model the Epic-16 scale target already invokes. So option (i) above, **if
scoped in-run only, does not contradict the GDD.** It is a scope decision, not a design conflict.

### 2.4 Provisional stories (designer-corrected 2026-08-05)

- **17.1** Level-objective content model — definitions, repository, `LevelRecipeDefinition` wiring,
  validation. **Now also owns objective *satisfiability* validation** (an objective must be
  completable on the generated floor), which §2.2 identified but no story carried. This extends
  Epic 16's connectivity validator rather than duplicating it — flagged to the architect as E17-Q7.
  > **Architect correction (ratified 2026-08-05):** satisfiability for **`none` and `slay_boss` in
  > full**, plus the **necessary (geometry + count) half of `cull_fraction`** — ≥2 living enemies,
  > all enemies on the reachable set, `ceil(0.5 × enemy_count)` in rooms with fightable space, exit
  > still reachable once the threshold is met. The **sufficient** half (can a class actually reach
  > the threshold and then the exit?) is not decidable by a flood fill and belongs to **17.5**.
  > See E17-Q7.
- **17.2** Exit-victory condition in the domain — outcome evaluator, resolvers, justified re-pin.
  > **Architect correction (2026-08-05):** this is a **new append-only `level_exit_reached` event**
  > plus a `LevelObjectiveEvaluator`, *not* a modification of `level_victory_reached`, whose
  > `remaining_enemy_count == 0` contract is enforced by two independent event validators. The
  > existing all-enemies-dead victory branch is **kept**. See E17-Q6.
- **17.3** Objective/exit presentation — is the exit locked, what unlocks it, where is it.
  **Priority raised: this ships WITH 17.2, not after it.** It is not polish. An unannounced lock
  condition turns a floor into a maze and makes the whole system invisible; 17.2 without 17.3 is not
  a shippable state.
- **17.4** Reward forfeiture — skipped rooms genuinely withhold their rewards. **This is the balance
  keystone.** Without it, skipping is strictly dominant and Direction A degrades every floor into a
  footrace. It is not a follow-up; it is what makes the choice a choice.
- **17.5** Winnability re-proof under exit-victory — new driver policy, re-derived catalog. Likely
  **cheaper than §2.2 originally implied** (see the corrected impact-table row).
  > **Architect additions (ratified 2026-08-05):** (a) absorbs the **sufficient** half of
  > `cull_fraction` satisfiability (the necessary half stays in 17.1 — see E17-Q7);
  > (b) **budget driver-policy work explicitly inside this story** — a fight-to-threshold-then-
  > navigate-to-exit policy is harder than either fighting or fleeing, and the Story 14.1 precedent
  > shows policy fragility surfaces as catalog failure if it is not budgeted up front;
  > (c) must run on **post-Epic-16 geometry**, or the expensive bill is paid twice. See E17-Q8.

---

## 3. Direction B — Reward restructure and Destroy-All outcomes

### 3.1 The ratified design

Observed in the 2026-07-20 playtest: the passive reward modal offered three passives, **each with
its own Consume/Destroy pair**. That framing is wrong — it makes "destroy" a property of each card
instead of a decision about the whole offer.

The ratified model: **three rewards; the player picks exactly one — OR chooses a single "Destroy"
at the bottom of the modal, which destroys ALL the offered rewards.** Destroying is a real
alternative play, not a fallback: it may grant **boons**, inflict **debuffs**, create **synergies**,
or unlock **secrets / meta unlocks / achievements**.

### 3.2 The split — reviewed and UPHELD (designer pass, 2026-08-05)

§6.1 action 4 asked whether the structural half should stay in Story 15.6. **It should. The split is
correct and 15.6 keeps it.**

Reasons: 15.6 fixes a defect observed in a live playtest; it is UI/flow work over the existing
`DestroyPassiveCommand`; it is registered and still in `backlog`, so nothing is being retrofitted;
and — decisively — **v0 destroy outcomes are already record-only**, so 15.6 changes what the player
is *offered* without changing what destroying *does*. That is a genuinely clean seam. Moving it to
Epic 17 would ship a known-wrong modal through all of Epic 16 for no benefit.

| Half | Home | Rationale |
|---|---|---|
| **Structural** — three rewards, pick one, single Destroy-All button | **Story 15.6** (Epic 15) | A UI/flow restructure over the existing `DestroyPassiveCommand`; small, and it fixes a live playtest defect |
| **Behavioural + content** — making recorded outcomes REAL, plus the outcome table (boons, debuffs, synergies, secrets, meta unlocks) | **Direction B (here)** | Needs content design **and a domain behaviour change to a shipped command** |

> **Correction (2026-08-05):** the original table called the Epic-17 half "content". It is **not only
> content** — switching destroy outcomes from record-only to live **changes the behaviour of a
> shipped command** and may require an append-only event. The stub's own §3.3 said this correctly
> while the table undersold it; the table above is corrected. Flagged to the architect as §6.2
> action 5.

### 3.3 What exists to build on

`DestroyPassiveCommand` (Story 6.6) already exists with a `DestroyOutcomeTableDefinition` and a
named-stream roll. **Critically, v0 destroy outcomes are `OUTCOME-RECORD-ONLY`** — the command
records what *would* happen without applying live effects (the deliberate 6.3 gold-reward-as-outcome
precedent). So Direction B is largely about **making recorded outcomes real** and expanding the
table, not inventing the mechanism.

The "achievement surface" question is **resolved** — see E17-Q4 in §5. No new surface is built.

### 3.3a 🏛️ Architect sizing of the domain-contract touch — §6.2 action 5

**Sized: SMALL. Smaller than §3.2's correction implies, because the "record-only → live" transition
is already precedented inside this very command.**

`DestroyPassiveCommand` is **not purely record-only today.** Story 6.6 already ships one live
effect: when the rolled outcome is `minor_restoration`, the command **reduces `curse_count` /
corruption** on the run — a real mutation, keyed off the machine-pinned `outcome_id` rather than
free text, applied *after* the 70/20/10 roll, drawing **zero additional RNG**.

That matters for three reasons:

1. **The mechanism exists and is test-pinned.** Direction B is extending a shipped pattern, not
   inventing one. "How does a rolled outcome become a mutation?" is already answered.
2. **The keying discipline is already settled.** Outcomes key off `outcome_id` / `outcome_category`,
   never free-text `outcome_effect`. That decision (the 6.6 Round-2 [Review][Decision]) should be
   restated as binding for every new outcome Direction B adds.
3. **§3.2's decisive argument for the 15.6 split still holds, but needs one word changed.** The
   claim "v0 destroy outcomes are already record-only" is now **mostly** true rather than wholly
   true. The split is still correct — 15.6 changes what the player is *offered*, not what destroying
   *does* — but the clean-seam argument rests on 15.6 touching only the offer, which it does.

**What Direction B actually costs at the domain boundary:**

| Item | Size | Note |
|---|---|---|
| Applying outcomes live | **Small** | Extends the `minor_restoration` pattern per outcome. Each new live outcome is a mutation keyed off `outcome_id`, zero extra RNG. |
| Event surface | **Possibly zero** | `passive_destroyed` already carries `outcome_category` + `outcome_id` + effect marker + draw provenance. If every new outcome maps onto an existing mutation with an existing event (Echo grant, unlock progress, curse change), **no new event type is needed.** Only an outcome with no existing recording path needs an append-only tail event. |
| RNG | **Zero change** | The 70/20/10 roll on the `rewards` stream stays exactly as shipped. Do **not** add a second roll. |
| Save schema | **Zero** | Outcomes land in currencies and counters that already serialize. |
| Fingerprints | **Low** | The reward composite may move if the outcome table's entries change; the roll itself does not. |

**Architect view: Direction B is a 1–2 story epic that does not need to wait behind anything.** It
confirms §6.1a's split recommendation on independent grounds — see §8.

### 3.4 Provisional stories (designer-corrected 2026-08-05)

- **17.6** Destroy-All outcome table content, **and applying outcomes live rather than record-only**
  (the domain-behaviour half). Outcomes map onto the existing meta layer per E17-Q4.
- ~~**17.7** Secrets / achievements surface~~ — **DELETED.** E17-Q4 resolves this: secrets and
  unlocks route through the **existing** Echo / unlock-progress meta layer. No new surface is built,
  so there is no story to write. Any presentation work is absorbed into 17.6.

---

## 4. What this stub deliberately does NOT do

- **Does not register anything in `sprint-status.yaml`.** Epic 17 has no backlog entries; it is not
  pickup-able by `auto-gds`, by design.
- **Does not touch `epics.md`.** Epic 17 enters the canonical epics list only after the designer and
  architect passes have corrected this stub and the Project Lead ratifies it. *(The designer pass of
  2026-08-05 edited `epics.md` only for **Epic 16** — FR71 and the FR37/38/39 amendments — never for
  Epic 17.)*
- **Does not decide the FR75 character-level question** (§2.3) — that is escalated to the Project
  Lead as pre-existing debt outside both epics.
- **Does not affect Epic 15 or Epic 16**, both of which are registered and ready. Epic 15's Story
  15.6 carries only the *structural* half of Direction B, and the designer pass upheld that split.

---

## 5. Open questions — designer answers recorded

| # | Question | Owner | Status |
|---|---|---|---|
| **E17-Q1** | Is "XP" the existing currencies, or a genuine new progression system? | Designer | ✅ **Existing currencies** — see §2.3. Separate FR75 debt escalated. |
| **E17-Q2** | What objective kinds ship in v1? | Designer | ✅ **Three: `none`, `slay_boss`, `cull_fraction`** — see below |
| **E17-Q3** | Is the exit *hidden* or merely *locked*? | Designer | ✅ **Locked, not hidden** — see below |
| **E17-Q4** | Own surface for secrets/achievements, or the existing meta layer? | Designer | ✅ **Existing meta layer; build no new surface** — see below |
| **E17-Q5** | How does exit-victory interact with the boss node and the finale? | Designer + Architect | ✅ **Both halves answered.** Designer half below; **architect half: the finale does NOT route through the outcome evaluator today** — see below |
| **E17-Q6** | Where does the win condition live after the change? | Architect | ✅ **A new append-only `level_exit_reached` event + a `LevelObjectiveEvaluator`.** Not a relaxed `level_victory_reached` — see below |
| **E17-Q7** | How is "objective satisfiable on this floor" validated at generation time? | Architect | ✅ **Extend AD-4 — confirmed.** `cull_fraction` splits **necessary (17.1) / sufficient (17.5)**; `none` and `slay_boss` stay wholly in 17.1 |
| **E17-Q8** | Re-pin and winnability-re-proof plan for a changed win condition? | Architect | ✅ **Exactly one combat re-pin.** Layout, route, affinity, finale, and save all hold — the objective-kind draw appends at the tail, per Epic 16's pattern |

### E17-Q2 — Objective kinds for v1: exactly three

| Kind | Meaning | Where it fits |
|---|---|---|
| **`none`** | The exit is open from the start. | **The default and the majority case.** Preserves "one node = one fight" on most floors. |
| **`slay_boss`** | The exit unlocks when the floor's designated boss/elite dies. | Boss node and elite nodes. Already how the finale reads. |
| **`cull_fraction`** | The exit unlocks at ≥N% of the floor's living enemies defeated (**50% baseline**). | Mid/late combat floors. The interesting middle case. |

**Deferred, deliberately:** fetch/key objectives, survive-N-rounds, reach-the-exit-before-round-N
(that one waits on the Q2b round counter), escort, and anything requiring a new entity type. Each
additional kind multiplies both generation-satisfiability validation and winnability re-proof cost —
three kinds is enough to prove the system.

**Weighting follows the house contract: positive weights only, never exclusive.** `none` dominates
early; objectives grow more common with depth; no kind is ever impossible at any depth.

### E17-Q3 — The exit is LOCKED, not hidden

**For v1 the exit is a normal map feature, revealed by exploration like anything else, that renders
visibly SEALED when its objective is unmet, with the unmet condition stated in plain language.**

- **Fog already provides the hiddenness.** An unexplored exit is invisible today. A second
  concealment layer on top of fog is redundant and unreadable.
- **A hidden exit turns a floor into a search problem.** The GDD is explicit that generation
  "prioritizes readable tactical spaces over novelty" and that fog "must not create unfair instant
  punishment". Hunt-the-pixel is the failure mode both lines exist to prevent.
- **Locked-and-visible is what makes the objective a decision.** "The exit is right there, sealed,
  and the seal wants half the floor dead" is a tempting mistake — pillar 4, *Risk Is the Run's
  Currency*. "There is an exit somewhere" is just homework.
- **The GDD already takes this position.** Level Progression states: *"Exits should be clear. Hidden
  or secret exits can be added later."* Locked-now / hidden-later is the existing stance, and this
  answer is consistent with it rather than overriding it.

Secret exits remain a legitimate **post-MVP** idea, on top of a locked-exit system that already works.

### E17-Q4 — Map onto the existing meta layer; build no achievement surface

The shipped meta layer already carries every currency Direction B needs: **Oath Shards**, **Echoes**
(lore/codex discoveries), **Seal Fragments**, **class mastery progress**, and **unlock progress**.
Echoes *are* the discovery surface. Unlock progress *is* the achievement surface.

- A destroy outcome that "reveals a secret" grants an **Echo**. One that "unlocks something" advances
  **unlock progress**. Both are already listed as Destroy reward examples in the GDD.
- The GDD caps MVP meta at *"a small unlock tree or menu, not a deep account-power grind."* A parallel
  achievement system is exactly the second meta surface that stance rejects.
- Player-facing achievements as a distinct list are **post-MVP**, and arguably a platform feature
  (Game Center / Play Games) rather than a game system.

**Consequence:** story 17.7 is deleted (§3.4).

### E17-Q5 — Designer half: the boss node

Exit-victory and the boss finale do **not** conflict. The boss node is simply the canonical
`slay_boss` case: its exit unlocks when the Larval Avatar dies. The MVP victory condition in the GDD
("defeat the Larval Avatar at the final node") is preserved exactly — it becomes an *instance* of the
objective model rather than an exception to it, which is a tidier design than it was before.

The one guardrail: **the boss node must never be skippable.** `slay_boss` on the finale floor is not
a weighted draw — it is fixed content.

### 🏛️ E17-Q5 — Architect half: the finale keeps its own seam, and always has

**Answered by the §2.2 consumer trace: the boss/finale path does not consume `CombatOutcomeEvaluator`
at all.** No file in the boss chain references it. The Larval Avatar resolves through
`BossPhaseResolver` → `BossTurnResolver` → `RunOrchestrator.resolve_boss_victory()` →
`RecordFirstVictoryCommand`, a wholly separate path.

**So the finale is not at risk from this change, and needs no work in Direction A.** The designer's
framing — that the boss node is "simply the canonical `slay_boss` case" — is true *as design*, and it
is even cheaper than it sounds *as architecture*: the boss floor already behaves as a fixed
`slay_boss` objective by construction, on its own seam, with the arena excluded from the room/corridor
generator (Epic 16 OQ-4).

**Recommendation: leave it that way.** Do not route the finale through the new objective evaluator in
v1. Unifying them is a tidiness win with a real regression risk against the one path that ends a run
in victory, and it buys nothing the player can perceive. Revisit only if a second boss ever exists.

**The "never skippable" guardrail is therefore free** — it is enforced by the finale never consulting
the objective system at all, rather than by a special case inside it.

### 🏛️ E17-Q6 — Where the win condition lives: a new event, not a relaxed one

**Answer: a new `LevelObjectiveEvaluator` at the same seam as `CombatOutcomeEvaluator`, emitting a
new append-only tail event `level_exit_reached`. `level_victory_reached` keeps its exact current
meaning and every existing consumer is untouched.**

This is forced by the §2.2 finding. `remaining_enemy_count == 0` is not a branch — it is a **validated
event contract** enforced at three layers, two of which reject the event before it reaches gameplay:

- `DomainEvent._validate_level_victory_reached_payload` hard-rejects `remaining_enemy_count != 0`.
- `BoardState._validate_level_victory_reached_event` hard-rejects the event unless the board holds
  zero living enemies **and** `defeated_enemy_ids` equals the board's complete defeated list.

Emitting `level_victory_reached` on an exit-victory (enemies still alive) is rejected **twice** before
`CombatOutcomeState` ever sees it. The two available shapes:

| Shape | Cost | Verdict |
|---|---|---|
| **Relax the two validators** to accept a non-zero remaining count | Weakens a validated domain contract for *every* consumer, including the auto-resolve resolver and the winnability driver, which legitimately rely on it. Every existing victory assertion loses its guarantee. | ❌ **Rejected** |
| **New append-only tail event `level_exit_reached`** with its own payload validator and its own `BoardState` apply-time validator; `CombatOutcomeState` maps it to `STATE_VICTORY` | One tail enum member, two small validators, one outcome-state branch. Existing semantics fully preserved. | ✅ **Recommended** |

**Concrete shape:**

- `DomainEvent.Type` grows by exactly **one append-only tail member** (`level_exit_reached`), on top
  of Epic 16's `enemy_awakened`. Enum ordering discipline is preserved; index assignment depends on
  epic ordering and must be stated in the story, not assumed.
- Its payload asserts what exit-victory actually means: the hero occupies the exit cell, the floor's
  objective is satisfied, and it **records** `remaining_enemy_count` (any value ≥ 0) plus the
  forfeited-reward count for 17.4.
- `LevelObjectiveEvaluator` is a **pure evaluator sibling** of `CombatOutcomeEvaluator`, called from
  the same four consumers. Defeat is unchanged and continues to flow through `level_defeat_reached`.
- **`CombatOutcomeEvaluator` keeps its all-enemies-dead victory branch**, which remains correct: a
  floor cleared of enemies is still a win. Exit-victory is an *additional* path to `STATE_VICTORY`,
  not a replacement. This is what makes E17-Q8's "weaker condition" reasoning hold.

### 🏛️ E17-Q7 — Extend AD-4, confirmed — with one carve-out

**The designer's lean is CONFIRMED. Do not build a parallel validator.** The Epic-16 architect pass
has shaped AD-4 accordingly (see `game-architecture.md` §9): the connectivity validator is being
built as a **reachability oracle plus a registered list of satisfiability predicates**, rather than
four hard-coded checks. Epic 16 registers one predicate; Epic 17 registers its objective kinds
against the same oracle. **The flood-fill, the reachable set, and the membership test are written
once and never rewritten.** That shaping costs Epic 16 a parameter and an array.

**The carve-out — a refinement of the story boundary, not of the principle.**

`cull_fraction` is **not a generation-time reachability property**, and no amount of extending AD-4
will make it one. "Is the exit reachable?" and "does a boss exist on this floor?" are questions about
geometry. "Can ≥50% of this floor's enemies be **defeated** by this class?" is a question about
combat — AD-4's flood fill has no model of damage, HP, or class kit.

| Objective kind | Satisfiability is… | Home |
|---|---|---|
| `none` | Trivial — exit reachability, already proven by AD-4 | **17.1**, as scoped |
| `slay_boss` | Geometry — the boss exists and is reachable | **17.1**, as scoped |
| `cull_fraction` | **Split** — see below | **17.1 + 17.5** |

**✅ RATIFIED 2026-08-05 (Project Lead): `cull_fraction` splits necessary/sufficient.**

| | Condition | Owner | Method |
|---|---|---|---|
| **Necessary** | ≥2 living enemies (so a 50% threshold is meaningful in whole units); every enemy on the reachable set; `ceil(0.5 × enemy_count)` enemies sit in rooms with fightable space; the exit stays reachable once the threshold is met | **17.1** | AD-4's oracle — geometry and counting |
| **Sufficient** | A class can actually reach the threshold *and then* reach the exit | **17.5** | Reference driver only |

This keeps each story's acceptance criteria provable by the tool that story owns. The two rejected
alternatives are worth recording: leaving the whole question in 17.1 puts an **unanswerable AC**
inside the validator — the kind satisfied by a check that looks right and proves nothing; moving it
wholly to 17.5 leaves **no generation-time guard at all**, permitting degenerate floors (a
`cull_fraction` objective on a one-enemy floor, or on enemies sealed where the threshold cannot be
met).

**The "extend, don't duplicate" principle and AD-4's shape are unchanged. Only the story boundary
moves.**

### 🏛️ E17-Q8 — Re-pin and winnability-re-proof plan

**Answer: yes, the combat-side change can be confined to ONE justified re-pin — with a caveat §2.2
did not anticipate.**

**What moves:**

| Fixture family | Moves? | Why |
|---|---|---|
| **Layout fingerprints** | **No** | Direction A adds no draw to the layout phase. Objectives are node properties, not geometry. |
| **Combat-replay composites** | **Yes — the one justified re-pin** | The driver gains a navigate-to-exit policy, so replays diverge even on seeds whose *outcome* is unchanged. |
| **Route / affinity fixtures** | **No — if the objective-kind draw is appended at the tail** | See below. |
| **Finale fingerprints** | **No** | The finale does not consume the changed seam (E17-Q5). |
| **Save schema** | **No** | Objectives are content + node properties; the 23-key gate is unaffected. |

**Objective kind is a weighted draw, and it lands on the same stream as size class — follow Epic 16's
pattern exactly and it is free.** E17-Q2 ratifies three kinds on positive weights, growing more common
with depth — structurally the same shape as Epic 16's depth-weighted size-class bands.

Epic 16 (ratified 2026-08-05) appends its size-class draws at the **tail** of `RouteGenerator`'s fixed
draw order and stores the value on `RouteNode`, which costs **zero fingerprint movement**: route
generation mints its own `map` stream-set instance (so affinity is decoupled), and
`RouteGenerator.fingerprint()` does not cover the new field. **Direction A should append its
objective-kind draw immediately after Epic 16's size-class draw, in the same pass, on the same
principle** — one more tail draw on an order that already exists, one more non-fingerprinted
`RouteNode` field.

Two conditions carry over and must be honored, or the freebie evaporates:

1. **Tail placement is load-bearing.** Inserting the draw anywhere before step (4) shifts every route
   fingerprint. Append only.
2. **Coverage is paid for separately.** As with size class, add the objective-kind distribution to
   the batch fixture (bands hold with depth; **no kind is ever zero-probability at any depth** — the
   positive-weights contract). Do not fold either field into the route fingerprint.

**Winnability re-proof — the designer's weaker-condition finding is CONFIRMED and strengthened.**
Exit-victory is strictly weaker than all-enemies-dead: any class that can kill everything can walk to
the exit. And because E17-Q6 keeps `CombatOutcomeEvaluator`'s existing victory branch intact,
**every currently-winnable seed remains winnable by its existing path.** The catalog cannot regress on
the `none` / `slay_boss` kinds; it can only gain.

So the re-proof cost is **not** a full re-derive:

- `none` / `slay_boss` — **cheap.** Existing catalog entries remain valid; add exit-reach proofs.
- `cull_fraction` — **the expensive case**, as the designer identified. At 50% it is nearly as strong
  as the old condition, and it needs a genuinely new driver policy (fight to a threshold, *then*
  disengage and navigate to the exit) — which is a harder policy than either fighting or fleeing.
- **Budget driver-policy work explicitly inside 17.5**, exactly as Epic 16 budgets it inside 16.2.
  The Story 14.1 precedent (a geometry change made a Medium seed unwinnable by the kite heuristic)
  applies with full force here.

**One sequencing note that saves real work:** Direction A's re-proof should run on **post-Epic-16
geometry**. Re-proving against open-room boards and then again against room/corridor boards pays the
same expensive bill twice. This is a concrete reason the dependency in §6.1a is real and not just
thematic.

### Sanity-check against the Epic-16 GDD pass (§6.1 action 3)

**Yes — exit-victory shortens runs, materially. That is good news, and it changes how this direction
should be understood.**

Under the current all-enemies-dead condition, a floor's duration is bounded below by "kill
everything", which scales with both enemy count and traversal distance. That is precisely the
pressure the Epic-16 GDD pass had to write down honestly: 1 tile/turn movement × ~4.3× board area ×
movement animation all push node duration the same way, leaving **size-class mix as the only free
pacing lever**.

**Direction A adds a second lever, and a better one.** Under exit-victory, floor size stops being a
duration *tax* and becomes a duration *choice*: the player who wants the rewards pays the turns, and
the player who wants tempo walks. That reframes Direction A:

> **Direction A is the pacing release valve for Epic 16 — not an unrelated feature.** If Epic 16
> ships and measured runs overshoot the 20-35 minute average-run target, this is the fix. It
> strengthens the case for sequencing it tightly after Epic 16.

Two things to watch, neither a blocker:

- **Runs could get too short.** Mitigated by **17.4 (reward forfeiture) being real** — a player who
  sprints past everything arrives at tier 6 with a weak build and dies there. That is self-correcting
  and it is pillar 4 working as designed. It only works if 17.4 actually lands.
- **`cull_fraction` must not become a difficulty dial.** Do not scale the percentage upward with
  depth as a challenge knob — that would breach the difficulty non-goal the Epic-16 pass just
  restated. Vary it for **texture**, on positive weights, like everything else.

**Difficulty non-goal: unaffected.** Objectives are structure, not scaling. No objective kind
introduces a stat multiplier or a selectable tier.

---

## 6. ⚑ REVIEWER INSTRUCTIONS — required actions on this stub

### 6.1 Game Designer (Samus Shepard) — ✅ COMPLETE 2026-08-05

| # | Action | Result |
|---|---|---|
| 1 | Answer E17-Q1, record in §2.3, delete the branch that does not apply | ✅ §2.3 rewritten; both original branches superseded and deleted; FR75 debt escalated |
| 2 | Answer E17-Q2, E17-Q3, E17-Q4 and record in §5 | ✅ All three answered in §5, plus the designer half of E17-Q5 |
| 3 | Sanity-check Direction A against the Epic-16 GDD pacing target and difficulty non-goal | ✅ §5 closing subsection — it **does** shorten runs, and that reframes it as Epic 16's pacing release valve |
| 4 | Challenge the §3.2 split | ✅ **Split upheld**; 15.6 keeps the structural half. Table corrected — the Epic-17 half is behaviour + content, not content alone |
| 5 | Correct or delete the provisional story lists | ✅ §2.4 corrected (17.1 absorbs satisfiability validation; 17.3 promoted to ship with 17.2; 17.4 named the balance keystone; 17.5 downgraded in cost). §3.4: **17.7 deleted** |
| 6 | State whether Epic 17 is the right container | ✅ **No — recommend splitting.** See §6.1a |

### 6.1a Container recommendation: SPLIT into two epics

**Epic 17 is not the right container. Directions A and B should be separate epics.**

They share no machinery, no dependency, and no risk profile. The stub groups them only because both
were deferred on the same day — which is a filing accident, not a design relationship.

| | **Direction A** | **Direction B** |
|---|---|---|
| Nature | Domain-truth surgery on the win condition | Content + making a record-only command live |
| Depends on Epic 16 | **Yes** — objectives need rooms, corridors, aggro | **No** — only on Story 15.6 |
| Fingerprint risk | High — combat composites move, one justified re-pin | Low |
| Size | ~5 stories | ~1-2 stories |
| Playable outcome | "Floors are won by reaching the exit" | "Destroying an offer does something real" |

**Recommendation:**

- **Epic 17 — Exit Victory and Level Objectives** (Direction A). Sequenced tightly after Epic 16, of
  which it is the pacing release valve.
- **Epic 18 — Destroy-All Outcomes** (Direction B). Independent; can ship any time after Story 15.6
  lands. It is small enough that absorbing it into a later content/polish epic is also reasonable —
  the load-bearing point is that **it must not wait behind Direction A's re-pin risk for no reason.**

This also satisfies the project's own epic rule — *"Every epic must preserve a playable build"* and
deliver a coherent playable outcome. A single epic spanning both directions has two unrelated
outcomes and therefore no coherent one.

### 6.2 Game Architect (Cloud Dragonborn) — ✅ COMPLETE 2026-08-05

| # | Action | Result |
|---|---|---|
| 1 | Answer E17-Q6, E17-Q7, E17-Q8; record in §5 | ✅ All three answered in §5, plus the architect half of E17-Q5 |
| 2 | Verify §2.2's impact table against the real code | ✅ Full trace run. **Original list wrong in both directions** — the interactive session was missing, the finale path is not a consumer. Three enforcement layers found. §2.2 rewritten |
| 3 | Assess the fingerprint / re-pin blast radius | ✅ E17-Q8 — confinable to one combat re-pin, **plus a route/affinity re-pin if objective kind is a weighted draw**; share it with Epic 16's |
| 4 | State the dependency direction; name the AD to shape now | ✅ §8 — dependency confirmed on three independent grounds; **AD-4 confirmed, AD-5 added** |
| 5 | Flag and size Direction B's domain-contract touch | ✅ §3.3a — **small**; the record-only→live mechanism already ships inside the command |
| 6 | Comment on the FR75 character-level debt, option (ii) | ✅ §2.3 — **zero save-migration cost**, 5 definition-layer files, ~13 test refs |

*(Original action list retained below for the record.)*

1. **Answer E17-Q6, E17-Q7, E17-Q8** and record them in §5. Note the designer's E17-Q7 lean:
   **extend** Epic 16's connectivity validator rather than duplicate it (folded into story 17.1).
2. **Verify §2.2's impact table against the real code.** It was compiled from targeted greps, not a
   full trace — confirm the consumer list of `combat_outcome_evaluator`
   (`scripts/tactical/outcomes/combat_outcome_evaluator.gd`) is complete, and add any seam it misses.
3. **Assess the fingerprint/re-pin blast radius** of an exit-victory condition, and state whether it
   can be confined to one justified re-pin as §2.2 assumes. Factor in the designer finding that
   exit-victory is a **weaker** win condition than all-enemies-dead, which should reduce catalog churn.
4. **State the dependency direction explicitly:** confirm Direction A must follow Epic 16, and name
   any Epic-16 architectural decision (AD-1..AD-6) that should be shaped *now* to make it cheaper
   later — especially **AD-4** (the connectivity validator), which E17-Q7 wants to extend.
5. **Flag anything in Direction B that touches domain contracts** — applying destroy outcomes live
   (rather than record-only) changes command behaviour and may need an append-only event. The
   designer pass corrected §3.2 to call this out explicitly; size it.
6. **New for the architect:** comment on the **FR75 character-level debt** in §2.3 — specifically
   whether option (ii) (retire the gate) has any content-boundary or migration cost, given four
   baseline definitions carry non-zero values today.

### 6.3 Both passes

- Update this stub **in place**; do not fork a second copy.
- Change the **Status** banner at the top when the stub is no longer a stub.
- If your analysis invalidates a ratified decision, **say so plainly** and escalate to the Project
  Lead rather than quietly reinterpreting it.
- Epic 17 enters `epics.md` and `sprint-status.yaml` **only** after both passes and the Project
  Lead's ratification — not as a side effect of either pass.

---

## 7. Designer pass change record — 2026-08-05

Executed by the Game Designer alongside the Epic-16 GDD pass. **No ratified decision was overridden.**
One ratified requirement (**GDD FR75**) was found to be **unsatisfiable in the shipped code** and is
escalated in §2.3 rather than reinterpreted.

**Corrections made to this stub:**

1. **§2.3 rewritten.** The premise "no character-progression concept exists" was **incomplete**. A
   shipped, validated, content-populated `character_level_requirement` gate exists on armour and
   jewellery, with four non-zero baseline values and no possible satisfier. E17-Q1 answered
   (existing currencies); both original branches deleted; FR75 debt escalated as a separate item.
2. **§2.3 branch-(b) objection withdrawn.** The claim that an XP system contradicts the GDD's meta
   stance is wrong for **in-run** levelling, which the GDD actively endorses as buildcraft.
3. **§2.2 corrected** — evaluator path (`scripts/tactical/outcomes/`), plus the finding that
   exit-victory is a **weaker** condition than all-enemies-dead, likely reducing re-proof cost.
4. **§3.2 split upheld**, table corrected: the Direction-B half is **behaviour + content**, not
   content alone.
5. **Story lists corrected** — 17.1 absorbs objective satisfiability; 17.3 promoted to ship with
   17.2; 17.4 named the balance keystone; **17.7 deleted** per E17-Q4.
6. **Container recommendation: split** into Epic 17 (Direction A) and Epic 18 (Direction B) — §6.1a.
7. **E17-Q2/Q3/Q4 answered** and the designer half of **E17-Q5**; §5 table updated with status marks.

**Awaiting Project Lead ratification:** the container split (§6.1a), the three objective kinds
(E17-Q2), the locked-not-hidden exit (E17-Q3), and — separately from this epic — the **FR75
character-level decision** (§2.3, options i/ii/iii).

---

## 8. Architect pass change record — 2026-08-05

Executed by the Game Architect (Cloud Dragonborn) alongside the Epic-16 generation-architecture pass.
Grounded in the shipped code at build `6b7c4fd`; the headless suite was run as a diagnostic and is
**205 PASS / 0 FAIL**. **No production code was changed** — this is a design pass. **No ratified
decision was overridden**; two collisions are escalated below rather than reinterpreted.

**Corrections made to this stub:**

1. **§2.2 consumer trace rewritten from a real trace.** The interactive tap loop — the path a human
   actually plays — was missing from the consumer list. The finale path was listed but **is not a
   consumer**. `epic_1_micro_combat_scenario.gd` was missing.
2. **§2.2 gained the three-enforcement-layer finding.** `remaining_enemy_count == 0` is a validated
   *event contract*, not a gameplay branch. This is the finding that most changes Direction A's shape.
3. **E17-Q6 answered:** new append-only `level_exit_reached` event + `LevelObjectiveEvaluator`;
   `level_victory_reached` untouched; the existing all-enemies-dead branch kept.
4. **E17-Q7 answered:** extend AD-4 — **confirmed** — with `cull_fraction` split
   **necessary (17.1) / sufficient (17.5)**, ratified 2026-08-05.
5. **E17-Q8 answered:** exactly **one** combat re-pin; route/affinity hold if the objective-kind draw
   is appended at the tail, per Epic 16's ratified size-class pattern.
6. **E17-Q5 architect half answered:** the finale keeps its own seam; recommend not unifying in v1.
7. **§2.4 story list corrected** — 17.1 scope narrowed, 17.2 reshaped, 17.5 given three additions.
8. **§3.3a added** — Direction B sized; the record-only→live mechanism is already precedented.
9. **§2.3 gained the architect's option-(ii) costing** — zero save migration.

### 8.1 Dependency direction — §6.2 action 4

**Direction A must follow Epic 16. CONFIRMED, on three independent grounds** — the designer's
argument was thematic; these are structural:

1. **Objective satisfiability validation extends Epic 16's validator (E17-Q7).** Building it first
   means building it twice.
2. **Winnability re-proof must run on final geometry (E17-Q8).** Re-proving against open rooms and
   then again against room/corridor floors pays the most expensive bill in the project twice.
3. **The objective-kind weighted draw should share Epic 16's `map`-stream re-pin (E17-Q8).**
   Separately sequenced, it is two route/affinity re-pins instead of one.

**Direction B has no Epic-16 dependency. CONFIRMED** — §3.3a found nothing in it that touches
geometry, generation, the map stream, or the win condition. **The §6.1a split is endorsed on
architectural grounds**, not only on the designer's coherence grounds: the two directions have
disjoint blast radii, and holding B behind A's re-pin risk buys nothing.

### 8.2 The Epic-16 decision shaped now to make Epic 17 cheaper — §6.2 action 4

**AD-4 — confirmed, and already acted on.** `game-architecture.md` §3 and §9 now specify the
connectivity validator as a **reachability oracle plus registered satisfiability predicates**, rather
than four hard-coded checks. Epic 16 registers one predicate; Epic 17 registers its objective kinds
against the same oracle. Cost to Epic 16: a parameter and an array. Saving in Epic 17: a rewrite.

**AD-5 should be added to that list, and was not previously flagged.** Direction A makes stealth a
complete strategy, which is only implementable if "unseen" is a **queryable board property**. AD-5
already puts `awake` on the tactical entity rather than in a presenter — keeping it there (and
resisting any pressure in 16.3 to treat the wake cue as presentation state) is what a future stealth
objective reads. Zero extra cost today; it is a decision to *hold*, not to add.

**AD-3 is a quiet third.** Reusing `Terrain.WALL` for filler means Epic 17's exit-placement and
objective-satisfiability checks inherit one walkability model instead of reasoning about two.

### 8.3 Escalations to the Project Lead — status

1. ~~**The two-re-pin schedule vs. the depth-weighted size-class bands.**~~ **✅ WITHDRAWN 2026-08-05
   after verification — there is no collision.** The escalation assumed one shared `map` stream and a
   fingerprint covering the new field; both were wrong. `RouteGenerator` mints its own stream-set
   instance (affinity decoupled) and `RouteGenerator.fingerprint()` covers only
   count/id/type/depth/links/boss-depth. Appending the draws at the **tail** of the route draw order
   costs **zero fingerprint movement**, and the ratified two-re-pin schedule stands unchanged.
   **Direction A inherits the pattern** — see E17-Q8.
2. ~~**`MAX_INTERIOR_WALL_RATIO = 0.35` rejects BSP layouts by construction**~~ (Epic 16, not
   Epic 17). **✅ RESOLVED 2026-08-05.** Not a ratification conflict but a blocking implementation
   finding. The bound measures a metric that conflates placed blockers with structural filler;
   **re-based onto the carved set** (`blockers + wrinkles / carved floor`), value held at `0.35`,
   with an absent-key fallback so Story 16.1 is byte-identical, plus a new
   `insufficient_reachable_fraction` check. Now an explicit AC on Story 16.2. See
   `game-architecture.md` §2.

**No escalation remains open from this pass.**

### 8.4 Project Lead rulings applied — 2026-08-05

Both open architect questions were ruled on and the documents updated in place:

| Question | Ruling | Applied to |
|---|---|---|
| Size-class draw placement / the "third re-pin" | **Tail-append inside `RouteGenerator`; no re-pin. Coverage via a separate distribution fixture, not the route fingerprint.** | `game-architecture.md` §7/§8; this stub E17-Q8, §8.3 |
| `cull_fraction` satisfiability home | **Split necessary (17.1) / sufficient (17.5).** | `game-architecture.md` §9; this stub E17-Q7, §2.4 stories 17.1 + 17.5 |
| `MAX_INTERIOR_WALL_RATIO` collision (Epic 16) | **Re-base onto the carved set, hold `0.35`, absent-key fallback, add `insufficient_reachable_fraction`.** | `game-architecture.md` §2; `epics.md` Story 16.2 ACs |

### 8.5 What this pass deliberately did NOT do

- **Did not register Epic 17 anywhere.** No `sprint-status.yaml` entry, no `epics.md` entry. It
  remains a stub, by instruction and by §4's own rule.
- **Did not change any Epic 15 story**, including 15.6, whose split §3.2 upheld.
- **Did not edit any `godot/` production code.** The suite was run only as a diagnostic.
- **Did not decide the FR75 question** — costed it (§2.3) and left the decision escalated.
- **Did not apply the container split.** §6.1a remains a recommendation; §8.1 endorses it.
