#!/usr/bin/env bash
# ==============================================================================
# AstraDeck Universal 1-Click Desktop Companion Setup
# Works on fresh PCs via:
#   curl -sSL https://raw.githubusercontent.com/<user>/<repo>/main/server/setup.sh | bash
# Or locally inside the repository.
#
# Idempotent — safe to re-run. Already-running steps print status and skip.
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
INFO_FILE="$HOME/.astradeck/server_info.json"

# Parse optional command-line flags
SETUP_ADB=0
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --adb|-a|--auto-adb)  SETUP_ADB=1 ;;
        --force|-f)            FORCE=1 ;;
    esac
done
if [ "${ASTRADECK_ADB:-0}" = "1" ] || [ "${SETUP_ADB_ENV:-0}" = "1" ]; then
    SETUP_ADB=1
fi

echo "============================================================"
echo "          AstraDeck 1-Click Desktop Companion Setup         "
echo "============================================================"

# ── Helper: read port from server_info.json ───────────────────────────────────
get_running_port() {
    if [ -f "$INFO_FILE" ]; then
        grep -o '"port": [0-9]*' "$INFO_FILE" 2>/dev/null | awk '{print $2}' || echo "8765"
    else
        echo "8765"
    fi
}

# ── IDEMPOTENCY CHECK ─────────────────────────────────────────────────────────
check_already_running() {
    local port
    port="$(get_running_port)"
    # Linux systemd
    if [ "$OS_TYPE" = "Linux" ] && command -v systemctl &>/dev/null; then
        if systemctl --user is-active --quiet astradeck.service 2>/dev/null; then
            echo "[✓] AstraDeck is already running (systemd, port $port)."
            if [ "$FORCE" -eq 0 ]; then
                echo "    • systemctl --user restart astradeck.service  — restart"
                echo "    • systemctl --user status  astradeck.service  — view logs"
                echo "    • bash setup.sh --force                       — reinstall/update"
                return 0
            fi
            echo "[!] --force: reinstalling/updating..."
            return 1
        fi
    fi
    # macOS LaunchAgent
    if [ "$OS_TYPE" = "Darwin" ]; then
        if launchctl list 2>/dev/null | grep -q "com.astradeck.companion"; then
            echo "[✓] AstraDeck is already running (LaunchAgent, port $port)."
            if [ "$FORCE" -eq 0 ]; then
                echo "    Run with --force to reinstall/update."
                return 0
            fi
            echo "[!] --force: reinstalling/updating..."
            return 1
        fi
    fi
    return 1
}

if check_already_running; then
    exit 0
fi

if [ -z "$PYTHON_BIN" ]; then
    echo "[-] Error: python3 is required. Please install Python 3."
    exit 1
fi

echo "[*] Checking Python dependencies (websockets, psutil)..."
if python3 -c "import websockets, psutil" 2>/dev/null; then
    echo "[✓] Python dependencies already satisfied."
else
    echo "[*] Installing required packages (websockets, psutil)..."
    python3 -m pip install websockets psutil --break-system-packages 2>/dev/null || \
    python3 -m pip install websockets psutil 2>/dev/null || \
    pip install websockets psutil 2>/dev/null || true
fi


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
    cp -u "$CURRENT_SCRIPT_DIR/dynamic_function_engine.py" "$INSTALL_DIR/" 2>/dev/null || cp "$CURRENT_SCRIPT_DIR/dynamic_function_engine.py" "$INSTALL_DIR/"
else
    echo "[*] Fetching companion files from GitHub ($GITHUB_REPO)..."
    curl -sSL "$RAW_BASE/astradeck_agent.py" -o "$INSTALL_DIR/astradeck_agent.py"
    curl -sSL "$RAW_BASE/app_lifecycle.py" -o "$INSTALL_DIR/app_lifecycle.py"
    curl -sSL "$RAW_BASE/system_controls.py" -o "$INSTALL_DIR/system_controls.py"
    curl -sSL "$RAW_BASE/dynamic_function_engine.py" -o "$INSTALL_DIR/dynamic_function_engine.py"
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

# ── USB Tethering: NetworkManager shared IPv4 fix (Linux only) ────────────────
# When Android USB Tethering is enabled, the PC side must have an IPv4 address.
# NetworkManager sometimes fails DHCP on RNDIS — force "shared" mode so the PC
# assigns itself 192.168.42.1 and runs a mini DHCP server for the phone.
setup_nm_dispatcher() {
    local DISP_FILE="/etc/NetworkManager/dispatcher.d/99-astradeck-usb-tether"
    if [ -f "$DISP_FILE" ]; then
        echo "[✓] NM dispatcher hook already installed (auto USB-tether fix on plug-in)."
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        echo "[*] Installing NM dispatcher for auto USB-tether IPv4 fix..."
        sudo tee "$DISP_FILE" > /dev/null << 'DISP'
#!/usr/bin/env bash
# AstraDeck: auto-fix USB tethering interface to shared IPv4 on plug-in
IFACE="$1"; ACTION="$2"
[[ "$ACTION" == "up" ]] || exit 0
echo "$IFACE" | grep -qE '^(usb[0-9]+|rndis[0-9]+|enp[0-9]+s[0-9]+f[0-9]+u[0-9]+|enx[0-9a-f]+)$' || exit 0
CON=$(nmcli -t -f NAME,DEVICE con show 2>/dev/null | grep ":${IFACE}$" | cut -d: -f1 | head -1)
[ -n "$CON" ] || exit 0
METHOD=$(nmcli -g ipv4.method con show "$CON" 2>/dev/null)
[ "$METHOD" != "shared" ] || exit 0
nmcli con modify "$CON" ipv4.method shared ipv6.method ignore && nmcli con up "$CON"
DISP
        sudo chmod +x "$DISP_FILE" 2>/dev/null || true
        echo "[✓] NM dispatcher installed — USB tethering auto-fixes on next plug-in."
    else
        echo "[*] (Optional, needs sudo) To auto-fix USB tethering on plug-in:"
        echo "      sudo nmcli con modify 'Wired connection 2' ipv4.method shared"
        echo "      sudo nmcli con up 'Wired connection 2'"
    fi
}

