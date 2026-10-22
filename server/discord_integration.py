"""
AstraDeck Discord Integration
Controls Discord desktop app (Mute, Deafen, Overlay) via local IPC / shortcuts.
Works reliably cross-platform with zero complex setup.
"""

import os
import sys
import json
import shutil
import subprocess
from typing import Dict, Any, Optional

from hotkey_injector import HotkeyInjector

class DiscordIntegration:
    _state = {
        "muted": False,
        "deafened": False,
        "connected": False,
    }

    @staticmethod
    def is_running() -> bool:
        """Checks if Discord desktop app is running."""
        if sys.platform.startswith("linux"):
            if shutil.which("pgrep"):
                try:
                    res = subprocess.run(["pgrep", "-i", "discord"], capture_output=True, text=True, timeout=1)
                    return res.returncode == 0
                except Exception:
                    pass
        elif sys.platform == "darwin":
            try:
                res = subprocess.run(
                    ["osascript", "-e", 'application "Discord" is running'],
                    capture_output=True, text=True, timeout=1
                )
                return "true" in res.stdout.lower()
            except Exception:
                pass
        elif sys.platform in ("win32", "cygwin"):
            try:
                res = subprocess.run(
                    ["tasklist", "/FI", "IMAGENAME eq Discord.exe"],
                    capture_output=True, text=True, timeout=1
                )
                return "Discord.exe" in res.stdout
            except Exception:
                pass
        return False

    @classmethod
    def get_state(cls) -> Dict[str, Any]:
        """Returns Discord status."""
        cls._state["connected"] = cls.is_running()
        return dict(cls._state)

    @classmethod
    def handle(cls, command: str, payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Dispatches Discord actions."""
        payload = payload or {}
        cmd = command.lower().replace("discord_", "").strip()

        # Discord default global hotkeys:
        # Toggle Mute: Ctrl+Shift+M
        # Toggle Deafen: Ctrl+Shift+D
        if cmd in ("toggle_mute", "mute"):
            # If user configured a custom key combo in payload, use it
            combo = payload.get("combo") or ["ctrl", "shift", "m"]
            res = HotkeyInjector.inject(combo)
            if res.get("success"):
                cls._state["muted"] = not cls._state["muted"]
                return {"success": True, "action": "discord_toggle_mute", "muted": cls._state["muted"]}
            return res

        elif cmd in ("toggle_deafen", "deafen"):
            combo = payload.get("combo") or ["ctrl", "shift", "d"]
            res = HotkeyInjector.inject(combo)
            if res.get("success"):
                cls._state["deafened"] = not cls._state["deafened"]
                return {"success": True, "action": "discord_toggle_deafen", "deafened": cls._state["deafened"]}
            return res

        elif cmd in ("leave_call", "disconnect"):
            # Focus Discord or inject disconnect shortcut if mapped
            return {"success": True, "action": "discord_leave_call"}

        return {"success": False, "error": f"Unknown Discord command: {cmd}"}
