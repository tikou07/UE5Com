# setup_environment.ps1
# Unified environment setup for Simulink_Image_Processing.
# - Installs Visual C++ Redistributable (x64)
# - Downloads and extracts Python 3.11 embeddable to python_runtime
# - Installs pip and requirements.txt
# - Tests pyzmq import
# - Launches MATLAB to run startup.m (which will configure MATLAB-side settings)
#
# Run this from PowerShell (may require admin privileges for VC runtime install).

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
Write-Host "Project root: $projectRoot"

# --- Step 1: Install vcpkg and ZeroMQ ---
Write-Host "`n--- Step 1: Installing vcpkg and ZeroMQ ---"
$vcpkgRoot = "$env:LOCALAPPDATA\vcpkg"
if (-not (Test-Path "$vcpkgRoot\vcpkg.exe")) {
    Write-Host "vcpkg not found. Please install it by following the instructions at https://vcpkg.io/" -ForegroundColor Yellow
    Write-Host "Attempting to install vcpkg to $vcpkgRoot..."
    if (Test-Path $vcpkgRoot) {
        Remove-Item -Recurse -Force $vcpkgRoot
    }
    git clone https://github.com/Microsoft/vcpkg.git $vcpkgRoot
    & "$vcpkgRoot\bootstrap-vcpkg.bat"
}

& "$vcpkgRoot\vcpkg.exe" remove zeromq:x64-windows --recurse
Write-Host "Installing zeromq:x64-windows via vcpkg..."
& "$vcpkgRoot\vcpkg.exe" install zeromq:x64-windows

$vcpkgInstalledDir = "$vcpkgRoot\packages\zeromq_x64-windows"
$zmqLibPath = Join-Path $vcpkgInstalledDir "lib\libzmq-mt-4_3_5.lib"
$zmqDllPath = Join-Path $vcpkgInstalledDir "bin\libzmq-mt-4_3_5.dll"

$projectLibDir = Join-Path $projectRoot "ThirdParty\lib\Win64"
$projectBinDir = Join-Path $projectRoot "ThirdParty\bin\Win64"

if (-not (Test-Path $projectLibDir)) {
    New-Item -ItemType Directory -Path $projectLibDir -Force
}
if (-not (Test-Path $projectBinDir)) {
    New-Item -ItemType Directory -Path $projectBinDir -Force
}

Copy-Item -Path $zmqLibPath -Destination (Join-Path $projectLibDir "libzmq-v143-mt-s-4_3_5.lib") -Force
Copy-Item -Path $zmqDllPath -Destination (Join-Path $projectBinDir "libzmq-mt-4_3_5.dll") -Force

# --- Step 2: Install Visual C++ Redistributable (x64) ---
Write-Host "`n--- Step 1: Installing Visual C++ Redistributable (x64) ---"
$vcTmp = Join-Path $env:TEMP 'vc_redist.x64.exe'
if (-not (Test-Path $vcTmp)) {
    Write-Host "Downloading vc_redist.x64.exe to $vcTmp ..."
    Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile $vcTmp -UseBasicParsing
} else {
    Write-Host "vc_redist.x64.exe already exists at $vcTmp"
}
Write-Host "Installing Visual C++ Redistributable (x64) ... (may prompt UAC)"
Start-Process -FilePath $vcTmp -ArgumentList '/install','/quiet','/norestart' -Wait

# --- Step 2: Setup Python (embeddable) and venv-like environment ---
Write-Host "`n--- Step 2: Setting up embedded Python runtime ---"
$pythonInstallDir = Join-Path $projectRoot "python_runtime"
$pyExe = Join-Path $pythonInstallDir "python.exe"

if (Test-Path $pyExe) {
    Write-Host "Python already exists at $pyExe. Skipping download/extract."
} else {
    $tmpZip = Join-Path $env:TEMP 'python-3.11.6-embed-amd64.zip'
    $url = 'https://www.python.org/ftp/python/3.11.6/python-3.11.6-embed-amd64.zip'

    if (-Not (Test-Path $tmpZip)) {
        Write-Host "Downloading Python embeddable package..."
        Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing
        Write-Host "Downloaded package to $tmpZip"
    } else {
        Write-Host "Package already exists at $tmpZip"
    }

    Write-Host "Extracting Python to $pythonInstallDir"
    Expand-Archive -Path $tmpZip -DestinationPath $pythonInstallDir -Force
}

