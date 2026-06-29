# PromptCocoIsland — 刘海屏原生增强卡片

参考 [ericjypark/codex-island](https://github.com/ericjypark/codex-island) 实现的 macOS 原生
Dynamic Island 风格悬浮卡片，停靠在 MacBook 刘海（notch）正下方。取代之前的
pywebview 方案（`claude-ui/bin/claude-card.py`），不再有停靠时的 trace-trap 崩溃。

## 功能

- **刘海停靠**：自动检测带刘海的屏幕（`safeAreaInsets.top > 0`），把胶囊条贴在顶部正中；
  无刘海机型回退到菜单栏位置。
- **点击展开**：胶囊条 → 展开卡片（会话上下文 / 草稿 / 增强 / 结果）。
- **全局快捷键 ⌃⌥⌘P**：在任意 App 中召出卡片并聚焦输入。
- **会话感知**：原生读取 `~/.claude/sessions` + `projects/*.jsonl`，取最近 20 轮对话作为
  增强上下文（`SessionReader.swift`，等价于 `src/session_reader.py`）。
- **增强**：POST `http://127.0.0.1:8765/enhance`（`mcp-server/http_server.py`），
  payload 为 `{draft, conversation}`，与原 Python 卡片一致。
- **应用并关闭**：把结果写入剪贴板并向前台 App 模拟 ⌘V 粘贴。

## 构建 & 运行

```bash
npm run claude:island:build   # 或 bash claude-ui/swift/build.sh
npm run claude:island         # 运行（无 Dock 图标，accessory app）
pkill -f PromptCocoIsland     # 退出
```

## 权限

- **辅助功能（Accessibility）**：「应用并关闭」的 ⌘V 模拟需要在
  *系统设置 → 隐私与安全性 → 辅助功能* 中授权运行该二进制的终端 / App。
- 全局快捷键基于 Carbon `RegisterEventHotKey`，不需要辅助功能权限。
- 增强服务未启动时会提示「增强服务未运行」，先跑 `mcp-server/http_server.py`。

## 文件

| 文件 | 职责 |
| --- | --- |
| `Sources/App.swift` | 入口、停靠窗口控制、全局快捷键、AppState |
| `Sources/IslandView.swift` | SwiftUI 胶囊条 + 展开卡片 UI |
| `Sources/SessionReader.swift` | 原生读取 Claude Code 会话上下文 |
| `Sources/EnhanceClient.swift` | 调用增强 HTTP 接口 |
| `Sources/Selection.swift` | 剪贴板读取 + 模拟粘贴 |
