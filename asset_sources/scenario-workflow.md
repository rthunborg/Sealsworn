# Sealsworn — Scenario.gg Workflow (board / world art)

Step-by-step process for the **board/world** assets (characters, enemies, boss, tiles, affinities). Style spec: [`style-bible.md`](style-bible.md). Actual prompts: [`prompt-pack.md`](prompt-pack.md) §A. Targets/IDs: [`asset-manifest.md`](asset-manifest.md).

> Exact Scenario UI labels may differ; we'll adjust as we did with Recraft. The *method* below is what matters.

## How Scenario differs from Recraft (mindset shift)
| | Recraft (icons) | Scenario (board art) |
|---|---|---|
| Output | Vector SVG | **Raster PNG + transparency** |
| Consistency | one-image style / preset | a **trained custom generator** (15–30 refs) |
| Pose/scale | n/a | **ControlNet** holds front-facing billboard + scale |
| Background | flat plate | **must be removed** (transparent for the board) |

**Key carry-over lesson:** a trained generator works *here* (characters/enemies/tiles are a cohesive family) — unlike the diverse glyphs, where it failed. So Scenario is the *right* place to train a style.

## Which Scenario tool for what
- **Create → Images** — the main generator for characters, enemies, boss, and props. You pick the base model here. ControlNet / reference controls live inside this tool.
- **Generate → Textures** — makes *seamless materials* → use this for **floor / wall tiles** (tileable), not the Images tool.
- **Models** (top nav) — browse/choose a base model; your trained model will live here later.
- **Tools → Train** — train `sealsworn-darkfantasy-v0` (Phase 2).
- **Edit → Remove Background** — transparent cutouts (Phase 4).
- **Edit → Enhance** — upscale (Phase 4).

## Asset order (unblock order)
Enemies (3) + hero silhouettes (3) → Labyrinth tiles/props (~9) → locked classes (2) → affinity treatments (4) → **boss last** (Epic 9).

## Phase 1 — North-star set (cheap, base model)

> **"North-star anchors"** = our term (not Scenario's) for the first 2–3 images we get *looking right*. They set the visual target for the whole set and become the references we train the model on. Nail these and the rest follows.

1. Open **Create → Images** and pick a **stylized dark-fantasy / painterly RPG base model** via the model selector (not photoreal, not anime, not pixel-art).
2. Generate ~20 candidates of just **3 anchors** — Warrior, Iron Cultist, and a floor+wall tile — using the Scenario STYLE PREFIX (prompt-pack §A) which already encodes the **Shattered Pixel Dungeon billboard look**: square grid, ~30° top-down floor, front-facing upright sprite, rim-lit, key light upper-left, dark stone palette + warm accents, plain dark background for clean cutout.
3. **Curate 15–30** images that genuinely share the look. This is your training set — quality of this set = quality of everything downstream.

## Phase 2 — Train the custom generator
4. Train a custom model named **`sealsworn-darkfantasy-v0`** on the curated set.
5. Save the STYLE PREFIX as the default prompt; set resolution **1024×1024**.

## Phase 3 — Generate the roster
6. Switch to `sealsworn-darkfantasy-v0`. Per asset: **STYLE PREFIX + subject line** from prompt-pack §A, Count 4, pick best.
7. **ControlNet for consistency:** make ONE reference pose/silhouette (a front-facing standing figure) and reuse it as the structure/pose reference for *all* characters and enemies — this is what keeps stance, facing, and scale uniform across the cast.
8. Generate every character/enemy on a **plain neutral background** for a clean cutout.

## Phase 4 — Post-process (per asset)
9. **Remove background** (Scenario's background-removal tool) → transparent PNG.
10. **Upscale** the approved ones → **downscale** to target px: tiles **256×256**, standard characters/enemies **256×384** (bottom-center anchor), boss up to **512×512**.
11. Export PNG → `asset_sources/<category>/` and the runtime mirror `godot/assets/<category>/`.

## Phase 5 — Gate + manifest
12. Run the 3-point readability gate (grayscale / phone-size / silhouette) **plus the distinctiveness check**: Iron Cultist vs Gate Brute vs Ash Seer must be tell-apart-able from silhouette alone (it's a tactical-clarity requirement, not polish).
13. Flip the matching manifest rows → `generated`, log provenance (tool/model/seed/date/license).

## Tiles & affinities — specifics
- Tiles are **top-down textures**, square, ideally **seamless/tileable** (floor, wall, rubble/blocker, entrance, exit, door + sealed-door, hazard, reward) — generate as flat top-down, not in perspective.
- Affinity treatments (Scorched/Flooded/Cursed/Darkness) are best as **overlay/recolor layers** over the base tiles, each with its required non-color cue (NFR9), not separate full tilesets.

## Cadence (same as Recraft)
- **Placeholder pass first** on cheap settings to prove the look, **production upscale only after** the style is locked.
- The manifest is the source of truth; update as you go.
- Lock seeds once a look is approved.
