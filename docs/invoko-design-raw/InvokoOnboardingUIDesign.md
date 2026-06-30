# Invoko Onboarding UI Design

## 1. 文档目标

这份文档只讨论 UI 设计，不重复定义 onboarding 旅程本身。  
旅程、信息架构和教学策略以 `InvokoOnboardingFlow.md` 为准；这里聚焦：

- 整体视觉方向
- 页面空间结构
- 每一屏的 UI 构成
- 组件与状态
- 动效与节奏
- 与现有桌面端视觉语言的衔接方式

目标是为后续 SwiftUI 实现提供一条明确的视觉路线，而不是停留在抽象概念层。

## 2. 核心判断

左右分栏不适合 Invoko 的 onboarding 主形态。

原因不是单纯审美，而是产品入口决定了用户的注意力路径：

- Invoko 是全局型 app，不是典型主窗口工具。
- 用户最重要的操作入口在顶部中间的 notch / floating panel。
- onboarding 应该训练用户记住“抬头去顶部叫它”，而不是“看窗口右边的说明”。

新设计应该“先定容器，再排内容”。

结论是：

- 先建立一个“Mac 设备容器”，让所有内容被范围限制住。
- 容器内部再做上下结构：上方屏幕是 Notch Theater，下方机身区是 Guidance Deck。

一句话总结：

> Invoko 的 onboarding UI 不该像“请完成设置”，  
> 而该像“被限制在一台 Mac 里的桌面排练场”。

## 3. 气质与风格

### 3.1 气质关键词

- `Calm`：不吵，不花，不像 AI 玩具
- `Capable`：像能替用户做事的工具，而不是只会对话的 bot
- `Alive`：有状态变化、结果感和轻量运动
- `Desktop-native`：尊重 macOS 的材质、留白、圆角和边框语言

### 3.2 不应该长成什么样

- 不应该像系统设置向导
- 不应该像营销官网搬进 app
- 不应该像一个纯文字的教学页
- 不应该像 dashboard 里的 feature list

### 3.3 应该长成什么样

- 一个顶部有真实入口感的舞台
- 一个底部承接解释和决策的内容面板
- 一个让用户看完就知道“以后往哪里看、按什么键、会发生什么”的空间

## 4. 总体布局框架

推荐把 onboarding 主画面做成 `Mac Device Container + Screen + Guidance Deck` 的结构。

### 推荐骨架

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Step label / Progress rail                         Skip / Close     │
├─────────────────────────────────────────────────────────────────────┤
│                 Mac Device Container (clipped)                      │
│                                                                     │
│   ┌──────────────────── Screen Area ─────────────────────────────┐  │
│   │                        Notch Theater                          │  │
│   │        simulated notch / live state / result preview           │  │
│   └───────────────────────────────────────────────────────────────┘  │
│   ┌──────────────────── Guidance Deck (in body) ─────────────────┐  │
│   │ Eyebrow / Headline / Body / Chips / CTA                        │  │
│   └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 为什么这样更适合

- 所有内容被“容器”限制，不会溢出。
- 视觉焦点始终在“设备屏幕”中间，而不是任意自由排版。
- 用户心理上更接近“真实桌面”，而不是“页面设计稿”。
- 便于把 Notch 状态作为唯一主入口复用。

### 布局比例建议

- 容器宽度 `860-980`
- 容器高度 `620-720`
- 屏幕区高度 `52-60%`
- 机身区（说明）高度 `22-28%`
- 其余用于上下留白与阴影
- 外边距 `24-32`

### 窄窗口适配

当宽度低于 `860` 时，仍然保持“单设备容器”。  
只做三件事：

- 缩短屏幕区高度
- 机身区切换为 compact 文案
- 缩减装饰元素数量

## 5. 视觉方向

### 5.1 保留现有桌面端的系统感

现有 app 的视觉语言是：

- 中性浅色背景
- `windowBackgroundColor / controlBackgroundColor`
- 微弱边框
- 简洁按钮
- 小到中号圆角

