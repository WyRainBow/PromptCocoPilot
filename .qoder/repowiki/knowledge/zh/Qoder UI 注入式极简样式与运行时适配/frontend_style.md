## 1. 系统与方法 (System & Approach)

本项目**不包含传统的前端工程化样式体系**（如 CSS 预处理器、Tailwind、组件库或全局主题配置）。其“前端样式”主要体现为 **Qoder UI 自动化模块**中，通过 Chrome DevTools 协议向 Qoder 应用界面**动态注入**的轻量级 DOM 元素及其内联样式。

核心策略是：**运行时注入 (Runtime Injection)**。脚本在目标应用（Qoder）的 `document.head` 中动态创建 `<style>` 标签，并插入特定的 CSS 类，以确保优化按钮与宿主应用的视觉风格保持基本一致且不破坏原有布局。

## 2. 关键文件 (Key Files)

*   `qoder-ui/src/observer_script.js`: **核心样式逻辑所在地**。定义了 `ensureOptimizeStyles()` 函数，负责生成和注入 CSS 规则，以及创建带有特定类名 (`qoder-optimize-input-button`) 的按钮元素。
*   `qoder-ui/src/devtools_client.js`: 提供与 Qoder 内部 WebView 通信的 WebSocket 客户端，是注入脚本的前提，但不直接包含样式定义。
*   `.qoder/repowiki/knowledge/zh/Qoder UI 注入式样式与极简按钮设计/frontend_style.md`: 详细记录了样式设计的规范与约束。

## 3. 架构与约定 (Architecture & Conventions)

### 3.1 样式注入机制
*   **隔离性**: 样式通过唯一的 ID (`qoder-optimize-input-style`) 和数据属性 (`data-prompt-coco-pilot-version`) 进行管理，防止重复注入或版本冲突。
*   **CSS 变量适配**: 颜色使用了 `var(--foreground, #555)`，尝试适配 Qoder 宿主环境的主题变量（如深色/浅色模式），若变量不存在则回退到硬编码的深灰色。
*   **系统字体栈**: 字体定义为 `-apple-system, BlinkMacSystemFont, sans-serif`，确保在 macOS 环境下与原生应用视觉融合。

### 3.2 视觉规范 (Visual Specs)
注入的 `.qoder-optimize-input-button` 遵循以下极简设计规范：
*   **尺寸**: 固定高度 `22px`，最小宽度 `22px`，内边距 `0 6px`。
*   **外观**: 透明背景 (`background: transparent`)，无边框 (`border: 0`)，圆角 `4px`。
*   **交互反馈**:
    *   **Hover**: 背景变为半透明灰色 `rgba(127, 127, 127, 0.16)`。
    *   **Busy/Loading**: 透明度降低至 `0.62`，光标变为 `wait`。
    *   **状态文本**: 按钮文本会根据状态动态变化（“优化输入” -> “优化中” -> “已优化”/“优化失败”）。

## 4. 开发者规则 (Rules for Developers)

1.  **禁止引入重型样式框架**: 由于目标是注入到第三方 Electron/WebView 应用中，严禁引入 Tailwind、Bootstrap 等全局样式库，以免污染宿主环境或导致体积过大。
2.  **样式必须内联或动态注入**: 所有 UI 相关的 CSS 必须写在 `observer_script.js` 的模板字符串中，并通过 JS 动态插入。
3.  **使用 CSS 变量实现主题兼容**: 优先使用 `var(--xxx)` 获取宿主应用的颜色值，确保在深色模式下依然可见。
4.  **类名命名空间化**: 所有自定义类名必须以 `qoder-optimize-input-` 为前缀，避免与 Qoder 内部类名冲突。
5.  **无响应式设计需求**: 目标环境为桌面端 IDE，无需考虑移动端响应式布局，但需确保按钮在输入框附近的定位准确。