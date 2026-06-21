# Codex “优化输入” Button Integration

This project cannot directly patch the closed Codex desktop input toolbar from this repository. Instead, it now provides the stable local API that a Codex UI button can call.

## Button Behavior

Suggested label: `优化输入`

Suggested placement: next to the microphone/send controls in the input toolbar.

Click flow:

1. Read the current input draft.
2. Collect recent visible chat messages.
3. Collect code facts already gathered by Codex during the current task.
4. Add current file, selected code, task state, and user preferences when available.
5. POST the payload to PromptCocoPilot.
6. Replace the input text with the returned `enhanced` value, or show a review diff before replacing.

The button should never auto-send. It only optimizes the draft for user review.

## Local HTTP API

Start the local API:

```bash
python3 mcp-server/http_server.py --host 127.0.0.1 --port 8765
```

Endpoint:

```text
POST http://127.0.0.1:8765/enhance
Content-Type: application/json
```

Example request:

```json
{
  "draft": "那这个怎么改",
  "conversation": [
    {
      "role": "assistant",
      "content": "已读取 src/auth.py 和 src/session.py，发现 validate_session 可能返回 401。"
    }
  ],
  "code_facts": [
    {
      "path": "src/session.py",
      "summary": "validate_session returns 401 when token lookup misses",
      "symbols": ["validate_session"]
    }
  ],
  "task_state": "正在定位有效用户登录后仍返回 401 的原因。",
  "current_file": "src/session.py",
  "selected_code": "def validate_session(token): ...",
  "user_preferences": [
    "先说明根因，再给最小修改方案。",
    "修改后补充测试。"
  ]
}
```

Example response:

```json
{
  "draft": "那这个怎么改",
  "enhanced": "基于前面已读取的 src/auth.py 和 src/session.py，请定位有效用户登录后仍返回 401 Unauthorized 的根因，并给出最小修改方案..."
}
```

## Codex Toolbar Adapter Pseudocode

```ts
async function onOptimizeInputClick() {
  const draft = input.getValue()
  const payload = {
    draft,
    conversation: getVisibleRecentMessages(12),
    code_facts: getGatheredCodeFacts(),
    task_state: getCurrentTaskState(),
    current_file: editor.currentFilePath(),
    selected_code: editor.selectedText(),
    user_preferences: getUserPreferences(),
  }

  const response = await fetch("http://127.0.0.1:8765/enhance", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(payload),
  })

  const {enhanced} = await response.json()
  input.setValue(enhanced)
  input.focus()
}
```

## Privacy Boundary

Only visible chat text and explicit code facts should be sent. Hidden model reasoning is not available and should not be included. Prefer compact, verifiable facts over full raw transcripts.
