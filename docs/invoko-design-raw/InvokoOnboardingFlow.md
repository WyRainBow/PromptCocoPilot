# Invoko Onboarding Flow

> 2026-04-09 更新：文中所有 `Option / typing` 与 `Ask Human message` 相关描述已不再代表当前产品方向。当前核心入口只保留 `Fn` 语音与 `memo`，`Ask Human` 也只保留 call 形态；后续若继续沿用此文，需要先移除旧的打字/发消息链路描述。

## 1. 文档目的

为 Invoko 设计一条新的 onboarding 流程，帮助新用户在第一次打开产品时快速理解：

1. Invoko 是什么。
2. 为什么它需要系统权限。
3. 最快的上手方式是什么。
4. 任务和记忆最后会去哪里。
5. 哪些能力是核心路径，哪些能力是后续发现。

这份文档面向产品、设计和客户端实现，目标不是只写欢迎页，而是定义一条完整的首次体验路径。

## 2. 当前产品理解

基于官网、现有桌面端实现和这轮对话，目前对 Invoko 的定义如下：

- Invoko 是一个常驻 macOS 的 `voice agent that acts for you`。
- 核心入口不是聊天窗口，而是全局快捷键。
- `Fn`：按住说话，松开提交。适合提问、下指令、让 Agent 直接干活。
- `Option`：唤起打字，回车后走同样的 agent 流程。适合不方便说话时使用。
- 任务结果可能有三种走向：
  - 直接回答。
  - 生成内容并回填到当前输入位置。
  - 将重任务 hand off 到后台并并行处理。
- `memo it`：`double Shift`，基于当前屏幕内容做快速保存。
- `long record`：长时间收集音频和屏幕信息，之后可用 `Hey Voko` 唤起。
- `History`：存正式任务线程。
- `Collection`：存 memo 和 long record 这类记忆型内容。
- `Ask Human`：当 Agent 卡住或需要确认时，可以主动给用户打电话或发消息，而不是静默等待。

## 3. Onboarding 北极星

新用户在第一次完成 onboarding 后，应该形成下面这个 mental model：

> Invoko 是一个在 Mac 上随叫随到的行动型语音助手。  
> 我按住 `Fn` 说一句，它就会结合我当前屏幕和上下文帮我做事。  
> 它需要录屏权限来理解我在看什么，需要辅助功能权限来在别的 app 里操作。  
> 正式任务会进入 `History`，想保存的内容会进入 `Collection`。

这条 onboarding 的真正成功标准不是“用户看完了介绍”，而是：

1. 用户完成两个硬性权限授权。
2. 用户真的用 `Fn` 完成一次提问。
3. 用户知道 `Option` 和 `memo it` 的存在，但不会在首轮被塞太多信息。

## 4. 设计原则

### 4.1 先建立产品模型，再讲权限

现在的桌面端 onboarding 太像 setup，而不像 onboarding。  
它直接让用户授权，但没有先回答“Invoko 到底是什么”。

权限不是孤立设置项，而是产品承诺的一部分：

- 录屏权限 = 让 Invoko 理解你此刻在看什么。
- 辅助功能权限 = 让 Invoko 能在别的 app 里替你完成动作。

所以在用户授权前，必须先给出一句足够清晰的产品定义。

### 4.2 首个 aha moment 必须是 `Fn`

首轮 onboarding 不应该把用户教育成“一个功能列表的读者”，而要让他真的完成一次动作。  
Invoko 的第一成功动作应该是：

> 按住 `Fn`，正常说一句需求，松开后看到 Agent 开始工作并给出结果。

这是最符合产品定位的瞬间，也是最容易让用户理解“voice agent that acts for you”的方式。

### 4.3 `Option` 和 `memo it` 是第二层，不应抢第一层注意力

`Option` 和 `memo it` 都重要，但都不应该和 `Fn` 抢首个 aha。

推荐策略：

- 首轮主路径只强推 `Fn`。
- `Option` 和 `memo it` 在 `Fn` 成功后，用一屏快速地图介绍。
- 用户可以选择试其中一个；另一个则轻量带过。

### 4.4 `Ask Human` 和 `long record` 放入 “one more thing”

这两个能力很有特色，但不是首轮成功的必要路径。

