# Sealsworn — Scenario Board-Art Provenance Log

Generation record for the Scenario.gg board/world art (companion to [`asset-manifest.md`](asset-manifest.md)).
Captures tool/model/seed/prompt/asset-ids so any asset can be reproduced or traced. Approval = 3-point readability gate ([`style-bible.md`](style-bible.md) §5).

## Locked pipeline decisions (2026-06-22)

- **Engine:** `model_google-gemini-3-1-flash` ("Gemini 3.1 Flash") on Scenario. Chosen via a 4-way Warrior bake-off (see below) for best match to the SPD billboard brief + clean near-black background + cost balance (~12 CU/img @ 1K).
- **Route:** **No custom LoRA** — prompt + seed, frontier engine. Consistency comes from the shared STYLE PREFIX (and reference-image conditioning if any asset drifts). Decided after anchors proved the look is reproducible without training. Fallback: train a Z-Image/Flux.2 LoRA on this curated set if drift appears.
- **Resolution:** generate @ **1K**, downscale on export, **no upscaling** (per style-bible §2). Characters `aspectRatio 2:3`, tiles `1:1`.
- **Team/project:** `team_EBxPGFkaK4Ye7raqEfT8RoaD` / `proj_WfiBG24wwGjUKAz3qiNYxXZr`.
- **Gemini note:** no negative-prompt field — all "avoid" terms folded into the positive prompt. Batch **seed IS recorded** (reproducible). Per-asset cost @ 1K, 2 outputs = 24 CU.

### STYLE PREFIX (character billboards, no baked base)
> dark medieval fantasy, stylized painterly 2.5D game art, grim cosmic-horror undercurrent, single front-facing full-body character, head-to-toe with both feet visible, upright standing pose viewed from a high ~30 degree top-down angle, strong readable silhouette, rim-lit to separate from the background, key light from upper-left, low-key moody lighting, cold desaturated stone palette with warm candlelight accents, stylized not photoreal, clean readable shapes for a small mobile screen, centered subject, isolated on a plain flat dark neutral background. NO pedestal, NO plinth, NO base, NO platform, NO stone slab or tile under the feet, NO diorama, no groundplane, no cast shadow, single character only, no text, no watermark, no UI. Subject: <per-asset line>

> **Lesson:** the first anchor pass said "standing on a tile" → the model baked a stone plinth under the figure, which would travel with the transparent cutout and double-up on the real floor tile. Fixed by the explicit NO-base clause above. Tiles are generated separately as flat top-down textures.

## CU ledger (running)

| Batch | CU | Cumulative |
|---|---|---|
| Warrior bake-off (4 models, superseded) | 105 | 105 |
| Anchors v2 (Warrior, Iron Cultist, floor+wall tile) | 72 | 177 |
| Roster pass 1 (Gate Brute, Ash Seer, Pyromancer, Ranger) | 96 | 273 |

Start balance 5000 → **~4727 remaining**.

## North-star anchors (selected)

| Asset | Prompt-pack id | Seed | Selected asset | Alt | Status |
|---|---|---|---|---|---|
| Warrior | `char.warrior` | 895306129 | `asset_tmCbHVJgiyGpfFVr5pFuQCdz` | `asset_A72c7haiBJ1wyja84staSu8L` | candidate ✔ recommended |
| Iron Cultist | `enemy.iron_cultist` | 1781317260 | `asset_DcGJMuUhipPAhcZJtvcbNiom` | `asset_sQkAFYUXb49Q5u6KKXyxGewM` | candidate ✔ recommended |
| Floor+wall tile | `tile.floor`/`tile.wall` | 676067521 | `asset_YzVjAm4xhR4iHvCAWEztggZw` | `asset_cv8mBSYiLFYS61yskv3eco5Q` | candidate ✔ recommended (re-do flat-lit + seamless for production) |

## Roster pass 1

| Asset | Prompt-pack id | Job (for seed) | Selected asset | Alt | Status |
|---|---|---|---|---|---|
| Gate Brute | `enemy.gate_brute` | `job_Y24mmS34yjmoFTNaKGDKdQjw` | `asset_PhSJDzzWyRR1fcGtnnNoopj8` | `asset_Q6DuM8NnRYQr6NBU9Y59U4Up` | candidate ✔ recommended |
| Ash Seer | `enemy.ash_seer` | `job_63qNXEyyEdRjU2qXh9hPABEn` | `asset_VCQmzMQTieqKyrmsiWe2eFHy` | `asset_utSdb8RwWvisN4sYrPuMmX4u` | candidate ✔ recommended |
| Pyromancer | `char.pyromancer` | `job_jDuf9US9aV2xVvbk1yV98Cy3` | `asset_22PCYrpjoNStsZxH1qhZq2nE` | `asset_5dSUiCATxvi9B6TM6TVFopvm` | candidate ✔ recommended |
| Ranger | `char.ranger` | `job_b3Ub7UpFp9SuxyzGVTwoKJ54` | `asset_3ZNTFzjra2T9x3xyp5R7J7Ct` | `asset_q7TJ23upMXg3Rw5eFv1amaoo` | candidate ✔ recommended |

