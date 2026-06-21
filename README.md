# Claude Code Prompt Enhancer Skill

A context-aware input optimizer skill for Claude Code, replicating the "Enhance Prompt" feature from Kilo Code.

## Goal
Provide a pre-send prompt optimization layer that:
- Reads current conversation history and task context.
- Rewrites/optimizes the user's draft input for clarity, specificity, and completeness.
- Supports adding relevant context (files, selections, history).
- Allows user review before sending (transparent).

## Features (Target)
- Lightweight dedicated rewriter (like Kilo's enhance-prompt.ts).
- Conversation history support (last N messages).
- Editor/workspace context integration via MCP or caller.
- MCP Tool exposure for use in Claude Code and other agents.
- SKILL.md for easy integration in Claude Code.
- Review-before-send UX pattern.

## Project Structure
- `skill/` - SKILL.md and supporting files for Claude Code skills.
- `mcp-server/` - Python MCP server providing the `enhance_prompt` tool.
- `docs/` - Detailed documentation and technical scheme.
- `examples/` - Usage examples and configurations.
- `tests/` - Verification scripts and tests.

## Installation (Claude Code)
1. Install the MCP server.
2. Add to claude_desktop_config.json or equivalent.
3. Use the skill or call the tool from chat.

See `docs/install.md` and `examples/` for details.

## Qoder Support
Qoder (AI coding IDE) supports MCP servers via `~/.qoder/mcp.json` (or per-plugin mcp.json in `~/.qoder/plugins/`).

We have added the prompt-enhancer MCP entry:
```json
{
  "mcpServers": {
    "prompt-enhancer": {
      "command": "python3",
      "args": ["/Users/wy770/Desktop/PromptCocoPilot/mcp-server/server.py"],
      "env": {
        "DASHSCOPE_API_KEY": "sk-..."
      }
    }
  }
}
```

Launch Qoder with project:
```bash
open -a Qoder /path/to/your/project
```

Start a fresh chat (no preceding dialogue) for fair base test.

- Base: directly ask vague prompt (e.g. "帮我看看登录模块这个接口是什么").
- With enhancer: use `/prompt-enhancer <vague prompt>` if supported, or invoke the `enhance_prompt` MCP tool with draft + context (history/files).

See `docs/qoder-integration.md` (to be added) and previous Claude tests for patterns.

Restart Qoder after config changes. Check MCP tools list in Qoder.

## Reference
- Replicates the pattern from Kilo Code's Enhance Prompt (see `enhance-prompt.ts` in Kilo-Org/kilocode).
- Uses strict rewrite instruction to only improve the draft, not execute it.

## Status
✅ Core implemented as Skills + MCP only.

- Real Dashscope (via Resume-Agent key or env) enhancement integrated in enhance.py (no more weak fallback).
- Advanced features added to SKILL.md: auto-trigger on vague inputs, full history context, transparent before/after + changes summary, editor context support, review-before-send.
- MCP server updated for real LLM rewrite matching Kilo Code pattern.
- Config example and integration guide in docs/.

To test: Configure the MCP in your Claude Code, add the skill, run `claude`, and use vague prompts. The skill will guide auto-enhance with real model.

## Qoder Testing
- MCP added to `~/.qoder/mcp.json`
- Launch: `open -a Qoder /path/to/project` (e.g. Resume-Agent)
- Fresh chat (no preceding dialogue) for base test vs `/prompt-enhancer` or MCP `enhance_prompt`.
- See `docs/qoder-integration.md` and `docs/TECH_SCHEME.md` for setup and comparison.

## License
MIT (or match target).

## Technical Scheme
See `docs/TECH_SCHEME.md` for complete architecture, implementation details, and decisions.