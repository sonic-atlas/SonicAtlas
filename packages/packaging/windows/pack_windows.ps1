$ErrorActionPreference = 'Stop'

$appDir = Join-Path $PSScriptRoot "../../app"
Push-Location $appDir
try {
    Write-Host "Generating licenses..." -ForegroundColor Cyan
    dart run dart_pubspec_licenses:generate
    dart run ../packaging/common/gen_extra_licenses.dart
}
finally {
    Pop-Location
}

& (Join-Path $PSScriptRoot "gen_nsis_version.ps1")
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\build" | Out-Null
makensis "./installer.nsi"