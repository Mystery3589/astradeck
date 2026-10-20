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
PYTHON_BIN="$(which python3 || echo "")"

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

OS_TYPE="$(uname -s)"

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
Environment="PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"
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
if command -v adb &> /dev/null; then
    DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device$" | wc -l)
    if [ "$DEVICE_COUNT" -gt 0 ]; then
        echo "[*] USB Android device detected. Forwarding port $PORT..."
        adb reverse tcp:$PORT tcp:$PORT 2>/dev/null || true
        echo "[+] USB reverse tunnel active on port $PORT"
    fi
fi

echo "============================================================"
echo "[✓] Setup complete! AstraDeck Companion is running on port $PORT."
echo "    Your phone will now connect automatically."
echo "============================================================"
