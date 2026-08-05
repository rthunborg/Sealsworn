# Epic 16 — Generation Architecture Note (Game Architect pass)

> **Status:** DRAFT for ratification. The pre-epic architecture note that
> `sprint-change-proposal-2026-07-24.md` §5 requires **before Story 16.1**. Companion to
> `epic-16-design-brief.md` (Game Designer pass) — that document owns the design questions; this one
> owns the technical seams, invariants, and the determinism plan.
>
> **Authored:** 2026-07-24 · **Build:** `a78653c` · **Grounded in the shipped generator**, not assumed.

---

## 1. What exists today (the honest baseline)

| Aspect | Current state | Source |
|---|---|---|
| Size classes | **Small + Medium only**; validator rejects anything else | `generation_request.gd:97` `_is_valid_size_class` |
| Small layout | Fixed **8×8**, deliberately not jittered | `small_level_layout_generator.gd:72` |
| Medium layout | Fixed **~14×12** | `medium_level_layout_generator.gd` |
| Floor shape | **One open interior room**: border WALL ring, scattered interior blocker WALLs, 1–2 "wrinkles" (choke-point / blocker-cluster / hazard) | both generators, `_build_layout` |
| Reachability | Guaranteed **by construction** — the central corridor row is reserved blocker-free, so entrance→exit is trivially connected; the whole interior is walkable | `small_level_layout_generator.gd:105`, `_blocker_candidate_cells` |
| Determinism | Strict **fixed draw order** (blocker count → blocker positions → wrinkle kinds → wrinkle positions → enemy/reward placement), every draw via `STREAM_LEVEL`, per-seed fingerprint regression | `FIXED DRAW ORDER` docblocks in both generators |
| Placement pools | **Shrinking candidate pool** — each placement removes its cell, so blockers/wrinkles/enemies/rewards never collide | `_draw_blocker_cells`, `_remaining_after_wrinkles` |
| Validation | `BoardState.try_from_snapshot()` strict validate-then-reject; focused reward-reachability assert | `build_board_snapshot`, `validate_reward_reachability` |
| Zoom | `TacticalBoardZoomState` — 64px cells, default zoom **1.0**, min 0.75 / max 2.0; one shared state for **draw AND hit-test** | `tactical_board_zoom_state.gd:6-12` |

**The key architectural fact:** today reachability is a *structural guarantee* (nothing can be
unreachable, because the interior is open and a corridor row is reserved). Epic 16 converts it into
a *proven property* (rooms and corridors can disconnect, so connectivity must be validated). That
inversion is the heart of the epic's risk.

---

## 2. Architectural decisions

### AD-1 — Two-phase re-pin (16.1 dimensions, then 16.2 algorithm) — **ratified in the proposal**

Do not change dimensions and algorithm together. 16.1 enlarges Small/Medium and adds Large while
keeping the open-interior algorithm; 16.2 replaces the algorithm at the settled sizes. Two small
verifiable fingerprint movements, each independently reviewable, instead of one entangled one.
This is the same discipline Story 14.1 used for its justified combat re-pin.

### AD-2 — Room/corridor generation as a new phase, not a rewrite of the placer chain

Insert a **structure phase** ahead of the existing placement chain, preserving the shipped
draw-order discipline:

```
1. structure      (NEW) room count → room rects → corridor carve → dead-end carve
2. blockers       (existing, now drawing from room-interior cells)
3. wrinkles       (existing)
4. enemies        (existing, via EntityRewardPlacer)
5. rewards        (existing)
```

Rationale: `TacticalWrinklePlacer` and `EntityRewardPlacer` are **already shared siblings** across
both generators and already consume a shrinking candidate pool. If the structure phase emits its
**reachable-floor cell list** as that pool, phases 2–5 work unchanged. The new phase appends its
draws at the **front** of the fixed order — which is precisely why 16.2 re-pins, and why it must be
a single deliberate re-pin rather than incremental drift.

