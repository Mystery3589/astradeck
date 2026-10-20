# ==============================================================================
# AstraDeck Universal 1-Click Desktop Companion Setup (Windows PowerShell)
# Run via:
#   irm https://raw.githubusercontent.com/<user>/<repo>/main/server/setup.ps1 | iex
# ==============================================================================

$Repo = if ($env:ASTRADECK_REPO) { $env:ASTRADECK_REPO } else { "Mystery3589/astradeck" }
$Branch = if ($env:ASTRADECK_BRANCH) { $env:ASTRADECK_BRANCH } else { "main" }
$RawBase = "https://raw.githubusercontent.com/$Repo/$Branch/server"
$InstallDir = "$env:USERPROFILE\.astradeck\server"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       AstraDeck 1-Click Desktop Companion Setup (Windows)  " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Check Python
$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) {
    Write-Host "[-] Python is not installed. Please install Python from python.org or Microsoft Store." -ForegroundColor Red
    return
}

# 2. Install dependencies
Write-Host "[*] Checking Python packages (websockets, psutil)..." -ForegroundColor Yellow
python -m pip install websockets psutil --quiet

# 3. Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# 4. Download companion files
Write-Host "[*] Downloading companion agent files..." -ForegroundColor Yellow
Invoke-RestMethod -Uri "$RawBase/astradeck_agent.py" -OutFile "$InstallDir\astradeck_agent.py"
Invoke-RestMethod -Uri "$RawBase/app_lifecycle.py" -OutFile "$InstallDir\app_lifecycle.py"
Invoke-RestMethod -Uri "$RawBase/system_controls.py" -OutFile "$InstallDir\system_controls.py"

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

# 7. Check for connected Android device via ADB
$Adb = Get-Command adb -ErrorAction SilentlyContinue
if ($Adb) {
    adb reverse tcp:8765 tcp:8765 2>$null
    Write-Host "[+] ADB reverse tunnel configured on port 8765." -ForegroundColor Green
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[✓] Setup complete! AstraDeck Companion is running silently." -ForegroundColor Green
Write-Host "    It will now auto-start whenever you log into Windows." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
