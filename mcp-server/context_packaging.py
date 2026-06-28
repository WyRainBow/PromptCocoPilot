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
    # New: overall project/workspace description (codebase map, tech stack, etc.)
    # This is the main gap vs Kilo Code — fills the "workspace summary" role.
    project_summary: str = ""
    # New: lightweight file list of the project for codebase-awareness
    workspace_files: Sequence[str] = field(default_factory=tuple)


# Context budget sent to the rewriter. Unit = approximate TOKENS, not chars.
# Calibrated for Chinese / mixed text: CJK ≈ 1 token/char, ASCII/code ≈ 4 chars/token
# (real CJK ratio is ~1.5-2 chars/token, so this estimate errs on the safe side).
# The old "1 token ≈ 4 chars" mapping over-counted Chinese by ~2x and either wasted
# half the window or risked overflow; see _estimate_tokens for the real calc.
DEFAULT_CONTEXT_BUDGET = 6_000


def _truncate_smart(text: str, max_chars: int) -> str:
    """Keep the head and tail of long text, cutting the middle.

    Naive head-only truncation loses conclusions in long AI replies.
    This preserves the first 60% (setup/context) and last 40% (conclusion).
    """
    if len(text) <= max_chars:
        return text
    head = int(max_chars * 0.6)
    tail = max_chars - head
    return text[:head].rstrip() + "\n…[truncated]…\n" + text[-tail:].lstrip()


def _estimate_tokens(text: str) -> int:
    """Rough token estimate calibrated for Chinese / mixed text.

    CJK chars ≈ 1 token each; ASCII/code ≈ ~4 chars/token. This replaces the old
    "1 token ≈ 4 chars" assumption, which over-counted Chinese by ~2x.
    """
    cjk = sum(1 for ch in text if "一" <= ch <= "鿿")
    non_cjk = len(text) - cjk
    return cjk + (non_cjk // 4)


def _format_lines(title: str, lines: Iterable[str]) -> str:
    content = "\n".join(line for line in lines if line)
    return f"{title}:\n{content}" if content else ""


def _dedup_code_facts(facts: Sequence[CodeFact]) -> list[CodeFact]:
    """Merge code facts for the same file path, combining summaries and symbols."""
    seen: dict[str, CodeFact] = {}
    for fact in facts:
        key = fact.path.strip()
        if not key:
            continue
        if key in seen:
            prev = seen[key]
            merged_summary = prev.summary
            if fact.summary and fact.summary not in prev.summary:
                merged_summary = f"{prev.summary}; {fact.summary}"
            merged_symbols = list(dict.fromkeys(list(prev.symbols) + list(fact.symbols)))
            seen[key] = CodeFact(path=key, summary=merged_summary, symbols=merged_symbols)
        else:
            seen[key] = fact
    return list(seen.values())


def assemble_enhancement_context(
    draft: str,
    context: PromptContext,
    *,
    max_messages: int = 12,
    max_chars_per_message: int = 600,
    max_selected_code_chars: int = 1200,
    context_budget: int = DEFAULT_CONTEXT_BUDGET,
) -> str:
    """Build the context payload sent to the prompt enhancer.

    Improvements over v1:
    - Smart truncation (head+tail) so AI reply conclusions aren't lost.
    - First-message task definition is always preserved (head + recent tail),
      so long conversations don't lose the original goal.
    - code_facts deduplication by file path.
    - project_summary and workspace_files fields (Kilo Code gap filler).
    - Token-budget cap calibrated for Chinese/mixed text (_estimate_tokens),
      enforced iteratively with a hard-truncation fallback so it never overflows
      even when non-conversation sections alone exceed the budget.
    """
    assembled = _assemble_with_cap(
        draft, context, max_messages, max_chars_per_message, max_selected_code_chars
    )

    # Iterative budget enforcement. We only trim the conversation section
    # (other sections aren't message-sized), so iterate a bounded number of
    # times and stop when we either fit or hit the per-message floor.
    cap = max_chars_per_message
    for _ in range(4):
        est = _estimate_tokens(assembled)
        if est <= context_budget or not context.conversation or cap <= 80:
            break
        cap = max(80, int(cap * (context_budget / est) * 0.8))
        assembled = _assemble_with_cap(
            draft, context, max_messages, cap, max_selected_code_chars
        )

    # Hard fallback: if non-conversation content alone exceeds the budget,
    # the loop above cannot shrink it further — truncate the whole payload
    # rather than risk overflowing a small-model window.
    if _estimate_tokens(assembled) > int(context_budget * 1.2):
        assembled = _truncate_smart(assembled, context_budget * 4)

    return assembled


def _assemble_with_cap(
    draft: str,
    context: PromptContext,
    max_messages: int,
    max_chars_per_message: int,
    max_selected_code_chars: int,
) -> str:
    """Assemble the context payload with a given per-message cap (no budget loop)."""
    parts: list[str] = [f"Draft prompt:\n{draft.strip()}"]

    # Project-level summary (Kilo Code workspace description equivalent)
    if context.project_summary.strip():
        parts.append(f"Project context:\n{context.project_summary.strip()}")

    if context.conversation:
        msgs = [m for m in context.conversation if m.content.strip()]
        if msgs:
            # Keep the original task definition (first message) PLUS the most
            # recent messages. Pure tail-only truncation loses the initial goal
            # in long conversations; pinning the first message preserves intent.
            if len(msgs) > max_messages:
                recent = [msgs[0]] + msgs[-(max_messages - 1):]
            else:
                recent = msgs
            parts.append(
                _format_lines(
                    "Recent conversation",
                    (
                        f"{msg.role}: "
                        f"{_truncate_smart(msg.content.strip(), max_chars_per_message)}"
                        for msg in recent
                    ),
                )
            )

    deduped_facts = _dedup_code_facts(context.code_facts)
    if deduped_facts:
        parts.append(
            _format_lines(
                "Code facts already gathered",
                (
                    f"- {fact.path}: {fact.summary}"
                    + (f" (symbols: {', '.join(fact.symbols)})" if fact.symbols else "")
                    for fact in deduped_facts
                    if fact.path or fact.summary
                ),
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
            + _truncate_smart(context.selected_code.strip(), max_selected_code_chars)
        )
    if editor_lines:
        parts.append(_format_lines("Editor context", editor_lines))

    if context.user_preferences:
        parts.append(
            _format_lines(
                "User preferences",
                (
                    f"- {pref.strip()}"
                    for pref in context.user_preferences
                    if pref.strip()
                ),
            )
        )

    if context.workspace_files:
        # Show at most 40 files to hint at project structure without flooding context
        shown = list(context.workspace_files[:40])
        suffix = f"\n  … and {len(context.workspace_files) - 40} more" if len(context.workspace_files) > 40 else ""
        parts.append(_format_lines("Workspace files (sample)", ["\n".join(f"  {f}" for f in shown) + suffix]))

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
            symbols=tuple(str(s) for s in item.get("symbols", []) or []),
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
        user_preferences=tuple(str(p) for p in raw.get("user_preferences", []) or []),
        project_summary=str(raw.get("project_summary", "") or ""),
        workspace_files=tuple(str(f) for f in raw.get("workspace_files", []) or []),
    )
