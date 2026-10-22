"""
AstraDeck OBS Studio Integration
Controls OBS Studio via OBS WebSocket v5 protocol.
Communicates using obsws-python if available, with graceful fallback.
"""

import os
import json
from typing import Dict, Any, Optional

try:
    import obsws_python as obs
except ImportError:
    obs = None

CONFIG_PATH = os.path.expanduser("~/.astradeck/config.json")

class OBSIntegration:
    _client = None
    _last_error = ""

    @classmethod
    def _load_config(cls) -> Dict[str, Any]:
        if os.path.exists(CONFIG_PATH):
            try:
                with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    return data.get("obs", {})
            except Exception:
                pass
        return {}

    @classmethod
    def get_client(cls):
        if cls._client is not None:
            return cls._client

        if obs is None:
            cls._last_error = "obsws-python is not installed"
            return None

        cfg = cls._load_config()
        host = cfg.get("host", "localhost")
        port = int(cfg.get("port", 4455))
        password = cfg.get("password", "")

        try:
            cls._client = obs.ReqClient(host=host, port=port, password=password, timeout=2)
            return cls._client
        except Exception as e:
            cls._client = None
            cls._last_error = str(e)
            return None

    @classmethod
    def reset_client(cls):
        cls._client = None

    @classmethod
    def get_state(cls) -> Dict[str, Any]:
        """Returns OBS status for state_broadcaster."""
        state = {
            "connected": False,
            "recording": False,
            "streaming": False,
            "scene": "",
            "virtual_cam": False,
        }

        client = cls.get_client()
        if not client:
            return state

        try:
            rec = client.get_record_status()
            state["recording"] = rec.output_active

            stream = client.get_stream_status()
            state["streaming"] = stream.output_active

            scene = client.get_current_program_scene()
            state["scene"] = scene.current_program_scene_name

            cam = client.get_virtual_cam_status()
            state["virtual_cam"] = cam.output_active

            state["connected"] = True
        except Exception:
            cls.reset_client()

        return state

    @classmethod
    def handle(cls, command: str, payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Dispatches OBS commands."""
        payload = payload or {}
        cmd = command.lower().replace("obs_", "").strip()

        client = cls.get_client()
        if not client:
            return {
                "success": False,
                "error": f"Cannot connect to OBS Studio: {cls._last_error}. Ensure OBS is running and WebSocket server is enabled (Tools -> WebSocket Server Settings)."
            }

        try:
            if cmd in ("toggle_recording", "recording"):
                client.toggle_record()
                return {"success": True, "action": "obs_toggle_recording"}

            elif cmd in ("start_recording", "record_start"):
                client.start_record()
                return {"success": True, "action": "obs_start_recording"}

            elif cmd in ("stop_recording", "record_stop"):
                client.stop_record()
                return {"success": True, "action": "obs_stop_recording"}

            elif cmd in ("toggle_streaming", "streaming"):
                client.toggle_stream()
                return {"success": True, "action": "obs_toggle_streaming"}

            elif cmd in ("start_streaming", "stream_start"):
                client.start_stream()
                return {"success": True, "action": "obs_start_streaming"}

            elif cmd in ("stop_streaming", "stream_stop"):
                client.stop_stream()
                return {"success": True, "action": "obs_stop_streaming"}

            elif cmd in ("toggle_virtual_cam", "virtual_cam"):
                client.toggle_virtual_cam()
                return {"success": True, "action": "obs_toggle_virtual_cam"}

            elif cmd in ("switch_scene", "set_scene", "scene"):
                scene_name = payload.get("scene") or payload.get("scene_name", "")
                if not scene_name:
                    return {"success": False, "error": "Missing scene name in payload"}
                client.set_current_program_scene(scene_name)
                return {"success": True, "action": "obs_switch_scene", "scene": scene_name}

            elif cmd in ("toggle_mute", "mute"):
                source = payload.get("source") or payload.get("input", "Mic/Aux")
                client.toggle_input_mute(source)
                return {"success": True, "action": "obs_toggle_mute", "source": source}

            elif cmd in ("save_replay_buffer", "replay_buffer"):
                client.save_replay_buffer()
                return {"success": True, "action": "obs_save_replay_buffer"}

            return {"success": False, "error": f"Unknown OBS command: {cmd}"}

        except Exception as e:
            cls.reset_client()
            return {"success": False, "error": str(e)}
