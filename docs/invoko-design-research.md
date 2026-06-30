# Invoko 设计与前端调研

> 目标：把 Invoko 的前端设计与视觉语言"抄"到 PromptCocoPilot。
> 本文档是抄写前的完整调研，覆盖：设计哲学、设计 token、网站前端结构、
> 桌面 notch 状态机、onboarding，以及落到本项目的可操作清单。

---

## 0. 一句话结论

Invoko 的设计可以概括为：

- **桌面端（app）**：浅色雾面 + 陶瓷感，"两房间世界观"——Voko（角色舞台，中央圆 + 气泡）和 Sala（工作年鉴，编辑排版 + 图表）。强调留白、短软阴影、克制动效。
- **官网（invoko.ai）**：深色 navy hero（`#0b1120`）+ 浅色 section，Instrument Serif 大标题配 DM Sans 正文，hero 里用 IP mark（notch 图标）+ app icon 轨道做品牌动效。
- **核心入口**：刘海 notch（Dynamic Island 形态），不是聊天窗口。

PromptCocoPilot 现在的 Swift 岛（`claude-ui/swift`）是深色 navy + 蓝色 accent 的刘海卡片。要"抄 Invoko"，方向上有两条：
1. 抄 **官网**的深色 navy + serif 大字 + app icon 轨道（偏营销/品牌感）。
2. 抄 **app**的浅色雾面 + 陶瓷感 + 状态机（偏产品/工具感）。

两者气质不同，下文分开讲。

---

## 1. 信息来源

| 来源 | 位置 | 可信度 |
|---|---|---|
| 设计系统文档（主） | `/Applications/Invoko.app/Contents/Resources/ExplorationVokoSalaDesign.md`（860 行） | 内部原文，最高 |
| Onboarding UI 文档 | `…/Resources/InvokoOnboardingUIDesign.md`（560 行） | 内部原文 |
| Onboarding 流程文档 | `…/Resources/InvokoOnboardingFlow.md`（682 行） | 内部原文 |
| Notch 状态机文档 | `…/Resources/NotchStateMachine.md`（176 行） | 内部原文 |
| 官网前端 | `https://invoko.ai`（Next.js，缓存于 `/tmp/invoko_ai.html`） | 实际渲染 |
| 安装的 app | `/Applications/Invoko.app`，v0.2.5 (build 80)，bundleID `com.tryclico.invoko` | 二进制 |

意外发现：Invoko 把完整内部设计文档直接打进 app bundle 的 Resources 里，这是抄写的金矿。

---

## 2. 产品定位与设计哲学

### 2.1 定位

> Invoko is a voice agent that acts for you on your Mac.

- 全局型 app（`LSUIElement=true`，无 Dock 图标），核心入口是顶部 notch + 全局快捷键（`Fn` 按住说话）。
- 不是聊天机器人，不是 dashboard，不是系统设置向导。

### 2.2 设计哲学（文档原文精神）

- "一个应用内世界观中的两个房间"：Voko 是有舞台感、会回应你的房间；Sala 是冷静的工作年鉴。
- 基底不是纯白，而是**轻微偏暖的雾面中性色**。
- 不大面积用玻璃，不做发光描边，不做赛博紫蓝。
- 阴影要**短、软、低对比**，像纸张和物件浮在桌面上，而不是悬浮卡片。
- 所有模块都要"留白和静气"，不要把 detail 塞满。

### 2.3 明确的反模式（直接抄不要踩的坑）

- 大面积毛玻璃卡片堆满屏幕
- 紫蓝霓虹渐变
- 到处发光的圆环和波纹
- 每个模块都是同一种圆角卡片
- 看起来像 AI 生成的通用"智能助手面板"
- 不能把 Voko 做成普通 chat layout 加一个圆头像
- 不能为了"AI 感"而滥用发光、波形、渐变

---

## 3. 设计系统 Token（可直接抄）

> 桌面端设计语言。这是抄 app 视觉的核心。

### 3.1 颜色

**共享色板**（两个房间通用）：

| 语义 | 色值 |
|---|---|
| 背景底色 | `#F4F1EA`（轻微偏暖的雾面中性） |
| 一级文字 | `#201C18` |
| 二级文字 | `#6A625A` |
| 分隔线 | `#D8D0C7` |
| 高亮暖色 | `#D47A5A` |
| 高亮雾蓝 | `#7C93A8` |
| 高亮橄榄 | `#7F8A63` |

