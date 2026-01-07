:: Creating cert (in powershell):
:: $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=Sonic Atlas" -KeyUsage DigitalSignature -CertStoreLocation "Cert:\CurrentUser\My"
:: $password = ConvertTo-SecureString -String "StrongPassword" -Force -AsPlainText
:: Export-PfxCertificate -Cert $cert -FilePath "C:\certs\SonicAtlas.pfx" -Password $password

@ECHO OFF
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION

:: --- Config ---
set CERT_PATH=C:\certs\SonicAtlas.pfx
set CERT_PASS=StrongPassword
set TIMESTAMP_URL=http://timestamp.digicert.com
:: --- End of Config ---

if "%1"=="" (
    echo Usage: %0 InstallerFile.exe
    exit /b 1
)

set "FILE_TO_SIGN=%~1"

where signtool >nul 2>nul
if errorlevel 1 (
    echo signtool not found
    exit /b 1
)

echo Signing file: %FILE_TO_SIGN% ...
signtool sign ^
    /f "%CERT_PATH%" ^
    /p "%CERT_PASS%" ^
    /tr "%TIMESTAMP_URL%" ^
    /td sha256 ^
    /fd sha256 ^
    /d "Sonic Atlas Installer" ^
    /du "https://github.com/sonic-atlas" ^
    "%FILE_TO_SIGN%"

if %ERRORLEVEL% NEQ 0 (
    echo Failed to sign file %FILE_TO_SIGN%
    exit /b 1
)

echo File signed successfully: %FILE_TO_SIGN%
exit /b 0