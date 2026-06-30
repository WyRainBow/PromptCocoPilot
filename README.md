# Claude Code 提示词增强器 Skill

一个上下文感知的输入优化 Skill，专为 Claude Code 设计，复刻 Kilo Code 的 "Enhance Prompt" 功能。

## 项目目标

提供一个**发送前提示词优化层**，实现以下功能：
- 读取当前对话历史和任务上下文
- 对用户输入的草稿进行重写、优化，提升清晰度、具体性和完整性
- 支持注入相关上下文（文件、选中代码、历史记录）
- 支持用户在发送前进行审阅（透明可控）

## 核心特性

- 轻量级专用重写器（参考 Kilo Code 的 enhance-prompt.ts 设计）
- 支持对话历史上下文（最近 N 条消息）
- 支持「下一轮问题打包」：把用户新草稿、前文对话、已读取代码事实、当前任务状态、当前文件/选区、用户偏好一起送去增强
- 通过 MCP 或调用方集成编辑器/工作区上下文
- 提供 MCP Tool，可在 Claude Code 及其他支持 MCP 的 Agent 中使用
- 包含 SKILL.md，便于在 Claude Code 中集成
- 支持「增强前/后」对比展示 + 用户审阅的 UX 模式

## 项目结构

- `skill/` — SKILL.md 及 Claude Code Skill 相关文件
- `mcp-server/` — Python MCP Server，提供 `enhance_prompt` 工具
- `docs/` — 详细文档和技术方案
- `examples/` — 使用示例和配置
- `tests/` — 验证脚本和测试用例

## 推荐流程：下一轮问题增强

这个项目最适合用在连续编码对话里，不只是润色一句话，而是把“下一句问题”和“前面已经发生过的上下文”一起打包：

1. 用户输入一个很短的后续问题，例如「那这个怎么改」
2. 调用方收集最近对话、Claude Code 已读过的文件、从代码里得到的事实、当前任务状态、编辑器上下文和用户偏好
3. 调用 `enhance_prompt`，传入 `draft` 加结构化上下文
4. 工具返回一版可审阅的优化提示词
5. 用户确认后，再把优化后的提示词发给 Claude Code 执行

`enhance_prompt` 现在既支持传统的 `context` 字符串，也支持结构化字段：

- `conversation`：最近的 `{role, content}` 对话消息
- `code_facts`：已经读取代码后得到的 `{path, summary, symbols}` 事实
- `task_state`：当前排查/实现进度
- `current_file` / `selected_code`：编辑器上下文
- `user_preferences`：希望保留的用户约束或风格偏好

不调用模型也可以先查看打包效果：

```bash
python3 examples/enhance-next-turn.py examples/next-turn-context.json --print-context
```

## Codex「优化输入」按钮接口

仓库本身不能直接修改 Codex 桌面客户端的输入栏，但已经提供了按钮可调用的本地 HTTP API：

```bash
python3 mcp-server/http_server.py --host 127.0.0.1 --port 8765
```

Codex 侧如果支持输入栏 action，可以新增一个「优化输入」按钮，让它读取当前输入框内容和上下文，POST 到 `http://127.0.0.1:8765/enhance`，再把返回的 `enhanced` 写回输入框供用户审阅。

详见 `docs/codex-button-integration.md`。

## 上下文感知回复建议（Invoko 风格）

