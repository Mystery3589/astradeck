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

set "SETUP_ADB=0"
if /i "%~1"=="--adb" set "SETUP_ADB=1"
if /i "%~1"=="-a" set "SETUP_ADB=1"
if "%ASTRADECK_ADB%"=="1" set "SETUP_ADB=1"
if "%SETUP_ADB_ENV%"=="1" set "SETUP_ADB=1"

set "PLATFORM_TOOLS_DIR=%USERPROFILE%\.astradeck\platform-tools"
set "ADB_EXE=%PLATFORM_TOOLS_DIR%\adb.exe"

where adb >nul 2>nul
if %errorlevel% neq 0 (
    if not exist "%ADB_EXE%" (
        if "%SETUP_ADB%"=="1" (
            call :InstallAdb
        ) else (
            echo.
            echo ============================================================
            echo [?] ADB (Android Debug Bridge) is not installed.
            echo     Auto-setting up ADB enables 1-click zero-latency USB
            echo     cable connection with your phone (no manual config).
            echo ============================================================
            set /p "ADB_CHOICE=[?] Would you like to auto-setup ADB now? (Y/n): "
            if /i not "!ADB_CHOICE!"=="n" (
                call :InstallAdb
            )
        )
    )
)

where adb >nul 2>nul
if %errorlevel% equ 0 (
    set "ADB_CMD=adb"
) else if exist "%ADB_EXE%" (
    set "ADB_CMD=%ADB_EXE%"
) else (
    set "ADB_CMD="
)

if defined ADB_CMD (
    echo [*] Checking for USB connected Android devices...
    "%ADB_CMD%" reverse tcp:8765 tcp:8765 >nul 2>nul
    echo [+] USB reverse tunnel active on port 8765.
)

echo ============================================================
echo [V] Setup complete! AstraDeck Companion is running silently.
echo     It will now start automatically whenever your PC turns on.
echo ============================================================
pause
exit /b 0

:InstallAdb
echo [*] Downloading official Google Android platform-tools for Windows...
powershell -NoProfile -Command ^
    "$ProgressPreference = 'SilentlyContinue';" ^
    "New-Item -ItemType Directory -Force -Path '%USERPROFILE%\.astradeck' | Out-Null;" ^
    "$zip = '%USERPROFILE%\.astradeck\platform-tools.zip';" ^
    "Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip -UseBasicParsing;" ^
    "Expand-Archive -Path $zip -DestinationPath '%USERPROFILE%\.astradeck' -Force;" ^
    "Remove-Item $zip -Force -ErrorAction SilentlyContinue;" ^
    "$userPath = [Environment]::GetEnvironmentVariable('Path', 'User');" ^
    "if ($userPath -notlike '*platform-tools*') { [Environment]::SetEnvironmentVariable('Path', $userPath + ';%PLATFORM_TOOLS_DIR%', 'User') };"
if exist "%ADB_EXE%" (
    echo [+] ADB successfully installed to %ADB_EXE%
    "%ADB_EXE%" start-server >nul 2>nul
)
exit /b 0
