"""
AstraDeck Cross-Platform Hotkey & Text Injector
Supports Linux (X11 & Wayland), macOS, and Windows.
"""

import os
import sys
import shutil
import subprocess
from typing import List, Union

class HotkeyInjector:
    @staticmethod
    def get_os() -> str:
        if sys.platform.startswith("linux"):
            return "linux"
        elif sys.platform in ("win32", "cygwin"):
            return "windows"
        elif sys.platform == "darwin":
            return "darwin"
        return "linux"

    @staticmethod
    def is_wayland() -> bool:
        return os.environ.get("XDG_SESSION_TYPE", "").lower() == "wayland" or "WAYLAND_DISPLAY" in os.environ

    @classmethod
    def send_hotkey(cls, keys: Union[List[str], str]) -> dict:
        """
        Injects a key combination into the currently focused window.
        `keys` can be a list: ["ctrl", "alt", "t"] or a string "ctrl+alt+t".
        """
        if isinstance(keys, str):
            # Split by '+' or ' '
            raw_keys = [k.strip() for k in keys.replace("+", " ").split() if k.strip()]
        else:
            raw_keys = [str(k).strip() for k in keys if str(k).strip()]

        if not raw_keys:
            return {"status": "error", "message": "No keys provided"}

        os_name = cls.get_os()

        if os_name == "linux":
            return cls._send_hotkey_linux(raw_keys)
        elif os_name == "darwin":
            return cls._send_hotkey_macos(raw_keys)
        elif os_name == "windows":
            return cls._send_hotkey_windows(raw_keys)

        return {"status": "error", "message": f"Unsupported platform: {os_name}"}

    @classmethod
    def type_text(cls, text: str) -> dict:
        """Types or pastes text directly into the focused window."""
        if not text:
            return {"status": "ok", "message": "Empty text"}

        os_name = cls.get_os()

        if os_name == "linux":
            return cls._type_text_linux(text)
        elif os_name == "darwin":
            return cls._type_text_macos(text)
        elif os_name == "windows":
            return cls._type_text_windows(text)

        return {"status": "error", "message": f"Unsupported platform: {os_name}"}

    # ── Linux Implementation ──────────────────────────────────────────────────
    @classmethod
    def _send_hotkey_linux(cls, keys: List[str]) -> dict:
        wayland = cls.is_wayland()

        # 1. Try Wayland tools if session is Wayland
        if wayland:
            # Try wtype
            if shutil.which("wtype"):
                # wtype modifiers: -M ctrl, -k key
                cmd = ["wtype"]
                pressed_mods = []
                final_keys = []
                for k in keys:
                    norm = k.lower()
                    if norm in ("ctrl", "control"):
                        cmd.extend(["-M", "ctrl"])
                        pressed_mods.append("ctrl")
                    elif norm in ("alt", "mod1"):
                        cmd.extend(["-M", "alt"])
                        pressed_mods.append("alt")
                    elif norm in ("shift",):
                        cmd.extend(["-M", "shift"])
                        pressed_mods.append("shift")
                    elif norm in ("super", "win", "meta", "logo"):
                        cmd.extend(["-M", "logo"])
                        pressed_mods.append("logo")
                    else:
                        final_keys.append(k)

                for fk in final_keys:
                    cmd.extend(["-k", fk.lower()])

                # Release modifiers
                for mod in pressed_mods:
                    cmd.extend(["-m", mod])

                try:
                    res = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
                    if res.returncode == 0:
                        return {"status": "ok", "backend": "wtype", "keys": keys}
                except Exception:
                    pass

            # Try ydotool
            if shutil.which("ydotool"):
                # ydotool key keycode:1 keycode:0
                # ydotool accepts key names or combinations like ctrl+alt+t
                combo = "+".join(keys)
                try:
                    res = subprocess.run(["ydotool", "key", combo], capture_output=True, text=True, timeout=3)
                    if res.returncode == 0:
                        return {"status": "ok", "backend": "ydotool", "keys": keys}
                except Exception:
                    pass

        # 2. Try xdotool (works natively on X11 and on XWayland apps)
        if shutil.which("xdotool"):
            combo = "+".join(keys)
            try:
                res = subprocess.run(["xdotool", "key", "--clearmodifiers", combo], capture_output=True, text=True, timeout=3)
                if res.returncode == 0:
                    return {"status": "ok", "backend": "xdotool", "keys": keys}
            except Exception:
                pass

        # 3. Fallback to ydotool even if not wayland
        if shutil.which("ydotool"):
            try:
                res = subprocess.run(["ydotool", "key", "+".join(keys)], capture_output=True, text=True, timeout=3)
                if res.returncode == 0:
                    return {"status": "ok", "backend": "ydotool", "keys": keys}
            except Exception:
                pass

        return {
            "status": "error",
            "message": "No functional hotkey injector found. Install 'wtype', 'ydotool', or 'xdotool'."
        }

    @classmethod
    def _type_text_linux(cls, text: str) -> dict:
        if cls.is_wayland():
            if shutil.which("wtype"):
                try:
                    res = subprocess.run(["wtype", "--", text], capture_output=True, text=True, timeout=5)
                    if res.returncode == 0:
                        return {"status": "ok", "backend": "wtype", "chars": len(text)}
                except Exception:
                    pass
            if shutil.which("ydotool"):
                try:
                    res = subprocess.run(["ydotool", "type", "--", text], capture_output=True, text=True, timeout=5)
                    if res.returncode == 0:
                        return {"status": "ok", "backend": "ydotool", "chars": len(text)}
                except Exception:
                    pass

        if shutil.which("xdotool"):
            try:
                res = subprocess.run(["xdotool", "type", "--clearmodifiers", "--", text], capture_output=True, text=True, timeout=5)
                if res.returncode == 0:
                    return {"status": "ok", "backend": "xdotool", "chars": len(text)}
            except Exception:
                pass

        return {"status": "error", "message": "No typing utility found. Install 'wtype' or 'xdotool'."}

    # ── macOS Implementation ──────────────────────────────────────────────────
    @classmethod
    def _send_hotkey_macos(cls, keys: List[str]) -> dict:
        # Map common keys to AppleScript modifier syntax
        modifiers = []
        regular_key = None

        for k in keys:
            norm = k.lower()
            if norm in ("cmd", "command"):
                modifiers.append("command down")
            elif norm in ("ctrl", "control"):
                modifiers.append("control down")
            elif norm in ("alt", "opt", "option"):
                modifiers.append("option down")
            elif norm in ("shift",):
                modifiers.append("shift down")
            else:
                regular_key = k

        if not regular_key:
            return {"status": "error", "message": "No base key specified in hotkey combo"}

        using_clause = f" using {{{', '.join(modifiers)}}}" if modifiers else ""
        escaped_key = regular_key.replace('"', '\\"')

        # Special AppleScript key codes for arrows, return, tab, escape
        key_code_map = {
            "return": 36, "enter": 36,
            "tab": 48,
            "space": 49,
            "delete": 51, "backspace": 51,
            "escape": 53, "esc": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        }

        if escaped_key.lower() in key_code_map:
            code = key_code_map[escaped_key.lower()]
            script = f'tell application "System Events" to key code {code}{using_clause}'
        else:
            script = f'tell application "System Events" to keystroke "{escaped_key}"{using_clause}'

        try:
            res = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=4)
            if res.returncode == 0:
                return {"status": "ok", "backend": "osascript", "keys": keys}
            return {"status": "error", "message": res.stderr.strip()}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @classmethod
    def _type_text_macos(cls, text: str) -> dict:
        escaped = text.replace('\\', '\\\\').replace('"', '\\"')
        script = f'tell application "System Events" to keystroke "{escaped}"'
        try:
            res = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                return {"status": "ok", "backend": "osascript", "chars": len(text)}
            return {"status": "error", "message": res.stderr.strip()}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    # ── Windows Implementation ────────────────────────────────────────────────
    @classmethod
    def _send_hotkey_windows(cls, keys: List[str]) -> dict:
        # 1. Try pyautogui if installed
        try:
            import pyautogui
            pyautogui.hotkey(*[k.lower() for k in keys])
            return {"status": "ok", "backend": "pyautogui", "keys": keys}
        except ImportError:
            pass

        # 2. Fallback to PowerShell WScript.Shell SendKeys
        # SendKeys representation: ^ = Ctrl, + = Shift, % = Alt
        mod_prefix = ""
        base_key = ""
        for k in keys:
            norm = k.lower()
            if norm in ("ctrl", "control"):
                mod_prefix += "^"
            elif norm in ("shift",):
                mod_prefix += "+"
            elif norm in ("alt",):
                mod_prefix += "%"
            else:
                base_key = k

        send_str = f"{mod_prefix}{{{base_key.upper()}}}" if len(base_key) > 1 else f"{mod_prefix}{base_key}"
        ps = f"$ws = New-Object -ComObject WScript.Shell; $ws.SendKeys('{send_str}')"
        try:
            subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=False, timeout=3)
            return {"status": "ok", "backend": "powershell_sendkeys", "keys": keys}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @classmethod
    def _type_text_windows(cls, text: str) -> dict:
        try:
            import pyautogui
            pyautogui.write(text)
            return {"status": "ok", "backend": "pyautogui", "chars": len(text)}
        except ImportError:
            pass

        # Fallback using clipboard paste in PowerShell
        ps = f"Set-Clipboard -Value @'\n{text}\n'@; $ws = New-Object -ComObject WScript.Shell; $ws.SendKeys('^v')"
        try:
            subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=False, timeout=5)
            return {"status": "ok", "backend": "powershell_clipboard", "chars": len(text)}
        except Exception as e:
            return {"status": "error", "message": str(e)}
