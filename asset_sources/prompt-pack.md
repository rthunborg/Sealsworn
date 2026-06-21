# Sealsworn — Prompt Pack (v0)

Copy-paste prompt templates for **Scenario.gg** (board/world art) and **Recraft** (UI/symbolic art).
Constraints derive from [`style-bible.md`](style-bible.md). IDs match [`asset-manifest.md`](asset-manifest.md).

How to use: paste the **STYLE PREFIX** for the tool, append the per-asset line, and apply the shared **NEGATIVE**. Lock seeds once a look is approved so you can reproduce/iterate.

---

## A. SCENARIO.GG — board / world art

**STYLE PREFIX (paste before every prompt):**
> dark medieval fantasy, stylized painterly 2.5D, grim cosmic-horror undercurrent, square orthographic grid game, high top-down camera ~30°, single front-facing character billboard, strong readable silhouette, rim-lit to separate from dark background, key light upper-left, low-key moody lighting, cold desaturated stone palette with warm candlelight accents, clean edges, mobile-readable, centered subject, plain dark neutral background for clean cutout, consistent scale, high detail

**NEGATIVE (all Scenario prompts):**
> isometric, diamond grid, multiple characters, text, watermark, UI, busy background, full environment scene, photorealistic, bright saturated colors, blurry, low-contrast silhouette, cropped limbs, extra limbs, sci-fi, technology

### Playable classes — portrait + board silhouette
- `char.warrior` — heavily armored melee warrior, steel plate, large weapon, broad heavy silhouette, grim resolve
- `char.pyromancer` — robed fire-caster, embers and ash, warm glow at hands, lean mystic silhouette
- `char.ranger` — hooded archer, leather and cloak, bow, agile lean silhouette

### Locked classes — sealed/teaser (desaturated, grayed)
- `char.necromancer_locked` — robed death-caster silhouette, **sealed/desaturated grey, faint eldritch teal seal**, "locked" feel
- `char.shadeblade_locked` — agile shadow-assassin silhouette, **sealed/desaturated grey, faint eldritch teal seal**

### Enemies — must be instantly distinguishable
- `enemy.iron_cultist` — lean robed cultist, iron mask, advancing posture, physical-threat read
- `enemy.gate_brute` — massive hulking brute, body-blocking bulk, heavy stance, immovable read
- `enemy.ash_seer` — gaunt caster, raised hand mid-telegraph, **eldritch teal glow** marking power

### Boss
- `boss.larval_avatar` — cosmic-horror larval entity, impossible geometry, **heavy eldritch teal**, containment-failure dread, marquee centerpiece, larger scale

### Tiles & props (256×256, seamless where tiling)
- `tile.floor` — dark fantasy dungeon stone floor tile, subtle wear, top-down
- `tile.wall` — stone Labyrinth wall, slight height extrusion, top-down
- `tile.blocker` — rubble / broken pillar blocker prop
- `tile.entrance` — level entrance marker tile, subtle inviting cue
- `tile.exit` — level exit / stair-down tile, clear directional read
- `tile.door` — heavy iron-bound door, openable state
- `tile.door_sealed` — same door **sealed shut, faint eldritch teal seal glow** (forward-commitment)
- `tile.hazard` — generic hazard tile, danger read, warm warning glow
- `tile.reward_object` — reward chest / object on tile, inviting highlight

### Affinity overlays (recolor/effect layers over base tiles)
- `affinity.scorched` — scorched ember overlay, cracked glowing char, orange
- `affinity.flooded` — flooded conductive overlay, wet sheen + spark arcs, electric blue
- `affinity.cursed` — cursed corruption overlay, creeping rot veins, magenta-violet
- `affinity.darkness` — darkness overlay, near-black vignette, reduced-visibility fade

---

## B. RECRAFT — UI / symbolic icons (FINALIZED METHOD)

The treatment is now baked into a **saved custom style**, so per-asset prompts are SHORT — just the subject. This replaces the old "paste a long prefix every time" approach.

**Fixed setup for every icon:**
- **Style:** `Sealsworn Icons` (custom, bound to **V3 Vector**). Its **style-level prompt** holds the treatment:
  > dark fantasy game UI icon, polished steel and dark iron, bold clean dark outline, flat with slight depth, faint warm amber edge highlight only, high contrast, single centered emblem, even padding, dark slate background, distinct by silhouette
- **Settings:** Aspect **1:1** · **AI prompt Off** · **Avoid text Yes** · **Palette Auto** · **Artistic level Not selected** · **Count 4** (one item at a time) — *except passive glyphs use **Image set** mode (see below).*
- **Prompting rules (learned the hard way):** lead with the **shape**; name a real **archetype** (e.g. "kukri") not vague adjectives ("curved"); specify **material** for non-metal items; for sparse items add "large, fills most of the frame" so the model doesn't pad with decorative frames. Orientation need not be uniform — `centered` + even scale is what matters.

**BASE NEGATIVE** (use for weapons/support/currency unless a row overrides it):
> two weapons, crossed weapons, multiple objects, disconnected parts, orange-dominant, glowing blade, dark-filled blade, hollow outline, ornate frame, border, plaque, picture frame, background panel, decorative background, vignette, crest, badge, busy background, photorealistic, text, watermark, sci-fi, neon

