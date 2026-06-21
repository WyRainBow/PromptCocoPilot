"""Tests for the local HTTP API intended for an Optimize Input button."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mcp-server"))

import http_server


def test_build_enhance_response_returns_enhanced_prompt_for_button_payload():
    captured = {}

    def fake_handle_tool(arguments):
        captured["arguments"] = arguments
        return "请基于已读取的 session.py，修复登录后 401，并补充测试。"

    response = http_server.build_enhance_response(
        {
            "draft": "那这个怎么改",
            "conversation": [
                {"role": "assistant", "content": "已读取 src/session.py。"}
            ],
            "code_facts": [
                {
                    "path": "src/session.py",
                    "summary": "validate_session may return 401 for valid users",
                    "symbols": ["validate_session"],
                }
            ],
        },
        enhance_handler=fake_handle_tool,
    )

    assert response["enhanced"] == "请基于已读取的 session.py，修复登录后 401，并补充测试。"
    assert response["draft"] == "那这个怎么改"
    assert captured["arguments"]["code_facts"][0]["path"] == "src/session.py"


def test_build_enhance_response_rejects_missing_draft():
    try:
        http_server.build_enhance_response({})
    except ValueError as exc:
        assert "draft" in str(exc)
    else:
        raise AssertionError("missing draft should raise ValueError")


if __name__ == "__main__":
    test_build_enhance_response_returns_enhanced_prompt_for_button_payload()
    test_build_enhance_response_rejects_missing_draft()
    print("All HTTP button server tests passed.")
