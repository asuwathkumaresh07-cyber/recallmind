param([Parameter(ValueFromRemainingArguments = $true)][string[]]$FlutterArguments)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$env:FLUTTER_ROOT = Join-Path $projectRoot '.flutter-sdk'
$env:APPDATA = Join-Path $projectRoot '.tool-data'
$env:LOCALAPPDATA = Join-Path $projectRoot '.tool-data'
$env:PUB_CACHE = Join-Path $projectRoot '.pub-cache'
& (Join-Path $env:FLUTTER_ROOT 'bin/cache/dart-sdk/bin/dart.exe') (Join-Path $env:FLUTTER_ROOT 'bin/cache/flutter_tools.snapshot') @FlutterArguments
exit $LASTEXITCODE