## Locked classes (sealed/desaturated grey + faint teal seal)

| Asset | Prompt-pack id | Job | Selected source | Alt | Status |
|---|---|---|---|---|---|
| Necromancer (sealed) | `char.necromancer_locked` | `job_Vgnynb4bwGjusBkBLyMro6de` | `asset_3h5fBwedLVpLTzTXvZLuuGCG` | `asset_hTicRUcieEnd64NF4EBhoLpo` | generated |
| Shadeblade (sealed) | `char.shadeblade_locked` | `job_tW4TNQF27tT24CRj2QJsNqKL` | `asset_VYDQiBT44rZWJeewNBgbckzm` | `asset_oMo3CNd4KHmC4Xo1GfQ9gXm5` | generated |

## Tiles (top-down, 1:1)

| Asset | Prompt-pack id | Selected source | Status |
|---|---|---|---|
| Floor | `tile.floor` | `asset_f6dPrUpt9Fpk24gPH7J3JfQ3` | generated (flat-lit, near-seamless) |
| Wall | `tile.wall` | `asset_tVjSkPMMaBRomqZtyc6J8DsR` | generated |
| Blocker | `tile.blocker` | `asset_nneQYDJz9Pmp2Eo1AqruhbFf` | generated |
| Entrance | `tile.entrance` | `asset_sZt8UcYKu5RRhkq2mm8pc27m` | generated (v2 top-down; v1 `asset_eEA9oAHTH8xQVLwnrZR9agC7` was perspective) |
| Exit | `tile.exit` | `asset_cfbqSigRBWtM9oBZEEay8wvA` | generated |
| Door | `tile.door` | `asset_QeFtysZ7LaPy7Wbgi6dgFhrq` | generated (v2 top-down; v1 front-facing alt `asset_HCatCygEYzqLLKUtxcG4MoH3`) |
| Door (sealed) | `tile.door_sealed` | `asset_cbVNasSs1s8r79RJ3wFEFDit` | generated (v2 top-down; v1 front-facing alt `asset_oqLh7sBnrAgLDgW4JGVADRQM` — gorgeous, kept as billboard option) |
| Hazard | `tile.hazard` | `asset_werLBTDTPsG2HKVKCiUZZkfv` | generated (skull+ember = non-color danger cue) |
| Reward | `tile.reward_object` | `asset_LPmf22zXTRqsfEpeQUs44cR5` | generated |

## Affinity treatments (full-tile floor variants — overlay extraction deferred to engine)

| Asset | Prompt-pack id | Selected source | Non-color cue (NFR9) | Status |
|---|---|---|---|---|
| Scorched | `affinity.scorched` | `asset_4rZtQFsLR8SQ4VU8sFWhGwPX` | cracked glowing-ember pattern | generated |
| Flooded | `affinity.flooded` | `asset_rheTUmB5LBq23ik7VD9p3Nuu` | wet sheen + spark arcs | generated |
| Cursed | `affinity.cursed` | `asset_pqXbmNa3XZ7rh3yUvYL8Ao7B` | creeping rot veins | generated |
| Darkness | `affinity.darkness` | `asset_taxsxNWiM6FLukiPeGhRanAz` | vignette + visibility fade | generated |

## Boss

| Asset | Prompt-pack id | Job | Selected source | Alts | Status |
|---|---|---|---|---|---|
| Larval Avatar | `boss.larval_avatar` | `job_xB1tfp46bz2ajmRairBr8zJX` | `asset_awu5QkXGoN3uhcA3ZRBWzouu` | `asset_GHjDdjkXP2iQZ1zkkdCrHr5S`, `asset_kdUxpTypLaCBU6XXTsZmmnXW` (max-spectacle) | generated |

## Background-removal cutouts (Bria Remove Background, 3 CU each) + local export

Transparent PNGs exported to `asset_sources/`. Tiles/affinities are full-bleed (no cutout).

