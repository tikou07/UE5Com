@echo off
setlocal

:: --- Configuration ---
set "PROJECT_ROOT=%~dp0"
set "CMAKE_CHECK_FILE=%PROJECT_ROOT%ThirdParty\cmake\bin\cmake.exe"
set "PS_SCRIPT=%PROJECT_ROOT%setup.ps1"

:: --- Main Logic ---
echo --- Simulink Image Processing Dependency Setup Script ---

:: 1. Check if dependencies are already set up
if exist "%CMAKE_CHECK_FILE%" (
    echo Dependencies already set up. Exiting.
    pause
    exit /b 0
)

:: 2. If not, run the setup with Administrator privileges
echo Dependencies not found. Setup process will be initiated.
echo Requesting administrative privileges to run setup...

>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    goto :UACPrompt
) else (
    goto :run_setup
)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    :: Pass a flag to the script to indicate it's being run as admin
    echo UAC.ShellExecute "cmd.exe", "/C ""%~s0"" :run_setup", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:run_setup
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%~dp0"
    echo --- Running Dependency Setup (Admin Privileges) ---
    PowerShell -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -SetupOnly
    if %errorlevel% neq 0 (
        echo ERROR: Dependency setup failed.
        pause
        exit /b %errorlevel%
    )
    echo --- Dependency Setup Finished ---
    popd
    echo.
    echo --- Dependency Setup Finished Successfully ---
    pause
    exit /b 0
)
