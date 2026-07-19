# Story 14.8: Hero-Select Rebuild

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a hero-select screen with portraits, class kits, and clear selection feedback,
so that choosing a class feels like a real decision, not five gray bars.

## Context & Why This Story Exists

Epic 14 ("Playable & Presentable") is the **second pre-ship backlog epic**, added 2026-07-16 after an agent-driven desktop playtest found the built MVP is **not honestly finishable** and **does not look intentional** (`playtest-sessions/agent-playtest-2026-07-16.md`; `sprint-change-proposal-2026-07-16.md`). Story 14.8 is the **FIRST story of Band 2** ("looks intentional" — presentation), landing after Band 1 (14.1–14.7) made the loop finishable + readable.

It closes finding **F13** (`sprint-change-proposal-2026-07-16.md` line 25):

> **F13 — the hero-select is five gray text bars + empty void with zero selection feedback, despite the approved portraits sitting in-repo.**

The current `hero_select_presenter.gd` builds a bare `VBoxContainer` with one `Button` per class (`_render_roster`, lines 68-83) — a text label like `"Warrior"` or `"Necromancer (locked: <hint>)"` — and a single "Begin Descent" confirm. The five approved character portraits (`godot/assets/characters/char.*.png`) are already imported and are used by the tactical board, but the hero-select screen renders none of them, shows no per-class kit, and gives no visible selection state. 14.8 rebuilds this screen.

**This story is a PRESENTATION SCENE over shipped, pinned view-model contracts — it makes NO domain / command / event / RNG / save change and re-pins NOTHING.** Everything it renders already exists: the `HeroSelectViewModel` roster projection (5.2/11.6), the `ClassStartSummaryViewModel` class-kit projection (5.5), and the already-imported portraits. This is the same ratified Band-2 shape as the presentation-only Band-1 stories (14.2/14.3/14.5): additive presentation reading pinned VMs, the assertable render decisions in a scene-free `RefCounted` seam, the scene verified by construction + the compile guardrail.

**The design call it implements (from `sprint-change-proposal-2026-07-16.md`):** the 14.8 scope row (line 143) — "Rebuild hero select using the **existing approved portraits** + per-class kit summaries + **visible selection state** + a minimal title treatment | Presentation scene over the existing pinned `HeroSelectViewModel`/`ClassStartSummaryViewModel`; no domain change." There is **no vetoable D-decision unique to 14.8** (D1/D2 are 14.1; D3/D6 are 14.5; D4 is 14.4; D5 is 14.7).

**Why this screen matters beyond cosmetics (the load-bearing flow fact — read before Task 1).** After Story 14.5's **D3 reroute**, hero-select is the **SINGLE live seed + class source** for the whole game. The outpost's "Descend Again" now navigates to the hero-select stage (`SceneManager.go_to_stage("hero_select")`) instead of starting a class-less run — and 14.5 **deleted** the outpost's own start/seed logic (`RunSeedSource.resolve` + `_new_run_entropy` + `controller.start`) as dead code. So `hero_select_presenter._on_confirm_pressed` (lines 99-128) is now the **only** place a live run starts, for **both** the initial descent and every re-descend, threading the seed through the 14.4 `RunSeedSource` seam. **14.8 must NOT touch that confirm/start path** — it rebuilds the *presentation* around it (portraits, kit summaries, selection state) and leaves the start seam byte-identical.

## Acceptance Criteria

**AC1 — Portraits + per-class kit summaries + a minimal title (F13; FR68)**
Given the hero-select stage is shown
When it renders
Then it uses the **existing approved character portraits** (`godot/assets/characters/char.warrior.png`, `char.pyromancer.png`, `char.ranger.png`, `char.necromancer_locked.png`, `char.shadeblade_locked.png` — already imported) and shows each playable class's **kit summary** (weapon / support / passives, sourced from `ClassStartSummaryViewModel`) plus a **minimal title treatment** — **no empty-void layout**
And it renders from the **existing pinned `HeroSelectViewModel` / `ClassStartSummaryViewModel`** (no domain change), **degrading gracefully if a portrait texture is unresolved** (a missing-import dev checkout shows a labeled placeholder, never a crash or a blank tile — the defensive-runtime-load discipline).

