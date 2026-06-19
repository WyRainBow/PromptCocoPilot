# Technical Scheme: Context-Aware Prompt Enhancer Skill for Claude Code

**Project**: Claude Code Prompt Enhancer (Context-aware Input Optimizer)
**Reference**: Kilo Code "Enhance Prompt" feature (enhance-prompt.ts)
**Goal**: Deliver a reusable, context-aware input optimization capability primarily for Claude Code users, with MCP and Skill interfaces.

## 1. Architecture Overview

Hybrid approach (as recommended):
- **Core Logic**: Lightweight, dedicated prompt rewriter (no full agent loop).
- **Exposure**: MCP Tool (universal) + SKILL.md (Claude Code native).
- **UI Layer**: Thin caller (future plugins) responsible for assembling context and presenting review UI.
- **Context Sources**: Conversation history (task messages), editor state (file + selection), user-provided.

This mirrors Kilo Code exactly:
- Backend does pure rewrite using strict instructions.
- Caller (UI) injects rich context before the rewrite call.
- Result is returned to input for human review.

## 2. Core Components

### 2.1 Enhance Logic (`mcp-server/enhance.py`)
- `INSTRUCTION`: Strict system prompt (copied/adapted from Kilo):
  - Rewrite only.
  - Never answer/execute/discuss the content.
  - Return only the enhanced prompt.
  - Clean output (no fences, no quotes).
- `enhance_prompt(draft, context=None, generate_fn=None)`:
  - Assembles "Draft prompt to enhance..." message.
  - Supports prepending context.
  - Falls back to simple structured improvement for testing.
  - Production: pass a `generate_fn` that uses the user's preferred model (small/fast model recommended for speed).

Why direct generateText equivalent:
- Fast, low token, no tool use or agent overhead.
- Matches Kilo's comment: "Lightweight prompt enhancement... no agent identity, tools, or plugins."

### 2.2 MCP Server (`mcp-server/server.py`)
- Stdio JSON-RPC compatible with Claude MCP clients.
- Registers tool `enhance_prompt`.
- Input: `draft` (required), `context` (optional string), `include_history`.
- Output: Enhanced text only.
- Can be extended to support full `mcp` SDK.

Deployment:
- Run as persistent process.
- Configured in Claude's MCP servers list.

### 2.3 Skill Definition (`skill/SKILL.md`)
- Instructs Claude *when* and *how* to use the tool.
- Emphasizes review step.
- Provides context assembly guidance.
- Can be loaded automatically or via /skill-name.

### 2.4 Context Assembly (Examples)
- See `examples/context-assembly.py`.
- Typical: recent_messages (last N) + current_file + selected_code.
- In advanced callers (plugins): pull from editor API + session store.
- For pure skill mode: Claude can summarize recent turns itself and pass as context.

## 3. Integration with Claude Code

1. MCP registration → tool becomes available.
2. Skill file → Claude knows the procedure and best practices.
3. User experience:
   - User types vague prompt.
   - Claude (guided by skill or user) calls tool with assembled context.
   - Presents enhanced version.
   - User approves → sends the optimized prompt.

This delivers the "raw input → context completion → rewrite → human review → send" flow.

## 4. Comparison to Kilo Code

- Kilo: ✨ button in UI → assembles context (history + codebase) → calls enhance → replaces input.
- Ours: MCP tool + Skill instructions → same logic.
- Advantage: Works in any MCP-capable host (Claude Code, other agents). Can be called programmatically or by the model.
- Future: Thin VS Code / CLI wrappers that add the button + auto context collection (exactly like Kilo).

## 5. Design Decisions & Trade-offs

- **Lightweight rewriter vs full agent**: Chose lightweight (Kilo pattern) for speed and to avoid side effects. Enhancement should never run tools or produce side effects itself.
- **MCP first**: Provides universality. Skills are prompt-instructions; MCP provides the actual capability.
- **Context passed in, not auto-fetched in core**: Core stays pure. Callers (plugins, hosts, or Claude itself) decide what context matters. This is flexible and privacy-friendly.
- **No default interval or auto-fire in core**: The enhancer is on-demand or triggered by skill rules.
- **Fallback in enhance**: For development/testing without real LLM. Production always provides generate_fn or integrates with host model routing.
- **Python**: Easy to run as MCP server, matches common Claude ecosystem patterns.

## 6. Extensibility

- Add more tools: `suggest_clarifying_questions`, `decompose_task`.
- Structured output: Return JSON with "enhanced", "changes", "assumptions".
- History strategies: Configurable N messages, summary, or key facts only.
- Model selection: Support small model for enhancement step.
- Plugins: Future VS Code extension that calls this MCP and injects editor state automatically.

## 7. Verification & Quality

- Unit tests for clean() and enhance_prompt (with/without context).
- Syntax checks on all Python.
- The server is a minimal but functional stdio MCP implementation.
- All code committed only after verification.

## 8. Roadmap / Remaining (if any)

- Full MCP SDK compliance (optional, current stdio works for most).
- Example full context assembler for a specific editor.
- CLI wrapper.
- Benchmarks against raw prompts.
- Integration tests with actual Claude Code (manual).

## 9. Files Created (Summary)

- README.md
- mcp-server/enhance.py (core)
- mcp-server/server.py (MCP exposure)
- skill/SKILL.md
- docs/install.md
- docs/TECH_SCHEME.md (this file)
- examples/context-assembly.py
- tests/test_enhance.py

All commits follow Conventional Commits.

This scheme ensures the skill is:
- Faithful to the Kilo Code reference.
- Practical for Claude Code users.
- Extensible and composable via MCP.
- Focused on the pre-send optimization use case with full context awareness.

---

*Generated during full-auto execution.*