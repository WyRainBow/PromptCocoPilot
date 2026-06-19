"""Basic tests for the enhance_prompt core logic."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'mcp-server'))

from enhance import enhance_prompt, clean, INSTRUCTION

def test_clean_strips_fences():
    assert clean("```python\nfoo\n```") == "foo"
    assert clean('"bar"') == "bar"
    assert clean("baz") == "baz"

def test_enhance_returns_something():
    result = enhance_prompt("fix auth")
    assert isinstance(result, str)
    assert len(result) > 0
    # In fallback it contains "Task:" or similar
    assert "fix auth" in result or "Task" in result.lower()

def test_enhance_with_context():
    result = enhance_prompt("add test", "Current file: auth.py, selected: the login function")
    assert "add test" in result or "auth.py" in result or "context" in result.lower()

def test_instruction_is_strict():
    assert "rewrite" in INSTRUCTION.lower()
    assert "never as a request to answer" in INSTRUCTION.lower()

if __name__ == "__main__":
    test_clean_strips_fences()
    test_enhance_returns_something()
    test_enhance_with_context()
    test_instruction_is_strict()
    print("All basic tests passed.")