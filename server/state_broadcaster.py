"""
AstraDeck Cross-Platform Live State Broadcaster
Pushes real-time system stats (CPU, RAM, Volume), media status, active window titles,
and integration states to connected clients for live button updates and auto-profile switching.
"""

import os
import sys
import shutil
import asyncio
import subprocess
import json
from typing import Dict, Any, Optional

try:
    import psutil
except ImportError:
    psutil = None

from system_controls import CrossPlatformControls
from media_controller import MediaController
from spotify_integration import SpotifyIntegration
from obs_integration import OBSIntegration
from discord_integration import DiscordIntegration

class StateBroadcaster:
    @staticmethod
    def get_os() -> str:
        if sys.platform.startswith("linux"):
            return "linux"
        elif sys.platform in ("win32", "cygwin"):
            return "windows"
        elif sys.platform == "darwin":
            return "darwin"
        return "linux"

    @classmethod
    def get_active_window_title(cls) -> str:
        """Attempts to detect the active window title for auto profile switching."""
        os_name = cls.get_os()

        if os_name == "linux":
            # 1. Try xdotool on X11 / XWayland
            if shutil.which("xdotool"):
                try:
                    res = subprocess.run(
                        ["xdotool", "getactivewindow", "getwindowname"],
                        capture_output=True, text=True, timeout=1
                    )
                    title = res.stdout.strip()
                    if title:
                        return title
                except Exception:
                    pass

            # 2. Try Hyprland active window if available
            if shutil.which("hyprctl"):
                try:
                    res = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=1)
                    if res.returncode == 0 and res.stdout:
                        data = json.loads(res.stdout)
                        return data.get("title") or data.get("class", "")
                except Exception:
                    pass

            # 3. Try Sway active window if available
            if shutil.which("swaymsg"):
                try:
                    res = subprocess.run(["swaymsg", "-t", "get_tree"], capture_output=True, text=True, timeout=1)
                    # best effort
                except Exception:
                    pass

        elif os_name == "darwin":
            script = 'tell application "System Events" to get name of first process whose frontmost is true'
            try:
                res = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=1)
                return res.stdout.strip()
            except Exception:
                pass

        elif os_name == "windows":
            try:
                import win32gui
                hwnd = win32gui.GetForegroundWindow()
                return win32gui.GetWindowText(hwnd) or ""
            except Exception:
                # PowerShell fallback
                ps = '(Get-Process | Where-Object { $_.MainWindowHandle -eq (Get-Process -Id (Get-WmiObject Win32_Process -Filter "Handle=(Get-Item env:HWND).Value").ProcessId).MainWindowHandle }).MainWindowTitle'
                # graceful empty
                return ""

        return ""

    @classmethod
    def get_snapshot(cls) -> Dict[str, Any]:
        """Collects current system, media, window, and integration states."""
        # 1. System CPU and Memory
        cpu = 0
        ram = 0
        if psutil:
            try:
                cpu = round(psutil.cpu_percent(interval=None))
                ram = round(psutil.virtual_memory().percent)
            except Exception:
                pass

        # 2. Volume & Brightness
        vol, brightness = CrossPlatformControls.get_current_state()

        # 3. Media Metadata (Title, Artist, Playing status)
        media_info = MediaController.get_metadata()

        # 4. Active Window Title
        window_title = cls.get_active_window_title()

        return {
            "system": {
                "cpu_percent": cpu,
                "ram_percent": ram,
                "volume": vol,
                "brightness": brightness,
            },
            "media": {
                "title": media_info.get("title", ""),
                "artist": media_info.get("artist", ""),
                "album": media_info.get("album", ""),
                "playing": media_info.get("playing", False),
                "player": media_info.get("player", ""),
            },
            "spotify": SpotifyIntegration.get_state(),
            "window": {
                "title": window_title,
            },
            "obs": OBSIntegration.get_state(),
            "discord": DiscordIntegration.get_state(),
        }
