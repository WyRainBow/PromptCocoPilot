# 上下文感知回复建议功能 — Invoko 调研与实现文档

> 本文档记录 `感知上下文` 功能从调研到实现的完整过程，
> 包括 Invoko 产品调研、API 分析、技术选型、架构设计和代码说明。

---

## 1. 调研：Invoko 是如何感知上下文的？

### 1.1 信息来源

| 来源 | 地址 | 内容 |
|---|---|---|
| Invoko 官网 | https://invoko.ai | 产品定位、功能说明、隐私政策 |
| Invoko 隐私政策 | https://invoko.ai/privacy/ | 屏幕数据处理细节 |
| Invoko Product Hunt | https://www.productcool.com/product/invoko | 产品深度分析 |
| Apple ScreenCaptureKit | https://developer.apple.com/videos/play/wwdc2022/10156/ | WWDC22 截图框架 |
| 项目已有调研文档 | `docs/invoko-design-research.md` | 设计系统、notch 状态机、内部文档路径 |

### 1.2 Invoko 的上下文感知机制（官方原文）

Invoko 官网 FAQ 原文：

> **How does Invoko use screen context?**
> Invoko can use the current app, window title, page URL, selected text, focused field, and a screenshot when the task needs it.
> That context helps Invoko answer from the work already open on your Mac.

> **Is Invoko always listening or watching my screen?**
> No. Invoko starts when you invoke it with a shortcut, tap, or request.
> Voice, screen context, app control, and account connectors each need their own permission.

### 1.3 Invoko 感知层详解

Invoko 感知 **6 层内容**（按隐私敏感度从低到高）：

| 层 | 内容 | 技术手段 | 隐私级别 |
|---|---|---|---|
| 1 | **当前 App 名称 + Bundle ID** | `NSWorkspace.shared.frontmostApplication` | 低 |
| 2 | **窗口标题** | AXUIElement `kAXTitleAttribute` | 低 |
| 3 | **页面 URL**（浏览器标签页） | AXUIElement `AXURL` | 中 |
| 4 | **选中的文字** | `NSPasteboard.general`（剪贴板） | 中 |
| 5 | **聚焦输入框内容** | AXUIElement `kAXValueAttribute` | 高 |
| 6 | **截图** | ScreenCaptureKit / CGWindowListCreateImage | 高 |

**隐私三原则（Invoko 明确承诺）：**
1. **按需触发**：所有感知都在用户主动触发时才读取，从不被动监控
2. **用完即弃**：截图仅在内存中处理，不存储，不上传
3. **权限分层**：每个感知层都需要独立授权（屏幕录制、辅助功能等）

### 1.4 Invoko 的产品价值

> "Invoko starts with the app, page, selection, and field in front of you."
> — Invoko 首页标语

核心价值：**消除上下文切换**。用户不需要描述"我现在在看什么"，Invoko 直接感知屏幕内容，
给出回复建议、操作建议或内容摘要。

### 1.5 Invoko 设计语言（参考）

| 维度 | 桌面 App（Voko） | 官网 |
|---|---|---|
| 基底色 | `#F4F1EA`（暖米色） | `#0b1120`（深海军蓝） |
| Accent | `#C96C4A`（陶土红） | `#0f308a`（蓝） |
| 字体 | SF Pro（macOS 系统） | Neue Montreal + Aime serif |
| 阴影 | 短软低对比 | 品牌感深色 |
| 动效 | 180/240ms + easeOut | 呼吸漂浮 |

详见：`docs/invoko-design-research.md`

---

## 2. 技术选型

### 2.1 为什么用 ScreenCaptureKit 而不是 CGWindowListCreateImage？

`CGWindowListCreateImage` 在 **macOS 15.0 被标记为废弃**（`CGWindow.h:271`）：

```swift
// 旧 API（macOS 15 已废弃）
CGWindowListCreateImage(...) // ❌ Obsoleted in macOS 15.0
```

