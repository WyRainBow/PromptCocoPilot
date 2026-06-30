# INVOKO 刘海 UI 完整架构（从二进制逆向扒取 · 核查修正版）

> 来源：本地 `strings` 逆向 `/Applications/Invoko.app/Contents/MacOS/Invoko`（2026-06-30 版本）。
>
> **⚠️ 重要核查说明**：主二进制是 release 构建，Swift 自定义符号已完全 strip（`nm` 只能看到系统框架引用）。可读信息只有两种：
> - **Swift 类型元数据字符串**（以独立行出现，`^Notch[A-Z]` 精确匹配）
> - **属性/配置 key**（以子串形式出现在 camelCase 变量名中，如 `_proactiveNotchStage`、`ipToNotchGlowBounceDurationNs`）
>
> 本文档**严格区分**这两类——只列出可独立确认的类型名（70 个），属性/配置 key 不作为独立组件计入，但仍作为"功能推断线索"保留在说明中。
>
> 附：[`NotchStateMachine.md`](NotchStateMachine.md)（代码入口 + 状态机逻辑）| [`ExplorationVokoSalaDesign.md`](ExplorationVokoSalaDesign.md)（Voko/Sala 探索页完整设计规范）

---

## 一、整体命名规律

Invoko 的刘海系统叫 **"NotchV3"**（第三代重构）。命名前缀分几层：

| 前缀 | 含义 | 实测数量 |
|------|------|---------|
| `NotchV3*` | 第三代刘海视图组件 | 45 |
| `Notch*`（无 V3） | 刘海基础设施（类型 + 属性 key） | 26 |
| `FloatingPanel*` | 从刘海浮出的独立面板 | 5 |
| `NotchWelcome*` | 欢迎气泡 | 1 独立类型（+ 子串） |

---

## 二、实测可确认的 NotchV3* 组件全集（45 个）

这些是刘海展开后**实际渲染的 UI 组件**，均以独立类型名存在于二进制中：

### 容器与卡片
- `NotchV3StatusBar` —— 状态栏（最外层容器）
- `NotchV3CardSurface` —— 卡片背景面
- `NotchV3ExpandedCard` —— 展开的完整卡片
- `NotchV3CardSeparator` —— 卡片分隔线
- `NotchV3CardPillButton` —— 胶囊按钮
- `NotchV3CircleIconButton` —— 圆形图标按钮

### 云朵与品牌
- `NotchV3CloudImageStack` —— 云朵图层堆叠
- `NotchV3ProactiveCloud` —— **主动出现的云**（核心吉祥物）

### 主动态（Proactive = AI 主动推草稿/选项）
- `NotchV3ProactiveSurface` —— 主动态容器面
- `NotchV3ProactiveAmbientView` / `NotchV3ProactiveAmbientLoadingView` —— 环境态/加载态
- `NotchV3ProactiveSkeletonLine` —— 骨架屏（加载占位）
- `NotchV3ProactivePulseDot` —— 脉冲圆点
- `NotchV3ProactiveAppIcon` —— 应用图标
- `NotchV3ProactiveCloseButton` —— 关闭按钮
- `NotchV3ProactiveActionButton` / `NotchV3ProactiveActionButtonStyle` —— 主动作按钮
- `NotchV3ProactiveReplyOptionButton` —— 回复选项按钮
- `NotchV3ProactiveDraftOptionsView` —— **草稿选项视图**（多个 AI 草稿供选）

### 语音与输入
- `NotchV3VoiceControlRow` —— 语音控制行
- `NotchV3VoiceShortcutHint` —— 语音快捷键提示
- `NotchV3InputRow` —— 文本输入行
- `NotchV3LiveWaveBars` —— **实时波形条**（录音时的音浪）
- `NotchV3LongRecordingIPIndicator` —— 长录音指示器

### 处理中状态
- `NotchV3ProcessingControlRow` —— 处理中控制行
- `NotchV3RoutingText` —— "正在路由…"文本
- `NotchV3RunningText` / `NotchV3RunningDotIcon` —— 运行中文本+圆点
- `NotchV3ThinkingText` —— "思考中"文本
- `NotchV3LoaderCircle` —— 加载圆圈
- `NotchV3AnimatedDottedText` —— 动画点状文本（"正在思考…"）
- `NotchV3BlinkingCursor` —— 闪烁光标

