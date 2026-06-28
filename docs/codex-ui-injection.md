# Codex UI “优化输入” 注入

通过 Chrome DevTools Protocol (CDP) 把一个「优化输入」按钮注入 Codex 桌面应用的输入框旁边。
架构与 `qoder-ui/` 同构，针对 Codex 做了适配，并已在真实 Codex 上验证通过（2026-06-28）。

> 与 `docs/codex-button-integration.md` 的区别：那篇只描述“如果 Codex 自己愿意暴露按钮，应调用哪个本地 API”；
> 本文是**真正主动注入**按钮到 Codex UI 的实现。

## 原理

Codex 是 Electron 应用（bundle id `com.openai.codex`，内部代号 owl）。
`codex-ui` 的 daemon 通过 Codex 暴露的 DevTools 端口：

1. 连接 Codex 主窗口 renderer（`/json/list` → 选 page target）。
2. 注入一段 observer 脚本（每 1s 检查），在输入框父容器上挂一个「优化输入」按钮。
3. 点击按钮：读取输入框草稿 + 可见上下文 → 经 CDP binding 推给 daemon → daemon
   `POST http://127.0.0.1:8765/enhance` → 把 `enhanced` 文本写回输入框（供审阅，**不会自动发送**）。

## 实测发现（2026-06-28）

在真实 Codex 上验证得到的关键事实（已固化进代码/文档，省去你二次踩坑）：

- **Codex 默认不开 remote debugging**（与 Qoder 不同，Qoder 会自行写 `DevToolsActivePort`）。
  必须用 `--remote-debugging-port=<port>` 启动。
- **Codex 输入框是 `.ProseMirror`**（contenteditable DIV，外层是 Tailwind `text-size-chat ... overflow-y-auto` div）。
  observer 多候选选择器的第一项直接命中，无需调整。
- **Codex 没有 “Prompt Enhance” 按钮，也没有独立 send button**（回车提交）。因此按钮用
  `position:absolute` 挂在 `.ProseMirror` 的父容器右下角（`bottom:8px; right:10px`）。
- **9222 端口常被占用**：本机常驻的 `chrome-devtools-mcp` 的 Chrome 占了 IPv4 `127.0.0.1:9222`，
  Codex 即便带 flag 也只能绑到 IPv6 `[::1]:9222`，而 `curl 127.0.0.1:9222` 会打到错误的进程。
  **改用 9333 规避**。
- **直接执行可执行文件**（`/Applications/Codex.app/Contents/MacOS/Codex --remote-debugging-port=9333`）
  比 `open -a Codex --args ...` 更可靠地把 flag 传到 Chromium；但这种方式**不会生成 `DevToolsActivePort` 文件**，
  所以 daemon 用**自动端口发现**（见下）而非读文件。
- renderer target：`app://-/index.html`，title `Codex`。

## 使用步骤

### 一条命令启动（在你的终端跑，避免随工具会话被回收）

```bash
nohup /Applications/Codex.app/Contents/MacOS/Codex --remote-debugging-port=9333 >/tmp/codex.log 2>&1 &
nohup python3 ~/Desktop/PromptCocoPilot/mcp-server/http_server.py --port 8765 >/tmp/enhance.log 2>&1 &
sleep 7
cd ~/Desktop/PromptCocoPilot && node codex-ui/bin/codex-optimize-input.js
```

成功标志（终端打印）：

```
[prompt-coco-codex] attached to Codex main window (app://-/index.html)
```

然后在 Codex 输入框写一句模糊的话（如「那这个怎么改」），点右下角「优化输入」即可。

> 注意：
> - daemon 要保持终端运行（Ctrl+C 或关终端按钮即消失）。
> - Codex 必须用 9333 启动；**别从 Dock 点开**（那样没有调试端口，daemon 扫不到）。
> - 若 `8765` 已被占用（说明增强 API 已在跑），第二条 `nohup` 会报一行端口占用，忽略即可。

