"""Tests for assembling context-aware next-turn prompt enhancement input."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mcp-server"))

from context_packaging import CodeFact, ConversationMessage, PromptContext, assemble_enhancement_context


def test_assemble_enhancement_context_packages_history_code_facts_and_task_state():
    context = PromptContext(
        conversation=[
            ConversationMessage("user", "帮我看看登录模块这个接口是什么"),
            ConversationMessage("assistant", "我读取了 auth.py 和 session.py，发现登录接口会创建 session。"),
            ConversationMessage("user", "那这个怎么改"),
        ],
        code_facts=[
            CodeFact(
                path="src/auth.py",
                summary="login() validates password and calls create_session()",
                symbols=["login", "create_session"],
            ),
            CodeFact(
                path="src/session.py",
                summary="validate_session() returns 401 when token lookup misses",
                symbols=["validate_session"],
            ),
        ],
        task_state="正在定位有效用户登录后仍返回 401 Unauthorized 的原因。",
        current_file="src/auth.py",
        selected_code="def login(username, password): ...",
        user_preferences=["先说明根因，再给最小修改方案。"],
    )

    packaged = assemble_enhancement_context("那这个怎么改", context, max_messages=2)

    assert "Draft prompt:\n那这个怎么改" in packaged
    assert "Recent conversation" in packaged
    assert "assistant: 我读取了 auth.py" in packaged
    assert "Code facts already gathered" in packaged
    assert "src/auth.py" in packaged
    assert "login, create_session" in packaged
    assert "Current task state" in packaged
    assert "401 Unauthorized" in packaged
    assert "User preferences" in packaged


def test_assemble_enhancement_context_truncates_long_messages_without_losing_draft():
    long_message = "a" * 500
    context = PromptContext(
        conversation=[ConversationMessage("assistant", long_message)],
    )

    packaged = assemble_enhancement_context("继续", context, max_chars_per_message=80)

    assert "Draft prompt:\n继续" in packaged
    assert "a" * 80 in packaged
    assert "a" * 120 not in packaged


if __name__ == "__main__":
    test_assemble_enhancement_context_packages_history_code_facts_and_task_state()
    test_assemble_enhancement_context_truncates_long_messages_without_losing_draft()
    print("All context packaging tests passed.")
