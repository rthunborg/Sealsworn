# Epic 16 — Design Brief (Game Designer pass)

> **Status:** DRAFT for ratification by the Project Lead. This is the pre-epic GDD pass that
> `sprint-change-proposal-2026-07-24.md` §5 requires **before Story 16.1**. It proposes GDD changes
> and surfaces the design questions Epic 16 cannot be built without answering. It does **not** edit
> `gdd.md` — the ratified answers do, in a follow-up edit.
>
> **Companion:** `epic-16-generation-architecture.md` (the Game Architect pass).
> **Authored:** 2026-07-24 · **Build:** `a78653c`

---

## 1. What Epic 16 changes, in design terms

The ratified vision (2026-07-24): keep the core loop and route/node model — **a node is still one
fight the player clears** — but make the floor a real place. Multi-room dungeons with corridors,
dead-ends, and structural filler that is not all walkable; three size classes instead of two, up to
a Large floor approaching Shattered Pixel Dungeon scale; a camera that defaults further out; and
**enemies that wake on their own line of sight** instead of all activating at once.

This is a **pillar-level change to "Tactical combat clarity"** (GDD §Design Pillars, pillar 1), not
a content addition. It changes what a fight *is*: today every fight is a single open-room brawl
where all enemies engage immediately; after Epic 16 a fight is an approach through structure where
threat arrives in waves you provoke.

---

## 2. ⚠️ The finding that must be resolved before 16.1 — the round budget

> **Scope correction (2026-07-24, after verification).** An earlier draft of this brief implied
> players face a turn limit. **They do not.** `interactive_combat_session.gd` enforces **no round
> cap** — a human player can take as many turns as they like, today and after Epic 16. `MAX_ROUNDS`
> is a **headless harness termination guard** on the auto-resolve resolver and the winnability proof
> driver (a `while` loop must terminate); on hitting it the resolver **fails loud and never
> fabricates an outcome**. The problem below is therefore narrower than first stated — but it still
> blocks Story 16.1.

**Measured facts (not estimates):**

| Fact | Value | Source |
|---|---|---|
| Harness round cap | **`MAX_ROUNDS = 64`** | `live_combat_resolver.gd:75`, shared by `reference_combat_driver.gd:81` |
| **Interactive player cap** | **NONE** — no turn limit in live play | `interactive_combat_session.gd` (no cap present) |
| Warrior clearing a **Medium** (~14×12) elite board | **~39 rounds** | winnability catalog, `test_reference_combat_driver.gd:86` (seed 24680) |
| Current Medium board area | 14×12 = **168 cells** | `medium_level_layout_generator.gd` |
| Proposed Large board area | 26×28 = **728 cells** | ratified scale target |
| Hero movement | **1 tile per turn** | tactical movement model |

**The problem.** The warrior's proof run already consumes **~61% of the harness cap** on a Medium
board. A Large floor is **~4.3× the area** and roughly **2× the linear traversal distance**; at one
tile per turn, crossing it costs tens of turns of pure walking before a blow is struck. Even a
modest multiplier puts the proof run past 64 rounds — at which point **the winnability proof fails**
(the driver returns cap-reached rather than victory) and Story 16.1's acceptance criterion — *"every
class can still win at every size class"* — **cannot pass**.

This is a **test-harness constraint, not a game rule.** The fix is to make the guard scale with
board size (or otherwise decouple "this board is non-progressing" from "this fight is long"), never
to impose a turn limit on players.

**There is precedent for exactly this fragility.** Story 14.1's corpse-clearing change made Medium
seed 512 **un-winnable by the reference kite heuristic** — "dead bodies now vacate their cells, so
the melee pursuers path THROUGH corpse cells and the ranger kite policy no longer converges within
MAX_ROUNDS" (`test_reference_combat_driver.gd:86`). A geometry change already broke a class's
winnability once. Room/corridor geometry is a **far larger** change to the assumptions those
heuristics encode — a ranger kite policy tuned for an open room may not converge in a corridor at
all.

**This is not a blocker to the vision — it is a design question the vision must answer.** Options in
§4 (Q1/Q2).

---

## 3. Proposed GDD changes

### 3.1 Level structure (new/expanded subsection)

Replace the implicit "one open arena per node" model with:

- A tactical floor is composed of **rooms connected by corridors**, including **dead-ends** and
  **structural filler** that is not reachable. Not every cell is a destination.
- **Three size classes**, with the working targets: **Small ~12×12**, **Medium ~18×16**,
  **Large ~26×28** (up from a fixed 8×8 / ~14×12 two-class model).
- Which node types draw which size class is a content-recipe decision (see Q5).
- Floor geometry is **generated deterministically from the run seed** and validated for
  connectivity and fightability before use — structure never makes a node unwinnable.

