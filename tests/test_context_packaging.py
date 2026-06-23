"""Tests for context assembly improvements."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mcp-server"))

from context_packaging import (
    CodeFact,
    ConversationMessage,
    PromptContext,
    assemble_enhancement_context,
    _dedup_code_facts,
    _truncate_smart,
    DEFAULT_CONTEXT_BUDGET,
)


def test_assemble_packages_all_fields():
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


def test_smart_truncation_keeps_head_and_tail():
    long_message = "START" + "middle" * 100 + "END"
    result = _truncate_smart(long_message, 40)
    assert "START" in result
    assert "END" in result
    assert "…[truncated]…" in result
    assert len(result) < len(long_message)


def test_smart_truncation_passes_short_messages_unchanged():
    short = "hello world"
    assert _truncate_smart(short, 200) == short


def test_dedup_code_facts_merges_same_path():
    facts = [
        CodeFact("src/auth.py", "login creates session", ["login"]),
        CodeFact("src/auth.py", "create_session stores token in Redis", ["create_session"]),
        CodeFact("src/session.py", "validate_session checks token", ["validate_session"]),
    ]
    deduped = _dedup_code_facts(facts)
    assert len(deduped) == 2
    auth_fact = next(f for f in deduped if f.path == "src/auth.py")
    assert "login creates session" in auth_fact.summary
    assert "create_session stores token" in auth_fact.summary
    assert "login" in auth_fact.symbols
    assert "create_session" in auth_fact.symbols


def test_dedup_code_facts_no_duplicate_symbols():
    facts = [
        CodeFact("src/auth.py", "summary A", ["login", "logout"]),
        CodeFact("src/auth.py", "summary B", ["login", "register"]),
    ]
    deduped = _dedup_code_facts(facts)
    assert len(deduped) == 1
    syms = list(deduped[0].symbols)
    assert syms.count("login") == 1  # no duplicate


def test_project_summary_included():
    context = PromptContext(
        project_summary="Python Flask app with Redis sessions. Auth module in src/auth/."
    )
    packaged = assemble_enhancement_context("fix login", context)
    assert "Project context:" in packaged
    assert "Python Flask app" in packaged


def test_workspace_files_shown():
    context = PromptContext(
        workspace_files=["src/auth.py", "src/session.py", "tests/test_auth.py"],
    )
    packaged = assemble_enhancement_context("add test", context)
    assert "Workspace files" in packaged
    assert "src/auth.py" in packaged


def test_workspace_files_capped_at_40():
    files = [f"src/module_{i}.py" for i in range(60)]
    context = PromptContext(workspace_files=files)
    packaged = assemble_enhancement_context("fix bug", context)
    assert "src/module_0.py" in packaged
    assert "src/module_39.py" in packaged
    assert "src/module_40.py" not in packaged
    assert "20 more" in packaged


def test_budget_enforcement_trims_conversation():
    # Create a huge conversation that exceeds the budget
    big_messages = [
        ConversationMessage("assistant", "x" * 600) for _ in range(12)
    ]
    context = PromptContext(conversation=big_messages)
    packaged = assemble_enhancement_context(
        "fix bug", context, context_budget=3_000
    )
    # Result should be within roughly 2x budget tolerance (budget is approximate)
    assert len(packaged) < DEFAULT_CONTEXT_BUDGET * 2


def test_assemble_truncates_long_messages_keeping_tail():
    # The conclusion appears at the end — must not be lost
    long_message = "preamble " * 50 + "IMPORTANT CONCLUSION"
    context = PromptContext(
        conversation=[ConversationMessage("assistant", long_message)],
    )
    packaged = assemble_enhancement_context("next step?", context, max_chars_per_message=200)
    assert "IMPORTANT CONCLUSION" in packaged


if __name__ == "__main__":
    test_assemble_packages_all_fields()
    test_smart_truncation_keeps_head_and_tail()
    test_smart_truncation_passes_short_messages_unchanged()
    test_dedup_code_facts_merges_same_path()
    test_dedup_code_facts_no_duplicate_symbols()
    test_project_summary_included()
    test_workspace_files_shown()
    test_workspace_files_capped_at_40()
    test_budget_enforcement_trims_conversation()
    test_assemble_truncates_long_messages_keeping_tail()
    print("All context packaging tests passed.")