- `Ask Human` 是高记忆点功能，适合放在最后作为差异化亮点。
- `long record + Hey Voko` 也适合放在最后，作为“进阶模式”介绍。

这样可以保证 onboarding 的主路径短、清晰、结果导向。

### 4.5 case by case 教学更适合 Invoko，但不该取代主路径

是的，Invoko 比起“按功能列表教学”，更适合按真实任务场景来教。

原因很简单：

- 用户要学的不是按钮位置，而是“遇到这个工作场景时，我该怎么叫 Invoko”。
- Invoko 的能力天然是任务导向，不是页面导向。
- `Fn`、`Option`、`memo it`、后台任务、`Ask Human` 本身就是不同 case 下的表现形式。

但不建议把整个 onboarding 一开始就拆成 case 入口。  
原因是第一次打开时，用户还没有稳定的 mental model，过早分流会增加理解成本。

更适合 Invoko 的结构是：

1. 用一条很短的主路径建立产品定义。
2. 让用户完成一次 `Fn` 的 first win。
3. 再进入 case by case 的渐进式教学。

换句话说：

> 主路径负责让用户“先会用”。  
> case 教学负责让用户“越用越懂”。

## 5. 推荐信息架构

推荐把 Invoko 的首次体验分成 `3 个核心步骤 + 3 个渐进教学层`：

1. Welcome：建立产品模型。
2. Required Access：完成录屏和辅助功能授权。
3. First Win：用 `Fn` 完成第一次真实提问。
4. Guided Cases：按场景继续教学 `Ask / Write / Save`。
5. Where Things Go：理解 `History`、`Collection` 和后台任务。
6. One More Thing：介绍 `Ask Human` 和 `long record`。

其中：

- `1-3` 是必须完成的核心路径。
- `4-6` 是渐进教学层，可以做成一组连续页面，也可以做成 onboarding 结束后的任务卡。
- 如果担心首轮过长，可以允许用户在完成 `Fn` first win 后直接进入产品，再由首页继续承接 `4-6`。

## 6. 分步流程设计

### Step 1. Welcome

#### 目标

先把 Invoko 定义清楚，让用户知道它不是普通聊天工具。

#### 推荐标题

`Invoko is a voice agent that acts for you.`

#### 推荐副标题

`Hold Fn, say what you need, and Invoko can answer, write, or keep heavier work running in the background.`

#### 建议内容结构

- 一句主定义。
- 三个结果型能力，不要列一堆功能名：
  - `Ask`：直接问，直接得到结果。
  - `Write`：让它生成内容并写回当前工作流。
  - `Hand off`：复杂任务丢给后台继续跑。
- 一个非常短的承诺：
  - `Invoko works from your screen and your intent, not from a blank chat box.`

#### CTA

`Set up Invoko`

#### 不建议

- 不要一上来讲 `History`、`Collection`、`long record`、`Ask Human`。
- 不要在欢迎页堆所有快捷键。

---

### Step 2. Required Access

#### 目标

把两个硬性权限讲成“能力开关”，而不是“系统麻烦事”。

#### 这是硬性完成项

用户必须完成以下两个授权后，才能继续：

- `Screen Recording`
- `Accessibility`

#### 推荐页面标题

`Invoko needs two permissions to work across your Mac.`

#### 权限卡片结构

##### A. Screen Recording

- 标题：`See what you're looking at`
- 解释：`Invoko reads on-screen context so you don’t have to describe everything manually.`
- 用户收益：
  - 回答更贴近当前屏幕。
  - `memo it` 才能成立。
  - 之后的长录制和上下文理解也会更自然。

##### B. Accessibility

- 标题：`Act inside other apps`
- 解释：`Invoko uses Accessibility access to paste, confirm, and interact with the app you're already using.`
- 用户收益：
  - 写作类结果能真正回填。
  - Agent 能在外部 app 中执行动作。

#### 页面文案建议

不要写“Authorize”这种只有操作没有意义的词，建议改成更结果导向的按钮：

- `Enable Screen Access`
- `Enable App Control`

完成后统一 CTA：

- `Continue`

#### 关于麦克风权限

虽然 `Fn` 首次使用时仍然需要麦克风权限，但不建议把麦克风和上面两个权限并列成“主授权”。

推荐做法：

