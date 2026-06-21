# Qoder Prompt Enhancer Integration

Qoder is an AI coding IDE (similar to Cursor/Claude Code) with MCP support.

## Architecture (Same as Claude)
- MCP Tool: `enhance_prompt` (in mcp-server/server.py + enhance.py)
- Skill guidance: Use SKILL.md logic (adapt for Qoder if it supports skills/quests)

The enhancer:
- Takes `draft` + `context` (conversation history, files, selections)
- Uses real LLM (Dashscope/DeepSeek via compatible API) with strict rewrite instruction (from Kilo Code pattern)
- Returns only the enhanced prompt (cleaned)
- Fast model for low latency, separate from main agent context

## Setup in Qoder
1. MCP config: Add to `~/.qoder/mcp.json` (or relevant `mcp.json` in `~/.qoder/plugins/cache/.../qoder-computer-use/`)

Example (we have added this):
```json
{
  "mcpServers": {
    "prompt-enhancer": {
      "command": "python3",
      "args": ["/Users/wy770/Desktop/PromptCocoPilot/mcp-server/server.py"],
      "env": {
        "DASHSCOPE_API_KEY": "sk-722ca9b566444513a605d125768a0673"
      }
    }
  }
}
```

2. Launch Qoder with your project (e.g. Resume-Agent for login tests):
   ```bash
   open -a Qoder /Users/wy770/Resume-Agent
   ```

3. Restart Qoder after editing mcp.json.

4. In Qoder, look for MCP tools (similar to /mcp in Claude) – `enhance_prompt` should appear.

## Fair Testing in Qoder Quest/Tasks
- Start a **completely fresh chat** (no preceding dialogue or project history in chat).
- **Base test** (no enhancer): Directly paste vague prompt, e.g.:
  - "帮我看看登录模块这个接口是什么"
  - Observe: Qoder searches code, may enhance internally or ask questions.
- **With enhancer**:
  - If Qoder supports `/prompt-enhancer` command (like Claude), use:
    `/prompt-enhancer 帮我看看登录模块这个接口是什么`
  - Or manually invoke MCP tool `enhance_prompt` (draft + context from recent turns/files).
  - Expected: Before/After shown, changes explained, user reviews before sending.

Use the skill logic from `skill/SKILL.md`:
- Auto-trigger on vague inputs.
- Assemble context (last N messages + current file/selection).
- Call tool.
- Present for review.
- Do not execute original vague prompt.

## Comparison to Base (from tests)
- Base (no tool): Direct search + broad answer or clarification. May miss structure, no explicit before/after.
- With enhancer: Searches first (via Qoder tools or manual), rewrites prompt using real model + context, outputs enhanced version with explanation and options. More precise, transparent, user-controlled.

See user's Claude tests for examples (e.g., vague login prompt -> enhanced with specific files like auth.py/better_auth.py, offered 3 ready versions).

## Advanced
- Context assembly example: see `examples/context-assembly.py`
- Real enhancement in `mcp-server/enhance.py` (uses Dashscope if key available).
- For Qoder quests: Use in agent/task modes for context-aware prompt improvement.

Restart Qoder and verify MCP after changes.

## Status
MCP added to Qoder config. Test with fresh session in Qoder quest.

See main README and TECH_SCHEME.md for more.