这套语言是对的，不需要推翻。  
新的 onboarding 要做的是把“notch 入口感”做强，而不是把风格做花。

### 5.2 新 onboarding 的视觉重点

以“容器 + 屏幕”的真实感为主，不做花哨特效：

- 页面外层仍然是浅色、安静、系统化背景
- 设备容器内屏幕区偏深，强调入口与状态
- 机身区偏浅，保证阅读性

### 5.3 色彩建议

以主题色为主，尽量收敛：

- `Neutral`
  - 页面背景、普通卡片、边框、正文
- `Accent`
  - 主 CTA
  - notch 状态点
  - 关键强调

### 推荐语义映射

- `Fn / Ask / Live` -> 主题色
- `Write / Action` -> 中性色 + 主题色强调
- `memo it / Collection / Remember` -> 中性色 + 主题色强调
- `Granted / Done` -> 主题色 + 轻微亮度变化

### 5.4 字体与层级

不要走营销页的大 serif 路线。  
onboarding 更适合系统字体，但标题可以更圆一点、更厚一点。

推荐层级：

- Eyebrow：`11-12 / medium`
- Headline：`30-36 / semibold`
- Body：`14-15 / regular`
- Support bullets：`12.5-13 / regular`
- CTA：沿用 `MycoButtonStyle`

### 5.5 圆角与边框

推荐统一为三级圆角：

- Top theater 大容器：`24`
- 中型卡片：`16`
- 小卡片 / chip / 状态 pill：`10-999`

边框保持非常轻，阴影只用于抬起 theater，不要给每个元素都加重影。

## 6. 页面结构规范

### 6.1 顶部 Header

顶部不该只是两根进度条。  
建议改成一个更完整但仍然克制的 header：

- 左：step label
- 中：progress rail
- 右：`Skip for now` 或 `Not now`

推荐形态：

```text
[Step 2 · Required Access]        ─────●─────○─────○─────        Skip
```

### 6.2 Screen Theater

这是每一步真正的主角。  
它不是插图区，而是一个“模拟真实产品入口”的舞台。

推荐结构：

```text
┌──────────────────────────────────────────────────────────┐
│ faint desktop backdrop                                  │
│                                                          │
│                    [ simulated notch ]                   │
│                                                          │
│      transcript / permission / mission / output          │
└──────────────────────────────────────────────────────────┘
```

关键点：

- notch 必须始终在顶部中线附近
- notch 的展开和收起要参考真实产品状态
- 背景可以暗示桌面环境，但不能喧宾夺主
- 所有内容必须被屏幕范围裁切

### 6.3 Guidance Deck in Body Area

底部 guidance deck 负责讲清楚当前这一屏的意义。

每一屏都沿用同样结构：

- Eyebrow
- Headline
- 1 段主要解释
- 2-3 条 supporting bullets
- optional trust note
- CTA 区

这样用户每一步都知道：

- 我现在在看什么
- 这一屏为什么重要
- 我下一步该做什么

## 7. 分屏 UI 设计

### Screen 1. Authorization (Step 1)

#### 目标

第一屏是“授权”，不是“欢迎”。
但体验上要让用户感觉它很顺滑，不像系统设置。

#### Screen 区域布局

- **左上角**：`Step 1 / n`
- **右上角**：进度条（短胶囊式）
- **中央**：两个授权卡（Screen Recording / Accessibility）
- 授权卡要有“流畅推进”的动效与状态切换

#### Notch 行为（循环态）

- notch 每 2 秒切换一次任务形态
- notch 下方出现一行解释当前形态是什么（例如 `Listening`, `Answering`, `Writing`, `Handing off`）
- 切换节奏：`2.0s` 常驻 + `220ms` 过渡
- 过渡方式：notch 内容淡出 40% -> 内容切换 -> 淡入 100%，位置不移动

#### 授权卡设计（丝滑）