**Recommended algorithm:** deterministic room placement (grid-partition or BSP) + corridor carve
between room centroids + optional dead-end stubs. BSP is the better fit — it naturally produces
non-overlapping rooms, gives corridor endpoints for free, and its recursion order is trivially
deterministic given a fixed split-draw order.

### AD-3 — The unreachable-cell invariant lives in the domain, enforced once

New structural concept: a cell may be **structurally unreachable** (filler between rooms).
The invariant — *an unreachable cell is never a move target, never a spawn site, never a reward
site, never a valid path node* — must be enforced at **one domain seam**, not patched per consumer.

Consumers that must respect it (audit list for 16.2):
- `tactical_movement_query.gd` / `tactical_path_query.gd` — never route through or land on it
- `tactical_visibility_query.gd` / `darkness_visibility_layer.gd` — LoS treatment (see below)
- `EntityRewardPlacer` — never place on it
- `tactical_board_tap_router.gd` — a tap resolves to it as "not a destination", not as a silent reject
- `TacticalBoardViewModel` / presenter — renders as structure, not as dark floor

**Recommended representation:** reuse the existing `BoardCell.Terrain.WALL` for filler rather than
inventing a new terrain kind. WALL already blocks movement *and* line of sight, already serializes,
and every consumer already honors it — so the invariant is inherited rather than re-implemented, and
the 16.2 audit shrinks to "is anything treating open interior as implicitly reachable?". Introduce a
distinct terrain value **only** if design wants filler that blocks movement but not sight
(e.g. a chasm), which is not currently required.

### AD-4 — Reachability becomes a validated property (the new validator)

Story 16.2 must add a connectivity validator asserting, on the built grid:
1. the reachable floor set is **fully connected** (one flood-fill component);
2. **entrance → exit** is reachable;
3. **every** enemy, reward, and entity sits on a reachable cell;
4. a **minimum fightable-space** guarantee per size class (no encounter jammed into a corridor).

Failure is a **structured error** through the existing `ActionResult`/`GenerationResult` phase-error
path (validate-then-reject, never coerce) — the Story 3.2 precedent. Whether a failed layout
**retries with a fresh draw** or **fails the node** is an open call (see §5 OQ-2); retry is the
conventional roguelike answer but consumes stream draws and so must be part of the fixed order.

### AD-5 — Enemy activation state belongs to the board, not the presenter

Dormant/awake is **tactical truth** (it changes whose turn resolves), so it lives on the tactical
entity state and flows through the turn resolver — never in a scene node. Presentation renders the
wake cue by observing the state change.

Consequences:
- `tactical_entity_state.gd` gains an activation field; `enemy_turn_resolver.gd` skips dormant units.
- The **in-node fight stays ephemeral** — activation is combat-scoped and is *not* persisted, so the
  **23-key `RunSnapshot` gate stays 23** and `SCHEMA_VERSION` is untouched. (A mid-fight save would
  change this; that remains out of scope, as it has been since Epic 11.)
- Waking should emit an **append-only tail domain event** so the log/explanation layer and the
  AI-decision explanation tests can read it.
- The turn engine must not deadlock when every surviving enemy is dormant — with the shipped
  `WaitCommand` (14.1) the player can always pass, so this is satisfied, but 16.3 must test it.

### AD-6 — Zoom: change the default, not the seam

`TacticalBoardZoomState` already owns cell size, viewport, origin, zoom, and clamps, and is already
the **single shared source for draw and hit-test**. Story 16.4 is therefore a **defaults change**:
derive the initial zoom from board size (grid-fit per size class) instead of the constant `1.0`, and
widen `min_zoom` below 0.75 so a 26×28 floor can fit a phone viewport. **Do not fork the seam** —
the shared-state property is what makes taps land correctly, and it is verified without a SceneTree.

---

## 3. The determinism plan (the load-bearing section)

