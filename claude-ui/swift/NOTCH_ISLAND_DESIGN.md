# PromptCocoPilot 刘海灵动岛 · 设计与实现文档

> 原生 Swift/AppKit 实现的 MacBook 刘海灵动岛（Invoko / Dynamic Island 风格）。
> 桌面浮云 ⇄ 收进刘海 ⇄ 展开增强卡片。云朵用 Rive 渲染（复刻 Invoko 的 IPDefault 资产）。
>
> 代码位置：`claude-ui/swift/Sources/`，构建脚本 `claude-ui/swift/build.sh`。

---

## 1. 目标

做一个真正**嵌进刘海**的浮动云 UI，而不是一个贴在屏幕顶部、浮在刘海下面的卡片。三个交互维度：

1. **浮动态（floating）**：一朵云在桌面自由拖动。
2. **停靠态（docked）**：云收进刘海，和菜单栏齐平，像长在刘海里。
3. **展开态（expanded）**：双击云，从所在位置展开"增强/优化"卡片；再次收起回到原位。

参考：[ericjypark/codex-island]、本地 `开源工具/CodeIsland`（wxtsky）、本地安装的 **Invoko**（原生 Swift app）。

---

## 2. 整体架构

### 2.1 窗口：NSPanel（非激活面板）

文件：`Sources/App.swift` → `IslandWindowController`、`KeyablePanel`。

关键点（和 CodeIsland 一致）：

```swift
let p = KeyablePanel(
    contentRect: ...,
    styleMask: [.borderless, .nonactivatingPanel],   // 不抢焦点
    backing: .buffered, defer: false)
p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)  // 盖在菜单栏/刘海之上
p.backgroundColor = .clear
p.isOpaque = false
p.hasShadow = false
p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
```

- **`.nonactivatingPanel`**：点击不会激活我们的 app、不抢走别的 app 的焦点（用 `NSWindow` 会激活，是早期"融不进刘海"的根因之一）。
- **`KeyablePanel`** 重写 `canBecomeKey = true`，否则输入框（草稿/结果）无法获得键盘焦点。
- **窗口层级 = 菜单栏 + 2**：盖在系统菜单栏与刘海之上。

### 2.2 宿主视图：`NotchHostingView`（去 safe-area）

`NSHostingView` 子类，做三件事：

1. `safeAreaInsets → .zero`（+ macOS 14 `safeAreaRegions = []`，SwiftUI 里再 `.ignoresSafeArea(.all)`）：让 SwiftUI 内容能画到刘海/菜单栏**正下方乃至之内**，而不是被 safe area 顶下来。**这是"贴合刘海"的前提**——早期内容被 safe area 推到刘海下面就是因为这个。
2. `acceptsFirstMouse = true` + `mouseDown → window.makeKey()`：非激活面板上第一次点击也能即时触发 SwiftUI 动作。
3. 把 `needsLayout / needsUpdateConstraints` 的置位**延迟到下一个 runloop**：避免 AppKit 在 display-cycle 里重入 `_postWindowNeedsUpdateConstraints` 崩溃。

### 2.3 三态状态机

`Sources/App.swift` → `AppState`：

```swift
enum Presence { case floating, docked, expanded }
@Published var presence: Presence = .floating      // 默认：桌面浮云
@Published var dockPreview: Bool                    // 拖近刘海时的"落点预览"
@Published var notchHovered: Bool                   // 停靠态 hover → 变宽
var expandedFromDock: Bool                          // 从刘海展开 vs 从浮云展开
@Published var mascot: MascotState                  // idle / thinking / done（切换 .riv）
```

视图层 `Sources/IslandView.swift` → `IslandRoot` 按 `presence` 切换三套渲染：
`cloudFloating` / `dockedCanvas` / `expandedCanvas`，附 `dockingPreview`（拖近刘海的光晕）。

---

## 3. 刘海几何

`Sources/App.swift` → `NotchInfo.detect(_:)`：

```swift
let h = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 32     // 刘海高
let w = screen.frame.width - leftAux.width - rightAux.width                 // 刘海宽
```

- `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` = 刘海**两侧**可用的菜单栏区域。
- 刘海开孔宽 = 屏宽 − 左翼 − 右翼。

本机实测（内置 Liquid Retina XDR，1512pt 宽）：

| 量 | 值 |
|---|---|
| 刘海宽（开孔） | **185 pt** |
| 刘海高 | **32 pt** |
| 左翼可用宽 | 663 pt |
| 右翼可用宽 | 664 pt |

