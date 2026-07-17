# Professional-Quality Rubric — the six lenses

Score every screen and every interaction through ALL six lenses. Lenses 1–2 find defects in what
exists. Lenses 3–6 exist to find what is MISSING — an agent that only critiques what it sees will
never report an absent animation or an unbuilt menu, so lenses 4–5 are mandatory checklists where
every item gets an explicit `present / partial / missing` verdict with a screenshot reference.

## Lens 1 — Playability (defects)

Soft-locks, dead inputs, unreachable states, wrong state transitions, stale renders, crashes.
Probe deliberately: reject-path taps (walls, corpses, out-of-range), rapid double inputs, quitting
mid-action, resizing the window mid-run. Any state where no available input changes anything is a
Blocker by definition. Cross-check surprises against the Godot log
(`%APPDATA%\Godot\app_userdata\Sealsworn\logs\godot.log`) — a clean log + dead input means silent
domain rejection, not a crash.

## Lens 2 — Comprehension (the checklist's seven items)

Score C1–C7 from `_bmad-output/planning-artifacts/mvp-playtest-comprehension-checklist.md` §3 as
far as reachable: movement, attack-preview clarity, preview/commit distinction (audio off),
damage/death explainability, Consume/Destroy clarity, positioning, quit/resume. The agent read is
advisory (it cannot feel confusion) — frame each as "what on screen would tell a first-time player
this?" and mark FAIL when the answer is "nothing".

## Lens 3 — Game-feel / juice (temporal analysis)

Use `burst` captures around every action type (move, attack, kill, death, reward, screen change)
and diff the frames:

- **Response time:** does ANYTHING change within ~1 frame of input? Every input needs an
  acknowledgment within ~100 ms — visual, since this game ships silent.
- **Animation presence:** identical frames across a burst = the sprite teleported / the value
  snapped. Movement should tween; hits should flash/knock; deaths should fade/collapse; numbers
  should count or float.
- **Transitions:** screen changes should fade/slide, not hard-cut. Burst across every scene
  boundary (select→run, node→node, death→outpost).
- **Idle life:** with no input for 3+ seconds, does anything move (ambient flicker, breathing
  sprites, particle drift)? A fully static frame reads as frozen software, not a living world.
- **Emphasis moments:** kills, rewards, level transitions, and death deserve outsized feedback
  (shake, zoom, slow-down, sting). Note every unmarked big moment.

## Lens 4 — Visual / UI craft (per-screen checklist)

For each screen, verdict + evidence on each item:

- **Theme:** consistent fonts/sizes/colors/StyleBoxes, or default-Godot gray? (The repo has a
  generated Recraft UI frame kit — button_plate/panel_frame/modal_frame.svg — is it used?)
- **Layout:** alignment grid, margins, use of space (dead voids?), visual hierarchy (can you tell
  title from body from action at a squint?), safe areas at multiple window sizes.
- **Affordances:** do interactive things look interactive; are hover/pressed/disabled/SELECTED
  states rendered (test by clicking and re-shotting — a selection with no visual change is a FAIL);
  are tap targets ≥44px?
- **Content quality:** player-facing text free of internal markers (`[#]`, `[!]`, snake_case ids,
  `(coming soon)`, `not yet tallied`); real names via display_name; numbers formatted.
- **Asset usage:** are the approved assets on disk actually on screen (character portraits,
  icons, frames)? `godot/assets/**` vs what renders — unused approved art is a finding.
- **Readability:** contrast, text size at arm's length, non-color channels for every meaning
  (the accessibility contract), no clipped/overlapping labels at 2.0× text scale.

## Lens 5 — Professional-completeness inventory (absence audit)

Walk this list explicitly; every item gets `present / partial / missing` + where you looked.
This is how missing things get noticed — never skip an item because "obviously not built yet":

title screen · main menu · settings surface · pause/escape menu · save-slot or continue surface ·
onboarding/tutorialization (first-run hints, tooltips) · HUD (styled, not debug text) ·
range/target highlights · turn/phase indicator · action-economy display · floating damage numbers
or combat log · enemy intent/telegraphs · minimap or route map · progress indicators (node X of
Y, run progress) · reward/loot presentation moment · level-up/unlock celebration · death screen ·
victory screen · run summary · credits · app icon/window title · audio: music, ambient, SFX,
UI sounds (known-descoped here — still record it) · haptics/screen-shake equivalents ·
empty/error states (full inventory, nothing to buy) · loading states · confirmation dialogs for
destructive choices · accessibility options surface.

## Lens 6 — Genre benchmark

For each major screen, ask explicitly: "what would a shipped game in this genre show here?"
Reference points for a mobile-first tactical roguelite: **Slay the Spire** (map/reward/deck
screens), **Into the Breach** (telegraphs, undo, clarity), **Hoplite** (one-screen tactical
readability), **Shattered Pixel Dungeon** (mobile HUD economy), **Darkest Dungeon** (tone,
narration, death framing). Name the 2–3 biggest gaps per screen versus that bar — concretely
("StS shows the three reward cards fanned with rarity color and a skip button; here the reward is
one gray text row"), never generically ("looks unpolished").

## Output discipline

Every finding: lens, screen, severity (Blocker / Major / Polish), evidence (screenshot filename),
and a one-line concrete fix direction. Rank Blockers first. End with the absence-audit table
(lens 5) in full — including the `present` rows, so coverage is provable.
