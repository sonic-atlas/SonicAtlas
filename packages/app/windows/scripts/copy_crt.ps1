$ErrorActionPreference = "Stop"

if (-not $env:VCToolsRedistDir) {
    throw "VCToolsRedistDir is not set. Try running this from a Developer PowerShell"
}

$crtPath = Join-Path $env:VCToolsRedistDir "x64\Microsoft.VC143.CRT"

if (-not (Test-Path $crtPath)) {
    throw "CRT path not found: $crtPath"
}

$dest = Resolve-Path (Join-Path $PSScriptRoot "..\crt")
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$dest | Out-Null

$files = @(
    "vcruntime140.dll",
    "vcruntime140_1.dll",
    "msvcp140.dll"
)

foreach ($f in $files) {
    $src = Join-Path $crtPath $f
    if (Test-Path $src) {
        Copy-Item $src $dest -Force
        Write-Host "Copied $f"
    }
}