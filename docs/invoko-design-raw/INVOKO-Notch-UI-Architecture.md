# INVOKO 刘海 UI 完整架构（从二进制逆向扒取）

> 来源：本地 `strings` + `nm` 逆向 `/Applications/Invoko.app/Contents/MacOS/Invoko`（2026-06-30 版本）。
> 主二进制是 release 构建，Swift 自定义符号已 strip，但 **ObjC 桥接类型名 + Swift 类型元数据字符串仍可读**，共扒出 265 个 UI 类，其中刘海子系统 110+ 个。
> 本文是 [`NotchStateMachine.md`](NotchStateMachine.md) 的**组件级补充**——那篇讲状态机逻辑，本文讲「每个状态由哪些视图组件搭出来」。

---

## 一、整体命名规律

Invoko 的刘海系统叫 **"NotchV3"**（第三代重构）。命名前缀分几层：

| 前缀 | 含义 |
|------|------|
| `NotchV3*` | 第三代刘海的**视图组件**（最核心，41 个） |
| `Notch*`（无 V3） | 刘海的**状态/几何/手势/动画**基础设施（40+ 个） |
| `FloatingPanel*` | 从刘海**浮出**的独立面板 |
| `NotchWelcome*` | 首次出现时的"欢迎气泡" |
| `NotchPreview*` / `NotchPull*` | 拖拽预览 / 下拉手势 |

---

## 二、刘海状态机基础设施（`Notch*` 基础类）

这些不是视图，而是**控制刘海怎么收/怎么展、什么时机触发**的骨架。对应你项目里的 `App.swift` / `AppState`。

### 状态与阶段
- `NotchStage` / `NotchStageChanged` —— 刘海的阶段（收起/预览/展开/消失）
- `NotchPresentation` / `NotchPresentationStage` —— 当前展示什么
- `NotchExpandedPresentationKind` —— 展开时具体展开哪一种（结果/任务/欢迎…）
- `NotchVisualState` —— 右侧 icon 的视觉语义
- `NotchOptions` / `NotchOptionHandler` / `NotchOptionSelected` —— 展开后的选项配置

### 几何与吸附
- `NotchAnchorPoint` —— 锚点（吸附到刘海的参考点）
- `NotchBodyShape` —— 刘海主体形状
- `NotchSeparator` —— 分隔线
- `NotchGenerator` —— 形状生成器
- `NotchScreenReadingState` —— 屏幕阅读（无障碍）状态

### 手势（这套很值得抄）
- `NotchPullGestureOverlay` —— 下拉手势覆盖层
- `NotchPullStart/Started/Changed/Ended/Cancelled/Armed` —— 下拉手势的完整生命周期
- `NotchPullThreshold` —— 下拉到多少触发
- `NotchPullPressBegan` —— 按下开始
- `NotchPullActive` —— 正在下拉中
- `NotchTapGestureModifier` —— 单击手势
- `NotchEdgeCue` —— 边缘提示（告诉用户可以下拉）

### 动画时序（全用 ns 纳秒精度）
- `NotchBounceDelayNs` / `NotchBounceToken` —— 弹跳动画
- `NotchGlowBounceDurationNs` —— 发光弹跳时长
- `NotchDisappearFadeDurationNs` —— 消失淡出时长
- `NotchReverseGeometryDurationNs` —— 几何反向动画时长
- `NotchTransitionAppearing` / `NotchTransitionFadingOut` / `NotchTransitionGlowVisible` / `NotchTransitionTask` —— 过渡动画状态
- `NotchGlow` —— **发光效果**（你之前 commit 里的 glow 就是抄这个）

### 队列与恢复
- `NotchQueueEvent` —— 事件队列（多个事件排队展示）
- `NotchOutputRestoreTask` / `NotchOutputRestoreDelayNs` —— 输出内容恢复
- `NotchShouldRestoreInvisibleCompactPanel` —— 不可见时是否恢复紧凑面板
- `NotchSuppressesOutputPresentation` —— 抑制输出展示

