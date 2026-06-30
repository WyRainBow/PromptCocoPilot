# IslandView.swift 当前实现文档

> 记录 PromptCocoPilot 刘海岛（Island）的三种状态及其尺寸规格。
> 基于 `/Users/wy770/Desktop/PromptCocoPilot/claude-ui/swift/Sources/IslandView.swift`

---

## 0. 状态概览

| 状态 | `state.presence` | 触发方式 |
|---|---|---|
| 静默 docked | `.docked` | 云朵拖到刘海附近并释放 |
| 悬浮 floating | `.floating` | 双击刘海栏，展开卡收回 |
| 展开 expanded | `.expanded` | 双击刘海栏或悬浮云，双击收起 |

另有 `dockPreview`（hover 预览）独立于 `presence`，由拖拽手势触发。

---

## 1. 静默状态 `dockedCanvas`

### 视觉描述

```
┌────────────────────────────────────────────────┐
│  [云朵]              [相机挖孔]           [●]  │  ← 与菜单栏齐平
└────────────────────────────────────────────────┘
```
- **黑底**，融入菜单栏
- 云朵在**刘海左侧**（相机左边）
- 右侧有一个小圆点（状态指示器）
- 底部圆角刚好在菜单栏线，无悬挂

### 尺寸规格

```
宽度  = notch.width + 105    (静态)
      或 notch.width + 145  (hover)

高度  = notch.height         (刘海高度，固定)
       + 0                   (dockHang 恒为 0)

肩宽  = shoulderExt = 4      (顶部左右两侧各延伸 4px，使顶边弧线融入菜单栏)

底部圆角 = 11
```

### 内部布局 `residentDocked`

| 元素 | 位置 | 尺寸（静态） | 尺寸（hover） |
|---|---|---|---|
| 云朵 `RiveCloudView` | 左侧 | `36 x 31` | `40 x 32` |
| 云朵左边距 | - | `8` | `11` |
| 相机挖孔 | 中间 | `notch.width` | `notch.width` |
| 状态圆点 | 右侧 | `6 x 6` + 阴影 | `6 x 6` + 阴影 |
| 圆点右边距 | - | `11` | `14` |

### 相关代码

```swift
private func dockHang(_ hovered: Bool) -> CGFloat { 0 }

private func dockWidth(_ hovered: Bool) -> CGFloat {
    state.notch.width + (hovered ? 145 : 105)
}
```

---

## 2. 悬浮状态 `cloudFloating`

### 视觉描述

屏幕中央一个**蓝色渐变大云朵**（带表情），双击可展开。

### 尺寸规格

```
宽度  = 140
高度  = 96
内边距 = 水平 4，垂直 5
```

### 相关代码

```swift
private var cloudFloating: some View {
    RiveCloudView()
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .frame(width: 140, height: 96)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { state.toggleExpand() }
}
```

---

## 3. 展开卡片 `expandedCanvas`

### 两种来源

| 来源 | 形状 | 尺寸 |
|---|---|---|
| 从刘海展开 (`expandedFromDock=true`) | `NotchPanelShape` + 圆角裙摆 | 宽度 `380`，高度自适应 |
| 从悬浮展开 (`expandedFromDock=false`) | `RoundedRectangle` | 宽度 `380`，高度自适应 |

### 卡片头部 `cardHeader`

```
┌────────────────────────────────────────────────┐
│  [云 38x26]  会话标签          [折叠按钮 ▲]   │
└────────────────────────────────────────────────┘
高度 = notch.height（刘海来源）或 32（悬浮来源）
```

### 卡片内容 `cardContent`

1. **会话选择器** `sessionPicker`
2. **上下文查看器** `contextViewer`
3. **草稿编辑器** — 多行文本输入，placeholder 提示
4. **增强按钮** — 调用 AI 增强草稿
5. **结果展示区** — 增强后的内容展示

---

## 4. Hover 预览 `dockingPreview`

> ⚠️ **当前实现与设计意图不符**，需要修正（见下方「问题与修正」章节）。

### 当前代码（有问题）

