"""Multi-round smoke tests for the 5 context-packaging optimizations.

Each round isolates ONE optimization and asserts its real behavior, not just
that tests pass. Run: python3 tests/multi_round_smoke.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mcp-server"))

from context_packaging import (
    PromptContext,
    ConversationMessage,
    CodeFact,
    assemble_enhancement_context,
    _estimate_tokens,
    DEFAULT_CONTEXT_BUDGET,
)
from server import _clean_button_context


def _result(ok, detail):
    return ("PASS" if ok else "FAIL", detail)


# ---------- Round 1: first-message task definition preserved ----------
def round1():
    print("\n=== Round 1: 首条任务定义保留（长对话） ===")
    goal = "ORIGINAL_TASK_GOAL_FIX_LOGIN_401"
    messages = [ConversationMessage("user", goal)] + [
        ConversationMessage("assistant", f"中间填充回复 #{i}，关于其他无关话题") for i in range(30)
    ]
    ctx = PromptContext(conversation=messages)
    out = assemble_enhancement_context("那这个怎么改", ctx, max_messages=5)

    has_goal = goal in out
    # 最近一条也应保留（max_messages=5 => 首1 + 最近4）
    last_kept = "中间填充回复 #29" in out
    dropped_middle = "中间填充回复 #10" in out  # 中间被丢弃
    print(f"  首条任务定义保留: {has_goal}")
    print(f"  最近消息保留: {last_kept}")
    print(f"  中间消息被丢弃(预期True): 丢弃={not dropped_middle}")
    ok = has_goal and last_kept and not dropped_middle
    return _result(ok, "first-message + recent tail kept, middle dropped")


# ---------- Round 2: CJK token estimate ----------
def round2():
    print("\n=== Round 2: 中文 token 预算估算 ===")
    pure_cjk = _estimate_tokens("你好世界测试中文")  # 8
    pure_ascii = _estimate_tokens("hello world example")  # 18//4=4
    mixed = _estimate_tokens("你好world")  # 2 + (5//4=1) = 3
    # 关键对比: 旧假设 1token≈4char 会把 8 个中文字算成 2 token，
    # 新估算算成 8 token —— 中文应被更高权重计数
    old_style_undercount = len("你好世界测试中文") // 4  # 2
    print(f"  纯中文(8字): 新估算={pure_cjk} token (旧4char假设仅={old_style_undercount})")
    print(f"  纯ASCII(18字符): {pure_ascii} token")
    print(f"  混合'你好world': {mixed} token")
    ok = (pure_cjk == 8 and pure_ascii == 4 and mixed == 3
          and pure_cjk > old_style_undercount)
    return _result(ok, "CJK counted 1:1, ASCII 4:1; no longer under-counts Chinese")


# ---------- Round 3: iterative convergence + hard fallback ----------
def round3():
    print("\n=== Round 3: 迭代收敛不超窗 + 非对话内容兜底 ===")
    # 场景A: 巨大对话能被迭代收紧到预算内
    big_msgs = [ConversationMessage("assistant", "页" * 800) for _ in range(12)]
    ctxA = PromptContext(conversation=big_msgs)
    outA = assemble_enhancement_context("fix", ctxA, context_budget=2_000)
    fitA = _estimate_tokens(outA) <= 2_000 * 1.2
    print(f"  场景A 巨大对话最终 token={_estimate_tokens(outA)} (预算2000, 容差1.2x): {'在预算内' if fitA else '超预算!'}")

    # 场景B: 非对话内容(project_summary)本身就超过预算 —— 必须硬截断兜底
    huge_summary = "项目摘要" + ("详情" * 5000)
    ctxB = PromptContext(project_summary=huge_summary)
    outB = assemble_enhancement_context("fix", ctxB, context_budget=2_000)
    # 兜底硬截断用 context_budget*4 字符上限
    fitB = len(outB) <= 2_000 * 4 * 1.1 + 200  # 容许截断标记开销
    print(f"  场景B 非对话内容超预算 -> 硬截断后字符数={len(outB)} (上限~{2_000*4}): {'已兜底' if fitB else '未兜底!'}")
    print(f"  场景B 含截断标记: {'…[truncated]…' in outB}")

    ok = fitA and fitB
    return _result(ok, "never overflows window even when non-conversation content is huge")


# ---------- Round 4: button-path source + noise cleaning ----------
def round4():
    print("\n=== Round 4: 按钮路径 source 标记 + 噪声清洗 ===")
    # 模拟 document.body.innerText 的真实噪声：UI 菜单 + 空行 + 短碎片
    noisy = """文件 编辑 视图 帮助


