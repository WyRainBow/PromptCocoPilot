该仓库未引入专用的日志框架（如 Python `logging` 模块或 Node.js Winston/Pino），而是采用语言原生的标准输出作为主要的可观测性手段。这种轻量级设计符合其作为本地开发辅助工具的定位，但缺乏结构化日志和分级管理能力。

### 1. Python 组件 (MCP Server & HTTP API)
- **实现方式**：直接使用内置的 `print()` 函数。
- **主要场景**：
  - **错误回退提示**：在 `mcp-server/enhance.py` 中，当 Dashscope API 调用失败时，通过 `print(f"[enhance] Real Dashscope call failed: {e}. Using fallback.")` 输出警告。
  - **服务启动信息**：在 `mcp-server/http_server.py` 中，使用 `print` 告知用户 HTTP 监听地址。
  - **协议通信**：在 `mcp-server/server.py` 中，`print(json.dumps(message), flush=True)` 被用于 MCP 协议的 JSON-RPC 消息传输（这是 MCP stdio 传输层的必要实现，而非传统意义上的日志）。
- **特点**：缺乏日志级别管理（INFO/ERROR/WARN），也没有结构化字段。所有输出均直接流向 `stdout`。

### 2. JavaScript 组件 (Qoder UI Daemon)
- **实现方式**：使用 Node.js 原生的 `console.log` 和 `console.error`。
- **命名约定**：所有日志均带有统一的前缀 `[prompt-coco-qoder]`，便于在终端中进行过滤和识别。
- **主要场景**：
  - **状态追踪**：记录守护进程的连接状态（如 `attached to Qoder agents window`、`DevTools connection closed; reconnecting`）。
  - **业务事件**：记录 Prompt 优化请求的处理结果（如 `optimize-success`、`optimize-error`）。
  - **异常捕获**：使用 `console.error` 记录 DevTools 连接失败或应用优化结果时的异常堆栈。
- **特点**：虽然区分了 `log` 和 `error`，但依然属于非结构化的文本输出，未集成到任何日志收集系统。

### 3. 开发建议
- **当前约束**：由于缺乏统一的日志配置，生产环境调试主要依赖终端实时输出。
- **改进方向**：若需提升可维护性，建议在 Python 端引入 `logging` 模块并配置基础 handler，在 JS 端考虑使用支持多级别输出的轻量级库，以便在部署为后台服务时能更灵活地控制输出粒度。