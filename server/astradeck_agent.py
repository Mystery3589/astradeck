import asyncio
import json
import os
import sys
import socket
import platform
from pathlib import Path
import websockets
from app_lifecycle import AppLifecycleManager
from system_controls import CrossPlatformControls

DEFAULT_PORT = 8765
PORT_RANGE = range(8765, 8785)
PIN = "1234"
VERSION = "2.5.0"

class AstraDeckServer:
    def __init__(self):
        self.hostname = platform.node()
        self.os_type = platform.system()
        self.os_version = platform.release()
        self.authenticated_clients = set()
        self.active_port = DEFAULT_PORT
        self.info_file = Path.home() / ".astradeck" / "server_info.json"

    def find_open_port(self):
        """Scans for an available port starting at DEFAULT_PORT."""
        for port in PORT_RANGE:
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    s.bind(("0.0.0.0", port))
                    self.active_port = port
                    return port
            except OSError:
                continue
        raise RuntimeError("No available ports found in AstraDeck port range (8765-8785)!")

    def save_runtime_info(self):
        """Saves current server port, IP, and PID for auto-discovery and setup scripts."""
        try:
            self.info_file.parent.mkdir(parents=True, exist_ok=True)
            info = {
                "port": self.active_port,
                "ip": self.get_local_ip(),
                "pid": os.getpid(),
                "version": VERSION,
                "hostname": self.hostname,
                "os": self.os_type,
            }
            with open(self.info_file, "w") as f:
                json.dump(info, f, indent=2)
        except Exception as e:
            print(f"[Warning] Failed to write server info file: {e}")

    def get_local_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    # --- UDP Discovery Beacon (Dynamic Port) ---
    async def run_udp_discovery(self):
        """Listens for ASTRADECK_DISCOVER broadcasts and replies with active port."""
        loop = asyncio.get_running_loop()
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        
        try:
            sock.bind(('', DEFAULT_PORT))
            sock.setblocking(False)
            print(f"[UDP Beacon] Listening for discovery on UDP port {DEFAULT_PORT} (announcing TCP :{self.active_port})...")

            while True:
                data, addr = await loop.sock_recvfrom(sock, 1024)
                message = data.decode('utf-8', errors='ignore').strip()
                if "ASTRADECK_DISCOVER" in message or "NEXUS_DISCOVER" in message:
                    response = json.dumps({
                        "type": "ASTRADECK_BEACON",
                        "name": f"{self.hostname} ({self.os_type})",
                        "os": self.os_type,
                        "osVersion": self.os_version,
                        "agentVersion": VERSION,
                        "ip": self.get_local_ip(),
                        "port": self.active_port,
                        "transport": "wifi",
                        "supportedFeatures": [
                            "volume_control",
                            "brightness_control",
                            "mic_mute",
                            "app_launch",
                            "obs_control",
                            "system_mute"
                        ]
                    })
                    sock.sendto(response.encode('utf-8'), addr)
                    print(f"[UDP Beacon] Responded to auto-discovery from {addr[0]}")
        except Exception as e:
            print(f"[UDP Beacon] Discovery notice: {e}")

    # --- Bluetooth RFCOMM Server (Linux Native) ---
    async def run_bluetooth_server(self):
        """Native Bluetooth RFCOMM listener if AF_BLUETOOTH is available."""
        if not hasattr(socket, "AF_BLUETOOTH") or not hasattr(socket, "BTPROTO_RFCOMM"):
            return
        
        loop = asyncio.get_running_loop()
        try:
            bt_sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
            bt_sock.bind((socket.BDADDR_ANY, 4))
            bt_sock.listen(1)
            bt_sock.setblocking(False)
            print("[Bluetooth] RFCOMM Serial channel 4 listening for AstraDeck...")

            while True:
                client_sock, client_info = await loop.sock_accept(bt_sock)
                print(f"[Bluetooth] Client connected via RFCOMM: {client_info}")
                asyncio.create_task(self.handle_bluetooth_client(client_sock))
        except Exception as e:
            print(f"[Bluetooth] RFCOMM initialization note: {e}")

    async def handle_bluetooth_client(self, client_sock):
        loop = asyncio.get_running_loop()
        try:
            while True:
                data = await loop.sock_recv(client_sock, 4096)
                if not data:
                    break
                line = data.decode("utf-8", errors="ignore").strip()
                for chunk in line.split("\n"):
                    if not chunk.strip():
                        continue
                    try:
                        req = json.loads(chunk)
                        action = req.get("action")
                        payload = req.get("payload", {})
                        resp = await self.dispatch_action(action, payload)
                        resp["id"] = req.get("id", 0)
                        out = (json.dumps(resp) + "\n").encode("utf-8")
                        await loop.sock_sendall(client_sock, out)
                    except Exception as e:
                        err_out = (json.dumps({"status": "error", "message": str(e)}) + "\n").encode("utf-8")
                        await loop.sock_sendall(client_sock, err_out)
        except Exception:
            pass
        finally:
            client_sock.close()

    # --- WebSocket Handler ---
    async def handle_client(self, websocket):
        client_id = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
        print(f"[WS] Client connected: {client_id}")

        try:
            async for raw in websocket:
                try:
                    data = json.loads(raw)
                    action = data.get("action")
                    req_id = data.get("id", 0)

                    # 1. Ping / Heartbeat
                    if action == "ping":
                        await websocket.send(json.dumps({
                            "id": req_id,
                            "type": "pong",
                            "timestamp": data.get("timestamp")
                        }))
                        continue

                    # 2. Authentication Handshake (PIN or saved token)
                    if action == "auth":
                        provided_pin = str(data.get("pin", "")).strip()
                        provided_token = str(data.get("token", "")).strip()
                        if provided_pin == PIN or provided_token == "session_ok":
                            self.authenticated_clients.add(client_id)
                            print(f"[WS] Client {client_id} successfully authenticated")
                            await websocket.send(json.dumps({
                                "id": req_id,
                                "status": "authenticated",
                                "token": "session_ok",
                                "message": "Pairing successful"
                            }))
                        else:
                            print(f"[WS] Client {client_id} failed auth (entered: '{provided_pin}')")
                            await websocket.send(json.dumps({
                                "id": req_id,
                                "status": "unauthorized",
                                "message": "Invalid PIN. Default PIN is 1234"
                            }))
                        continue

                    if client_id not in self.authenticated_clients:
                        await websocket.send(json.dumps({
                            "id": req_id,
                            "status": "error",
                            "message": "Authentication required. Send 'auth' action with PIN."
                        }))
                        continue

                    # 3. Action Dispatcher
                    resp = await self.dispatch_action(action, data.get("payload", {}))
                    resp["id"] = req_id
                    await websocket.send(json.dumps(resp))

                except Exception as e:
                    print(f"[WS] Error processing request: {e}")
                    await websocket.send(json.dumps({
                        "id": req_id if 'req_id' in locals() else 0,
                        "status": "error",
                        "message": str(e)
                    }))
        except Exception as e:
            print(f"[WS] Client disconnected: {client_id}")
        finally:
            self.authenticated_clients.discard(client_id)

    async def dispatch_action(self, action: str, payload: dict) -> dict:
        print(f"[Dispatch] Action: {action}, Payload: {payload}")

        if action == "launch_app":
            target = payload.get("app") or payload.get("target", "")
            return AppLifecycleManager.launch_or_focus(target)

        elif action == "open_website":
            url = payload.get("url", "")
            return AppLifecycleManager.open_url(url)

        elif action == "set_volume":
            vol = payload.get("value", 50)
            return CrossPlatformControls.set_master_volume(vol)

        elif action == "set_brightness":
            val = payload.get("value", 80)
            return CrossPlatformControls.set_brightness(val)

        elif action == "toggle_mute":
            return CrossPlatformControls.toggle_mute()

        elif action == "toggle_mic":
            return CrossPlatformControls.toggle_mic()

        elif action == "get_system_status":
            return {
                "status": "ok",
                "os": self.os_type,
                "hostname": self.hostname,
                "agentVersion": VERSION,
                "port": self.active_port,
            }

        return {"status": "error", "message": f"Unknown action: {action}"}

    async def start(self):
        self.active_port = self.find_open_port()
        self.save_runtime_info()
        local_ip = self.get_local_ip()

        print("=" * 60)
        print(f"     AstraDeck Desktop Companion Agent v{VERSION}     ")
        print("=" * 60)
        print(f"  OS Host:       {self.hostname} ({self.os_type} {self.os_version})")
        print(f"  Local IP:      {local_ip}")
        print(f"  WebSocket:     ws://0.0.0.0:{self.active_port} (and 127.0.0.1 for USB)")
        print(f"  Pairing PIN:   {PIN}")
        print(f"  UDP Discovery: Broadcast Port {DEFAULT_PORT} -> TCP {self.active_port}")
        print("=" * 60)

        # Start UDP Discovery
        asyncio.create_task(self.run_udp_discovery())

        # Start Bluetooth RFCOMM listener (if supported)
        asyncio.create_task(self.run_bluetooth_server())

        # Start WebSocket Server on dynamically selected port
        async with websockets.serve(self.handle_client, "0.0.0.0", self.active_port):
            await asyncio.Future()

if __name__ == "__main__":
    server = AstraDeckServer()
    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        print("\nAstraDeck Agent shutting down.")
