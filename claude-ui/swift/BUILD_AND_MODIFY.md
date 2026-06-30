# 构建 & 修改指南（PromptCocoIsland / Swift 刘海小云朵）

> 本文说明：① 这个程序**怎么启动**；② 之前为什么编不过 Rive 版本、现在怎么修的；③ 以后想改**尺寸 / 动画 / 行为**，具体改**哪个文件的哪个符号**。
>
> 视觉与刘海物理尺寸的设计细节见 [`NOTCH_ISLAND_DESIGN.md`](NOTCH_ISLAND_DESIGN.md)，本文不重复，只讲"动手改哪里"。

---

## 1. 这是哪个项目？别改错了

仓库根目录下有多个并列的 UI 子项目，**它们是各自独立的小程序，不要串**：

| 目录 | 是什么 | 入口 |
|------|--------|------|
| **`claude-ui/swift/`** | ✅ **本文讲的那个** —— 原生 Swift 刘海小云朵（Rive 动画） | `build/PromptCocoIsland` |
| `claude-ui/bin/` | 同功能的 Python (pywebview) 老版本 | `claude-float.py` 等 |
| `codex-ui/` | 给 Codex 用的优化输入守护进程（Node） | `codex-optimize-input.js` |
| `qoder-ui/` | 给 Qoder 用的优化输入（Node） | `qoder-optimize-input.js` |
| `mcp-server/` | 后端增强服务（`/enhance` 接口，端口 8765） | `http_server.py` |

**要改"刘海里那个小云朵"——改 `claude-ui/swift/`。** 其余目录跟它无关。

---

## 2. 怎么启动

### 一次性构建 + 运行

```bash
cd claude-ui/swift
bash build.sh                              # 编译 → build/PromptCocoIsland
./build/PromptCocoIsland                    # 启动（无 Dock 图标，常驻刘海）
```

或者用根目录的 npm 快捷脚本：

```bash
npm run claude:island:build                 # = bash claude-ui/swift/build.sh
npm run claude:island                        # 直接运行已编译产物
```

停止：`pkill -f PromptCocoIsland`

### ⚠️ 前置：增强服务必须先跑

小云朵点"优化"会调用后端 `http://127.0.0.1:8765/enhance`。没起会提示「增强服务未运行」：

```bash
python3 mcp-server/http_server.py --host 127.0.0.1 --port 8765
```

---

## 3. 当前情况：Rive 版本是怎么救回来的（重要背景）

### 之前为什么编不过

代码 `import RiveRuntime` 用的是 **Rive 动画**（`.riv` 矢量动画，idle / thinking / done 三态）。
原先用的 `RiveRuntime.framework` 是**从 Invoko.app 里抠出来的残缺二进制**——只有 Mach-O 库，**没有 `.swiftmodule` / `.swiftinterface`**。

裸 `swiftc`（本项目不用 Xcode 工程，直接 `swiftc` 编译）必须靠模块声明才能 `import`，于是任何机器上都报：

```
Sources/RiveCloudView.swift:2:8: error: no such module 'RiveRuntime'
```

**这不是"换台电脑没 Rive 文件"的问题，是那个 framework 本身就不能用于裸 swiftc。** 你下午在另一台电脑编不过、回到这台电脑也编不过，根因都是它。

### 现在的修复（已提交，commit `f65b8b3`）

1. **换用官方 `rive-app/rive-ios` v6.21.0** 的 macOS slice（`macos-arm64_x86_64`），它**带完整的 `Modules/RiveRuntime.swiftmodule`**，裸 swiftc 能正常 `import`。
2. **`Frameworks/` 和 `Resources/*.riv` 不再被 `.gitignore` 忽略**，已入库 → `git clone` 后开箱即编 Rive 版本。
3. **`build.sh` 加了自动下载兜底**：万一 framework 缺失（比如 clone 丢了），会自动从官方 release 拉取并校验 checksum（`a44ceea0…`）。
4. Invoko 那个旧 framework 留作 `Frameworks/RiveRuntime.framework.invoko_bak` 备查。