### 工具栏（展开后的底部工具）
- `NotchTools` / `NotchToolsVisible` / `NotchToolsEllipsisButton` / `NotchToolsPanelChrome` —— 工具面板
- `NotchToolSurfaceSelection` —— 工具表面选择
- `NotchTrailingActionGroup` —— 尾部操作按钮组
- `NotchInlineActionButtonStyle` / `NotchInlineIconButton` / `NotchInlineIconTextButton` / `NotchLabToolButton` —— 行内按钮样式

### 其他
- `NotchIsland` —— "岛屿"容器概念（动态岛风格）
- `NotchView` —— 刘海根视图
- `NotchVisible` / `NotchPreviewActive` / `NotchBeforePreview` —— 可见性状态
- `NotchHandoff` —— 状态交接（浮云 ↔ 刘海）
- `NotchOutputAccessoryModel` / `NotchOutputContentHeightKey` —— 输出附属模型/高度

---

## 三、刘海输出内容（`NotchOutput*`）

刘海上展示的"AI 输出结果"由这套组件承载：

- `NotchOutput` / `NotchOutputView` —— 输出根视图
- `NotchOutputCardView` —— 卡片容器
- `NotchOutputBodyView` / `NotchOutputBodyStyle` —— 输出主体（文本块）
- `NotchOutputViewModel` —— 视图模型
- `NotchStreamingResultBodyView` —— **流式输出**的结果主体（边生成边显示）

---

## 四、第三代视图组件全集（`NotchV3*`，最值得抄）

这是刘海展开后**实际渲染的 UI 组件**，41 个，按功能分组：

### 🏠 容器与卡片
- `NotchV3StatusBar` —— 状态栏（最外层容器，你的代码已有对应）
- `NotchV3CardSurface` —— 卡片背景面
- `NotchV3ExpandedCard` —— 展开的完整卡片
- `NotchV3CardSeparator` —— 卡片分隔线
- `NotchV3CardPillButton` —— 胶囊按钮
- `NotchV3CircleIconButton` —— 圆形图标按钮

### ☁️ 云朵与品牌
- `NotchV3CloudImageStack` —— 云朵图层堆叠
- `NotchV3ProactiveCloud` —— **主动出现的云**（核心吉祥物）

### 🔵 主动态（Proactive = 主动提示/草稿）
"Proactive" 是 Invoko 的招牌交互——AI 主动给你推草稿/选项：
- `NotchV3ProactiveSurface` —— 主动态容器面
- `NotchV3ProactiveAmbientView` / `NotchV3ProactiveAmbientLoadingView` —— 环境态/加载态
- `NotchV3ProactiveSkeletonLine` —— 骨架屏（加载占位）
- `NotchV3ProactivePulseDot` —— 脉冲圆点
- `NotchV3ProactiveAppIcon` —— 应用图标
- `NotchV3ProactiveCloseButton` —— 关闭按钮
- `NotchV3ProactiveActionButton` / `NotchV3ProactiveActionButtonStyle` —— 主动作按钮
- `NotchV3ProactiveReplyOptionButton` —— 回复选项按钮
- `NotchV3ProactiveDraftOptionsView` —— **草稿选项视图**（多个 AI 草稿供选）

### 🎤 语音与输入
- `NotchV3VoiceControlRow` —— 语音控制行
- `NotchV3VoiceShortcutHint` —— 语音快捷键提示
- `NotchV3InputRow` —— 文本输入行
- `NotchV3LiveWaveBars` —— **实时波形条**（录音时的音浪）
- `NotchV3LongRecordingIPIndicator` —— 长录音指示器

### ⚡ 处理中状态
- `NotchV3ProcessingControlRow` —— 处理中控制行
- `NotchV3RoutingText` —— "正在路由…"文本
- `NotchV3RunningText` / `NotchV3RunningDotIcon` —— 运行中文本+圆点
- `NotchV3ThinkingText` —— "思考中"文本
- `NotchV3LoaderCircle` —— 加载圆圈
- `NotchV3AnimatedDottedText` —— 动画点状文本（"正在思考…"）
- `NotchV3BlinkingCursor` —— 闪烁光标

