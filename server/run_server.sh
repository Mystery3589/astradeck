#!/usr/bin/env bash
# ==============================================================================
# AstraDeck Desktop Companion Launcher
# Starts the background agent for Linux, Windows (Git Bash/WSL), and macOS
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Checking Python 3 requirements..."
if ! command -v python3 &> /dev/null; then
    echo "[-] Error: python3 is required to run AstraDeck Desktop Agent."
    exit 1
fi

# Ensure websockets and psutil are available
python3 -c "import websockets, psutil" 2>/dev/null || {
    echo "[*] Installing required companion packages (websockets, psutil)..."
    python3 -m pip install websockets psutil
}

echo "[*] Starting AstraDeck Desktop Companion..."
exec python3 "$SCRIPT_DIR/astradeck_agent.py"