**关键物理事实**：刘海开孔（中间那 185pt × 32pt）是**物理挖孔、非显示区**——在那儿画任何东西都看不见（摄像头在那）。所以放在刘海正中的内容必须放到开孔**下方**。这条约束贯穿整个停靠态设计。

> 屏幕检测优先选**带刘海**的内置屏：`auxiliaryTopLeftArea != nil || safeAreaInsets.top > 0`，否则回退主屏。多屏环境下 app 会落在刘海屏。

---

## 4. 停靠态：贴合刘海的关键

这是整个项目最难调、迭代最多的部分。结论先行：

> **贴合 = 和菜单栏齐平（高度 = 刘海高，下面不挂任何东西）。**
> 任何"挂在菜单栏下面的圆角裙边"都会被眼睛读成一个浮出来的盒子 = "超出"。

### 4.1 `NotchPanelShape`（移植自 CodeIsland）

`Sources/IslandView.swift` 末尾。一个 `Shape`：

- **顶边外扩 `topExtension`（肩膀）**：顶边比主体两侧各宽 `ext`，再用三次贝塞尔曲线"拐"下来融进菜单栏 —— 盒子像是从刘海**长出来**的，而不是浮在下面。
- **底部连续曲率圆角**（squircle，`k = 0.62`）：苹果味圆角。
- `minHeight`：固定下限，防止弹簧动画过冲把形状缩到刘海上面去。

停靠态用它作背景，并 `.padding(.horizontal, shoulderExt)` 把肩膀让回窗口边缘内（不被裁）。

### 4.2 当前停靠态参数（已定稿）

`dockedCanvas` / `residentDocked` / `dockHang` / `dockWidth`：

```swift
shoulderExt = 4                                   // 顶部小肩膀融入菜单栏
dockHang(hovered)  = 0                            // ★ 齐平：菜单栏线以下不挂任何东西
dockWidth(hovered) = notch.width + (hovered ? 116 : 76)   // 静态 ~261，hover ~301
bottomRadius = 11
// residentDocked：HStack { 云(左翼) | Color.clear(notch.width 留给摄像头) | 蓝点(右翼) }
// 云：静态 30×28、hover 34×32，leading 8/11；整体高度 = 刘海高(32)，纵向居中
```

- 盒子高度 = 刘海高（32pt），**下面不挂**，圆角落在菜单栏线上。
- 云在**左翼**（摄像头左边，菜单栏高度），蓝点在**右翼**。
- 中间 `Color.clear.frame(width: notch.width)` 把摄像头开孔让出来。
- hover 时**只横向变宽**，不变高 —— 这种"只横着长"才像 Invoko 的 resident notch。

### 4.3 为什么是"齐平 + 不挂裙边"（踩坑实录）

迭代里试过的错误形态，以及为什么错：

| 试过的形态 | 为什么被否 |
|---|---|
| 内容没顶到刘海顶（有缝） | 看着像贴上去的黑块（"虚假"），没融进刘海 |
| 往下挂一个圆角裙边（nh+8 ~ nh+20） | 露在菜单栏**下面**的那块盒子被读成"超出" |
| 又窄又长的"舌头"（云在开孔正下方、≈刘海宽） | 太长太窄，不是用户要的"云在摄像头旁边"（第二个 = CodeIsland 那种） |
| 裙边收窄（菜单栏层全宽 + 窄裙边） | 浅色壁纸下菜单栏层那条黑还是露出来 |
| **齐平、高度=刘海高、不挂裙边** ✅ | **定稿**：黑色翼藏进（深色）菜单栏，下面什么都不挂 → 不超出 |

### 4.4 "超出"的真相 + 壁纸洞察

用真实屏幕像素量过（截图 + CGImage 扫描）：

- **CodeIsland 实测**：菜单栏层整条是暗的（融进深色菜单栏），菜单栏线**以下什么都没有**。它从不"超出"，就是因为：宽黑翼**藏在深色菜单栏里 + 下面不挂东西**。
- 我们早期"超出"纯粹是因为**有裙边往菜单栏下面挂**——那块挂下来的圆角盒子是唯一被眼睛读成"盒子超出"的东西。去掉裙边（`dockHang = 0`）即解决。

**重要前提（已知限制）**：这种"宽翼藏进菜单栏"的做法**依赖菜单栏是深色**（深色壁纸/深色模式）。在**浅色/亮色壁纸**下，菜单栏是半透明透出壁纸色，我们这条比刘海宽的黑翼**会显出来**——CodeIsland / Invoko 在浅色壁纸下同样会显。要在**任意壁纸**下都绝不超出，唯一办法是把整块黑做到 **≤ 刘海宽**、云放到开孔下方（见 §4.5 备选）。当前定稿选了"齐平宽翼"方案（深色壁纸下完美贴合）。

