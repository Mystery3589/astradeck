#!/usr/bin/env bash
# ==============================================================================
# AstraDeck Universal 1-Click Desktop Companion Setup
# Works on fresh PCs via:
#   curl -sSL https://raw.githubusercontent.com/<user>/<repo>/main/server/setup.sh | bash
# Or locally inside the repository.
# ==============================================================================

set -e

# Configurable GitHub repository source
GITHUB_REPO="${ASTRADECK_REPO:-Mystery3589/astradeck}"
GITHUB_BRANCH="${ASTRADECK_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/server"

INSTALL_DIR="$HOME/.astradeck/server"
PLATFORM_TOOLS_DIR="$HOME/.astradeck/platform-tools"
PYTHON_BIN="$(which python3 || echo "")"
OS_TYPE="$(uname -s)"

# Parse optional command-line flags
SETUP_ADB=0
for arg in "$@"; do
    case "$arg" in
        --adb|-a|--auto-adb)
            SETUP_ADB=1
            ;;
    esac
done
if [ "${ASTRADECK_ADB:-0}" = "1" ] || [ "${SETUP_ADB_ENV:-0}" = "1" ]; then
    SETUP_ADB=1
fi

echo "============================================================"
echo "          AstraDeck 1-Click Desktop Companion Setup         "
echo "============================================================"

if [ -z "$PYTHON_BIN" ]; then
    echo "[-] Error: python3 is required. Please install Python 3."
    exit 1
fi

echo "[*] Checking Python dependencies (websockets, psutil)..."
python3 -c "import websockets, psutil" 2>/dev/null || {
    echo "[*] Installing required packages (websockets, psutil)..."
    python3 -m pip install websockets psutil --break-system-packages 2>/dev/null || \
    python3 -m pip install websockets psutil 2>/dev/null || \
    pip install websockets psutil 2>/dev/null || true
}

# Determine script source
CURRENT_SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    CURRENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

mkdir -p "$INSTALL_DIR"

# Copy or download files into permanent install location ~/.astradeck/server
if [ -n "$CURRENT_SCRIPT_DIR" ] && [ -f "$CURRENT_SCRIPT_DIR/astradeck_agent.py" ]; then
    echo "[*] Installing from local repository..."
    cp -u "$CURRENT_SCRIPT_DIR/astradeck_agent.py" "$INSTALL_DIR/" 2>/dev/null || cp "$CURRENT_SCRIPT_DIR/astradeck_agent.py" "$INSTALL_DIR/"
    cp -u "$CURRENT_SCRIPT_DIR/app_lifecycle.py" "$INSTALL_DIR/" 2>/dev/null || cp "$CURRENT_SCRIPT_DIR/app_lifecycle.py" "$INSTALL_DIR/"
    cp -u "$CURRENT_SCRIPT_DIR/system_controls.py" "$INSTALL_DIR/" 2>/dev/null || cp "$CURRENT_SCRIPT_DIR/system_controls.py" "$INSTALL_DIR/"
else
    echo "[*] Fetching companion files from GitHub ($GITHUB_REPO)..."
    curl -sSL "$RAW_BASE/astradeck_agent.py" -o "$INSTALL_DIR/astradeck_agent.py"
    curl -sSL "$RAW_BASE/app_lifecycle.py" -o "$INSTALL_DIR/app_lifecycle.py"
    curl -sSL "$RAW_BASE/system_controls.py" -o "$INSTALL_DIR/system_controls.py"
fi

# --- Android Debug Bridge (ADB) Auto-Setup ---
setup_adb() {
    echo "============================================================"
    echo "          Android Debug Bridge (ADB) Auto-Setup             "
    echo "============================================================"

    # 1. Check if ADB is already installed on system
    if command -v adb &>/dev/null; then
        echo "[+] System ADB detected: $(command -v adb)"
        adb version 2>/dev/null | head -n 1 || true
        adb start-server 2>/dev/null || true
        return 0
    fi

    # 2. Check if previously installed in ~/.astradeck/platform-tools
    if [ -x "$PLATFORM_TOOLS_DIR/adb" ]; then
        echo "[+] Local AstraDeck ADB found at: $PLATFORM_TOOLS_DIR/adb"
        export PATH="$PLATFORM_TOOLS_DIR:$PATH"
        "$PLATFORM_TOOLS_DIR/adb" start-server 2>/dev/null || true
        return 0
    fi

    echo "[*] Setting up official Google Android platform-tools..."
    mkdir -p "$PLATFORM_TOOLS_DIR"

    if [ "$OS_TYPE" = "Linux" ]; then
        ADB_URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
    elif [ "$OS_TYPE" = "Darwin" ]; then
        ADB_URL="https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"
    else
        echo "[-] Auto-download not supported on $OS_TYPE"
        return 1
    fi

    echo "[*] Downloading platform-tools for $OS_TYPE (~12MB)..."
    python3 -c "
import urllib.request, zipfile, io, os, sys

url = '$ADB_URL'
dest_dir = os.path.expanduser('~/.astradeck')
os.makedirs(dest_dir, exist_ok=True)
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        z.extractall(dest_dir)
    adb_path = os.path.join(dest_dir, 'platform-tools', 'adb')
    if os.path.exists(adb_path):
        os.chmod(adb_path, 0o755)
        print('[+] Successfully extracted ADB to:', adb_path)
    else:
        print('[-] Extraction completed but adb binary not found at:', adb_path)
        sys.exit(1)
except Exception as e:
    print('[-] Error downloading/extracting ADB:', e)
    sys.exit(1)
" || {
        echo "[-] Could not auto-download platform-tools."
        return 1
    }

    export PATH="$PLATFORM_TOOLS_DIR:$HOME/.local/bin:$PATH"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$PLATFORM_TOOLS_DIR/adb" "$HOME/.local/bin/adb" 2>/dev/null || true

    # Add to shell profile if not already present
    if [ -f "$HOME/.bashrc" ] && ! grep -q "astradeck/platform-tools" "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.astradeck/platform-tools:$PATH"' >> "$HOME/.bashrc"
    fi
    if [ -f "$HOME/.zshrc" ] && ! grep -q "astradeck/platform-tools" "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.astradeck/platform-tools:$PATH"' >> "$HOME/.zshrc"
    fi

    "$PLATFORM_TOOLS_DIR/adb" start-server 2>/dev/null || true
    echo "[+] ADB is now configured and ready for USB connections!"
}

