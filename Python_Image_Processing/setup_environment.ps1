# setup_environment.ps1
# Environment setup for Python_Image_Processing.
# Installs Python dependencies into the local python_runtime.

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
Write-Host "Project root: $projectRoot"

# --- Setup Python dependencies ---
Write-Host "`n--- Setting up Python dependencies ---"
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
    & $pipPath install -r $requirementsFile
} else {
    Write-Host "Warning: No requirements.txt found. Skipping Python dependency installation." -ForegroundColor Yellow
}

# --- Quick test for pyzmq import ---
Write-Host "`n--- Testing library imports ---"
try {
    & $pyExe -c "import zmq, numpy, cv2; print('Successfully imported zmq, numpy, and cv2.')"
    Write-Host "Python environment test successful." -ForegroundColor Green
} catch {
    Write-Host "Error: Python environment test failed. Key libraries (zmq, numpy, cv2) could not be imported." -ForegroundColor Red
    Write-Host "Please check the installation logs above for errors."
}

Write-Host "`nSetup finished."