### 4.5 备选方案（保留思路，未启用）

若要在浅色壁纸下也绝不超出：把 `dockWidth` 收成 `notch.width`、`dockHang` 调到能容下云的高度，`residentDocked` 改成
`VStack { Color.clear(刘海高) ; 云居中 }`，云落在开孔**正下方**。代价：云在摄像头下方而非旁边（不是 CodeIsland 那种横排）。代码里 `NotchPanelShape(topExtension: 0, ...)` 已能直接支持。

---

## 5. 调研：Invoko & CodeIsland

用户要求"攻破 Invoko 的设计"。结论：

### 5.1 Invoko 是原生 Swift/AppKit（不是 Electron）

`/Applications/Invoko.app/Contents/`：
- `Frameworks/`：`RiveRuntime.framework`（**和我们一样用 Rive 渲染云**）、`Sparkle`、`Sentry`、`libinvoko_voice_core.dylib`。
- `Resources/`：`IPDefault*.riv`（idle / thinking / done / listening / error … 整套状态）、`NotchStateMachine.md`、`ExplorationVokoSalaDesign.md`。
- `MacOS/Invoko`：26MB 原生二进制；`Info.plist` `LSUIElement = true`（无 Dock 图标）。

### 5.2 Invoko 的刘海状态机（来自其自带 `NotchStateMachine.md`）

- 入口：`UI/Panels/FloatingPanelController.swift`（几何收放）、`UI/Views/NotchV3StatusBar.swift`（"V3 cloud/status bar"）、`UI/Views/CompactBarView.swift`、`State/NotchPresentationState.swift`。
- 停靠的云 = **"folded resident notch / 横向 resident handle"**：和菜单栏齐平的**横条**，云坐在摄像头旁边的翼里；**不往下挂**。
- hover / fold-cue → 进入"更大的**横向**展开态"（横着变宽，不是竖着挂）。

→ 印证了 §4 的结论：**齐平 + 横向**，不挂裙边。

### 5.3 CodeIsland（本地源码）

- `Sources/CodeIsland/ScreenDetector.swift`：刘海几何检测（和我们 `NotchInfo` 同公式）。
- `Sources/CodeIsland/PanelWindowController.swift`：**大透明窗口贴屏顶**（`y = screenFrame.maxY - height`），在里面画刘海形状；这是"内容永远对齐刘海"的根本手法。
- `Sources/CodeIsland/NotchPanelView.swift` → `NotchPanelShape`：肩膀 + squircle 圆角（我们移植了它）；折叠态 `CompactLeftWing`（mascot ≈ 26pt）+ `Spacer(刘海宽)` + `CompactRightWing`，整条 = 刘海高。

---

## 6. 云的渲染（Rive）

`Sources/RiveCloudView.swift` —— 1:1 复刻 Invoko 的云（直接渲染 Invoko 的 `.riv` 资产）。

```swift
RiveViewModel(RiveModel(riveFile: file),
              stateMachineName: cfg.sm, fit: .contain, artboardName: cfg.artboard)
```

按 `AppState.mascot` 切 `.riv` / artboard / state machine：

| 状态 | 文件 | artboard | state machine |
|---|---|---|---|
| idle | `IPDefaultIdle` | `idle` | `State Machine 1`（自动眨眼） |
| thinking | `IPDefaultThinking` | `thinking` | `Thinking` |
| done | `IPDefaultDone` | `task complete` | `Task Complete`（烟花） |

- 加载失败回退到手绘 `CloudView`（`Sources/CloudView.swift`）。
- `.allowsHitTesting(false)`：点击/拖拽穿透给父视图（双击展开、拖动）。
- `.riv` 文件由 `build.sh` 拷到可执行文件旁；用 `Bundle.main.executableURL` 定位。

> ⚠️ `RiveRuntime.framework` 与 `IPDefault*.riv` 是 **Invoko 的专有资产**，仅供本地/个人使用，**已被 `.gitignore` 忽略，不随仓库分发**。换机需自行从本地 Invoko 拷贝（见 §9）。

---

## 7. 交互

`IslandWindowController.handleDrag(_:)`，用 `NSEvent` 本地监听 + **绝对鼠标坐标**（避免 SwiftUI `DragGesture` 跟着移动窗口抖动）。

