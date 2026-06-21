# Prompt Enhancer Skill

**Purpose**: Pre-send optimization of user prompts using full conversation context. Replicates the excellent "Enhance Prompt" UX and behavior from Kilo Code.

**When to use**:
- User gives a vague, short, or incomplete instruction in chat.
- You want to make the prompt clearer, more specific, and grounded in current task history before acting.
- Always offer the enhanced version for user review before executing.

**How it works**:
1. User types a draft in the input.
2. You (or user via command) call the `enhance_prompt` MCP tool.
3. Provide the draft + relevant context from the current conversation/task (recent messages, current files if known, selected code snippets).
4. The tool returns an improved prompt.
5. Present the before/after to the user (or directly replace in input if UX supports).
6. User reviews and sends the improved version.

**Tool Usage (via MCP)**:
Call `enhance_prompt` with:
- `draft`: The user's raw input.
- `context`: Concatenated relevant history + editor context. Example format:
  ```
  Recent conversation:
  User: ...
  Assistant: ...

  Current file: auth/login.py
  Selected code: def check_session(...)

  Draft: fix the auth bug
  ```

The tool will return only the enhanced prompt text.

**Best Practices**:
- **Auto-trigger on vague inputs**: If the user's message is short, ambiguous, or lacks specifics (e.g. "fix bug", "add feature", "make it better"), **automatically call the enhance_prompt tool** before doing any work.
- Include last 8-12 messages as history by default. Claude Code can summarize or select relevant turns if context is too long.
- Always surface the **before/after** for human review (transparency is key, just like Kilo Code's ✨ button).
- Present what was improved (e.g. "Added specific file references and success criteria from recent discussion").
- Do **not** execute the original vague prompt directly.
- The enhancement uses a fast model (via Dashscope in the MCP server) to keep latency low.
- Support passing extra context: current file paths, selected code, project conventions, user preferences.

**Advanced Features Supported**:
- Conversation history awareness (cross-turn intent accumulation)
- Editor/workspace context injection (files, selections)
- Structured output: The enhanced prompt should be ready-to-send, concrete, with clear steps or requirements.
- User can edit the result before sending (the tool returns text you can modify in the input box).
- Long-term: In future, can incorporate persistent user style/preferences (for now, rely on recent context + explicit instructions).

**Example Flow (Automatic)**:
User types: "fix the auth"
Claude (following this skill):
1. Detects vague prompt.
2. Assembles context: recent messages about login 401 + current file src/auth/login.py + selected function.
3. Calls enhance_prompt tool with draft + full context.
4. Gets improved prompt.
5. Shows user: 
   "I used the prompt enhancer. Here's the optimized version:

   [enhanced text]

   Changes: Added file reference, specific error, expected behavior from history.
   Does this look correct? (You can edit it before sending)"

**Tool Usage (via MCP)**:
Call `enhance_prompt` with:
- `draft`: The user's raw input.
- `context`: Concatenated relevant history + editor context. Example format:
  ```
  Recent conversation (last turns):
  User: ...
  Assistant: ...

  Current file: auth/login.py
  Selected code: def check_session(...)

  Draft: fix the auth bug
  ```

The tool will return only the enhanced prompt text (cleaned).

**Configuration**:
- Pair with the MCP server in `mcp-server/server.py` (it auto-detects DASHSCOPE_API_KEY from env or /Users/wy770/Resume-Agent/.env and performs real enhancement).
- For best results, in Claude Code settings or prompts, prefer including recent task history when calling the tool.
- The server uses a fast model for enhancement to save tokens/latency.

This skill makes every input as powerful as if the user had written a perfect prompt from the start, with full context awareness. It closely replicates Kilo Code's Enhance Prompt flow inside Claude Code via MCP + Skill.

See `docs/claude-code-integration.md` and `docs/TECH_SCHEME.md` for setup, advanced strategies, and technical details.