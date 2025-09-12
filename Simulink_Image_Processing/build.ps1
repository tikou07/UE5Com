# build.ps1
# Main build script for the Simulink_Image_Processing project.
# This script handles prerequisite tool setup automatically.
# The actual library and S-Function build is handled by build_sfunctions.m
# Must be run with Administrator privileges.

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
Write-Host "Project root: $projectRoot"

# --- Helper function to find an executable ---
function Find-Executable {
    param (
        [string]$command,
        [string]$localDir = ""
    )
    # 1. Check local project directory first
    if ($localDir -and (Test-Path (Join-Path $localDir $command))) {
        return (Join-Path $localDir $command)
    }
    # 2. Check system PATH
    $found = Get-Command $command -ErrorAction SilentlyContinue
    if ($found) {
        return $found.Source
    }
    return $null
}

# --- Step 1: Setup Git ---
Write-Host "`n--- Step 1: Setting up Git ---"
$gitInstallDir = Join-Path $projectRoot "ThirdParty\git"
$gitExe = Find-Executable "git.exe" (Join-Path $gitInstallDir "cmd")

if (-not $gitExe) {
    Write-Host "Git not found. Downloading and extracting portable Git..."
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.45.2.windows.1/PortableGit-2.45.2-64-bit.7z.exe"
    $gitInstaller = Join-Path $env:TEMP "git_installer.exe"
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
    Write-Host "Extracting Git to $gitInstallDir..."
    New-Item -Path $gitInstallDir -ItemType Directory -Force | Out-Null
    Start-Process -FilePath $gitInstaller -ArgumentList "-o`"$gitInstallDir`" -y" -Wait
    Remove-Item $gitInstaller -Force
    $gitExe = Join-Path $gitInstallDir "cmd\git.exe"
    Write-Host "Git setup complete."
} else {
    Write-Host "Git found at $gitExe."
}

# --- Step 2: Initialize Git Submodules ---
Write-Host "`n--- Step 2: Checking and initializing Git submodules ---"
$zmqDir = Join-Path $projectRoot "ThirdParty\zeromq"
if (-not (Test-Path (Join-Path $zmqDir "CMakeLists.txt"))) {
    Write-Host "ZeroMQ submodule not initialized. Running submodule update..."
    & $gitExe submodule update --init --recursive
    Write-Host "Submodule initialized successfully." -ForegroundColor Green
} else {
    Write-Host "Submodule already initialized."
}

# --- Step 3: Setup Python dependencies using uv ---
Write-Host "`n--- Step 3: Setting up Python dependencies using uv ---"

# Setup MATLAB-compatible Python first
$pythonInstallDir = Join-Path $projectRoot "ThirdParty\python"
$pythonExeForVenv = Join-Path $pythonInstallDir "python.exe"
if (-not (Test-Path $pythonExeForVenv)) {
    Write-Host "MATLAB-compatible Python not found. Downloading Python 3.11 embeddable package..."
    New-Item -Path $pythonInstallDir -ItemType Directory -Force | Out-Null
    $pythonZipUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"
    $pythonZipPath = Join-Path $env:TEMP "python-embed.zip"
    Invoke-WebRequest -Uri $pythonZipUrl -OutFile $pythonZipPath -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($pythonZipPath, $pythonInstallDir)
    Remove-Item $pythonZipPath -Force
    if (-not (Test-Path $pythonExeForVenv)) { throw "Python embeddable package installation failed." }
    Write-Host "MATLAB-compatible Python installed successfully at $pythonInstallDir"
} else {
    Write-Host "MATLAB-compatible Python found at $pythonExeForVenv"
}

# Setup uv
$uvInstallDir = Join-Path $projectRoot "ThirdParty\uv"
$uvExe = Join-Path $uvInstallDir "uv.exe"
if (-not (Test-Path $uvExe)) {
    Write-Host "uv not found. Downloading and installing uv..."
    New-Item -Path $uvInstallDir -ItemType Directory -Force | Out-Null
    $uvZipUrl = "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip"
    $uvZipPath = Join-Path $env:TEMP "uv.zip"
    Invoke-WebRequest -Uri $uvZipUrl -OutFile $uvZipPath -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($uvZipPath, $uvInstallDir)
    Remove-Item $uvZipPath -Force
    if (-not (Test-Path $uvExe)) { throw "uv installation failed." }
    Write-Host "uv installed successfully."
} else {
    Write-Host "uv found at $uvExe"
}

# Create virtual environment using MATLAB-compatible Python
$venvDir = Join-Path $projectRoot ".venv"
$pyExe = Join-Path $venvDir "Scripts\python.exe"
if (-not (Test-Path $pyExe)) {
    Write-Host "Python virtual environment not found. Creating one with MATLAB-compatible Python..."
    & $uvExe venv --python "$pythonExeForVenv" "$venvDir" 2>$null
    Write-Host "Virtual environment created using MATLAB-compatible Python."
} else {
    Write-Host "Python virtual environment already exists. Checking if it uses the correct Python..."
    $currentBasePython = & $pyExe -c "import sys; print(sys._base_executable)" 2>$null
    if ($currentBasePython -ne $pythonExeForVenv) {
        Write-Host "Virtual environment uses different Python. Recreating with MATLAB-compatible Python..."
        Remove-Item -Path $venvDir -Recurse -Force
        & $uvExe venv --python "$pythonExeForVenv" "$venvDir" 2>$null
        Write-Host "Virtual environment recreated using MATLAB-compatible Python."
    } else {
        Write-Host "Virtual environment already uses the correct MATLAB-compatible Python."
    }
}
$pyprojectFile = Join-Path $projectRoot 'pyproject.toml'
if (Test-Path $pyprojectFile) {
    Write-Host "Syncing Python environment with pyproject.toml..."
    # Change directory to the project root so uv can find pyproject.toml
    Push-Location $projectRoot
    & $uvExe sync --python "$pyExe" 2>$null
    Pop-Location
    Write-Host "Python environment synced successfully." -ForegroundColor Green
} else {
    Write-Host "Warning: No pyproject.toml found. Skipping Python dependency installation." -ForegroundColor Yellow
}

# --- Step 4: Setup CMake ---
Write-Host "`n--- Step 4: Setting up CMake ---"
$cmakeInstallDir = Join-Path $projectRoot "ThirdParty\cmake"
$cmakeExe = Find-Executable "cmake.exe" (Join-Path $cmakeInstallDir "bin")
if (-not $cmakeExe) {
    Write-Host "CMake not found. Downloading and extracting CMake..."
    $cmakeUrl = "https://github.com/Kitware/CMake/releases/download/v3.30.1/cmake-3.30.1-windows-x86_64.zip"
    $cmakeZip = Join-Path $env:TEMP "cmake.zip"
    Invoke-WebRequest -Uri $cmakeUrl -OutFile $cmakeZip -UseBasicParsing
    Write-Host "Extracting CMake to $cmakeInstallDir..."
    $tempExtractDir = Join-Path $env:TEMP "cmake_temp_extract"
    if (Test-Path $tempExtractDir) { Remove-Item -Recurse -Force $tempExtractDir }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($cmakeZip, $tempExtractDir)
    $extractedDir = Get-ChildItem -Path $tempExtractDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if ($extractedDir) {
        Move-Item -Path (Join-Path $extractedDir.FullName "*") -Destination $cmakeInstallDir -Force
    }
    Remove-Item -Path $tempExtractDir -Recurse -Force
    Remove-Item -Path $cmakeZip -Force
    Write-Host "CMake setup complete."
} else {
    Write-Host "CMake already exists at $cmakeExe."
}

# --- Step 5: Run MATLAB build script ---
Write-Host "`n--- Step 5: Running MATLAB build script ---"
$matlabExe = Find-Executable "matlab.exe"
if (-not $matlabExe) {
    throw "Could not find matlab.exe. Please ensure MATLAB is installed and its 'bin' directory is in the system's PATH."
}
$logFile = Join-Path $projectRoot "build_log.txt"
if (Test-Path $logFile) {
    try {
        Remove-Item $logFile -Force -ErrorAction Stop
    } catch {
        Write-Warning "Could not delete old log file '$logFile'. It may be locked by another process. This is non-critical; MATLAB will overwrite it."
    }
}

Write-Host "Starting MATLAB to run build_sfunctions.m... Log: $logFile"
$matlabCommand = "try; build_sfunctions; catch e; disp(getReport(e)); exit(1); end; exit(0);"

try {
    & $matlabExe -sd "$projectRoot" -r $matlabCommand -wait -nodesktop -nosplash -logfile "$logFile"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "MATLAB build process failed. Check the log for details: $logFile"
        if (Test-Path $logFile) { Get-Content $logFile | Write-Error }
        exit 1
    }
    Write-Host "MATLAB build process finished successfully." -ForegroundColor Green
}
finally {
    Write-Host "Ensuring all MATLAB processes are terminated."
    Get-Process -Name "MATLAB" -ErrorAction SilentlyContinue | Stop-Process -Force
}

Write-Host "`nBuild process completed successfully."