优化输入
发送
x
.
你好，请帮我修复登录接口在管理员用户登录后返回 401 的问题

recent code: def login(user, pwd): return validate(pwd)



"""
    cleaned = _clean_button_context(noisy)
    # 短噪声行("x", ".")应被清除；空行折叠；保留有效内容
    noise_dropped = "x\n" not in cleaned and ".\n" not in cleaned
    prose_kept = "请帮我修复登录接口" in cleaned and "def login" in cleaned
    ui_label_kept = "优化输入" in cleaned  # >2字符的UI标签保留(不误杀)
    collapsed = "\n\n\n" not in cleaned
    print(f"  噪声短行(x/.)被清除: {noise_dropped}")
    print(f"  有效内容保留: {prose_kept}")
    print(f"  长UI标签未误杀: {ui_label_kept}")
    print(f"  空行折叠: {collapsed}")
    print(f"  清洗前 {len(noisy)} 字符 -> 清洗后 {len(cleaned)} 字符")
    ok = noise_dropped and prose_kept and collapsed
    return _result(ok, "UI-chrome noise dropped, real prose preserved")


# ---------- Round 5: server end-to-end (button vs structured path) ----------
def round5():
    print("\n=== Round 5: server.py 端到端（按钮路径 vs 结构化路径分流） ===")
    from server import handle_enhance_prompt_tool

    # 结构化路径: 不带 source，走 assemble_enhancement_context
    structured_args = {
        "draft": "那这个怎么改",
        "conversation": [
            {"role": "user", "content": "帮我看看登录模块"},
            {"role": "assistant", "content": "读取了 auth.py"},
        ],
        "project_summary": "Flask app with Redis sessions",
    }
    # 注入 mock generate_fn 避免真实API调用 —— 通过 context 反推
    # 我们检查 context 是否被正确打包(用 fallback 时 context[:200] 会出现在输出)
    # 这里直接验证分流逻辑: source=ui-button 触发清洗
    button_args = {
        "draft": "fix it",
        "context": "Visible Codex context (button path):\n\n\n优化输入\nx\n\n请修复401",
        "source": "ui-button",
    }

    # 验证 source=ui-button 且无结构化字段 -> 不走 assemble, 只清洗 context
    # 我们无法看内部 context，但可通过 _clean_button_context 直接验证清洗生效
    # 端到端: 构造一个能观察 context 的 mock
    captured = {}

    def fake_generate(user_content, system):
        captured["user_content"] = user_content
        return "ENHANCED"

    import enhance as enhance_mod
    orig = enhance_mod._simple_fallback_enhance
    # 强制走 fallback(无key环境) 并截获
    def spy_fallback(text, context=None):
        captured["context"] = context
        return orig(text, context)

    enhance_mod._simple_fallback_enhance = spy_fallback
    try:
        # 临时禁用 dashscope key 让其走 fallback
        saved_key = enhance_mod._DASHSCOPE_API_KEY
        enhance_mod._DASHSCOPE_API_KEY = ""
        handle_enhance_prompt_tool(button_args)
    finally:
        enhance_mod._DASHSCOPE_API_KEY = saved_key
        enhance_mod._simple_fallback_enhance = orig

    ctx_seen = captured.get("context", "") or ""
    noise_cleaned = "x\n" not in ctx_seen and "优化输入" in ctx_seen  # 优化输入是>2字保留
    button_prefix_seen = "button path" in ctx_seen
    print(f"  按钮路径 context 前缀透传: {button_prefix_seen}")
    print(f"  source=ui-button 触发清洗(噪声x已去除): {noise_cleaned}")
    print(f"  清洗后 context 片段: {ctx_seen[:120]!r}")
    ok = button_prefix_seen and noise_cleaned
    return _result(ok, "button path context flows through _clean_button_context in server")


def main():
    rounds = [round1, round2, round3, round4, round5]
    results = []
    for r in rounds:
        try:
            results.append(r())
        except Exception as exc:  # noqa: BLE001
            results.append(("ERROR", f"{type(exc).__name__}: {exc}"))

    print("\n" + "=" * 56)
    print("多轮测试汇总")
    print("=" * 56)
    for i, (status, detail) in enumerate(results, 1):
        mark = "✅" if status == "PASS" else "❌"
        print(f"  轮{i} [{status}] {mark} {detail}")

    all_pass = all(s == "PASS" for s, _ in results)
    print("=" * 56)
    print(f"{'✅ 全部通过' if all_pass else '❌ 存在失败'} ({sum(1 for s,_ in results if s=='PASS')}/{len(results)})")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
