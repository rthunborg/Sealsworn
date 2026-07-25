# Agent Playtest — 2026-07-20 (desktop, agent-driven, post-Epic-14)

> **Protocol:** modeled on `_bmad-output/planning-artifacts/mvp-playtest-comprehension-checklist.md`
> (§4 session record, §3 comprehension items) and the agent-playtest six-lens rubric, driven by an
> AI agent via OS-level mouse/keyboard on the real Windows build (`main` @ `a78653c`, the first
> build after the Epic 14 "Playable & Presentable" merge). An agent session **cannot** score the
> human-felt OSG dimensions (fun, memorability, replay desire) and does **not** count toward the
> ≥5 observed human sessions (OSG-1). Screenshot evidence lives in the session scratchpad
> (`playtest-shots/`, filenames cited per finding).
>
> **Three runs were played — one per MVP class.** For the first time, the loop is playable
> end-to-end: run C (Pyromancer) won a combat node, consumed a passive at the reward modal, chose
> a route branch, passed an event node, and died in a depth-2 elite fight. Epic 14's fixes are
> real: of the 2026-07-16 report's five Blockers, **all five are fixed or substantially
> addressed** (rejection feedback and the death moment remain partial — see What Works). The new
> top problem is one class of layout bug (F1/F2) that renders most of the new HUD unreadable.

## Session records

### Session A (run 1 — Warrior)