**解决方案：**
```swift
if #available(macOS 15.0, *) {
    screenshotBase64 = _screenshotViaScreenCaptureKit()  // ✅ 新 API
} else {
    screenshotBase64 = _screenshotViaCGWindowList()       // ✅ 旧 API 兜底
}
```

ScreenCaptureKit 是 Apple 官方推荐的 macOS 12+ 截图方案，功能更强（支持单窗口、视频流等）。

### 2.2 为什么截图是可选的（screenshotNeeded 参数）？

截图是 **最高隐私敏感度** 的感知层，且 ScreenCaptureKit 需要 Screen Recording 系统权限。
为了：
1. 减少不必要的权限请求（用户体验）
2. 加快感知速度（截图是 async 调用，比 AX API 慢）
3. 减少 API 负载和 token 消耗

**当前实现：截图暂不发送**（`screenshotNeeded=false`），未来可按需开启。

### 2.3 为什么用 HTTP API 而不是 MCP？

- HTTP API (`/generate_reply`) 延迟更低，适合实时交互场景
- MCP 适合工具调用场景，适合"增强 prompt"这类工具化需求
- 两种协议共存：`/enhance` 用 MCP，`/generate_reply` 用 HTTP

---

## 3. 架构设计

### 3.1 数据流

```
用户点击"感知上下文"
       │
       ▼
Swift: ContextAwareness.gather()
       │  同步读取 5 层（App名/标题/URL/选中/输入框）
       ▼
Swift: ReplySuggestionClient.fetchSuggestions()
       │  POST { context, draft } → http://127.0.0.1:8765/generate_reply
       ▼
Python: http_server.py → build_generate_reply_response()
       │
       ▼
Python: enhance.py → generate_reply_suggestions()
       │  调用 Dashscope API / 降级关键词匹配
       ▼
返回: { suggestions: [...], context_summary: "App: 飞书 | Window: 群聊" }
       │
       ▼
Swift: 更新 state.suggestions[] → 显示快捷回复选项
       │
       ▼
用户点击选项 → 自动填入草稿 draft
```

### 3.2 Swift 侧模块

| 文件 | 职责 |
|---|---|
| `Sources/ContextAwareness.swift` | 6 层感知逻辑，全同步（截图除外） |
| `Sources/ReplySuggestionClient.swift` | HTTP 客户端，调用 `/generate_reply` |
| `Sources/App.swift` | 新增 `suggestions[]`、`gatherSuggestions()`、`applySuggestion()` |
| `Sources/IslandView.swift` | 新增"感知上下文"按钮 + 快捷回复列表 UI |

### 3.3 Python 侧模块

| 文件 | 职责 |
|---|---|
| `mcp-server/enhance.py` | 新增 `generate_reply_suggestions()`、`_detect_app_type()`、`_fallback_suggestions()` |
| `mcp-server/http_server.py` | 新增 `POST /generate_reply` 端点 |

---

## 4. 核心代码说明

### 4.1 ContextAwareness.swift — 6 层感知

```swift
enum ContextAwareness {
    // Layer 1: 前台 App
    static func frontmostApp() -> (name: String, bundleID: String) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.localizedName ?? "", app?.bundleIdentifier ?? "")
    }

    // Layer 2+3: 窗口标题 + URL（递归遍历 AX 树）
    static func windowInfo(pid: pid_t) -> (title: String, url: String) { ... }

    // Layer 4: 剪贴板选中文字
    static func selectedText() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    // Layer 5: 聚焦输入框
    static func focusedFieldText(pid: pid_t) -> String { ... }

    // Layer 6: 截图（ScreenCaptureKit）
    static func screenshot() async -> String { ... }

    // 统一入口
    static func gather(screenshotNeeded: Bool = false) -> Context { ... }
}
```

**关键设计点：**
- AX API 递归深度限制 `depth > 8` 防止过深遍历（网页 DOM 可能很深）
- 截图输出为 base64 PNG，JSON 序列化友好
- 所有感知层都是**同步调用**（除截图外），延迟 < 50ms

