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

# --- Step 1: Initialize Git Submodules ---
Write-Host "`n--- Step 1: Checking and initializing Git submodules ---"
$zmqDir = Join-Path $projectRoot "ThirdParty\zeromq"
if (-not (Test-Path (Join-Path $zmqDir "CMakeLists.txt"))) {
    Write-Host "ZeroMQ submodule not initialized. Running 'git submodule update --init --recursive'..."
    try {
        git submodule update --init --recursive
        Write-Host "Submodule initialized successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to initialize submodule. Please run 'git submodule update --init --recursive' manually in the project root."
        exit 1
    }
} else {
    Write-Host "Submodule already initialized."
}

# --- Step 2: Setup Python dependencies (from setup_environment.ps1) ---
Write-Host "`n--- Step 2: Setting up Python dependencies ---"
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

# --- Step 3: Setup CMake (from setup_environment.ps1) ---
Write-Host "`n--- Step 3: Setting up CMake ---"
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

# --- Step 4: Run MATLAB build script ---
Write-Host "`n--- Step 4: Running MATLAB build script ---"
function Find-MatlabExe {
    # 1. Try to find via Get-Command (if in PATH)
    try {
        $matlabExe = (Get-Command matlab -ErrorAction Stop).Source
        if ($matlabExe) {
            Write-Host "Found MATLAB executable in PATH: $matlabExe"
            return $matlabExe
        }
    } catch {}

    # 2. Search common installation directories
    Write-Host "MATLAB not found in PATH. Searching common installation locations..."
    $programFiles = ${env:ProgramFiles}
    $matlabRoot = Get-ChildItem -Path "$programFiles\MATLAB" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -match '^R\d{4}[ab]$' } |
                  Sort-Object Name -Descending |
                  Select-Object -First 1
    
    if ($matlabRoot) {
        $matlabExe = Join-Path $matlabRoot.FullName "bin\matlab.exe"
        if (Test-Path $matlabExe) {
            Write-Host "Found MATLAB executable at: $matlabExe"
            return $matlabExe
        }
    }

    return $null
}

try {
    # Find matlab.exe
    $matlabExe = Find-MatlabExe
    if (-not $matlabExe) {
        throw "Could not find matlab.exe. Please ensure MATLAB is installed and that its 'bin' directory is in the system's PATH environment variable."
    }
    
    $logFile = Join-Path $projectRoot "build_log.txt"
    if (Test-Path $logFile) {
        Remove-Item $logFile
    }
    
    Write-Host "Starting MATLAB in $projectRoot... Output will be logged to $logFile"
    
    # Use the call operator (&) and MATLAB's -logfile option for robustness
    & $matlabExe -r "run_build" -wait -nodesktop -nosplash -logfile $logFile
    
    # Check the exit code from MATLAB
    if ($LASTEXITCODE -ne 0) {
        Write-Error "MATLAB build process failed. Check the log for details: $logFile"
        # Display the log content in the console for immediate feedback
        Get-Content $logFile | Write-Error
        exit 1
    }
    
    Write-Host "MATLAB build process finished." -ForegroundColor Green
} catch {
    Write-Error "An error occurred while trying to run MATLAB."
    Write-Error $_
    exit 1
}

Write-Host "`nBuild process completed."