**AC2 — Clear visible selection state + locked classes with their unlock cost (NFR9)**
Given the player selects a class
When the selection changes
Then the screen shows a **clear visible selection state** — the selected class is **unmistakably distinguished by border / label / text, NOT color alone** (NFR9) — and **locked classes are shown as locked with their unlock cost**
And the **authoritative selectability gate stays `HeroSelectViewModel.is_class_selectable` / `RunStartCommand`** (the UI's grey-out + confirm-enable is UX on top of the fail-closed command gate; the UI does **not** become authoritative — a mis-enabled confirm on a locked/unknown class still cannot start a run).

**AC3 — Pinned-contract posture: no domain change, art-import discipline, verified by construction (determinism/save gates held)**
Given the pinned contracts
When this story lands
Then **any newly-imported art has its `*.png.import` sidecar committed** (the 13.1 import discipline) — but the five portraits are **already imported**, so 14.8 is expected to add **no new art** (if a new `.gd` seam file is added, its `.gd.uid` sidecar is committed instead); **no domain / save / RNG contract changes**; the scene is **verified by construction + the compile guardrail** (`test_run_flow_scenes_load.gd`, which already loads `hero_select.tscn`); the assertable render decisions live in a **scene-free `RefCounted` seam with a unit test** (the 14.2/14.3/14.5 posture)
And **every pinned fingerprint stays byte-identical** (the 23-key `RunSnapshot` gate stays 23, `ProfileSnapshot.SCHEMA_VERSION == 1`, the 7 named RNG streams unchanged, no new event/enum value, no new autoload, no new RNG draw site). **14.8 re-pins NOTHING.**

## Tasks / Subtasks

- [x] **Task 1 — The scene-free hero-select render seam (portrait + selection + locked + kit-summary decisions) (AC1, AC2)**
  - [x] Add a new `godot/scripts/ui/view_models/hero_select_render_view.gd` (`extends RefCounted`) — the pinned scene-free render-decision seam the rebuilt presenter reads (mirrors `OutpostRenderView` / `TacticalAttackPreviewPanel` / `TacticalCombatFeedback`: assertable render decisions in a unit-tested `RefCounted`, the presenter is thin glue). Recommended: build it FROM a `HeroSelectViewModel` (so it reuses the pinned roster projection + `is_class_selectable`) plus the currently-selected class id. Expose ONLY what the presenter draws (the 14.3 "seams expose only what the presenter consumes" rule):
    - a per-class **row projection** in `HeroSelectViewModel.classes()` order carrying: `class_id`, `display_name`, `selectable`, `is_selected` (== the seam's selected id, fail-closed false for none), `portrait_path` (the const map below — the `_locked` suffix for the two locked classes), `locked_label` (for a locked class: `unlock_hint` + the numeric unlock cost from `MetaSpendRules.class_unlock_cost(class_id)` when the id is a known `CLASS_UNLOCKS` entry, else just the hint — a deterministic presentation read, NOT a domain change), and the **kit summary** for a selectable class (see Task 2's `re_derive_kit` source; a locked class has no kit — render only the locked affordance).
    - `is_class_selectable(class_id)` passthrough (delegate to the wrapped `HeroSelectViewModel` — the UI pre-gate; the authoritative gate stays `RunStartCommand`).
  - [x] Pin an EXACT key set for the row projection (the `HeroSelectViewModel.ENTRY_KEYS` / `TacticalBoardViewModel` exact-key discipline — a key never silently appears/vanishes). A non-resolving class id is skipped fail-closed (never a half-row), mirroring `HeroSelectViewModel.classes()`.
  - [x] Keep the seam a PURE read: no RNG, no mutation, no live `ClassDefinition`/`StartingKit` handle leaked out (project plain String/bool/int). Use `str(...)` never eager `String(nullable)` in any assert/log message (14.1 retro).
  - [x] Acceptable alternative (only if you deliberately skip the seam): keep the portrait map + selected-state + kit projection as thin logic in the presenter (like `tactical_board_presenter.CLASS_TEXTURE_PATHS`), relying on the compile guardrail only. **Recommended: the seam** — it gives the `_locked`-suffix mapping, the pre-start kit projection, and the selected-state real automated coverage (AC3's "assertable logic in a `RefCounted` seam"). *(Chose the recommended seam.)*

- [x] **Task 2 — Rebuild the hero-select scene presentation (AC1, AC2)**
  - [x] Rewrite `hero_select_presenter._build_layout()` / `_render_roster()` (`hero_select_presenter.gd:42-83`) to render, per class row (reading the Task-1 seam):
    - the **portrait** via a `TextureRect` loaded **DEFENSIVELY at runtime** (`load(portrait_path)`, NEVER `preload`) with a null-guard → a labeled placeholder (mirror the `tactical_board_presenter.gd:62-85` discipline: the compile guardrail stays green on an un-imported `.godot/` checkout; an imported build shows the real portrait). This satisfies AC1's "degrading gracefully if a portrait texture is unresolved."
    - the class **display_name** + the **kit summary** for a selectable class: weapon / support / passives. Source the kit from the STATIC `ClassStartSummaryViewModel.re_derive_kit(class_id)` (returns a `StartingKit` with `weapon_id` / `support_id` / `baseline_hp` / `class_passive_id` / `equipment_synergy_passive_id`) and, if you surface passive text, `ClassStartSummaryViewModel.re_derive_resolver(class_id).explain(RuleTrigger.RUN_STARTED)` + `.explain(RuleTrigger.BEFORE_ATTACK)` (already human-readable explanation strings). **Do NOT call `summarize(run)` — there is no started run at hero-select; `summarize(null)` returns the identity-ABSENT empty surface.** (See Dev Notes "The kit summary source.") *(Passive explanations surfaced in the seam via `re_derive_resolver`.)*
    - a **locked** class as locked: its `char.*_locked.png` portrait + the locked label (`unlock_hint` + the numeric cost) + a disabled/blocked affordance. Do NOT wire a selection handler for a locked class.
    - a **minimal title treatment** (replace the plain "Choose Your Hero" `Label` with a styled title — a heading + basic spacing; the full `Theme` is 14.11, so keep this minimal, not a bespoke theme).
  - [x] Render the **visible selection state** (AC2): when a class is selected, distinguish its row by a **non-color channel** — a border + a `[Selected]`/checkmark label or bold text, not color alone (NFR9). Re-render (or update) the rows so the previously-selected row loses the marker and the new one gains it. Keep the confirm button ("Begin Descent") disabled until a selectable class is chosen (existing behavior). *(Selected row: border StyleBoxFlat + a "✓ Selected" text marker.)*
  - [x] Honor the `support_id == "none"` reality: Ranger's kit records `support_id == &"none"`, which is the REAL baseline `SUPPORT_NONE` (a valid no-support kit) — render it honestly as "No support" / "None", **NEVER** as a missing/error item (project-context.md line 176). Prefer human display names for weapon/support if easily resolved via the repositories; a snake_case id is an acceptable minimal fallback (polished display-naming across screens is 14.10/14.11) — but use `str(...)` and never render a raw null. *(Ranger's `none` renders "No support"; ids prettified via `String.capitalize()` — the snake_case minimal fallback.)*
  - [x] Keep geometry built from the injected viewport + `TacticalLayoutProfile` (targets ≥44px, `DEFAULT_MINIMUM_TOUCH_TARGET`), never hardcoded pixel positions (the existing `_build_layout` posture; the full semantic region plan across screens is 14.11).

- [x] **Task 3 — Preserve the authoritative selectability + start gates; keep the profile-unaware VM (AC2, AC3)**
  - [x] The UI grey-out / confirm-enable stays gated on `HeroSelectViewModel.is_class_selectable` (via the Task-1 seam); the AUTHORITATIVE fail-closed gate stays `RunStartCommand` (reached through `_on_confirm_pressed` → `RunFlowController.start`). Do **NOT** make the UI authoritative.
  - [x] **Do NOT touch `_on_confirm_pressed` (lines 99-128) or `_new_run_entropy` (137-140)** — the 14.4 `RunSeedSource` seam + the class-ful `RunFlowController.start` are the single live seed/class source (14.5's D3 reroute made hero-select the only start site). 14.8 rebuilds the *roster presentation* only; the confirm/start path is byte-identical. *(Both methods left byte-identical.)*
  - [x] **Keep `HeroSelectViewModel.new()` PROFILE-UNAWARE (line 32) — do NOT thread the profile (the WORK-AROUND, not a fix).** Rationale (read Dev Notes "The profile-threading decision"): the profile-threading fix is **explicitly bundled with the Necromancer/Shadeblade class-kit CONTENT story**, NOT the hero-select rebuild, because threading the profile WITHOUT authoring their kit content would make a spend-unlocked class read **selectable** while `RunStartCommand`'s kit gate still **rejects** it (necromancer/shadeblade carry no kit) — a NEW mis-enabled-start hazard. The current profile-unaware VM is **internally consistent** (grey-out + start gate both static). The three baseline classes (warrior/pyromancer/ranger) are always selectable, so the class-ful descend always works and F13 is satisfied. Render necromancer/shadeblade as locked via their `_locked` portraits + cost. *(`HeroSelectViewModel.new()` unchanged; the defer inherited unchanged.)*

- [x] **Task 4 — Render-decision test + determinism/save gates held + suite green (AC1, AC2, AC3)**
  - [x] Add `godot/tests/unit/ui/test_hero_select_render_view.gd` (the scene-free render-decision test — no SceneTree; the presenter is verified by construction + the compile guardrail). Pin, on a `HeroSelectRenderView` built from a fixture `HeroSelectViewModel` + a selected id:
    - the baseline roster projects all 5 rows in `class_ids()` order with the EXACT pinned key set;
    - each row's `portrait_path` maps correctly — `char.<id>.png` for warrior/pyromancer/ranger, `char.<id>_locked.png` for necromancer/shadeblade;
    - `is_selected` is true for exactly the selected class, false for the rest (and false-for-all when the selected id is empty/unknown — fail-closed);
    - a selectable row carries a non-empty kit summary (weapon/support/passives via `re_derive_kit`); a locked row carries the locked label (`unlock_hint` + cost 3 for necromancer / 5 for shadeblade) and NO kit;
    - `is_class_selectable` passthrough is fail-closed (warrior true; necromancer/shadeblade false with the profile-unaware VM; unknown id false).
  - [x] Use `str(...)` never eager `String(nullable)` in assert messages (14.1 retro test-honesty note).
  - [x] Confirm **no domain/RNG/save change**: the ONLY production files touched are `hero_select_presenter.gd` + `hero_select.tscn` (a rebuilt scene may gain child nodes) + the new `hero_select_render_view.gd` seam (+ its test). `HeroSelectViewModel` / `ClassStartSummaryViewModel` / `RunStartCommand` / `RunSnapshot` (23 keys, `SCHEMA_VERSION == 1`) / `RngStreamSet` (7 streams) / `DomainEvent` (no new enum value) / every generation/route/finale/combat file are **untouched**. No new autoload; no new event; no new draw site. **14.8 re-pins NOTHING.** *(`hero_select.tscn` NOT touched — the layout is code-built; only the presenter + the new seam + its test changed.)*
  - [x] Run the FULL headless suite (mandatory command below). Grep the RAW output for `SCRIPT ERROR|Parse Error|^FAIL` (the false-PASS guard): exactly the **6 documented stderr negatives** (int64-overflow ×2 in `test_manual_seed_loader.gd:153` + `test_domain_event.gd:146` — the 14-4 attribution correction; malformed-JSON ×3; `invalid_node_type` ×1), **ZERO new**. Baseline is **202 PASS files** (post-14.7); the new `test_hero_select_render_view.gd` ticks the count up by 1 → expect **≥203 PASS** (asserts added to existing files don't raise the file count). `git diff --check` is the orchestrator's job (delegate git policy). *(Result: 203 PASS files, 0 FAIL, guard clean; the 6 documented negatives present, zero new.)*

## Dev Notes

### The exact files — the 14.1 "wrong files to touch" precision applied to 14.8

The hero-select surface is **`godot/scenes/ui/hero_select.tscn`** (a `Control` root whose only ext_resource is the presenter script) + **`godot/scripts/ui/presenters/hero_select_presenter.gd`** (the script that builds the whole layout in `_ready` → `_build_layout` → `_render_roster`). There is **no separate `.tscn` node tree to edit** — the layout is code-built, so the rebuild is almost entirely in the presenter script (+ the new render seam). The `.tscn` may stay a thin `Control`+script (recommended) or gain static child nodes; either way it stays in the compile guardrail. **Mirror the portrait/texture pattern from `tactical_board_presenter.gd` (`CLASS_TEXTURE_PATHS`, lines 81-85 + the defensive-load discipline 62-65) — but that presenter is NOT a file 14.8 edits; it is the reference pattern.**

### The portrait map (the `_locked` suffix gotcha)

The class ids are lower_snake `warrior` / `pyromancer` / `ranger` / `necromancer` / `shadeblade` — but the two locked portraits carry a `_locked` filename suffix that the class id does NOT. A naive `char.%s.png` format breaks for the locked pair. Use an explicit const map:

```
const PORTRAIT_PATHS := {
    "warrior": "res://assets/characters/char.warrior.png",
    "pyromancer": "res://assets/characters/char.pyromancer.png",
    "ranger": "res://assets/characters/char.ranger.png",
    "necromancer": "res://assets/characters/char.necromancer_locked.png",
    "shadeblade": "res://assets/characters/char.shadeblade_locked.png",
}
```

All five `.png` + their `.png.import` sidecars already exist in-repo (confirmed) — **14.8 imports no new art.** Load each DEFENSIVELY at runtime (`load(path)` with a null-guard → a labeled placeholder), never `preload` (so the presenter script compiles on a fresh, un-imported checkout and the compile guardrail stays green — the `tactical_board_presenter.gd` discipline).

### The kit summary source — `re_derive_kit` / `re_derive_resolver`, NOT `summarize(run)`

`ClassStartSummaryViewModel.summarize(run)` needs a **STARTED** `RunState` (a seated `starting_kit` + `rules_resolver`); at hero-select **no run has started**, so `summarize(null)` / an empty-class run returns the identity-ABSENT surface (all empty, `has_class_identity == false`). The correct pre-start source is the pair of **STATIC** pure helpers on the same view model:

- `ClassStartSummaryViewModel.re_derive_kit(class_id)` → a `StartingKit` (`weapon_id`, `support_id`, `baseline_hp`, `class_passive_id`, `equipment_synergy_passive_id`) — byte-equal to what `RunStartCommand` would seat; deterministic, zero RNG. Returns `null` for a locked/unknown class (fail-closed) — so kit summaries render only for selectable classes, which is exactly right.
- `ClassStartSummaryViewModel.re_derive_resolver(class_id).explain(window)` → human-readable passive explanation strings for the two windows (`RuleTrigger.RUN_STARTED` = the equipment-synergy passive; `RuleTrigger.BEFORE_ATTACK` = the class passive), the resolver's stable order. Use these if you surface passive *text* (nicer than raw passive ids).

These are the SAME helpers `project-context.md` line 180 names as the canonical re-derive path. Using them for a pre-start preview is a pure deterministic read — no run, no RNG, no mutation.

### The profile-threading decision — 14.8 WORKS AROUND it (does NOT fix it)

The concern (the orchestrator flagged it explicitly): the standalone `hero_select_presenter` constructs `HeroSelectViewModel.new()` **profile-unaware** (line 32), so a class the player spent Oath Shards to unlock reads **locked** here. `HeroSelectViewModel` already SUPPORTS a profile (the 11.6 optional trailing `ProfileSnapshot` param → the `unlocked_class_ids_for` overlay), so "fixing" it looks like a one-line change. **It is deliberately deferred, and 14.8 must NOT reopen it. Why:**

- The fix is **bundled with the Necromancer/Shadeblade class-kit CONTENT story**, not the hero-select rebuild — three ledger entries converge on this (`deferred-work.md` lines 157-163 [12-2 T3 re-record], 287-297 [standalone-hero-select profile-awareness], 299-310 [`re_derive_kit` profile-awareness]; `project-context.md` line 456).
- **Threading the profile without the kit content creates a NEW hazard:** necromancer/shadeblade carry **no kit content** (`ClassDefinition` kit fields are only required/authored for selectable classes; project-context.md line 175). If the VM reported a spend-unlocked necromancer as **selectable**, the row would enable, the player would confirm, and `RunStartCommand`'s **kit gate** would then reject it (`unknown_starting_weapon`/…) — a mis-enabled-start dead-end. The current profile-**unaware** VM is **internally consistent**: the grey-out AND the authoritative gate are both static, so they always agree (the 11-6 reviewer's ratified rationale — "ZERO player-visible effect in v0").
- The three baseline classes (warrior/pyromancer/ranger) are **always** selectable regardless of profile, so the class-ful descend always works and **F13 is fully satisfied** by rendering all five with portraits + the two locked ones showing their cost.

**Recorded residual (honest):** after 14.8, a spend-unlocked necromancer/shadeblade still renders locked here. That is the standing 11.6/14.4/14.5 profile-threading defer; its owner is the class-kit CONTENT story (which will thread the profile into BOTH `HeroSelectViewModel.new(repo, profile)` AND `re_derive_kit`, and author the kits). **14.8 does not narrow or re-defer it — it inherits it unchanged.**

### D4 / manual-seed ENTRY UI — OUT OF SCOPE for 14.8 (scope clarification)

The orchestrator asked whether D4 (a manual-seed entry UI) belongs in 14.8. It does **not**. **D4** in the sprint change proposal (§3.1 design-decisions table, line 106) is the **"Per-run seed source (14.4)"** decision — an entropy-derived `root_seed` at normal new-run start with the manual-seed path preserved — and it was **already shipped in Story 14.4**. The manual-seed **entry path** (FR27) is the launch-configured `GameSession.get_root_seed()` → `RunSeedSource.resolve(...)` seam wired in 14.4 (read at `hero_select_presenter._on_confirm_pressed`, lines 107-116), **NOT an on-screen seed text field**. Neither the epics 14.8 ACs (epics.md lines 3140-3161) nor the sprint-change 14.8 scope row (line 143) scope any manual-seed entry widget into 14.8, and no Epic-14 story adds one. **14.8 therefore adds NO manual-seed entry UI** and leaves the 14.4 seed seam byte-identical. (If a player-facing seed-entry field is ever wanted, it is a separate later story — do not build it here.)

### Anti-patterns to avoid (this story specifically)

- **Do NOT change `HeroSelectViewModel`, `ClassStartSummaryViewModel`, `RunStartCommand`, or any domain/command/event/RNG/save file.** 14.8 is a presentation scene + a new presentation-only render seam. The 23-key `RunSnapshot` gate stays 23; `SCHEMA_VERSION == 1`; the 7 named streams unchanged; the VMs' pinned `ENTRY_KEYS` / `SUMMARY_KEYS` unchanged.
- **Do NOT thread the profile into the standalone hero-select** to "unlock" a spend-unlocked class — that is the deferred class-kit-content concern (above). Keep `HeroSelectViewModel.new()`.
- **Do NOT touch `_on_confirm_pressed` / `_new_run_entropy` / the `RunSeedSource` seam** — hero-select is the single live seed/class start site since 14.5's D3 reroute; the start path is byte-identical.
- **Do NOT call `summarize(run)` for the pre-start kit preview** — there is no run; use `re_derive_kit` / `re_derive_resolver`.
- **Do NOT `preload` the portraits** — load defensively at runtime with a null→placeholder fallback (the compile-guardrail-on-fresh-checkout discipline).
- **Do NOT treat `support_id == "none"` as missing/error** — it is the REAL Ranger no-support kit; render it honestly.
- **Do NOT rely on color alone for the selection state or the locked state** (NFR9) — use border/label/text.
- **Do NOT add a manual-seed entry field, a difficulty selector, or any new run-config UI** — out of scope (difficulty is a hard non-goal; seed entry is the 14.4 launch seam).
- **Do NOT import new art** — the five portraits already exist; if you nonetheless add any asset, commit its `*.png.import` sidecar (13.1). If you add the new `.gd` seam, commit its `.gd.uid` sidecar.
- **Do NOT use eager `String(nullable)` in assert messages** (14.1 retro — it crashes on a null read and masks the real failure). Use `str(...)`.
- **Keep the false-PASS grep guard standing** — grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL`; never trust the summary PASS line alone. Exactly the 6 documented stderr negatives; ZERO new.

## Project Structure Notes

- **Files touched (production):** `godot/scripts/ui/presenters/hero_select_presenter.gd` (the rebuilt roster presentation — portraits, kit summaries, selection state, locked affordances, minimal title; the confirm/start path UNCHANGED); a NEW `godot/scripts/ui/view_models/hero_select_render_view.gd` (the scene-free render-decision seam); and `godot/scenes/ui/hero_select.tscn` only if you add static child nodes (a thin `Control`+script is fine — the layout is code-built).
- **Test:** NEW `godot/tests/unit/ui/test_hero_select_render_view.gd` (the scene-free render-decision unit test). No new SceneTree test — the scene stays verified by construction + `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (which already loads `hero_select.tscn` at line 39 and compiles `hero_select_presenter.gd` at line 20). The pinned `HeroSelectViewModel` roster + selectability contract is already covered by `test_hero_select_view_model.gd` (5.2/11.6).
- **Assertable render decisions live in the scene-free `RefCounted` `HeroSelectRenderView` seam** (unit-tested); the presenter is thin glue verified by construction (the 14.2/14.3/14.5 posture). A new `.gd` global-class file gets a `.gd.uid` sidecar generated + committed (the 13.1 discipline). **14.8 adds no art** (portraits already imported).
- `scripts/rules/{conditions,operations}`, generation/route/finale/combat/save files — all untouched. No domain/command/event/save/RNG change.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Domain owns truth; presentation observes + submits commands (NFR14/NFR15).** The hero-select render is a pure read over the pinned `HeroSelectViewModel` / `ClassStartSummaryViewModel`; the confirm SUBMITS through the existing `RunFlowController.start` → `RunStartCommand` path (unchanged). The UI owns no run truth and mutates no domain/profile state.
- **Class-start surface is a scene-free projection with EXACT pinned key contracts** (project-context.md line 181): `HeroSelectViewModel.ENTRY_KEYS` / `ClassStartSummaryViewModel.SUMMARY_KEYS` are unchanged; the new render seam adds its own pinned row-key set (a key never silently appears/vanishes). UI-scene-last: 14.8 is the FR68 hero-select scene the 5.2/5.5 view models were built to feed.
- **`get_class` is a reserved `Object` method** (project-context.md line 174): the class accessor is `ClassRepository.get_class_definition(...)` — the view models already use it; never call `get_class`.
- **`support_id == "none"` is the REAL baseline support** (project-context.md line 176) — never render it as missing/error (falsely maligning the Ranger kit).
- **Save truth = versioned domain snapshots (NFR15).** No save change: the 23-key `RunSnapshot` gate stays 23; `ProfileSnapshot.SCHEMA_VERSION == 1`; the profile is not threaded (the deferred concern).
- **Named RNG only; deterministic under seed (NFR13).** 14.8 draws ZERO RNG (the render seams + `re_derive_kit`/`re_derive_resolver` are RNG-free pure reads; the seed source stays the 14.4 `RunSeedSource` seam, untouched). The 7 named streams are unchanged, unreordered.
- **Assertable logic lives in scene-free `RefCounted` seams** (no SceneTree presenter tests — verify by construction + the compile guardrail). No new autoload.
- **Difficulty is a hard non-goal.** 14.8 changes no enemy/HP/damage/reward number and adds no difficulty selector.
- **Color-independence (NFR9).** The selection state, locked state, and any status meaning carry a text/border/label channel, not color alone.
- **Every generator/route/finale/combat seed-regression fingerprint stays byte-identical** (14.8 touches only `scripts/ui/` + `scenes/ui/`; no fingerprint can move — including the 14.1-re-pinned combat replay at seed 24680). **14.8 re-pins NOTHING.**
- **Headless suite stays green** (202 PASS baseline post-14.7; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Deferred-work overlaps folded in (only those that touch 14.8's area)

- **The standalone-hero-select profile-awareness defer (`deferred-work.md` lines 287-297) — INHERITED, NOT resolved by 14.8.** "Wire `hero_select_presenter.gd`'s standalone scene to be profile-aware — thread the loaded profile into both the `HeroSelectViewModel` and the `controller.start(...)` call — bundled with authoring the Necromancer/Shadeblade class-kit content." 14.8 rebuilds the presentation but keeps `HeroSelectViewModel.new()` profile-unaware (see Dev Notes). Owner stays the class-kit CONTENT story.
- **The `re_derive_kit` profile-awareness defer (`deferred-work.md` lines 299-310) — NOT 14.8's, and unaffected.** 14.8 calls `re_derive_kit(class_id)` only for the always-selectable baseline classes (warrior/pyromancer/ranger), for which the static `def.is_selectable()` gate is already true — so the profile-awareness gap has zero effect on 14.8. It remains the class-kit content story's item.
- **The 12-2 T3 Necromancer/Shadeblade class-kit CONTENT re-record (`deferred-work.md` lines 157-163) — the OWNER of the two defers above.** 14.8 renders necromancer/shadeblade as locked (their `_locked` portraits + cost); it authors no kit and does not make them startable.
- **NOT 14.8:** the reward-overlay geometry + passive-confirm `display_name` (13.2 → Story 14.11), the player-HUD display-names/range-highlights (F9/F10 → Story 14.10), the outpost cleanup (F14 → Story 14.9), the UI theme + semantic layout across screens (F15/F16 → Story 14.11). Do not pull them into 14.8. (14.8's title treatment is *minimal*; the real `Theme` is 14.11.)

### Epic-14 constraints inherited (retro-notes/epic-14.md + the sprint change)

- **EXACT files (14.1 "wrong files" precision):** the hero-select surface is `hero_select_presenter.gd` + `hero_select.tscn` (+ the new render seam) — the code-built layout means the presenter script is where the rebuild lives; `tactical_board_presenter.gd`'s `CLASS_TEXTURE_PATHS`/defensive-load is the *reference pattern*, not a file to edit.
- **Render from the bound VM / the real source, not empty presenter state (14.3 systemic):** the roster reads the constructed `HeroSelectViewModel`; the kit summary reads `re_derive_kit(class_id)` — never an empty `summarize(null)`.
- **Seams expose only what the presenter consumes (14.3):** the render seam surfaces only the row fields the scene draws — no forward-looking dead output.
- **`str(...)` not eager `String(nullable)` in assert messages (14.1).** The false-PASS grep guard stays standing; exactly the 6 documented stderr negatives (int64-overflow ×1 `test_manual_seed_loader.gd:153` + ×1 `test_domain_event.gd:146` — the 14-4 attribution correction; malformed-JSON ×3; `invalid_node_type` ×1).
- **Hero-select is the SINGLE live seed + class start site since 14.5's D3 reroute** (the outpost's own start/seed logic was deleted as dead code). 14.8 must leave `_on_confirm_pressed` + the `RunSeedSource` seam byte-identical.
- **EPIC-LEVEL RISK (14.4/14.5 retro):** Band-1/2 presentation stories defer their user-facing verification to the pending on-device playtest. 14.8's hero-select is **automated-green but human-unverified** (no SceneTree test — verified by construction). Add to the on-device playtest checklist: portraits render for all five classes, the selected class is unmistakable (non-color), the two locked classes show their cost, each selectable class shows its kit, and confirming a class starts an 18-HP run (the Band-1 on-device playtest is still pending; the user authorized proceeding).
- **Difficulty stays a hard non-goal; 14.8 re-pins nothing; no new autoload; the scene is verified by construction + the compile guardrail.**

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output (never trust the summary PASS line alone). The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only. Baseline **202 PASS files** (post-14.7); the new `test_hero_select_render_view.gd` → expect **≥203 PASS**, ZERO new stderr negatives beyond the 6 documented.

### References

- `_bmad-output/planning-artifacts/epics.md#Epic 14: Playable & Presentable` — Story 14.8 ACs (body lines 3140-3161); the Band-2 demarcation (3138); the Epic List entry (521-527); FR68 (line 158).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-16.md` — **F13** the five-gray-bars/empty-void finding (line 25); the **14.8 scope row** (line 143); the **D4 = per-run seed source (14.4), NOT a manual-seed entry UI** clarification (§3.1 design-decisions table, line 106); the whole-epic success criteria (187-192).
- `_bmad-output/auto-gds/retro-notes/epic-14.md` — the 14.1 "wrong files to touch" precision; the `str(...)`-not-`String(nullable)` note + false-PASS grep; the 14.3 render-from-source systemic + seams-expose-only-consumed; the 14.4 stderr-negative attribution correction; the Band-1/2 human-verification-deferred epic risk.
- `_bmad-output/implementation-artifacts/14-5-run-end-beat-and-run-summary-screen.md` — the ratified Band-2-adjacent presentation-only story shape, the `RefCounted`-render-seam pattern, the false-PASS discipline, and the **D3 Descend→hero-select reroute that made hero-select the single live seed/class source** (+ the standalone-hero-select profile-threading "do not reopen" note, Task 4).
- `_bmad-output/implementation-artifacts/deferred-work.md` — the standalone-hero-select profile-awareness defer (287-297); the `re_derive_kit` profile-awareness defer (299-310); the 12-2 T3 Necromancer/Shadeblade class-kit CONTENT re-record that OWNS both (157-163).
- Source files (read before implementing):
  - `godot/scripts/ui/presenters/hero_select_presenter.gd` — `_ready` (31-36, the profile-unaware `HeroSelectViewModel.new()` at line 32 — KEEP); `_build_layout` (42-62) + `_render_roster` (68-83, the five text buttons to REPLACE — F13); `_on_class_selected` (86-93); `_on_confirm_pressed` (99-128, the 14.4 seed seam + class-ful start — DO NOT TOUCH); `_new_run_entropy` (137-140, DO NOT TOUCH).
  - `godot/scenes/ui/hero_select.tscn` — the thin `Control`+script scene root (the layout is code-built).
  - `godot/scripts/ui/view_models/hero_select_view_model.gd` — `ENTRY_KEYS` (48-53); `classes()` (75-82); `is_class_selectable` (89-93); the optional-profile constructor + the 11.6 `unlocked_class_ids_for` overlay (61-69 — the profile path 14.8 does NOT use); `_project_entry` (130-140).
  - `godot/scripts/ui/view_models/class_start_summary_view_model.gd` — `SUMMARY_KEYS` (50-62); `summarize(run)` (83-133, needs a STARTED run — NOT for pre-start); the STATIC `re_derive_kit` (171-185, the pre-start kit source) + `re_derive_resolver` (195-215, `.explain(window)` for passive text).
  - `godot/scripts/ui/presenters/tactical_board_presenter.gd` — the REFERENCE pattern only: `CLASS_TEXTURE_PATHS` (81-85, the 3-selectable precedent to extend to all five with the `_locked` suffix) + the defensive-runtime-load discipline (62-65, "never preload; load()+null→fallback").
  - `godot/scripts/save/meta_spend_rules.gd` — `CLASS_UNLOCKS` (55-64: necromancer cost 3 / shadeblade cost 5, `unlock_id == class_id` in v0); `class_unlock_cost(unlock_id)` (76, the numeric cost for AC2's locked affordance).
  - `godot/scripts/content/definitions/class_definition.gd` (via project-context.md line 175) — `display_name`, `lock_state`, `unlock_hint`, the kit fields (only authored for selectable classes).
  - Tests: `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the compile guardrail; loads `hero_select.tscn` at line 39, compiles the presenter at line 20); `godot/tests/unit/ui/test_hero_select_view_model.gd` (the pinned roster + selectability + 11.6 profile-overlay coverage — the model contract 14.8 reads).

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story). Implementation by Claude Opus 4.8 (gds-dev-story).

### Debug Log References

- Full headless suite (2× — post-implementation + post-`.gd.uid`-import re-run): **203 PASS files, 0 FAIL**. False-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output: **zero hits**. The 6 documented stderr negatives all present and unchanged (int64-overflow ×2 "Cannot represent 99999999999999999999…"; `RouteNode parse failed: invalid_node_type` ×1; `Parse JSON failed` ×3), ZERO new. No error references any file this story touched.
- `.gd.uid` sidecars for the two new `.gd` files were generated via `--headless --import` (the `--scene` test run does not emit them); `HeroSelectRenderView` registered as a global class with no collision.

### Completion Notes List

- **F13 closed via a presentation-only rebuild over pinned VMs.** Added the scene-free render-decision seam `hero_select_render_view.gd` (`HeroSelectRenderView`, `extends RefCounted`) and rebuilt `hero_select_presenter.gd` to draw it: per class row a portrait + display name + (selectable) kit summary or (locked) unlock affordance, plus a visible selection state. No domain / command / event / RNG / save change; **re-pins NOTHING**.
- **The seam is the assertable surface.** It wraps a profile-unaware `HeroSelectViewModel` + the selected id and projects rows with the EXACT pinned `ROW_KEYS` (`class_id`, `display_name`, `selectable`, `is_selected`, `portrait_path`, `locked_label`, `kit`). `portrait_path` uses the explicit const map (the `_locked` suffix for necromancer/shadeblade). `is_selected` is fail-closed (true only for a SELECTABLE row whose id == the selection; false on empty/unknown/locked). `locked_label` = unlock hint + numeric cost from `MetaSpendRules.class_unlock_cost` (necromancer 3 / shadeblade 5). The `kit` sub-dict (empty for a locked class) carries `weapon_id` / `support_id` / `baseline_hp` / `passives`, sourced from the STATIC `ClassStartSummaryViewModel.re_derive_kit` + `re_derive_resolver().explain(BEFORE_ATTACK)` then `.explain(RUN_STARTED)` — the pre-start path, never `summarize(run)`.
- **The confirm/start path is byte-identical.** `_on_confirm_pressed` (the 14.4 `RunSeedSource` seam → class-ful `RunFlowController.start`) and `_new_run_entropy` are untouched. `HeroSelectViewModel.new()` stays PROFILE-UNAWARE — the profile-threading fix is inherited unchanged as the class-kit CONTENT story's item (threading it here without authoring necro/shade kits would create a new mis-enabled-start hazard). Necromancer/shadeblade render locked (their `_locked` portraits + cost).
- **Presentation choices (verified by construction; pixel polish deferred to the on-device playtest).** Each row is a clickable `Button` (children `mouse_filter = IGNORE`, the tactical-board precedent) with a fixed `ROW_MIN_HEIGHT` to fit a 96px portrait; portraits load DEFENSIVELY (`ResourceLoader.exists` + `load()`, null → a labeled placeholder Panel). The selected row carries a border `StyleBoxFlat` + a "✓ Selected" text marker (NFR9 non-color). The roster sits in a `ScrollContainer` (added robustness — 5 tall rows can't push the confirm button off-screen on a short viewport). `hero_select.tscn` was NOT modified (the layout is code-built). Weapon/support ids are prettified via `String.capitalize()`; Ranger's `support_id == "none"` renders "No support" (never missing/error).
- **On-device playtest checklist (still pending per the Band-1/2 epic risk):** portraits render for all five classes; the selected class is unmistakable (border + marker, non-color); necromancer/shadeblade show their cost; each selectable class shows its kit; confirming starts an 18-HP run.

### File List

- `godot/scripts/ui/view_models/hero_select_render_view.gd` (NEW — the scene-free render-decision seam)
- `godot/scripts/ui/view_models/hero_select_render_view.gd.uid` (NEW — generated sidecar)
- `godot/scripts/ui/presenters/hero_select_presenter.gd` (MODIFIED — rebuilt roster presentation; confirm/start path byte-identical)
- `godot/tests/unit/ui/test_hero_select_render_view.gd` (NEW — the render-decision unit test)
- `godot/tests/unit/ui/test_hero_select_render_view.gd.uid` (NEW — generated sidecar)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED — 14-8 → review; last_updated)
- `_bmad-output/implementation-artifacts/14-8-hero-select-rebuild.md` (MODIFIED — status, tasks, Dev Agent Record)

### Review Findings

**Round 1 of 3**

Round 1 primary review (`gds-code-review`, Opus 4.8, full depth; verdict **Approve**; Critical 0 / High 0 / Med 0 / Low 3; **0 open `[Review][Decision]`**). Diffed against base `story/14-7-full-backpack-reward-escape-hatch` (merge-base == the 14-7 tip `69e4fded` — this story is STACKED on the 14-7 branch, deliberately NOT diffed against `main`; two-/three-dot identical). Presentation-scene-ONLY over `scripts/ui/`: the changed code set is EXACTLY the story's File List — MODIFIED `hero_select_presenter.gd` (rebuilt roster presentation) + NEW `hero_select_render_view.gd` seam (+ `.gd.uid`) + NEW `test_hero_select_render_view.gd` (+ `.gd.uid`). `hero_select.tscn` is NOT touched (the layout is code-built); NO domain/command/event/RNG/save/generation/route/finale/combat/schema file appears in the diff, so the 23-key `RunSnapshot` gate / `SCHEMA_VERSION == 1` / the 7 named RNG streams are byte-untouched and no fingerprint can move (14.8 re-pins NOTHING).

Verified against source (the scrutiny checklist):
- **Confirm/start path BYTE-IDENTICAL** — `_on_confirm_pressed` (the 14.4 `RunSeedSource` seam → class-ful `RunFlowController.start`) and `_new_run_entropy` appear NOWHERE in the diff (the final change hunk ends at `_on_class_selected`, whose only edit is `_confirm_button.disabled = false` → `_render_roster()`); both methods are unchanged. The single live seed/class start site (14.5's D3 reroute) is preserved.
- **`HeroSelectViewModel.new()` PROFILE-UNAWARE** — `_ready` line 46 is unchanged; the profile is not threaded. The deliberate defer (owner = the Necromancer/Shadeblade class-kit CONTENT story) is inherited unchanged; necromancer/shadeblade render locked via their `_locked` portraits + cost.
- **No `summarize(run)` at hero-select** — `summarize` appears in the seam ONLY in explanatory comments (never a call); the pre-start kit source is the STATIC `re_derive_kit` + `re_derive_resolver().explain(BEFORE_ATTACK)` then `.explain(RUN_STARTED)` (the same order `summarize` surfaces), a zero-RNG pure read.
- **Defensive portrait loading** — `_load_portrait` guards `path.is_empty()` + `ResourceLoader.exists(path)` + an `is Texture2D` check, returns null → a labeled placeholder `Panel`; never `preload`. All five `char.*.png` + `.png.import` sidecars confirmed in-repo (no new art).
- **`support_id == "none"` honesty** — `_support_display` renders the REAL Ranger baseline `&"none"` (and empty) as "No support", never a missing/error item; `test _ranger_kit_carries_the_real_none_support` pins the verbatim `"none"` projection.
- **Non-color channels (NFR9)** — selection = a border `StyleBoxFlat` (shape) + a "✓ Selected" text marker; locked = a "[Locked]" name suffix + the `locked_label` body text (`unlock_hint` + numeric cost). Neither state relies on color alone. `is_selected` is fail-closed (only a SELECTABLE row whose id == the selection).
- **Seam purity + fail-closed** — `HeroSelectRenderView` is a `RefCounted` pure read; null VM → empty roster; unknown/empty/locked selection → no marked row; it leaks no live `StartingKit`/`ClassDefinition`/resolver handle (projects plain String/bool/int/Array); `class_name HeroSelectRenderView` is unique (no collision); every preload dependency path exists.
- **Selection re-render safety** — the re-render frees the just-tapped row `Button` via deferred `queue_free` (the standard Godot "rebuild list on click" idiom; the object stays alive through its own `pressed` emission — detach-safe, no double-free); handlers are re-wired fresh each render (no signal leak). Cosmetic-only; verified by reasoning + covered by the pending on-device playtest.
- **Suite INDEPENDENTLY re-run on the review head:** **203 PASS / 0 FAIL** ("Headless tests passed.", exit 0; false-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` = 0 hits; exactly the 6 documented stderr negatives — int64-overflow ×2 / `invalid_node_type` ×1 / malformed-JSON ×3, ZERO new; the new `test_hero_select_render_view.gd` GREEN; the `test_run_flow_scenes_load.gd` compile guardrail GREEN; both new `.gd.uid` sidecars present).

Three `[Review][Defer]`, all Low / non-blocking:

- [ ] **[Review][Defer]** (Low, from code review of 14-8, 2026-07-19) — The seam declares `KIT_KEYS` (line 68 — the "EXACT kit-summary key set" for the row `kit` sub-dict) but NOTHING references or enforces it: `_kit_summary` builds `{weapon_id, support_id, baseline_hp, passives}` as a dict literal, and `test_hero_select_render_view.gd` pins the ROW key set (`EXPECTED_ROW_KEYS`) but asserts the kit's keys only INDIVIDUALLY — so a future drift of the kit sub-dict's key set is UNDETECTED (unlike the row set, which the test catches). This applies the codebase's own `ENTRY_KEYS`/`SUMMARY_KEYS` exact-key discipline one level too shallow. (`ROW_KEYS` the const is likewise unreferenced in production, but the row contract IS enforced via the test's duplicate `EXPECTED_ROW_KEYS` literal, so only `KIT_KEYS` is a true coverage gap.) Non-blocking. Owner: a seam test-hardening pass (assert the kit sub-dict's exact keys against `KIT_KEYS`, or drop the unused const) — fold into the next `scripts/ui/` hero-select touch (likely the class-kit CONTENT story that threads the profile into this seam).
- [ ] **[Review][Defer]** (Low, from code review of 14-8, 2026-07-19) — Per-selection re-derivation cost: `_on_class_selected` → `_render_roster` rebuilds the FULL roster on every tap, and for each selectable row `_kit_summary`/`_passive_explanations` call the STATIC `re_derive_kit` + `re_derive_resolver`, each constructing a FRESH baseline `ClassRepository` (and `re_derive_resolver` also a fresh `PassiveRepository`) — so one class tap triggers ~6 `ClassRepository` + 3 `PassiveRepository` constructions plus 5 ResourceLoader-cached `load()` portrait reads. For a 5-row menu this is negligible (sub-frame) and correctness is unaffected — recorded only as a known micro-inefficiency should `HeroSelectRenderView` ever be reused in a hot path or the roster grow. Non-blocking. Owner: optional — cache the projection or inject shared repositories on the next hero-select touch.
- [ ] **[Review][Defer]** (Low, from code review of 14-8, 2026-07-19) — Band-1/2 on-device human-verification defer: 14.8's hero-select surfaces are automated-green but human-unverified (no SceneTree presenter test — the ratified Epic-11/14 verify-by-construction + `test_run_flow_scenes_load.gd` compile-guardrail stance). The pending physical-device playtest must confirm: all five portraits render (real art, not the labeled placeholder); the selected class is unmistakable via the border + "✓ Selected" marker (non-color, NFR9); necromancer/shadeblade show their `_locked` portrait + unlock cost (3 / 5 Oath Shards); each selectable class shows its kit (weapon / support / HP / passives, Ranger's support reading "No support"); the selection re-render shows no flicker/soft-lock; and confirming a class starts an 18-HP run and navigates to the route map. Extends the standing 14-1/14-2/14-3/14-4/14-5/14-6 Band-1 on-device defers with 14.8's hero-select surface. Owner: the Band-1 physical-device observed-playtest pass.
