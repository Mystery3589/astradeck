param (
    [switch]$Adb   = $false,
    [switch]$Force = $false
)

if ($env:ASTRADECK_ADB -eq "1" -or $env:SETUP_ADB -eq "1") {
    $Adb = $true
}

$Repo = if ($env:ASTRADECK_REPO) { $env:ASTRADECK_REPO } else { "Mystery3589/astradeck" }
$Branch = if ($env:ASTRADECK_BRANCH) { $env:ASTRADECK_BRANCH } else { "main" }
$RawBase = "https://raw.githubusercontent.com/$Repo/$Branch/server"
$InstallDir = "$env:USERPROFILE\.astradeck\server"
$PlatformToolsDir = "$env:USERPROFILE\.astradeck\platform-tools"
$AdbExe = "$PlatformToolsDir\adb.exe"
$InfoFile = "$env:USERPROFILE\.astradeck\server_info.json"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       AstraDeck 1-Click Desktop Companion Setup (Windows)  " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ── Helper: get running port ──────────────────────────────────────────────────
function Get-RunningPort {
    if (Test-Path $InfoFile) {
        $info = Get-Content $InfoFile | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($info.port) { return $info.port }
    }
    return 8765
}

# ── IDEMPOTENCY CHECK ─────────────────────────────────────────────────────────
$AgentRunning = Get-Process -Name python* -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -eq "" } |
    Where-Object { (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine -like "*astradeck_agent*" }

if ($AgentRunning -and -not $Force) {
    $Port = Get-RunningPort
    Write-Host "[✓] AstraDeck is already running (PID $($AgentRunning.Id), port $Port)." -ForegroundColor Green
    Write-Host "    Re-run with -Force to reinstall/update." -ForegroundColor Gray
    return
}
if ($AgentRunning -and $Force) {
    Write-Host "[!] -Force: stopping existing process before reinstall..." -ForegroundColor Yellow
    $AgentRunning | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

# 1. Check Python
$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) {
    Write-Host "[-] Python is not installed. Please install Python from python.org or Microsoft Store." -ForegroundColor Red
    return
}

# 2. Install dependencies (idempotent — pip skips if already installed)
Write-Host "[*] Checking Python packages (websockets, psutil)..." -ForegroundColor Yellow
python -m pip install websockets psutil --quiet

# 3. Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.astradeck" | Out-Null

# 4. Download companion files
Write-Host "[*] Downloading companion agent files..." -ForegroundColor Yellow
Invoke-RestMethod -Uri "$RawBase/astradeck_agent.py"           -OutFile "$InstallDir\astradeck_agent.py"
Invoke-RestMethod -Uri "$RawBase/app_lifecycle.py"             -OutFile "$InstallDir\app_lifecycle.py"
Invoke-RestMethod -Uri "$RawBase/system_controls.py"           -OutFile "$InstallDir\system_controls.py"
Invoke-RestMethod -Uri "$RawBase/dynamic_function_engine.py"   -OutFile "$InstallDir\dynamic_function_engine.py"


# --- Android Debug Bridge (ADB) Auto-Setup ---
function Setup-Adb {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "          Android Debug Bridge (ADB) Auto-Setup             " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    $ExistingAdb = Get-Command adb -ErrorAction SilentlyContinue
    if ($ExistingAdb) {
        Write-Host "[+] System ADB detected: $($ExistingAdb.Source)" -ForegroundColor Green
        & adb start-server 2>$null
        return
    }

    if (Test-Path $AdbExe) {
        Write-Host "[+] Local AstraDeck ADB found at $AdbExe" -ForegroundColor Green
        $env:Path += ";$PlatformToolsDir"
        & $AdbExe start-server 2>$null
        return
    }

    Write-Host "[*] Downloading official Google platform-tools for Windows (~12MB)..." -ForegroundColor Yellow
    $ZipPath = "$env:USERPROFILE\.astradeck\platform-tools.zip"
    $Url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

    try {
        Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
        Write-Host "[*] Extracting platform-tools..." -ForegroundColor Yellow
        Expand-Archive -Path $ZipPath -DestinationPath "$env:USERPROFILE\.astradeck" -Force
        Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

        # Add to User PATH
        $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($UserPath -notlike "*$PlatformToolsDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$UserPath;$PlatformToolsDir", "User")
        }
        $env:Path += ";$PlatformToolsDir"

        Write-Host "[+] ADB installed successfully at $AdbExe" -ForegroundColor Green
        & $AdbExe start-server 2>$null
    } catch {
        Write-Host "[-] Failed to download/extract ADB: $_" -ForegroundColor Red
    }
}

$ExistingAdb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $ExistingAdb -and -not (Test-Path $AdbExe)) {
    if ($Adb) {
        Setup-Adb
    } else {
        Write-Host ""
        Write-Host "[?] ADB (Android Debug Bridge) is not installed." -ForegroundColor Yellow
        Write-Host "    Auto-setting up ADB enables 1-click zero-latency USB" -ForegroundColor Yellow
        Write-Host "    connection with your phone (no manual config needed)." -ForegroundColor Yellow
        $Ans = Read-Host "[?] Would you like to auto-install ADB now? (Y/n)"
        if ($Ans -eq "" -or $Ans -match "^[yY]") {
            Setup-Adb
        } else {
            Write-Host "[*] Skipping ADB setup. (Enable anytime with -Adb or `$env:ASTRADECK_ADB=1)" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "[+] ADB is available and configured." -ForegroundColor Green
}

# 5. Configure silent auto-start in Windows Startup folder
$StartupFolder = [System.Environment]::GetFolderPath('Startup')
$VbsPath = "$StartupFolder\astradeck_silent.vbs"

Write-Host "[*] Registering silent startup task..." -ForegroundColor Yellow
$VbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "python `"$InstallDir\astradeck_agent.py`"", 0, False
"@
Set-Content -Path $VbsPath -Value $VbsContent

# 6. Start the agent immediately in background
Write-Host "[*] Starting AstraDeck in background..." -ForegroundColor Green
wscript.exe "$VbsPath"

# 7. Check for connected Android device via ADB (idempotent)
$AdbCmd = if (Get-Command adb -ErrorAction SilentlyContinue) { "adb" } elseif (Test-Path $AdbExe) { $AdbExe } else { $null }
if ($AdbCmd) {
    $Port = Get-RunningPort
    $Existing = & $AdbCmd reverse --list 2>$null | Where-Object { $_ -like "*tcp:$Port*" }
    if ($Existing) {
        Write-Host "[✓] ADB reverse tunnel already active on port $Port." -ForegroundColor Green
    } else {
        & $AdbCmd reverse tcp:$Port tcp:$Port 2>$null
        Write-Host "[✓] ADB reverse tunnel configured on port $Port." -ForegroundColor Green
    }
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[✓] Setup complete! AstraDeck Companion is running." -ForegroundColor Green
Write-Host "    Your phone will connect automatically over:" -ForegroundColor Green
Write-Host "      - USB Tethering  (Settings -> Network -> USB Tethering)" -ForegroundColor Gray
Write-Host "      - Local Wi-Fi    (same router, zero config)" -ForegroundColor Gray
Write-Host "      - Bluetooth      (auto-paired)" -ForegroundColor Gray
if ($AdbCmd) {
    Write-Host "      - ADB USB tunnel (Developer Options -> USB Debugging)" -ForegroundColor Gray
}
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "    Re-run anytime — this script is fully idempotent." -ForegroundColor Gray
Write-Host "    Flags: -Force (reinstall/update) | -Adb (enable ADB)" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan
