$ErrorActionPreference = "Stop"
Set-Location -Path "$PSScriptRoot\.."

$FormatFiles = Get-ChildItem -Path "src" -Include *.cpp, *.hpp -Recurse | Select-Object -ExpandProperty FullName
$TidyFiles = Get-ChildItem -Path "src" -Include *.cpp -Recurse | Select-Object -ExpandProperty FullName

$CcPath = "build\msvc-debug\compile_commands.json"
if (Test-Path $CcPath) {
    (Get-Content $CcPath) -replace '-mno-direct-extern-access', '' | Set-Content $CcPath
}

& clang-format --style=file --fallback-style=none -i $FormatFiles
& clang-tidy -p build\msvc-debug $TidyFiles
Set-Location -Path "$PSScriptRoot"