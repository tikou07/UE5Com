@echo off
:: build.bat
:: This batch script serves as a simple wrapper to execute the main build.ps1
:: PowerShell script with elevated (Administrator) privileges.

:: Check for Administrator privileges
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else (
    goto gotAdmin
)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%~dp0"

:: Execute the PowerShell build script
echo --- Starting Build Process ---
PowerShell -ExecutionPolicy Bypass -File ".\build.ps1"

echo --- Build Process Finished ---
pause
popd
