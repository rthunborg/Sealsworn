# Auto-GDS Epic Loop — reusable session prompt

> Paste the block below into a **fresh session** to run one epic's stories through Auto-GDS,
> one story at a time, with a human merge gate between each.
>
> It is **epic-agnostic**: the loop reads the target epic from the first dry run and locks to it,
> so the same prompt works for Epic 15, 16, 17 and beyond with no edits.
>
> **Why the merge gate is mandatory, not optional** (the one rule people are tempted to skip):
> stories inside an epic routinely touch the same files — presenters, view models, shared strings —
> so a story branched from a `main` that lacks its predecessors will conflict, duplicate work, or be
> reviewed against stale context. Sealsworn also has a scar here: during Epic 14, GitHub
> **auto-closed PR #72 unrecoverably** when its base branch was deleted while a child branch still
> targeted it. Merging each story to `main` before starting the next avoids that shape entirely.

---

```
Run an Auto-GDS epic loop for the current/next epic.

Use Auto-GDS as a one-story-at-a-time orchestrator. Do not bypass Auto-GDS. Do not edit
implementation code directly. Do not run gds-create-story, gds-dev-story, or gds-code-review
directly except through Auto-GDS delegation.

SCOPE

The target epic is not hardcoded. Determine it from the first dry run, then lock to it:

1. Run /auto-gds status.
2. Run /auto-gds dry run.
3. Read the target story key from the dry run (e.g. "16-2-room-corridor-generation" -> epic 16).
4. Report the detected epic and its target story to me, and treat that epic as THE TARGET EPIC for
   the rest of this session. Every subsequent story must belong to it.
5. If the detected epic is not the one I expected, I will say so — otherwise proceed.

PREFLIGHT — stop and report if any of these hold

- Dry run reports a missing sprint-status.yaml (tell me to run gds-sprint-planning).
- Dry run reports a retrospective for the target epic (ask me whether to run it).
- Dry run reports any blocker.
- The working tree is not clean at the start of the loop.
- The current branch is not the default branch (main) at the start of the loop.

PER-STORY PIPELINE

For each story in the target epic:

1. Run /auto-gds.
2. Let Auto-GDS execute one full story pipeline end to end.
3. At the Phase 7 review halt: continue automatically ONLY if there are no unresolved
   [Review][Decision] items, no needs-human result, no blocker, and no ambiguity. If there is any
   decision-needed item, STOP and report it to me with the reviewer's own wording.
4. At the Phase 9 merge prompt: STOP and ask me to authorize the merge. Do not merge without my
   explicit approval.
5. Do NOT start the next story until the current story's PR is merged to main and its branch is
   deleted. Stories within an epic frequently share files, so each story must branch from a main
   that already contains its predecessors. NEVER stack a story branch on another story branch —
   deleting a base branch while a child still targets it can unrecoverably auto-close the child PR.
6. After each story, run `git status --short`, confirm the working tree is clean and the current
   branch is main, and inspect the Auto-GDS report path.
7. Continue to the next iteration only if the story completed cleanly (or was caveated exactly as
   Auto-GDS allows), the working tree state is as expected, and a fresh dry run still selects a
   story inside the target epic.

HARD STOPS — halt the loop and report

- A selected story falls outside the target epic (the epic is likely complete).
- Any unresolved [Review][Decision] item.
- Any needs-human, blocked, or ambiguous result.
- Any merge conflict.
- Any failing build, test, or CI gate.
- Unexpected modification of: engine/project settings, package or plugin versions, input maps,
  save formats or schema versions, RNG stream definitions, large serialized assets, scenes, or
  prefabs. (Some stories legitimately touch these — if the story file explicitly authorizes it,
  report it and continue; if it is unannounced, stop.)
- Auto-GDS attempts to start another story without a preceding dry run.
- The working tree contains unexpected files.
- 5 stories have completed in this session — stop and summarize before continuing.

RECOVERY — if a phase dies mid-run

If any Auto-GDS phase dies mid-run (process exit, API or spend limit, timeout), do NOT assume the
phase failed and do NOT re-run it blind. Delegates in this project have repeatedly persisted their
work before dying. First inspect the on-disk state — `git status`, the story file, the Auto-GDS
report path, and any resume notes — then report what you actually find and ask me before re-running
any phase.

REPORT AFTER EVERY STORY

- Story key
- Branch
- PR status (link, merged or open)
- Auto-GDS report path
- Sprint status entry for the story
- Suite result (pass count / failures)
- Whether the next dry run is safe to continue, and which story it selects
```

---

## Notes for the operator

- **The 5-story cap will usually bind before the epic ends.** That is deliberate — it forces a
  checkpoint. Re-paste the prompt in a fresh session to continue; the loop re-detects the epic.
- **Story size varies a lot.** Stories that reverse shipped behaviour, add a new surface, or re-pin
  fingerprints legitimately take much longer than a presentation-only story. A slow story is not by
  itself a signal that something is wrong.
- **Keep the merge gate.** It is the only place a human sees the diff before it becomes `main`.
