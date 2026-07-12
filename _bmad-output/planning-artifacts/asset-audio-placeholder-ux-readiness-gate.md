# Asset, Audio, Placeholder, and UX Readiness Gate — Dedicated Epic-10 Asset/UX Gate

> **Story:** 10.7 (Asset, Audio, Placeholder, and UX Readiness Gate) · **Epic:** 10 (Playtest Tuning and MVP Readiness)
> **Type:** Readiness / GATE artifact — the dedicated asset/audio/placeholder & UX pass the 10.6 final gate handed
> here (`mvp-readiness-gate.md` §7.6 + §8). The direct sibling of 10.1 device-tiers, 10.4 comprehension checklist,
> 10.5 accessibility audit, and 10.6 MVP-readiness gate. It VERIFIES the shipped asset inventory + the event-to-audio
> cue map + the provenance ledger + the UX-appendix coverage, DISPOSITIONS every open placeholder as a documented
> limitation for the offline-first v0 candidate, and ROLLS UP the shipped `asset-manifest.md` / the 10.5 audit / the
> 11.1 appendix. It authors no art/audio, builds no scene, fixes no deferral, and changes no production `godot/` code.
> **Status:** authored 2026-07-12 · discharges **GDD FR46** (door-sealing/containment-law feedback cue mapping) +
> **FR112/FR113/FR114** (MVP visual/audio baseline + preview/commit cue mapping) + **NFR17/NFR18** (asset
> provenance/tracking + non-MVP spare tracking) as the Epic-10 asset gate.
> **10.7 IS the LAST story of Epic 10 in EXECUTION order — the REAL Epic-10 close** (10-8 is numbered last for list
> continuity but ran early after 10-3). After 10.7 reaches `done`, the Epic-10 retrospective + the `epic-10:
> in-progress → done` transition follow (orchestrator/Phase-8-owned). This gate performs NO epic-status change; `epic-10`
> stays `in-progress` here.

---

## 1. Purpose and Scope