**Voko 专用**（角色舞台）：

| 语义 | 色值 |
|---|---|
| 中央舞台光晕 | `#F7E7D7` |
| 角色核心圆 | `#F3EEE7` |
| 核心描边 | `#D9CDBE` |
| 主强调 | `#C96C4A` |
| 记忆气泡 | `#E6EFE7` |
| 历史气泡 | `#EAE4F3` |
| 任务气泡 | `#F4E2D5` |

**Sala 专用**（总结画像，更纸感/石墨）：

| 语义 | 色值 |
|---|---|
| 纸面背景 | `#F6F2EB` |
| 模块底色 | `#F0EBE2` |
| 墨色文字 | `#1F1B17` |
| 次要说明 | `#72685F` |
| 图表蓝灰 | `#7A8EA1` |
| 图表鼠尾草绿 | `#899377` |
| 图表陶土色 | `#B97A5B` |
| 结构线 | `#D9D1C8` |

气质：暖米 / 雾蓝 / 陶土 / 鼠尾草绿，非常克制，没有任何荧光。

### 3.2 字体

**桌面 app**：沿用 macOS `SF Pro` 体系，但"不要全靠默认字重堆层级"。标题更像"编辑标题"。

**官网（重要修正）**：
CSS 变量名叫 `--font-dm-sans`（91 次）和 `--font-instrument-serif`（33 次），但这是**遗留命名**。`<head>` 里实际 preload 的字体文件是：

| 变量名（遗留） | 实际字体文件 | 用途 |
|---|---|---|
| `--font-dm-sans` | **Neue Montreal**（Regular + Medium，`.otf`） | 正文 / UI（大标题除外） |
| `--font-instrument-serif` | **Aime Light**（`.woff2`） | section 大标题（serif 衬线） |
| `--font-inter` | Inter（系统兜底） | 次要 |

所以官网的真实字体组合是 **Neue Montreal（无衬线）+ Aime（衬线展示字）**。大标题用 Aime serif、`font-weight:400`、`letter-spacing:-0.025em`、`line-height:1.05`；正文用 Neue Montreal。

> 抄官网时：display 字体找 Aime 或近似的现代衬线（如 Tiempos / Newsreader），body 用 Neue Montreal 或 Geist。

### 3.3 字号层级（桌面 app）

| 层级 | 建议 |
|---|---|
| 页面标题 | `28-34 / semibold` |
| 模块标题 | `17-20 / semibold` |
| 强调数字 | `30-44 / medium or semibold` |
| 正文 | `13-15 / regular` |
| 辅助注释 | `11-12 / medium` |

官网大标题用 `clamp(44px, 5.5vw, 72px)`，hero H1 `line-height:0.98`、`letter-spacing:-0.035em`。

### 3.4 间距 token

| token | 值 |
|---|---|
| `space-1` | `6` |
| `space-2` | `10` |
| `space-3` | `14` |
| `space-4` | `20` |
| `space-5` | `28` |
| `space-6` | `40` |
| `space-7` | `56` |

### 3.5 圆角与边框

| 元素 | 圆角 |
|---|---|
| 小 chip | `12` |
| 普通 bubble / 小模块 | `18-20` |
| 大面板 | `26-32` |
| 圆形角色核心 | `999` |

边框统一细线，不超过 `1px`。Onboarding 大容器圆角 `24`，中型卡片 `16`，chip/pill `10-999`。

### 3.6 动效

- 时长主档：`180ms / 240ms / 420ms`。
- easing：优先 `easeOut` 和 `spring(response: 0.35-0.5, dampingFraction: 0.8-0.9)`。
- 气质："像呼吸、漂浮、收音、排版切换，而不是炫目 UI 特效"。任何持续动画都必须轻，不抢内容。
- 遵守 macOS reduce motion：去 scale，保留 opacity 和状态色变化。

### 3.7 布局宽度档位（以 detail 可用宽度为准）

| 档位 | detail 宽度 | 内容最大宽度 |
|---|---|---|
| Wide | `>= 1100` | `1160` |
| Standard | `860-1099` | `980` |
| Compact | `640-859` | `760` |

