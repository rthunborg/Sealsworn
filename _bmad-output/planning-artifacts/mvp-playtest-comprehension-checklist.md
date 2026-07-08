# MVP Playtest Comprehension Checklist — Core-Loop Readiness Plan

> **Story:** 10.4 (Gameplay Comprehension and Playtest Checklist) · **Epic:** 10 (Playtest Tuning and MVP Readiness)
> **Type:** Readiness / playtest-checklist / comprehension-criteria artifact (the comprehension analog of the
> 10.1 device-tiers plan and the 11.1 UX appendix — author the checklist, run every headless-verifiable slice,
> record honest availability gaps for the observed-human rest, touch no simulation).
> **Status:** authored 2026-07-08 · discharges the FR47 (pacing/run-length) / FR48 (build-defining passive) /
> FR73 (worth-using consumable) **"Story 10.4" comprehension half** of the Epic-10 readiness-patch FR map so the
> 10.6 readiness gate consumes a structured comprehension signal, not guesswork.

---

## 1. Purpose and Scope

**Purpose.** This document validates whether the Sealsworn **core loop is UNDERSTANDABLE**. Epics 1-9 shipped
a complete headless deterministic domain; Epic 11 wired the first on-screen hands-off run-flow / HUD / outpost
layer; Epic 12 wired the INTERACTIVE tap-loop plus a class-armed, winnable, tactically-distinct hero. What the
project has never had is a **structured playtest checklist that proves the loop READS** to a first-time player.
This artifact is that checklist. It discharges the **comprehension half** of the Epic-10 MVP-readiness mandate
(the readiness patch maps FR47 pacing/run-length, FR48 early-mid build-defining passives, and FR73 worth-using
consumables to *both* Story 4.6/6.7 *and* Story 10.4) so that the **10.6 readiness gate** rests on a real,
structured comprehension checklist rather than guesswork.

**Scope (what this artifact delivers, and the honest boundary).**

1. The **seven comprehension items** (movement, attack-preview clarity, preview/commit distinction,
   damage/death explanation, Consume/Destroy clarity, positioning importance, quit/resume success), each with a
   concrete "what to observe", a pass/fail read, and the shipped SURFACE that produces it (§3, AC1).
2. The **session-record TEMPLATE** with every required field, the ≥5-observed-session target, and the honest
   availability gap for the observed-human dimension (§4, AC2).
3. The **death/victory/run-end feedback-capture** protocol, stored as LOCAL playtest notes — no telemetry
   (§5, AC3).
4. The **repeated-issue → tuning-task rules** + a tuning-task template (§6, AC4).
5. The **five-session acceptance thresholds** the 10.6 gate reads as the pass bar (§7, AC5).
6. The **consumable-frequency review** + the known headless-verified `warding_salve` finding (§8, AC6).
7. The **per-class comparison criteria** + the objective distinctness backing already proven by Story 12.2
   (§9, AC7).
8. The **FR47 pacing / replay-intent overlay** the checklist shares with Story 4.6 (§10).
9. A consolidated **Observed-Session Availability Gaps** ledger (each gap → owning follow-up) and the 10.5 /
   10.6 / 10.7 gate handoff (§11, §12).

**Out of scope (explicitly NOT this story).** Any change to a gameplay command, event, RNG stream,
`RunSnapshot` / `ProfileSnapshot` / `SettingsSnapshot` schema, save key, generator / route / finale
fingerprint, view model, content definition, or presenter / `.tscn`. **No difficulty selector, tier, or knob**
(a hard non-goal): a "tuning task" here is a content/UX/frequency note referencing the relevant epic/story/seed,
never a difficulty adjustment. **No live-service telemetry** (AC1 explicit): feedback is stored as LOCAL
playtest notes; `PlatformServices` stays a local no-op (NFR11). The full headless suite stays green and
byte-for-byte behaviorally unchanged; the only sanctioned `godot/` edits are the additive readiness-fact tests
in §8.1 / §9.2 (the `warding_salve` reward-table-absence tripwire and the Medium/affinity winnability catalog
extension). This story does NOT change the reward tables — it FLAGS the `warding_salve` finding for the tuning
pass.

