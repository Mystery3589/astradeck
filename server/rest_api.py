"""
AstraDeck Lightweight REST API Server
Provides HTTP endpoints on port 8766 (or companion port + 1) for external automation,
scripting, browser testing, and integration verification.
Zero external dependencies (uses standard library http.server + threading).
"""

import json
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional, Callable, Any

from state_broadcaster import StateBroadcaster

class AstraDeckHTTPRequestHandler(BaseHTTPRequestHandler):
    dispatch_handler: Optional[Callable[[str, dict], Any]] = None
    server_info_provider: Optional[Callable[[], dict]] = None

    def _set_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self):
        self.send_response(204)
        self._set_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/api/status":
            provider = AstraDeckHTTPRequestHandler.server_info_provider
            info = provider() if provider else {"status": "ok"}
            self._send_json(200, info)
        elif path == "/api/state":
            snapshot = StateBroadcaster.get_snapshot()
            self._send_json(200, snapshot)
        else:
            self._send_json(404, {"error": "Not Found", "available_endpoints": ["/api/status", "/api/state", "/api/action"]})

    def do_POST(self):
        path = self.path.split("?")[0]
        if path == "/api/action":
            content_length = int(self.headers.get("Content-Length", 0))
            body_data = self.rfile.read(content_length)
            try:
                data = json.loads(body_data.decode("utf-8")) if body_data else {}
            except Exception as e:
                self._send_json(400, {"error": "Invalid JSON", "details": str(e)})
                return

            action = data.get("action", "")
            payload = data.get("payload", data)
            if not action:
                self._send_json(400, {"error": "Missing 'action' in JSON body"})
                return

            handler = AstraDeckHTTPRequestHandler.dispatch_handler
            if handler:
                try:
                    res = handler(action, payload)
                    self._send_json(200, res)
                except Exception as e:
                    self._send_json(500, {"error": str(e)})
            else:
                self._send_json(503, {"error": "Dispatch handler not ready"})
        else:
            self._send_json(404, {"error": "Not Found"})

    def _send_json(self, code: int, data: Any):
        self.send_response(code)
        self._set_cors_headers()
        self.send_header("Content-Type", "application/json")
        encoded = json.dumps(data, indent=2).encode("utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format, *args):
        # Silence default HTTP server console noise
        pass

class RestApiServer:
    def __init__(self, port: int, dispatch_sync_callable: Callable[[str, dict], Any], server_info_callable: Callable[[], dict]):
        self.port = port
        AstraDeckHTTPRequestHandler.dispatch_handler = dispatch_sync_callable
        AstraDeckHTTPRequestHandler.server_info_provider = server_info_callable
        self.server: Optional[HTTPServer] = None
        self._thread: Optional[threading.Thread] = None

    def start(self):
        try:
            self.server = HTTPServer(("0.0.0.0", self.port), AstraDeckHTTPRequestHandler)
            self._thread = threading.Thread(target=self.server.serve_forever, daemon=True)
            self._thread.start()
            print(f"[AstraDeck REST API] Live at http://0.0.0.0:{self.port} (/api/status, /api/state, /api/action)")
        except Exception as e:
            print(f"[AstraDeck REST API] Warning: could not start HTTP server on port {self.port}: {e}")

    def stop(self):
        if self.server:
            self.server.shutdown()
            self.server.server_close()
