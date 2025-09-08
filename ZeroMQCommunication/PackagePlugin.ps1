# --- Configuration ---
$UeEnginePath = "C:\Program Files\Epic Games\UE_5.3\Engine"
$PluginUpluginPath = Join-Path $PSScriptRoot "ZeroMQCommunication.uplugin"
$PluginName = "ZeroMQCommunication"
$PackageOutputDir = Join-Path $PSScriptRoot "Package"
$FinalPackagePath = Join-Path $PackageOutputDir $PluginName

# --- Path Check ---
if (-not (Test-Path $UeEnginePath)) {
    Write-Error "Unreal Engine path not found: $UeEnginePath"
    Write-Error "Please edit the `$UeEnginePath variable in this script to match your environment."
    Read-Host "Press Enter to exit"
    exit 1
}

# --- Build Plugin ---
Write-Host "Packaging plugin..."
$RunUATPath = Join-Path $UeEnginePath "Build\BatchFiles\RunUAT.bat"
& $RunUATPath BuildPlugin -Plugin="$PluginUpluginPath" -Package="$FinalPackagePath"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Plugin packaging failed."
    Read-Host "Press Enter to exit"
    exit 1
}

# --- Copy DLL ---
Write-Host "Copying DLL..."
$DllSourcePath = Join-Path $PSScriptRoot "Source\ZeroMQCommunication\ThirdParty\ZeroMQ\bin\Win64\libzmq-mt-4_3_5.dll"
$DllDestPath = Join-Path $FinalPackagePath "Binaries\Win64"

if (-not (Test-Path $DllDestPath)) {
    New-Item -ItemType Directory -Path $DllDestPath | Out-Null
}

Copy-Item -Path $DllSourcePath -Destination $DllDestPath -Force
if ($?) {
    Write-Host ""
    Write-Host "====================================" -ForegroundColor Green
    Write-Host " Packaging completed successfully!" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Output location: $FinalPackagePath"
} else {
    Write-Error "DLL copy failed."
}

Read-Host "Press Enter to exit"