- 左：Screen Recording
- 右：Accessibility
- 每个卡片包含：标题、短说明、状态、按钮
- 状态切换应“丝滑”：颜色、边框、图标、按钮文本同步变化
- 状态机：
  - `Idle`：浅色边框 + 中性按钮
  - `Prompting`：按钮出现轻微 pulsing
  - `Granted`：边框变主题色，左上勾，按钮变 `Enabled`
- 授权成功动画：
  - 图标从空心到勾：`160ms`
  - 边框渐变：`220ms`
  - 文案“Enabled”淡入：`140ms`

#### Guidance Deck

- 仅一句话解释：“两项授权决定 Invoko 能不能理解屏幕并在应用里行动”
- CTA：`Continue`，仅在两项授权都完成后高亮

### Screen 2. First Win (Fn QA)

#### 目标

让用户真的感觉到 Invoko 在听、在想、在出结果。

#### 过场动画

- 授权完成后，设备外观“合上”向下消失
- 动画分段：
  1. 设备屏幕轻微收缩（`scale 1.0 -> 0.96`，`180ms`）
  2. 合上动作（屏幕上边缘向下折叠，`220ms`）
  3. 整体向下消失（`y: 0 -> 40` + `opacity 1 -> 0`，`240ms`）
- 左上 `Step 1 / n` 与右上进度条**在合上同时**平滑迁移到面板左上/右上：
  - 时间：`300ms`
  - 方式：位置平移 + 轻微缩放（`1.0 -> 0.94`）
- 合上结束后，教学视图出现：`fade + slight up`（`200ms`）

#### Screen 区域

- Fn QA 场景
- 直接给一个问题提示用户提问
- notch 对应进入 `Listening -> Answering` 状态

#### Guidance Deck

- 标题：`Hold Fn. Ask naturally.`
- 说明：强调真实问题，不是 hotkey 测试
- bullets：`Press and hold / Speak normally / Release to send`

### Screen 3. Writing (Use Case 2)

#### 目标

用一个真实的输入框场景让用户感知 “写回应用”。

#### Screen 区域

- 模拟 iMessage 或邮件输入框
- 用户指令：例如“帮我回这条信息”
- Invoko 输出写进输入框

#### Guidance Deck

- 标题：`Write directly into your app.`
- 说明：强调“写完自动回填”

### Screen 4. Long Record / Hey Voko

#### 目标

展示长时间上下文 + 随时唤起。

#### Screen 区域

- 长录制状态提示
- 通过 `Hey Voko` 提一个 QA

#### Guidance Deck

- 标题：`Keep a longer thread of context.`
- 说明：先记录，之后再问

### Screen 5. Long Task + Ask Human

#### 目标

展示复杂任务 + Ask Human 触发路径，同时介绍界面。

#### Screen 区域

- 一个长任务（比如跨语言+保存+发送）
- 任务在执行中，界面展示进度
- 触发 Ask Human 时弹出说明文案

#### Guidance Deck

- 标题：`When tasks get complex, Invoko can ask you.`
- 说明：任务执行中 -> Ask Human 弹出解释

#### Ask Human 触发说明（动画细节）

- 触发瞬间：notch 变成 “waiting on you”
- 屏幕中间出现一张提示卡（`scale 0.98 -> 1.0` + `opacity 0 -> 1`，`180ms`）
- 文案建议：`Invoko needs one detail. It can call or message you to unblock the task.`
- 卡片停留 `2.5s` 后弱化为角落提示条

## 8. 组件系统

### 8.1 Progress Rail

用于整个流程顶部。

要求：

- 比当前两根 capsule 更可读
- 能显示当前 step label
- 支持 `done / current / upcoming`

### 8.2 Guidance Deck

底部统一 narrative 容器。

包含：

- eyebrow
- headline
- body
- bullets
- optional trust note
- CTA row

### 8.3 Device Container

外层设备容器。

要求：

- 清晰边界与圆角
- 内容必须裁切在容器内
- 容器内再分为屏幕区和机身区

### 8.4 Simulated Notch Shell

这是整个 onboarding 的核心品牌组件。

