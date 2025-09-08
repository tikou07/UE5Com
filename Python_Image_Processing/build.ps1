# build.ps1
# Main build script for the Python_Image_Processing project.

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$logFile = Join-Path $projectRoot "build_log.txt"
Start-Transcript -Path $logFile -Force

Write-Host "Project root: $projectRoot"
Write-Host "Log file: $logFile"

# --- Setup Python dependencies using uv ---
Write-Host "`n--- Setting up Python dependencies using uv ---"

try {
    # 1. Setup uv
    $uvInstallDir = Join-Path $projectRoot "ThirdParty\uv"
    $uvExe = Join-Path $uvInstallDir "uv.exe"

    if (-not (Test-Path $uvExe)) {
        Write-Host "uv not found. Downloading and installing uv..."
        New-Item -Path $uvInstallDir -ItemType Directory -Force | Out-Null
        
        $uvZipUrl = "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip"
        $uvZipPath = Join-Path $env:TEMP "uv.zip"
        
        Invoke-WebRequest -Uri $uvZipUrl -OutFile $uvZipPath -UseBasicParsing
        
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
        & $uvExe venv -p 3.11 "$venvDir"
        Write-Host "Virtual environment created at $venvDir"
    } else {
        Write-Host "Python virtual environment already exists at $venvDir"
    }

    # 3. Sync dependencies from pyproject.toml
    $pyprojectFile = Join-Path $projectRoot 'pyproject.toml'
    if (Test-Path $pyprojectFile) {
        Write-Host "Syncing Python environment with $pyprojectFile..."
        & $uvExe sync --python "$pyExe"
        Write-Host "Python environment synced successfully." -ForegroundColor Green
    } else {
        Write-Host "Warning: No pyproject.toml found. Skipping Python dependency installation." -ForegroundColor Yellow
    }

} catch {
    Write-Error "An error occurred during Python setup with uv: $_"
    Stop-Transcript
    exit 1
}

# --- Quick test for pyzmq import ---
Write-Host "`n--- Testing library imports ---"
try {
    & $pyExe -c "import zmq, numpy, cv2; print('Successfully imported zmq, numpy, and cv2.')"
    Write-Host "Python environment test successful." -ForegroundColor Green
} catch {
    Write-Host "Error: Python environment test failed. Key libraries (zmq, numpy, cv2) could not be imported." -ForegroundColor Red
    Write-Host "Please check the installation logs for errors."
}

Write-Host "`nBuild process completed."
Stop-Transcript