- 在这一步只强制完成录屏和辅助功能。
- 到 `Fn` 试说的时刻再即时请求麦克风。
- 这样用户会把麦克风理解成“我要开始说话了，所以现在需要麦克风”，而不是 onboarding 阶段又多一个抽象设置。

---

### Step 3. First Win

#### 目标

让用户用 `Fn` 完成第一次真实任务，这是整个 onboarding 的核心。

#### 推荐标题

`Hold Fn. Ask naturally.`

#### 推荐副标题

`Press and hold Fn, say what you need, then release to send.`

#### 交互设计

这一屏不要只是“测试热键是否工作”，而要让用户完成一条真的请求。

推荐结构：

- 中间大按钮/键帽：`Fn`
- 状态反馈：
  - `Holding...`
  - `Listening...`
  - `Working...`
  - `Done`
- 三个示例 prompt chip，帮助用户开口：
  - `Summarize what’s on my screen`
  - `Draft a reply in my tone`
  - `What should I do next here?`

#### 结果反馈

用户松开后，不要只显示“测试成功”，而要展示一段真实返回：

- 如果是问答，展示简短结果。
- 如果是写作，展示“Invoko can also write back into your app.”
- 如果是复杂任务，展示“Invoko can keep heavier tasks running in the background.”

#### 为什么这一步重要

这一屏实际上在教育三件事：

1. `Fn` 是主入口。
2. Invoko 是自然语言驱动的，不需要 prompt engineering。
3. 它不是一个静态助手，而是一个会继续处理任务的 agent。

---

### Step 4. Guided Cases

#### 目标

在用户已经理解 `Fn` 之后，用场景而不是功能列表继续教学。

#### 推荐标题

`What do you want Invoko to help with next?`

#### 核心判断

这一屏不要做成静态 feature grid。  
它应该更像一个 “choose your next move” 的场景选择器。

推荐只放 `3 个 case`：

1. `Ask`
2. `Write`
3. `Save`

这三个 case 足够覆盖 Invoko 最重要的用户心智。

#### 推荐交互

- 页面出现三张 mission card。
- 用户任选一个进入 15-30 秒的微教学。
- 完成一个 case 后，标记为 `Done`，再推荐另一个。
- 没被选中的 case 不强迫完成，但会在首页继续出现。

#### Case A：Ask

- 标题：`Ask about what’s in front of you`
- 入口：`Fn`
- 文案：`Hold Fn and ask naturally. Invoko uses your screen and context to answer faster.`
- 推荐示例：
  - `What matters on this screen?`
  - `Summarize this for me`
  - `What should I do next?`

这张卡强化的是：

- `Fn` 是主入口。
- Invoko 是 screen-aware 的。
- 提问不需要先搭聊天上下文。

#### Case B：Write

- 标题：`Write back into the app you’re using`
- 入口：`Option` 或 `Fn`
- 文案：`Ask Invoko to draft, rewrite, or reply. It can place the result back into your flow.`
- 推荐示例：
  - `Write a clearer reply`
  - `Turn this into a shorter version`
  - `Draft this in my tone`

这张卡要顺带解释：

- `Accessibility` 为什么重要。
- Invoko 不是只会回答，它还会写回去。
- `Option` 是“不方便说话时的同一条 agent 流程”。

#### Case C：Save

- 标题：`Save something worth keeping`
- 入口：`double Shift`
- 文案：`Use memo it when you see something you’ll want later. Invoko turns the current screen into a reusable memory.`
- 推荐示例：
  - 保存一段研究结论
  - 保存一个重要 decision
  - 保存当前屏幕里的关键 takeaways

这张卡强化的是：

- `memo it` 不是截图工具，而是记忆工具。
- 保存的内容会进入 `Collection`。
- 屏幕理解是 Invoko 的一部分，不是附加玩具。

#### 推荐呈现方式

- 选中某个 case 后，右侧显示：
  - 快捷键
  - 真实例句
  - 预期结果
  - “结果会去哪” 的提示
- 未选中 case 保持收起，避免视觉过载。

#### 为什么这一步比纯 feature map 更好

- 它教的是“什么时候该用 Invoko”，而不是“Invoko 有什么按钮”。
- 它更接近真实工作流。
- 它为首页和空状态继续承接 case 教学打下基础。