### 结果展示
- `NotchV3ResultCard` —— 结果卡片
- `NotchV3ResultTask` —— 任务结果
- `NotchV3ResultFile` / `NotchV3ResultFileCard` —— 文件结果
- `NotchV3ResultBodyPresentation` / `NotchV3ResultBodyTextView` —— 结果主体文本
- `NotchV3DoneStepRow` —— 完成步骤行

### 跟进交互
- `NotchV3FollowUpPill` —— 跟进胶囊
- `NotchV3FollowUpVoiceRow` —— 跟进语音行
- `NotchV3ScheduleClockButton` —— 定时钟按钮（定时任务）

### 基础设施
- `NotchV3RenderKind` —— 渲染类型枚举
- `NotchV3ScrollActivityObserver` / `NotchV3ScrollActivityObserver11Coordinator` —— 滚动活动观察者

---

## 三、实测可确认的 Notch* 基础设施类型（26 个）

这些**以独立类型名**存在于二进制中（不含 NotchV3）：

### 视图与容器
- `NotchView` —— ❌ 实际上不存在独立类型（`FastModeNotchView` 是变体前缀，不是独立类）
- `NotchIsland` —— "岛屿"容器概念（动态岛风格，真实类型）
- `NotchOutput` —— 输出根视图（真实类型，但具体由 `NotchOutputView` 承载）
- `NotchOutputView` / `NotchOutputCardView` / `NotchOutputBodyView` —— 输出组件系列
- `NotchOutputViewModel` —— 输出视图模型
- `NotchStreamingResultBodyView` —— 流式输出主体

### 面板与手势
- `NotchPullGestureOverlay` —— 下拉手势覆盖层（真实类型）
- `NotchTapGestureModifier` —— 单击手势（真实类型）
- `NotchQueueEvent` —— 事件队列（真实类型，用于多事件排队展示）
- `NotchScreenReadingState` —— 屏幕阅读无障碍状态（真实类型）

### 样式与布局
- `NotchVisualState` —— 右侧 icon 的视觉语义（真实类型）
- `NotchExpandedPresentationKind` —— 展开类型枚举（真实类型）
- `NotchOutputBodyStyle` —— 输出主体样式（真实类型）
- `NotchOutputAccessoryModel` / `NotchOutputContentHeightKey` —— 输出附属模型/高度（真实类型）
- `NotchSeparator` —— 分隔线（真实类型）
- `NotchTransientLeftIndicator` —— 左侧瞬时指示器（真实类型）

### 工具栏
- `NotchToolsPanelChrome` —— 工具面板框架（真实类型）
- `NotchToolSurfaceSelection` —— 工具表面选择（真实类型）
- `NotchTrailingActionGroup` —— 尾部操作按钮组（真实类型）
- `NotchInlineActionButtonStyle` / `NotchInlineIconButton` / `NotchInlineIconTextButton` / `NotchLabToolButton` —— 行内按钮系列（真实类型）
- `NotchNonHorizontalExpansionRevealModifier` —— 非水平展开动画修饰符（真实类型）

### 欢迎气泡
- `NotchWelcomeBubbleController` —— 欢迎气泡控制器（真实类型，源码路径 `Invoko/NotchWelcomeBubble.swift`）

### 预览窗口
- `NotchPreviewWindow` —— 预览窗口（真实类型，源码路径 `Invoko/NotchPreviewWindow.swift`）

---

## 四、通过 Swift Mangled Symbol 确认的类型

这些类型在 `strings` 中不以独立行出现，但通过 **Swift mangled symbol（`_TtC6Invoko…`）或 ObjC 桥接名称（`Invoko.xxx`）确认存在**：

| 类型名 | 确认方式 | 说明 |
|--------|---------|------|
| `FloatingPanelController` | ObjC: `Invoko.FloatingPanelController` | 浮动面板控制器 |
| `NonKeyPanel` | mangled: `_TtC6Invoko11NonKeyPanel` | 非模态面板 |
| `FloatingPanelCommandVoice` | ObjC: `FloatingPanelCommandVoice` | 命令语音浮层 |
| `FloatingPanelCommandVoiceCoordinator` | mangled: `_TtC6Invoko36FloatingPanelCommandVoiceCoordinator` | 命令语音协调器 |
| `FloatingPanelAskHumanVoiceCoordinator` | mangled: `_TtC6Invoko37FloatingPanelAskHumanVoiceCoordinator` | "问人类"语音协调器 |
| `FloatingActive` | ObjC: `isFloatingActive` | 浮动激活状态 |
| `NotchWelcomeBubble` | ObjC + 源码: `notchWelcomeBubbleController` / `NotchWelcomeBubble.swift` | 欢迎气泡基类（子类 `NotchWelcomeBubbleController` 独立存在） |
| `NotchPreviewActive` | ObjC: `ipFoldCueNotchPreviewActive` | 预览激活状态 |
| `NotchWelcomeContentHeight` | ObjC: `ipNotchWelcomeContentHeight` | 欢迎内容高度 |
| `NotchWelcomeRevealDelay` | ObjC: `ipNotchWelcomeRevealDelay` | 欢迎显示延迟 |
| `NotchWelcomeVisible` | ObjC: `_isIPNotchWelcomeVisible` | 欢迎可见性 |

