"""Read the active Claude Code session and extract conversation context."""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Optional

CLAUDE_DIR = Path.home() / '.claude'
SESSIONS_DIR = CLAUDE_DIR / 'sessions'
PROJECTS_DIR = CLAUDE_DIR / 'projects'


def _cwd_to_slug(cwd: str) -> str:
    """Convert a cwd path to the slug Claude Code uses for project directories.

    Claude Code replaces every non-[a-zA-Z0-9._-] character with '-',
    which matches observed directories like '-Users-mac------PromptCocoPilot'.
    """
    return re.sub(r'[^a-zA-Z0-9._\-]', '-', cwd)


def _load_all_sessions() -> list[dict]:
    """Load all process session descriptors, sorted by most-recently-updated."""
    if not SESSIONS_DIR.exists():
        return []
    sessions = []
    for sf in SESSIONS_DIR.glob('*.json'):
        try:
            data = json.loads(sf.read_text())
            data['_mtime'] = sf.stat().st_mtime
            sessions.append(data)
        except Exception:
            pass
    # Prefer busy > idle; within same status, most recently updated first.
    def sort_key(d):
        status_rank = 0 if d.get('status') == 'busy' else 1
        return (status_rank, -(d.get('updatedAt') or d['_mtime'] * 1000))
    sessions.sort(key=sort_key)
    return sessions


def _find_jsonl(session: dict) -> Optional[Path]:
    cwd = session.get('cwd', '')
    session_id = session.get('sessionId', '')
    if not cwd or not session_id:
        return None
    slug = _cwd_to_slug(cwd)
    p = PROJECTS_DIR / slug / f'{session_id}.jsonl'
    return p if p.exists() else None


def _parse_conversation(jsonl_path: Path, max_messages: int) -> list[dict]:
    """Return the last *max_messages* user/assistant turns from the JSONL."""
    messages = []
    try:
        for line in jsonl_path.read_text(encoding='utf-8').splitlines():
            if not line.strip():
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            if obj.get('type') not in ('user', 'assistant'):
                continue
            content = obj.get('message', {}).get('content', '')
            if isinstance(content, list):
                text = '\n'.join(
                    c.get('text', '') for c in content if c.get('type') == 'text'
                )
            elif isinstance(content, str):
                text = content
            else:
                continue
            text = text.strip()
            if text:
                messages.append({
                    'role': obj['type'],
                    'content': text,
                    'ts': obj.get('timestamp', ''),
                })
    except Exception:
        pass
    return messages[-max_messages:]


def get_current_context(max_messages: int = 20) -> tuple:
    """Return (conversation, cwd) for the most active Claude Code session.

    Tries sessions in order: busy first, then most-recently-updated.
    Returns the first session that has a readable JSONL with at least one message.
    Falls back to ([], '') if nothing is found.
    """
    for session in _load_all_sessions():
        jsonl = _find_jsonl(session)
        if not jsonl:
            continue
        conv = _parse_conversation(jsonl, max_messages)
        if conv:
            return conv, session.get('cwd', '')
    return [], ''


def get_session_summary() -> str:
    """Return a one-line human-readable summary of the active session."""
    sessions = _load_all_sessions()
    for session in sessions:
        jsonl = _find_jsonl(session)
        if not jsonl:
            continue
        conv = _parse_conversation(jsonl, 1)
        if conv:
            cwd = session.get('cwd', '')
            name = cwd.split('/')[-1] if cwd else '未知项目'
            status = session.get('status', '')
            count_lines = sum(
                1 for l in jsonl.read_text().splitlines()
                if '"type": "user"' in l or '"type": "assistant"' in l
            )
            return f'📍 {name}  ·  ~{count_lines // 2} 轮对话  [{status}]'
    return '未检测到活跃会话'
