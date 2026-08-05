# Epic 17 — Objectives, Exit Victory & Reward Restructure (STUB)

> **Status:** ⚠️ **STUB — deliberately incomplete.** Drafted 2026-07-24 to capture two ratified
> design directions that are **too large for Epic 15 or 16** and would otherwise be lost. This is a
> holding document, **not** a ratified epic: no story is registered in `sprint-status.yaml`, and
> nothing here is ready for `auto-gds`.
>
> **⚑ REVIEWERS: this stub is an explicit deliverable of the Epic-16 designer and architect passes.**
> See §6 for what each of you must do to it. It was written *before* your analyses and is expected
> to be wrong in places — correcting it is part of the job, not a courtesy.
>
> **Companions:** `epic-16-design-brief.md` (designer pass) · `epic-16-generation-architecture.md`
> (architect pass) · `../sprint-change-proposal-2026-07-24.md` (Epics 15–16 of record).
> **Build:** `a78653c`

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

**Dependency:** Epic 17 executes **after Epic 16**. The objective system's most interesting cases
(a locked exit behind a boss room, a 50%-cull gate, sneaking past a dormant patrol) are only
meaningful once rooms, corridors, and sight-based aggro exist.

---

## 2. Direction A — Exit victory and level objectives

### 2.1 The ratified design

- **Reaching the exit is the ONLY win condition for any level.**
- The exit may be **hidden** or **locked** until a per-level **objective** is satisfied. Examples
  given: slay the boss; kill ≥50% of the monsters; no objective at all.
- Therefore **stealth or speed is sometimes a complete strategy** — a player may legitimately reach
  the exit without clearing the floor.
- **Skipping has a cost:** enemies and rooms left behind are rewards forfeited.

### 2.2 Why it is epic-scale (the honest impact)

**It changes domain truth.** The shipped condition is `living_enemy_count == 0 → victory`
(`combat_outcome_evaluator.gd:39-40`) — an Epic-1 seam consumed by the auto-resolve resolver, the
reference winnability driver, the finale path, and every combat fixture. This is not a presentation
change.

Consequences to plan for:

| Impact | Detail |
|---|---|
| **New content concept** | Level objectives need a definition type, a repository, validation, and `LevelRecipeDefinition` wiring — the Epic-3 content-boundary pattern |
| **Winnability proof changes meaning** | "Can this class kill everything?" becomes "Can this class reach the exit?" — a different question needing a different driver policy, and a re-derived seed catalog |
| **Exit reachability becomes load-bearing** | Epic 16's connectivity validator proves the exit is *reachable*; Epic 17 additionally needs it *satisfiable* (an objective must be completable on the generated floor) |
| **Fingerprint risk** | Combat-replay composites almost certainly move; layout fingerprints should not. Plan one justified re-pin, per the 14.1 / 16.1 / 16.2 discipline |
| **Reward forfeiture must be real** | Skipping only costs something if unclaimed rewards are actually withheld — which touches the reward/loot flow |

### 2.3 ⚠️ Unresolved: the XP gap

The ratified wording states a skipping player "misses out on **XP** and loot."

**No XP or character-progression system exists in this codebase.** Verified 2026-07-24: no
experience-point or character-level progression concept exists under `godot/scripts/`. The shipped
progression currencies are **gold** (in-run), **Oath Shards** (meta), **passives**, and **loot**.

Two readings, and they differ enormously in scope:
- **(a)** "XP" was shorthand for the existing currencies → **no new system**; this is just reward
  forfeiture, and Direction A stays as scoped above.
- **(b)** A real XP / character-level system is intended → **a separate epic of its own**, touching
  progression, balance, the meta layer, and the GDD's deliberately shallow meta-power stance
  (the GDD caps meta bonuses as "small and sparse" and rejects broad raw-stat ladders for MVP).

**This must be resolved in the designer pass before Epic 17 is scoped.** Do not let it be decided
implicitly by a story author.

### 2.4 Provisional stories (expect these to change)

- **17.1** Level-objective content model (definitions, repository, recipe wiring, validation)
- **17.2** Exit-victory condition in the domain (outcome evaluator, resolvers, justified re-pin)
- **17.3** Objective/exit presentation (is the exit locked? what unlocks it? where is it?) — without
  this the system is invisible and the floor becomes a maze
- **17.4** Reward forfeiture (skipped rooms genuinely withhold their rewards)
- **17.5** Winnability re-proof under exit-victory (new driver policy + re-derived catalog)

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

### 3.2 The split (already reflected in Epic 15)

| Half | Home | Rationale |
|---|---|---|
| **Structural** — three rewards, pick one, single Destroy-All button | **Story 15.6** (Epic 15) | A UI/flow restructure over the existing `DestroyPassiveCommand`; small, and it fixes a live playtest defect |
| **Content** — the rich destroy-outcome table (boons, debuffs, synergies, secrets, meta unlocks, achievements) | **Epic 17 (here)** | Needs content design plus an achievement/meta-unlock surface that does not exist |

### 3.3 What exists to build on