**Purpose.** Epics 1–9 shipped a complete headless deterministic domain; Epic 11 wired the LIVE run-flow scenes +
hands-off loop; Epic 12 wired the INTERACTIVE hands-on tap-loop + a class-armed, winnable hero; the Epic-10 first
tranche (10-1/10-2/10-3/10-8) shipped the readiness measurement + consolidated regression + fairness harnesses;
10-4 shipped the comprehension checklist; 10-5 shipped the accessibility audit; **10-6 shipped the final
MVP-readiness gate and explicitly HANDED 10.7 the asset/audio/placeholder & UX-readiness pass** (`mvp-readiness-gate.md`
§7.6 rolls placeholder/asset/audio up + hands 10.7 the Flooded `_placeholder` [F-1] + the 0-file audio track; §8
gap-ledger names 10.7 owner). **Story 10.7 is that dedicated gate.** It answers, systematically and with evidence,
whether the MVP build uses readable visuals and feedback even where production assets are deferred — so that
placeholders do not hide missing gameplay communication or readiness risk (the story's player value).

**Scope (what this gate does — and does NOT do).**

- **VERIFY what can be verified now.** The shipped placeholder-asset inventory against every required MVP roster
  class (AC1, §3); the event-to-audio cue map across all 13 required feedback meanings + the audio-off equivalence
  (AC2, §4); the asset-metadata/provenance completeness + the no-silent-promotion guarantee (AC3, §5); the
  UX-appendix coverage of every named surface (AC5, §7).
- **DISPOSITION every open placeholder** — the Story 4.5, Story 7.5 (the 10.7-OWNED marquee item), Story 8.2, and
  asset/audio-mapping placeholders — each as `replaced` / `de-scoped with an approved limitation` / `blocking
  readiness`, with the affected story + player-facing risk + owner + target replacement path (AC4, §6).
- **ROLL UP the shipped inputs** (`asset_sources/asset-manifest.md` + `provenance-log.md` + `prompt-pack.md`; the
  10.5 accessibility audio-off audit; the 11.1 UX appendix; the `DomainEvent.Type` vocabulary) — it re-authors no
  asset, re-derives no manifest, and forks no second cue map.
- **RECORD honest availability gaps** for anything a headless agent cannot perform now — a human-eyes readability
  confirmation on a physical display, a produced audio track, a built settings scene, the live conductive-interaction
  art/VFX — each named against its owning follow-up (§8).

> **This gate VERIFIES + DISPOSITIONS + ROLLS UP; it authors no art/audio, builds no scene, fixes no deferral, and
> changes no production code.** No gameplay command / event / RNG stream / `RunSnapshot`/`ProfileSnapshot`/`SettingsSnapshot`
> schema / save key / generator-route-finale fingerprint / seed-regression sample / view model / content definition /
> presenter / `.tscn` / `export_presets.cfg` is changed, and no binary asset under `asset_sources/**` or
> `godot/assets/**` is authored, moved, or re-exported. The `_CUE_CATALOG` in `tactical_accessibility_model.gd` (the
> Flooded `_placeholder` cue ids) is READ, not renamed — this gate DISPOSITIONS it in prose, it does not touch the
> code. The full headless suite stays green and byte-for-byte behaviorally unchanged (**191 PASS / 0 `^FAIL`**,
> verified fresh in §9). No new test is added (§9 — the audio-off / cue-coverage facts are already covered by the
> two accessibility tests; the 10.6 precedent). The one sanctioned ledger edit is refining
> `asset_sources/asset-manifest.md` disposition/status columns to reflect this gate's AC4 dispositions (§6.6) —
> squarely AC3/AC4 provenance work, and `asset_sources/` is the project-context home for provenance/reviews, NOT
> `godot/` production code.

### 1.1 Two DIFFERENT "G4"s — kept distinct throughout this gate

Two independent gap-numbering schemes both use the label "G4". This gate keeps them distinct (the 10-6 Phase-3
retro-note flagged that this ambiguity persists specifically INTO 10.7 — its AC5 UX-prerequisite check + its
difficulty non-goal touch the settings surface):

- **Device-tiers §6 G4** = *no on-device / windowed render-frame profiler for sustained 60/30 FPS frame stability*
  (NFR6). One of the physical-device **G1–G7** gaps (10.6-owned; NOT this story). [Source:
  `device-tiers-and-performance-budgets.md` §6]
- **UX appendix §16 G4** = *the settings VIEW MODEL / settings SCENE gap* (PARKED — no settings scene; the outpost
  has no difficulty selector). The settings paper-audit gap (= finding F-3) that touches this story's AC5
  UX-prerequisite check + the difficulty non-goal. [Source: `ux-appendix-run-flow.md` §16 G4; `deferred-work.md`
  10-5 review F-3]

The "G1–G7" label always means the device-tiers physical-device set; the settings-VM gap is always written
"appendix §16 G4 (settings)".

---

## 2. The verification reality (why art/audio/scene/human-eyes passes are availability gaps, not blockers)

A headless autonomous agent **cannot** author final art, produce an audio track, build a settings scene, or eyeball
a readability confirmation on a physical phone display. The ACs were written to be dischargeable **without** any of
those, because the inputs this gate rolls up are all SHIPPED and readable:

- **Verify now:** the AC1 inventory roll-up (grounded in `asset-manifest.md`), the AC2 cue map + audio-off
  conclusion (grounded in the manifest §SFX + the 10.5 audit §7 + the two accessibility tests), the AC3 provenance
  confirmation (grounded in the manifest + `provenance-log.md` + `prompt-pack.md`), the AC4 disposition ledger, and
  the AC5 UX-appendix coverage verification (grounded in `ux-appendix-run-flow.md`).
- **Disposition now:** each open placeholder (Story 4.5 / 7.5 / 8.2 / asset-audio) as `replaced` / `de-scoped with
  an approved limitation` / `blocking`, with owner + target (§6).
- **Record as an availability gap:** the human-eyes physical-display readability confirmation, the produced audio
  track, the built settings scene, and the live conductive-interaction art/VFX — each named against its owning
  follow-up (§8).

This is the **same honesty posture** 10.1 used (record each gap against an owner rather than invent the data), 10.5
used (the human-eyes availability gaps → the 10.6 gate), and 10.6 used (DECIDE each open gap as a documented
limitation for the v0 candidate). 10.7's job is to DISPOSITION each open placeholder as an acceptable documented
readiness LIMITATION for the offline-first **v0 CANDIDATE** (with an owner + target discharge path), NOT to author
the missing art/audio or build the missing scene. The project-context rule that MAKES the human-hands-on-hardware
pass a legitimate availability gap: *"Human playtests remain required for feel, readability, frustration, and
excitement"* (§ Testing Rules). **The preserved build is a v0 candidate, not the final ship** — the audio track, the
Flooded conductive art/VFX, and the physical-display readability confirmation are explicitly pre-ship follow-ups,
not hard blockers that stop this gate.

---

## 3. AC1 — Placeholder-asset inventory

**GIVEN production art or audio is not yet final, WHEN MVP asset planning is reviewed, THEN production assets/audio
may be deferred ONLY IF placeholder ids exist for every required roster class, AND each placeholder is readable
enough to support tactical, reward, route, outpost, and summary decisions.**

The gate ROLLS UP `asset_sources/asset-manifest.md` (the SHIPPED inventory that already declares itself "Satisfies
the Story 10.7 readiness gate and NFR17/NFR18"). Every required roster class maps to a tracked-or-better id — there
is **no class with no id and no produced asset** (the condition that would block "may be deferred only if
placeholder ids exist"). The visual roster is `approved` / `generated`; only audio is a `planned` 0-file track
(dispositioned in §6.4).

### 3.1 Required-class → tracked-or-better id map

| # | AC1-required class | Count | Manifest id(s) | Status |
|---|---|---|---|---|
| 1 | Playable class portraits / silhouettes | 3 | `char.warrior`, `char.pyromancer`, `char.ranger` (portrait + board silhouette each) | **approved** ☑ |
| 2 | Locked class silhouettes / icons | 2 | `char.necromancer_locked`, `char.shadeblade_locked` | **approved** ☑ |
| 3 | Enemy-pattern visuals | 3 | `enemy.iron_cultist`, `enemy.gate_brute`, `enemy.ash_seer` | **approved** ☑ |
| 4 | Boss visual | 1 | `boss.larval_avatar` | **approved** ☑ |
| 5 | Affinity treatments | 4 | `affinity.scorched`, `affinity.flooded`, `affinity.cursed`, `affinity.darkness` | **approved** ☑ |
| 6 | Small/Medium Labyrinth tiles + props | 9 tiles + 3 props | `tile.floor/wall/blocker/entrance/exit/door/door_sealed/hazard/reward_object` + props `door`/`door_sealed`/`reward_object` | **approved** ☑ |
| 7 | Baseline weapon icons | 9 | `icon.weapon.{sword,dagger,spear,axe,mace,bow,crossbow,staff,wand}` | **generated** ☐ |
| 8 | Support icons | 2 | `icon.support.{tome,shield}` | **generated** ☐ |
| 9 | Passive icons / placeholder glyphs (20–30 band) | 28 | `icon.passive.001`–`028` (4 archetypes) | **generated** ☐ (28 ∈ [20,30]) |
| 10 | Currency icons | 4 | `icon.currency.{gold,oath_shard,echo,seal_fragment}` | **generated** ☐ |
| 11 | Tactical / outpost / run UI frames | 9 screens | `ui.{hero_select,tactical_hud,preview,passive_modal,run_map,outpost,run_summary,settings,save_resume}` — assembled in-engine (9-slice / StyleBox) from the **generated** Recraft frame kit `icons/ui/{button_plate,panel_frame,modal_frame}.svg` | **planned** ☐ (frame kit generated; screens assembled in-engine) |
| 12 | Range / fog overlays | 5 | `overlay.{move_range,attack_range,blocked_line,fog_hidden,fog_memory}` — **engine-drawn** flat Godot fills/shaders (NFR9), + `overlay.seer_mark` / `banner.victory` / `banner.defeat` **generated** | **planned** (engine-drawn) / **generated** (seer_mark + banners) ☐ |
| 13 | Core SFX | 14 cues | `sfx.*` (the 14-cue AC2 cue map, §4) | **planned** / 0-file → **descoped** (§6.4) |
| 14 | Ambient loops | 7 | `amb.{labyrinth,outpost,scorched,flooded,cursed,darkness,boss}` | **planned** / 0-file → **descoped** (§6.4) |

Totals (v0, per the manifest): **~92 visual** (5 classes ×2 views, 3 enemies, 1 boss, 4 affinities, 9 tiles, 11
item icons, 30 passive glyphs, 4 currency, 9 UI frames, ~9 overlays/banners) · **14 SFX** · **7 ambient**. Every
AC1-required class has a tracked-or-better id; **no roster class is a "no id, no asset" gap.**

### 3.2 The readability basis (the "readable enough" half of AC1)

Readability is gated by the manifest's **3-point readability gate** — *grayscale · phone-size · silhouette*
("Approval = passes the 3-point readability gate"). The evidence:

- **The 22 Scenario board-art assets (characters, enemies, boss, affinities, tiles, props) already PASSED the
  3-point gate** — evidence regenerable via `python asset_sources/_tools/process_board_art.py`, with full provenance
  + CU ledger in `provenance-log.md` (engine `model_google-gemini-3-1-flash`, generate @ 1K, downscale on export,
  no upscaling). These are the `approved` ☑ rows (classes / enemies / boss / affinities / tiles / props), so the
  tactical, route, and outpost decision surfaces read at the contract level.
- **The tactical readability of every affinity/Darkness danger cue is proven headless** — every run-flow affinity
  cue id (including the tracked Flooded conductive-danger PLACEHOLDER) resolves in the live `TacticalAccessibilityModel`
  catalog with a **non-color channel** (`test_run_flow_accessibility_coverage.gd`; the 10.5 audit §8), so the danger
  reads with color stripped regardless of the final art. This is the AC1 "readable enough to support tactical
  decisions" backing for the affinity surface.
- **The `generated`-but-unapproved icons** (weapons/support/passives/currency) are present on disk + tracked; the
  Approved checkbox (☐) is the human 3-point-gate pass, deferred to an asset-approval pass on import (§6.5) — a
  tracked, honest state, not a readability failure.

**The "may be deferred only if placeholder ids exist" condition HOLDS for every class** — every class carries at
minimum a tracked/planned id, and the whole visual roster is `approved`/`generated`.

### 3.3 The AC1 human-eyes availability gap (recorded, not a block)

A human-eyes readability confirmation on a physical display (real grayscale legibility + real phone-size silhouette
read on hardware) is recorded as availability gap **AG-1** (§8), owned by the **10.6 physical-device pass owner**
(it intersects the 10.5 ASG-1/ASG-2 physical-device passes and the device-tiers G1–G7 set). The CONTRACT-level
readability (the 3-point gate on the board art + the non-color cue channels) is verified now; the felt on-device
read is the physical-device dimension — an acceptable documented limitation for the v0 candidate, NOT a blocker.

**AC1 verdict:** MET — every required roster class maps to a tracked-or-better id (§3.1); the readability basis is
the manifest's 3-point gate (§3.2, board art passed, cue channels non-color); no class is a no-id gap; the
human-eyes physical-display confirmation is recorded as AG-1 (§8).

---

## 4. AC2 — Event-to-audio cue map + audio-off equivalence

**GIVEN audio feedback is mapped from domain outcomes, WHEN the event-to-audio cue map is reviewed, THEN it includes
movement, weapon hits, enemy actions, hazards, preview/confirm distinction, passive pickup, Consume, Destroy,
curse/corruption, door sealing, death, reward reveal, and boss victory, AND muting audio never removes required
information because visual/textual equivalents remain available.**

### 4.1 The 13 required feedback meanings → shipped cue id + past-tense `DomainEvent.Type`

The 14 SFX cues in `asset-manifest.md` §SFX cover the 13 required AC2 meanings (preview + confirm are two SHIPPED
cues covering the single "preview/confirm distinction" meaning). Each meaning maps to (a) the shipped cue id and (b)
the past-tense `DomainEvent.Type` it fires off (READ from `godot/scripts/core/events/domain_event.gd`; presentation
MIRRORS the event, it never drives domain control flow):

| # | AC2 meaning | Shipped cue id | Past-tense `DomainEvent.Type` source |
|---|---|---|---|
| 1 | Movement | `sfx.move` | `ENTITY_MOVED` |
| 2 | Weapon hits | `sfx.weapon_hit` | `DAMAGE_APPLIED` |
| 3 | Enemy actions | `sfx.enemy_action` | `ENTITY_MOVED` + `DAMAGE_APPLIED` + `TILE_MARKED` (telegraph) |
| 4 | Hazards | `sfx.hazard` | `DAMAGE_APPLIED` (hazard DoT) + `TILE_MARKED` |
| 5 | Preview | `sfx.preview` | the `feedback_preview` cue (+ optional `AUDIO_FEEDBACK_PREVIEW` id) |
| 6 | Confirm (DISTINCT from preview) | `sfx.confirm` | the `feedback_committed` cue (+ optional `AUDIO_FEEDBACK_COMMITTED` id) |
| 7 | Passive pickup | `sfx.passive_pickup` | `ITEM_GAINED` + `PASSIVE_CONSUMED` |
| 8 | Consume | `sfx.consume` | `PASSIVE_CONSUMED` |
| 9 | Destroy | `sfx.destroy` | `PASSIVE_DESTROYED` |
| 10 | Curse / corruption | `sfx.curse` | `CURSE_APPLIED` |
| 11 | Door sealing | `sfx.door_seal` | `ROUTE_SEALED` (Story 4.4 — "doors seal behind the hero as a containment law"; GDD FR46) |
| 12 | Death | `sfx.death` | `RUN_COMPLETED` (outcome `failed`/`run_failed`) + `FIRST_DEATH_RECORDED` |
| 13 | Reward reveal | `sfx.reward_reveal` | `REWARD_OFFERED` + `REWARD_RESOLVED` |
| 14 | Boss victory | `sfx.boss_victory` | `BOSS_DEFEATED` + `RUN_COMPLETED` (outcome `victory`) + `FIRST_VICTORY_RECORDED` |

Every one of the 13 named AC2 meanings maps to a shipped cue id AND a past-tense domain event source. **No meaning
is missing, and no cue is invented without an event source.**

### 4.2 Audio-off equivalence — muting never removes required information (REUSED, not re-derived)

The accessibility contract GUARANTEES audio-off equivalence, and it is proven headless (this gate REFERENCES the
proof; it does NOT re-derive it or add a duplicate test):

- **Feedback cues keep a visual/textual channel regardless of audio.** `TacticalAccessibilityModel._feedback_entry`
  sets `visual_available` independent of `audio_available`; both feedback cues (`feedback_preview`,
  `feedback_committed`) carry non-color visual/textual channels, so the preview-vs-committed distinction survives
  with audio muted or absent. Proven by
  `test_tactical_accessibility_cues.gd::_audio_feedback_cues_always_have_visual_or_textual_equivalents` (which
  builds the model with `{"audio_available": false}` and asserts the muted feedback still marks `visual_available:
  true` for BOTH preview and committed, and keeps them visually distinct).
- **Only the two preview/commit cues declare an audio id, and both keep a visual channel.** `AUDIO_FEEDBACK_PREVIEW`
  / `AUDIO_FEEDBACK_COMMITTED` (`audio_feedback_preview` / `audio_feedback_committed`) are OPTIONAL parallel ids;
  the same test asserts every cue that declares an `audio_cue_id` STILL carries a non-color visual/textual channel —
  so audio NEVER carries sole meaning. The warning / damage / reward meanings (rows 2–4, 12–14) carry **no audio id
  at all** — they are visual/textual by construction.
- **The run-flow affinity/Darkness reads are non-color too.** `test_run_flow_accessibility_coverage.gd` drives the
  REAL run-flow read-model projections and asserts every emitted cue id (including the tracked Flooded
  conductive-danger PLACEHOLDER) resolves in the live catalog with a non-color channel — so the tactical danger
  reads with color AND audio stripped.

**Conclusion: no required information is audio-only.** Every AC2 feedback meaning has a visual/textual equivalent
guaranteed by the contract; the two feedback cues' optional audio ids are additive; and audio is a **0-file
placeholder track** in v0 (dispositioned `descoped` in §6.4), so there is no audio-only surface even in principle.
[Source: `accessibility-and-readability-audit.md` §7 (§7.1 the contract fact, §7.2 the 0-file track, §7.3 the
no-audio-only conclusion); `asset-manifest.md` §SFX; the two accessibility tests above.]

**AC2 verdict:** MET — all 13 required meanings mapped to a shipped cue id + a past-tense domain-event source
(§4.1); the audio-off equivalence stated with its contract backing + the two accessibility tests (§4.2); the
no-audio-only conclusion drawn.

---

## 5. AC3 — Asset metadata / provenance completeness

**GIVEN placeholder or AI-assisted assets are used, WHEN asset metadata is validated, THEN each entry records
stable id, status, tool or source, prompt if applicable, date, source reference, license/provenance notes, editable
source path, runtime export path, and approval status, AND unapproved placeholder or exploration assets cannot be
silently treated as production assets.**

### 5.1 The 10 required fields — completeness confirmation

Every placeholder / AI-assisted asset entry carries the 10 required fields, distributed across the three shipped
provenance docs (a deliberate manifest-plus-ledgers split, per the manifest's own instruction: *"Per-asset
provenance to capture at generation … append to the row or a sibling `provenance-log.md`"*):

| # | Required field | Where it lives |
|---|---|---|
| 1 | Stable id | `asset-manifest.md` — the `ID` column (e.g. `char.warrior`, `icon.passive.001`, `sfx.door_seal`) |
| 2 | Status | `asset-manifest.md` — the `Status` column (`planned`/`placeholder`/`generated`/`approved`/`descoped`/`blocking`) |
| 3 | Tool or source | `asset-manifest.md` per-section provenance (Recraft V3 Vector for icons; Gemini 3.1 Flash for board art) + `provenance-log.md` "Locked pipeline decisions" |
| 4 | Prompt (if applicable) | `prompt-pack.md` (the prompt ids + negatives) + `provenance-log.md` (the STYLE PREFIX + per-asset prompt-pack id) |
| 5 | Date | `asset-manifest.md` (icons "Generated 2026-06-21") + `provenance-log.md` ("Locked pipeline decisions (2026-06-22)") |
| 6 | Source reference | `provenance-log.md` (the per-asset Scenario `asset_*` / `job_*` ids + seeds) |
| 7 | License / provenance notes | `asset-manifest.md` ("License: Recraft Pro (commercial)") + `provenance-log.md` (the CU ledger + engine/route decisions) |
| 8 | Editable source path | `asset-manifest.md` — the `Source dir` column (`asset_sources/...`) |
| 9 | Runtime export path | `asset-manifest.md` — the `Runtime path` column (`godot/assets/...`) |
| 10 | Approval status | `asset-manifest.md` — the `Approved` column (☑ = 3-point gate passed; ☐ = pending) |

The editable-source (`asset_sources/...`) → runtime-export (`godot/assets/...`) split is recorded per asset (fields
8–9), matching the project-context Code-Organization rule (*"editable asset source files, prompts, provenance, and
reviews live in `asset_sources/`; runtime-ready art/audio live in `godot/assets/`"*). **No entry is missing a
required field** — the manifest-plus-ledgers set carries all 10 for every AI-assisted asset.

### 5.2 The status vocabulary PREVENTS silent promotion

An unapproved / exploration asset is **structurally distinguishable** from a production asset, so it cannot be
silently shipped as production:

- **Manifest statuses** `planned` → `placeholder` → `generated` → `approved` (+ `descoped` / `blocking`) are a
  monotone ladder; a `generated`-but-unchecked icon is not `approved`, and the **Approved checkbox is the 3-point
  readability-gate pass** — so a `generated` icon with ☐ cannot be silently treated as production (it has not
  cleared the gate).
- **Project-context asset statuses** `exploration` / `placeholder` / `approved_reference` / `production` /
  `deprecated` (§ Static Content & Asset Rules) require *schema + semantic + smoke-test + HUMAN APPROVAL before
  production use*, and **placeholder assets carry `_placeholder` in filenames** — the same distinct-from-final marker
  the Flooded conductive cue ids use in code (`affinity_conductive_danger_placeholder` / `..._vfx`), so a placeholder
  is legible as a placeholder at both the asset and the cue level.
- **Platform & Build rule:** *test content and experimental assets cannot ship unless explicitly approved for
  production* — AC3's "unapproved cannot be silently treated as production", applied to assets.

The current honest state: the board-art roster is `approved` ☑ (3-point gate passed); the Recraft icons
(weapons/support/passives/currency) are `generated` ☐ (approval pending on import — §6.5); the UI frames/overlays
are `planned` (assembled in-engine — §6.5); the audio track is `descoped` (§6.4). **No entry is mislabeled as
production, and none is a silent promotion.**

**AC3 verdict:** MET — all 10 required fields confirmed present across the manifest + provenance-log + prompt-pack
(§5.1); the status vocabulary + the Approved checkbox + the `_placeholder` marker prevent silent promotion (§5.2);
no metadata-field gap found (the `generated` ☐ icons are a tracked approval-pending state, not a missing field).

---

## 6. AC4 — Placeholder-disposition ledger

**GIVEN placeholder behavior exists in Story 4.5, Story 7.5, Story 8.2, or asset/audio mappings, WHEN final MVP
readiness is assessed, THEN each placeholder is replaced, explicitly de-scoped with an approved limitation, or
listed as blocking readiness, AND the readiness notes identify the affected story, player-facing risk, owner, and
target replacement path.**

**Default disposition** (per the offline-first v0 CANDIDATE scope + the 10.1/10.5/10.6 honesty posture): **`de-scoped
with an approved limitation`** for anything a headless agent cannot produce (art / audio / scene), each with its
owner + target. A placeholder is **`blocking`** ONLY if it makes the loop genuinely unplayable or hides required
gameplay communication — **none currently does** (every non-color cue channel is present; the loop is complete +
winnable per the 10.6 gate §3). A row is **`replaced`** where a later epic already superseded it.

### 6.1 Story 4.5 — `node_placeholder_resolved` / `run_completed.outcome = boss_placeholder`

| Placeholder | Disposition | Player-facing risk | Owner | Target replacement path |
|---|---|---|---|---|
| `run_completed.outcome = boss_placeholder` (the placeholder boss run-end) | **REPLACED** (Epic 9) | **None** — the real Larval Avatar boss level + first-victory reveal ship (Epic 9); the live boss fight + victory reuse the SAME `boss` route node + `run_completed` boundary. The `boss_placeholder` outcome id is RETAINED in the vocabulary by design (it is the placeholder-path marker the event validator still pins); it is not dead, it is simply not the shipped victory path. | Epic 9 (closed) | Done — `BossNodeEnterCommand` / `resolve_boss_victory` / `FirstVictoryRevealBeat` (Epic 9). |
| `node_placeholder_resolved` (shop / reforge / event / rest non-combat node offers) | **de-scoped with an approved limitation** | **LOW** — the backing DOMAIN exists and is integration-proven (Epic 6 loot/rewards, Epic 7 risk/events); only the live-node-resolution HUD wiring is caller-driven/deferred (the same present-in-domain / thin-in-live-flow status as the 10.6 gate §3.3 "collect rewards" + "make passive choices" steps). The non-combat offers do not hide gameplay communication — they are present + tested, just not yet wired into a live scene. | The reward/passive/event live-HUD-wiring story (a later HUD story) | Wire the non-combat node offers (loot / reforge / event / rest) into the live run-flow HUD/shell. |

### 6.2 Story 7.5 — the Flooded `affinity_conductive_danger_placeholder` (+ `..._vfx`) — the 10.7-OWNED marquee item (F-1)

| Placeholder | Disposition | Player-facing risk | Owner | Target replacement path |
|---|---|---|---|---|
| Flooded `affinity_conductive_danger_placeholder` (cue id) + `affinity_conductive_danger_placeholder_vfx` (visual id) + the placeholder explanation string, in `affinity_effect_resolver.gd` (`CUE_/VISUAL_/EXPLANATION_CONDUCTIVE_DANGER_PLACEHOLDER`) surfaced through `tactical_accessibility_model.gd` `_CUE_CATALOG` | **de-scoped with an approved limitation** (the default; NOT `blocking`) | **LOW** — the placeholder ALREADY carries a non-color `shape` + `label` + `text` channel with `danger` severity (`_CUE_CATALOG["affinity_conductive_danger_placeholder"]`), so the conductive danger reads with color stripped **even as a placeholder** — proven by `test_run_flow_accessibility_coverage.gd::_every_registered_affinity_and_darkness_catalog_cue_is_non_color` (which asserts `has_non_color_channel("affinity_conductive_danger_placeholder")`). It is NOT a color-only or missing-cue violation. No LIVE conductive-interaction MECHANIC exists yet — 11.4 surfaces only the deterministic MARKS (`conductive_danger_cells` / pathing cells are board/preview DATA, `is_placeholder: true`), so there is no hidden gameplay effect the placeholder conceals. | A later affinity-effects / conductive-interaction VFX story (post-MVP) | Replace the `_placeholder` cue/visual ids with FINAL ids + author the conductive water/electric art/VFX + the final explanation, WHEN the live conductive-interaction mechanic ships. (This gate does NOT rename the cue ids — that is the owning story's job; the ids stay distinct-from-final on purpose.) |

This is the ONE placeholder 10.7 explicitly OWNS the disposition for (10.6 §7.6 + §8 handed it here; the 10.5 audit
F-1 recorded it as a tracked placeholder and deferred the full treatment to 10.7). **Disposition: de-scope with an
approved limitation.** [Source: `deferred-work.md` "Flooded electric-interaction `_placeholder` (Epic-10 readiness,
10-7)"; `project-context.md` line 450; `mvp-readiness-gate.md` §7.6/§8; `accessibility-and-readability-audit.md` §5
F-1.]

### 6.3 Story 8.2 — `RunSummary` `not_yet_supported` placeholders + the F-2 blank outcome label

| Placeholder | Disposition | Player-facing risk | Owner | Target replacement path |
|---|---|---|---|---|
| `RunSummary` `not_yet_supported` fields (`echoes_discovered` / `unlock_progress` render as `0` / `[]` until a live source exists) + the F-2 blank `outcome_or_cause` label | **de-scoped with an approved limitation** | **LOW** — a readability-completeness gap, not a broken step. The run outcome IS conveyed non-color via the SEPARATE reveal beats (`FirstDeathNarrativeBeat` / `FirstVictoryRevealBeat`) + `phase` (`PHASE_COMPLETED` / `PHASE_FAILED`), never `outcome_or_cause` (which stays blank until the run-level event store lands). The summary panel is present + reachable; only the tally fields are placeholders. | The **run-level event-store / summary-render story** (origin 11.5 code review; the F-2 / T4 deferral) — NOT 10.7 | Thread a run-level event store so the summary carries real echoes / unlock / outcome; until then, a summary-render MUST key the outcome label off `phase`, not `outcome_or_cause`. |

The 8.2 ledger explicitly says these are *"TRACKED for the Epic-10 readiness pass (AC5; Story 10.7 names Story
8.2)"* — 10.7 NAMES them and records them against the run-level event-store / summary-render owner; it does not fix
them. [Source: `deferred-work.md` "dev of 8-2" (`not_yet_supported`) + the F-2 entry; `accessibility-and-readability-audit.md`
§5 F-2; `mvp-readiness-gate.md` §3.1.]

### 6.4 Asset/audio mapping — the audio track (0 files)

| Placeholder | Disposition | Player-facing risk | Owner | Target replacement path |
|---|---|---|---|---|
| The audio track — all 14 SFX (`sfx.*`) + 7 ambient loops (`amb.*`) are `planned`, **0 files on disk** (`godot/assets/audio/{sfx,ambience,music}/**` exist but hold no files) | **de-scoped with an approved limitation** (NON-GATING) | **LOW / none** — **nothing is audio-only** (§4.2; the 10.5 audio-off audit §7 confirms every AC2 feedback meaning has a visual/textual equivalent, and only the two preview/commit cues even declare an optional audio id, each keeping a visual channel). The v0 candidate ships silent; no required gameplay information is lost. | A post-MVP audio-production pass | Author + import + `approve` the 14 SFX + 7 ambient (tool TBD — ElevenLabs suggested for SFX, Suno / Stable Audio for ambient, per the manifest). This gate refines the manifest audio rows `planned → descoped` (§6.6). |

### 6.5 Asset/audio mapping — the generated-but-unapproved icons + the planned in-engine UI frames/overlays

| Placeholder | Disposition | Player-facing risk | Owner | Target replacement path |
|---|---|---|---|---|
| `generated`-but-`☐`-approved icons (weapons ×9, support ×2, passives ×28, currency ×4) | **de-scoped with an approved limitation** (present + tracked; approval pending) | **LOW** — the icons are present on disk and tracked; only the human 3-point-gate approval (eyes on a display) is deferred. Kept `generated` ☐ (NOT flipped to `descoped`) because the assets are produced and intended for v0 — the honest state is "generated, approval-pending", not "cut". | An asset-approval pass | Confirm the 3-point gate on import + check the Approved box (`generated → approved`). Verify the flagged passive picks (002 skull, 007 fang, 012 chain, **023 cracked-rune**) against `icons/_future/alternates/`. |
| `planned` in-engine UI frames (`ui.*` ×9) + engine-drawn overlays (`overlay.move_range` / `attack_range` / `blocked_line` / `fog_hidden` / `fog_memory`) | **de-scoped with an approved limitation** (assembled/drawn in-engine when the scenes are built) | **LOW** — the Recraft frame kit (`button_plate`/`panel_frame`/`modal_frame`) + the engine-drawn flat fills (NFR9) are the intended production path; the `ui.*` rows are `planned` because they are assembled in Godot (9-slice / StyleBox), not authored as flat art. No missing communication — the overlays are deterministic engine fills. | The scene stories (11.3 HUD; 11.4 visual treatment; the outpost/summary scene owners) | Assemble the `ui.*` frames in-engine from the frame kit; draw the range/fog overlays as flat Godot fills/shaders. |

### 6.6 Manifest ledger refinement (the sanctioned AC3/AC4 provenance edit)

To reflect this gate's AC4 dispositions in the ledger (not just this report), `asset_sources/asset-manifest.md` is
refined (AC3/AC4 provenance work; `asset_sources/` is NOT `godot/` production code):

- The 14 SFX rows + the 7 ambient rows: status `planned → descoped` (the manifest's own vocabulary for "approved
  MVP limitation"), with the SFX + ambient section headers annotated with the 10.7 disposition (de-scoped for v0,
  non-gating, owner = a post-MVP audio-production pass, target = author + import + approve). This is the story's
  explicit example ("mark … the 0-file audio track `descoped` with the approved-limitation note").
- A new "Story 10.7 readiness-gate dispositions (AC4)" summary section records each disposition (audio descoped;
  Flooded conductive VFX descoped; icons generated/approval-pending; UI frames planned/in-engine) with a pointer to
  this report.
- The `generated` icon rows and the `planned` UI/overlay rows are LEFT as-is (they are not descoped — §6.5); the
  Flooded conductive VFX has no manifest row (it is a code-level cue in `affinity_effect_resolver.gd`, which this
  gate does not touch), so it is dispositioned in prose (§6.2) + the new summary section.

**No binary asset is authored, moved, or re-exported; no `godot/` code is touched; the `_CUE_CATALOG` cue ids are
unchanged.**

### 6.7 Nothing is classified `blocking`

**No open placeholder is a HARD BLOCKER.** Each is either `replaced` (Story 4.5 boss), or `de-scoped with an
approved limitation` (the Story 4.5 non-combat offers, the Story 7.5 Flooded conductive placeholder, the Story 8.2
summary tallies, the audio track, the generated icons, the planned UI frames) — none makes the loop unplayable or
hides required gameplay communication (every non-color cue channel is present; the live loop is complete + winnable
per the 10.6 gate §3). Every row carries its affected story + player-facing risk + owner + target replacement path.

**AC4 verdict:** MET — every named placeholder (Story 4.5 / 7.5 / 8.2 / asset-audio) has a disposition row with the
story + risk + owner + target quartet (§6.1–§6.5); the Story-7.5 Flooded conductive placeholder is 10.7-owned and
de-scoped with an approved limitation (§6.2); none is `blocking` (§6.7); the ledger refinement records the
dispositions in the manifest (§6.6).

---

## 7. AC5 — UX-prerequisite coverage

**GIVEN UI-heavy scene production is about to begin, WHEN UX prerequisites are checked, THEN a lightweight UX
appendix or equivalent implementation notes exist for tactical HUD, preview/confirm, inspect, passive modal, run
map, outpost/meta, run summary, settings, and save/resume recovery, AND the absence of a standalone UX document
remains non-blocking only for domain-first Epic 1 work and view-model/command-bridge contracts.**

### 7.1 The 11.1 UX appendix covers every named surface

`_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (Story 11.1 — the "lightweight UX appendix" delivered
expressly to be "consumed by Story 10.7's UX prerequisite check") covers each AC5-required surface with a section
citation:

| # | AC5-required surface | Appendix section | Primary contract |
|---|---|---|---|
| 1 | Tactical HUD | **§1** | `TacticalBoardViewModel` + `TacticalLayoutProfile` |
| 2 | Preview / confirm | **§2** (§2.3 the preview-vs-committed distinction) | command bridge `move`/`attack` + `TacticalAttackCommitFlow` + preview VMs |
| 3 | Inspect | **§3** | `TacticalInspectView` + bridge `inspect` |
| 4 | Passive modal | **§4** | `PassiveRewardModalViewModel` + `PassiveRewardCommitFlow` |
| 5 | Run map | **§5** | `RouteState` / `RouteNode` (route VM gap G2 — CLOSED by 11.3's `RouteMapViewModel`, per 10.5 §4.9) |
| 6 | Outpost / meta | **§7** | `OutpostViewModel` |
| 7 | Run summary | **§8** | `RunSummary` |
| 8 | Settings | **§12** | `SettingsSnapshot` / `SettingsManager` (settings VM gap = appendix §16 G4, §7.3) |
| 9 | Save / resume recovery | **§13** | `SaveManager` → `RunResumeService` + `OutpostViewModel.recovery_state` |

Plus the appendix's bonus coverage (beyond the AC5-required nine): hero select **§6**, first-death reveal **§9**,
first-victory reveal **§10**, manual-seed no-progression warning **§11**, the global layout+accessibility pass
**§14**, the affinity read **§15**. Every AC5-required surface is covered; **no named surface is missing.**

The appendix maps every screen to the EXISTING view-model / command-bridge contracts WITHOUT inventing a domain
surface — the one architectural rule it obeys (§0.3): *"UI observes domain state through view models / read
surfaces, and submits player intent through the command bridge; scenes, `Control` nodes, audio, VFX, and animation
are presentation — they own no tactical truth."* Every binding is a `RefCounted` DTO / read surface, fail-closed
(`has_*` gates), pinned-key.

### 7.2 The non-blocking caveat

The AC5 caveat — *"the absence of a standalone UX document remains non-blocking only for domain-first Epic 1 work
and view-model/command-bridge contracts"* — is SATISFIED: the appendix now exists and binds every surface to the
existing contracts (§0.3), so the caveat is moot for the scene stories. The caveat only ever excused the
domain-first Epic-1 phase (build the domain model + the command/event/RNG/board contracts before a standalone UX
doc); it never excused shipping UI-heavy scenes with no UX notes — and the appendix is exactly those notes.

### 7.3 The appendix's own Contract Gaps (recorded against owners — 10.7 does NOT resolve them)

The appendix §16 Contract Gaps are recorded against their owners (this gate records; it does not build the scenes or
resolve the gaps):

| Gap | What it is | Owning story | 10.7 posture |
|---|---|---|---|
| **G1** | In-run HUD run context (hero HP, node progress, gold, inventory/passive access not aggregated on `TacticalBoardViewModel`) | **11.3** | RECORD; the fields are named in §16 G1. Not this gate's fix. |
| **G2** | Route/run-map view model | 11.3 | **CLOSED** — 11.3's `RouteMapViewModel` projects the route reads (10.5 §4.9); recorded as closed, not open. |
| **G3** | "Oath Shards earned" summary↔profile display coupling (`oath_shards_earned` stays `0`/`not_yet_supported`; awarded total lives on `profile.oath_shards`) | **11.5** | RECORD; overlaps the Story-8.2 summary tally (§6.3). Not this gate's fix. |
| **appendix §16 G4 (settings)** | The settings VIEW model / settings SCENE gap — PARKED; no settings scene, the outpost has no difficulty selector (= finding F-3) | settings-scene owner (**11.3/11.5** per the eventual scene split) | RECORD; the human-eyes settings-scene readability stays a paper audit (AG-3, §8). Kept DISTINCT from the device-tiers §6 G4 (FPS profiler). |

**Difficulty non-goal confirmed at the settings surface.** The appendix §12.3 states the negative readiness
criterion — *"The settings screen MUST NOT present a difficulty selector"* — and it is regression-enforced at the
contract level (`SettingsSnapshot.PREFERENCE_KEYS` has no difficulty key; `test_settings_snapshot.gd::_difficulty_non_goal_keys_are_absent`
drops an injected `difficulty_tier`/`enemy_scaling`). This gate CONFIRMS the non-goal; it never proposes adding a
difficulty knob.

**AC5 verdict:** MET — the appendix covers every AC5-required surface with a section citation (§7.1); the
non-blocking caveat is satisfied + stated (§7.2); the appendix's Contract Gaps (G1 → 11.3, G3 → 11.5, appendix §16
G4 settings → settings-scene owner; G2 closed) are recorded against their owners without resolving them (§7.3); the
two "G4"s are kept distinct.

---

## 8. Availability-gaps ledger (the honest-scope rest)

Every dimension this headless gate cannot discharge now, named against the AC it affects and its owning follow-up.
Each is an acceptable documented readiness limitation for the offline-first **v0 candidate** — a **pre-ship
follow-up**, not a hard blocker. (These are the human-eyes / produced-asset / built-scene residue; the
contract-level checks are all verified in §3–§7.)

| Gap | What is missing | AC affected | Disposition | Owning follow-up |
|---|---|---|---|---|
| **AG-1** | A human-eyes readability confirmation on a physical display (real grayscale legibility + phone-size silhouette read on hardware). The 3-point gate on the board art + the non-color cue channels are verified; the felt on-device read is not. | AC1 | Acceptable documented limitation | The **10.6 physical-device pass owner** (intersects the 10.5 ASG-1/ASG-2 + the device-tiers G1–G7 set) |
| **AG-2** | A produced audio track (14 SFX + 7 ambient; 0 files today). Non-gating — nothing is audio-only (§4.2). | AC2 / AC4 | Acceptable documented limitation (de-scoped, §6.4) | A **post-MVP audio-production pass** (author + import + approve) |
| **AG-3** | The settings-SCENE human-eyes accessibility audit (appendix §16 G4 / F-3 — a paper audit until the scene + optional VM are built; the difficulty non-goal is confirmed at the contract level, regression-enforced, so nothing gameplay-bearing depends on the scene). | AC5 | Acceptable documented limitation | The **settings-scene owner (11.3/11.5)** |
| **AG-4** | The live conductive-interaction art/VFX + final (non-placeholder) cue for Flooded/Conductive (F-1). The placeholder already reads non-color; no live mechanic exists yet. | AC4 | Acceptable documented limitation (de-scoped, §6.2) | A **later affinity-effects / conductive-interaction VFX story** (post-MVP) |

**Verified now in this gate (NOT gaps):** the required-class → tracked-or-better id map (§3.1), the 3-point
readability gate on the board art + the non-color cue channels (§3.2), the 13-meaning cue map + the audio-off
equivalence (§4, the two accessibility tests), the 10-field provenance completeness + the no-silent-promotion
guarantee (§5), the disposition of every open placeholder (§6), and the UX-appendix coverage of every surface (§7).

---

## 9. Overall verdict, suite check, and the Epic-10 close

### 9.1 Overall asset/audio/placeholder/UX readiness verdict: `READY_WITH_GATES`

The MVP is **READY WITH DOCUMENTED GATES** for the offline-first v0 candidate on the asset/audio/placeholder/UX
axis:

- ✅ **AC1** — the visual roster is present + readability-gated (every required class → a tracked-or-better id; the
  board art passed the 3-point gate; the cue channels are non-color),
- ✅ **AC2** — the cue map is complete (all 13 meanings → a shipped cue id + a past-tense domain event) + audio-off
  equivalent (no required info is audio-only),
- ✅ **AC3** — the provenance is tracked (all 10 fields) + the status vocabulary prevents silent promotion,
- ✅ **AC4** — every open placeholder is dispositioned with an owner + target (none `blocking`),
- ✅ **AC5** — the UX appendix covers every named surface + binds to the existing contracts,

with the **audio track (AG-2) + the Flooded conductive art/VFX (AG-4) + the human-eyes physical-display readability
confirmation (AG-1) + the settings-scene human-eyes audit (AG-3)** as recorded pre-ship follow-ups. This is
consistent with the existing `sprint-status.yaml` `readiness_status: READY_WITH_GATES` — the verdict IS "ready with
documented gates", so it is left as-is (NOT silently flipped).

### 9.2 The full-suite check (read from the raw runner output — not fabricated)

Run fresh for this gate via PowerShell (`godot --headless --path C:\Sealsworn\godot --scene
res://tests/headless/test_runner.tscn --quit-after 10`):

| Metric | Result |
|---|---|
| **PASS count** (`^PASS`) | **191** |
| **FAIL count** (`^FAIL`) | **0** |
| **Runner exit / final line** | exit 0; `Headless tests passed.` |
| **False-PASS grep guard** (`SCRIPT ERROR` / `Parse Error` / `^FAIL`) | **0 matches — clean** |

The **191 PASS / 0 `^FAIL`** count matches the post-10.6 baseline exactly, confirming this gate changed the suite by
nothing (no test added, no pin moved). The 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3,
`invalid_node_type` ×1) are the expected deliberate fail-path assertions — unchanged, NOT regressions. **No new test
is added:** AC2's audio-off equivalence + the run-flow cue-coverage FACT are already asserted by
`test_run_flow_accessibility_coverage.gd` + `test_tactical_accessibility_cues.gd` (the 10.5 / 2.6 tests); adding a
duplicate would violate the story's "do not duplicate an existing assertion" rule (the 10.6 precedent, which also
added none).

### 9.3 The Epic-10 close

**10.7 is the LAST story of Epic 10 in EXECUTION order** (`10-1 → 10-2 → 10-3 → 10-8 → 12-1 → 12-2 → 10-4 → 10-5 →
10-6 → 10-7`; 10-8 is numbered last for list continuity but ran early after 10-3). After 10.7 reaches `done`, the
**Epic-10 retrospective + the `epic-10: in-progress → done` transition** follow (orchestrator / Phase-8-owned) —
this gate performs NO epic-status change (`epic-10` stays `in-progress`). Cross-references: the sibling gate 10.6
handed 10.7 this pass (`mvp-readiness-gate.md` §7.6 + §8 + §10); the 10.5 accessibility audit + the 11.1 UX appendix
are the two inputs consumed (§4 / §7); the `asset-manifest.md` + `provenance-log.md` + `prompt-pack.md` are the
asset/provenance backbone (§3 / §5).

---

## 10. Determinism / no-touch invariants respected

This gate/roll-up story moves NONE of the pinned invariants — it VERIFIES / DISPOSITIONS / ROLLS UP: the 7 named RNG
streams (`map` / `level` / `combat` / `loot` / `rewards` / `events` / `cosmetic`), zero new RNG draw sites, the
23-key `RunSnapshot` gate, `ProfileSnapshot` / `SettingsSnapshot` `SCHEMA_VERSION == 1`, every generator / route /
finale fingerprint SOURCE + its pinned values, every seed-regression sample, the `_CUE_CATALOG` cue ids (the Flooded
`_placeholder` ids stay distinct-from-final), and the default deterministic paths stay byte-identical. This gate
changed NO production `godot/` gameplay / save / RNG / content / generator / view-model / presenter / scene path, NO
`.tscn`, and NO `export_presets.cfg` preset; it added NO test; it authored / moved / re-exported NO binary asset.
The one sanctioned ledger edit is `asset_sources/asset-manifest.md` (the AC3/AC4 provenance dispositions, §6.6) — not
`godot/` production code. The full headless suite stays green + byte-for-byte unchanged (191 PASS → 191 PASS).

---

## 11. References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 10 §"Story 10.7: Asset, Audio,
  Placeholder, and UX Readiness Gate" (lines ~2578–2611). FR-map: "GDD FR46: door sealing/containment-law feedback →
  Story 4.4 and Story 10.7"; "GDD FR112/FR113/FR114: MVP visual/audio baseline and preview/commit cue mapping →
  Story 10.7"; "Placeholder replacement/de-scope checkpoints → Stories 4.5, 7.5, 8.2, and 10.7". NFR17/NFR18 (asset
  provenance/tracking + non-MVP spare tracking).
- **The SHIPPED asset/provenance ledger (AC1/AC3 backbone — VERIFIED, not rebuilt):** `asset_sources/asset-manifest.md`
  (the inventory + id/status/source/runtime/approval columns + the §SFX cue map + the 3-point readability gate + the
  Scenario board-art gate/export note), `asset_sources/provenance-log.md` (the tool/model/seed/date/license CU
  ledger), `asset_sources/prompt-pack.md` (prompts + negatives), `asset_sources/style-bible.md`,
  `asset_sources/scenario-workflow.md`, `asset_sources/icons/_future/UNUSED-ASSETS.md` (NFR18 spares).
- **The audio-off + cue-coverage evidence (AC2 — verified, NOT duplicated):**
  `_bmad-output/planning-artifacts/accessibility-and-readability-audit.md` §7 (audio-off equivalence; §7.2 the
  0-file placeholder-track fact), §4.6/§5 F-1 (the tracked Flooded conductive placeholder → 10.7), §8/§10 (the
  cue-coverage test + the 10.7 handoff); `godot/tests/unit/ui/test_run_flow_accessibility_coverage.gd`
  (`_every_registered_affinity_and_darkness_catalog_cue_is_non_color`);
  `godot/tests/unit/ui/test_tactical_accessibility_cues.gd`
  (`_audio_feedback_cues_always_have_visual_or_textual_equivalents`).
- **The domain-event vocabulary (AC2 event sources):** `godot/scripts/core/events/domain_event.gd` — `ENTITY_MOVED`
  / `DAMAGE_APPLIED` / `TILE_MARKED` / `ROUTE_SEALED` / `NODE_PLACEHOLDER_RESOLVED` / `RUN_COMPLETED` /
  `PASSIVE_CONSUMED` / `PASSIVE_DESTROYED` / `ITEM_GAINED` / `REWARD_OFFERED` / `REWARD_RESOLVED` / `CURSE_APPLIED` /
  `FIRST_DEATH_RECORDED` / `FIRST_VICTORY_RECORDED` / `BOSS_DEFEATED`.
- **The placeholder cue-catalog source (AC4 F-1):** `godot/scripts/ui/view_models/tactical_accessibility_model.gd`
  (`_CUE_CATALOG` — the FINAL cues + the distinct Flooded `affinity_conductive_danger_placeholder`),
  `godot/scripts/rules/operations/affinity_effect_resolver.gd` (`CUE_/VISUAL_/EXPLANATION_CONDUCTIVE_DANGER_PLACEHOLDER`
  + `is_placeholder: true` on the conductive cue).
- **The UX appendix (AC5 backbone):** `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` §0.3 (the one
  architectural rule), §0.7 (the screen roster), §1 HUD / §2 preview-confirm / §3 inspect / §4 passive modal / §5
  run map / §7 outpost / §8 run summary / §12 settings / §13 save-resume, §16 (Contract Gaps — G1/G2/G3/appendix §16
  G4 settings VM), §12.3 (difficulty non-goal).
- **The handoff source (10.6) + the sibling precedents:** `_bmad-output/planning-artifacts/mvp-readiness-gate.md`
  §7.6 (rolls placeholder/asset/audio up + HANDS 10.7 the Flooded `_placeholder` + the 0-file audio track), §8 (the
  gap-ledger rows naming 10.7 owner), §10 (`READY_WITH_GATES`); the structural twins
  `10-5-accessibility-and-readability-audit.md` + `10-6-mvp-readiness-gate-and-playable-build-preservation.md`.
- **Deferred-work ledger (overlapping items dispositioned above, not reopened):**
  `_bmad-output/implementation-artifacts/deferred-work.md` — the Flooded `_placeholder` (F-1 → 10.7 owns); the
  0-file audio track (→ 10.7); the Story-8.2 `not_yet_supported` placeholders ("Story 10.7 names Story 8.2"); the
  F-2 thin-summary label (→ run-level event-store/summary-render owner); F-3 settings paper-audit (→ settings-scene
  owner); the Story-4.5 `node_placeholder_resolved`/`boss_placeholder` checkpoint (boss REPLACED by Epic 9).
- **Epic-10 retro (constraints folded):** `_bmad-output/auto-gds/retro-notes/epic-10.md` — §10-6 Phase-3 (the two-G4
  ambiguity persists into 10.7), §10-8 Phase-0 (10-7 is the real Epic-10 close), §10-2 (the sanctioned edits
  override the touch-nothing reflex), §10-1 (iOS/G7 is 10.6-owned, not asset content).
- **Project rules:** `CLAUDE.md` / `AGENTS.md` / `project-context.md` (§ Static Content & Asset Rules — the 10
  provenance fields + the asset statuses + the never-call-AI-for-runtime-content rule; § Code Organization — the
  `asset_sources/` ↔ `godot/assets/` split; § Presentation/View-Model/Accessibility line 450 — the Flooded
  `_placeholder`; § Settings Rules — the difficulty non-goal; § Testing Rules — human playtests required + the
  PowerShell/false-PASS-guard runner note). `sprint-status.yaml` (`readiness_status: READY_WITH_GATES`; `epic-10`
  in-progress; 10-7 the execution-order tail).

---

## 12. Change Log

| Date | Version | Change | Author |
|---|---|---|---|
| 2026-07-12 | 1.0 | Initial authoring — the dedicated Epic-10 Asset/Audio/Placeholder/UX readiness gate (the pass 10.6 §7.6 handed here). AC1 required-class → tracked-or-better id map (visual roster `approved`/`generated`; audio `planned`→descoped) + the 3-point readability basis + the AG-1 human-eyes gap. AC2 the 13-meaning cue map (each → a shipped `sfx.*` id + a past-tense `DomainEvent.Type`) + the audio-off equivalence (no required info is audio-only; the two accessibility tests referenced, not duplicated). AC3 the 10-field provenance completeness (manifest + provenance-log + prompt-pack) + the no-silent-promotion guarantee (status vocabulary + Approved checkbox + `_placeholder` marker). AC4 the placeholder-disposition ledger — Story 4.5 (boss REPLACED by Epic 9; non-combat offers de-scoped), Story 7.5 the 10.7-OWNED Flooded `affinity_conductive_danger_placeholder` (+ `..._vfx`) de-scoped with an approved limitation (non-color channel present; NOT blocking), Story 8.2 `not_yet_supported`/F-2 de-scoped (run-level event-store owner), the audio track de-scoped (non-gating), the generated icons + planned UI frames — none `blocking`; the manifest disposition refinement (§6.6). AC5 the 11.1 UX-appendix coverage of every named surface + the non-blocking caveat + the §16 Contract Gaps recorded against owners (G1→11.3, G2 closed, G3→11.5, appendix §16 G4 settings→settings-scene owner) kept distinct from device-tiers §6 G4. The availability-gaps ledger (AG-1..AG-4). Overall verdict `READY_WITH_GATES`; the suite stays 191 PASS / 0 `^FAIL` (no test added); 10.7 noted as the Epic-10 close (retro + epic-done transition orchestrator-owned). VERIFIES + DISPOSITIONS + ROLLS UP; authors no art/audio, builds no scene, fixes no deferral, changes no production `godot/` code. Discharges FR46 + FR112/FR113/FR114 + NFR17/NFR18. | Story 10.7 (dev agent, Opus 4.8) |
