"""Tests for MCP tool argument handling."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mcp-server"))

import server


def test_handle_enhance_prompt_tool_packages_structured_context(monkeypatch=None):
    captured = {}

    def fake_enhance_prompt(draft, context=None):
        captured["draft"] = draft
        captured["context"] = context
        return "enhanced prompt"

    server.enhance_prompt = fake_enhance_prompt

    result = server.handle_enhance_prompt_tool(
        {
            "draft": "那这个怎么改",
            "conversation": [
                {"role": "assistant", "content": "已读取 src/auth.py 和 src/session.py。"}
            ],
            "code_facts": [
                {
                    "path": "src/session.py",
                    "summary": "validate_session may return 401 for valid users",
                    "symbols": ["validate_session"],
                }
            ],
            "task_state": "正在定位登录后 401。",
        }
    )

    assert result == "enhanced prompt"
    assert captured["draft"] == "那这个怎么改"
    assert "Draft prompt:\n那这个怎么改" in captured["context"]
    assert "src/session.py" in captured["context"]
    assert "401" in captured["context"]


if __name__ == "__main__":
    test_handle_enhance_prompt_tool_packages_structured_context()
    print("All server tool tests passed.")
