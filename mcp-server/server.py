#!/usr/bin/env python3
"""
MCP Server for Claude Code Prompt Enhancer.

Exposes a context-aware enhance_prompt tool.

This replicates the "Enhance Prompt" capability from Kilo Code as a reusable MCP tool.

Usage in Claude Code:
1. Add to your MCP config (claude_desktop_config.json or equivalent):
   {
     "mcpServers": {
       "prompt-enhancer": {
         "command": "python3",
         "args": ["/path/to/this/server.py"]
       }
     }
   }

2. The tool "enhance_prompt" will be available.
   Call it with draft prompt and optional context (history, files, etc.).

The server uses the core enhance logic.
For production, integrate with your preferred LLM provider inside the enhance call or let the host model handle if using skill mode.
"""

import sys
import json
from typing import Any

# Add local path
sys.path.insert(0, ".")

try:
    from enhance import enhance_prompt
except ImportError:
    from mcp_server.enhance import enhance_prompt  # type: ignore

# Simple MCP stdio server implementation (compatible with common Claude MCP clients)
# For full compliance, `pip install mcp` and use the official SDK is recommended.
# This is a minimal working version for tool registration and calls.

def send(message: dict):
    print(json.dumps(message), flush=True)

def main():
    # Handshake / init (basic)
    for line in sys.stdin:
        try:
            req = json.loads(line.strip())
        except Exception:
            continue

        method = req.get("method")
        req_id = req.get("id")

        if method == "initialize":
            send({
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {}
                    },
                    "serverInfo": {
                        "name": "prompt-enhancer",
                        "version": "0.1.0"
                    }
                }
            })
        elif method == "tools/list":
            send({
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "tools": [
                        {
                            "name": "enhance_prompt",
                            "description": "Rewrite and optimize a user prompt using provided context (conversation history, current files, selections, etc.). Returns an improved version ready for review and sending. Replicates Kilo Code Enhance Prompt behavior.",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "draft": {
                                        "type": "string",
                                        "description": "The raw user input/prompt to enhance."
                                    },
                                    "context": {
                                        "type": "string",
                                        "description": "Optional context: recent conversation history, current file paths, selected code, user preferences, etc."
                                    },
                                    "include_history": {
                                        "type": "boolean",
                                        "description": "Whether to include conversation history (if context not directly provided)."
                                    }
                                },
                                "required": ["draft"]
                            }
                        }
                    ]
                }
            })
        elif method == "tools/call":
            params = req.get("params", {})
            tool_name = params.get("name")
            arguments = params.get("arguments", {})

            if tool_name == "enhance_prompt":
                draft = arguments.get("draft", "")
                context = arguments.get("context") or ""
                # Simple handling
                enhanced = enhance_prompt(draft, context or None)
                send({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "content": [
                            {
                                "type": "text",
                                "text": enhanced
                            }
                        ]
                    }
                })
            else:
                send({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": "Tool not found"}
                })
        else:
            # Unknown - ignore or error
            if req_id:
                send({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": "Method not found"}
                })

if __name__ == "__main__":
    main()