`DestroyPassiveCommand` (Story 6.6) already exists with a `DestroyOutcomeTableDefinition` and a
named-stream roll. **Critically, v0 destroy outcomes are `OUTCOME-RECORD-ONLY`** — the command
records what *would* happen without applying live effects (the deliberate 6.3 gold-reward-as-outcome
precedent). So Direction B is largely about **making recorded outcomes real** and expanding the
table, not inventing the mechanism.

**Open question:** "secrets / meta unlocks / achievements" implies an **achievement surface** that
does not exist. Scope it, or map it onto the existing Oath-Shard / unlock-progress meta layer.

### 3.4 Provisional stories (expect these to change)

- **17.6** Destroy-All outcome table content + applying outcomes live (not record-only)
- **17.7** Secrets / achievements surface, or an explicit mapping onto the existing meta layer

---

## 4. What this stub deliberately does NOT do

- **Does not register anything in `sprint-status.yaml`.** Epic 17 has no backlog entries; it is not
  pickup-able by `auto-gds`, by design.
- **Does not touch `epics.md`.** Epic 17 enters the canonical epics list only after the designer and
  architect passes have corrected this stub and the Project Lead ratifies it.
- **Does not decide the XP question** (§2.3) or the achievements question (§3.3).
- **Does not affect Epic 15 or Epic 16**, both of which are registered and ready. Epic 15's Story
  15.6 carries only the *structural* half of Direction B.

---

## 5. Open questions carried into the passes

| # | Question | Owner |
|---|---|---|
| **E17-Q1** | Is "XP" the existing currencies, or a genuine new progression system? (§2.3) | **Designer** |
| **E17-Q2** | What objective kinds ship in v1? (boss-slain / kill-N% / none / others?) | **Designer** |
| **E17-Q3** | Is the exit *hidden* (must be found) or merely *locked* (visible but shut)? These are very different UX and generation problems | **Designer** |
| **E17-Q4** | Do secrets/achievements get their own surface, or map onto the existing unlock-progress meta layer? (§3.3) | **Designer** |
| **E17-Q5** | How does exit-victory interact with the boss node and the finale path? | **Designer + Architect** |
| **E17-Q6** | Where does the win condition live after the change — outcome evaluator, or a new objective evaluator seam? | **Architect** |
| **E17-Q7** | How is "objective satisfiable on this floor" validated at generation time, and does it extend Epic 16's connectivity validator or sit beside it? | **Architect** |
| **E17-Q8** | What is the re-pin and winnability-re-proof plan for a changed win condition? | **Architect** |

---

## 6. ⚑ REVIEWER INSTRUCTIONS — required actions on this stub

This stub was drafted **before** the Epic-16 designer and architect passes. Both passes must review
and **correct** it. It is expected to contain wrong assumptions; leaving them uncorrected is the
failure mode this section exists to prevent.

### 6.1 Game Designer (Samus Shepard) — run FIRST

1. **Answer E17-Q1 (the XP gap) explicitly.** This is the single largest scope fork in the stub.
   Record the answer in §2.3 and delete the branch that does not apply.
2. **Answer E17-Q2, E17-Q3, E17-Q4**, and record them in §5.
3. **Sanity-check Direction A against the GDD** you are already updating for Epic 16 — particularly
   the pacing target (Q4: ~20–35 min, ~70%-of-nodes death expectation) and the difficulty non-goal.
   *An exit-victory model may shorten runs substantially; say so if it does.*
4. **Challenge the split in §3.2.** If the structural reward change should NOT ship in Epic 15
   Story 15.6, say so — 15.6 is registered but not yet implemented, so it can still move.
5. **Correct or delete the provisional story lists** (§2.4, §3.4) — they are a first guess.
6. **State whether Epic 17 is the right container at all**, or whether Directions A and B should be
   two separate epics. They share no machinery; the stub groups them only because both were deferred
   on the same day.

### 6.2 Game Architect (Cloud Dragonborn) — run SECOND, after the designer

1. **Answer E17-Q6, E17-Q7, E17-Q8** and record them in §5.
2. **Verify §2.2's impact table against the real code.** It was compiled from targeted greps, not a
   full trace — confirm the consumer list of `combat_outcome_evaluator` is complete, and add any
   seam it misses.
3. **Assess the fingerprint/re-pin blast radius** of an exit-victory condition, and state whether it
   can be confined to one justified re-pin as §2.2 assumes.
4. **State the dependency direction explicitly:** confirm Epic 17 must follow Epic 16, and name any
   Epic-16 architectural decision (AD-1..AD-6) that should be shaped *now* to make Epic 17 cheaper
   later — especially **AD-4** (the connectivity validator), which E17-Q7 may want to extend rather
   than duplicate.
5. **Flag anything in Direction B that touches domain contracts** — applying destroy outcomes live
   (rather than record-only) changes command behavior and may need an append-only event.

### 6.3 Both passes

- Update this stub **in place**; do not fork a second copy.
- Change the **Status** banner at the top when the stub is no longer a stub.
- If your analysis invalidates a ratified decision, **say so plainly** and escalate to the Project
  Lead rather than quietly reinterpreting it.
- Epic 17 enters `epics.md` and `sprint-status.yaml` **only** after both passes and the Project
  Lead's ratification — not as a side effect of either pass.
