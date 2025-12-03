$esptoolPath = 'esptool.exe'
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path

# Paths to possible images
$recoveryBin = Join-Path $scriptDir 'ESPrecovery.bin'
$firmwareBin = Join-Path $scriptDir 'ESPfirmware.bin'

if (-not (Test-Path $esptoolPath)) {
    Write-Error "esptool not found at: $esptoolPath"
    exit 1
}

# Decide which image to flash and at which offset
$imagePath = $null
$offset    = $null
$desc      = ""

# Priority rule:
#   - If ESPrecovery.bin exists → ALWAYS use it (even if ESPfirmware.bin also exists).
#   - Else if ESPfirmware.bin exists → use it.
if (Test-Path $recoveryBin) {
    if (Test-Path $firmwareBin) {
        Write-Host "Both ESPrecovery.bin and ESPfirmware.bin found. Using ESPrecovery.bin (full flash) by priority." -ForegroundColor Yellow
    }

    $imagePath = $recoveryBin
    $offset    = '0x00000'
    $desc      = "recovery image (full flash)"
}
elseif (Test-Path $firmwareBin) {
    $imagePath = $firmwareBin
    $offset    = '0x10000'
    $desc      = "application firmware (app-only)"
}
else {
    Write-Error "Neither ESPrecovery.bin nor ESPfirmware.bin found next to this script."
    exit 1
}

# Auto-detect ESP32-S3 COM port by VID/PID
$port = (Get-PnpDevice -Class 'Ports' -PresentOnly |
        Where-Object { $_.DeviceID -match 'VID_303A' -and $_.DeviceID -match 'PID_1001' } |
        Select-Object -First 1).Caption -replace '.*\((COM\d+)\).*', '$1'

if ($port -match 'COM\d+') {
    Write-Host "ESP32-S3 found on $port." -ForegroundColor Green
    Write-Host "Flashing $desc from file: $imagePath at offset $offset ..." -ForegroundColor Green

    & $esptoolPath `
        --chip esp32s3 `
        --port $port `
        --baud 921600 `
        --before default-reset `
        --after hard-reset `
        write-flash -z --flash-mode keep --flash-freq keep --flash-size keep `
        $offset $imagePath
}
else {
    Write-Error "Error: ESP32-S3 device (VID:303A PID:1001) not found. Please check connection."
}
