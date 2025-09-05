# build.ps1
# Main build script for the MATLAB_Image_Processing project.
# This script must be run with Administrator privileges.
#
# It performs the following steps:
# 1. Sets up Python dependencies.
# 2. Sets up CMake.
# 3. Executes the MATLAB MEX build script.

$ErrorActionPreference = 'Stop'

# --- Ensure the script is run as Administrator ---
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run with Administrator privileges. Please re-run from an elevated PowerShell prompt."
    exit 1
}

$projectRoot = $PSScriptRoot
Write-Host "Project root: $projectRoot"

# --- Step 1: Setup Python dependencies (from setup_environment.ps1) ---
Write-Host "`n--- Step 1: Setting up Python dependencies ---"
$pythonInstallDir = Join-Path $projectRoot "python_runtime"
$pyExe = Join-Path $pythonInstallDir "python.exe"

if (-not (Test-Path $pyExe)) {
    Write-Error "Python runtime not found at $pyExe. Please ensure the 'python_runtime' directory is correctly placed."
    exit 1
}
$requirementsFile = Join-Path $projectRoot 'requirements.txt'
if (Test-Path $requirementsFile) {
    Write-Host "Installing Python requirements from $requirementsFile..."
    & $pyExe -m pip install -r $requirementsFile
} else {
    Write-Host "Warning: No requirements.txt found. Skipping Python dependency installation." -ForegroundColor Yellow
}

# --- Step 2: Setup CMake (from setup_environment.ps1) ---
Write-Host "`n--- Step 2: Setting up CMake ---"
$cmakeInstallDir = Join-Path $projectRoot "ThirdParty\cmake"
if (-not (Test-Path $cmakeInstallDir)) {
    New-Item -Path $cmakeInstallDir -ItemType Directory | Out-Null
}
$cmakeExe = Join-Path $cmakeInstallDir "bin\cmake.exe"

if (-not (Test-Path $cmakeExe)) {
    Write-Host "CMake not found. Downloading and extracting CMake..."
    $cmakeUrl = "https://github.com/Kitware/CMake/releases/download/v3.30.1/cmake-3.30.1-windows-x86_64.zip"
    $cmakeZip = Join-Path $env:TEMP "cmake.zip"
    
    Invoke-WebRequest -Uri $cmakeUrl -OutFile $cmakeZip -UseBasicParsing
    
    Write-Host "Extracting CMake to $cmakeInstallDir..."
    Expand-Archive -Path $cmakeZip -DestinationPath $env:TEMP -Force
    
    $extractedDir = Get-ChildItem -Path $env:TEMP | Where-Object { $_.PSIsContainer -and $_.Name -like 'cmake-*' } | Select-Object -First 1
    if ($extractedDir) {
        Move-Item -Path (Join-Path $extractedDir.FullName "*") -Destination $cmakeInstallDir -Force
        Remove-Item -Path $extractedDir.FullName -Recurse -Force
    }
    
    Remove-Item -Path $cmakeZip -Force
    Write-Host "CMake setup complete."
} else {
    Write-Host "CMake already exists at $cmakeExe."
}

# --- Step 3: Run MATLAB build script ---
Write-Host "`n--- Step 3: Running MATLAB build script ---"
try {
    # Find matlab.exe
    $matlabExe = (Get-Command matlab).Source
    if (-not $matlabExe) {
        throw "matlab.exe not found in system PATH."
    }
    
    $argumentList = @(
        "-r",
        "run_build",
        "-wait",
        "-nodesktop",
        "-nosplash"
    )
    
    $logFile = Join-Path $projectRoot "build_log.txt"
    Write-Host "Starting MATLAB in $projectRoot... Output will be logged to $logFile"
    
    Start-Process -FilePath $matlabExe -ArgumentList $argumentList -WorkingDirectory $projectRoot -Wait -NoNewWindow -RedirectStandardOutput $logFile -RedirectStandardError $logFile
    
    Write-Host "MATLAB build process finished." -ForegroundColor Green
} catch {
    Write-Error "An error occurred while trying to run MATLAB."
    Write-Error $_
    exit 1
}

Write-Host "`nBuild process completed."
