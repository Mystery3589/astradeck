import os
import sys
import json
import time
import shutil
import subprocess
import asyncio
import re
from pathlib import Path

FUNCTIONS_DIR = Path.home() / ".astradeck" / "functions"
METADATA_FILE = FUNCTIONS_DIR / "functions_registry.json"

class DynamicFunctionEngine:
    """
    Function 3 of AstraDeck: Dynamic Function Creator & Runner.
    Takes user-defined desired actions from AstraDeck and dynamically
    synthesizes, generates, and executes host functions without prebuilding.
    """

    @classmethod
    def ensure_storage(cls):
        FUNCTIONS_DIR.mkdir(parents=True, exist_ok=True)
        if not METADATA_FILE.exists():
            with open(METADATA_FILE, "w") as f:
                json.dump({}, f)

    @classmethod
    def load_registry(cls) -> dict:
        cls.ensure_storage()
        try:
            with open(METADATA_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return {}

    @classmethod
    def save_registry(cls, registry: dict):
        cls.ensure_storage()
        try:
            with open(METADATA_FILE, "w") as f:
                json.dump(registry, f, indent=2)
        except Exception as e:
            print(f"[DynamicFunctionEngine] Error saving registry: {e}")

    @classmethod
    def synthesize_function(cls, action_definition: str, name: str = "", metadata: dict = None) -> dict:
        """
        Synthesizes an executable host script from a user-defined desired action.
        Works across Linux (Hyprland/Wayland/X11), Windows, and macOS.
        """
        cls.ensure_storage()
        raw_text = action_definition.strip()
        if not raw_text:
            return {"status": "error", "message": "Action definition cannot be empty."}

        now_ts = int(time.time() * 1000)
        func_id = re.sub(r'[^a-zA-Z0-9_]', '_', name.strip().lower() if name else raw_text[:24].strip().lower())
        func_id = f"fn_{func_id}_{now_ts}"

        script_content, resolved_name, icon_hint = cls._resolve_recipe(raw_text)
        final_name = name.strip() if name.strip() else resolved_name

        script_path = FUNCTIONS_DIR / f"{func_id}.sh"
        if sys.platform == "win32":
            script_path = FUNCTIONS_DIR / f"{func_id}.bat"

        with open(script_path, "w") as f:
            f.write(script_content)

        # Make executable on Unix
        if sys.platform != "win32":
            os.chmod(script_path, 0o755)

        record = {
            "id": func_id,
            "name": final_name,
            "definition": raw_text,
            "script_path": str(script_path),
            "icon_hint": icon_hint,
            "created_at": str(now_ts),
            "custom_metadata": metadata or {}
        }

        registry = cls.load_registry()
        registry[func_id] = record
        cls.save_registry(registry)

        print(f"[DynamicFunctionEngine] Created function '{final_name}' ({func_id}) for: '{raw_text}'")
        return {
            "status": "created",
            "function_id": func_id,
            "name": final_name,
            "icon_hint": icon_hint,
            "script_path": str(script_path),
            "message": f"Synthesized function '{final_name}' successfully."
        }

    @classmethod
    def _resolve_recipe(cls, query: str) -> tuple[str, str, str]:
        """
        Intelligent capability matcher: Inspects available desktop tools and
        constructs the exact script for the host desktop session.
        """
        q = query.lower().strip()

        # 1. Direct Shell Script or Command provided explicitly
        if q.startswith("#!") or "\n" in query or q.startswith("bash ") or q.startswith("sh ") or q.startswith("python3 "):
            script = f"#!/usr/bin/env bash\n# User custom script\n{query}\n"
            return script, "Custom Script", "terminal"

        # 2. Lock Screen
        if any(w in q for w in ["lock screen", "lock pc", "lock session", "lock"]):
            if shutil.which("hyprlock"):
                return "#!/usr/bin/env bash\nhyprlock\n", "Lock Screen", "lock"
            elif shutil.which("swaylock"):
                return "#!/usr/bin/env bash\nswaylock -f\n", "Lock Screen", "lock"
            elif shutil.which("loginctl"):
                return "#!/usr/bin/env bash\nloginctl lock-session\n", "Lock Screen", "lock"
            elif sys.platform == "win32":
                return "rundll32.exe user32.dll,LockWorkStation\n", "Lock Screen", "lock"

        # 3. Screenshot Capabilities (Full / Area / Active Window)
        if "screenshot" in q or "screen shot" in q or "capture" in q:
            pics_dir = Path.home() / "Pictures" / "Screenshots"
            pics_dir.mkdir(parents=True, exist_ok=True)
            timestamp = "$(date +%Y%m%d_%H%M%S)"
            out_file = f"{pics_dir}/screenshot_{timestamp}.png"

            if "active" in q or "window" in q:
                if shutil.which("grim") and shutil.which("hyprctl") and shutil.which("slurp"):
                    script = f"""#!/usr/bin/env bash
FILE="{out_file}"
hyprctl -j activewindow | jq -r '"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"' | grim -g - "$FILE"
wl-copy < "$FILE" 2>/dev/null || true
notify-send "AstraDeck" "Active window screenshot saved & copied!" -i camera 2>/dev/null || true
"""
                    return script, "Window Screenshot", "camera_alt"

            if "area" in q or "select" in q:
                if shutil.which("grim") and shutil.which("slurp"):
                    script = f"""#!/usr/bin/env bash
FILE="{out_file}"
grim -g "$(slurp)" "$FILE"
wl-copy < "$FILE" 2>/dev/null || true
notify-send "AstraDeck" "Area screenshot saved & copied!" -i camera 2>/dev/null || true
"""
                    return script, "Area Screenshot", "crop"

            # Default: Full Screenshot
            if shutil.which("grim"):
                script = f"""#!/usr/bin/env bash
FILE="{out_file}"
grim "$FILE"
wl-copy < "$FILE" 2>/dev/null || true
notify-send "AstraDeck" "Screenshot saved to Pictures & copied!" -i camera 2>/dev/null || true
"""
                return script, "Take Screenshot", "camera_alt"
            elif shutil.which("gnome-screenshot"):
                return f"#!/usr/bin/env bash\ngnome-screenshot -f {out_file}\n", "Take Screenshot", "camera_alt"

        # 4. Toggle Dark Mode / Light Mode
        if "dark mode" in q or "night light" in q or "gamma" in q:
            if shutil.which("gammastep"):
                script = """#!/usr/bin/env bash
if pgrep -x gammastep > /dev/null; then
    pkill gammastep
    notify-send "AstraDeck" "Night Light Disabled" 2>/dev/null || true
else
    gammastep -O 4000 &
    notify-send "AstraDeck" "Night Light Enabled" 2>/dev/null || true
fi
"""
                return script, "Toggle Night Light", "nightlight"

        # 5. Media Player Controls (via playerctl)
        if any(w in q for w in ["play", "pause", "music", "spotify", "next track", "previous track"]):
            if "next" in q:
                return "#!/usr/bin/env bash\nplayerctl next 2>/dev/null || true\n", "Next Track", "skip_next"
            if "prev" in q:
                return "#!/usr/bin/env bash\nplayerctl previous 2>/dev/null || true\n", "Previous Track", "skip_previous"
            return "#!/usr/bin/env bash\nplayerctl play-pause 2>/dev/null || true\n", "Play / Pause", "play_arrow"

        # 6. Audio Device Switcher (Headphones <-> Speakers)
        if "switch audio" in q or "headphones" in q or "speakers" in q or "sink" in q:
            script = """#!/usr/bin/env bash
if command -v pactl > /dev/null; then
    sinks=($(pactl list short sinks | awk '{print $2}'))
    current=$(pactl get-default-sink)
    for i in "${!sinks[@]}"; do
        if [[ "${sinks[$i]}" == "$current" ]]; then
            next_idx=$(( (i + 1) % ${#sinks[@]} ))
            next_sink="${sinks[$next_idx]}"
            pactl set-default-sink "$next_sink"
            notify-send "AstraDeck" "Switched Audio Sink: $next_sink" 2>/dev/null || true
            break
        fi
    done
fi
"""
            return script, "Switch Audio Sink", "headset"

        # 7. Window Management / Desktop Workspace (Hyprland / Wayland)
        if "hyprland" in q or "workspace" in q or "window" in q:
            num_match = re.search(r'workspace\s+(\d+)', q)
            if num_match:
                ws = num_match.group(1)
                return f"#!/usr/bin/env bash\nhyprctl dispatch workspace {ws}\n", f"Workspace {ws}", "desktop_windows"
            if "float" in q or "floating" in q:
                return "#!/usr/bin/env bash\nhyprctl dispatch togglefloating\n", "Toggle Floating", "picture_in_picture"
            if "fullscreen" in q:
                return "#!/usr/bin/env bash\nhyprctl dispatch fullscreen 1\n", "Fullscreen", "fullscreen"

        # 8. System Power / Session Management
        if "sleep" in q or "suspend" in q:
            return "#!/usr/bin/env bash\nsystemctl suspend\n", "Suspend PC", "power_settings_new"
        if "reboot" in q or "restart pc" in q:
            return "#!/usr/bin/env bash\nsystemctl reboot\n", "Reboot PC", "restart_alt"
        if "power off" in q or "shutdown" in q:
            return "#!/usr/bin/env bash\nsystemctl poweroff\n", "Shut Down", "power_off"

        # 9. Clipboard Utilities / Trash
        if "empty trash" in q or "clean trash" in q:
            return "#!/usr/bin/env bash\nrm -rf ~/.local/share/Trash/* 2>/dev/null\nnotify-send 'AstraDeck' 'Trash emptied' 2>/dev/null || true\n", "Empty Trash", "delete"

        # 10. Open Terminal
        if "terminal" in q:
            for term in ["alacritty", "kitty", "foot", "wezterm", "gnome-terminal", "konsole", "xterm"]:
                if shutil.which(term):
                    return f"#!/usr/bin/env bash\n{term} &\n", "Open Terminal", "terminal"

        # 11. Generic Command / Hotkey / Process runner
        script = f"""#!/usr/bin/env bash
# Dynamically synthesized action: {query}
{query}
"""
        title = query.strip()
        if len(title) > 20:
            title = title[:20] + "..."
        return script, title, "smart_button"

    @classmethod
    def execute_function(cls, function_id: str = "", command: str = "", args: list = None) -> dict:
        """
        Executes a dynamic function or inline command in the host session.
        """
        cls.ensure_storage()
        registry = cls.load_registry()

        script_to_run = None
        func_name = "Dynamic Action"

        if function_id and function_id in registry:
            record = registry[function_id]
            script_to_run = record.get("script_path")
            func_name = record.get("name", func_name)
        elif command:
            res = cls.synthesize_function(command)
            script_to_run = res.get("script_path")
            func_name = res.get("name", func_name)

        if not script_to_run or not os.path.exists(script_to_run):
            return {"status": "error", "message": f"Function '{function_id}' not found."}

        env = os.environ.copy()
        try:
            print(f"[DynamicFunctionEngine] Executing: {script_to_run} ({func_name})")
            proc = subprocess.Popen(
                [script_to_run] + (args or []),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True,
                env=env,
                text=True
            )
            return {
                "status": "executed",
                "function_id": function_id,
                "name": func_name,
                "pid": proc.pid,
                "message": f"Executed function '{func_name}'."
            }
        except Exception as e:
            print(f"[DynamicFunctionEngine] Execution failed: {e}")
            return {"status": "error", "message": str(e)}

    @classmethod
    def list_functions(cls) -> list:
        registry = cls.load_registry()
        return list(registry.values())
