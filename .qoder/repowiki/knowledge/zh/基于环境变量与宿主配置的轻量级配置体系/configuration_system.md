## 1. 系统概述
PromptCocoPilot 采用**去中心化、轻量级**的配置策略，未引入专用的配置文件（如 `.yaml`、`.toml`）或复杂的配置管理框架。其配置体系主要依赖以下三种方式：
1. **环境变量 (Environment Variables)**：用于管理敏感信息（API Key）和运行时参数（端口、模型选择）。
2. **宿主应用配置 (Host Configuration)**：通过 MCP 协议标准，将服务启动命令注入到 Claude Code 或 Qoder 的宿主配置文件中。
3. **硬编码路径与默认值 (Hardcoded Defaults)**：在代码中直接定义默认路径、端口和回退逻辑，辅以环境变量覆盖。

## 2. 关键配置项与文件

### 2.1 环境变量配置
核心逻辑位于 `mcp-server/enhance.py` 和 `qoder-ui/src/daemon.js`。

| 变量名 | 作用域 | 说明 |
| :--- | :--- | :--- |
| `DASHSCOPE_API_KEY` | Python (MCP) | 阿里云 Dashscope API 密钥。优先从环境变量读取，若不存在则尝试从硬编码路径 `/Users/wy770/Resume-Agent/.env` 加载（见 `enhance.py:24-36`）。 |
| `ENHANCE_MODEL` | Python (MCP) | 指定用于提示词增强的模型，默认为 `deepseek-v4-flash`。 |
| `QODER_DEVTOOLS_PORT` | Node.js (Qoder UI) | 指定 Qoder DevTools 调试端口。若未设置，则从 `DevToolsActivePort` 文件动态读取。 |
| `QODER_SUPPORT_DIR` | Node.js (Qoder UI) | 覆盖 Qoder 支持目录的默认路径（默认为 `~/Library/Application Support/Qoder`）。 |

### 2.2 宿主集成配置
服务本身不包含独立的 `config.json`，而是要求用户在宿主应用中配置启动命令。

- **Claude Code**: 需在 `claude_desktop_config.json` 中注册 MCP Server：
  ```json
  {
    "mcpServers": {
      "prompt-enhancer": {
        "command": "python3",
        "args": ["/absolute/path/to/mcp-server/server.py"]
      }
    }
  }
  ```
- **Qoder**: 类似地，需在 `~/.qoder/mcp.json` 中注册。

### 2.3 运行时参数
- **HTTP 服务**: `mcp-server/http_server.py` 使用 `argparse` 接收命令行参数 `--host` (默认 `127.0.0.1`) 和 `--port` (默认 `8765`)。

## 3. 架构约定与设计决策

1. **零配置文件原则**：为了降低部署复杂度，项目避免使用额外的配置解析库。所有非敏感配置均通过代码常量或命令行参数暴露。
2. **敏感信息隔离**：API Key 严禁硬编码在版本控制文件中。`enhance.py` 实现了从环境变量到特定 `.env` 文件的回退加载机制，但生产环境建议直接使用环境变量。
3. **动态发现机制**：Qoder UI 组件通过读取 `DevToolsActivePort` 文件动态获取调试端口，而非依赖静态配置，增强了在不同环境下的适应性。
4. **本地回环限制**：HTTP 服务和 DevTools 连接均默认绑定 `127.0.0.1`，确保配置的安全性，防止外部访问。

## 4. 开发者指南

- **添加新配置项**：优先使用 `os.getenv()` (Python) 或 `process.env` (Node.js) 读取环境变量，并提供合理的默认值。
- **敏感信息管理**：不要在代码中提交真实的 API Key。若需本地测试，可创建 `.env` 文件并确保其已加入 `.gitignore`。
- **路径配置**：涉及文件系统的路径（如 Qoder 支持目录）应通过 `qoder-ui/src/qoder_paths.js` 统一管理，并支持通过环境变量覆盖。
- **模型切换**：如需更换增强模型，只需设置 `ENHANCE_MODEL` 环境变量，无需修改代码。