# PreToolUse hook (Write|Edit): blocks writes to protected Sealsworn paths.
# prototype/ is frozen validation evidence; _bmad/ is installer-managed (re-run the installer instead).
# Input: Claude Code hook JSON on stdin. Exit 2 = block the tool call.
$in = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = $in.tool_input.file_path
if ($file -and (($file -replace '\\','/') -match '/(prototype|_bmad)/')) {
  [Console]::Error.WriteLine("BLOCKED: '$file' is a protected path (prototype/ is frozen validation evidence; _bmad/ is installer-managed).")
  exit 2
}
exit 0
