$ErrorActionPreference = "Stop"

$FfmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-lgpl-shared.zip"
$OutputDir = Join-Path $PSScriptRoot "ffmpeg\windows-x64"
$ZipFile = Join-Path $PSScriptRoot "ffmpeg.zip"

Write-Host "Downloading FFmpeg LGPL (Shared) for Windows..."
Invoke-WebRequest -Uri $FfmpegUrl -OutFile $ZipFile

Write-Host "Extracting..."
Expand-Archive -Path $ZipFile -DestinationPath $PSScriptRoot -Force

$ExtractedFolder = Get-ChildItem -Path $PSScriptRoot -Filter "ffmpeg-*-win64-lgpl-shared" | Select-Object -First 1

if ($null -eq $ExtractedFolder) {
    Write-Error "Could not find extracted FFmpeg folder."
}

if (Test-Path $OutputDir) { Remove-Item -Recurse -Force $OutputDir }
New-Item -ItemType Directory -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Path "$OutputDir\include" | Out-Null
New-Item -ItemType Directory -Path "$OutputDir\lib" | Out-Null
New-Item -ItemType Directory -Path "$OutputDir\bin" | Out-Null

Write-Host "Copying artifacts to $OutputDir..."
Copy-Item -Recurse "$($ExtractedFolder.FullName)\include\*" "$OutputDir\include\"
Copy-Item -Recurse "$($ExtractedFolder.FullName)\lib\*" "$OutputDir\lib\"
Copy-Item -Recurse "$($ExtractedFolder.FullName)\bin\*.dll" "$OutputDir\bin\"

Remove-Item -Recurse -Force $ExtractedFolder.FullName
Remove-Item -Force $ZipFile

Write-Host "Done!"