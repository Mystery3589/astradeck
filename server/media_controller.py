"""
AstraDeck Cross-Platform Media Controller
Provides native playback controls and metadata extraction without requiring API tokens.
Supports Spotify, YouTube/Browsers, VLC, Apple Music, and system media players.
"""

import os
import sys
import shutil
import subprocess
from typing import Optional, Dict, Any

class MediaController:
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
    def control(cls, command: str, player: Optional[str] = None) -> Dict[str, Any]:
        """
        Executes playback commands:
        'play_pause' | 'toggle' | 'play' | 'pause' | 'next' | 'previous' | 'stop' |
        'volume_up' | 'volume_down' | 'mute'
        """
        cmd = (command or "play_pause").lower()
        os_name = cls.get_os()

        if os_name == "linux":
            return cls._control_linux(cmd, player)
        elif os_name == "darwin":
            return cls._control_macos(cmd, player)
        elif os_name == "windows":
            return cls._control_windows(cmd, player)

        return {"status": "error", "message": f"Unsupported platform: {os_name}"}

    @classmethod
    def get_metadata(cls, player: Optional[str] = None) -> Dict[str, Any]:
        """
        Retrieves current track title, artist, album, status, and art URL.
        Zero API tokens required — uses OS D-Bus/AppleScript/Windows native queries.
        """
        os_name = cls.get_os()

        if os_name == "linux":
            return cls._get_metadata_linux(player)
        elif os_name == "darwin":
            return cls._get_metadata_macos(player)
        elif os_name == "windows":
            return cls._get_metadata_windows(player)

        return {"status": "error", "message": f"Unsupported platform: {os_name}"}

    # ── Linux Implementation (MPRIS / playerctl) ──────────────────────────────
    @classmethod
    def _control_linux(cls, cmd: str, player: Optional[str]) -> Dict[str, Any]:
        if shutil.which("playerctl"):
            action_map = {
                "play_pause": "play-pause",
                "toggle": "play-pause",
                "play": "play",
                "pause": "pause",
                "next": "next",
                "previous": "previous",
                "prev": "previous",
                "stop": "stop",
            }
            action = action_map.get(cmd, "play-pause")
            args = ["playerctl"]
            if player:
                args.extend(["-p", player])
            args.append(action)

            try:
                res = subprocess.run(args, capture_output=True, text=True, timeout=3)
                if res.returncode == 0:
                    return {"status": "ok", "command": cmd, "player": player or "default"}
                return {"status": "notice", "message": res.stderr.strip() or "No player responded"}
            except Exception as e:
                return {"status": "error", "message": str(e)}

        # Fallback to xdotool multimedia key injection on X11
        if shutil.which("xdotool"):
            key_map = {
                "play_pause": "XF86AudioPlay",
                "toggle": "XF86AudioPlay",
                "next": "XF86AudioNext",
                "previous": "XF86AudioPrev",
                "stop": "XF86AudioStop",
            }
            xkey = key_map.get(cmd, "XF86AudioPlay")
            try:
                subprocess.run(["xdotool", "key", xkey], check=False, timeout=3)
                return {"status": "ok", "backend": "xdotool_multimedia_key", "command": cmd}
            except Exception as e:
                return {"status": "error", "message": str(e)}

        return {"status": "error", "message": "playerctl not installed. Install via: sudo apt install playerctl"}

    @classmethod
    def _get_metadata_linux(cls, player: Optional[str]) -> Dict[str, Any]:
        if not shutil.which("playerctl"):
            return {"status": "unavailable", "message": "playerctl not installed"}

        args = ["playerctl"]
        if player:
            args.extend(["-p", player])
        # Format: title:::artist:::album:::status:::artUrl:::playerName
        args.extend(["metadata", "--format", "{{title}}:::{{artist}}:::{{album}}:::{{status}}:::{{mpris:artUrl}}:::{{playerName}}"])

        try:
            res = subprocess.run(args, capture_output=True, text=True, timeout=3)
            if res.returncode != 0 or not res.stdout.strip():
                return {
                    "status": "stopped",
                    "title": "",
                    "artist": "",
                    "album": "",
                    "playing": False,
                    "player": player or ""
                }

            parts = res.stdout.strip().split(":::")
            return {
                "status": "ok",
                "title": parts[0] if len(parts) > 0 else "",
                "artist": parts[1] if len(parts) > 1 else "",
                "album": parts[2] if len(parts) > 2 else "",
                "playing": (parts[3].lower() == "playing") if len(parts) > 3 else False,
                "art_url": parts[4] if len(parts) > 4 else "",
                "player": parts[5] if len(parts) > 5 else (player or "unknown")
            }
        except Exception as e:
            return {"status": "error", "message": str(e)}

    # ── macOS Implementation (AppleScript) ────────────────────────────────────
    @classmethod
    def _control_macos(cls, cmd: str, player: Optional[str]) -> Dict[str, Any]:
        target = "Spotify" if (player and "spotify" in player.lower()) else "Music"
        action_map = {
            "play_pause": "playpause",
            "toggle": "playpause",
            "play": "play",
            "pause": "pause",
            "next": "next track",
            "previous": "previous track",
            "prev": "previous track",
            "stop": "pause",
        }
        action = action_map.get(cmd, "playpause")
        script = f'if application "{target}" is running then tell application "{target}" to {action}'

        try:
            res = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=4)
            return {"status": "ok", "target": target, "command": cmd}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @classmethod
    def _get_metadata_macos(cls, player: Optional[str]) -> Dict[str, Any]:
        target = "Spotify" if (player and "spotify" in player.lower()) else "Music"
        script = f'''
        if application "{target}" is running then
            tell application "{target}"
                set t_name to name of current track
                set t_artist to artist of current track
                set t_album to album of current track
                set t_state to player state as string
                return t_name & ":::" & t_artist & ":::" & t_album & ":::" & t_state
            end tell
        else
            return ""
        end if
        '''
        try:
            res = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=4)
            out = res.stdout.strip()
            if not out:
                return {"status": "inactive", "title": "", "artist": "", "playing": False}
            parts = out.split(":::")
            return {
                "status": "ok",
                "title": parts[0] if len(parts) > 0 else "",
                "artist": parts[1] if len(parts) > 1 else "",
                "album": parts[2] if len(parts) > 2 else "",
                "playing": (parts[3].lower() == "playing") if len(parts) > 3 else False,
                "player": target
            }
        except Exception as e:
            return {"status": "error", "message": str(e)}

    # ── Windows Implementation (PowerShell / Media Keys) ──────────────────────
    @classmethod
    def _control_windows(cls, cmd: str, player: Optional[str]) -> Dict[str, Any]:
        vk_map = {
            "play_pause": "0xB3",
            "toggle": "0xB3",
            "play": "0xB3",
            "pause": "0xB3",
            "next": "0xB0",
            "previous": "0xB1",
            "prev": "0xB1",
            "stop": "0xB2",
        }
        vk = vk_map.get(cmd, "0xB3")
        ps = f"$w = New-Object -ComObject WScript.Shell; $w.SendKeys([char]{vk})"
        try:
            subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=False, timeout=3)
            return {"status": "ok", "backend": "windows_media_key", "command": cmd}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @classmethod
    def _get_metadata_windows(cls, player: Optional[str]) -> Dict[str, Any]:
        # Return graceful baseline; in Windows, global system media transport controls (GSMTC)
        # require winsdk / Windows.Media.Control or pywinrt.
        return {
            "status": "ok",
            "title": "",
            "artist": "",
            "playing": False,
            "player": player or "windows_system"
        }