if (-not (Test-Path $pyExe)) {
    Write-Error "Python extraction failed or python.exe not found at $pyExe"
    exit 1
}

# Ensure python311._pth contains site-packages line
$sitePackagesPath = "Lib\site-packages"
$pthFile = Join-Path $pythonInstallDir "python311._pth"
$pthContent = @"
python311.zip
.
$sitePackagesPath
"@
Set-Content -Path $pthFile -Value $pthContent -Encoding UTF8NoBOM

Write-Host "Found python: $pyExe"

# Install pip (get-pip.py)
$getPipUrl = "https://bootstrap.pypa.io/get-pip.py"
$getPipScript = Join-Path $env:TEMP "get-pip.py"
Write-Host "Downloading get-pip.py to $getPipScript ..."
Invoke-WebRequest -Uri $getPipUrl -OutFile $getPipScript -UseBasicParsing
Write-Host "Installing pip..."
& $pyExe $getPipScript

# Install requirements from Simulink_Image_Processing/requirements.txt if present
$requirementsFile = Join-Path $projectRoot 'requirements.txt'
$pipPath = Join-Path $pythonInstallDir "Scripts\pip.exe"
if (-not (Test-Path $pipPath)) {
    Write-Error "pip installation failed or pip.exe not found at $pipPath"
    exit 1
}

if (Test-Path $requirementsFile) {
    Write-Host "Installing Python requirements from $requirementsFile..."
    & $pipPath install -r $requirementsFile
} else {
    Write-Host "No requirements.txt found at $requirementsFile. Skipping pip install."
}

# --- Step 3: Quick test for pyzmq import ---
Write-Host "`n--- Step 3: Testing pyzmq import ---"
try {
    & $pyExe -c "import zmq,sys; print('sys.executable=', sys.executable); print('zmq version=', getattr(zmq, '__version__', 'unknown'));"
} catch {
    Write-Host "Warning: pyzmq import test failed. If you rely on zmq in MATLAB/Python, please check installation." -ForegroundColor Yellow
}

# --- Step 4: Launch MATLAB to run startup.m and build_sfunctions.m ---
Write-Host "`n--- Step 4: Launching MATLAB to configure environment and build S-Functions ---"
$matlabExe = 'matlab'  # Assume matlab is available in PATH. If not, please run MATLAB manually.
$startupMFull = Join-Path $projectRoot 'startup.m'
$buildSfunctionsMFull = Join-Path $projectRoot 'build_sfunctions.m'

if (-not (Test-Path $startupMFull)) {
    Write-Host "Error: startup.m not found at $startupMFull" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $buildSfunctionsMFull)) {
    Write-Host "Error: build_sfunctions.m not found at $buildSfunctionsMFull" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $startupMFull)) {
    Write-Host "Error: startup.m not found at $startupMFull" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $buildSfunctionsMFull)) {
    Write-Host "Error: build_sfunctions.m not found at $buildSfunctionsMFull" -ForegroundColor Red
    exit 1
}

$logFile = Join-Path $projectRoot 'matlab_build.log'
Stop-Process -Name "matlab" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}
$matlabCommand = "run('$startupMFull'); exit;"
Write-Host "Running: matlab -r ""$matlabCommand"" -logfile ""$logFile"""
# Use Start-Process to run matlab with -logfile and capture exit code
$p = Start-Process -FilePath $matlabExe -ArgumentList '-r', $matlabCommand, '-logfile', $logFile -NoNewWindow -Wait -PassThru

if (Test-Path $logFile) {
    Write-Host "`n--- MATLAB Build Log ---"
    Get-Content $logFile
    Write-Host "--- End of MATLAB Log ---"
}

if ($p.ExitCode -ne 0) {
    Write-Host "MATLAB process exited with error code: $($p.ExitCode)." -ForegroundColor Red
    Write-Host "Setup failed. Please check the MATLAB log above for details." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nMATLAB process completed successfully."
}

Write-Host "`nSetup finished."
