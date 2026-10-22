"""
AstraDeck Native Spotify Integration
Controls the local Spotify desktop app across Linux, macOS, and Windows.
Zero external Spotify API keys or Spotify Premium subscription required.
Communicates directly via OS-level IPC (MPRIS / AppleScript / Media Keys).
"""

import sys
import shutil
import subprocess
from typing import Dict, Any, Optional

class SpotifyIntegration:
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
    def is_running(cls) -> bool:
        """Checks if Spotify desktop client is currently running."""
        os_name = cls.get_os()
        if os_name == "linux":
            if shutil.which("playerctl"):
                try:
                    res = subprocess.run(
                        ["playerctl", "-l"],
                        capture_output=True, text=True, timeout=1
                    )
                    return "spotify" in res.stdout.lower()
                except Exception:
                    pass
            # Fallback to pgrep
            if shutil.which("pgrep"):
                try:
                    res = subprocess.run(["pgrep", "-i", "spotify"], capture_output=True, text=True, timeout=1)
                    return res.returncode == 0
                except Exception:
                    pass
        elif os_name == "darwin":
            try:
                res = subprocess.run(
                    ["osascript", "-e", 'application "Spotify" is running'],
                    capture_output=True, text=True, timeout=1
                )
                return "true" in res.stdout.lower()
            except Exception:
                pass
        elif os_name == "windows":
            try:
                res = subprocess.run(
                    ["tasklist", "/FI", "IMAGENAME eq Spotify.exe"],
                    capture_output=True, text=True, timeout=1
                )
                return "Spotify.exe" in res.stdout
            except Exception:
                pass
        return False

    @classmethod
    def get_state(cls) -> Dict[str, Any]:
        """Retrieves Spotify playback state and metadata."""
        os_name = cls.get_os()
        state = {
            "track": "",
            "artist": "",
            "album": "",
            "playing": False,
            "connected": False,
        }

        if not cls.is_running():
            return state

        state["connected"] = True

        if os_name == "linux" and shutil.which("playerctl"):
            try:
                # Status: Playing / Paused
                st_res = subprocess.run(
                    ["playerctl", "--player=spotify", "status"],
                    capture_output=True, text=True, timeout=1
                )
                state["playing"] = "playing" in st_res.stdout.lower()

                # Track Title
                t_res = subprocess.run(
                    ["playerctl", "--player=spotify", "metadata", "title"],
                    capture_output=True, text=True, timeout=1
                )
                state["track"] = t_res.stdout.strip()

                # Artist
                a_res = subprocess.run(
                    ["playerctl", "--player=spotify", "metadata", "artist"],
                    capture_output=True, text=True, timeout=1
                )
                state["artist"] = a_res.stdout.strip()

                # Album
                alb_res = subprocess.run(
                    ["playerctl", "--player=spotify", "metadata", "album"],
                    capture_output=True, text=True, timeout=1
                )
                state["album"] = alb_res.stdout.strip()
            except Exception:
                pass

        elif os_name == "darwin":
            apple_script = '''
            tell application "Spotify"
                if player state is playing then
                    set isPlaying to true
                else
                    set isPlaying to false
                end if
                set currentTrack to name of current track
                set currentArtist to artist of current track
                set currentAlbum to album of current track
                return (isPlaying as string) & "|||" & currentTrack & "|||" & currentArtist & "|||" & currentAlbum
            end tell
            '''
            try:
                res = subprocess.run(
                    ["osascript", "-e", apple_script],
                    capture_output=True, text=True, timeout=1
                )
                parts = res.stdout.strip().split("|||")
                if len(parts) >= 4:
                    state["playing"] = parts[0].strip().lower() == "true"
                    state["track"] = parts[1].strip()
                    state["artist"] = parts[2].strip()
                    state["album"] = parts[3].strip()
            except Exception:
                pass

        elif os_name == "windows":
            # On Windows, Spotify sets window title to "Artist - Title" when playing
            try:
                import win32gui
                def enum_windows(hwnd, extra):
                    if win32gui.IsWindowVisible(hwnd):
                        title = win32gui.GetWindowText(hwnd)
                        if title and " - " in title:
                            import win32process
                            try:
                                _, pid = win32process.GetWindowThreadProcessId(hwnd)
                                import psutil
                                proc = psutil.Process(pid)
                                if "spotify" in proc.name().lower():
                                    extra.append(title)
                            except Exception:
                                pass
                titles = []
                win32gui.EnumWindows(enum_windows, titles)
                if titles:
                    raw = titles[0]
                    parts = raw.split(" - ", 1)
                    state["artist"] = parts[0].strip()
                    state["track"] = parts[1].strip()
                    state["playing"] = True
            except Exception:
                pass

        return state

    @classmethod
    def handle(cls, command: str, payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Dispatches Spotify actions."""
        payload = payload or {}
        cmd = command.lower().replace("spotify_", "").strip()
        os_name = cls.get_os()

        if os_name == "linux":
            if shutil.which("playerctl"):
                if cmd in ("play_pause", "toggle"):
                    subprocess.run(["playerctl", "--player=spotify", "play-pause"], check=False)
                    return {"success": True, "action": "spotify_play_pause"}
                elif cmd in ("next", "skip"):
                    subprocess.run(["playerctl", "--player=spotify", "next"], check=False)
                    return {"success": True, "action": "spotify_next"}
                elif cmd in ("previous", "prev"):
                    subprocess.run(["playerctl", "--player=spotify", "previous"], check=False)
                    return {"success": True, "action": "spotify_previous"}
                elif cmd == "stop":
                    subprocess.run(["playerctl", "--player=spotify", "stop"], check=False)
                    return {"success": True, "action": "spotify_stop"}
                elif cmd in ("volume_up", "vol_up"):
                    subprocess.run(["playerctl", "--player=spotify", "volume", "0.05+"], check=False)
                    return {"success": True, "action": "spotify_volume_up"}
                elif cmd in ("volume_down", "vol_down"):
                    subprocess.run(["playerctl", "--player=spotify", "volume", "0.05-"], check=False)
                    return {"success": True, "action": "spotify_volume_down"}
                elif cmd == "set_volume":
                    vol = float(payload.get("volume", 0.5))
                    subprocess.run(["playerctl", "--player=spotify", "volume", str(vol)], check=False)
                    return {"success": True, "action": "spotify_set_volume", "volume": vol}

        elif os_name == "darwin":
            script_map = {
                "play_pause": 'tell application "Spotify" to playpause',
                "toggle": 'tell application "Spotify" to playpause',
                "next": 'tell application "Spotify" to next track',
                "skip": 'tell application "Spotify" to next track',
                "previous": 'tell application "Spotify" to previous track',
                "prev": 'tell application "Spotify" to previous track',
                "stop": 'tell application "Spotify" to pause',
            }
            if cmd in script_map:
                subprocess.run(["osascript", "-e", script_map[cmd]], check=False)
                return {"success": True, "action": f"spotify_{cmd}"}
            elif cmd == "set_volume":
                vol = int(float(payload.get("volume", 0.5)) * 100)
                subprocess.run(["osascript", "-e", f'tell application "Spotify" to set sound volume to {vol}'], check=False)
                return {"success": True, "action": "spotify_set_volume", "volume": vol}

        elif os_name == "windows":
            try:
                import pyautogui
                key_map = {
                    "play_pause": "playpause",
                    "toggle": "playpause",
                    "next": "nexttrack",
                    "skip": "nexttrack",
                    "previous": "prevtrack",
                    "prev": "prevtrack",
                    "stop": "stop",
                    "volume_up": "volumeup",
                    "volume_down": "volumedown",
                }
                if cmd in key_map:
                    pyautogui.press(key_map[cmd])
                    return {"success": True, "action": f"spotify_{cmd}"}
            except Exception as e:
                return {"success": False, "error": str(e)}

        return {"success": False, "error": f"Unsupported Spotify command or OS: {cmd}"}
