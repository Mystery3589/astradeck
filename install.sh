#!/usr/bin/env bash
# ==============================================================================
# AstraDeck Mobile Deployment Script
# Builds the Flutter release/debug APK and installs it onto the connected device
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================="
echo "          AstraDeck Mobile Installer              "
echo "=================================================="

# Check for adb
if ! command -v adb &> /dev/null; then
    echo "[-] Error: 'adb' command not found. Ensure Android SDK platform-tools are in your PATH."
    exit 1
fi

# Check for connected devices
echo "[*] Detecting connected Android devices..."
DEVICES=$(adb devices | grep -v "List" | grep "device$" | awk '{print $1}')

if [ -z "$DEVICES" ]; then
    echo "[-] No Android device detected via adb."
    echo "    Please connect your phone via USB with USB Debugging enabled, or start an emulator."
    exit 1
fi

DEVICE_ID=$(echo "$DEVICES" | head -n 1)
DEVICE_MODEL=$(adb -s "$DEVICE_ID" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
echo "[+] Detected device: $DEVICE_MODEL ($DEVICE_ID)"

# Check flutter
if ! command -v flutter &> /dev/null; then
    echo "[-] Error: 'flutter' command not found."
    exit 1
fi

echo "[*] Resolving dependencies..."
flutter pub get

echo "[*] Building APK..."
flutter build apk --debug

APK_PATH="$SCRIPT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

if [ ! -f "$APK_PATH" ]; then
    echo "[-] Error: Built APK not found at $APK_PATH"
    exit 1
fi

echo "[*] Installing AstraDeck onto $DEVICE_MODEL..."
adb -s "$DEVICE_ID" install -r "$APK_PATH"

echo "[*] Setting up USB ADB reverse tunnel (port 8765)..."
adb -s "$DEVICE_ID" reverse tcp:8765 tcp:8765 || true

echo "[*] Launching AstraDeck..."
adb -s "$DEVICE_ID" shell am force-stop com.nexusdeck.nexus_deck
adb -s "$DEVICE_ID" shell am start -n com.nexusdeck.nexus_deck/com.nexusdeck.nexus_deck.MainActivity > /dev/null 2>&1 || true

echo "=================================================="
echo "[✓] AstraDeck successfully installed and launched!"
echo "=================================================="
