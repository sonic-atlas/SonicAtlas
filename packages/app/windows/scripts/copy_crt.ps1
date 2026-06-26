$ErrorActionPreference = "Stop"

$cl = (Get-Command cl.exe -ErrorAction SilentlyContinue)

if (-not $cl) {
    throw "cl.exe not found. Make sure MSVC environment is loaded (ilammy/msvc-dev-cmd)"
}

$msvcRoot = Split-Path (Split-Path $cl.Source -Parent) -Parent
$msvcRoot = Split-Path $msvcRoot -Parent

$redistRoot = Join-Path $msvcRoot "..\..\..\..\Redist\MSVC"

$redistRoot = Resolve-Path $redistRoot

$crtPath = Get-ChildItem $redistRoot -Directory -Recurse |
    Where-Object { $_.Name -eq "Microsoft.VC143.CRT" } |
    Select-Object -First 1

if (-not $crtPath) {
    throw "Microsoft.VC143.CRT not found."
}

$crtPath = $crtPath.FullName

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