# Decide whether to run ADB setup
if [ "$SETUP_ADB" -eq 1 ]; then
    setup_adb
else
    # If not explicitly requested, check if adb is missing and ask interactively
    if ! command -v adb &>/dev/null && [ ! -x "$PLATFORM_TOOLS_DIR/adb" ]; then
        SHOULD_PROMPT=0
        if [ -c /dev/tty ] || [ -t 0 ]; then
            SHOULD_PROMPT=1
        fi

        if [ "$SHOULD_PROMPT" -eq 1 ]; then
            echo ""
            echo "============================================================"
            echo "[?] ADB (Android Debug Bridge) is not installed."
            echo "    Auto-setting up ADB enables 1-click zero-latency USB"
            echo "    cable connection with your phone (no manual config)."
            echo "============================================================"
            printf "[?] Would you like to auto-setup ADB now? [Y/n]: "
            REPLY=""
            if [ -c /dev/tty ]; then
                read -r REPLY < /dev/tty || true
            else
                read -r REPLY || true
            fi
            case "$REPLY" in
                [nN][oO]|[nN])
                    echo "[*] Skipping ADB setup. (You can enable it anytime with: --adb)"
                    ;;
                *)
                    setup_adb
                    ;;
            esac
        fi
    fi
fi

if [ "$OS_TYPE" = "Linux" ]; then
    echo "[*] Configuring auto-start systemd background service..."
    SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SERVICE_DIR"

    SERVICE_FILE="$SERVICE_DIR/astradeck.service"
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=AstraDeck Desktop Companion Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_BIN $INSTALL_DIR/astradeck_agent.py
Environment="PYTHONUNBUFFERED=1"
Environment="PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PLATFORM_TOOLS_DIR:$PATH"
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now astradeck.service
    loginctl enable-linger "$USER" 2>/dev/null || true
    echo "[+] AstraDeck background service successfully configured & started!"
    echo "    (Auto-starts on boot/login. Runs all backend services silently)"

elif [ "$OS_TYPE" = "Darwin" ]; then
    echo "[*] Configuring macOS LaunchAgent..."
    PLIST_DIR="$HOME/Library/LaunchAgents"
    mkdir -p "$PLIST_DIR"
    PLIST_FILE="$PLIST_DIR/com.astradeck.companion.plist"

    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.astradeck.companion</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON_BIN</string>
        <string>$INSTALL_DIR/astradeck_agent.py</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PLATFORM_TOOLS_DIR</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
</dict>
</plist>
EOF
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load -w "$PLIST_FILE" 2>/dev/null || true
    echo "[+] AstraDeck LaunchAgent installed and running!"
fi

# Query dynamic port from server_info.json
sleep 1.5
INFO_FILE="$HOME/.astradeck/server_info.json"
PORT="8765"
if [ -f "$INFO_FILE" ]; then
    PORT=$(grep -o '"port": [0-9]*' "$INFO_FILE" | awk '{print $2}')
fi

# Setup ADB reverse for connected Android phone over USB
ADB_BIN="$(command -v adb || echo "$PLATFORM_TOOLS_DIR/adb")"
if [ -x "$ADB_BIN" ] || command -v adb &> /dev/null; then
    DEVICE_COUNT=$("$ADB_BIN" devices 2>/dev/null | grep -v "List" | grep "device$" | wc -l)
    if [ "$DEVICE_COUNT" -gt 0 ]; then
        echo "[*] USB Android device detected. Forwarding port $PORT..."
        "$ADB_BIN" reverse tcp:$PORT tcp:$PORT 2>/dev/null || true
        echo "[+] USB reverse tunnel active on port $PORT"
    fi
fi

echo "============================================================"
echo "[✓] Setup complete! AstraDeck Companion is running on port $PORT."
echo "    Your phone will now connect automatically."
echo "============================================================"