左右内容边距 `32`（紧时 `24`），模块主间距 `24/28/40`，首屏顶部留 `32-40`。

---

## 4. 官网 invoko.ai 前端结构

### 4.1 技术

Next.js。无内联 CSS 变量定义（`:root` 在外部 CSS），根变量 `--button-bg` / `--button-radius` / `--button-shadow` 未内联，需从渲染态推断。`--button-radius` 被按钮统一引用。

### 4.2 配色统计（HTML 内 hex 出现次数）

| 色值 | 次数 | 角色 |
|---|---|---|
| `#0b1120` | 39 | hero 深色 navy（占主导） |
| `#0f0d0c` | 22 | 深 section 文字/底 |
| `#f4f6fa` | 16 | 浅 section 背景 |
| `#0f308a` | 9 | 蓝色（按钮/强调候选） |
| `#86868b` | 6 | 次要灰文字 |
| `#1d1d1f` | 4 | Apple 式深灰标题 |
| `#ff6154` | 3 | 红色 accent（macOS 关闭钮色系） |

气质：**深色 navy hero + 极浅冷灰 section**，与桌面 app 的暖米色完全相反——官网更"科技/品牌"，app 更"陶瓷/纸感"。

### 4.3 Section 顺序（按标题出现）

1. **Hero**：H1 `Say it. Invoko gets it done.`（深 navy `#0b1120`，`line-height:0.98`）
2. `An AI helper beside you.`
3. `Ask without opening a chat.`
4. `Act from the context already on screen.`
5. `Let the task keep moving across apps.`
6. `Privacy in Invoko you're in control`
7. `What beta users are saying.`（评价区）
8. `Beta access`（CTA）
9. `Ask & Answered`
10. `Start working with your voice.`
11. `Curious if Invoko is right for you?`（FAQ）
12. Footer（Pricing / Privacy / Data security / FAQ / Contact / hey@invoko.ai）

### 4.4 Hero 的品牌动效（抄点）

H1 里把 `Invok[圆圈]o` 的 `o` 换成了一个 **IP mark**（notch 图标容器），里面：
- 一个云形 glyph（`ip-default-thinking.png` / `ip-inactive-sleep.png`）
- 围绕它的一圈 **app icon 轨道**：Gmail / Chrome / YouTube / GitHub / Notion / Calendar / Drive / Docs / Sheets / Figma / Discord / Linear（用 `cdn.simpleicons.org` 的单色图标）
- 三个**能力轨道节点**：voice（mic-vocal）、screen（monitor）、accessibility（人形图标）
- 一个 `hero-nudge-note`（nudge it 贴纸）

这是把"Invoko 能跨这些 app 行动 + 具备语音/屏幕/辅助功能三种能力"做成了一个微型动效品牌符号。**这是官网最值得抄的一个细节。**

### 4.5 按钮样式

- 主按钮：`min-height:44-58px`、`padding 0 28-40px`、`border-radius: var(--button-radius)`、`background: var(--button-bg)`、白字、`box-shadow: var(--button-shadow)`、`text-shadow:0 1px 1px rgba(0,0,0,0.16)`、`letter-spacing:0.01em`、`font-weight:500`。
- 过渡统一 `transition: background 0.18s, opacity 0.18s, transform 0.18s, box-shadow 0.18s`。
- 次级按钮：`rgba(255,255,255,0.84)` 半透明白底 + `1px solid rgba(11,17,32,0.08)` + 浅阴影。
- eyebrow 小标签：`font-size:10-12px`、`letter-spacing:0.06-0.2em`、`text-transform:uppercase`、低透明度灰。

---

## 5. 桌面核心：Notch 状态机

> 这是 PromptCocoPilot 岛最该学的部分——Invoko 的 notch 是整个产品的入口和状态中枢。

### 5.1 主视觉态（visualState，决定右侧 icon 语义）

优先级：`typing > listening > errorCompact > outputting > running > screenReading > thinking > draftComplete > agentBackgroundTask > inactive`

| 态 | 右侧状态位 |
|---|---|
| inactive | logo |
| typing | typing |
| listening | 声波 |
| thinking / running / outputting | `aqi.medium` |
| draftComplete | check → logo |
| screenReading | eye |
| errorCompact | warning |
| agentBackgroundTask | progress / logo |

