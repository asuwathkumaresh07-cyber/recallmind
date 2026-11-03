$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$originalPubspec = [System.IO.File]::ReadAllText($pubspecPath)
try {
    [System.IO.File]::WriteAllText($pubspecPath, $originalPubspec + "`nhooks:`n  user_defines:`n    sqlite3:`n      source: system`n      name_windows: winsqlite3`n")
    & (Join-Path $PSScriptRoot 'flutter-local.ps1') test --no-pub
    $testExitCode = $LASTEXITCODE
} finally {
    [System.IO.File]::WriteAllText($pubspecPath, $originalPubspec)
}
exit $testExitCode