### 4.2 generate_reply_suggestions — 回复生成逻辑

```python
def generate_reply_suggestions(context, existing_draft, num_suggestions):
    if _DASHSCOPE_API_KEY:
        # → 调用 Dashscope 生成 AI 回复
        app_type = _detect_app_type(bundle_id, app_name, page_url)
        context_desc = _build_context_desc(...)
        raw = _call_dashscope_reply(context_desc)
        suggestions = _parse_suggestions(raw, num)
        if suggestions:
            return suggestions
    # → 降级到关键词匹配
    return _fallback_suggestions(context, existing_draft)
```

**App 类型检测逻辑（`app bundle ID` 关键词匹配）：**

| App 类型 | Bundle ID 关键词 |
|---|---|
| 飞书 | `lark`, `feishu`, `bytedance` |
| 微信 | `wechat`, `weixin` |
| Slack | `slack` |
| 钉钉 | `dingtalk`, `dingding` |
| Gmail | `mail.google` |
| 浏览器 | `chrome`, `safari`, `firefox`, `arc` |

### 4.3 _fallback_suggestions — 关键词降级

当无 API Key 时，根据 App 类型返回预设回复：

```python
if app_type in ("飞书", "微信", "Slack", "钉钉"):
    return ["好的收到", "收到，我看看", "稍等，我看下"]

if app_type in ("Gmail", "邮件客户端"):
    return ["收到，我会处理", "好的，感谢告知", "了解，稍后回复你"]

if app_type in ("浏览器", "飞书文档", "Notion"):
    return ["帮我总结一下", "提取关键信息"]
```

---

## 5. UI 设计

### 5.1 入口位置

**"感知上下文"按钮**位于草稿输入框上方，与会话选择器、上下文折叠区同一行。

这样设计的原因：
1. 在使用流程上：先感知上下文 → 生成建议 → 用户选填 → 再增强
2. 与 Invoko 的 Action Cards 概念一致：感知 → 建议 → 采纳
3. 不额外占用垂直空间，展开收起自然

### 5.2 建议列表

每个建议显示为 pill 样式的按钮，带序号（`1` `2` `3`）和右箭头图标。

点击后直接填入草稿，用户可编辑后再点"增强"。

---

## 6. 未来扩展方向

| 方向 | 说明 |
|---|---|
| **截图发送** | `screenshotNeeded=true`，LLM 视觉理解后生成更精准的回复 |
| **飞书插件注入** | 在飞书输入框旁注入快捷回复按钮，无需打开岛卡片 |
| **记忆（Memory）** | Invoko 有"memory feature"——跨会话记住重要上下文 |
| **跨 App 操作** | Invoko 可以跨 App 执行操作（如"帮我发邮件给..."） |
| **快捷键触发** | 参考 Invoko：⌘+双击 或 自定义快捷键快速触发感知 |

---

## 7. 参考资料汇总

### 官方文档
- Invoko 官网：https://invoko.ai
- Invoko 隐私政策：https://invoko.ai/privacy/
- Apple ScreenCaptureKit：https://developer.apple.com/documentation/screencapturekit
- Apple AXUIElement：https://developer.apple.com/documentation/applicationservices/accessibility_guidelines

### 项目内已有文档
- `docs/invoko-design-research.md` — Invoko 设计系统调研（设计 token、notch 状态机、Onboarding）
- `docs/TECH_SCHEME.md` — MCP 提示词增强技术方案
- `.qoder/repowiki/zh/content/核心架构/上下文组装器.md` — 上下文组装器架构

### 第三方分析
- ProductCool Invoko 测评：https://www.productcool.com/product/invoko
- AIPure Invoko 功能汇总：https://aipure.ai/products/invoko

---

*文档生成时间：2026-07-01*
*实现分支：main (commit 8f11581)*