---

## 五、从属性/配置 Key 推断的功能（⚠️ 不可作为类型）

以下是从 camelCase 属性名推断出的**功能线索**，它们不是独立类型，仅作功能推断参考：

### 下拉手柄相关
从 `onNotchPullStarted`、`foldedNotchPullStart` 等属性名推断：
- 存在 `NotchPullStart` / `NotchPullStarted` 事件（回调，不是独立类型）
- 存在折叠态下的 `NotchPullStart` 行为
- 存在 `NotchPullChanged` / `NotchPullEnded` / `NotchPullCancelled` / `NotchPullArmed` 事件回调

### 动画时序配置
从 `ipToNotchBounceDelayNs`、`ipToNotchGlowBounceDurationNs` 等推断：
- 存在纳秒精度的弹跳延迟、发光弹跳时长、消失淡出时长、几何反向动画时长配置
- 存在 `NotchTransitionAppearing` / `NotchTransitionFadingOut` / `NotchTransitionGlowVisible` / `NotchTransitionTask` 等过渡状态 key

### 状态与展示
从 `ipNotchOutputRestoreTask`、`ipNotchOutputRestoreDelayNs`、`proactiveNotchShouldRestoreInvisibleCompactPanel` 等推断：
- 存在输出恢复任务和延迟配置
- 存在不可见紧凑面板的恢复策略
- 存在输出展示抑制机制

### 工具栏可见性
从 `_isNotchToolsVisible`、`onOpenNotchTools` 推断：
- 存在工具栏可见性状态（属性，不是类型）
- 存在打开工具栏的事件回调

### 发光效果
从 `HomingNotchGlow`、`ipToNotchGlowBounceDurationNs` 推断：
- 存在发光效果组件（`NotchGlow` 作为枚举值存在，但具体渲染组件形式未知）

---

## 六、对"就块"项目的启示（哪些值得抄）

你现在的 `claude-ui/swift/IslandView.swift` 相当于 Invoko 的 `NotchV3StatusBar` + 少量组件。对照 Invoko，**实测可确认值得借鉴的**：

| Invoko 组件 | 类型确认 | 你目前 | 价值 |
|------------|---------|--------|------|
| `NotchV3LiveWaveBars` 录音波形 | ✅ 真实类型 | 无 | ⚠️ 看是否做语音 |
| `NotchV3ProactiveSkeletonLine` 骨架屏 | ✅ 真实类型 | 无 | ✅ loading 体验好 |
| `NotchV3AnimatedDottedText` 点状文本 | ✅ 真实类型 | 无 | ✅ "思考中…"动画，简单好看 |
| `NotchPullGestureOverlay` 下拉手势 | ✅ 真实类型 | 你有拖动 | ✅ 下拉展开比双击更直觉 |
| `NotchV3ProactiveDraftOptionsView` 多草稿 | ✅ 真实类型 | 无 | ⚠️ 如果要多 AI 草稿对比 |
| `NotchQueueEvent` 事件队列 | ✅ 真实类型 | 无 | ⚠️ 多 agent 并发时有用 |
| `NotchV3ProactiveCloud` 云朵 | ✅ 真实类型 | 无 | ✅ 品牌感强 |
| `NotchWelcomeBubbleController` 欢迎气泡 | ✅ 真实类型 | 无 | ✅ 新用户引导 |

> 注：`NotchGlow` 在文档初版中列为核心发光组件，但实测它是一个枚举值（`HomingNotchGlow`），具体发光渲染组件的形式无法从二进制中确认。

---

## 七、扒取方法（可复现）

