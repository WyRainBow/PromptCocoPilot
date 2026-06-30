# Desktop Notch 状态机（收束版）

## 代码入口
- `State/NotchPresentationState.swift`
  负责两件事：
  1. `visualState`：右侧 icon / 主视觉语义
  2. `expandedPresentation`：当前 notch 真正在展开什么
- `Controllers/AppController.swift`
  负责排队展示 `notchEventQueue`
- `UI/Panels/FloatingPanelController.swift`
  负责 close / `Esc` / transient hold / 几何收放
- `UI/Views/CompactBarView.swift`
  只消费共享状态，不再自己发明一套展开态语义
- `UI/Views/NotchV3StatusBar.swift`
  定义 `NotchV3RenderKind`、V3 cloud/status bar、result/task/auth/error/notification 卡片和高度测量规则

## 现在的口径
当前实现仍然不是单一 `enum` 覆盖全部，但“展开内容是谁”已经收束成单一来源：

1. `NotchPresentationState.visualState`
   决定右侧 icon 和主视觉语义
2. `NotchExpandedPresentationState.kind`
   决定当前展开内容、关闭方式、是否阻塞 queue
3. `AppController.notchEventQueue`
   决定 notification / background completion 的排队顺序
4. `CompactBarView.notchV3RenderKind`
   是 view-layer adapter：只从 `NotchPresentationState` / `PanelDisplayState` / `GenerationState` / running task store 推导 V3 视觉，不把 lab enum 搬进状态机

也就是说，现在判断 notch 的真实展开内容，优先看 `expandedPresentation`，不是再去散看 `isResultVisible / isTaskPlanVisible / isVoiceVisible`。

补充：IP Widget -> Notch 链路是 presentation mode 规则，不是新的 `NotchExpandedPresentationState.kind`。IP 正常展开时仍和 visual notch 互斥，compact panel 只作为隐藏的共享状态宿主；只有 fold cue / folded resident notch 会让 notch surface 可见。这个可见 resident notch 即使 `expandedPresentation == nil` 也保持横向正常态，不再回到独立收起终态；hover / fold cue 预览才进入更大的横向展开态。具体交互规则见 [IP Widget -> Notch Transition Design](../../../docs/ip-widget-notch-transition-design-2026-05-21.md)。

## 主视觉态
`visualState` 仍然保留，用来表达 icon 语义，不直接负责 queue。

| 主视觉态 | 典型条件 | 右侧状态位 |
|---|---|---|
| `inactive` | 无更高优先级状态 | `logo` |
| `typing` | 输入框可见，且未进入 voice / result | typing |
| `listening` | 语音转录中 | 声波 |
| `thinking` | loading 但无 stream output | `aqi.medium` |
| `running` | agent start / working 阶段 | `aqi.medium` |
| `outputting` | loading 且已有 stream output；loading 但 stream 为空不能渲染 output surface | `aqi.medium` |
| `draftComplete` | 完成且有 output | `check -> logo` |
| `screenReading` | screen reading 且完全空闲 | `eye` |
| `errorCompact` | 只有 error，没有展开详情 | warning |
| `agentBackgroundTask` | 后台任务 hover / transient peek | progress / logo |

优先级仍是：
`typing > listening > errorCompact > outputting > running > screenReading > thinking > draftComplete > agentBackgroundTask > inactive`

## 展开态总表
下面这张表才是“notch 到底正在展示什么”的主表。

