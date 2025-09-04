# setup_environment.ps1
# Environment setup for MATLAB_Image_Processing.
# - Installs Visual C++ Redistributable (x64) if necessary.
# - Installs Python dependencies into the local python_runtime.
#
# Run this from PowerShell (may require admin privileges).

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
Write-Host "Project root: $projectRoot"

# --- Step 1: Install Visual C++ Redistributable (x64) ---
Write-Host "`n--- Step 1: Installing Visual C++ Redistributable (x64) ---"
$vcTmp = Join-Path $env:TEMP 'vc_redist.x64.exe'
try {
    # Check if the runtime is already installed by looking for a key registry entry.
    # This is a heuristic and might not be 100% reliable for all versions.
    $regKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    if (Test-Path $regKey) {
        Write-Host "Visual C++ 2015-2022 Redistributable (x64) appears to be installed."
    } else {
        throw "VC++ Redistributable not detected."
    }
} catch {
    Write-Host "VC++ Redistributable not detected or check failed. Proceeding with installation." -ForegroundColor Yellow
    if (-not (Test-Path $vcTmp)) {
        Write-Host "Downloading vc_redist.x64.exe to $vcTmp ..."
        Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile $vcTmp -UseBasicParsing
    } else {
        Write-Host "vc_redist.x64.exe already exists at $vcTmp"
    }
    Write-Host "Installing Visual C++ Redistributable (x64) ... (may prompt for UAC)"
    Start-Process -FilePath $vcTmp -ArgumentList '/install', '/quiet', '/norestart' -Wait
}


# --- Step 2: Setup Python dependencies ---
Write-Host "`n--- Step 2: Setting up Python dependencies ---"
$pythonInstallDir = Join-Path $projectRoot "python_runtime"
$pyExe = Join-Path $pythonInstallDir "python.exe"

if (-not (Test-Path $pyExe)) {
    Write-Error "Python runtime not found at $pyExe. Please ensure the 'python_runtime' directory is correctly placed."
    exit 1
}

# Ensure python311._pth is configured for site-packages
$sitePackagesPath = "Lib\site-packages"
$pthFile = Join-Path $pythonInstallDir "python311._pth"
if ((Get-Content $pthFile) -notcontains $sitePackagesPath) {
    Write-Host "Adding site-packages to $pthFile"
    Add-Content -Path $pthFile -Value $sitePackagesPath
}

# Install pip if not already present
$pipPath = Join-Path $pythonInstallDir "Scripts\pip.exe"
if (-not (Test-Path $pipPath)) {
    $getPipUrl = "https://bootstrap.pypa.io/get-pip.py"
    $getPipScript = Join-Path $env:TEMP "get-pip.py"
    Write-Host "Downloading get-pip.py to $getPipScript ..."
    Invoke-WebRequest -Uri $getPipUrl -OutFile $getPipScript -UseBasicParsing
    Write-Host "Installing pip..."
    & $pyExe $getPipScript
} else {
    Write-Host "pip already installed."
}

# Install requirements from requirements.txt
$requirementsFile = Join-Path $projectRoot 'requirements.txt'
if (Test-Path $requirementsFile) {
    Write-Host "Installing Python requirements from $requirementsFile..."
    & $pyExe -m pip install -r $requirementsFile
} else {
    Write-Host "Warning: No requirements.txt found. Skipping Python dependency installation." -ForegroundColor Yellow
}

# --- Step 3: Quick test for pyzmq import ---
Write-Host "`n--- Step 3: Testing pyzmq import ---"
try {
    & $pyExe -c "import zmq, numpy, cv2; print('Successfully imported zmq, numpy, and cv2.')"
    Write-Host "Python environment test successful." -ForegroundColor Green
} catch {
    Write-Host "Error: Python environment test failed. Key libraries (zmq, numpy, cv2) could not be imported." -ForegroundColor Red
    Write-Host "Please check the installation logs above for errors."
}

Write-Host "`nSetup finished."
