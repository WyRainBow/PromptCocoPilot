"""Basic tests for the enhance_prompt core logic."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'mcp-server'))

from enhance import enhance_next_prompt, enhance_prompt, clean, INSTRUCTION
from context_packaging import CodeFact, ConversationMessage, PromptContext

def test_clean_strips_fences():
    assert clean("```python\nfoo\n```") == "foo"
    assert clean('"bar"') == "bar"
    assert clean("baz") == "baz"

def test_enhance_returns_something():
    result = enhance_prompt("fix auth", generate_fn=lambda user, system: "Task: fix auth")
    assert isinstance(result, str)
    assert len(result) > 0
    # In fallback it contains "Task:" or similar
    assert "fix auth" in result or "Task" in result.lower()

def test_enhance_with_context():
    result = enhance_prompt(
        "add test",
        "Current file: auth.py, selected: the login function",
        generate_fn=lambda user, system: "Add a test for auth.py login behavior.",
    )
    assert "add test" in result or "auth.py" in result or "context" in result.lower()

def test_instruction_is_strict():
    assert "rewrite" in INSTRUCTION.lower()
    assert "never as a request to answer" in INSTRUCTION.lower()

def test_enhance_next_prompt_passes_packaged_context_to_rewriter():
    captured = {}

    def fake_generate(user_content, system_instruction):
        captured["user_content"] = user_content
        captured["system_instruction"] = system_instruction
        return "请基于 auth.py 和 session.py 中已定位的 401 问题，给出最小修改方案。"

    result = enhance_next_prompt(
        "那这个怎么改",
        PromptContext(
            conversation=[
                ConversationMessage("assistant", "我已经读取 auth.py，发现 login 会创建 session。")
            ],
            code_facts=[
                CodeFact("src/session.py", "validate_session returns 401 on token miss", ["validate_session"])
            ],
            task_state="有效用户登录后仍返回 401。",
        ),
        generate_fn=fake_generate,
    )

    assert "最小修改方案" in result
    assert "Draft prompt:\n那这个怎么改" in captured["user_content"]
    assert "src/session.py" in captured["user_content"]
    assert "401" in captured["user_content"]
    assert captured["system_instruction"] == INSTRUCTION

if __name__ == "__main__":
    test_clean_strips_fences()
    test_enhance_returns_something()
    test_enhance_with_context()
    test_instruction_is_strict()
    test_enhance_next_prompt_passes_packaged_context_to_rewriter()
    print("All basic tests passed.")