要求：

- 尺寸比例接近真实 notch
- 支持 collapsed / listening / working / result / authorization / ask human
- 形状更接近 Dynamic Island，而不是纯矩形
- 不能只是静态黑条

### 8.5 Capability Card

用于权限页。

状态：

- default
- hover
- prompting
- granted

### 8.6 Mission Card

用于 `Ask / Write / Save`。

内容：

- title
- shortcut label
- short descriptor
- CTA
- completion state

### 8.7 Result Preview Card

用于 First Win 和 Guided Cases。

内容：

- input
- output
- result type

### 8.8 Destination Card

用于 `History` 和 `Collection`。

内容：

- title
- stored items
- why it matters

## 9. 动效系统

动效应该服务“状态感”，不要服务“炫技”。

### 9.1 页面切换

- 方向明确的滑入滑出
- `220-280ms`
- 用轻弹簧，不要飘

### 9.2 元素进入

- 容器整体：轻微缩放 + fade
- 屏幕内容：轻微上浮 + fade
- Guidance Deck：`y +12 -> 0` + `opacity 0 -> 1`（`220ms`）

### 9.3 关键微交互

- 权限 granted：边框和图标同步切换
- `Fn` 按下：notch 激活，keycap 变亮，waveform 启动
- mission card hover：轻微抬升，不超过 `1.01`
- case completed：绿色勾选，不要真撒花
- notch 展开：保持顶部锚点稳定，不要像 modal 一样从中间长出来
- notch 形态切换：内容淡出 40% + 高度微调（`<= 6px`）

### 9.4 减少动效模式

要遵守 macOS reduce motion：

- 去掉 scale
- 保留 opacity
- 保留状态颜色变化

## 10. 与现有桌面端的一致性要求

这套 UI 需要明显比当前 onboarding 更丰富，但不能像另一个产品。

### 必须保留

- 当前 app 的浅色主背景
- 当前按钮风格和交互节奏
- 当前品牌 logo 作为入口识别
- 当前圆角和边框语言
- 当前 notch / compact panel 的品牌空间关系

### 可以加强

- 更强的上下空间结构
- 更深的 notch theater 容器
- 更明确的状态颜色
- 更完整的 progress rail
- 更真实的结果预览

### 不建议引入

- 官网式大面积液态玻璃
- 过重纹理背景
- 彩虹式多色系统
- 过多插画

## 11. 首页承接 UI

既然 case by case 教学是正确方向，首页不应该再只是统计面板。

推荐在 onboarding 结束后，首页增加一块 `Mission Strip`：

```text
[ Ask with Fn ]   [ Write into app ]   [ Save with memo it ]
```

要求：

- 每张卡保留小说明
- 已完成的卡显示 `Done`
- 下一张推荐卡始终更醒目

这样 onboarding 和真实产品不会割裂。

## 12. 实现建议

推荐把现在的单视图拆成一组更明确的 onboarding 组件：

- `DesktopOnboardingChrome`
- `DesktopOnboardingGuidanceDeck`
- `DesktopOnboardingNotchTheater`
- `DesktopOnboardingSimulatedNotch`
- `DesktopOnboardingWelcomeTheater`
- `DesktopOnboardingPermissionTheater`
- `DesktopOnboardingFirstWinTheater`
- `DesktopOnboardingMissionTheater`
- `DesktopOnboardingDestinationTheater`
- `DesktopOnboardingOneMoreThingTheater`

同时建议补一组 onboarding 专用 token：

- `OnboardingLayout`
- `OnboardingColorRole`
- `OnboardingTheaterStyle`
- `OnboardingMotion`

这样不会把 onboarding 的复杂度继续塞回一个超大的 `DesktopOnboardingFlowView`。

## 13. 最终 UI 判断

如果把整份文档压成一句话，那就是：

> 上面负责让用户记住入口，  
> 下面负责让用户理解当前步骤，  
> 整个 onboarding 负责让用户相信 Invoko 真的会在顶部那条 notch 里活起来。
