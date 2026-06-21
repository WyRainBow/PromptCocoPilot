#!/usr/bin/env python3
"""
全自动真实模型测试脚本 - 测试 Prompt Enhancer 的使用效果

使用 Resume-Agent 项目中的 DASHSCOPE_API_KEY (Dashscope 兼容 OpenAI endpoint)
模型: deepseek-v4-flash 等

测试目标:
1. 验证 enhance_prompt 是否正确使用上下文 (对话历史)
2. 检查增强后的 prompt 是否更清晰、具体
3. 验证是否遵守 "只改写、不执行" 原则
4. 评估整体使用效果，如果不好则自动建议或修改

运行方式:
cd /Users/wy770/Desktop/PromptCocoPilot
python3 tests/test_real_usage.py
"""

import os
import sys
import json
import requests
from pathlib import Path

# 添加项目路径
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "mcp-server"))

from enhance import enhance_prompt, INSTRUCTION, clean

# ==================== 配置 ====================
RESUME_AGENT_ENV = Path("/Users/wy770/Resume-Agent/.env")
DASHSCOPE_BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
MODEL = "deepseek-v4-flash"   # 快速模型，适合测试增强器；如需更好质量可换 qwen-max 或 deepseek-reasoner

def load_dashscope_key():
    """从 Resume-Agent 的 .env 加载 DASHSCOPE_API_KEY"""
    key = os.getenv("DASHSCOPE_API_KEY")
    if key:
        return key

    if RESUME_AGENT_ENV.exists():
        with open(RESUME_AGENT_ENV) as f:
            for line in f:
                line = line.strip()
                if line.startswith("DASHSCOPE_API_KEY="):
                    return line.split("=", 1)[1].strip()
    raise RuntimeError("无法找到 DASHSCOPE_API_KEY。请确保 /Users/wy770/Resume-Agent/.env 存在且包含该 key。")

API_KEY = load_dashscope_key()

def call_dashscope_for_enhance(user_content: str, system_instruction: str) -> str:
    """
    使用 Dashscope OpenAI 兼容端点调用模型进行 prompt 增强。
    第一个参数是组装好的 user message (包含 draft + context)
    第二个参数是 system_instruction (INSTRUCTION)
    """
    url = f"{DASHSCOPE_BASE_URL}/chat/completions"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": user_content},
        ],
        "temperature": 0.3,
        "max_tokens": 2048,
        "top_p": 0.95,
    }

    resp = requests.post(url, headers=headers, json=payload, timeout=60)
    if resp.status_code != 200:
        raise RuntimeError(f"Dashscope API 错误 {resp.status_code}: {resp.text[:500]}")

    data = resp.json()
    content = data["choices"][0]["message"]["content"]
    return clean(content)

# ==================== 测试用例 ====================

TEST_CASES = [
    {
        "name": "测试1: 简单模糊任务 + 代码上下文",
        "draft": "fix the bug",
        "context": """Recent conversation:
User: The login is broken after the recent refactor in auth module.
Assistant: Can you show the error?
User: 401 unauthorized for valid users.

Current file: src/auth/login.py
Selected code:
def login(username, password):
    if check_password(username, password):
        return create_session()
""",
    },
    {
        "name": "测试2: 产品需求 + 历史对话",
        "draft": "add a dashboard",
        "context": """Previous messages:
User: We are building a resume generator app.
User: The backend is FastAPI + PostgreSQL.
User: Users complain that after uploading PDF, they cannot see progress.

Current task: Add a dashboard page that shows upload history and generation status.
""",
    },
    {
        "name": "测试3: 纯模糊指令（无上下文）",
        "draft": "make it better",
        "context": None,
    },
    {
        "name": "测试4: 带多轮历史的复杂任务",
        "draft": "implement the feature",
        "context": """Conversation history (last 6 turns):
1. User: I want to support exporting resume to PDF.
2. Assistant: Which library do you prefer?
3. User: Use reportlab or weasyprint, but keep it simple.
4. User: Also need to handle Chinese fonts properly.
5. Assistant: Do you have font files?
6. User: Yes, in assets/fonts.

The user just said: implement the feature
""",
    },
]

def run_single_test(case: dict):
    print(f"\n{'='*70}")
    print(f"【{case['name']}】")
    print(f"{'='*70}")
    print(f"原始 Draft: {case['draft']!r}")
    if case.get("context"):
        print(f"\n提供的 Context (部分): {case['context'][:300]}...")
    else:
        print("\n无 Context")

    # 构造传递给 enhance 的输入
    # 注意：我们的 enhance_prompt 会把 context 拼进 user content
    enhanced = enhance_prompt(
        text=case["draft"],
        context=case.get("context"),
        generate_fn=call_dashscope_for_enhance,   # 关键：传入真实模型调用
    )

    print(f"\n增强后 Prompt:\n{enhanced}")
    print(f"\n长度变化: {len(case['draft'])} -> {len(enhanced)} chars")

    # 简单自动评估
    score_notes = []
    if len(enhanced) > len(case["draft"]) * 1.5:
        score_notes.append("✅ 明显更详细")
    if case.get("context") and any(kw in enhanced for kw in ["login", "auth", "PDF", "dashboard", "Chinese", "font"]):
        score_notes.append("✅ 正确吸收了上下文中的关键词")
    if "please" in enhanced.lower() or "step" in enhanced.lower() or "provide" in enhanced.lower():
        score_notes.append("✅ 增加了结构化指令")
    if "fix the bug" in enhanced or case["draft"] in enhanced and len(enhanced) < len(case["draft"]) * 1.2:
        score_notes.append("⚠️  可能改写不够充分")

    print("自动观察:", " | ".join(score_notes) if score_notes else "需要人工判断")

    return {
        "name": case["name"],
        "original": case["draft"],
        "enhanced": enhanced,
        "context_used": bool(case.get("context")),
    }

def main():
    print("开始全自动真实模型测试 (使用 Dashscope / DeepSeek via compatible mode)")
    print(f"模型: {MODEL}")
    print(f"Key 来源: Resume-Agent/.env")

    results = []
    for case in TEST_CASES:
        try:
            res = run_single_test(case)
            results.append(res)
        except Exception as e:
            print(f"测试失败: {e}")
            results.append({"name": case["name"], "error": str(e)})

    print("\n\n" + "="*70)
    print("测试总结")
    print("="*70)
    for r in results:
        if "error" in r:
            print(f"❌ {r['name']}: {r['error']}")
        else:
            print(f"✅ {r['name']}: 增强长度 {len(r['original'])} → {len(r['enhanced'])}")

    # 简单总体评价
    good_count = sum(1 for r in results if "error" not in r and len(r.get("enhanced", "")) > len(r.get("original", "")) * 1.3)
    print(f"\n总体: {good_count}/{len(results)} 个 case 改写明显更详细。")

    if good_count < len(results) * 0.7:
        print("\n⚠️  使用效果一般，建议检查 INSTRUCTION 或 context 拼接逻辑。")
    else:
        print("\n✅ 使用效果良好。")

if __name__ == "__main__":
    main()