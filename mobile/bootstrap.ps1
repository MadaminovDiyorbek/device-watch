$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$flutterBat = Join-Path $repoRoot "tools\flutter\bin\flutter.bat"

if (-not (Test-Path $flutterBat)) {
    Write-Host "Flutter SDK yo'q: $flutterBat"
    Write-Host "Birinchi marta: git clone --depth 1 -b stable https://github.com/flutter/flutter.git `"$($repoRoot)\tools\flutter`""
    exit 1
}

$appDir = Join-Path $PSScriptRoot "device_watch_app"
if (-not (Test-Path $appDir)) {
    Write-Host "Yo'q: $appDir"
    exit 1
}

Set-Location $appDir

if (-not (Test-Path (Join-Path $appDir "android"))) {
    Write-Host "flutter create . ..."
    & $flutterBat create . --project-name device_watch_app
}

& $flutterBat pub get
Write-Host "Tayyor. Keyin: & `"$flutterBat`" run (device_watch_app ichida)"
