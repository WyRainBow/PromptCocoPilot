# Installation for Claude Code

## 1. MCP Server Setup

1. Ensure Python 3.10+.
2. (Recommended) `pip install mcp` for full protocol support (the provided server.py is a minimal stdio implementation and works with many clients).
3. Copy or link the `mcp-server/` directory.

## 2. Configure in Claude Code / Desktop

Edit your config (usually `~/Library/Application Support/Claude/claude_desktop_config.json` on macOS or equivalent):

```json
{
  "mcpServers": {
    "prompt-enhancer": {
      "command": "python3",
      "args": [
        "/absolute/path/to/PromptCocoPilot/mcp-server/server.py"
      ],
      "env": {}
    }
  }
}
```

Restart Claude Code / Desktop.

## 3. Using the Skill

- Place the `skill/SKILL.md` in your `.claude/skills/prompt-enhancer/SKILL.md` (or follow your client's skill loading).
- Or simply ask Claude to use the `enhance_prompt` tool when prompts are vague.
- For best UX, combine with a thin client integration that auto-collects history and editor state and calls the tool.

## 4. Testing

Run the server manually:
```bash
python3 mcp-server/server.py
```
( it waits for stdio JSON-RPC).

Use the tool from chat: "enhance this prompt: fix the bug" (Claude should discover and use the tool).

For follow-up prompts during a coding task, pass structured context when possible:

```json
{
  "draft": "那这个怎么改",
  "conversation": [
    {"role": "assistant", "content": "Read src/auth.py and src/session.py; login succeeds but later session validation returns 401."}
  ],
  "code_facts": [
    {"path": "src/session.py", "summary": "validate_session returns 401 when token lookup misses", "symbols": ["validate_session"]}
  ],
  "task_state": "Investigating valid users receiving 401 after login",
  "current_file": "src/session.py",
  "selected_code": "def validate_session(token): ...",
  "user_preferences": ["Explain root cause first", "Prefer minimal code changes"]
}
```

See `examples/` for sample context assembly and full flows.

## Notes
- The enhancer is deliberately lightweight and only rewrites — it never executes the task.
- Pair with "Include recent history" setting for conversation-aware results.
- You can configure a fast/small model for the enhancement step in your host if supported.
