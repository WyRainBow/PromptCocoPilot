"""Context assembly helpers for next-turn prompt enhancement."""

from dataclasses import dataclass, field
from typing import Iterable, Sequence


@dataclass(frozen=True)
class ConversationMessage:
    role: str
    content: str


@dataclass(frozen=True)
class CodeFact:
    path: str
    summary: str
    symbols: Sequence[str] = field(default_factory=tuple)


@dataclass(frozen=True)
class PromptContext:
    conversation: Sequence[ConversationMessage] = field(default_factory=tuple)
    code_facts: Sequence[CodeFact] = field(default_factory=tuple)
    task_state: str = ""
    current_file: str = ""
    selected_code: str = ""
    user_preferences: Sequence[str] = field(default_factory=tuple)


def _truncate(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rstrip() + "..."


def _format_lines(title: str, lines: Iterable[str]) -> str:
    content = "\n".join(line for line in lines if line)
    return f"{title}:\n{content}" if content else ""


def assemble_enhancement_context(
    draft: str,
    context: PromptContext,
    *,
    max_messages: int = 12,
    max_chars_per_message: int = 600,
    max_selected_code_chars: int = 1200,
) -> str:
    """Build the context payload sent to the prompt enhancer.

    The package intentionally records what the agent has already learned, so a
    vague next prompt like "那这个怎么改" can be rewritten with continuity.
    """
    parts: list[str] = [f"Draft prompt:\n{draft.strip()}"]

    if context.conversation:
        recent = context.conversation[-max_messages:]
        parts.append(
            _format_lines(
                "Recent conversation",
                (
                    f"{message.role}: "
                    f"{_truncate(message.content.strip(), max_chars_per_message)}"
                    for message in recent
                    if message.content.strip()
                ),
            )
        )

    if context.code_facts:
        parts.append(
            _format_lines(
                "Code facts already gathered",
                (
                    f"- {fact.path}: {fact.summary}"
                    + (f" (symbols: {', '.join(fact.symbols)})" if fact.symbols else "")
                    for fact in context.code_facts
                    if fact.path or fact.summary
                )
            )
        )

    if context.task_state.strip():
        parts.append(f"Current task state:\n{context.task_state.strip()}")

    editor_lines = []
    if context.current_file.strip():
        editor_lines.append(f"Current file: {context.current_file.strip()}")
    if context.selected_code.strip():
        editor_lines.append(
            "Selected code:\n"
            + _truncate(context.selected_code.strip(), max_selected_code_chars)
        )
    if editor_lines:
        parts.append(_format_lines("Editor context", editor_lines))

    if context.user_preferences:
        parts.append(
            _format_lines(
                "User preferences",
                (
                    f"- {preference.strip()}"
                    for preference in context.user_preferences
                    if preference.strip()
                ),
            )
        )

    return "\n\n".join(part for part in parts if part)


def prompt_context_from_dict(raw: dict) -> PromptContext:
    """Convert MCP JSON arguments into a PromptContext."""
    conversation = [
        ConversationMessage(
            role=str(item.get("role", "unknown")),
            content=str(item.get("content", "")),
        )
        for item in raw.get("conversation", []) or []
        if isinstance(item, dict)
    ]
    code_facts = [
        CodeFact(
            path=str(item.get("path", "")),
            summary=str(item.get("summary", "")),
            symbols=tuple(str(symbol) for symbol in item.get("symbols", []) or []),
        )
        for item in raw.get("code_facts", []) or []
        if isinstance(item, dict)
    ]

    return PromptContext(
        conversation=conversation,
        code_facts=code_facts,
        task_state=str(raw.get("task_state", "") or ""),
        current_file=str(raw.get("current_file", "") or ""),
        selected_code=str(raw.get("selected_code", "") or ""),
        user_preferences=tuple(
            str(item) for item in raw.get("user_preferences", []) or []
        ),
    )
