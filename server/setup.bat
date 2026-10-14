@echo off
REM ==============================================================================
REM AstraDeck 1-Click Setup & Background Service Installer for Windows
REM ==============================================================================

echo ============================================================
echo           AstraDeck 1-Click Desktop Companion Setup (Windows)
echo ============================================================

where python >nul 2>nul
if %errorlevel% neq 0 (
    echo [-] Error: Python is required. Please install Python from python.org or Microsoft Store.
    pause
    exit /b 1
)

echo [*] Installing required packages (websockets, psutil)...
python -m pip install websockets psutil --quiet

set "SCRIPT_DIR=%~dp0"
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "VBS_FILE=%STARTUP_FOLDER%\astradeck_silent.vbs"

echo [*] Setting up silent background auto-start...
(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo WshShell.Run "python """ ^& "%SCRIPT_DIR%astradeck_agent.py""" , 0, False
) > "%VBS_FILE%"

echo [*] Starting AstraDeck in background...
wscript "%VBS_FILE%"

where adb >nul 2>nul
if %errorlevel% equ 0 (
    echo [*] Checking for USB connected Android devices...
    adb reverse tcp:8765 tcp:8765 >nul 2>nul
    echo [+] USB reverse tunnel active on port 8765.
)

echo ============================================================
echo [V] Setup complete! AstraDeck Companion is running silently.
echo     It will now start automatically whenever your PC turns on.
echo ============================================================
pause