### Weapon icons (9) — ✅ generated
| ID | Prompt | Extra negative (append to BASE) |
|---|---|---|
| `icon.weapon.sword` | a straight knightly sword, filled brushed-steel blade, leather-wrapped grip, centered | — |
| `icon.weapon.dagger` | a short curved fighting dagger, kukri-style, broad single-edged blade with a gentle forward curve, sharp pointed tip, wrapped grip, centered | straight sword blade, longsword, sickle, crescent, scythe |
| `icon.weapon.spear` | a long thrusting spear, small slender steel leaf-shaped head on a long straight wooden shaft, full length, centered | short blade, dagger, staff, halberd |
| `icon.weapon.axe` | a heavy double-bladed battle axe, polished steel, faint amber edge only, centered | dark blade |
| `icon.weapon.mace` | a one-handed war mace, dark iron flanged head with short spikes, short sturdy handle, centered | hammer, axe, flail, chain |
| `icon.weapon.bow` | a recurve war bow, curved wooden bow with a taut bowstring, two limbs and visible string, dark wood and steel nocks, centered | sword, sickle, crescent blade, no string, harp |
| `icon.weapon.crossbow` | a mechanical crossbow, horizontal bow limbs on a wooden stock with a trigger, T-shaped, dark wood and steel, centered | gun, rifle, longbow |
| `icon.weapon.staff` | a tall arcane wizard staff, long wooden shaft topped with a small glowing focus crystal, no blade, centered | spear, blade, weapon, short wand |
| `icon.weapon.wand` | a magic wand, short stout dark-wood rod with carved spiral runes, a small glowing crystal at the tip, relic craftsmanship, large, fills most of the frame, centered | staff, long thin shaft, blade, ornate frame, plaque |

### Support items (2)
| ID | Prompt | Negative |
|---|---|---|
| `icon.support.tome` | a closed arcane tome, leather cover with a metal clasp and corner fittings, centered, single object | BASE |
| `icon.support.shield` | a heater shield, dark steel face with an iron rim and a central boss, centered, single object | two objects, multiple objects, disconnected parts, orange-dominant, glowing, dark-filled, hollow outline, ornate frame, picture frame, background panel, decorative background, vignette, heraldic crest, coat of arms, busy background, photorealistic, text, watermark, sci-fi, neon |

> Shield gets its own negative: the BASE forbids "shield/crest/border," which would fight an actual shield. This version keeps anti-frame but allows the shield + rim.

### Currency (4) — cosmic relics carry the reserved eldritch teal
| ID | Prompt | Negative |
|---|---|---|
| `icon.currency.gold` | a small stack of gold coins, warm gold, centered, single object | BASE + `silver, gem` |
| `icon.currency.oath_shard` | a fractured crystalline oath shard, faint eldritch teal glow, centered, single object | BASE |
| `icon.currency.echo` | a small floating ghostly wisp mote, faint eldritch teal glow, centered, single object | BASE |
| `icon.currency.seal_fragment` | a broken carved stone seal fragment, relic rune, faint eldritch teal glow, centered, single object | BASE |

### Passive glyphs (20–30) — via **Image set** mode
Placeholder archetype symbols; map to specific passives when Epic 6 designs them. All render through `Sealsworn Icons` as metal emblems, so prompts are just the symbol.

**How to run Image set:**
1. In the generation-mode dropdown (Image / Video / Mockup / **Image set** / Exploration) choose **Image set**.
2. Keep the `Sealsworn Icons` style + the settings above selected — those are the "shared settings."
3. You get a multi-row list: **paste one symbol prompt per row** (do ~8–10 per run).
4. Generate — it produces all rows together in one batch, same style/negative.
5. Pick the readable ones; re-roll misses individually at Count 4.

**GLYPH NEGATIVE** (note: drops "multiple/crossed" since some glyphs are composite symbols):
> orange-dominant, glowing edges, hollow outline, ornate frame, border, plaque, picture frame, background panel, decorative background, vignette, busy background, photorealistic, text, watermark, sci-fi, neon

**Prompts** — `icon.passive.001`–`028` (each line = one emblem):

*Offense:* `crossed swords` · `a flaming skull` · `a dripping blood drop` · `a jagged lightning bolt` · `a clenched spiked gauntlet fist` · `three slashing claw marks` · `a serrated fang`

*Defense:* `a tower shield` · `a stone fortress wall` · `a layered aegis ward` · `a knight's helm` · `interlocked chain links` · `a thorned barrier ring` · `a closed fortress gate`

*Utility:* `an open watchful eye` · `an hourglass` · `an ornate key` · `a compass rose` · `a lit lantern` · `a coiled rope` · `a pair of boots`

*Rule-bender (add `faint eldritch teal accent` to each):* `an upside-down inverted hourglass` · `a cracked broken rune` · `a two-faced mask` · `an ouroboros looping serpent` · `a die showing impossible faces` · `a tangled knot` · `a coin frozen mid-flip`

### UI frames / overlays
- `ui.*` frames — ornate dark-stone panel frame, iron corners, candle-warm trim. **Recommend:** generate decorative corner/border pieces and assemble as 9-slice in Godot rather than fixed-size full panels.
- `overlay.move_range` / `overlay.attack_range` / `overlay.blocked_line` — flat tile-highlight markers, distinct by shape+pattern (not color alone)
- `overlay.fog_hidden` / `overlay.fog_memory` — fog states: hidden (opaque) vs memory (desaturated/dimmed)
- `overlay.seer_mark` — telegraph marker, **eldritch teal**, clearly "danger here next turn"
- `banner.victory` / `banner.defeat` — outcome banner treatments

---

## C. Audio (tool TBD — ElevenLabs SFX / Suno or Stable Audio suggested)

Not Scenario/Recraft, but tracked for the Story 10.7 cue map. Brief generation cues:
- **SFX:** crisp tactical feedback first. Preview = soft/neutral; confirm = decisive — must be audibly distinct. Door-seal = heavy ominous. Cosmic events (Seer mark, soul-return, boss victory) carry the eldritch tone.
- **Ambient loops:** dark medieval foundation + restrained cosmic unease; must never overpower tactical readability. One per: Labyrinth, outpost, Scorched, Flooded, Cursed, Darkness, boss/finale.