### 3.2 Enemy behavior (new subsection — "Awareness")

- Enemies begin a floor **dormant** and take no turn while dormant.
- An enemy **wakes** when it perceives the hero: within its **sight range**, along a valid **line of
  sight**, using the same visibility/darkness model the player is subject to.
- Waking is **permanent** for the encounter (no re-sleeping) and is **observable** — the player gets
  a readable cue, and the decision is explainable ("woke: saw hero at range 3").
- Design intent: **the player controls the pace of engagement.** Approach, sightlines, and
  positioning decide how many enemies you face at once. This is what makes a large floor tense
  rather than exhausting, and it is the mechanism that keeps "one node = one fight" playable at
  scale.

### 3.3 Pacing (§ Economy/Pacing — amendment, and the honest risk)

The GDD targets a **20–35 minute run** (gdd.md:200) across a **constant 8-tier route**. That is
~2.5–4.4 minutes per node. **Three Epic-15/16 changes all push run length up at once:**

1. **Bigger floors** → more turns per node (§2).
2. **Movement animation** (Story 15.8) → each turn now takes *real wall-clock time* it previously
   did not; a tween on every unit move plus a **sequenced enemy phase** is a direct multiplier on
   perceived node duration.
3. **Sight-based aggro** → an approach phase that is deliberately slower and more cautious.

The GDD should either **restate the run-length target** in light of this, or **name the levers**
that hold it (see Q1/Q4). Shipping all three changes without revisiting the target means the
20–35 minute claim silently becomes false.

### 3.4 Difficulty non-goal — reaffirmed

Scale and structure are **not** difficulty knobs. A Large floor is not a "hard mode"; it is a
different tactical space. No story in Epic 16 introduces a player-selectable difficulty tier or a
stat-scaling multiplier. This restates the existing hard non-goal; nothing in Epic 16 relaxes it.

---

## 4. Design questions requiring the Project Lead's ratification

**Q1 — Movement speed. — RATIFIED 2026-07-24: keep as-is (option b).** Hero movement stays
**1 tile per turn** on every size class. No move-points model, no out-of-combat speed boost. A Large
floor is deliberately a slow, dangerous crawl, and the tactical movement model plus every existing
movement fixture stays untouched — the cheapest option for Epic 16 and the one that preserves the
shipped combat feel.

> **Two consequences to carry forward.** (1) **Traversal dominates a Large floor.** The warrior proof
> run takes ~39 rounds on Medium; on a Large floor at 1 tile/turn it could plausibly exceed 100.
> That is *fine for players* (Q2: no turn limit), but the harness guard must scale generously —
> a Large cap in the low hundreds, not a nudge above 64. (2) **This sharpens Q4.** Slow movement ×
> 4.3× area × movement animation (15.8) all push node duration the same direction, so the run-length
> target and the size-class mix (Q5) are now the *only* levers left holding pacing. Decide them
> deliberately.

**Q2 — The harness round cap. (Blocking 16.1.) — RATIFIED 2026-07-24.**
**There is NO turn limit for levels and none will be introduced.** Players are never bounded by a
round count; the shipped interactive session already imposes none. `MAX_ROUNDS` is retained **only**
as a headless non-progression guard and is **scaled with board size** so a legitimate long fight on
a Large floor is never mistaken for a stuck board. The guard must remain generous enough that
hitting it always means "this board is broken," never "this fight was long."

**Q2b — Round tracking becomes a first-class domain fact. (New requirement, ratified 2026-07-24.)**
Rounds must be **counted and available as domain state**, because future content depends on it:
secrets gated on reaching something *before* round N, and unlocks keyed to round counts.
**Current gap (verified):** `tactical_turn_state.gd` tracks `turn_number`, but there is **no
persistent round counter anywhere in domain state** — the resolver's `rounds` is a *local loop
variable*, discarded after the fight. So the tracking this requires does not exist yet.
*Recommended: add a round counter to the tactical turn state (a domain fact, exposed to the view
model and the combat log), and treat "round N reached" as an addressable condition for later
content. Note the in-node fight is ephemeral (not saved), so a round count surviving quit/resume is
a separate question tied to the mid-fight-save scope that has been deferred since Epic 11.*

**Q3 — Win condition. — RATIFIED 2026-07-24, and DEFERRED OUT OF EPIC 16 → Epic 17.**
The ratified design: **reaching the exit is the only win condition for any level.** The exit may be
**hidden or locked** until a per-level objective is met — slay the boss, kill ≥50% of the monsters,
or nothing at all — so **stealth or speed is sometimes sufficient**. A player who skips enemies or
rooms **forfeits the rewards** in them.