**Unchanged:** every layout-affecting draw routes through `GenerationRequest.draw_layout_int` /
`draw_layout_float` → `RngStreamSet.STREAM_LEVEL`. No new stream. No `randi()`/`randf()`. Generation
stays a pure function of (root seed, recipe, starting stream state). The **new structure draws are
documented in the FIXED DRAW ORDER docblock** of each generator, exactly as the wrinkle and
placement phases were appended before them.

**Re-pin schedule — exactly two, both deliberate:**

| Story | What moves | What must NOT move |
|---|---|---|
| **16.1** | Layout fingerprints for Small/Medium (dimensions), plus new Large entries | Route fingerprints; finale fingerprints; the draw order itself |
| **16.2** | Layout fingerprints (algorithm) + any combat-replay composite that depends on geometry | Route/finale fingerprints; save schema; the named-stream set |

Each re-pin is **re-derived via the existing `tools/dump_*` regeneration path in the same PR**, with
the justification recorded — never a hand-edit to make a drifting test pass. This is the ratified
project rule and the 14.1 precedent.

**Winnability re-prove — the underestimated cost.** `APPROVED_LIVE_COMBAT_SEED_CATALOG` must be
re-derived from **live runs** for every class at every size class after *each* re-pin. Story 14.1
already demonstrated the failure mode: corpse-clearing made Medium seed 512 unwinnable **by the
reference kite heuristic** — a legitimate deterministic consequence, not a bug.

⚠️ **Room/corridor geometry is a far larger perturbation of the heuristics than corpse-clearing
was.** The reference driver's policies (ranger kiting, melee one-at-a-time commit, seer-detonation
dodging) all encode open-room assumptions. Kiting in a corridor may never converge. **Plan for the
reference driver's hero policy to need work in 16.2** — budget it in the story rather than
discovering it when the catalog fails.

### AD-7 — `MAX_ROUNDS` is a harness guard; rounds become a tracked domain fact (ratified 2026-07-24)

**No turn limit exists or will exist for players.** `interactive_combat_session.gd` enforces no
round cap — verified. `MAX_ROUNDS = 64` binds only `live_combat_resolver.gd` (auto-resolve) and
`reference_combat_driver.gd` (the winnability proof), where a `while` loop must terminate; on the
cap it fails loud and never fabricates an outcome.

- **Scale the guard with board size** (16.1) so a legitimate long Large-floor proof run is not
  misread as a non-progressing board. Keep it generous: hitting it must always mean "broken board."
- **Add a round counter to domain state.** Verified gap: `tactical_turn_state.gd` carries
  `turn_number`, but no `round_number`/`round_count` exists anywhere in domain state — the
  resolver's `rounds` is a local loop variable, discarded. Future content (secrets gated on acting
  before round N, round-keyed unlocks) needs rounds as an addressable fact, exposed to the view
  model and combat log.
- The in-node fight remains **ephemeral**, so the counter does not persist across quit/resume and
  the **23-key `RunSnapshot` gate stays 23**. Persisting it is tied to the mid-fight-save scope
  deferred since Epic 11 — out of scope here, recorded as a known boundary.

---

## 4. Performance posture (Story 16.5)

A 26×28 floor is **728 cells vs 168 today (~4.3×)**. The current presenter draws a tile grid per
cell. Before Large is enabled on any tier, 16.5 must **measure** (not assert) against
`device-tiers-and-performance-budgets.md`, and if a tier misses budget, deliver the remedy: tile
batching, culling of off-screen cells, and — a natural win here — **culling unreachable filler**,
which on a room/corridor floor may be a large fraction of the grid. Movement animation (15.8) runs
concurrently with this load and must stay responsive.

---

## 5. Open questions for the architect/lead

**All five RATIFIED 2026-07-24.**

- **OQ-1 — Algorithm choice. → BSP (Binary Space Partitioning).** Recursively split the floor
  rectangle until sections are room-sized, place one room per leaf, connect sibling rooms with
  corridors while unwinding. Chosen because rooms cannot overlap (each owns its section), corridor
  endpoints fall out of the tree for free, and the recursion is trivially deterministic given a
  fixed split-draw order — which is what the `STREAM_LEVEL` fixed-order discipline requires.
