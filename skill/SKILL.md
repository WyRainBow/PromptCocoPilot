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
- Include last 5-10 messages as history by default (configurable in settings).
- Always surface the enhanced prompt for human review (transparency).
- Do not execute the original vague prompt directly.
- Use a fast/small model for the enhancement step if your host supports it (saves tokens and latency).

**Example Invocation in Claude Code chat**:
User: "add login"
You (internally):
Call enhance_prompt with draft="add login", context= [paste relevant recent messages + files]

Then respond with:
"Enhanced prompt: [result]

Does this look good? Shall I proceed with the improved version?"

**Configuration**:
- Pair with the MCP server in `mcp-server/server.py`.
- For best results, enable "include task history" equivalent in your client settings.

This skill makes every input as powerful as if the user had written a perfect prompt from the start. 

See `docs/` and `examples/` for full setup and advanced context strategies.