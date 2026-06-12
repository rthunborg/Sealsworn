# Codex CLI → Claude Code Migration Audit (2026-06-10)

## Inventory of agent-instruction surfaces found

| Surface | Location | Status |
|---|---|---|
| `AGENTS.md` (project guide) | repo root | Kept — tool-agnostic, now imported by `CLAUDE.md` |
| `project-context.md` (compact rulebook) | repo root | Kept — no Codex-specific content found |
| `CLAUDE.md` | repo root | **Created in this audit** — imports `@AGENTS.md` |
| Codex BMAD skills (120 dirs, git-tracked) | `.agents/skills/` | Legacy — 45 refreshed by the 2026-06-10 dual-target reinstall, 75 stale orphans from removed modules (cis, bmb, …) |
| Claude Code BMAD skills (45 dirs) | `.claude/skills/` | New install — currently **untracked in git** |
| Codex global instructions | `~/.codex/AGENTS.md` | Docker/WSL conventions; not Sealsworn-relevant (no Docker here). Port to `~/.claude/CLAUDE.md` if still wanted globally |
| Codex hooks | `~/.codex/hooks.json` | Secret-scan + sprint-status gate + eslint/tsc/vitest post-write. The gate script `scripts/sprint-status-gate.sh` **does not exist** in this repo (the hook was already dead). JS/TS hooks target the prototype era, not Godot |
| Codex approval rules | `~/.codex/rules/default.rules` | One `prefix_rule` git-add allowlist referencing files that don't exist in this repo (likely another project). Dropped |
| Codex config | `~/.codex/config.toml` | `approval_policy = "never"`, `sandbox_mode = "danger-full-access"`. Not ported — choose Claude Code permission mode per session instead of a blanket bypass |
| Guard skills (user-level) | `~/.claude/skills/{test-gate, visual-validation, review-round-guard, story-file-audit, frontend-component}` | Resolve in Claude Code, but **test-gate, visual-validation, and frontend-component are written for a Next.js project** (`nextjs-app/`, tsc/eslint/vitest, Playwright, Figma screen IDs) — not this Godot project |
| `docs/` | `docs/playtesting/epic-1-micro-combat-notes.md` | Notes only, no rules files |

## What was ported

- **Advisory conventions** — already centralized in `AGENTS.md`; `CLAUDE.md` now imports it so Claude Code loads them natively, plus Claude-specific notes (test command, skill entry points, canonical epics file, frozen `prototype/`, legacy `.agents/`).
- **Test gate concept** — re-targeted from vitest/tsc to the Godot headless suite; drafted as a `PreToolUse` hook on `sprint-status.yaml` writes (pending approval, see audit conversation).
- **Secret-scan on write** — drafted as a `PreToolUse` hook (direct port of the Codex hook).
- **Protected paths** — drafted as a `PreToolUse` hook blocking writes to `prototype/` and `_bmad/`.
- **review-round-guard / story-file-audit** — remain user-level skills (they need LLM judgment; not portable to shell hooks). Functional as-is.

## What was dropped

- **Visual validation gate** — entirely Next.js/Figma-specific (Playwright screenshot of a dev server vs Figma reference PNGs under `nextjs-app/docs/...`). No Godot equivalent exists and Epic 2 stories carry no Figma screen IDs. Could be rebuilt later on Godot screenshot capture if desired.
- **eslint / tsc / vitest post-write hooks** — prototype-era; production is typed GDScript.
- **`~/.codex/rules/default.rules`** — stale, references another project's files.
- **Codex `approval_policy=never` / full-access sandbox** — intentionally not ported.

## Needs your manual decision