> 想升级 Rive 版本：改 `build.sh` 顶部的 `RIVE_VERSION` 和 `RIVE_CHECKSUM`（checksum 从 [rive-ios releases](https://github.com/rive-app/rive-ios/releases) 取），删掉本地 framework 让脚本重新下载即可。

---

## 4. 想改东西，改哪里（速查表）

所有改动都在 `claude-ui/swift/Sources/` 下。**改完必须重新 `bash build.sh`**。

### 4.1 改刘海尺寸（长度 / 宽度 / 高度）

> 物理尺寸的设计推导看 [`NOTCH_ISLAND_DESIGN.md`](NOTCH_ISLAND_DESIGN.md)。这里只给"动手改哪里"。

停靠态（docked，云收进刘海那态）的尺寸**在两个文件里各有一份，必须同步改**，否则窗口和内容对不齐、出现缝隙：

| 要改的 | 文件 | 符号 | 当前值 |
|--------|------|------|--------|
| 停靠**宽度**（常态/hover） | [`IslandView.swift:66`](Sources/IslandView.swift) | `dockWidth(_:)` | `notch.width + 105`（hover `+145`，≈290pt） |
| 停靠**宽度**（窗口侧，必须同上） | [`App.swift:531`](Sources/App.swift) | `modeSize()` | `notch.width + 105`（hover `+145`） |
| 停靠**下挂高度** | [`IslandView.swift:65`](Sources/IslandView.swift) | `dockHang(_:)` | `0`（齐平，不挂裙边） |
| 停靠**云朵尺寸** | [`IslandView.swift`](Sources/IslandView.swift) `residentDocked` | 云尺寸 | `36×31`（hover `40×32`） |
| 刘海高（基准） | [`App.swift`](Sources/App.swift) | `safeAreaInsets.top` 读取 | `32 pt` |

> ⚠️ **`dockWidth` 和 `modeSize()` 是同一个数的两份拷贝**，改了一个必须改另一个。这是已知约束（见设计文档"必须保持一致"那段）。

### 4.2 改 Rive 动画（云朵的表情/状态）

| 要改的 | 文件 | 说明 |
|--------|------|------|
| 用哪个 `.riv`、哪个 artboard / stateMachine | [`RiveCloudView.swift`](Sources/RiveCloudView.swift) `make(_:)` | 按 `MascotState`（idle/thinking/done）映射到 `.riv` 文件名 |
| 动画资源本身 | [`Resources/*.riv`](Resources/) | 替换 `.riv` 文件（构建时会自动复制到产物旁） |

### 4.3 改交互 / 快捷键 / 窗口行为

| 要改的 | 文件 |
|--------|------|
| 全局快捷键、 AppState、停靠/浮动态切换 | [`App.swift`](Sources/App.swift) |
| 胶囊条 + 展开卡片 UI、拖动落点 | [`IslandView.swift`](Sources/IslandView.swift) |
| 读取 Claude Code 会话上下文 | [`SessionReader.swift`](Sources/SessionReader.swift) |
| 调用增强接口 `/enhance` | [`EnhanceClient.swift`](Sources/EnhanceClient.swift) |
| 剪贴板读取 + 模拟粘贴 | [`Selection.swift`](Sources/Selection.swift) |

---

## 5. 常见坑

- **`no such module 'RiveRuntime'`** → framework 的 `Modules/` 丢了或被换回 Invoko 残缺版。删掉 `Frameworks/RiveRuntime.framework` 重跑 `build.sh`（会自动下官方版）。
- **点优化提示「增强服务未运行」** → 先起 `mcp-server/http_server.py`（见 §2）。
- **改了尺寸但没生效 / 有缝** → `dockWidth`（IslandView）和 `modeSize()`（App）没同步，见 §4.1。
- **运行后看不到云** → 确认进程在跑（`pgrep -fl PromptCocoIsland`），它无 Dock 图标，只在刘海/屏幕顶部出现。
