"""
Example of how a caller (VS Code extension, wrapper, or skill host) can assemble context
before calling the enhance_prompt tool.

This mirrors Kilo Code's approach of providing task history + editor context.
"""

from typing import List, Dict, Any

def assemble_context(
    recent_messages: List[Dict[str, str]],
    current_file: str = "",
    selected_code: str = "",
    max_history: int = 10,
) -> str:
    """
    Build a compact context string for the enhancer.
    """
    parts = []
    if recent_messages:
        history = "\n".join(
            f"{m['role']}: {m['content'][:300]}" for m in recent_messages[-max_history:]
        )
        parts.append(f"Recent conversation history:\n{history}")

    if current_file:
        parts.append(f"Current file: {current_file}")

    if selected_code:
        parts.append(f"Selected code:\n{selected_code[:500]}")

    return "\n\n".join(parts)

# Example usage
if __name__ == "__main__":
    messages = [
        {"role": "user", "content": "help with auth"},
        {"role": "assistant", "content": "What part of auth?"},
        {"role": "user", "content": "the login is broken after refactor"},
    ]
    ctx = assemble_context(
        messages,
        current_file="src/auth/login.py",
        selected_code="def login(user): ...",
    )
    print("Assembled context for enhancer:\n", ctx)
    # Then pass ctx as the 'context' arg to enhance_prompt(draft, context=ctx)