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

# Context awareness: screen-aware reply generation
try:
    from enhance import generate_reply_suggestions
except ImportError:
    try:
        from mcp_server.enhance import generate_reply_suggestions
    except ImportError:
        generate_reply_suggestions = None  # type: ignore


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


def build_generate_reply_response(payload: dict[str, Any]) -> dict[str, Any]:
    """Return reply suggestions for the current screen context.
    
    Payload shape (all optional except context):
        {
            "context": { ... ContextAwareness.Context JSON ... },
            "draft": "optional existing draft text",
            "num_suggestions": 3,
        }
    
    Response shape:
        {
            "suggestions": ["回复选项1", "回复选项2", ...],
            "context_summary": "App: 飞书 | Window: ... | URL: ...",
        }
    """
    if generate_reply_suggestions is None:
        raise RuntimeError("generate_reply_suggestions not available — ensure enhance.py is in the Python path")

    context: dict[str, Any] = payload.get("context", {})
    draft: str = str(payload.get("draft", "") or "").strip()
    num: int = min(int(payload.get("num_suggestions", 3)), 5)

    suggestions = generate_reply_suggestions(
        context=context,
        existing_draft=draft,
        num_suggestions=num,
    )

    # Build human-readable context summary
    app_name = context.get("appName", "")
    window_title = context.get("windowTitle", "")
    page_url = context.get("pageURL", "")
    parts = []
    if app_name:
        parts.append(f"App: {app_name}")
    if window_title:
        parts.append(f"Window: {window_title}")
    if page_url:
        parts.append(f"URL: {page_url}")
    summary = " | ".join(parts) if parts else "Unknown context"

    return {
        "suggestions": suggestions,
        "context_summary": summary,
    }


class OptimizeInputHandler(BaseHTTPRequestHandler):
    server_version = "PromptCocoPilotHTTP/0.1"

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self) -> None:
        # Health check for server_alive() probe
        if self.path == "/":
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(b"OK")
            return
        self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path == "/enhance":
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
            return

        if self.path == "/generate_reply":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
                response = build_generate_reply_response(payload)
            except RuntimeError as exc:
                self._send_json(503, {"error": str(exc)})
                return
            except json.JSONDecodeError:
                self._send_json(400, {"error": "invalid_json"})
                return
            except Exception as exc:
                self._send_json(500, {"error": str(exc)})
                return
            self._send_json(200, response)
            return

        self._send_json(404, {"error": "not_found"})

    def log_message(self, format: str, *args: Any) -> None:
        return

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")


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