| 展开态 | 进入条件 | 形态 | 关闭控件 | `Esc` | 是否阻塞 queue |
|---|---|---|---|---|---|
| `askHumanActive` | `askHuman.stage == .active` | 横向 bar + detached phone panel | phone panel 自己处理 | 挂断 | 是 |
| `askHumanIncoming` | `askHuman.stage == .incoming` | 纵向 incoming banner | 左上角 `x` | 取消 | 是 |
| `voiceCapture` | `isVoiceVisible` / recording / processing | 横向 listening bar；仅显式 message 时带下半区 | 左上角 `x` | 取消录音 | 是 |
| `queuedNotificationTaskPlan` | `userNotification != nil && isTaskPlanVisible` | 纵向 task plan + notification footer | 不走左上角 `x` | dismiss / no | 是 |
| `queuedNotification` | `userNotification != nil && isResultVisible` | 普通通知为 output 同宽的 V3 横向 notification bar；authorization/error 通知为 V3 decision/error card | 普通通知无显式控件；authorization/error 走卡片动作 | dismiss / no | 是 |
| `foregroundTaskPlan` | `isTaskPlanVisible && userNotification == nil` | V3 task list/card；不带底部 follow-up 输入框 | 左上角 `x` | 收起 task plan | 是 |
| `errorDetail` | `isErrorDetailVisible` | V3 error card，动态高度 + 最高高度 | 左上角 `x` / `Exit` | 收起 detail | 是 |
| `foregroundOutput` | `isResultVisible && resultOrigin == .foreground && hasResultSurfaceContent` | V3 output/done/result card | 左上角 collapse | 关闭 output | 是 |
| `backgroundCompletionOutput` | 显式恢复/直接展示后台结果时使用；普通后台完成不走这里 | V3 queued background output/done/result card | 左上角 collapse | 关闭 output | 是 |
| background completion reminder | 后台任务成功完成 | 横向 task list 展开态，显示 completed row；几秒后自动收起 | 无 | no | 否 |
| `routing` | loading 或 voice submit pending，且没有进入别的展开态；如果 stale `isResultVisible` 仍在但 stream 为空，也落回这里 | V3 横向 routing/running 条；`clarifying` 显示轮播 routing 文案 | 左上角 `x` | pause / cancel 当前 run | 是 |
| `backgroundHint` | 只有 hint 文案 | 纵向 hint | 左上角 `x` | 关闭 hint | 否 |
| `impactMenuDebug` | debug incoming capsule | 纵向 debug capsule | 左上角 `x` | 关闭 | 否 |
| `none` | 没有活跃展开内容 | 常规模式为空闲 compact geometry 或 hover bar；IP folded/resident mode 保持横向正常 resident handle | 无 | 无 | 否 |

## Queue 规则
这里要和“展开态优先级”分开看。

### 1. 前台展示不会被 queue 吞掉
这些态一旦正在前台显示，会先挡住 queue：
- `voiceCapture`
- `routing`
- `foregroundTaskPlan`
- `foregroundOutput`
- `askHumanIncoming`
- `askHumanActive`
- `errorDetail`

尤其是：
- `foregroundOutput` 永远先于 queued notification / background completion 被用户处理
- queued event 只能等前台展示关掉后再上
- loading/retry/follow-up 期间，如果没有真实 stream output，不允许因为旧的 `isResultVisible` 残留渲染成 output 卡；必须走 `routing`

### 2. queue 本身是 FIFO
`AppController.notchEventQueue` 目前只有两类事件：
- `userNotification`
- `backgroundCompletion`

它们都按入队顺序处理，不会并排显示。

### 3. background completion 不再“展示不了就直接消费”
现在的规则是：
- 如果此刻能展示，就进入 `backgroundCompletionOutput`
- 如果此刻被前台态挡住，只做一次 transient 提示，但事件继续留在 queue 里
- 等用户关掉当前前台态后，再真正展示这个结果

这和之前最大的区别是：
- 以前展示失败会直接 `resolve`
- 现在不会提前出队

## 关闭规则
### 统一口径
下面这些关闭动作现在都走 `FloatingPanelController` 的集中 dismiss：
- 左上角 `x`
- `Esc`
- notification footer 的 dismiss

### 关闭后的行为
- `foregroundTaskPlan`
- `foregroundOutput`
- `backgroundCompletionOutput`
- `errorDetail`
- `backgroundHint`

在常规 notch workflow 中，会先回到短暂的横向展开 hold，再自动收起。

例外：
- `askHumanActive` 不自动收起，它是 phone call 常驻态
- IP Widget resident notch 不自动收起；它是 presentation mode override，不抢占 `expandedPresentation` / queue
- `voiceCapture` 和 `routing` 仍走各自现有的 cancel / pause 链路
- completed result 上的 follow-up 会先收起 result/task surface，再进入 `routing`，避免出现“output 卡片里写 Routing...”的混合状态
- authorization 的 `Deny` / `Allow` 通过 `AuthorizationDecisionNotificationPayload` 携带 `authRequestID` / `taskID` / fallback identity；`Deny` 会取消授权等待、清 pending callback，并清理当前 auth notification

## 几何口径
`DesignTokens.NotchStateMachine` 仍保留旧 notch workflow 的基础尺寸；Notch V3 视觉路径使用 `InvokoTokens` 的 lab 对齐尺寸。`FloatingPanelController.compactBarSize(for:)` 根据当前 render kind 选择尺寸。

