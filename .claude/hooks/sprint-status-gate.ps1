# PreToolUse hook (Write|Edit): test gate on story status transitions.
# When sprint-status.yaml is written with a story moving to review/done, the full
# headless Godot suite must pass first (AGENTS.md "Mandatory Story Workflow").
# The runner prints "FAIL <script>" per failing test and exits with the failure count.
# Input: Claude Code hook JSON on stdin. Exit 2 = block the tool call.
$in = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = $in.tool_input.file_path
if (-not $file -or $file -notmatch 'sprint-status\.yaml$') { exit 0 }
$new = "$($in.tool_input.content)$($in.tool_input.new_string)"
if ($new -notmatch ':\s*(review|done)\b') { exit 0 }
$root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }
$out = & $godot --headless --path (Join-Path $root 'godot') --scene res://tests/headless/test_runner.tscn --quit-after 10 2>&1
if ($LASTEXITCODE -ne 0 -or ($out -join "`n") -match '(?m)^FAIL ') {
  [Console]::Error.WriteLine("TEST GATE FAILED: the headless suite must pass before a story moves to review/done.`n" + (($out | Select-Object -Last 15) -join "`n"))
  exit 2
}
exit 0
