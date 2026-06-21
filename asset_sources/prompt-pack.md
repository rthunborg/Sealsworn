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

### Passive glyphs (20–30) — use a DEDICATED glyph style, NOT `Sealsworn Icons`

⚠️ **Lesson learned:** `Sealsworn Icons` is trained on a steel sword, so it forces abstract symbols into blades (lightning bolt → a blade, claw marks → three daggers, blood drop → a sword on drips). **Do not use the weapon style for glyphs.** Two fixes, both keeping the dark-steel-emblem family:

- **Option A — neutral preset + treatment prompt (quick):** turn the custom style OFF, pick base **V4.1 Vector** (or V3 Vector), and prepend this treatment to every symbol:
  > dark fantasy game UI rune emblem, single centered flat engraved symbol, bold thick dark outline, polished steel and dark iron with a faint amber edge, dark slate background, high contrast, distinct silhouette, even padding
- **Option B — dedicated `Sealsworn Glyphs` style (recommended):** generate ONE clean *non-weapon* emblem with Option A (e.g. a shield or an eye), pick the cleanest, build a new style `Sealsworn Glyphs` from it, then Image-set all 28 through it. Same anchor→style→batch pattern as the weapons, without the sword bias.

**GLYPH NEGATIVE** — add `sword, blade, dagger, spear, weapon` to every NON-weapon symbol; omit those words only for `crossed swords`:
> sword, blade, dagger, spear, weapon, realistic scene, ornate frame, border, plaque, background panel, vignette, multiple unrelated objects, busy, photorealistic, text, watermark, sci-fi, neon

**Run via Image set** (8–10 rows per batch; mode dropdown → Image set; keep style + settings as the shared config; one symbol per row). A few symbols were simplified after the first batch came out busy (flaming skull → horned skull; spiked gauntlet → gauntlet). Prompts `icon.passive.001`–`028`:

*Offense:* `crossed swords` *(weapon — drop the anti-weapon negative for this one)* · `a horned skull` · `a single dripping blood drop` · `a jagged lightning bolt` · `a clenched gauntlet fist` · `three slashing claw marks` · `a serrated fang`

*Defense:* `a tower shield` · `a stone fortress wall` · `a layered aegis ward` · `a knight's helm` · `interlocked chain links` · `a thorned barrier ring` · `a closed fortress gate`

*Utility:* `an open watchful eye` · `an hourglass` · `an ornate key` · `a compass rose` · `a lit lantern` · `a coiled rope` · `a pair of boots`

*Rule-bender (add `faint eldritch teal accent` to each):* `an upside-down inverted hourglass` · `a cracked broken rune` · `a two-faced mask` · `an ouroboros looping serpent` · `a die showing impossible faces` · `a tangled knot` · `a coin frozen mid-flip`

### UI frames & panels (Recraft → 9-slice in Godot)

Make ONE coherent chrome kit and **reuse it across all screens** — don't generate 9 separate screen frames. Models fill the middle, so prompt for an **empty/hollow center** and slice in Godot. Use base **V4.1 Vector**, not the icon style.

| Element → IDs | Prompt | Negative |
|---|---|---|
| panel frame (9-slice) → all `ui.*` | an ornate dark fantasy UI panel border frame, carved dark stone with iron corner brackets and faint candle-warm trim, empty hollow center, square, symmetrical | filled center, content inside, text, character, weapon, busy, photorealistic, sci-fi |
| `ui.passive_modal` frame | an ornate dark fantasy modal window frame, iron filigree corners, dark stone, empty hollow center, portrait orientation | filled center, text, character, busy, photorealistic |
| UI button plate | a dark fantasy UI button plate, iron-bound dark stone, slight bevel, empty label area, horizontal | text, icon inside, busy, photorealistic |

The nine `ui.*` rows (hero_select, tactical_hud, preview, passive_modal, run_map, outpost, run_summary, settings, save_resume) are assembled in-engine from this kit — they are **not** nine separate generations.

### Tactical overlays — mostly ENGINE-drawn, not AI

`overlay.move_range`, `overlay.attack_range`, `overlay.blocked_line`, `overlay.fog_hidden`, `overlay.fog_memory` must tile, be semi-transparent, and align exactly to the grid — build them as **flat color fills + distinct patterns in Godot** (per NFR9), not Recraft art. Only these three are worth AI-generating:

| ID | Prompt | Negative |
|---|---|---|
| `overlay.seer_mark` | a glowing eldritch teal targeting rune, concentric circle telegraph mark, flat top-down view, transparent background | weapon, character, busy, photorealistic, warm colors |
| `banner.victory` | an ornate dark fantasy victory banner ribbon, iron-trimmed dark cloth with a faint warm glow, empty center | text, character, busy, photorealistic |
| `banner.defeat` | a tattered dark fantasy defeat banner ribbon, muted desaturated cloth, empty center | text, character, bright colors, busy |

---

## C. Audio (tool TBD — ElevenLabs SFX / Suno or Stable Audio suggested)

Not Scenario/Recraft, but tracked for the Story 10.7 cue map. Brief generation cues:
- **SFX:** crisp tactical feedback first. Preview = soft/neutral; confirm = decisive — must be audibly distinct. Door-seal = heavy ominous. Cosmic events (Seer mark, soul-return, boss victory) carry the eldritch tone.
- **Ambient loops:** dark medieval foundation + restrained cosmic unease; must never overpower tactical readability. One per: Labyrinth, outpost, Scorched, Flooded, Cursed, Darkness, boss/finale.