1. **Approve and write the drafted `.claude/settings.json` hooks** (shown in the audit conversation; not yet written). Open sub-questions: is `godot` on PATH for hook subprocesses (or should `GODOT_BIN` be set), and does the headless test runner exit non-zero on failure?
2. **Commit `.claude/skills/`** (currently untracked) so the team/CI shares the install, and **retire `.agents/skills/`** (1,991 tracked files; 75 of 120 skill dirs are stale orphans). Recommended: commit `.claude/`, delete `.agents/` once you stop using Codex on this repo.
3. **(Resolved 2026-06-10)** The sunnyseat/Next.js items were removed from global `~/.claude`: skills `test-gate`, `visual-validation`, `frontend-component`, `story-file-audit`, `bmad-story-brief`; scripts `epic-done.sh`, `sprint-status-gate.sh`, `visual-validate.sh`; and the dead Codex-style hook blocks in `~/.claude/settings.json`. Everything removed (plus the differing cloud-synced variants) is archived verbatim in `~/.claude/legacy-removed-2026-06-10.md`; newer copies live in `C:\Users\Rasmus\sunnyseat\.claude\`. `review-round-guard` stays global, genericized. **Still manual:** delete the four cloud-synced copies (`anthropic-skills:` test-gate, visual-validation, frontend-component, bmad-story-brief) from the claude.ai account via the Claude app's skills settings — the local cache re-syncs from the account, so deleting files doesn't remove them.
4. **BMAD installer answer `primary_platform = ["unity", "unreal", "other"]`** — Godot isn't selected. Re-run the installer if a godot option exists in gds v0.6.0, otherwise leave as "other".
5. **AGENTS.md epics pointer** — it references the GDD-local `epics.md` while `sprint-status.yaml` sources `planning-artifacts/epics.md`. CLAUDE.md clarifies this; optionally fix AGENTS.md itself.
6. **Uncommitted story-creation work** — `sprint-status.yaml` (2-5 → `ready-for-dev`) is modified and `2-5-adaptive-layout-profiles.md` is untracked. Per the AGENTS.md workflow these should be committed before dev starts. Branch is still named `codex/epic-2`; rename only if it bothers you.

## BMAD reinstall verification

- Manifest: core **6.8.0** + gds **v0.6.0** (bmad-game-dev-studio), installed 2026-06-10, targets `claude-code` **and** `codex`.
- All 45 `.claude/skills/` entries resolve in Claude Code (gds-* and bmad-* both listed as invocable skills).
- `sprint-status.yaml` intact: Epic 1 done (stories 1-1 … 1-11), Epic 2 in progress (2-1 … 2-4 done).
- **In-flight story: 2-5 Adaptive Layout Profiles — `ready-for-dev`**, story file present with baseline commit `a322c8b` (current HEAD), no tasks started.
- Headless test runner exists at `godot/tests/headless/test_runner.tscn`.

## Resume normal flow

After approving hooks and committing the pending story files:

```
/gds-dev-story _bmad-output/implementation-artifacts/2-5-adaptive-layout-profiles.md
```

## Appendix: drafted Sealsworn hooks (create under `.claude/`)

**Implemented 2026-06-11 with one change from the draft below:** `protected-paths` and
`sprint-status-gate` are project hooks (committed in `.claude/`), but `secret-scan` was
installed **globally** instead (`~/.claude/hooks/secret-scan.ps1` + `~/.claude/settings.json`)
since "never write secrets" is true in every project. `GODOT_BIN` was not needed — `godot`
is on PATH (verified by a live gate run). All hooks smoke-tested: block and pass-through
cases behave correctly.

### `.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/protected-paths.ps1" },
          { "type": "command", "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/secret-scan.ps1" },
          { "type": "command", "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/sprint-status-gate.ps1", "timeout": 300 }
        ]
      }
    ]
  }
}
```

### `.claude/hooks/protected-paths.ps1`

```powershell
$in = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = $in.tool_input.file_path
if ($file -and (($file -replace '\\','/') -match '/(prototype|_bmad)/')) {
  [Console]::Error.WriteLine("BLOCKED: '$file' is protected (prototype/ is frozen validation evidence; _bmad/ is installer-managed).")
  exit 2
}
exit 0
```

### `.claude/hooks/secret-scan.ps1`

```powershell
$in = [Console]::In.ReadToEnd() | ConvertFrom-Json
$content = "$($in.tool_input.content)$($in.tool_input.new_string)"
if ($content -match 'sk-[A-Za-z0-9]{20,}|Bearer [A-Za-z0-9]{20,}|(?i)(api_key|password|secret)\s*=\s*[''"][^''"]{8,}') {
  [Console]::Error.WriteLine('BLOCKED: possible secret in file write.')
  exit 2
}
exit 0
```

### `.claude/hooks/sprint-status-gate.ps1`

```powershell
$in = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = $in.tool_input.file_path
if (-not $file -or $file -notmatch 'sprint-status\.yaml$') { exit 0 }
$new = "$($in.tool_input.content)$($in.tool_input.new_string)"
if ($new -notmatch ':\s*(review|done)\b') { exit 0 }
$root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }
$out = & $godot --headless --path (Join-Path $root 'godot') --scene res://tests/headless/test_runner.tscn --quit-after 10 2>&1
if ($LASTEXITCODE -ne 0 -or ($out -join "`n") -match 'FAIL') {
  [Console]::Error.WriteLine("TEST GATE FAILED: headless suite must pass before a story moves to review/done.`n" + (($out | Select-Object -Last 15) -join "`n"))
  exit 2
}
exit 0
```

### `.claude/settings.local.json` (gitignored, machine-specific — only if `godot` is not on PATH)

```json
{
  "env": {
    "GODOT_BIN": "C:\\path\\to\\Godot_v4.6.3-stable_win64.exe"
  }
}
```

Open verification points: confirm `godot` resolves in hook subprocesses, and confirm
the test runner's failure output contains `FAIL` (the gate also checks the exit code).