### 子命令

| 命令 | 作用 |
|------|------|
| `node codex-ui/bin/codex-optimize-input.js` | 默认：常驻 daemon，自动发现端口并注入 |
| `node codex-ui/bin/codex-optimize-input.js launch` | 用 `--remote-debugging-port` 启动 Codex（检测到已在跑且无端口则拒绝） |
| `node codex-ui/bin/codex-optimize-input.js probe` | dump Codex DOM（renderer url / 输入框候选 / 发送按钮候选） |
| `npm run codex:install-agent` | 安装 LaunchAgent（开机自启 daemon） |
| `npm run codex:uninstall-agent` | 卸载 LaunchAgent |

### 端口自动发现

daemon（`attachAndRunOnce`）调用 `discoverDevToolsPort`，按以下顺序解析 Codex 调试端口：

1. `CODEX_DEVTOOLS_PORT` 环境变量；
2. `~/Library/Application Support/Codex/DevToolsActivePort` 文件（直接执行可执行文件启动时不存在）；
3. **扫描** `[9333, 9222, 9229, 8315, 9339, 9444]`，对每个端口请求 `/json/list`，
   只要存在 url 以 `app://` 开头（或 title 含 `codex`/`owl`）的 page target，即判定为 Codex。

扫描能正确区分 Codex（`app://`）和占着 9222 的别的 Chrome，避免误连。

## 上下文注入范围（重要）

点击「优化输入」时，observer 收集的上下文是 **`document.body.innerText` 去重空行后的最后 6000 个字符**
（`observer_script.js` 的 `visibleContext()`），作为 `context` 字段连同 `draft` 一起 POST 给增强 API。

- **按字符数截断，不按“条数”**：最后 6000 字能装多少条取决于每条长度（短消息十几条，长消息几条）。
- **包含 AI 的回答**：`body.innerText` 是页面所有可见文本，既有用户消息也有 AI 回答（以及可见 UI 文本），
  只要在最后 6000 字窗口内都会被带上。
- 这与结构化 `conversation` 字段（`server.py` 支持 `max_messages=12`、按 `{role,content}` 区分）不同——
  注入按钮在页面里拿不到结构化消息，只能取可见文本。

**如需更精准**（限定最近 N 条 / 排除 AI 回答 / 只取用户消息）：在 `observer_script.js` 的 `visibleContext()`
里改为遍历 Codex 的消息节点按 role 收集（Codex 的消息容器），再拼成 context。

## 文件

- `codex-ui/src/codex_paths.js` — userData 目录、`DevToolsActivePort`、默认端口
- `codex-ui/src/codex_launcher.js` — `launch` / `discoverDevToolsPort` / `waitForDevToolsPort` / `ensureCodexWithDebugPort`
- `codex-ui/src/devtools_client.js` — 极简 CDP WebSocket 客户端（与 qoder-ui 相同）
- `codex-ui/src/daemon.js` — 连接、target 匹配、注入、轮询、`POST /enhance`、`probe`
- `codex-ui/src/observer_script.js` — 注入脚本 + probe 诊断脚本（ProseMirror/textarea 兼容写入）
- `codex-ui/src/launch_agent.js` — LaunchAgent 安装/卸载
- `codex-ui/bin/codex-optimize-input.js` — 子命令入口
- `codex-ui/test/*.test.js` — 17 个测试（`npm run test:node`）

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `CODEX_DEVTOOLS_PORT` | 自动发现 | 调试端口（env > 文件 > 扫描） |
| `CODEX_USER_DATA_DIR` | `~/Library/Application Support/Codex` | Electron userData 目录 |
| `CODEX_APP_PATH` / `CODEX_APP_NAME` | `/Applications/Codex.app` / `Codex` | 应用位置 / `open -a` 名称 |
| `ENHANCE_ENDPOINT` | `http://127.0.0.1:8765/enhance` | 本地增强 HTTP API |