```swift
private var dockingPreview: some View {
    let nh = max(24, state.notch.height)
    let glowColor = Color(red: 0.55, green: 0.78, blue: 1.0)  // #8CC5FF
    return ZStack(alignment: .top) {
        // 1. 黑框
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black.opacity(0.85))
            .frame(width: 290, height: nh + 80)    // ❌ 高度延伸了 80px
            .offset(y: -8)

        // 2. 蓝色光晕填充
        Color(hex: "#8CC5FF")
            .opacity(0.18)
            .blur(radius: 18)
            .frame(width: 290, height: nh + 80)    // ❌ 同上
            .offset(y: -8)

        // 3. 蓝色描边
        RoundedRectangle(cornerRadius: 14)
            .stroke(glowColor.opacity(0.45), lineWidth: 1.2)
            .frame(width: 290, height: nh + 80)    // ❌ 同上
            .offset(y: -8)

        // 4. 云朵居中
        RiveCloudView()
            .frame(width: 46, height: 32)
            .frame(maxWidth: .infinity)
            .frame(height: nh)
    }
    .frame(maxWidth: .infinity)
    .frame(height: nh + 80)    // ❌ 同上
    .shadow(color: glowColor.opacity(0.35), radius: 12, y: 4)
}
```

### 当前尺寸（有问题）

```
宽度  = 290          (硬编码，未使用 dockWidth(true))
高度  = nh + 80      (❌ 往下延伸了 80px，不符合 Invoko 规格)
云朵  = 46 x 32      (❌ 比静态大，未放在左边)
```

---

## 5. 主题色板 `Theme`

```swift
private enum Theme {
    static let accent     = Color(red: 0.30, green: 0.56, blue: 1.0)    // #4d8eff 蓝色强调
    static let accentDeep = Color(red: 0.18, green: 0.42, blue: 0.95)    // 深蓝
    static let bodyTint   = Color(red: 0.055, green: 0.06, blue: 0.075)  // 近黑（融合刘海）
    static let surface    = Color(red: 0.11, green: 0.12, blue: 0.14)    // 深灰表面
    static let surfaceHi  = Color(red: 0.14, green: 0.15, blue: 0.17)    // 浅灰表面
    static let stroke     = Color.white.opacity(0.08)                     // 细线
    static let text       = Color(red: 0.92, green: 0.93, blue: 0.95)    // 主文字
    static let muted      = Color(red: 0.55, green: 0.58, blue: 0.64)    // 次要文字
    static let result     = Color(red: 0.62, green: 0.78, blue: 1.0)      // 结果色
}
```

---

## 6. 动效参数

| 动效 | 参数 |
|---|---|
| 云朵吸入/弹出 | `spring(response: 0.34, dampingFraction: 0.74)` |
| dockPreview 切换 | `spring(response: 0.3, dampingFraction: 0.7)` |
| notchHovered 切换 | `spring(response: 0.3, dampingFraction: 0.78)` |
| 展开卡片 | `.opacity` |

---

## 7. 问题与修正

### 问题 1：`dockingPreview` 高度错误

**现状**：高度 `nh + 80`，往下延伸 80px  
**问题**：不符合 Invoko 规格（horizontal 态高度不变）  
**应改为**：高度 `nh`（与静态 docked 一样）

### 问题 2：`dockingPreview` 宽度硬编码

**现状**：宽度硬编码 `290`  
**问题**：未使用 `dockWidth(true)` = `notch.width + 145`  
**应改为**：`dockWidth(true)`

### 问题 3：`dockingPreview` 云朵位置

**现状**：云朵居中，`46 x 32`  
**问题**：静态 docked 云朵在左侧  
**应改为**：云朵在左侧，大小与 hover 态一致 (`40 x 32`)

### 修正后的 `dockingPreview` 预期效果

```
┌────────────────────────────────────────────────┐
│  [云朵]              [相机挖孔]           [●]  │  ← 和静态 docked 一样
└────────────────────────────────────────────────┘
              ↓
        （半透明蓝色光晕伞，从框底往下扩散）
```

即：
- 黑色框：**和静态 docked 完全一样的形状**（顶边对齐刘海底，底部圆角在菜单栏线）
- 宽度：静态宽度 + 10px（`notch.width + 145`）
- 高度：**不变**（`nh`）
- 云朵：在框内左侧（`40 x 32`，与 hover 态一致）
- 光晕：**只**在框下方有半透明蓝色"伞状"光晕

---

## 8. 文件路径

```
/Users/wy770/Desktop/PromptCocoPilot/claude-ui/swift/Sources/IslandView.swift
```

相关状态管理：`App.swift` 中的 `AppState`。