setup_usb_tethering_linux() {
    if ! command -v nmcli &>/dev/null; then return 0; fi
    echo "[*] Checking USB Tethering (RNDIS) network configuration..."

    # Find USB/RNDIS interfaces by name pattern
    RNDIS_IFACES=$(ip link show 2>/dev/null | grep -oE 'usb[0-9]+|rndis[0-9]+|enp[0-9]+s[0-9]+f[0-9]+u[0-9]+|enx[0-9a-f]+' | head -10 || true)

    if [ -z "$RNDIS_IFACES" ]; then
        echo "[*] No USB tethering interface detected yet."
        echo "    → Enable Settings → Network → USB Tethering on your phone, then re-run."
        setup_nm_dispatcher
        return 0
    fi

    for IFACE in $RNDIS_IFACES; do
        echo "[*] Found USB/RNDIS interface: $IFACE"
        NM_CON=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep ":${IFACE}$" | cut -d: -f1 | head -1 || true)
        IFACE_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet )[\d.]+' | head -1 || true)
        if [ -n "$IFACE_IP" ]; then
            echo "[✓]   USB Tethering active on $IFACE ($IFACE_IP)."
            if [ -n "$NM_CON" ] && command -v firewall-cmd &>/dev/null; then
                nmcli con modify "$NM_CON" connection.zone trusted 2>/dev/null || true
            fi
            continue
        fi

        if [ -z "$NM_CON" ]; then
            echo "[*]   No NM connection for $IFACE — creating DHCP profile..."
            nmcli con add type ethernet ifname "$IFACE" con-name "astradeck-usb-tether" \
                connection.zone trusted ipv4.method auto 2>/dev/null || true
            nmcli con up "astradeck-usb-tether" 2>/dev/null || true
        else
            echo "[*]   Connecting '$NM_CON' with trusted zone..."
            nmcli con modify "$NM_CON" connection.zone trusted 2>/dev/null || true
            nmcli con up "$NM_CON" 2>/dev/null || true
            sleep 1
            IFACE_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet )[\d.]+' | head -1 || true)
            if [ -n "$IFACE_IP" ]; then
                echo "[✓]   USB Tethering connected! PC IP: $IFACE_IP"
            fi
        fi
    done
    setup_nm_dispatcher
}

if [ "$OS_TYPE" = "Linux" ]; then
    setup_usb_tethering_linux
elif [ "$OS_TYPE" = "Darwin" ]; then
    echo "[*] USB Tethering on macOS: System Settings → General → Sharing → Internet Sharing"
    echo "    Share your internet to iPhone/Android USB — phone gets 192.168.2.x automatically."
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

    if ! systemctl --user is-enabled --quiet astradeck.service 2>/dev/null; then
        systemctl --user enable astradeck.service
        echo "[✓] Service enabled for auto-start on login."
    else
        echo "[✓] Service already enabled."
    fi

    if systemctl --user is-active --quiet astradeck.service 2>/dev/null; then
        echo "[*] Restarting AstraDeck service (files updated)..."
        systemctl --user restart astradeck.service
    else
        systemctl --user start astradeck.service
    fi

    loginctl enable-linger "$USER" 2>/dev/null || true
    echo "[✓] AstraDeck background service running!"


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
PORT="$(get_running_port)"

# Setup ADB reverse for connected Android phone over USB (idempotent)
ADB_BIN="$(command -v adb || echo "$PLATFORM_TOOLS_DIR/adb")"
if [ -x "$ADB_BIN" ] || command -v adb &>/dev/null; then
    DEVICE_COUNT=$("$ADB_BIN" devices 2>/dev/null | grep -v "List" | grep "device$" | wc -l)
    if [ "$DEVICE_COUNT" -gt 0 ]; then
        EXISTING=$(adb reverse --list 2>/dev/null | grep "tcp:$PORT" || true)
        if [ -n "$EXISTING" ]; then
            echo "[✓] ADB reverse tunnel already active on port $PORT."
        else
            echo "[*] USB Android device detected. Forwarding port $PORT..."
            "$ADB_BIN" reverse tcp:$PORT tcp:$PORT 2>/dev/null || true
            echo "[✓] USB reverse tunnel active on port $PORT."
        fi
    fi
fi

echo "============================================================"
echo "[✓] Setup complete! AstraDeck Companion is running on port $PORT."
echo "    Your phone will connect automatically over:"
echo "      • USB Tethering  (Settings → Network → USB Tethering)"
echo "      • Local Wi-Fi    (same router, zero config)"
echo "      • Bluetooth      (auto-paired)"
if command -v adb &>/dev/null || [ -x "$PLATFORM_TOOLS_DIR/adb" ]; then
    echo "      • ADB USB tunnel (Developer Options → USB Debugging)"
fi
echo "============================================================"
echo "    Re-run anytime — this script is fully idempotent."
echo "    Flags: --force (reinstall/update) | --adb (enable ADB)"
echo "============================================================"