**Grounding.** Read alongside the run-flow UX appendix
(`_bmad-output/planning-artifacts/ux-appendix-run-flow.md` — §1 HUD, §2 preview/confirm, §3 inspect, §4 passive
modal, §13 save/resume, §14 layout+accessibility) and the project-context comprehension surfaces
(root `project-context.md`). The direct structural precedent is 10.1
(`_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md`): define what can be authored,
verify what can be verified now, record honest gaps against owners, touch no simulation.

---

## 2. The measurement reality (why observed sessions are availability gaps, not blockers)

A headless autonomous agent **cannot** run ≥5 observed human playtest sessions across physical mobile/desktop
form factors, cannot watch a tester's confusion or memorable-moment, and cannot produce tester feedback. The
ACs were written to be dischargeable **without** a live tester lab: AC2 explicitly permits *"at least five
observed sessions … are targeted before final readiness, **with fewer sessions treated as a documented
readiness limitation**."* Therefore the correct, honest outcome for this story is:

- **Author now:** the complete checklist, the session-record format, the feedback protocol, the tuning-triage
  rules, and the acceptance thresholds (everything in §3-§10 below).
- **Verify now (headless):** the readiness FACTS the checklist rests on — class distinctness (already proven by
  Story 12.2 on seed 4242; §9), the `warding_salve` reward-table absence (§8, backed by a new tripwire test),
  and the winnability inputs (extended to a Medium/elite + Scorched-affinity row; §9.2).
- **Record as an availability gap:** the observed-human dimension (the ≥5 sessions, the felt class-distinctness,
  the felt pacing/run-length), each named against its owning follow-up (§11).

This is the **same honesty posture** 10.1 used for physical-device measurement and 11.1 used for contract gaps.
The **10.6 readiness gate** is where the project decides whether a still-open observed-session gap is an
acceptable documented readiness **limitation** or must be discharged by a real observed-playtest pass before
MVP-readiness passes. 10.4's job is to make the checklist + format + thresholds + gap **explicit and
dischargeable** — not to run the sessions. This is also the project-context rule that MAKES the gap legitimate:
*"Human playtests remain required for feel, readability, frustration, and excitement"* (§ Testing Rules).

---

## 3. The seven comprehension items (AC1)

Each item below states **what to observe**, the **pass/fail read**, and the shipped **surface** that produces
it (mapped to the UX appendix section / the command / the save-resume seam). These are the audited comprehension
surfaces — **they already exist; the checklist observes them, it does not build them.** A tester runs the first
tactical loop (a Small combat node) and, where relevant, a full short run to a die-or-win end.

> **NO live-service telemetry (AC1).** Every observation below is recorded as **LOCAL playtest notes** — in the
> session records of §4 (this file) or a repo-local `playtest-sessions/` notes location. `PlatformServices`
> stays a local no-op (NFR11): no cloud call, no account, no always-on sink. Nothing here uploads or phones home.

### 3.1 Movement comprehension

- **What to observe:** the tester moves the hero to a reachable tile via the tap-loop, **without prompting**.
  Do they find and use movement on the live board within the first encounter?
- **Pass/fail read:** PASS if the tester moves deliberately toward or away from a threat within the first
  encounter unaided. FAIL if they cannot figure out how to move the hero after the first encounter.
- **Surface:** the interactive tap-loop move-commit on the live board — `InteractiveCombatSession.submit_move`
  (Story 12.1) through `TacticalCommandBridge`. UX appendix §14 (move-commit / layout profiles) + §1 (Tactical
  HUD).

### 3.2 Attack preview clarity

- **What to observe:** before committing an attack, is the attack preview legible? Does the tester understand
  the shown damage, the target, and whether the attack is legal, **before** they commit?
- **Pass/fail read:** PASS if the tester can state "this attack will hit that enemy for about N" from the
  preview before committing. FAIL if the preview is ignored or misread.
- **Surface:** `TacticalAttackPreview` via the command bridge (damage / target / legality). UX appendix §2;
  FR9 / FR10.

### 3.3 Preview/commit distinction