### 5.2 展开态（expandedPresentation，单一来源）

单一不变量：**notch 同时只认一个活跃展开态**，不做并排覆盖。queue 事件 FIFO，必须等当前活跃态处理完才展示下一个。前台态（voiceCapture / routing / foregroundTaskPlan / foregroundOutput / askHuman / errorDetail）会挡住 queue。

### 5.3 几何尺寸（Notch V3）

| 形态 | 尺寸 |
|---|---|
| V3 compact（收起） | `290 x 38` |
| V3 horizontal / 小展开（listening/routing/thinking/running/task） | `300 x 38` |
| V3 wide result / notification | `480 x 38 + 内容高度` |
| legacy normal | `179 x 32` |
| 进入 output 只让首次 reveal 动画，streaming 后续即时 resize 避免抖动 | — |

---

## 6. Onboarding 设计

### 6.1 结构：Mac Device Container

不做左右分栏（那是设置向导味）。而是 `Mac Device Container + Screen + Guidance Deck`：

```
[Step label / Progress rail            Skip]
┌─────────────────────────────────────────┐
│         Mac Device Container (clipped)  │
│  ┌──────── Screen Area ──────────────┐  │
│  │        Notch Theater              │  │
│  │  simulated notch / state / result │  │
│  └───────────────────────────────────┘  │
│  ┌──────── Guidance Deck ────────────┐  │
│  │ Eyebrow / Headline / Body / CTA   │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

- 容器宽 `860-980`，高 `620-720`，屏幕区占 `52-60%`，机身区 `22-28%`。
- 核心：**notch 必须始终在顶部中线附近**，展开/收起参考真实产品状态。背景暗示桌面但不喧宾夺主，所有内容被屏幕范围裁切。

### 6.2 流程（6 步，前 3 步硬性）

1. **Welcome**：先定义产品，不直接要权限。`Invoko is a voice agent that acts for you.`
2. **Required Access**：Screen Recording + Accessibility，讲成"能力开关"（`See what you're looking at` / `Act inside other apps`）。麦克风不放这里，留到 Fn 首用时即时请求。
3. **First Win**：用 `Fn` 完成第一次真实提问（不是热键测试）。`Hold Fn. Ask naturally.`
4. **Guided Cases**：Ask / Write / Save 三张 mission card，按场景教学。
5. **Where Things Go**：History（正式任务）vs Collection（保存的记忆）。
6. **One More Thing**：Ask Human（卡住时主动 call/message）+ Long Record（Hey Voko）。

### 6.3 动效原则

服务"状态感"不服务炫技：页面切换 `220-280ms` 轻弹簧；元素进入 `y+12→0 + opacity`；权限 granted 边框/图标同步切换；notch 展开保持顶部锚点稳定，不从中间长出来。

---

## 7. Voko vs Sala 对比（抄两房间的关键是做出反差）

| 维度 | Voko（角色舞台） | Sala（总结画像） |
|---|---|---|
| 构图 | 中央聚焦、环绕式 | 编辑排版、块面式 |
| 主角 | 人物核心圆（直径 `172-208`） | 今日画像与图表 |
| 情绪 | 温和、亲近、会回应 | 冷静、总结、会判断 |
| 动效 | 呼吸、漂浮、收音 | 渐显、描边、稳定 |
| 材质 | 哑光陶瓷 + 纸片 bubble | 纸面年鉴 + 细线图表 |
| 阅读方式 | 像在和谁说话 | 像在翻今天的记录册 |

Voko 中央圆 = 实体圆 + 很轻的外晕 + 一层状态环，材质像"陶瓷/石膏"。bubble 有 S/M/L 三档尺寸差（`96-120 / 132-164 / 180-220`），不是统一胶囊，固定六个方位，允许 5-8s 周期的轻微漂移。Sala 用 12 列逻辑网格但不画栅格感，hero `1-7`、app share `8-12`，Ability Hexagon 六轴固定（Focus/Output/Exploration/Recall/Follow-through/Recovery）。

---

## 8. 落到 PromptCocoPilot 的可抄写要点

### 8.1 现状对比

