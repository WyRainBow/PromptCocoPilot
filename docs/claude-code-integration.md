# 如何把 Prompt Enhancer 接入 Claude Code

## 架构说明

我们做了两部分：

1. **MCP Tool** (`enhance_prompt`)：提供实际的 prompt 改写能力
2. **Skill** (`SKILL.md`)：告诉 Claude 什么时候应该用这个工具，以及怎么传上下文

Claude Code 会通过 MCP 发现工具，通过 Skill 学习使用策略。

---

## ⚠️ 重要提醒（当前实现局限）

目前 `mcp-server/server.py` 调用 `enhance_prompt` 时**没有传入真实的 LLM generate 函数**，会走到 `_simple_fallback_enhance`（纯字符串拼接）。

**效果会比较差**，达不到 Kilo Code 的水平。

**推荐做法**（二选一）：

**方案 A（推荐）**：让 MCP Server 内部真正调用 LLM 做增强（需要配置 API Key）。
**方案 B**：Skill 让 Claude 自己做增强（不需要额外 Key，但消耗主模型 token）。

下面先教你怎么接进来，后面会告诉你怎么改成真实增强。

---

## 接入步骤

### 1. 配置 MCP Server

Claude Code 使用和 Claude Desktop 类似的配置文件。

macOS 配置文件路径通常是：

```bash
~/Library/Application Support/Claude/claude_desktop_config.json
```

（如果是 Claude Code 独立版本，路径可能略有不同，可以在设置里找 "MCP" 或直接搜索这个文件名）

在配置文件中添加以下内容：

```json
{
  "mcpServers": {
    "prompt-enhancer": {
      "command": "python3",
      "args": [
        "/Users/wy770/Desktop/PromptCocoPilot/mcp-server/server.py"
      ],
      "env": {
        // 如果你想让 server 内部调用真实模型，这里可以传 key
        "DASHSCOPE_API_KEY": "sk-你的key",
        "DEEPSEEK_BASE_URL": "https://dashscope.aliyuncs.com/compatible-mode/v1"
      }
    }
  }
}
```

**注意**：
- 请把路径改成你机器上的**绝对路径**
- `python3` 要确保是能直接运行的路径（可以用 `which python3` 查看）

修改完后**完全退出 Claude Code 并重新打开**（重启很重要）。

### 2. 安装 Skill

Claude Code 会自动加载项目里的 skills。

在你的工作区根目录执行：

```bash
mkdir -p .claude/skills/prompt-enhancer
cp /Users/wy770/Desktop/PromptCocoPilot/skill/SKILL.md .claude/skills/prompt-enhancer/
```

也可以直接把整个 `skill/` 文件夹内容复制过去。

### 3. 验证是否加载成功

重启后，在 Claude Code 聊天里输入：

```
请列出你当前可用的 MCP 工具
```

或者

```
你有 enhance_prompt 这个工具吗？
```

如果看到工具，就说明 MCP 接入了。

---

## 使用方式

### 方式一：让 Claude 自动使用（推荐）

因为我们提供了 `SKILL.md`，Claude 应该会在你输入比较模糊的 prompt 时，主动考虑调用 `enhance_prompt` 工具。

你可以直接说：

> 帮我写一个登录功能

Claude 如果遵守 skill，应该会先调用增强工具。

### 方式二：显式要求

```
先用 enhance_prompt 工具帮我优化一下这个需求，然后再执行：
帮我修 bug
```

### 方式三：传入结构化上下文（效果最好）

你可以让 Claude Code 把下一轮问题和前面已经读过的代码事实一起传给工具：

```
调用 enhance_prompt 工具，参数如下：
draft: 那这个怎么改
conversation:
- role: assistant
  content: 已读取 src/auth.py 和 src/session.py，定位到 validate_session 可能返回 401。
code_facts:
- path: src/session.py
  summary: validate_session 在 token 查找失败时返回 401 Unauthorized
  symbols: [validate_session]
task_state: 正在定位有效用户登录后仍返回 401 的原因
current_file: src/session.py
selected_code: def validate_session(token): ...
user_preferences:
- 先说明根因，再给最小修改方案
- 修改后补充测试
```

这对应的是「用户的新问题 + 最近对话 + Claude Code 已经读过/总结过的代码信息」一起增强，而不是只润色一句孤立的话。

---

## 让增强真正变强（关键步骤） - 已实现

**更新**: `enhance.py` 现在默认支持真实 Dashscope 调用！

- 如果 `DASHSCOPE_API_KEY` 在环境变量中（或从 `/Users/wy770/Resume-Agent/.env` 自动加载），`enhance_prompt` 会自动使用真实模型（deepseek-v4-flash via compatible mode）进行高质量改写。
- 完全复刻 Kilo Code 的 dedicated enhancer 调用模式。
- 增强时会严格使用 INSTRUCTION + 传入的 context（history + files 等）。

在 MCP 配置中传入 env 即可：

```json
"env": {
  "DASHSCOPE_API_KEY": "sk-你的key"
}
```

server.py 现在会通过 enhance 进行真实 LLM 增强。

### 进阶建议已加入（仅 Skills + MCP 范围内）

已在 `skill/SKILL.md` 中加入以下进阶能力指导：

- **自动触发**：对模糊输入（"fix bug", "add feature" 等）自动调用工具。
- **完整历史上下文**：默认带最近 8-12 条消息，Claude 负责组装。
- **已读代码事实**：把前面读到的文件、函数、错误路径、结论以 `code_facts` 传入。
- **透明 Review**：必须展示 before/after + 改动总结给用户编辑。
- **Editor 上下文**：支持传入当前文件、选中代码。
- **结构化具体化**：增强后的 prompt 必须包含具体文件、要求、成功标准。
- **不执行原 prompt**：永远先增强再行动。
- **低延迟**：MCP server 内部用 fast model 做增强。

这些使它更接近 Kilo Code 的 "原始输入 → 上下文补全 → 改写 → 人审 → 发送" 流程，且通过 Skill 自动引导。

---

## 常见问题

**Q: 重启后看不到工具？**  
A: 检查路径是否正确、python3 是否可用、配置文件格式是否正确。可以在终端手动运行 `python3 mcp-server/server.py` 看有没有报错。

**Q: 增强效果很一般？**  
A: 当前用的是 fallback 逻辑。必须改成真实 LLM 调用才能达到 Kilo Code 的水平。

**Q: 想实现像 Kilo 一样的 ✨ 按钮？**  
A: Claude Code 目前主要是通过工具调用 + Skill 引导。想有按钮需要写一个薄客户端（VS Code extension）来拦截输入框内容，调用我们的 MCP，再把结果写回去。

---

需要我现在帮你：

1. 把 `server.py` 改成真正调用 Dashscope/DeepSeek 做增强？
2. 提供一个更完善的 `enhance.py`（支持多种模型）？
3. 写一个简单的 VS Code 扩展骨架来实现 ✨ 按钮？

直接说要哪一个，我马上改。