---

### Step 5. Where Things Go

#### 目标

在用户已经看过真实 case 后，再解释信息架构，这时用户更容易真正理解 `History` 和 `Collection`。

#### 推荐标题

`Where your work ends up`

#### 两张主卡

- `History`
  - `Your real tasks and conversations live here.`
  - `Questions, writing tasks, and background jobs all become threads in History.`
- `Collection`
  - `Your memos and long-record summaries live here.`
  - `This is where saved context becomes something you can revisit later.`

#### 推荐补充：后台任务

可以增加一个小块解释：

- `Heavy work can keep running`
- `Invoko can keep more complex tasks going in the background, and you can come back to them in History.`

---

### Step 6. One More Thing

这一页不应该是“你必须现在学会”，而应该是“Invoko 还有两个特别强的能力”。

#### 模块 A：Ask Human

##### 推荐标题

`If Invoko gets blocked, it can ask you.`

##### 推荐说明

`Instead of silently waiting, Invoko can call or message you when it needs a decision, a missing detail, or a quick confirmation.`

##### 这页想传达的感觉

- 它不是死板的自动化。
- 它知道什么时候需要把你拉回环里。
- 它是主动协作，不是被动报错。

#### 模块 B：Long Record

##### 推荐标题

`You can also keep a longer thread of context.`

##### 推荐说明

`Long record can collect audio and screen context over time, then you can say "Hey Voko" to act from that recent context.`

##### 定位

- 这是进阶模式。
- 不要在首轮要求用户立即打开。

#### CTA

- `Open Invoko`
- 旁边可加次级按钮：`Skip for now`

## 7. case by case 的持续 onboarding

onboarding 不应该在最后一页结束。  
真正适合 Invoko 的方式，是把 case 教学继续延伸到产品内部。

### 7.1 首页不应该只是 dashboard，而应该是 mission hub

进入主界面后，首页最适合承接的是一组 `mission cards`，而不是只有统计信息。

推荐首页出现：

- `Ask something with Fn`
- `Write into your current app`
- `Save this with memo it`

每张卡都包含：

- 一个真实场景句子
- 对应快捷键
- 预期结果
- 完成状态

这样首页就不是“空 dashboard”，而是“下一步该怎么用 Invoko”。

### 7.2 case 教学应该是 progressive disclosure

推荐的节奏：

1. 首次只强推 `Fn`。
2. 完成一次问答后，推荐 `Write`。
3. 完成一次 writing 后，推荐 `memo it`。
4. 完成一次 memo 后，再介绍 `Ask Human` 或 `long record`。

这个顺序的好处是：

- 符合产品价值递进。
- 不会让用户第一次就被所有能力压住。
- 每一步都能用前一步的真实体验做铺垫。

### Home

首页不应该只显示空统计卡片，还应该显示 case-based 引导：

- `Try Fn to ask your first question`
- `Use Option when you want the same flow without speaking`
- `Use memo it to save what’s on screen`

如果要更丰富，建议把它们改成可完成的 mission：

- `Ask`
- `Write`
- `Save`

如果权限未完成，首页的权限卡片需要延续 onboarding 的语言，而不是退回通用设置语言。

### History 空状态

当前空状态只有：

- `No history yet`
- `Your conversations will appear here.`

建议改成更有引导性的版本，并且把下一个 case 接进去：

- 标题：`Your finished tasks will show up here`
- 说明：`Start with Fn. Ask something real, or run a writing task, and the thread will appear in History.`

### Collection 空状态

当前空状态只有：

- `No saved items yet`
- `Memos and cards will appear here.`

建议改成：

- 标题：`Saved context lives here`
- 说明：`Use memo it to save useful screens, or keep long-record summaries here for later recall.`

### 7.3 case 完成后要给“下一步推荐”

Invoko 很适合做一个轻量的连续学习链路：

- 完成 `Ask` 后：`Next, try writing into your current app`
- 完成 `Write` 后：`Next, save something with memo it`
- 完成 `Save` 后：`Now you know how Invoko answers, writes, and remembers`

这个“下一步推荐”可以出现在：

- 首页 mission card
- 完成 toast
- History / Collection 空状态
- 首次结果页底部

### 7.4 `Ask Human` 最适合做 contextual reveal

