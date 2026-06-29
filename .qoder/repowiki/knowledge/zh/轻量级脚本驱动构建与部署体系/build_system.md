PromptCocoPilot 采用极简的、无编译的脚本驱动构建与部署模式，未引入复杂的 CI/CD 流水线、容器化方案或自动化构建工具（如 Makefile、Docker）。项目由 Python (MCP Server) 和 Node.js (Qoder UI 集成) 两部分组成，依赖宿主环境直接运行。

### 1. 构建工具与依赖管理
- **Node.js 部分**：通过 `package.json` 管理元数据与脚本。未定义 `dependencies`，表明其仅依赖 Node.js 内置模块（如 `node:url`, `node:path`）或系统全局工具。提供了 `test:node` 脚本用于运行单元测试，以及 `qoder:install-agent` 等便捷命令用于 macOS 守护进程的安装与卸载。
- **Python 部分**：未提供 `requirements.txt`、`setup.py` 或 `pyproject.toml`。文档建议手动确保 Python 3.10+ 环境，并可选安装 `mcp` 库。这表明 Python 服务倾向于以源码形式直接运行，或通过宿主环境的虚拟环境手动管理依赖。

### 2. 部署与启动流程
- **MCP Server**：通过直接调用 `python3 mcp-server/server.py` 启动。在 Claude Code 等客户端中，通过配置文件指定解释器路径及脚本绝对路径进行集成。
- **HTTP API**：通过 `python3 mcp-server/http_server.py` 启动本地 HTTP 服务，供前端按钮或外部工具调用。
- **Qoder UI 守护进程**：通过 `node qoder-ui/bin/qoder-optimize-input.js` 启动。支持 `install-agent` 参数将自身注册为 macOS LaunchAgent，实现开机自启与后台驻留。

### 3. 测试策略
- **Node.js**：利用 Node.js 原生测试运行器 (`node --test`) 执行 `qoder-ui/test/` 下的测试文件。
- **Python**：存在 `tests/` 目录及多个 `test_*.py` 文件，但未在根目录发现统一的测试运行脚本，推测需手动调用 `pytest` 或 `python -m unittest` 执行。

### 4. 开发者规范
- **无编译步骤**：项目为解释型语言构成，修改代码后无需重新编译，重启服务即可生效。
- **路径配置**：由于缺乏自动化的安装脚本，集成时需手动配置绝对路径（如 Claude Desktop 配置文件中的 `args`）。
- **环境隔离**：建议开发者自行维护 Python 虚拟环境以隔离依赖，避免全局污染。