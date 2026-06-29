PromptCocoPilot 项目采用基于语言特性的实用主义错误处理策略，主要涵盖 HTTP API 响应标准化、MCP 协议错误码规范以及 Node.js 守护进程的自动重连机制。

### 1. Python HTTP API 错误处理 (`mcp-server/http_server.py`)
- **统一响应格式**：所有错误均通过 `_send_json` 方法返回 JSON 格式的 `error` 字段。
- **分层捕获逻辑**：
  - `ValueError`：针对业务逻辑校验（如缺少 `draft` 参数），返回 **400 Bad Request**。
  - `json.JSONDecodeError`：针对请求体解析失败，返回 **400 Bad Request** 并标记 `invalid_json`。
  - `Exception`：针对未预期的运行时错误，返回 **500 Internal Server Error**。
- **静默日志**：重写 `log_message` 为空实现，避免在标准输出中暴露敏感堆栈信息，仅通过响应体反馈错误。

### 2. MCP 协议与核心逻辑错误 (`mcp-server/server.py`, `mcp-server/enhance.py`)
- **JSON-RPC 规范**：遵循 MCP/JSON-RPC 2.0 标准，使用标准错误码（如 `-32601 Method not found`）处理工具调用或方法缺失。
- **健壮性设计**：在 `main` 循环中使用 `try...except Exception` 包裹 JSON 解析，确保单条非法输入不会导致服务进程崩溃。
- **API 密钥校验**：在 `enhance.py` 中，若未检测到 `DASHSCOPE_API_KEY`，直接抛出 `RuntimeError` 阻止无效请求。
- **降级策略 (Fallback)**：当 Dashscope API 调用失败时，系统会捕获异常并切换至 `_simple_fallback_enhance` 本地逻辑，保证服务可用性。

### 3. Qoder UI 守护进程自愈 (`qoder-ui/src/daemon.js`)
- **指数退避重连**：`runDaemon` 函数实现了无限循环的附件逻辑。连接失败或断开后，通过 `delayMs` 进行延迟重试，延迟时间从 1s 指数增长至 15s 上限，防止频繁重连冲击资源。
- **外部服务容错**：在 `handleOptimizeRequest` 中，若本地 HTTP 增强服务（8765端口）不可用，会通过 DevTools 协议向 UI 注入“服务未开”的提示，而非让前端无响应。
- **WebSocket 生命周期管理**：通过 `onclose` 和 `onerror` 监听器清理定时器并触发重连流程。

### 4. 开发者规范
- **Python 端**：优先使用具体的异常类型（如 `ValueError`）进行业务校验；对外部 API 调用必须包含超时设置和异常捕获。
- **Node.js 端**：所有异步操作（尤其是 WebSocket 通信和 HTTP 请求）必须包含 `try...catch` 块；禁止在未处理的 Promise 中抛出错误。
- **错误反馈**：面向用户的错误应转化为友好的文本提示（如“服务未开”），面向开发者的错误应保留原始 `message` 以便排查。