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

# --- Step 3: Setup Python dependencies using uv ---
Write-Host "`n--- Step 3: Setting up Python dependencies using uv ---"

try {
    # 1. Setup uv
    $uvInstallDir = Join-Path $projectRoot "ThirdParty\uv"
    $uvExe = Join-Path $uvInstallDir "uv.exe"

    if (-not (Test-Path $uvExe)) {
        Write-Host "uv not found. Downloading and installing uv..."
        New-Item -Path $uvInstallDir -ItemType Directory -Force | Out-Null
        
        # Directly download the uv executable zip for Windows
        $uvZipUrl = "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip"
        $uvZipPath = Join-Path $env:TEMP "uv.zip"
        
        Invoke-WebRequest -Uri $uvZipUrl -OutFile $uvZipPath -UseBasicParsing
        
        # Extract the contents directly to our target directory
        Expand-Archive -Path $uvZipPath -DestinationPath $uvInstallDir -Force
        
        Remove-Item $uvZipPath -Force

        if (-not (Test-Path $uvExe)) {
            throw "uv installation failed. uv.exe not found in $uvInstallDir"
        }
        Write-Host "uv installed successfully to $uvExe"
    } else {
        Write-Host "uv found at $uvExe"
    }

    # 2. Create a virtual environment
    $venvDir = Join-Path $projectRoot ".venv"
    $pyExe = Join-Path $venvDir "Scripts\python.exe"

    if (-not (Test-Path $pyExe)) {
        Write-Host "Python virtual environment not found. Creating one with uv..."
        # Specify a Python version that uv should find or download
        & $uvExe venv -p 3.11 "$venvDir"
        Write-Host "Virtual environment created at $venvDir"
    } else {
        Write-Host "Python virtual environment already exists at $venvDir"
    }

    # 3. Install requirements
    $requirementsFile = Join-Path $projectRoot 'requirements.txt'
    if (Test-Path $requirementsFile) {
        Write-Host "Installing Python requirements from $requirementsFile..."
        & $uvExe pip install -r "$requirementsFile" --python "$pyExe"
        Write-Host "Python requirements installed successfully." -ForegroundColor Green
    } else {
        Write-Host "Warning: No requirements.txt found. Skipping Python dependency installation." -ForegroundColor Yellow
    }

} catch {
    Write-Error "An error occurred during Python setup with uv: $_"
    exit 1
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