- **OQ-2 — Failed-validation policy. → Bounded retry, EXTENDING the shipped mechanism.** ⚠️ Note
  for the architect: this is **not new machinery**. Story **3.6 "generator-validation-and-bounded-
  retry" is already `done`** — a bounded-retry path exists. Epic 16's job is to **extend it to cover
  the new connectivity/fightability validators (AD-4)**, not to design a retry system. The
  determinism constraint stands: retries consume `STREAM_LEVEL` draws, so the attempt count must
  stay **fixed and documented in the FIXED DRAW ORDER** — otherwise a seed's layout depends on how
  many retries occurred. *Architect action: confirm the 3.6 retry seam is reusable as-is, or state
  what must change.*
- **OQ-3 — Filler representation. → Reuse `Terrain.WALL`** (AD-3). Inherits movement-blocking,
  sight-blocking, serialization, and every existing consumer's handling, so the unreachable-cell
  invariant is inherited rather than re-implemented.
- **OQ-4 — Boss arena. → Unchanged.** `boss_arena_builder.gd` stays a hand-shaped space and is
  excluded from the room/corridor generator.
- **OQ-5 — Recipe structure parameters. → Yes, additive fields** on `LevelRecipeDefinition` (room
  count band, corridor width, dead-end budget), planned alongside 16.2 as a content-schema change.

## 5b. ⚑ REQUIRED: review and correct the Epic 17 stub

A ratified design direction was **deferred out of Epic 16** and parked in
**`epic-17-objectives-stub.md`**: **exit-based victory with per-level objectives** — reaching the
exit becomes the only win condition, with the exit hidden or locked behind an objective (boss slain,
kill ≥50%, or none), making stealth and speed viable strategies.

This is deferred because it **changes domain truth**: the shipped condition is
`living_enemy_count == 0 → victory` (`combat_outcome_evaluator.gd:39-40`), an Epic-1 seam consumed
by the auto-resolve resolver, the winnability driver, and the finale path.

**The architect pass MUST review that stub and correct it.** Its §6.2 lists your required actions;
the substance is: decide where the win condition lives after the change (**E17-Q6**), how
"objective satisfiable on this floor" is validated at generation time (**E17-Q7** — likely an
extension of **AD-4**'s connectivity validator rather than a parallel one), and the re-pin /
winnability-re-proof plan for a changed win condition (**E17-Q8**). Also **verify §2.2's impact
table against the real code** — it was compiled from targeted greps, not a full consumer trace.

**Most valuable single contribution:** name any Epic-16 decision (AD-1..AD-6) that should be shaped
**now** to make Epic 17 cheaper later. AD-4 is the obvious candidate — a validator designed with
objective-satisfiability in mind costs little today and avoids a rewrite in Epic 17.

## 5c. Remaining open question

- **OQ-6 — Round-cap disposition.** Design **Q2** ratified that there is **no turn limit for
  levels**, but that **round/turn count must still be tracked** (secrets and unlocks may key off it).
  `MAX_ROUNDS = 64` therefore stops being a *rule* and becomes a *harness guard against
  non-progressing boards*. With Q1 ratified at 1 tile/turn, a Large floor may legitimately exceed
  100 rounds. **Architect action:** confirm the split — an explicit, generous per-size-class harness
  cap (low hundreds for Large, not 64), a round counter surfaced as durable run data, and no
  player-facing turn limit anywhere.

## 6. Story-readiness checklist

Before **16.1** starts: design **Q1 (movement speed)** and **Q2 (round cap)** ratified — 16.1's
winnability AC cannot pass without them.
Before **16.2** starts: **OQ-1**, **OQ-2**, **OQ-3** ratified; the reference-driver policy work
budgeted inside the story.
Before **16.3** starts: design **Q3 (win condition)** and **Q6 (sight ranges)** ratified.
Before **16.5** closes: design **Q5 (size class per node type)** ratified — it determines how often
a Large floor is actually generated, and therefore how much the performance gate binds.