```bash
BIN=/Applications/Invoko.app/Contents/MacOS/Invoko

# 独立类型名（精确匹配 ^Notch 开头）：
strings "$BIN" | grep -oE "^Notch[A-Z][a-zA-Z0-9]+$" | sort -u

# NotchV3 组件：
strings "$BIN" | grep -oE "^NotchV3[A-Z][a-zA-Z0-9]+$" | sort -u

# Swift mangled symbol（类定义）：
strings "$BIN" | grep "_TtC6Invoko"

# ObjC 桥接类型名：
strings "$BIN" | grep "Invoko\.[A-Z]" | grep -vE "Sentry|QuickLook"

# 属性/回调 key（子串匹配，功能推断用）：
strings "$BIN" | grep -iE "notchPull|notchStage|notchTools" | grep -v "NotchV3" | head -30
```

> **限制**：无法还原函数体实现逻辑（编译不可逆）。只能确认类型名存在与否，看不到继承关系、协议实现、或具体渲染代码。要看每个组件内部怎么画，需要配合运行时 UI 检查（Lookin / lldb）。

---

## 附录：类名幻觉核查表

以下名称在文档初版中出现，但**经实测不属于独立类型**（仅作记录，供后续核查参考）：

| 幻觉类名 | 实际来源 |
|---------|---------|
| `NotchStage` | `_proactiveNotchStage`（属性前缀） |
| `NotchStageChanged` | `onProactiveNotchStageChanged`（回调前缀） |
| `NotchPresentation` | `ipNotchPresentationKind` 等（属性前缀） |
| `NotchPresentationStage` | 同上 |
| `NotchOptions` | `_isNotchOptions…`（属性前缀） |
| `NotchOptionHandler` | `onOpenNotchOptions`（回调前缀） |
| `NotchOptionSelected` | 同上 |
| `NotchAnchorPoint` | `notchAnchorPoint`（属性名） |
| `NotchBodyShape` | `notchBodyShape`（属性名） |
| `NotchGenerator` | `notchGenerator`（属性名） |
| `NotchEdgeCue` | `notchEdgeCue`（属性名） |
| `NotchPullThreshold` | `notchPullThreshold`（属性名） |
| `NotchPullPressBegan` | `notchPullPressBegan`（属性名） |
| `NotchPullActive` | `notchPullActive`（属性名） |
| `NotchPullStart` | `foldedNotchPullStart`（属性前缀） |
| `NotchPullStarted` | `onNotchPullStarted`（回调前缀） |
| `NotchPullChanged` | 同上 |
| `NotchPullEnded` | 同上 |
| `NotchPullCancelled` | 同上 |
| `NotchPullArmed` | 同上 |
| `NotchBounceDelayNs` | `ipToNotchBounceDelayNs`（配置 key） |
| `NotchBounceToken` | 同上 |
| `NotchGlowBounceDurationNs` | `ipToNotchGlowBounceDurationNs` |
| `NotchDisappearFadeDurationNs` | `ipToNotchDisappearFadeDurationNs` |
| `NotchReverseGeometryDurationNs` | `ipToNotchReverseGeometryDurationNs` |
| `NotchTransitionAppearing` | `_ipNotchTransitionAppearing` |
| `NotchTransitionFadingOut` | `_ipNotchTransitionFadingOut` |
| `NotchTransitionGlowVisible` | `_ipNotchTransitionGlowVisible` |
| `NotchTransitionTask` | `ipNotchTransitionTask` |
| `NotchGlow` | `HomingNotchGlow`（枚举值前缀） |
| `NotchOutputRestoreTask` | `ipNotchOutputRestoreTask` |
| `NotchOutputRestoreDelayNs` | `ipNotchOutputRestoreDelayNs` |
| `NotchShouldRestoreInvisibleCompactPanel` | `proactiveNotchShouldRestoreInvisibleCompactPanel` |
| `NotchSuppressesOutputPresentation` | （推断属性，无直接匹配） |
| `NotchTools` | `_isNotchTools…`（属性前缀） |
| `NotchToolsVisible` | `_isNotchToolsVisible` |
| `NotchToolsEllipsisButton` | `8@NotchToolsEllipsisButton`（属性 key） |
| `NotchView` | `FastModeNotchView`（类型变体前缀） |
| `NotchVisible` | `_isIPWidgetResidentNotchVisible` |
| `NotchHandoff` | `onNotchHandoff`（回调前缀） |
| `NotchBeforePreview` | `ipFoldCueHadResidentNotchBeforePreview` |
