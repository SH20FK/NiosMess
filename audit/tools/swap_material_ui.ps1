# Phase 7 helper: swap material/cupertino imports to material_ui/cupertino_ui.
#
# Dry-run by default: prints what would change and touches nothing.
# Apply:  powershell -File audit/tools/swap_material_ui.ps1 -Apply
# Revert: git checkout -- pulse_flutter/lib pulse_flutter/test
#
# Never touches *.g.dart, *.freezed.dart, lib/l10n/secret/generated/**.
# Files that import with a prefix ("as foo") are reported, not changed: a prefix
# changes the qualification of every name in the file and must be reviewed.

param(
  [switch]$Apply
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = Join-Path $repoRoot 'pulse_flutter'
if (-not (Test-Path $root)) { throw "project dir not found: $root" }

$targets = @('lib', 'test') | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path $_ }

$files = foreach ($t in $targets) {
  Get-ChildItem -Path $t -Recurse -Filter *.dart -File
}

$material = 0
$cupertino = 0
$prefixed = @()
$changed = @()

foreach ($f in $files) {
  $rel = $f.FullName.Replace($root + '\', '')
  if ($rel -match '\.g\.dart$|\.freezed\.dart$') { continue }
  if ($rel -match '\\l10n\\secret\\generated\\') { continue }

  $text = [System.IO.File]::ReadAllText($f.FullName)
  $original = $text

  if ($text -match "'package:flutter/material\.dart'\s+as\s+\w+" -or
      $text -match "'package:flutter/cupertino\.dart'\s+as\s+\w+") {
    $prefixed += $rel
    continue
  }

  $beforeM = ([regex]::Matches($text, "'package:flutter/material\.dart'")).Count
  $beforeC = ([regex]::Matches($text, "'package:flutter/cupertino\.dart'")).Count
  if ($beforeM -eq 0 -and $beforeC -eq 0) { continue }

  $material += $beforeM
  $cupertino += $beforeC

  $text = $text.Replace("'package:flutter/material.dart'", "'package:material_ui/material_ui.dart'")
  $text = $text.Replace("'package:flutter/cupertino.dart'", "'package:cupertino_ui/cupertino_ui.dart'")

  if ($text -ne $original) {
    $changed += $rel
    if ($Apply) {
      [System.IO.File]::WriteAllText($f.FullName, $text, [System.Text.UTF8Encoding]::new($false))
    }
  }
}

"files to change: $($changed.Count)"
"material imports: $material"
"cupertino imports: $cupertino"
if ($prefixed.Count) {
  "prefixed imports (manual review): $($prefixed.Count)"
  $prefixed | ForEach-Object { "  - $_" }
}
if (-not $Apply) {
  ""
  "dry-run: nothing changed. Apply: powershell -File audit/tools/swap_material_ui.ps1 -Apply"
} else {
  ""
  "applied. Revert: git checkout -- pulse_flutter/lib pulse_flutter/test"
}
