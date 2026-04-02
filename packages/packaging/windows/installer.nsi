!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "nsDialogs.nsh"
!include "FileFunc.nsh"
!include "includes\version.nsh"

!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_PNAME}"
!define MUI_ICON "assets\icon.ico"
!define MUI_UNICON "assets\icon.ico"

SetCompressor /SOLID /FINAL lzma

OutFile ".\build\${APP_PNAME}-${APP_VERSION}-setup.exe"

Name "${APP_NAME}"
InstallDir "$PROGRAMFILES64\${APP_PNAME}"

RequestExecutionLevel admin
ShowInstDetails nevershow
ShowUninstDetails nevershow

VIProductVersion "${APP_VERSION}.${APP_BUILD}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "CompanyName" "${COMPANY}"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "FileDescription" "${APP_NAME} Installer"
VIAddVersionKey "LegalCopyright" "© 2026 ${COMPANY}"

; Signing directives
!finalize        'sign-install.bat "%1"' = 0
!uninstfinalize  'sign-install.bat "%1"' = 0

; MUI Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
Page custom OptionsPageCreate OptionsPageLeave
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APP_NAME}"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchApp
!insertmacro MUI_PAGE_FINISH

Function LaunchApp
    Exec '"$INSTDIR\${APP_EXENAME}.exe"'
FunctionEnd

Function InstallGameBarWidget
    DetailPrint "Installing Xbox Game Bar widget..."

    SetOutPath "$TEMP\SonicAtlasGameBar"
    File /r "..\..\gamebar\AppPackages\gamebar_0.1.4.0_x64_Test\*"

    ExecWait 'powershell -ExecutionPolicy Bypass -File "$TEMP\SonicAtlasGameBar\Add-AppDevPackage.ps1" -Silent'
FunctionEnd

!insertmacro MUI_LANGUAGE "English"

; Variables for opts
Var Dialog
Var CheckboxShortcut
Var CheckboxSMShortcut
var CheckboxGameBar

Function OptionsPageCreate
    nsDialogs::Create /NOUNLOAD 1018
    Pop $Dialog

    ${If} $Dialog == error
        Abort
    ${EndIf}

    ; Desktop shortcut
    ${NSD_CreateCheckBox} 0 0 100% 30u "Create shortcut on Desktop"
    Pop $CheckboxShortcut
    ${NSD_SetState} $CheckboxShortcut ${BST_CHECKED}

    ; Start menu shortcut
    ${NSD_CreateCheckBox} 0 35u 100% 30u "Create Start Menu shortcut"
    Pop $CheckboxSMShortcut
    ${NSD_SetState} $CheckboxSMShortcut ${BST_CHECKED}

    ; Xbox Game Bar Widget option
    ${NSD_CreateCheckBox} 0 70u 100% 30u "Install Xbox Game Bar Widget (Beta)"
    Pop $CheckboxGameBar
    ${NSD_SetState} $CheckboxGameBar ${BST_UNCHECKED}

    nsDialogs::Show
FunctionEnd

Function OptionsPageLeave
    ${NSD_GetState} $CheckboxShortcut $0
    StrCpy $CheckboxShortcut $0

    ${NSD_GetState} $CheckboxSMShortcut $0
    StrCpy $CheckboxSMShortcut $0

    ${NSD_GetState} $CheckboxGameBar $0
    StrCpy $CheckboxGameBar $0
FunctionEnd

Section "-Main Program" SEC01
    SetOutPath "$INSTDIR"
    DetailPrint "Installing ${APP_NAME}..."
    File /r "..\..\app\build\windows\x64\runner\Release\*"

    SetRegView 64

    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\${APP_EXENAME}.exe" "" "$INSTDIR\${APP_EXENAME}.exe"
    WriteUninstaller "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${APP_NAME}"

    WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "${COMPANY}"
    WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXENAME}.exe"
    WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
    WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1

    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IfErrors +3 0
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "${UNINST_KEY}" "EstimatedSize" "$0"

    ${If} $CheckboxShortcut == ${BST_CHECKED}
        ${OrIf} $CheckboxSMShortcut == ${BST_CHECKED}
            DetailPrint "Creating shortcuts..."
        ${EndIf}

    ${If} $CheckboxShortcut == ${BST_CHECKED}
        CreateShortCut "$DESKTOP\${APP_EXENAME}.lnk" "$INSTDIR\${APP_EXENAME}.exe"
    ${EndIf}
    ${If} $CheckboxSMShortcut == ${BST_CHECKED}
        CreateDirectory "$SMPROGRAMS\${APP_NAME}"
        CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXENAME}.exe"
    ${EndIf}

    ${If} $CheckboxGameBar == ${BST_CHECKED}
        Call InstallGameBarWidget
        WriteRegDWORD HKCU "Software\${COMPANY}\${APP_NAME}" "InstalledGameBarWidget" 1
    ${EndIf}
SectionEnd

Section "Uninstall"
    ReadRegDWORD $0 HKCU "Software\${COMPANY}\${APP_PNAME}" "InstalledGameBarWidget"
    ${If} $0 == 1
        ExecWait 'powershell -ExecutionPolicy Bypass -Command "Get-AppxPackage dev.sonicatlas.gamebar | Remove-AppxPackage" -Silent'
        DeleteRegValue HKCU "Software\${COMPANY}\${APP_PNAME}" "InstalledGameBarWidget"
    ${EndIf}

    IfFileExists "$DESKTOP\${APP_EXENAME}.lnk" 0 +2
    Delete "$DESKTOP\${APP_EXENAME}.lnk"
    IfFileExists "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" 0 +2
    Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"

    SetRegView 64

    DeleteRegKey HKLM "${UNINST_KEY}"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\App Paths\${APP_EXENAME}.exe"

    RMDir /r "$INSTDIR"
SectionEnd
