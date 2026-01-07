# Install powershell-yaml for processing YAML
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force
}

$yaml = Get-Content "../common/app.yaml" -Raw | ConvertFrom-Yaml

$version = "$($yaml.version.major).$($yaml.version.minor).$($yaml.version.patch)"
$build = $yaml.version.build

@"
!define APP_NAME "$($yaml.displayName)"
!define APP_PNAME "$($yaml.name)"
!define APP_EXENAME "$($yaml.exeName)"
!define APP_ID "$($yaml.id)"
!define APP_VERSION "$version"
!define APP_BUILD "$build"
!define COMPANY "$($yaml.company)"
"@ | Out-File "./includes/version.nsh" -Encoding utf8