| Prompt-pack id | Source asset | Cutout asset (transparent) | Local path |
|---|---|---|---|
| `char.warrior` | `asset_tmCbHVJgiyGpfFVr5pFuQCdz` | `asset_Gm2Z94JQXRu7knAFa18qP121` | `asset_sources/characters/char.warrior.png` |
| `char.pyromancer` | `asset_22PCYrpjoNStsZxH1qhZq2nE` | `asset_4QQ8piYNww5fyYwffqt92yLL` | `asset_sources/characters/char.pyromancer.png` |
| `char.ranger` | `asset_3ZNTFzjra2T9x3xyp5R7J7Ct` | `asset_H192sEH5QYg4eYbUUfrGkimX` | `asset_sources/characters/char.ranger.png` |
| `char.necromancer_locked` | `asset_3h5fBwedLVpLTzTXvZLuuGCG` | `asset_tTsJaUtDkiZfoLEvrGZwGpvM` | `asset_sources/characters/char.necromancer_locked.png` |
| `char.shadeblade_locked` | `asset_VYDQiBT44rZWJeewNBgbckzm` | `asset_EK4EHFSp6eJU5mKFjxNkTGKt` | `asset_sources/characters/char.shadeblade_locked.png` |
| `enemy.iron_cultist` | `asset_DcGJMuUhipPAhcZJtvcbNiom` | `asset_3h8UMLsUPXMYWzmDATaykyhU` | `asset_sources/enemies/enemy.iron_cultist.png` |
| `enemy.gate_brute` | `asset_PhSJDzzWyRR1fcGtnnNoopj8` | `asset_HKPYpMifK1C2GxtP79mkdU6W` | `asset_sources/enemies/enemy.gate_brute.png` |
| `enemy.ash_seer` | `asset_VCQmzMQTieqKyrmsiWe2eFHy` | `asset_hhgyy5PbTd92UhFRpoSkadDw` | `asset_sources/enemies/enemy.ash_seer.png` |
| `boss.larval_avatar` | `asset_awu5QkXGoN3uhcA3ZRBWzouu` | `asset_HDp8xEqoeH4tBHJSEMMDbcYo` | `asset_sources/boss/boss.larval_avatar.png` |

## CU ledger (final, this session)

| Batch | CU | Cumulative |
|---|---|---|
| Warrior bake-off (4 models, superseded) | 105 | 105 |
| Anchors v2 (Warrior, Iron Cultist, floor+wall tile) | 72 | 177 |
| Roster pass 1 (Gate Brute, Ash Seer, Pyromancer, Ranger) | 96 | 273 |
| Locked classes (Necromancer, Shadeblade) | 48 | 321 |
| Tiles ×9 | 108 | 429 |
| Tile fixes ×3 + affinities ×4 + boss ×3 | 120 | 549 |
| Cutouts ×9 (Bria, 3 CU each) | 27 | 576 |

Start balance 5000 → **~4424 remaining** (well under the ~1800 session cap). No upscaling used (generate @1K, downscale on export per style-bible).

## Open follow-ups (for approval pass)

- Run the 3-point readability gate (grayscale / phone-size / silhouette) on each at true display px; flip `Approved` boxes + status→`approved`.
- Downscale + mirror to `godot/assets/...` runtime paths (tiles 256², characters 256×384, boss ≤512) — deferred until approved.
- Tiles `floor`/`wall` are near-seamless, not verified tiling; affinity tiles are full variants, not extracted overlays. Prop tiles (blocker/door/reward) are full tiles, not transparent props — revisit if the board renderer wants layered props.
- `char.warrior` alt `asset_A72c7haiBJ1wyja84staSu8L` had a stray second sword (rejected).

## Gate + runtime export + props (2026-06-22, pass 2)

- **3-point readability gate: PASS** for all 22 (grayscale / phone-size / silhouette via `asset_sources/_tools/process_board_art.py`). Manifest flipped to `approved`. Notes: robed-caster trio (pyro/necro/ash_seer) share a silhouette family but separate by arm-pose + color; `entrance`≈`exit` at tiny grayscale; floor/wall not edge-seamless.
- **Runtime mirror** exported to `godot/assets/` (downscaled from 1K masters, no upscaling): chars/enemies 256×384, boss 512², tiles+aff 256².
- **Transparent props** (Bria, +12 CU) for placeable objects: `reward_object` `asset_BGXo6tiK16WPbZaBTisRm62D`, `door` `asset_V278J6ExrEQj7dq4hzMXjLEN`, `door_sealed` `asset_9yAjVtqMuHRv9K5Pn4Rcnmmc` → `godot/assets/tiles/props/`. Blocker prop `asset_TtD9r2y9HVPxQe4yDepHft8a` rejected (rubble fills tile, no bg removed).
- **CU:** 576 → **588** (prop cuts). ~**4412 remaining**.
- **Deferred (engine-time):** seamless tiling (variants/edge-blend), affinity overlays as in-engine recolor/shader, entrance/exit up-down cue.