PromptCocoPilot 的 Swift 岛（`claude-ui/swift/Sources/IslandView.swift`）现在：
- **深色** navy：`bodyTint #0E0F13`、`surface #1C1F24`、`accent #4D8EFF`（蓝）。
- 蓝色是唯一 accent，结果区用 `#9EC7FF` 浅蓝。
- 单一卡片：刘海条 + 展开卡片（会话选择 / 上下文折叠 / 草稿 / 增强 / 结果）。
- 圆角 `11-18`，阴影偏强（`shadow radius 8-14`）。

这恰好踩了 Invoko 反模式里的"赛博蓝紫"和"发光阴影"——Invoko 的 app 端是**浅色暖米 + 陶瓷感**，完全相反。

### 8.2 两个方向

**方向 A：抄官网（深色 navy + serif）**——改动小，气质偏品牌/科技。
- 主色保留深 navy，但把蓝 accent 换成官网的暖红/陶土（`#C96C4A` 或 `#D47A5A`）。
- 大标题上 Aime/serif，正文 Neue Montreal。
- 在 hero/卡片里复刻 IP mark + app icon 轨道动效。

**方向 B：抄 app（浅色暖米 + 陶瓷）**——改动大，气质偏产品/工具，更接近 Invoko 的真实使用态。
- 整个岛翻成浅色：背景 `#F4F1EA`，文字 `#201C18`/`#6A625A`，accent `#C96C4A`。
- 卡片用 `space-1..7` token、`18-20` 圆角、`1px` 细边框、短软阴影。
- 把单一卡片拆成 Voko 式的"中央元素 + 气泡"，或至少引入气泡式信息排布。

### 8.3 具体改动清单（按优先级）

1. **颜色 token 重写**（`IslandView.swift` 的 `Theme` enum）：换成 Invoko 共享色板。如果是刘海停靠（黑底融合），保留顶部纯黑渐变，但下半 + 展开卡换暖米。
2. **accent 收敛**：去掉多色 agent badge（橙/绿/紫），统一用一个暖 accent，agent 区分用形状/文字而非彩虹色——这正是 Invoko 明确反对的"彩虹式多色系统"。
3. **阴影/边框**：把 `shadow radius` 降到 `3-6`、`y 2-3`，边框统一 `1px` 低透明度。去掉发光阴影（`accent.opacity(0.35) shadow`）。
4. **圆角**：小元素 `12`、卡片 `18-20`，统一。
5. **间距**：引入 `space-1..7` 常量，替换现有的魔法数字（`14`/`13`/`6` 散落值）。
6. **动效**：状态切换用 `180/240ms + easeOut`，弹簧 `response 0.4 damping 0.85`。
7. **进阶（可选）**：把展开卡片从"表单堆叠"重构为 Voko 式中央元素 + 气泡；引入 notch 状态机（visualState 单一来源 + 展开态互斥）。

### 8.4 资产可复用

- `/Applications/Invoko.app/Contents/Resources/*.riv`（14 个 Rive 动画：Listening/Thinking/Idle/Waveform/Sparkle/Done/Error…）——notch 状态动画可直接借鉴形态（注意版权）。
- `Assets.car`（45MB）含全部 icon/raster，可用 `assetutil` 提取查看。
- 官网 `/images/ip-default-thinking.png`、`/images/hero-nudge-it.webp`——IP mark 品牌 glyph。

### 8.5 风险

- 字体版权：Aime / Neue Montreal 都是付费字体，抄官网需购买或找开源替代（Aime→Newsreader/Tiempos，Neue Montreal→Inter/Geist）。
- `.riv` 和 `Assets.car` 内资产受版权保护，"抄设计语言"可以，直接搬资产不行。
- Invoko app 端是浅色、本岛是深色刘海融合——如果保留刘海黑底融合，浅色化只能在展开卡内做，顶部条仍需黑。

---

## 附：关键路径速查

- 设计文档：`/Applications/Invoko.app/Contents/Resources/{ExplorationVokoSalaDesign,InvokoOnboardingUIDesign,InvokoOnboardingFlow,NotchStateMachine}.md`
- 官网缓存：`/tmp/invoko_ai.html`
- 本项目岛 UI：`/Users/mac/开源工具/PromptCocoPilot/claude-ui/swift/Sources/IslandView.swift`
- 本项目状态/窗口：`/Users/mac/开源工具/PromptCocoPilot/claude-ui/swift/Sources/App.swift`
