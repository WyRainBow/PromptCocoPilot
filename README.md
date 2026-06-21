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