- **浮动态**：自由拖动；拖近刘海顶部（`inDockZone`）→ `dockPreview`（蓝光落点光晕，松手吸入、拖离取消）。
- **停靠态**：往下拽把云拉出来变浮动；hover → 变宽。
- **双击云** → `toggleExpand()`：从当前位置展开卡片（`expandedFromDock` 决定从刘海长出还是从浮云长出），再次双击/点外面收起。
- **吸入动画**：窗口帧用 `NSAnimationContext` + `CAMediaTimingFunction(0.2, 0.9, 0.2, 1.06)`（弹性过冲）；内容用 `absorbTransition = .scale(0.35, anchor:.top) + .opacity`（"被吸进刘海"的错觉）。
- 点 UI 外部（全局监听）→ 收起卡片（非激活面板收不到 `resignKey`，所以手动监听）。

---

## 8. 关键尺寸常量速查

| 项 | 值 | 位置 |
|---|---|---|
| 窗口层级 | 菜单栏 + 2 | `App.swift` init |
| 浮云尺寸 | 140 × 96 | `cloudFloating` / `cloudSize` |
| 停靠宽 | `notch.width + 76`（hover +116） | `dockWidth` / `modeSize` |
| 停靠高 | `notch.height`（hang 0，齐平） | `dockHang` / `modeSize` |
| 停靠肩膀 / 圆角 | 4 / 11 | `shoulderExt` / `dockedCanvas` |
| 停靠云 | 30×28（hover 34×32），leading 8/11 | `residentDocked` |
| 展开卡宽 | 380 | `expandedCanvas` / `modeSize` |
| presence 动画 | `spring(response:0.34, damping:0.74)` | `IslandRoot.body` |

> ⚠️ `dockWidth` / `dockHang` 在 `IslandView.swift` 和 `App.swift` 的 `modeSize()` 里**各有一份，必须保持一致**（窗口尺寸 = SwiftUI 画的尺寸），否则会出现"内容没填满窗口/有缝"。

---

## 9. 构建与运行

```bash
cd claude-ui/swift
bash build.sh            # swiftc 直编（无 Xcode 工程），链接 RiveRuntime，拷 .riv 到 build/
./build/PromptCocoIsland # 运行；pkill -f PromptCocoIsland 退出
```

`build.sh` 关键：`-F Frameworks -framework RiveRuntime -Xlinker -rpath -Xlinker @loader_path/Frameworks`，并把 `Frameworks/RiveRuntime.framework`、`Resources/*.riv` 拷到 `build/` 旁。

**首次/换机准备**（这些被 gitignore，不在仓库里）：
```bash
mkdir -p Frameworks Resources
cp -R /Applications/Invoko.app/Contents/Frameworks/RiveRuntime.framework Frameworks/
cp /Applications/Invoko.app/Contents/Resources/IPDefault*.riv Resources/
```

---

## 10. 经验教训

1. **"贴合刘海"是架构问题，不是圆角问题**：窗口贴屏顶 + 内容去 safe-area + 在内部画刘海形状（带肩膀）。
2. **"超出"的元凶是挂在菜单栏下面的裙边**：齐平（`dockHang = 0`）才不被读成浮出的盒子。
3. **刘海开孔是非显示区**：摄像头旁边能放（翼），正中放不了；正中要内容只能放到开孔下方。
4. **宽翼藏菜单栏依赖深色背景**：浅色壁纸下会露；要绝对鲁棒得 ≤ 刘海宽（§4.5）。
5. **量，别猜**：用 `screencapture` + `CGImage` 扫像素、用 `CGWindowListCopyWindowInfo` 量自己和参照物（CodeIsland/Invoko）的真实窗口尺寸，比反复猜效率高得多。
6. **窗口尺寸与 SwiftUI 尺寸必须一致**（`modeSize` ↔ `dockWidth/dockHang`）。

---

## 11. 相关文件

| 文件 | 职责 |
|---|---|
| `Sources/App.swift` | `@main`、`AppState`、`NotchInfo`、`KeyablePanel`、`NotchHostingView`、`IslandWindowController`（窗口/拖拽/几何） |
| `Sources/IslandView.swift` | `IslandRoot` 三态视图、`NotchPanelShape`、停靠/展开/浮动渲染 |
| `Sources/RiveCloudView.swift` | Rive 渲染云，按 `mascot` 切 `.riv` |
| `Sources/CloudView.swift` | 手绘云（Rive 失败时回退） |
| `Sources/SessionReader.swift` | 多 Agent 会话聚合（Claude / Codex / Qoder） |
| `build.sh` | 直编 + 打包 RiveRuntime/.riv |

[ericjypark/codex-island]: https://github.com/ericjypark/codex-island
