## 1. 依赖管理系统概览

该仓库采用**极简主义**的依赖管理策略，主要特征如下：
- **无显式清单文件**：Python 模块（`mcp-server/`）和 Node.js 模块（`qoder-ui/`）均未提供标准的依赖清单文件（如 `requirements.txt`, `pyproject.toml`, `package-lock.json` 等）。
- **隐式运行时依赖**：依赖项通过代码中的 `import` 语句和文档中的安装说明隐式定义。
- **环境变量驱动配置**：关键的外部服务依赖（Dashscope API）通过环境变量或硬编码路径加载，而非通过配置文件管理。

## 2. 关键文件与依赖分析

### Python 后端 (`mcp-server/`)
- **核心依赖**：
  - `requests`: 用于调用 Dashscope API (`mcp-server/enhance.py`)。
  - `mcp`: 文档建议安装以获取完整协议支持，但当前实现为基于 `stdio` 的最小化自定义服务器 (`mcp-server/server.py`)。
- **缺失文件**：根目录及 `mcp-server/` 下未发现 `requirements.txt` 或 `setup.py`。开发者需根据代码导入手动安装依赖。
- **外部服务依赖**：
  - **Dashscope API**: 在 `enhance.py` 中硬编码了备用 `.env` 路径 (`/Users/wy770/Resume-Agent/.env`) 用于加载 `DASHSCOPE_API_KEY`。这是一种非标准的、特定于开发者的配置方式，不具备可移植性。

### Node.js 前端/守护进程 (`qoder-ui/`)
- **核心依赖**：
  - 仅使用 Node.js **标准库** (`node:fs`, `node:url`, `node:path`)。
  - 未引入任何第三方 npm 包，因此无需 `node_modules` 或锁文件。
- **构建/运行脚本**：`package.json` 仅定义了运行脚本（如 `test:node`, `qoder:optimize-input`），未声明 `dependencies` 或 `devDependencies`。

## 3. 架构约定与设计决策

1. **零第三方依赖偏好 (Node.js)**：
   `qoder-ui` 模块刻意避免引入外部 npm 包，直接利用 Node.js 内置模块与 Chrome DevTools Protocol 交互。这简化了部署流程，避免了依赖冲突和版本锁定问题。

2. **最小化 Python 依赖**：
   MCP 服务器仅依赖 `requests` 进行 HTTP 通信。虽然文档提及 `mcp` 库，但实际代码实现了自定义的 JSON-RPC over stdio 处理逻辑，降低了对特定 SDK 版本的耦合。

3. **非标准化的配置加载**：
   `enhance.py` 中存在硬编码的绝对路径 (`/Users/wy770/...`) 用于加载 API Key。这表明项目尚处于个人开发或早期原型阶段，缺乏标准化的配置管理（如 `.env` 文件解析库 `python-dotenv` 或统一的配置模块）。

## 4. 开发者遵循规则

- **手动安装依赖**：由于缺少锁文件和清单，新环境搭建时需手动执行 `pip install requests`。若需完整 MCP 功能，需额外执行 `pip install mcp`。
- **API Key 配置**：必须设置环境变量 `DASHSCOPE_API_KEY`，或确保存在特定的 `.env` 文件（建议修改代码以支持通用的 `.env` 加载机制）。
- **避免引入重型依赖**：保持 `qoder-ui` 的零依赖特性；Python 端如需新增功能，应优先评估是否可通过标准库或轻量级库实现。
- **环境隔离**：建议使用虚拟环境 (`venv`) 管理 Python 依赖，尽管项目中未提供自动化激活脚本。