#!/usr/bin/env python3
"""Local HTTP API for an Optimize Input button.

This does not modify Codex UI by itself. It provides the stable local endpoint a
Codex toolbar action can call when the app exposes a button/plugin hook.
"""

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Callable

try:
    from server import handle_enhance_prompt_tool
except ImportError:
    from mcp_server.server import handle_enhance_prompt_tool  # type: ignore


EnhanceHandler = Callable[[dict[str, Any]], str]


def build_enhance_response(
    payload: dict[str, Any],
    *,
    enhance_handler: EnhanceHandler = handle_enhance_prompt_tool,
) -> dict[str, str]:
    """Return the response body for an Optimize Input button request."""
    draft = str(payload.get("draft", "") or "").strip()
    if not draft:
        raise ValueError("draft is required")

    enhanced = enhance_handler(payload)
    return {
        "draft": draft,
        "enhanced": enhanced,
    }


class OptimizeInputHandler(BaseHTTPRequestHandler):
    server_version = "PromptCocoPilotHTTP/0.1"

    def do_POST(self) -> None:
        if self.path != "/enhance":
            self._send_json(404, {"error": "not_found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
            response = build_enhance_response(payload)
        except ValueError as exc:
            self._send_json(400, {"error": str(exc)})
            return
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid_json"})
            return
        except Exception as exc:
            self._send_json(500, {"error": str(exc)})
            return

        self._send_json(200, response)

    def log_message(self, format: str, *args: Any) -> None:
        return

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run the local Optimize Input HTTP API."
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), OptimizeInputHandler)
    print(f"PromptCocoPilot Optimize Input API listening on http://{args.host}:{args.port}/enhance")
    server.serve_forever()


if __name__ == "__main__":
    main()
