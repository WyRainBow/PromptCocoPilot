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

The server uses the core enhance logic with **real Dashscope** support (auto-loads DASHSCOPE_API_KEY from env or /Users/wy770/Resume-Agent/.env and calls the compatible endpoint for high-quality rewrite, just like Kilo Code's dedicated enhancer).

The enhancement is performed inside the MCP server using a fast model (default: deepseek-v4-flash via Dashscope). This keeps it lightweight and separate from the main Claude session.
"""

import sys
import json
from typing import Any

# Add local path
sys.path.insert(0, ".")

try:
    from enhance import enhance_prompt
    from context_packaging import assemble_enhancement_context, prompt_context_from_dict
except ImportError:
    from mcp_server.enhance import enhance_prompt  # type: ignore
    from mcp_server.context_packaging import assemble_enhancement_context, prompt_context_from_dict  # type: ignore

# Simple MCP stdio server implementation (compatible with common Claude MCP clients)
# For full compliance, `pip install mcp` and use the official SDK is recommended.
# This is a minimal working version for tool registration and calls.

def send(message: dict):
    print(json.dumps(message), flush=True)

def handle_enhance_prompt_tool(arguments: dict[str, Any]) -> str:
    draft = arguments.get("draft", "")
    context = arguments.get("context") or ""
    structured_output = bool(arguments.get("structured_output", False))

    structured_context_keys = {
        "conversation",
        "code_facts",
        "task_state",
        "current_file",
        "selected_code",
        "user_preferences",
        "project_summary",
        "workspace_files",
    }
    if any(key in arguments for key in structured_context_keys):
        packaged_context = assemble_enhancement_context(
            draft,
            prompt_context_from_dict(arguments),
        )
        context = f"{context}\n\n{packaged_context}".strip() if context else packaged_context

    enhanced = enhance_prompt(draft, context or None)

    if structured_output:
        import json as _json
        return _json.dumps({
            "original": draft,
            "enhanced": enhanced,
            "context_used": bool(context),
        }, ensure_ascii=False)
    return enhanced

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
                                    },
                                    "conversation": {
                                        "type": "array",
                                        "description": "Recent conversation messages to package with the draft for next-turn enhancement.",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "role": {"type": "string"},
                                                "content": {"type": "string"}
                                            },
                                            "required": ["role", "content"]
                                        }
                                    },
                                    "code_facts": {
                                        "type": "array",
                                        "description": "Facts already learned from reading the codebase, including files, summaries, and symbols.",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "path": {"type": "string"},
                                                "summary": {"type": "string"},
                                                "symbols": {
                                                    "type": "array",
                                                    "items": {"type": "string"}
                                                }
                                            }
                                        }
                                    },
                                    "task_state": {
                                        "type": "string",
                                        "description": "Current investigation or implementation state to preserve across the rewrite."
                                    },
                                    "current_file": {
                                        "type": "string",
                                        "description": "Current editor file path, if known."
                                    },
                                    "selected_code": {
                                        "type": "string",
                                        "description": "Current selected code or relevant snippet, if known."
                                    },
                                    "user_preferences": {
                                        "type": "array",
                                        "description": "User constraints or style preferences to carry into the enhanced prompt.",
                                        "items": {"type": "string"}
                                    },
                                    "project_summary": {
                                        "type": "string",
                                        "description": "High-level description of the project: tech stack, main modules, architecture. Equivalent to Kilo Code's workspace summary. Helps the enhancer add project-specific context."
                                    },
                                    "workspace_files": {
                                        "type": "array",
                                        "description": "Lightweight list of relevant file paths in the project (up to 40 shown). Gives the enhancer a sense of codebase structure.",
                                        "items": {"type": "string"}
                                    },
                                    "structured_output": {
                                        "type": "boolean",
                                        "description": "If true, return JSON with {original, enhanced, context_used} instead of plain text."
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
                enhanced = handle_enhance_prompt_tool(arguments)
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
