& "$PSScriptRoot/get_crt.ps1"
& "$PSScriptRoot/gen_nsis_version.ps1"

makensis "./installer.nsi"