- **What to observe:** does the deliberate **two-step** commit read as distinct from a committed action? (First
  tap PREVIEWS, second tap COMMITS.) Critically, **with audio OFF**, can the tester still tell a pending preview
  from a committed action?
- **Pass/fail read:** PASS if the tester never confuses "I'm previewing" with "I've acted", audio muted. FAIL if
  they commit by accident or cannot tell the two states apart without sound.
- **Surface:** `TacticalAttackCommitFlow` (the `feedback_preview` vs `feedback_committed` distinction). UX
  appendix §2.3 (the preview-vs-committed distinction is the load-bearing NON-COLOR cue, per the accessibility
  contract §0.5); FR11.

### 3.4 Damage/death explanation

- **What to observe:** after taking major damage or dying, can the tester explain the **main cause**? ("The
  seer detonation caught me", "the two melee bodies surrounded me".)
- **Pass/fail read:** PASS if the tester names the main cause of death or major damage. FAIL if the death feels
  arbitrary / unexplained. (Directly feeds the AC5 death-cause threshold, §7.)
- **Surface:** the combat explanation log / outcome surface (Epic 1 outcome + explanation; each `DomainEvent`
  is explainable in player/debug language).

### 3.5 Consume/Destroy clarity

- **What to observe:** at the passive-reward modal, is the **Consume vs Destroy** choice understood as
  *power-now* (Consume) vs *gamble* (Destroy)?
- **Pass/fail read:** PASS if the tester can articulate the trade-off before choosing. FAIL if the two options
  read as interchangeable or their consequences are opaque.
- **Surface:** the passive-reward modal data contract (`PassiveRewardModalViewModel` — the Epic-6 6.4 modal;
  Consume vs Destroy). UX appendix §4.

### 3.6 Positioning importance

- **What to observe:** does the tester grasp that **tile choice matters** — dodging an ash-seer detonation,
  keeping ranged spacing, not walking into a melee pincer?
- **Pass/fail read:** PASS if the tester adjusts position for a tactical reason (dodges a mark, kites, avoids
  being surrounded). FAIL if they stand still and take avoidable damage without noticing.
- **Surface:** the exact tactics the 12.2 reference driver encodes — ash-seer detonation dodging + ranged
  spacing + melee one-at-a-time commit (`reference_combat_driver.gd` hero policy). On screen the human drives
  the 12.1 tap-loop; the reference driver is the headless proof that these tactics win.

### 3.7 Quit/resume success

- **What to observe:** a mid-run **quit + resume** restores the run with no lost progress. Does the tester get
  back exactly where they left off?
- **Pass/fail read:** PASS if a resume lands the tester at the same route position with the run intact. FAIL if
  progress is lost, the run cannot resume, or the resume state is confusing.
- **Surface:** the Epic-2 save/resume seam — `SaveManager.resume_route_position` → `RunResumeService`
  (route-position save). UX appendix §13 (save/resume recovery states).

### 3.8 Item → surface summary

| # | Comprehension item | Shipped surface (already exists) | Reference |
|---|---|---|---|
| 1 | Movement | tap-loop move-commit on the live board | `InteractiveCombatSession.submit_move` (12.1); UX §14/§1 |
| 2 | Attack preview clarity | `TacticalAttackPreview` via the command bridge | UX §2; FR9/FR10 |
| 3 | Preview/commit distinction | `TacticalAttackCommitFlow` (`feedback_preview` vs `feedback_committed`) | UX §2.3; FR11 |
| 4 | Damage/death explanation | combat explanation log / outcome surface | Epic 1 outcome/explanation; feeds AC5 |
| 5 | Consume/Destroy clarity | `PassiveRewardModalViewModel` (Consume vs Destroy) | UX §4; Epic 6 (6.4) |
| 6 | Positioning importance | ash-seer dodge + ranged spacing (12.2 driver tactics) | `reference_combat_driver.gd` |
| 7 | Quit/resume | `SaveManager.resume_route_position` → `RunResumeService` | UX §13; Epic 2 (2.7/2.8) |

---

## 4. Session-record format + the ≥5-session target (AC2)

### 4.1 The session-record template

Each observed session fills ONE record below. **Value cells are left empty / `<pending observed pass>` — this
story does NOT fabricate tester data.** Every AC2 field is present verbatim.

| Field | Value |
|---|---|
| Tester id / alias | `<pending observed pass>` |
| Date | `<pending>` |
| Device / form factor | `<pending — e.g. mobile phone / tablet / Windows desktop>` |
| Build id | `<pending>` |
| Seed | `<pending — e.g. 4242>` |
| Class | `<pending — warrior / pyromancer / ranger>` |
| Session length | `<pending — minutes>` |
| Run outcome | `<pending — victory / death / quit>` |
| Nodes cleared | `<pending — N of route depth>` |
| Notable confusion | `<pending>` |
| Memorable moment | `<pending>` |
| Desire for another descent | `<pending — yes / no / unsure>` |
| Blocked action | `<pending — any action the tester could not perform>` |

> Reproduce this block once per session (a filled-in table per tester, or an equivalent per-session note file
> under a repo-local `playtest-sessions/` folder). The session-length + nodes-cleared fields double as the FR47
> pacing overlay (§10).

### 4.2 The ≥5-observed-session target + the availability gap

- **Target:** **at least five observed sessions across the available mobile AND desktop form factors** before
  final MVP readiness.
- **Documented readiness limitation:** **fewer than five sessions is treated as a documented readiness
  limitation** (AC2 explicit). It is recorded as availability gap **OSG-1** (§11) — not a silent omission.
- **Availability gap → owning action:** a headless agent cannot run observed sessions on physical form factors,
  so the observed-session pass is a **HUMAN action owned by the 10.6 readiness gate** (the same honest-scope
  posture 10.1 used for physical-device measurement; it also intersects the physical-device availability
  constraint the 10.6 gate owns for the mobile form factor — see the 10.1 device-tier gaps G1-G7).

---

## 5. Death/victory/run-end feedback capture (AC3)

When a playtester completes a **death, a victory, or a run end**, the observer captures the three post-run
prompts below. **Feedback is stored as LOCAL playtest notes** (the session record of §4 in this file, or a
repo-local `playtest-sessions/` notes file) — **never a remote sink** (NFR11; AC1/AC3).

### 5.1 The three post-run prompts

1. **Do you want another descent?** (the replay-intent signal — also the AC2 `desire-for-another-descent`
   field; feeds FR47/FR68 replay-intent, §10.)
2. **What confused you?** (the comprehension-friction signal — maps to the seven items of §3 and the AC5
   thresholds.)
3. **What moment do you remember?** (the memorable-build/passive/risk/enemy/moment signal — feeds the AC5
   "≥3/5 name a memorable moment" threshold.)

### 5.2 The protocol a later observed-session pass follows

So the availability gap is dischargeable **without re-designing the format**, a later observed-session pass runs
exactly this protocol per tester:

1. Run the first tactical loop (a Small combat node) to a die-or-win outcome; where time allows, run a full
   short run to a route end (death, victory, or a deliberate quit-and-resume, §3.7).
2. At the run-end moment, ask the three prompts of §5.1 verbatim; transcribe the tester's own words.
3. Fill the §4 session record; store it as a local note. Do not paraphrase confusion into "confusing" — record
   the specific surface and the specific misread (the compact-actionable-note discipline, §6.3).
4. Repeat for ≥5 sessions across the available form factors, rotating the class (warrior / pyromancer / ranger)
   so the §9 class-comparison is exercised.

---

## 6. Tuning-task triage rules (AC4)

### 6.1 The repeated-issue → tuning-task rule

**GIVEN repeated feedback identifies the same issue** (the same surface confuses ≥2 testers, or the same
blocker recurs), **a tuning task is created.** A single one-off confusion is a note, not yet a task; a repeated
signal crosses the bar. (The specific "repeated blocker in ≥2 sessions" hard rule is stated as an acceptance
threshold in §7.)

### 6.2 The tuning-task template

Every tuning task carries all three required fields plus the MVP-scope guard:

| Field | Content |
|---|---|
| Relevant epic / story | the epic + story that owns the confusing/broken surface (e.g. "Epic 6 / Story 6.4 passive modal") |
| Seed (if applicable) | the seed the issue reproduced on (e.g. `4242`), or `n/a` if seed-independent |
| Observed player impact | the concrete, compact impact ("2/3 testers could not tell Consume from Destroy at the modal") |
| MVP-scope guard | **scope remains focused on MVP readiness** — a tuning task is a content/UX/frequency note, **never a difficulty knob or a new-feature request** |

### 6.3 The compact-actionable discipline

A tuning task (and any consumable-frequency or winnability finding) is **compact and actionable** — system +
seed/context + observed impact — **never** a bare "confusing" and never a raw grid/log dump (the project-context
generator-diagnostics discipline carried to readiness notes).

---

## 7. Acceptance thresholds (AC5)

These are the **pass bar the 10.6 readiness gate reads.** Stated verbatim:

1. **Movement/attack-commit:** **no more than one of five** observed sessions may fail to understand basic
   movement / attack commit **after the first encounter**.
2. **Death/damage cause:** **no more than one of five** may be unable to explain the main cause of death or
   major damage.
3. **Memorable moment:** **at least three of five** should name a memorable build, passive, risk, enemy, or
   moment.
4. **Repeated-blocker rule:** **any repeated blocker in two or more sessions creates a tuning or UX task before
   readiness can pass.**

> With fewer than five observed sessions (availability gap OSG-1, §11), these thresholds cannot yet be scored —
> that shortfall is itself the documented readiness limitation the 10.6 gate weighs (an acceptable limitation or
> a hard blocker is the gate's call, not this story's).

---

## 8. Consumable-frequency review (AC6)

### 8.1 The four flag triggers

**GIVEN consumables appear during playtest or smoke runs, WHEN frequency, use rate, and player-perceived value
are reviewed**, a consumable is **FLAGGED for tuning** if it:

1. appears **too often**, OR
2. **never appears** across the approved sample, OR
3. is **ignored in three or more** relevant sessions, OR
4. is **described as not worth using** by repeated testers.

**Tuning notes reference reward tables + consumable definitions + observed context** (the compact-actionable
discipline, §6.3).

### 8.2 The known, headless-verified `warding_salve` finding — FLAGGED

The three baseline consumables are `minor_healing_draught`, `warding_salve`, and `ember_flask`
(`godot/scripts/content/repositories/consumable_repository.gd`). The two combat reward tables
(`godot/scripts/content/repositories/reward_table_repository.gd`) weight:

- `standard_combat_reward` → `minor_healing_draught` (weight 4),
- `elite_combat_reward` → `ember_flask` (weight 3),
- **neither table weights `warding_salve`.**

Therefore a real run **CANNOT roll `warding_salve` from a reward offer** — it is obtainable only via a direct
`PickupItemCommand`. This is **exactly the AC6 trigger #2** ("never appears across the approved sample"), and it
is a KNOWN 10.4-owned deferral (from the 6.7 Round-1 review, re-recorded in the 7.1 untouched note).

**FLAGGED for the frequency-tuning pass** with the explicit disposition choice, which is the **tuning pass's
decision, not this story's**: **either weight `warding_salve` into a reward table (e.g. as a mid-rarity
`elite_combat_reward` entry) OR record the deliberate omission** (it is `RARITY_UNCOMMON` — a "semi-rare salve
worth saving for a hard fight" — and the design may intend it as a pickup-only reward). This story does NOT
change the reward tables; it records the finding, referencing the reward table + the consumable definition + the
observed context (it can never surface in a reward-offer session).

**Headless tripwire (added by this story).** A new content-fact test,
`godot/tests/unit/content/test_consumable_reward_frequency.gd`, asserts LIVE from `RewardTableRepository` that
`warding_salve` is absent from every baseline reward-table entry's `content_id` set (and, as a positive
control, that `minor_healing_draught` and `ember_flask` ARE present). This is a **deliberate-update tripwire**:
a future story that DOES weight `warding_salve` into a table makes the assertion FAIL LOUD, at which point this
§8.2 finding is updated. It asserts a readiness FACT, not new gameplay behavior.

