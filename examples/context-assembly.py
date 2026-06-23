"""
Example of how a caller (VS Code extension, wrapper, or skill host) can assemble context
before calling the enhance_prompt tool.

This mirrors Kilo Code's approach of providing task history + editor context.
Use the structured PromptContext API for best results; this example shows the
legacy free-form string approach as a fallback.
"""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "mcp-server"))

from context_packaging import (
    ConversationMessage,
    CodeFact,
    PromptContext,
    assemble_enhancement_context,
)
from typing import List, Dict


def assemble_context_freeform(
    recent_messages: List[Dict[str, str]],
    current_file: str = "",
    selected_code: str = "",
    max_history: int = 12,
    max_chars_per_message: int = 600,
) -> str:
    """Build a compact context string for the enhancer (free-form fallback).

    Prefer the structured PromptContext API (assemble_enhancement_context) when
    possible — it deduplicates code facts, enforces a total budget, and uses
    smart head+tail truncation for long messages.
    """
    parts = []
    if recent_messages:
        history_lines = []
        for m in recent_messages[-max_history:]:
            content = m.get("content", "")
            if len(content) > max_chars_per_message:
                head = int(max_chars_per_message * 0.6)
                tail = max_chars_per_message - head
                content = content[:head].rstrip() + "\n…\n" + content[-tail:].lstrip()
            history_lines.append(f"{m['role']}: {content}")
        parts.append(f"Recent conversation history:\n" + "\n".join(history_lines))

    if current_file:
        parts.append(f"Current file: {current_file}")

    if selected_code:
        if len(selected_code) > 1200:
            head = int(1200 * 0.6)
            tail = 1200 - head
            selected_code = selected_code[:head].rstrip() + "\n…\n" + selected_code[-tail:].lstrip()
        parts.append(f"Selected code:\n{selected_code}")

    return "\n\n".join(parts)


# ---- Structured approach (recommended) ----

if __name__ == "__main__":
    messages = [
        {"role": "user", "content": "help with auth"},
        {"role": "assistant", "content": "What part of auth?"},
        {"role": "user", "content": "the login is broken after refactor"},
    ]

    # Option A: structured (recommended)
    context = PromptContext(
        conversation=[ConversationMessage(m["role"], m["content"]) for m in messages],
        code_facts=[
            CodeFact("src/auth/login.py", "login() hashes password, calls session.create()", ["login"]),
        ],
        current_file="src/auth/login.py",
        selected_code="def login(user): ...",
        project_summary="Python Flask app, auth module in src/auth/, sessions stored in Redis.",
    )
    packaged = assemble_enhancement_context("fix the login bug", context)
    print("=== Structured context (recommended) ===\n", packaged)

    # Option B: free-form (legacy fallback)
    freeform = assemble_context_freeform(
        messages,
        current_file="src/auth/login.py",
        selected_code="def login(user): ...",
    )
    print("\n=== Free-form context (fallback) ===\n", freeform)
    # Then pass either as the 'context' arg to enhance_prompt(draft, context=...)