`Ask Human` 很有特色，但它更适合在用户已经理解 “Invoko 会自己继续做事” 后再点亮。

推荐第一次介绍它的节点：

- 用户第一次看到后台任务时
- 用户第一次看到需要确认的流程时
- 或者 onboarding 的最后一页作为品牌亮点出现一次

这样用户会把它理解成：

`Invoko is collaborative when it needs me, not just automated when it doesn’t.`

## 8. 推荐文案基线

下面是一套更统一的 onboarding 口径，供设计和客户端实现时直接引用。

### 产品一句话

`Invoko is a voice agent that acts for you on your Mac.`

### 权限一句话

`Screen access helps Invoko understand your context. App control lets it act in the apps you already use.`

### Fn 一句话

`Hold Fn, say what you need, then release to send.`

### Option 一句话

`Use Option when you want the same workflow without speaking.`

### memo it 一句话

`Double Shift to save something worth keeping.`

### History / Collection 一句话

- `History keeps your real tasks.`
- `Collection keeps what you want to remember.`

### Ask Human 一句话

`When Invoko needs you, it can call or message instead of getting stuck.`

## 9. 对当前桌面端实现的修正建议

基于现有实现，建议优先修正以下问题：

### 9.1 现有 onboarding 过早进入 setup，缺少 Welcome

当前 `DesktopOnboardingFlowView` 只有：

- `Required Access`
- `Voice Hotkey`

这不够。  
应该在前面增加一个 `Welcome / What Invoko is` 步骤。

### 9.2 当前 Step 2 更像热键测试，不像首次成功

现在的 `voiceSetup` 更像：

- 热键是否按下。
- 麦克风是否录到。

但真正需要的是：

- 用户是否完成了一次真实提问。
- 用户是否看懂 Agent 的结果反馈。

### 9.3 快捷键文案存在过期信息

目前桌面首页有旧文案，需要按产品现状更新：

- `double command` -> `double shift`
- `Memo` -> `memo it`
- `Option ... copy to clipboard` -> 更贴近真实 agent 流程，不要只写 clipboard

### 9.4 当前实现还没有承接 case by case 教学

现在的桌面端 onboarding 和首页更像：

- 一次性 setup
- 然后进入静态主界面

但更适合的方向是：

- onboarding 完成第一次 `Fn`
- 首页继续承接 `Ask / Write / Save`
- 空状态继续教学

也就是说，真正要设计的不是单个 onboarding modal，而是一整条连续学习路径。

### 9.5 `History` 和 `Collection` 的认知分工还不够清楚

用户很容易在首次使用时不知道：

- 哪些内容是正式任务。
- 哪些内容是保存下来的上下文。

这个区分应该在 onboarding 中明确出现一次，而不是等用户自己猜。

### 9.6 `Ask Human` 应作为差异化能力出现

这是能明显拉开 Invoko 和普通桌面助手差别的功能。  
它不应该埋在深层逻辑里，而应该在 onboarding 收尾处被点亮一次。

## 10. 成功指标

可以用下面这些指标判断 onboarding 是否有效：

### 必看指标

- 完成录屏授权率
- 完成辅助功能授权率
- 完成首次 `Fn` 提问率
- 首次会话后进入主界面的完成率

### 行为指标

- 首日 `Fn` 再次使用率
- 首日 `memo it` 触发率
- 首日 `History` 打开率
- 首日 `Collection` 打开率

### 记忆点指标

- 用户是否理解 `History` vs `Collection`
- 用户是否知道 Invoko 能在需要时 `Ask Human`

## 11. 最终建议

Invoko 的 onboarding 不应该被设计成“教用户如何设置一个 app”，而应该被设计成“让用户第一次体验一个会行动的 voice agent”。

所以推荐的优先级是：

1. 先定义 Invoko 是什么。
2. 再把权限讲成能力前提。
3. 然后让用户用 `Fn` 完成第一次真实动作。
4. 最后再快速解释 `Option`、`memo it`、`History`、`Collection`。
5. 用 `Ask Human` 和 `long record` 做收尾记忆点。

如果只保留一句设计判断，那就是：

> 首轮 onboarding 的核心不是“完成设置”，而是“让用户第一次相信 Invoko 真的会替他做事”。