参考 [Invoko](https://invoko.ai) 的屏幕感知能力，新增"感知上下文"功能：

**Invoko 的核心机制：**

> "Invoko starts with the app, page, selection, and field in front of you."
> — 按需读取屏幕上下文，生成回复建议，无需用户描述"我在看什么"

**感知层（6 层，零被动监控）：**

| 层 | 内容 | 技术 |
|---|---|---|
| 1 | 前台 App 名称 + Bundle ID | `NSWorkspace` |
| 2 | 窗口标题 | AXUIElement |
| 3 | 页面 URL（浏览器标签） | AXUIElement AXURL |
| 4 | 选中文字 | `NSPasteboard` 剪贴板 |
| 5 | 聚焦输入框内容 | AXUIElement |
| 6 | 屏幕截图 | ScreenCaptureKit |

所有感知仅在点击"感知上下文"按钮时触发，从不被动监控。

**使用方式：**
1. 启动岛卡片（`⌃⌥⌘P` 或双击浮云）
2. 点击"感知上下文"按钮
3. 等待 1-2 秒，显示 1-3 个快捷回复选项
4. 点击选项 → 自动填入草稿 → 可编辑 → 点"增强"发送

**技术架构：**

```
Swift: ContextAwareness.gather()   ← 同步读取 5 层
     → ReplySuggestionClient        ← HTTP POST /generate_reply
     → Python: generate_reply_suggestions()  ← Dashscope LLM
     → 返回 suggestions[] + contextSummary
```

详见：
- `docs/context-awareness-design.md` — 完整调研与实现文档
- `claude-ui/swift/Sources/ContextAwareness.swift` — 6 层感知实现
- `mcp-server/enhance.py` — 回复生成逻辑

## 安装（Claude Code）

1. 启动 MCP Server
2. 将配置添加到 `claude_desktop_config.json`（或对应配置文件）
3. 在聊天中使用 Skill 或直接调用工具

详细步骤请参考：
- `docs/install.md`
- `examples/`

## Qoder 支持

Qoder（AI 编程 IDE）通过 `~/.qoder/mcp.json`（或 `~/.qoder/plugins/` 下的 mcp.json）支持 MCP Server。

我们已将 prompt-enhancer MCP 写入配置：

```json
{
  "mcpServers": {
    "prompt-enhancer": {
      "command": "python3",
      "args": ["/Users/wy770/Desktop/PromptCocoPilot/mcp-server/server.py"],
      "env": {
        "DASHSCOPE_API_KEY": "sk-你的密钥"
      }
    }
  }
}
```

启动 Qoder 并打开项目：

```bash
open -a Qoder /path/to/your/project
```

建议在**全新聊天**（无前置对话）中进行测试，以便公平对比增强前后的效果。

- **基础模式**：直接输入模糊 prompt（例如「帮我看看登录模块这个接口是什么」）
- **增强模式**：使用 `/prompt-enhancer <模糊提示>`（若支持），或直接调用 `enhance_prompt` MCP 工具并传入 draft + context

重启 Qoder 后可在工具列表中查看 `prompt-enhancer`。

## 使用方法

### 方式一：通过 Skill 自动触发（推荐）

当用户输入模糊、简短或不完整的指令时，Skill 会自动引导模型调用 `enhance_prompt` 工具。

示例：
```
帮我修个 bug
```

模型会先收集上下文（最近消息、当前文件、选中代码等），调用增强工具，并展示优化前后的对比。

### 方式二：手动调用工具

你可以显式要求：

```
先用 enhance_prompt 工具优化下面这个需求，再执行：
帮我加个仪表盘
```

或手动构造上下文：

```
调用 enhance_prompt 工具：
draft: 修登录问题
context: 
最近对话：
- 用户提到 401 错误
- 当前文件：src/auth/login.py
```

## 参考实现

- 核心逻辑参考 Kilo Code 的 Enhance Prompt 功能（`enhance-prompt.ts`）
- 采用严格的重写指令（只负责优化 prompt，不执行任务本身）

## 项目状态

✅ 已实现 Skills + MCP 核心能力

- `enhance.py` 已集成真实 Dashscope 调用（不再使用弱 fallback）
- `SKILL.md` 已加入进阶能力：自动触发模糊输入、完整历史上下文、透明 before/after + 改动说明、编辑器上下文支持、用户审阅后再发送
- MCP Server 支持真实 LLM 重写，对齐 Kilo Code 模式
- 文档与配置示例已完善

## 快速测试

**Claude Code：**
1. 配置好 MCP
2. 添加 Skill
3. 启动 `claude`
4. 输入模糊 prompt 观察效果

**Qoder：**
1. 将 MCP 加入 `~/.qoder/mcp.json`
2. 启动 Qoder 并打开项目
3. 新建聊天，输入模糊问题
4. 使用 `/prompt-enhancer` 或 MCP 工具进行增强

## 许可证

MIT

## 技术方案

完整架构、实现细节和设计决策请见：
- `docs/TECH_SCHEME.md`
- `docs/qoder-integration.md`
- `docs/claude-code-integration.md`