### 8.3 The observed use-rate / value dimension (an availability gap)

Triggers #1 (too often), #3 (ignored in ≥3 sessions), and #4 (described as not-worth-using) require observed
human sessions to score. They are recorded against availability gap **OSG-2** (§11): the felt consumable
use-rate and perceived value are confirmed by the observed-session pass the 10.6 gate owns. The `v0`
consumables are OUTCOME-RECORD-ONLY (using one records its intended effect; the live heal/ward/burn mutation is
Epic-7 risk-economy state), which the observed-value pass should keep in mind when reading "not worth using."

---

## 9. Per-class comparison (AC7)

### 9.1 The criterion + the three MVP classes

**GIVEN a playtester plays the first tactical loop with each MVP class — Warrior, Pyromancer, and Ranger — and
compares the class starts, THEN each class must change at least one combat decision through equipment, passive,
or preview behavior.** Any class that **feels like a stat-only reskin** is **flagged for tuning before more
class content is added**, referencing the class definition + starting kit + the passive-explanation surface.

| Class | Class definition (`class_repository.gd`) | Starting kit (weapon / support / passives) | Passive-explanation surface |
|---|---|---|---|
| **Warrior** | `warrior`, selectable, `baseline_hp` 18 | sword / **shield** / `warrior_unbreakable_guard` + `warrior_blade_and_board` | passive modal / inspect (§3.5, UX §3/§4) |
| **Pyromancer** | `pyromancer`, selectable, `baseline_hp` 18 | staff / **tome** / `pyromancer_kindling_focus` + `pyromancer_arcane_conduit` | passive modal / inspect |
| **Ranger** | `ranger`, selectable, `baseline_hp` 18 | bow / **none** / `ranger_steady_aim` + `ranger_hunters_quiver` | passive modal / inspect |

