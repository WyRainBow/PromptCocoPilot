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

## Reference
- Replicates the pattern from Kilo Code's Enhance Prompt (see `enhance-prompt.ts` in Kilo-Org/kilocode).
- Uses strict rewrite instruction to only improve the draft, not execute it.

## Status
In development - full auto execution mode active.

## License
MIT (or match target).

## Technical Scheme
See `docs/TECH_SCHEME.md` for complete architecture, implementation details, and decisions.