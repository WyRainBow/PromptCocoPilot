"""Edge / adversarial rounds for the optimizations.

Rounds 6-9 stress corner cases that break naive implementations:
- pure-ASCII long conversation (does CJK estimate mis-handle code/English?)
- empty / whitespace-only context (no crash)
- first message itself is empty (degenerate)
- observer visibleContext head+tail algorithm (string-level, no DOM)
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mcp-server"))

from context_packaging import (
    PromptContext,
    ConversationMessage,
    assemble_enhancement_context,
    _estimate_tokens,
)


def visible_context_str(raw, max_chars=6000):
    """Mirror of observer_script.js visibleContext() at string level (no DOM)."""
    import re
    text = re.sub(r"\n{3,}", "\n\n", raw).strip()
    if len(text) <= max_chars:
        return text
    head = int(max_chars * 0.6)
    tail = max_chars - head
    return text[:head].rstrip() + "\n…[truncated]…\n" + text[-tail:].lstrip()


# ---------- Round 6: pure-ASCII / code-heavy context ----------
def round6():
    print("\n=== Round 6: 纯英文/代码场景（中文估算不误伤） ===")
    # 大段英文代码, 旧的4char假设正好对ASCII合理; 新估算也应合理
    code_msgs = [ConversationMessage("assistant", "def foo():\n    return bar " * 100) for _ in range(8)]
    ctx = PromptContext(conversation=code_msgs)
    out = assemble_enhancement_context("refactor this", ctx, context_budget=2_000)
    fit = _estimate_tokens(out) <= 2_000 * 1.2
    # ASCII内容新估算(4char/token)与旧假设一致, 不应报错
    ascii_str = "hello world example test"  # 24 chars (含4空格)
    ascii_est = _estimate_tokens(ascii_str)  # 24//4 = 6
    print(f"  纯英文对话收敛后 token={_estimate_tokens(out)} (预算2000): {'在预算内' if fit else '超预算!'}")
    print(f"  ASCII估算合理性: {len(ascii_str)}字符 -> {ascii_est} token (24//4=6, ≈旧4char假设)")
    return ("PASS" if fit and ascii_est == 6 else "FAIL",
            "ASCII/code correctly estimated at 4 chars/token, no over-trim")


# ---------- Round 7: empty / degenerate inputs ----------
def round7():
    print("\n=== Round 7: 空输入 / 退化场景（不崩溃） ===")
    results = []

    # 空context
    try:
        out = assemble_enhancement_context("hello", PromptContext())
        ok_empty = "Draft prompt:\nhello" in out
        results.append(("空context", ok_empty, out))
    except Exception as e:
        results.append(("空context", False, f"CRASH: {e}"))

    # 仅空白消息
    try:
        ctx = PromptContext(conversation=[
            ConversationMessage("user", "   "),
            ConversationMessage("assistant", ""),
        ])
        out = assemble_enhancement_context("hi", ctx)
        ok_ws = "Draft prompt:\nhi" in out  # 不报错即可
        results.append(("空白消息过滤", ok_ws, out))
    except Exception as e:
        results.append(("空白消息过滤", False, f"CRASH: {e}"))

    # 首条消息内容为空(退化: 首条保留逻辑不应崩)
    try:
        ctx = PromptContext(conversation=[
            ConversationMessage("user", ""),
        ] + [ConversationMessage("assistant", f"reply {i}") for i in range(15)])
        out = assemble_enhancement_context("next", ctx, max_messages=4)
        ok_first_empty = "Draft prompt:\nnext" in out
        results.append(("首条消息为空", ok_first_empty, out))
    except Exception as e:
        results.append(("首条消息为空", False, f"CRASH: {e}"))

    all_ok = True
    for name, ok, detail in results:
        print(f"  {name}: {'PASS' if ok else 'FAIL'} -> {str(detail)[:80]!r}")
        all_ok = all_ok and ok
    return ("PASS" if all_ok else "FAIL", "no crash on empty/whitespace/degenerate-first-msg")


# ---------- Round 8: observer head+tail algorithm (string level) ----------
def round8():
    print("\n=== Round 8: observer visibleContext head+tail 算法（字符串级） ===")
    # 短内容原样
    r1 = visible_context_str("短内容")
    ok1 = r1 == "短内容"

    # 超长: 验证 60/40 比例 + 截断标记
    long_text = "A" * 10000
    r2 = visible_context_str(long_text)
    has_marker = "…[truncated]…" in r2
    head, _, tail = r2.partition("…[truncated]…")
    ok2 = has_marker and abs(len(head.strip()) - 3600) <= 5 and abs(len(tail.strip()) - 2400) <= 5

    # 任务定义在头,最近消息在尾 —— 都保留(对抗纯尾部截断会丢头的缺陷)
    composed = "TASK_GOAL_HEAD" + "X" * 8000 + "RECENT_MSG_TAIL"
    r3 = visible_context_str(composed)
    ok3 = "TASK_GOAL_HEAD" in r3 and "RECENT_MSG_TAIL" in r3

    print(f"  短内容原样返回: {'PASS' if ok1 else 'FAIL'}")
    print(f"  超长60/40比例+标记: {'PASS' if ok2 else 'FAIL'} (head={len(head.strip())}, tail={len(tail.strip())})")
    print(f"  头部目标+尾部近期都保留: {'PASS' if ok3 else 'FAIL'}")
    return ("PASS" if ok1 and ok2 and ok3 else "FAIL",
            "head(60%)+tail(40%) truncation preserves both ends")


# ---------- Round 9: CJK vs budget interaction (mixed long chat) ----------
def round9():
    print("\n=== Round 9: 中英混合长对话 + 真实预算交互 ===")
    # 模拟真实场景: 中文为主的中长对话, 验证中文不被错误地"宽松"放行导致超窗
    msgs = []
    for i in range(20):
        msgs.append(ConversationMessage("user", f"第{i}条用户消息：请帮我优化这个接口的性能瓶颈" * 3))
        msgs.append(ConversationMessage("assistant", f"第{i}条回复：我分析了代码，发现主要瓶颈在数据库查询" * 3))
    ctx = PromptContext(
        conversation=msgs,
        project_summary="这是一个 Flask + Redis 的电商后端，主要模块在 src/api/ 下。" * 5,
    )
    out = assemble_enhancement_context("那这个怎么改", ctx, context_budget=3_000)
    est = _estimate_tokens(out)
    fit = est <= 3_000 * 1.2
    # 首条中文任务定义应保留
    has_first = "第0条用户消息" in out
    print(f"  混合长对话最终 token={est} (预算3000, 容差1.2x={int(3000*1.2)}): {'在预算内' if fit else '超预算!'}")
    print(f"  首条中文任务保留: {has_first}")
    print(f"  输出长度 {len(out)} 字符")
    return ("PASS" if fit and has_first else "FAIL",
            "mixed CJK/ASCII long chat fits budget AND keeps first task goal")


def main():
    rounds = [round6, round7, round8, round9]
    results = []
    for r in rounds:
        try:
            results.append(r())
        except Exception as exc:  # noqa: BLE001
            import traceback
            traceback.print_exc()
            results.append(("ERROR", f"{type(exc).__name__}: {exc}"))

    print("\n" + "=" * 56)
    print("边界/对抗测试汇总")
    print("=" * 56)
    for i, (status, detail) in enumerate(results, 6):
        mark = "✅" if status == "PASS" else "❌"
        print(f"  轮{i} [{status}] {mark} {detail}")
    all_pass = all(s == "PASS" for s, _ in results)
    print("=" * 56)
    print(f"{'✅ 全部通过' if all_pass else '❌ 存在失败'} ({sum(1 for s,_ in results if s=='PASS')}/{len(results)})")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