The live combat LOADOUT derives from `run.starting_kit` via `CombatLoadout` (Epic 12), so the felt distinctness
comes from **equipment + support + preview**, not a passive-combat-effect engine (`scripts/rules/conditions/`
stays empty; the kit's passive ids are RECORDED, and distinctness is carried by the shield/tome/bow difference).

### 9.2 The objective distinctness backing — ALREADY MET

AC7's **objective half is already mechanically true**, proven by the direct 12.2 input
`godot/tests/unit/run/test_reference_combat_driver.gd` (its own comment labels seed 4242 "the direct input to
10.4's class-comparison AC"). On the SAME seed 4242:

- **Warrior** sword+shield emits `shield_block` `combat` rolls — a block chance on INCOMING enemy hits (the
  shield protects its OWNER),
- **Pyromancer** staff+tome emits `+1` `support_bonus_damage` on its OWN attacks (the tome bonus),
- **Ranger** bow+none emits **neither** (the real no-op support),
- and the three resolve the same seed in **different round counts** — a demonstrable, non-cosmetic per-class
  difference.

`godot/tests/unit/run/test_combat_loadout.gd` proves each live loadout derives from its `StartingKit` (all three
at `baseline_hp` 18). **AC7's objective half is MET by this proof;** the human class-comparison sessions (gap
OSG-3, §11) confirm the FELT distinctness. A class that a tester reports as a stat-only reskin becomes a
tuning-task per §6, referencing that class's definition + kit + passive-explanation surface.

**The two future classes (Necromancer / Shadeblade) carry NO runnable kit yet** — their class-kit content is
deferred (Epic-11 defer). AC7's "once Epic 6+ ships them" clause stays a **forward hook**, not a v0 obligation;
10.4 compares only the three MVP classes with runnable kits.

### 9.3 The Medium/affinity winnability disposition (the 12.2-owned fast-follow) — RESOLVED: EXTENDED

The 12.2 `ReferenceCombatDriver` winnability proof (`APPROVED_LIVE_COMBAT_SEED_CATALOG`) originally covered ONLY
`small_combat_basic` / `SIZE_SMALL` NEUTRAL boards `[4242, 8080, 6006, 2048, 512]`, even though the shipped
interactive path (`begin_interactive_combat_node`) also hosts the class loadout on `elite_combat` /
`SIZE_MEDIUM` + affinity-loaded boards. The 12.2 code review assigned a fast-follow "before/within 10.4":
**EITHER** extend the catalog with a Medium/elite seed × class row + a Scorched-affinity live seed, **OR** scope
the winnability claim to Small-neutral and hand the Medium/affinity proof to 10.6.

**Disposition chosen: EXTENDED (the preferred, coverage-adding option).** The catalog in
`test_reference_combat_driver.gd` is extended additively with:

- **≥1 `medium_combat_basic` / `SIZE_MEDIUM` NEUTRAL seed**, proven winnable by all three classes
  (`STATE_VICTORY` within the round cap), and
- **≥1 Scorched-affinity live seed** (a `medium_combat_basic` board with the `scorched` `AffinityDefinition`
  applied POST-generation on the built board via the driver's existing affinity params + `AffinityRepository`),
  proven winnable by all three classes under the Scorched hazard-DoT pressure.

The original five Small-neutral entries stay **byte-identical** (an additive extension — the inline-catalog +
finale discipline: new entries come from LIVE runs, annotated with their enemy mix + tactical read, never
hand-typed to hit a PASS). Each new entry's winnability is a genuine assertion: if any Medium/affinity seed is
NOT winnable by every class, the test FAILS LOUD (seed + class + reason) — a genuine balance/threshold finding to
triage, per the AC2 fail-loud discipline (not silently dropped). The **specific chosen seeds + their measured
round counts are recorded inline in the catalog annotations** (derived from the live probe runs of this story).
The affinity is applied as a POST-generation board effect on a BUILT board (the generator stays affinity-blind
— no affinity is wired into generation).

---

## 10. FR47 pacing / replay-intent overlay (the 4.6-shared readiness item)

The readiness patch maps **FR47** ("early/mid/late/finale pacing and run-length targets") to **both** Story 4.6
and Story 10.4. Story 4.6 already **measured and recorded** the STRUCTURAL pacing surface — the constant 8-tier
route depth, the node-type mix, and the `tools/dump_run_pacing_survey.gd` + `test_run_pacing_survey.gd` survey —
but left the HUMAN-FELT "20-35 minute run length" (`gdd.md:200`) and the constant-route-depth tuning as an
Epic-10 tester-note overlay.

- **This story does NOT re-measure the structural survey or change route/generation.** It records the
  run-length / pacing observation as a **session-record overlay**: the AC2 **session length** + **nodes
  cleared** fields (§4) ARE the pacing data; the FELT pacing note ("did the run drag / feel too short?") is part
  of the observed-session pass (gap OSG-4, §11).
- The **"another descent?"** replay-intent signal (the AC2 desire-for-another-descent field + the AC3
  want-another-descent prompt, §5) is recorded as the **FR47 / FR68 replay-intent readiness input the 10.6 gate
  reads.**

---

## 11. Observed-Session Availability Gaps (the honest-scope ledger)

Every observed-human dimension this headless story cannot discharge, named against the AC it affects and its
owning follow-up. The **10.6 readiness gate decides** whether each is an acceptable documented readiness
limitation or a hard blocker.

| Gap | What is missing | AC affected | Owning follow-up |
|---|---|---|---|
| **OSG-1** | ≥5 observed human sessions across physical mobile + desktop form factors (fewer = documented readiness limitation) | AC2, AC5 | a physical-device observed-playtest pass, owned by the **10.6 readiness gate** (intersects the 10.1 device G1-G7 physical-device gaps) |
| **OSG-2** | The felt consumable use-rate / perceived value (AC6 triggers #1 too-often, #3 ignored-in-≥3, #4 not-worth-using) | AC6 | the observed-session pass (§8.3); the `warding_salve` reward-table-absence finding is ALREADY verified headless (§8.2) |
| **OSG-3** | The FELT per-class distinctness (a tester comparing warrior/pyromancer/ranger starts) | AC7 | the observed class-comparison sessions (§9.2); the OBJECTIVE distinctness is ALREADY proven headless (12.2) |
| **OSG-4** | The felt pacing / run-length ("20-35 min", does the run drag?) | FR47 | the observed-session pass (§10); the STRUCTURAL pacing survey was ALREADY measured by 4.6 |

**Verified headless in this story (NOT gaps):** the `warding_salve` reward-table absence (§8.2, tripwire test),
the objective class distinctness (§9.2, 12.2 proof), and the Small-neutral + Medium-neutral + Scorched-affinity
winnability inputs (§9.3, extended catalog).

---

## 12. Sibling Epic-10 gate handoff

This checklist **feeds and complements** the other Epic-10 readiness stories; it does NOT implement their
content.

- **10.5 (Accessibility & readability audit).** The audited HUD / preview / inspect surfaces overlap the
  comprehension items of §3 (esp. §3.2 preview, §3.3 preview/commit, §3.6 positioning). **10.4 does NOT perform
  10.5's audit** — 10.5 owns the systematic accessibility/readability pass; §3 here is a comprehension read,
  not a contrast/colorblind/target-size audit.
- **10.6 (MVP readiness gate & playable-build preservation).** **Consumes this checklist** — the acceptance
  thresholds (§7), the observed-session availability gaps (§11), the "die or win" loop gate, and the
  consumable/class/winnability findings. The gate decides whether each OSG gap is an acceptable limitation or a
  blocker.
- **10.7 (Asset/audio/placeholder & UX readiness gate).** Owns the placeholder-asset / audio / UX readiness
  pass (including the Flooded `_placeholder` conductive-interaction readiness item — NOT this story's). **10.4
  does NOT touch it**; recorded as a handoff only.

---

## 13. References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 10 §"Story 10.4". FR map
  (readiness patch): FR47 + NFR5 (pacing → 4.6 AND 10.4), FR48 + NFR42 (build-defining passive → 6.7 AND 10.4),
  FR73 (worth-using consumable → 6.7 AND 10.4); FR30, FR70.
- **The two feeders (referenced, not rebuilt):** `godot/tests/unit/run/test_reference_combat_driver.gd` (class
  distinctness on seed 4242 = "the direct input to 10.4's class-comparison AC" + the winnability catalog),
  `godot/tests/unit/run/test_combat_loadout.gd` (kit-derived loadout),
  `godot/scripts/run/reference_combat_driver.gd` (the winnability PROOF harness — the Medium/affinity extension
  target), `godot/scripts/content/repositories/reward_table_repository.gd` (the `warding_salve`-absent finding),
  `godot/scripts/content/repositories/consumable_repository.gd` (the 3 baseline consumables),
  `godot/scripts/content/repositories/class_repository.gd` (the three MVP class kits).
- **UX appendix (the audited comprehension surfaces):** `_bmad-output/planning-artifacts/ux-appendix-run-flow.md`
  — §1 HUD, §2 preview/confirm (two-step commit + the §2.3 audio-off distinction), §3 inspect, §4 passive modal,
  §13 save/resume, §14 layout+accessibility (move-commit), §0.5 accessibility.
- **Prior readiness-doc precedents (the structural model):**
  `_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md` (10.1 — docs-plus-gaps,
  verify-what-you-can, honest availability gaps, touch-no-simulation);
  `_bmad-output/implementation-artifacts/11-1-run-flow-ux-appendix-and-screen-contracts.md` (11.1 —
  contract-gaps-against-owners).
- **Overlapping deferred-work items (folded here, not reopened elsewhere):**
  `_bmad-output/implementation-artifacts/deferred-work.md` — the 12.2 Medium/affinity winnability gap (§9.3
  resolves it), the 6.7/7.1 `warding_salve` consumable-frequency finding (§8.2 flags it), the 4.6 FR47 pacing
  tracked notes (§10 overlays them), the Epic-11 Necromancer/Shadeblade class-kit forward hook (§9.2).
- **Project rules:** root `project-context.md` (NO telemetry/NFR11; difficulty non-goal; the Epic-12
  loadout/winnability lines 274-281 + 477-480; the reference-driver-is-a-proof-harness line 279; the Epic-10
  readiness-harness rollup lines 283-292; human-playtests-required Testing rule).