### ✅ 结果展示
- `NotchV3ResultCard` —— 结果卡片
- `NotchV3ResultTask` —— 任务结果
- `NotchV3ResultFile` / `NotchV3ResultFileCard` —— 文件结果
- `NotchV3ResultBodyPresentation` / `NotchV3ResultBodyTextView` —— 结果主体文本
- `NotchV3DoneStepRow` —— 完成步骤行

### 💬 跟进交互
- `NotchV3FollowUpPill` —— 跟进胶囊
- `NotchV3FollowUpVoiceRow` —— 跟进语音行
- `NotchV3ScheduleClockButton` —— 定时钟按钮（定时任务）

### 🔧 基础设施
- `NotchV3RenderKind` —— 渲染类型枚举（你代码里有）
- `NotchV3ScrollActivityObserver` / `NotchV3ScrollActivityObserver11Coordinator` —— 滚动活动观察者（嵌套 Coordinator）

---

## 五、浮出面板与欢迎气泡

### FloatingPanel（从刘海浮出的独立窗口）
- `FloatingPanel` / `FloatingPanelController` / `NonKeyPanel` —— 浮动面板容器/控制器
- `FloatingPanelCommandVoice` / `FloatingPanelCommandVoiceCoordinator` —— 命令语音浮层
- `FloatingPanelAskHumanVoiceCoordinator` —— "问人类"语音浮层
- `FloatingActive` —— 浮动激活状态

### NotchWelcome（首次/欢迎气泡）
- `NotchWelcomeBubble` / `NotchWelcomeBubbleController` —— 欢迎气泡 + 控制器
- `NotchWelcomeVisible` / `NotchWelcomeContentHeight` / `NotchWelcomeRevealDelay` —— 可见性/高度/显示延迟

### NotchPreview（拖拽预览）
- `NotchPreviewWindow` / `NotchPreviewActive` —— 预览窗口/激活态

---

## 六、对你就块项目的启示（哪些值得抄）

你现在的 `claude-ui/swift/IslandView.swift` 相当于 Invoko 的 `NotchV3StatusBar` + 少量组件。对照 Invoko，**你缺的、值得借鉴的**：

| Invoko 组件 | 你目前 | 是否值得抄 |
|------------|--------|-----------|
| `NotchPullGestureOverlay` 下拉手势 | 你有拖动 | ✅ 下拉展开比双击更符合直觉 |
| `NotchV3LiveWaveBars` 录音波形 | 无 | ⚠️ 看是否做语音 |
| `NotchV3ProactiveSkeletonLine` 骨架屏 | 无 | ✅ loading 体验好 |
| `NotchV3AnimatedDottedText` 点状文本 | 无 | ✅ "思考中…"动画，简单好看 |
| `NotchGlow` 发光 + `NotchTransitionGlowVisible` | 你已有 glow | ✅ 已对齐 |
| `NotchEdgeCue` 边缘提示 | 无 | ✅ 提示可下拉，降低学习成本 |
| `NotchQueueEvent` 事件队列 | 无 | ⚠️ 多 agent 并发时有用 |
| `NotchV3ProactiveDraftOptionsView` 多草稿 | 无 | ⚠️ 如果要多 AI 草稿对比 |

---

## 附：扒取方法（可复现）

```bash
BIN=/Applications/Invoko.app/Contents/MacOS/Invoko

# 主二进制是 release stripped，但 ObjC 桥接类型名 + Swift 元数据字符串可读：
strings "$BIN" | grep -oE "NotchV3[A-Z][a-zA-Z0-9]+" | sort -u      # 第三代组件
strings "$BIN" | grep -oE "Notch[A-Z][a-zA-Z0-9]+" | sort -u         # 全部刘海类
strings "$BIN" | grep -oE "Floating[A-Z][a-zA-Z0-9]+" | sort -u      # 浮动面板
strings "$BIN" | grep -E "^[A-Z][a-zA-Z]+(View|Controller|Panel)$" | sort -u  # 全部 UI 类

# Swift 符号（多数已 strip，只能看到系统框架引用）：
nm "$BIN" | xcrun swift-demangle | grep -i notch
```

> 限制：无法还原函数体实现逻辑（编译不可逆）。能看到「有哪些组件、叫什么、怎么分组」，但具体每个组件内部怎么画，需要配合运行时 UI 检查（Lookin/lldb）。
