import asyncio
import json
import os
import sys
import shutil
import subprocess
import socket
import platform
from pathlib import Path
import websockets
from app_lifecycle import AppLifecycleManager
from system_controls import CrossPlatformControls
from dynamic_function_engine import DynamicFunctionEngine

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
        self.active_bt_client = None
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
        """Resolves host IP prioritizing Wi-Fi and Ethernet over USB tethering."""
        try:
            import psutil
            addrs = psutil.net_if_addrs()
            # 1. Prioritize Wi-Fi interfaces
            for iface, addr_list in addrs.items():
                if any(w in iface.lower() for w in ['wlan', 'wlp', 'wifi']):
                    for a in addr_list:
                        if a.family == socket.AF_INET and not a.address.startswith("127."):
                            return a.address
            # 2. Prioritize Ethernet / LAN interfaces
            for iface, addr_list in addrs.items():
                if not any(skip in iface.lower() for skip in ['tailscale', 'docker', 'virbr', 'rndis', 'lo']):
                    for a in addr_list:
                        if a.family == socket.AF_INET and not a.address.startswith("127."):
                            return a.address
        except Exception:
            pass

        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    def get_all_ips(self):
        """Returns all non-loopback IPv4 addresses across network cards."""
        ips = []
        try:
            import psutil
            for iface, addr_list in psutil.net_if_addrs().items():
                for a in addr_list:
                    if a.family == socket.AF_INET and not a.address.startswith("127."):
                        if a.address not in ips:
                            ips.append(a.address)
        except Exception:
            pass
        if not ips:
            ips.append(self.get_local_ip())
        return ips

    # --- Automatic ADB Reverse Watchdog ---
    async def run_adb_reverse_watchdog(self):
        """Continuously ensures 'adb reverse tcp:PORT tcp:PORT' is active whenever a phone is connected."""
        if not shutil.which("adb"):
            print("[ADB Watchdog] adb executable not found. Automatic reverse tunnel disabled.")
            return

        print(f"[ADB Watchdog] Active: automatically tunneling tcp:{self.active_port} whenever phone is plugged in.")
        last_had_device = False

        while True:
            try:
                proc = await asyncio.create_subprocess_exec(
                    "adb", "devices",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, _ = await proc.communicate()
                lines = stdout.decode().splitlines()
                has_device = any("\tdevice" in line for line in lines)

                if has_device:
                    if not last_had_device:
                        print(f"[ADB Watchdog] Phone detected! Setting up reverse tunnel for port {self.active_port}...")
                    rev = await asyncio.create_subprocess_exec(
                        "adb", "reverse", f"tcp:{self.active_port}", f"tcp:{self.active_port}",
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    await rev.communicate()
                    last_had_device = True
                else:
                    last_had_device = False
            except Exception:
                pass
            await asyncio.sleep(2)

    # --- UDP Discovery Beacon (Dynamic Port) ---
    async def run_udp_discovery(self):
        """Listens for ASTRADECK_DISCOVER broadcasts and replies with active port and IPs."""
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
                        "allIps": self.get_all_ips(),
                        "port": self.active_port,
                        "transport": "wifi",
                        "supportedFeatures": [
                            "volume_control",
                            "brightness_control",
                            "mic_mute",
                            "app_launch",
                            "system_mute",
                            "custom_functions"
                        ]
                    })
                    sock.sendto(response.encode('utf-8'), addr)
                    print(f"[UDP Beacon] Responded to auto-discovery from {addr[0]}")
        except Exception as e:
            print(f"[UDP Beacon] Discovery notice: {e}")

    # --- Bluetooth RFCOMM Server (Linux Native) ---
    async def run_bluetooth_server(self):
        """Native Bluetooth RFCOMM listener with automatic recovery loop."""
        if not hasattr(socket, "AF_BLUETOOTH") or not hasattr(socket, "BTPROTO_RFCOMM"):
            return

        loop = asyncio.get_running_loop()

        while True:
            # Ensure Bluetooth adapter is powered on, connectable and discoverable
            if shutil.which("bluetoothctl"):
                try:
                    subprocess.run(["bluetoothctl", "power", "on"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    subprocess.run(["bluetoothctl", "pairable", "on"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    subprocess.run(["bluetoothctl", "discoverable-timeout", "0"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    subprocess.run(["bluetoothctl", "discoverable", "on"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except Exception:
                    pass

            bt_sock = None
            try:
                bt_sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
                try:
                    bt_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                except Exception:
                    pass
                bt_sock.bind((socket.BDADDR_ANY, 4))
                bt_sock.listen(2)
                bt_sock.setblocking(False)
                print("[Bluetooth] RFCOMM Serial channel 4 listening for AstraDeck...", flush=True)

                while True:
                    try:
                        client_sock, client_info = await loop.sock_accept(bt_sock)
                        client_sock.setblocking(False)
                        print(f"[Bluetooth] Client connected via RFCOMM: {client_info}", flush=True)
                        asyncio.create_task(self.handle_bluetooth_client(client_sock))
                    except asyncio.CancelledError:
                        raise
                    except Exception as loop_err:
                        print(f"[Bluetooth] Accept loop notice: {loop_err}", flush=True)
                        await asyncio.sleep(0.5)
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"[Bluetooth] RFCOMM server exception: {e}. Re-initializing in 2s...", flush=True)
            finally:
                if bt_sock:
                    try:
                        bt_sock.close()
                    except Exception:
                        pass
            await asyncio.sleep(2)

    async def handle_bluetooth_client(self, client_sock):
        loop = asyncio.get_running_loop()
        buffer = ""

        # Close existing active BT client to prevent stale sockets locking channel
        if self.active_bt_client and self.active_bt_client != client_sock:
            try:
                self.active_bt_client.close()
            except Exception:
                pass
        self.active_bt_client = client_sock

        try:
            # Immediately push current system volume and brightness so mobile sliders sync
            try:
                vol, brightness = CrossPlatformControls.get_current_state()
                init_msg = (json.dumps({
                    "type": "system_state",
                    "volume": vol,
                    "brightness": brightness,
                    "status": "connected"
                }) + "\n").encode("utf-8")
                await loop.sock_sendall(client_sock, init_msg)
            except Exception as e:
                print(f"[Bluetooth] Initial state push notice: {e}", flush=True)

            while True:
                data = await loop.sock_recv(client_sock, 4096)
                if not data:
                    break
                buffer += data.decode("utf-8", errors="ignore")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        req = json.loads(line)
                        action = req.get("action")
                        payload = req.get("payload", {})
                        if action == "ping":
                            resp = {
                                "id": req.get("id", 0),
                                "type": "pong",
                                "timestamp": req.get("timestamp")
                            }
                        else:
                            resp = await self.dispatch_action(action, payload)
                            resp["id"] = req.get("id", 0)
                        out = (json.dumps(resp) + "\n").encode("utf-8")
                        await loop.sock_sendall(client_sock, out)
                    except Exception as e:
                        err_out = (json.dumps({"status": "error", "message": str(e)}) + "\n").encode("utf-8")
                        await loop.sock_sendall(client_sock, err_out)
        except Exception as e:
            print(f"[Bluetooth] Client connection closed: {e}", flush=True)
        finally:
            if self.active_bt_client == client_sock:
                self.active_bt_client = None
            try:
                client_sock.close()
            except Exception:
                pass

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
                            # Immediately push current system state so app sliders sync
                            try:
                                vol, brightness = CrossPlatformControls.get_current_state()
                                await websocket.send(json.dumps({
                                    "type": "system_state",
                                    "volume": vol,
                                    "brightness": brightness,
                                }))
                            except Exception:
                                pass
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

        # --- Function 1: Hardware Control (Sound, Mic, Brightness) ---
        if action == "hardware_control":
            target = payload.get("target", "volume")
            command = payload.get("command", "adjust")
            value = payload.get("value")
            return CrossPlatformControls.handle_hardware_control(target, command, value)

        # --- Function 2: Smart Application Opener ---
        elif action in ("open_app", "launch_app"):
            target = payload.get("app") or payload.get("target") or payload.get("url", "")
            return AppLifecycleManager.launch(target)

        # --- Function 3: Dynamic Function Creator & Runner ---
        elif action == "create_function":
            definition = payload.get("action_definition") or payload.get("definition", "")
            name = payload.get("name", "")
            meta = payload.get("metadata", {})
            return DynamicFunctionEngine.synthesize_function(definition, name=name, metadata=meta)

        elif action == "execute_function":
            func_id = payload.get("function_id", "")
            cmd = payload.get("command", "")
            args = payload.get("args", [])
            return DynamicFunctionEngine.execute_function(function_id=func_id, command=cmd, args=args)

        elif action == "list_functions":
            return {"status": "ok", "functions": DynamicFunctionEngine.list_functions()}

        # --- Backward-Compatible Aliases ---
        elif action == "open_website":
            url = payload.get("url", "")
            AppLifecycleManager.open_in_browser(url)
            return {'status': 'opened_browser_url', 'url': url}

        elif action == "set_volume":
            # Flutter sends key "volume", not "value"
            vol = payload.get("volume", payload.get("value", 50))
            return CrossPlatformControls.set_volume(vol)

        elif action == "adjust_volume":
            step = payload.get("step", payload.get("delta", 5))
            return CrossPlatformControls.adjust_volume(step)

        elif action == "set_brightness":
            # Flutter sends key "brightness", not "value"
            val = payload.get("brightness", payload.get("value", 80))
            return CrossPlatformControls.set_brightness(val)

        elif action == "adjust_brightness":
            step = payload.get("step", payload.get("delta", 10))
            return CrossPlatformControls.adjust_brightness(step)

        elif action == "toggle_mute":
            return CrossPlatformControls.toggle_mute()

        elif action in ("toggle_mic_mute", "toggle_mic"):
            return CrossPlatformControls.toggle_mic_mute()

        elif action == "set_mic_volume":
            vol = payload.get("volume", payload.get("value", 75))
            return CrossPlatformControls.set_mic_volume(vol)

        elif action == "media_control":
            cmd = payload.get("command", "play_pause")
            return CrossPlatformControls.media_control(cmd)

        elif action == "get_system_status":
            vol, brightness = CrossPlatformControls.get_current_state()
            return {
                "status": "ok",
                "os": self.os_type,
                "hostname": self.hostname,
                "agentVersion": VERSION,
                "port": self.active_port,
                "volume": vol,
                "brightness": brightness,
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

        # Start Automatic ADB Reverse Watchdog (Auto-tunnel on USB plug-in)
        asyncio.create_task(self.run_adb_reverse_watchdog())

        # Start WebSocket Server on dynamically selected port
        async with websockets.serve(self.handle_client, "0.0.0.0", self.active_port):
            await asyncio.Future()

if __name__ == "__main__":
    server = AstraDeckServer()
    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        print("\nAstraDeck Agent shutting down.")