> ⚠️ **This is a new system, not a setting.** It changes domain truth: the shipped win condition is
> `living_enemy_count == 0 → victory` (`combat_outcome_evaluator.gd:39`), an Epic-1 seam consumed by
> the auto-resolve resolver, the winnability driver, the finale, and every combat fixture. It also
> requires a new **level-objective content concept** (definition + repository + recipe wiring) and
> changes what the winnability proof proves ("can this class kill everything" → "can this class
> reach the exit"). **It is therefore deferred to Epic 17** (`epic-17-objectives-stub.md`).
> **Epic 16 ships against the EXISTING all-enemies-dead condition** so geometry, scale, and aggro
> land first and Epic 17 designs objectives against real multi-room floors.
>
> **Open gap for the designer:** the ratified wording says a skipping player "misses out on **XP** and
> loot." **No XP or character-progression system exists in the codebase** (verified 2026-07-24: no
> experience/character-level concept in `godot/scripts/`). Either the intent is the existing
> currencies (gold / loot / Oath Shards), or XP is itself a new system to scope. **Resolve in the
> designer pass.**

**Q4 — Run length. — RATIFIED 2026-07-24.** **~20–35 minutes for an AVERAGE run**, where the
expected outcome is that a player **dies at roughly 70% of nodes completed** — i.e. the target
describes a typical *incomplete* run of ~5–6 of the 8 tiers, not a full clear.

> This materially eases the §3.3 pacing risk: the budget covers ~5–6 nodes, not 8. It does not
> eliminate it — Q1 (1 tile/turn) plus 4.3× area plus movement animation still push node duration
> up — so **Q5's size-class mix remains the primary pacing lever.**

**Q5 — Size class per node type. — RATIFIED 2026-07-24.** Large is **rare and special** (elites,
pre-boss) with Small early and Medium standard — **but weighted by depth, never exclusive.** There
must always remain a **slim chance** of a Large floor appearing early or a Small floor appearing
late.

> Consistent with ratified decision **D3** (reward weighting): **positive weights only, no
> exclusions.** Depth shifts the odds; it never forecloses an outcome. The designer should state the
> weighting bands; a zero-probability entry is out of contract.

**Q6 — Sight ranges. — RATIFIED 2026-07-24.** **Every enemy carries its own sight range**, varying
by monster type and fighting style — **ranged enemies see further than melee** as a general rule.
The **Darkness affinity** both darkens the level **visually** and **reduces sight range for the
player AND for monsters**.

> Reuses the shipped darkness/visibility model rather than adding a parallel one. Note the symmetry
> requirement: darkness cuts *both* sides, so it is a mutual-concealment mechanic, not a pure
> player debuff — the designer should confirm the reduction is applied through one shared seam.

---

## 4b. ⚑ REQUIRED: review and correct the Epic 17 stub

Two ratified directions were **deferred out of Epic 16** while settling the questions above, and are
parked in **`epic-17-objectives-stub.md`**:

- **Direction A — exit-based victory with per-level objectives** (ratified Q3). Deferred because it
  changes domain truth (`combat_outcome_evaluator.gd:39`), needs a new level-objective content
  concept, and redefines what the winnability proof proves.
- **Direction B — reward restructure** (from the 2026-07-20 playtest): three rewards, pick one, or a
  single **Destroy-All**. The *structural* half stays in Epic 15 Story 15.6; the rich
  destroy-outcome content (boons, debuffs, secrets, meta unlocks, achievements) is deferred.

**The designer pass MUST review that stub and correct it** — it was drafted before this analysis and
is expected to be wrong in places. Its §6.1 lists your required actions verbatim. The single most
important is **E17-Q1: the XP gap** — the ratified Q3 wording says a skipping player forfeits "XP",
but **no XP or character-progression system exists in this codebase**. Resolve whether that means
the existing currencies (gold / loot / Oath Shards) or a genuinely new system, because the two
readings differ by an entire epic of scope.

You are also explicitly invited to **challenge the container**: Directions A and B share no
machinery and are grouped only because both were deferred on the same day.

## 5. What this brief does NOT decide

- The generation algorithm, the unreachable-cell invariant, activation-state storage, and the
  re-pin/winnability plan — all in the **architecture note** (`epic-16-generation-architecture.md`).
- Exact tuning numbers (sight ranges, room counts, movement values) — story-level content decisions
  once Q1–Q6 are answered.
- Anything in Epic 15, which ships first and is unaffected by this brief.

## 6. Handoff

Once Q1–Q6 are ratified: apply §3.1–§3.4 to `gdd.md` (level structure, enemy awareness, pacing,
difficulty non-goal restated), add the **enemy-awareness FR** to the FR Coverage Map against Epic 16,
then refine the Story 16.1–16.5 acceptance criteria in `epics.md` to match the ratified answers —
particularly 16.1 (dimensions + round budget) and 16.3 (sight model).