| Field | Value |
|---|---|
| Tester id / alias | claude-agent (observer = same) |
| Date | 2026-07-19/20 (paused ~13h mid-run by workstation lock) |
| Device / form factor | Windows desktop, windowed; client sizes exercised 984×901, 574×1001, 774×1381 |
| Build id | `main` @ `a78653c` |
| Seed | 158585842 (surfaced at the outpost after death — seed display is new and works) |
| Class | Warrior (sword 4 dmg / adjacent_cardinal; shield block never visibly proc'd) |
| Session length | ~35 min active |
| Run outcome | death (node 1 — a Scorched elite-feel board, 4 enemies: 2 melee + 2 ranged ghost-sprites matching the seer art that marks in runs B/C) |
| Nodes cleared | 0 of 9 |
| Notable confusion | burn-per-turn discovered only via clipped log; Wait button gave no ack (pressed 3× believing it broken, F7); stale log windows (F2); HP losses unaccountable in the moment |
| Memorable moment | killing the cultist that then burned to death on its own hazard tile — genuine emergent tactics (uncreditable to the UI: it was readable only in the log) |
| Desire for another descent | n/a (agent) |
| Blocked action | landing on corpse tiles (silently rejected, no hint); attacking the boxed-in seers without crossing a burn moat |

> Run-1 screenshot filenames use provisional nicknames coined before the log identified anyone:
> "knight" = the armored melee cultist (`iron_cultist_melee`), "brute" = the second melee sprite.

### Session B (run 2 — Ranger)

| Field | Value |
|---|---|
| Tester id / alias | claude-agent |
| Date | 2026-07-20 |
| Device / form factor | Windows desktop, windowed 574×1001 client |
| Build id | `main` @ `a78653c` |
| Seed | not recorded (quit before outpost; seed shows only at run end — mid-run it is nowhere) |
| Class | Ranger (bow: 2 dmg preview, +1 actual at range; reach 4 straight_line; blocked by units) |
| Session length | ~15 min |
| Run outcome | deliberate quit (Alt+F4) mid-fight at 7/18 to test resume → **run lost** (C7 FAIL, F3) |
| Nodes cleared | 0 |
| Notable confusion | a seer mark on my tile scrolled past unseen → 4 "unexplained" detonation damage (F5); preview said 2, hit dealt 3 (F4) |
| Memorable moment | the dodge-shoot dance vs the marking seers — the domain supports real ranged play (line-of-fire blocking by units included) |
| Desire for another descent | n/a |
| Blocked action | shooting through an occupied cell — correctly rejected WITH a red border + "Line of fire is blocked" hint (the good reject path) |

### Session C (run 3 — Pyromancer)

| Field | Value |
|---|---|
| Tester id / alias | claude-agent |
| Date | 2026-07-20 |
| Device / form factor | Windows desktop, windowed 574×1001 client |
| Build id | `main` @ `a78653c` |
| Seed | 644951494 (outpost) |
| Class | Pyromancer (staff: reach 4 straight_line, 2 preview / 3 actual with tome; consumed Kindling Focus mid-run) |
| Session length | ~20 min |
| Run outcome | death (depth-2 Elite Combat, 5 enemies) after **winning node 1** and clearing the event node |
| Nodes cleared | **2 of 9** |
| Notable confusion | staff is secretly ranged (walked into melee needlessly — nothing shows weapon reach before arming, F12); event node resolved to nothing (F9); "Passives spent/destroyed: none recorded yet" after I consumed one (F10) |
| Memorable moment | the full Consume/Destroy modal with real prose per passive — the first screen in the game that reads like a finished game |
| Desire for another descent | n/a |
| Blocked action | none new — all rejects were either correctly hinted or already-known silent cases |

## Comprehension items (checklist §3) — as scored by the agent

| # | Item | Read |
|---|---|---|
| 1 | Movement | **PASS (caveats)** — single-tap pathfound movement with reachable-tile outlines works and feels modern; but the legend that explains the outlines is clipped offscreen (F1), the range cap surfaces only as a clipped "Too far to move" hint, and corpse rules (can pass, can't land) are never stated |
| 2 | Attack preview clarity | **FAIL (on §3.2's own bar)** — the surface finally exists: target, damage, reach, and legality all render before commit (fixing old F2-2026-07-16; left-clipped per F1, readable at zoom). But §3.2's PASS requires the tester to state "this attack will hit for about N" — and the shown N excludes every support/passive bonus, so a tester reading the preview *correctly* still states a wrong N whenever a bonus applies (F4). Structural credit in prose; the verdict follows the number |
| 3 | Preview/commit distinction | **PASS** — armed state renders (white target border + Confirm/Cancel buttons); audio-off distinction holds; no accidental commits observed across ~30 attacks |
| 4 | Damage/death explanation | **FAIL** — the cause data exists (log lines name burns, marks, weapons) but the surface defeats it: a ~3-line window that shows *stale* lines while the newest overflow invisibly (F2), text left-clipped (F1), kills and death never acknowledged on screen (F15). The agent repeatedly could not account for its own HP losses in the moment |
| 5 | Consume/Destroy clarity | **PASS (Consume path only)** — reached for the first time. At decision time the agent articulated the §3.5 trade-off from the modal's own prose: Consume = "permanent edge of bonus fire damage now", Destroy = "smother the flame — a temporary burst" (the gamble), then chose Consume via the confirmation step. The Destroy and decline paths went untested (next-session protocol item). Layout defects (F13) don't block comprehension |
| 6 | Positioning importance | **PASS (§3.6's adjust-for-a-tactical-reason clause)** — the agent repeatedly repositioned unaided for tactical reasons: dodged seer marks, kept ranged spacing/kited, used corpse chokepoints, baited enemies across hazards. The FAIL clause ("stands still and takes avoidable damage without noticing") did not apply: the run-B detonation damage was unavoidable *by observation* because the mark telegraph is unreadable — that failure is charged to item 4 and F5, not to positioning comprehension |
| 7 | Quit/resume | **FAIL** — mid-run quit + relaunch lands at hero select with the run gone; no continue surface; and the game offers no in-game quit/pause, so window-close is the only quit a player has (F3) |

## Findings

Severity bands per the rubric: **Blocker** (cannot finish / cannot understand) → **Major**
(comprehension or feel failure) → **Polish** (craft gap vs the professional bar).

### Blockers

- **F1 — One layout bug hides nearly the entire HUD (lens 1/4; every combat screenshot, esp.
  `05-zoom-hud-left/right.png`, `17-hud-bottom-3x.png`).** The HUD label column — HP "N/18",
  "Gold 0", "Bag 0/6", "Node x/y", Class, affinity badge, and the highlight legend ("Move:
  outline   Attack: corner ticks") — renders at negative-x, clipped at the window's left edge, at
  every size tested (574/774/984 wide; portrait, landscape, tall). The same root cause clips the
  attack-preview text ("Target/Expected damage/Weapon reach"), the reject hints ("Too far to
  move"), the Confirm Attack button label (renders garbled), the Wait/End Turn label, and the
  first ~2 characters of every log line. Most of Epic 14's HUD work is shipped and invisible.
  *Fix direction: the HUD/control-region containers are anchored off-canvas; likely one presenter
  layout-profile/anchor fix un-hides everything at once.*
- **F2 — The event log shows a stale 3-line window; the newest lines are the hidden ones
  (lens 1/2; `13-knight-attacked.png`, `47-kite-retreat.png` vs actual state).** The log label
  holds the event tail but overflows its panel downward, so the panel shows the *oldest* lines of
  the window — 2–3 turns stale — while kills, marks, burns, and death reasons scroll past below
  the clip. The one feedback channel the game has presents the past as if it were the present.
  *Fix direction: bottom-anchor the label / show last-N-that-fit, newest visible.*
- **F3 — Quit/resume loses the run; there is no quit (lens 1/5; `39-relaunch.png`).** Closing the
  game mid-run (the only quit that exists — there is no pause menu, no in-game quit button) and
  relaunching boots to hero select. The run is gone; no Continue surface exists anywhere. C7 FAIL
  and an absence-audit triple (pause menu, save/continue surface, quit flow).
  *Fix direction: the Epic-2 resume seam (`SaveManager.resume_route_position` → `RunResumeService`)
  exists; the boot flow never consults it — add a Continue path at boot plus an in-game pause/quit.*

### Major — correctness

- **F4 — The attack-preview damage number is wrong whenever a bonus applies (lens 2;
  `43-pyro-preview-hud.png` vs `44-pyro-hit1-6-hud.png`).** Preview says "Expected damage: 2" for
  the Pyromancer staff; the hit deals 3 (tome +1). Ranger: preview 2, ranged hit deals 3 (steady
  aim). With Kindling Focus consumed the preview still says 2 while the target's bar drops ~4.
  `TacticalAttackPreview` evidently excludes `support_bonus_damage` and consumed-passive bonuses.
  FR9/FR10's one load-bearing number lies to the player.
  *Fix direction: fold support-item and consumed-passive bonuses into the preview computation so
  the shown N equals the resolved N (plus a range-conditional note for steady aim).*
- **F5 — Seer marks have no readable telegraph (lens 2/6; `31-ranged-armed.png`,
  `34-ranged-kill-8.png`).** Marks exist only as a (clipped, usually hidden) log line "enemy_N
  marked hero at (x,y)". No parseable tile overlay marks the doomed tile. Both runs B and C ate
  4-damage detonations that read as spontaneous. Additionally, the detonation flash was observed
  rendering on the hero's *current* tile while the log placed the (avoided) detonation on the
  *previous* tile (`33-ranged-shot-1.png`) — the flash may be anchored to the wrong cell.
  *Fix direction: render a persistent marked-tile overlay (glyph + non-color channel, NFR9) from
  mark to detonation; verify the detonation-flash cell anchor in the presenter.*
- **F6 — Internal identifiers are the player-facing vocabulary (lens 4; `08-tap-enemy-preview.png`,
  `19-onto-burn-tile.png`).** "enemy_3", "iron_cultist_melee", reach "1 (adjacent_cardinal)" /
  "4 (straight_line)", and the fallback "Unknown event hero_waited occurred." all render to the
  player. Log coordinates are also 1-indexed grid refs ("moved from (4,3) to (4,4)") — a
  coordinate language nothing else on screen shares.
  *Fix direction: a display-name pass over every log/preview string (enemy names, weapon names,
  reach phrasing) + a `hero_waited` formatter; speak in directions or names, not grid coords.*
- **F9 — Event nodes resolve to nothing (lens 1/2; `52-event-node-2.png`).** Choosing "Event
  [Unknown Risk]" on the route returns to the route screen with Cleared+1 within one frame. No
  narrative, no choice, no outcome display — the node type is a silent no-op on screen.
  *Fix direction: a minimal event outcome card (what happened, what changed) before returning to
  the route — even one sentence would discharge the comprehension gap.*
> **CORRECTION (2026-07-24): F10's "shards always 0" was a mis-report.** `MetaAwardRules` awards
> `min(1 + 1×nodes_cleared, 5)` on a COMPLETED run and **0 on death by an explicit Story-8.3 design
> decision**. All three runs here ended in death, so 0 was correct behavior — the economy was wired
> and working. The loot/passives-unrecorded half of F10 stands (deferred run-level event store,
> ledger F-2). Ratified decision D4 (2026-07-24) now *changes* that design so deaths do award shards.

- **F10 — The run-summary economy is unwired (lens 1/5; `59-elite-death-8.png`).** After clearing
  2 nodes and consuming a passive: "Oath Shards earned this run: 0", "Notable loot: — none —",
  "Passives spent/destroyed: — none recorded yet —". Shard income appears to be zero always
  (against 3/5 shard unlock costs = a treadmill), and the passive I consumed was not recorded.
  Also observed: no consumable/gold drop appeared in any of 3 runs; Bag stayed 0/6 throughout.
  *Fix direction: wire shard earning, loot, and consumed/destroyed-passive recording into the run
  summary; decide and implement the intended shard-income rule so unlocks are reachable.*
- **F-Q1 (verify intent) — HP resets to full between nodes (lens 1; `54-elite-preview-hud.png`).**
  Run C ended node 1 at 6/18 and entered node 2 at 18/18. If the risk economy intends persistent
  HP across a descent, this is a serious bug; if intended, it contradicts the "Safer Combat"
  route copy having any meaning. Flagged for a design/code check rather than asserted.
  *Fix direction: check hero-HP persistence across `begin_interactive_combat_node` in the run
  snapshot; align behavior with the GDD risk economy and document the answer.*

### Major — comprehension / feel

- **F7 — Wait/End Turn gives zero acknowledgment (lens 2/3; `16-after-wait.png`,
  `17-after-wait2.png`).** No press feedback, no visible log line (its event renders as the F6
  fallback, and usually below the F2 clip), no round counter. The agent pressed it three times
  convinced it was broken; a player will too.
  *Fix direction: pressed-state styling + an immediately visible "You wait." line (rides the F2
  fix); a round counter would also discharge that absence-audit gap.*
- **F8 — The enemy phase is invisible (lens 3; every post-commit burst, e.g.
  `09-attack-commit-1..8.png`).** All enemy moves, attacks, and marks resolve within ~1 frame of
  the player's commit. Units teleport; nothing sequences or animates the enemy turn. Combined
  with F2, the player's only account of what just happened is a stale log. (The one feedback that
  DOES exist and works: a gold damage-flash tint on damaged units, `09-attack-commit-1.png`, and
  the detonation tile flash, `33-ranged-shot-1.png`.)
  *Fix direction: sequence the enemy phase — per-enemy step delay + a movement tween — so actions
  are watchable; build on the existing flash channel.*
- **F11 — Hazard/corpse visual vocabulary collision (lens 4; `14a-zoom-knight-tile.png`,
  `14b-zoom-brute-corpse.png`).** The skull motif means both "burn hazard tile" and "corpse
  remains"; on Scorched boards corpses are near-invisible dark-on-dark inside skull-tile art.
  Safe floor vs hazard differs only by a 2px yellow-vs-blue border and a glyph on uniformly loud
  lava art — it fails a squint test outright (and the borders are a color-only channel, an NFR9
  concern). On the blue "conductive" boards no hazard tiles appeared at all, so the vocabulary
  also varies silently by affinity.
  *Fix direction: give corpses a distinct silhouette + non-color channel, and dim safe-floor art
  so hazard tiles pop at a squint.*
- **F12 — Weapon identity is hidden until you arm an attack (lens 2/4; `43-pyro-preview.png` vs
  `28-ranger-selected.png`).** Nothing shows your weapon's reach or damage before an attack is
  armed — the Pyromancer's staff turned out to be a reach-4 line weapon after the agent had
  walked into melee. Class select lists only "Weapon: Staff / Support: Tome"; the HUD class line
  is clipped (F1) and carries no kit stats.
  *Fix direction: a persistent kit line (weapon, damage, reach) in the HUD and on the hero-select
  rows.*
- **F14 — Mis-taps commit irreversible moves (lens 1; `19-onto-burn-tile.png` — a boundary-pixel
  tap committed an unintended 2-tile move mid-fight in session A).** Movement is single-tap-commit
  with no confirm or undo. At mobile fat-finger sizes this will burn turns and runs. (Attack got
  the two-step treatment; movement got none — Into the Breach ships undo for exactly this reason.)
  *Fix direction: either a move-confirm step matching the attack flow, or a pre-enemy-phase undo.*

### Major — presentation

- **F13 — Reward modal layout is broken (lens 4; `49-victory-3.png`, `50-consume-passive-2.png`).**
  The passive text stack renders over/through the decorative modal frame art (the frame floats as
  separate decoration); in the confirmation step, two of three white button bars render with no
  visible label. Also content: a Pyromancer is offered "Hunter's Quiver" (a Ranger passive that
  is dead weight for the class) — the reward pool appears class-blind.
  *Fix direction: make the frame the actual modal container with content laid out inside it,
  label the confirmation buttons, and filter the reward pool by class.*
- **F15 — Every transition is a hard cut; death has no moment (lens 3; `26-death-2..10.png`,
  `04-begin-descent-2/3.png`).** Select→combat, victory→modal, modal→route, and death→outpost all
  swap within ≤1 frame. Death in particular: from standing sprite to the outpost text screen with
  zero acknowledgment — the Epic-8 first-death narrative beat still never renders. The only death
  acknowledgment in the game is the outpost line "Outcome: Fallen".
  *Fix direction: 200–300 ms fades/slides at every scene seam + a staged death beat (the Epic-8
  narrative content already exists in-repo).*
- **F16 — No animations; the game is fully static at idle (lens 3; `21-resume-state.png` =
  pixel-identical after 30+ min).** Movement teleports, deaths snap to corpse art, numbers snap.
  The damage flash (F8) is the sole motion in combat; there is no ambient/idle motion anywhere.
  *Fix direction: tween moves, fade deaths, count HP changes; add minimal ambient motion
  (flicker/particle drift) so idle doesn't read as frozen software.*

### Polish

- **F17 — Placeholder-gray surface language (lens 4; `05-zoom-hud-right.png`, `03b-zoom-begin-btn.png`,
  `51-confirm-consume-8.png`).** Five full-width empty slab panels fill the HUD region (~80% of
  each panel is empty gray); route and outpost are left-anchored text rows over a ~70-85% dead
  void; Begin Descent is an unstyled full-width slab with no enabled/disabled distinction. The
  Recraft frame kit IS wired into `sealsworn_theme.tres` but reads as flat gray at these sizes.
  *Fix direction: collapse empty panels, size panels to content, and apply the frame kit at a
  scale where its art is visible.*
- **F18 — Marker syntax and placeholder copy in player text (lens 4; `51-confirm-consume-8.png`
  route strings, `26-death-10.png` outpost rows).** Route/outpost strings carry
  `[!] [✓] [☠] [✓✓] ◆` markers and four "— Coming later" rows. (The old-report F14 `[#]` prefixes
  are gone; `[!]` and friends survive as the residue.)
  *Fix direction: replace marker glyphs with themed icons or plain copy; cut or properly style
  the Coming-later rows.*
- **F19 — Hero select craft (lens 4; `01-boot.png`, `03a-zoom-row2-3.png`).** Unselected
  playable-class rows clip the class NAME at the row top (Warrior/Pyromancer/Ranger are unnamed
  until clicked — locked rows render fine); portraits are ~48px thumbnails of the approved full
  art; ~60% of the screen is empty.
  *Fix direction: reserve row height for an unclipped name label, scale the portraits up, and
  spend the void on kit/lore per class.*
- **F20 — Identity/app-shell gaps (lens 5; repo evidence: `project.godot` `config/icon`; no
  on-screen capture taken of the taskbar icon — flag carried on repo state + the absence audit).**
  App icon is `icon_placeholder.svg`; no settings or accessibility surface anywhere; audio absent
  entirely (known descoped — 0 audio files in repo). Window title works ("Sealsworn (DEBUG)").
  *Fix direction: commission/approve a real icon via the asset pipeline; add a minimal settings
  surface (text scale + the NFR9 colorblind check).*

## What already works (credit where due — and it is substantial)

Epic 14 transformed the build. Verified working on-screen this session:

- **All five 2026-07-16 Blockers are gone:** Wait/End Turn exists and functions (old F1 —
  soft-lock escape confirmed by hazard-tick death test); the attack preview renders with
  target/damage/reach + Confirm/Cancel (old F2); "Too far to move" / "Line of fire is blocked" /
  red-border illegal-target feedback exists (old F3, partially — see silent cases below); Descend
  Again routes through hero select with a real class kit (old F4); death at least lands on an
  outpost that names the outcome and seed (old F5, partially — the moment itself is still a cut).
- **Interaction vocabulary:** cyan hero cell, blue reachable-move outlines (with pathfinding,
  including through-corpse paths), red threat borders on adjacent enemies, corner ticks on legal
  attack targets, white armed-target border, red illegal-target border. A real, coherent system —
  currently sabotaged only by the clipped legend (F1).
- **The tactical domain plays well:** per-turn hazard burn that enemies also suffer (the run-3
  brute mostly killed itself chasing the agent across lava — emergent kiting is real); seer
  mark-dodge cycles; line-of-fire blocking; corpse pass-through-but-not-landing; three genuinely
  different weapons (sword 4/adjacent, bow line-4 blocked-by-units, staff line-4) — class
  distinctness is visible in play, not just in tests (AC7 felt-half evidence, within agent limits).
- **Content surfaces:** the Consume/Destroy modal with real prose + confirmation; a route screen
  with branch choice, cleared-tracking, and a final-boss teaser ("The Larval Avatar, depth 7");
  an outpost with real outcome/seed/node data and proper "not enough shards" empty-states; seeds
  randomize per run (four distinct boards across two affinity treatments observed: scorched ×2
  layouts, blue "conductive" ×2 layouts).
- **Stability:** zero crashes, zero script errors in `godot.log` across 3 runs, a mid-run process
  kill, a relaunch, a workstation lock/unlock, and multiple live window resizes. Tap hit-testing
  stayed pixel-accurate at three window sizes.

## Absence audit (lens 5 — full walk)

| Item | Verdict | Where looked / evidence |
|---|---|---|
| Title screen | **missing** | boot lands directly on hero select (`01-boot.png`) |
| Main menu | **missing** | boot screen (`01-boot.png`), outpost (`26-death-10.png`) — neither offers one |
| Settings surface | **missing** | hero select (`01-boot.png`), combat HUD (`05-zoom-hud-left/right.png`), outpost (`26-death-10.png`) |
| Pause / escape menu | **missing** | no button on any screen (`05`, `26`, `51`); Esc key untested (protocol gap to close next session) |
| Save-slot / continue surface | **missing** | relaunch mid-run → hero select, no continue (`39-relaunch.png`) |
| Onboarding / first-run hints | **missing** | zero hints/tooltips across all screens in 3 runs (`01`, `06`, `29`, `51`) |
| HUD (styled, not debug text) | **partial** | structured themed HUD exists but is clipped off-canvas + empty slabs (F1, F17) |
| Range/target highlights | **present** | move outlines + attack corner ticks + armed/illegal borders (`23`, `32`, `36`) |
| Turn/phase indicator | **partial** | "Your Turn" chip only; enemy phase invisible (F8); no round counter |
| Action-economy display | **missing** | combat HUD holds nothing on actions-per-turn (`05-zoom-hud-left/right.png`); the rule was derived by experiment |
| Floating damage numbers / combat log | **partial** | log exists with causes; window stale+clipped (F2); no floating numbers |
| Enemy intent / telegraphs | **partial** | threat borders + attack ticks present; seer marks unreadable (F5); no intent icons |
| Minimap / route map | **partial** | route exists as a text list; no map visual (`51-confirm-consume-8` → route) |
| Progress indicators | **present** | "Cleared N/9" + depth labels on route; "Node x/y" in HUD (clipped) |
| Reward / loot presentation moment | **partial** | passive modal is substantive (C5 PASS) but layout-broken (F13); no gold/consumable drop ever appeared (F10) |
| Level-up / unlock celebration | **missing** | class unlocks are plain text rows at the outpost (`26-death-10.png`) |
| Death screen | **missing** | death hard-cuts to outpost (F15); only "Outcome: Fallen" acknowledges it |
| Victory screen | **partial** | node victory jumps straight to the reward modal; no victory beat |
| Run summary | **partial** | outpost rows exist; loot/passive rows unwired (F10) |
| Credits | **missing** | not on hero select, outpost, or any reachable screen (`01`, `26-death-10.png`) |
| App icon / window title | **partial** | title ✓; icon is `icon_placeholder.svg` |
| Audio (music/ambient/SFX/UI) | **missing** | known descoped; 0 audio files in repo (asset-pipeline state) |
| Haptics / screen-shake equivalents | **missing** | burst-diffs across every action type show no shake/zoom/hit-stop (`09-attack-commit-1..8.png`, `26-death-1..10.png`) |
| Empty/error states | **partial** | "Not enough Oath Shards…" ✓; Bag 0/6 renders (clipped); full-bag escape hatch still a known ledger item |
| Loading states | **missing** | all transitions are instant hard cuts — nothing currently takes long enough to need one, and none exists (the cuts themselves are F15) |
| Confirmation dialogs (destructive) | **present** | Consume/Destroy confirmation step with display name (`50-consume-passive-2.png`); 2 of 3 buttons blank (F13) |
| Accessibility options surface | **missing** | no settings surface at all; in-play NFR9 is mixed (text labels widespread ✓, but border-color-only tile semantics, F11) |

## Genre benchmark (lens 6 — biggest gaps per screen)

- **Hero select** vs Slay the Spire's character select: no splash/key art (approved portraits used
  as thumbnails), classes unnamed until clicked (F19), no run history/statistics.
- **Combat** vs Into the Breach / Hoplite: ItB shows every enemy's exact next action on the board —
  Sealsworn shows adjacency threat only, and its one unique telegraph (the seer mark) is invisible
  (F5); ItB ships move undo — Sealsworn commits moves on one tap (F14); Hoplite's one-screen
  readability — Sealsworn's key state lives in a broken log (F2). The board art itself is at
  genre bar; the information layer is not.
- **Route** vs StS map: a text list vs a branching map with icons, path preview, and burn-marked
  progress. The data (branches, depths, final teaser) is already there; only the presentation is
  missing.
- **Reward** vs StS: no fanned presentation, no rarity signal, and unclear whether a "take
  nothing" option exists (not tested); off-class passives dilute the choice (F13).
- **Death** vs Darkest Dungeon: DD stages death as narrative punctuation — Sealsworn's death is a
  frame swap to a text screen (F15), the Epic-8 first-death beat exists in the repo and still
  never renders; no cause-of-death recap or run epitaph (what killed you, where, with what) even
  though the event data exists; no memorialization tying the death into meta-progression the way
  DD's graveyard does.
- **Outpost** vs Slay the Spire's run-end / Hades' hub: StS ends a run with a scored summary
  (cards picked, damage taken, bosses, seed) — Sealsworn's outpost has the data rows but they are
  unwired placeholders (F10); Hades frames its hub as a living place with characters and visible
  upgrade surfaces — the outpost is left-anchored text rows with four "Coming later" stubs over a
  ~70% void (`26-death-10.png`); unlock progress is a text line with no visual progress toward the
  3/5-shard costs.

## Disposition

The build crossed the line from "broken demo" to "playable game with an unreadable UI." The
recommended split (input to `gds-correct-course` / sprint planning — this report changes no code):

1. **Readability hotfix band (highest leverage, smallest scope):** F1 + F2 are plausibly two
   presenter-layer fixes that un-hide the majority of Epic 14's already-shipped work. F7 (wait
   ack) and F6 (display-name pass over log/preview strings + a `hero_waited` formatter) ride the
   same surfaces. Do this before ANY human playtest — today these four decide every comprehension
   score.
2. **Correctness band:** F4 (preview math must include bonuses), F3 (mid-run resume — the Epic-2
   seam exists; the boot flow never consults it), F5 (render the mark telegraph; verify the
   detonation-flash anchor), F-Q1 (confirm between-node HP intent), F9 (event nodes need at least
   a one-card outcome surface), F10 (wire shards/loot/passive recording — the meta loop currently
   pays 0).
3. **Presentation/juice band (epic-scale):** F8/F15/F16 (sequenced enemy phase, transitions, a
   death moment, move/hit/death animation), F11 (hazard/corpse vocabulary), F13/F17/F18/F19/F20
   (reward modal geometry, route/outpost styling, hero-select craft, icon), F12/F14 (kit panel;
   move confirm or undo).

**OSG note:** with band 1 landed, observed human sessions (OSG-1) become meaningful for the first
time — the loop is completable and the comprehension surfaces exist. Before band 1, human testers
would mostly measure F1/F2. This agent session does not count toward the ≥5-session target and
cannot supply the felt-fun/memorability thresholds (§7 of the checklist).

**Protocol gaps to close next agent session:** press Esc in combat (pause-menu probe); test
declining a passive at the reward modal; reach a Mystery/elite reward and the finale surface;
verify the detonation-flash anchor against code.
