# build.ps1
# Main build script for the MATLAB_Image_Processing project.
# This script must be run with Administrator privileges.

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
    # It's a self-extracting 7z archive. We can run it with -o to specify output dir.
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
    try {
        & $gitExe submodule update --init --recursive
        Write-Host "Submodule initialized successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to initialize submodule. Please ensure Git is installed and run 'git submodule update --init --recursive' manually in the project root."
        exit 1
    }
} else {
    Write-Host "Submodule already initialized."
}

# --- Step 3: Setup Python dependencies ---
Write-Host "`n--- Step 3: Setting up Python dependencies ---"
$pythonInstallDir = Join-Path $projectRoot "python_runtime"
$pyExe = Join-Path $pythonInstallDir "python.exe"

if (-not (Test-Path $pyExe)) {
    Write-Host "Local Python runtime not found. Downloading and extracting Python embeddable package..."
    $pythonUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"
    $pythonZip = Join-Path $env:TEMP "python.zip"
    
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonZip -UseBasicParsing
    
    Write-Host "Extracting Python to $pythonInstallDir..."
    if (-not (Test-Path $pythonInstallDir)) { New-Item -Path $pythonInstallDir -ItemType Directory | Out-Null }
    Expand-Archive -Path $pythonZip -DestinationPath $pythonInstallDir -Force
    
    Remove-Item $pythonZip -Force
    
    # Verify installation
    $pyExe = Join-Path $pythonInstallDir "python.exe"
    if (-not (Test-Path $pyExe)) {
        Write-Error "Python extraction failed. python.exe not found in $pythonInstallDir"
        exit 1
    }
    Write-Host "Python runtime setup complete. Found at $pyExe"
    
    # Update pth file to include site-packages
    $pthFile = Join-Path $pythonInstallDir "python311._pth"
    Add-Content -Path $pthFile -Value "Lib\site-packages"

    # Install pip
    $getPipUrl = "https://bootstrap.pypa.io/get-pip.py"
    $getPipScript = Join-Path $env:TEMP "get-pip.py"
    Invoke-WebRequest -Uri $getPipUrl -OutFile $getPipScript -UseBasicParsing
    & $pyExe $getPipScript
    Remove-Item $getPipScript -Force
    Write-Host "pip installed successfully."
}

$requirementsFile = Join-Path $projectRoot 'requirements.txt'
if (Test-Path $requirementsFile) {
    Write-Host "Installing Python requirements from $requirementsFile..."
    $pipExe = Join-Path $pythonInstallDir "Scripts\pip.exe"
    if (-not (Test-Path $pipExe)) {
        Write-Error "pip.exe not found after installation."
        exit 1
    }
    & $pipExe install -r $requirementsFile
} else {
    Write-Host "Warning: No requirements.txt found. Skipping Python dependency installation." -ForegroundColor Yellow
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
    if (-not (Test-Path $cmakeInstallDir)) { New-Item -Path $cmakeInstallDir -ItemType Directory | Out-Null }
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

# --- Step 5: Run MATLAB build script ---
Write-Host "`n--- Step 5: Running MATLAB build script ---"
$matlabExe = Find-Executable "matlab.exe"

if (-not $matlabExe) {
    throw "Could not find matlab.exe. Please ensure MATLAB is installed and its 'bin' directory is in the system's PATH."
}

$logFile = Join-Path $projectRoot "build_log.txt"
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

Write-Host "Starting MATLAB in $projectRoot... Output will be logged to $logFile"

try {
    & $matlabExe -sd "$projectRoot" -r "run_build" -wait -nodesktop -nosplash -logfile $logFile

    if ($LASTEXITCODE -ne 0) {
        Write-Error "MATLAB build process failed. Check the log for details: $logFile"
        Get-Content $logFile | Write-Error
        exit 1
    }

    Write-Host "MATLAB build process finished." -ForegroundColor Green
}
finally {
    # --- Finalization: Kill any lingering MATLAB processes ---
    Write-Host "Ensuring all MATLAB processes are terminated."
    Get-Process -Name "MATLAB" -ErrorAction SilentlyContinue | Stop-Process -Force
}

Write-Host "`nBuild process completed."