| 几何 | 尺寸 | 条件 |
|---|---:|---|
| legacy normal | `179 x 32` | 非 V3 常规收起态 |
| legacy horizontal normal | `263 x 34` | IP folded/resident idle handle 等旧横向正常态 |
| legacy expanded | `273 x 36` | 仍未迁入 V3 的旧展开态 |
| V3 compact | `290 x 38` | inactive / standby / compact done / compact error / running mini / long recording |
| V3 horizontal / small expanded | `300 x 38` | hover input / listening / routing / thinking / running / task plan / background running / auth / error |
| V3 wide result / notification | `480 x 38 + 内容高度`；普通 notification 只有 `480 x 38` | outputting / done / done with file / done tasks / 普通 notification |
| 纵向展开 | `bar height + 动态内容高度` | result / task plan / error detail / auth / notification / hint / incoming / 显式 voice message |
| detached panel | bar `273 x 36` + 外部分离面板 | `askHumanActive` |

## 当前代码里的关键判断
### 展开态来源
- `State/NotchPresentationState.swift`
  `expandedPresentation`

### V3 视觉 adapter
- `UI/Views/CompactBarView.swift`
  `notchV3RenderKind`
- `UI/Views/NotchV3StatusBar.swift`
  V3 render kind、卡片组件、高度/滚动阈值和 cloud image map

### queue 消费
- `Controllers/AppController.swift`
  `presentCurrentQueuedEventIfNeeded()`

### 关闭和 transient
- `UI/Panels/FloatingPanelController.swift`
  `dismissCurrentExpandedPresentation()`
  `beginDismissalHorizontalTransient()`
  `scheduleDismissalHorizontalTransientCollapse()`

## 现在最重要的几个不变量
1. notch 同时只认一个活跃展开态，不做并排覆盖。
2. queue 事件必须等当前活跃展开态处理完，再展示下一个。
3. foreground output 不能被 queued notification / background completion 抢走。
4. 普通 notification 不进入 result/detail 纵向卡片，只显示 output 同宽的 V3 横向 notification bar；authorization/error notification 才能进入 V3 decision/error card。后台任务完成不 seed `task_complete` notification，也不直接展示 output；只短暂展开 task list completed row 后自动收起。notification 不走左上角 `x`，但 `Esc` 仍然可 dismiss 当前 queued notification。
5. 允许横向常驻的例外包括 phone call 和 IP Widget resident notch；IP 正常展开态与 visual notch 互斥，IP resident notch 只存在于 fold cue / folded resident mode，静止时为横向正常态，hover / fold cue 预览 / resident pull / fold commit bounce 时为横向展开态，不是活跃展开态，也没有独立的收起终态。fold cue 预览出现时先做轻量 center scale/opacity 入场再展开；离开 fold target 或从 resident notch 往外拖出 IP 时，发光横向展开态直接整体 scale/fade 消失，不再先缩回横向正常态。resident hover 时 cloud glyph 做快速竖向弹跳。
6. task deck 任务收起 task plan 后，继续执行时保留横向 loading/running bar，不再落到 `routing`。
7. 从常规正常态进入横向态（Fn listening / Ask Human active / routing 等）走同一套 `notchGeometry` 几何动画；进入 output 时只让首次 reveal 动画，streaming 后续增高继续即时 resize，避免生成过程抖动。
8. `outputting` 只表示“正在输出真实 stream”；retry / follow-up / clarifying 不能用 output 卡承载 `Routing...` 文案。`foregroundOutput` / `backgroundCompletionOutput` 的进入条件统一由 `hasResultSurfaceContent` 把关：必须有真实 stream / 用户编辑过的 `editedText` / 仍活跃的 task deck，否则即便 `isResultVisible` 还残留为 `true`（典型场景：authorization 流里 `generationState.reset()` 把 stream 清空、`isLoading` 翻成 `false` 之后），也只允许落到 `.queuedNotification` / `.routing` / `.none`，不能把 bar 撑成 480 宽却没东西可渲染。
9. `Task completed` 只有在 running task store 没有当前任务、task plan 没有 running/pending step、且结果已 terminal done 后才显示；运行中 task row 使用 loading glyph。
10. running/background running 的展开卡宽度使用 V3 small expanded `300`，不使用 wide result `480`；只有没有真实 running task / active step 时才显示 `Running backend` 兜底文案。
11. V3 task list 只有内容明显超过可见高度才包 `ScrollView`；短列表直接 `VStack`，并保留 slack / bottom padding 避免误出滚动条。
