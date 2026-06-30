# INVOKO UI 资源完整扒取报告

> 来源：逆向 `/Applications/Invoko.app/Contents/MacOS/Invoko` + `Resources/` 目录完整扫描（2026-06-30 版本）。
>
> 本文是 [`INVOKO-Notch-UI-Architecture.md`](INVOKO-Notch-UI-Architecture.md)（类名结构）和 [`INVOKO-Design-Tokens-Extracted.md`](INVOKO-Design-Tokens-Extracted.md)（Token 数值）的**资源层补充**——那两篇讲代码里的类型和 Token，本文档讲实际渲染资源。

---

## 一、Rive 动画状态全集（15 个 .riv 文件）

Invoko 的刘海/云朵角色用 **Rive** 驱动（`IPRiveAnimationView` / `IPRiveViewModel` / `IPRiveCharacterView`）。每个 .riv 文件对应一个 UI 状态。

### 完整清单

| 文件名 | 大小 | 状态名 | 核心组件 | 备注 |
|--------|------|--------|----------|------|
| `IPDefaultIdle.riv` | 12K | idle | 云 + 圆点 | 待机态 |
| `IPDefaultThinking.riv` | 16K | thinking | 云 + 眼睛 | 思考中 |
| `IPDefaultRouting.riv` | 8.7K | routing | 星球动画 | 路由/分发中 |
| `IPDefaultListening.riv` | 21K | listening | 云 + 眼睛 + blink + 手 | 录音中 |
| `IPDefaultOutputting.riv` | 9.7K | outputting | 云 + 手 + 眼睛 | 输出中 |
| `IPDefaultDone.riv` | 16K | done | 云 + 圆点 | 完成态 |
| `IPDefaultError.riv` | 2.4K | error | 云 | 错误态 |
| `IPDefaultTyping.riv` | 9.9K | typing | 云 + 双手 + 眼睛 | 输入中（用户打字时） |
| `IPDefaultAuthorization.riv` | 9.1K | authorization | 授权相关 | 权限请求态 |
| `IPDefaultBackgroundHint.riv` | 12K | background hint | 背景提示 | 后台提示态 |
| `IPDefaultWaveform.riv` | 9.6K | recording | 云 + 手 + 眼睛 | 录音波形态 |
| `IPDefaultSparkle.riv` | 7.2K | agent background | 背景代理 | 后台代理态 |
| `IPDefaultAcknowledge.riv` | 121K | acknowledge | **PPNeueMontreal-Bold 字体嵌入** | 确认/应答态，最大文件 |
| `IPDefaultNotification.riv` | 170K | notification | 灯泡 + 颜色信息（Figma 源） | 通知态 |
| `IPDefaultHelp.riv` | 2.0M | help | **大量 Figma 元数据嵌入** | 帮助态，最大单个文件 |

### 核心组件词汇表

Rive 文件里提取到的动画组件名称（这些是 Rive 内部 artboard 里的节点名）：

| 组件 | 出现在哪些状态 |
|------|---------------|
| `cloud` | listening, outputting, typing, waveform, error, idle, done |
| `eyes` | listening, outputting, typing, waveform |
| `blink` | listening, outputting, typing |
| `hand` / `handL` / `handR` | outputting, typing, waveform |
| `planet` | routing |
| `thinking` | thinking |
| `recording` | waveform |
| `background hint` | background hint |
| `agent background` | sparkle |
| `bulb` | notification |
| `cloud` + `eyes` + `blink` | idle, thinking |

### 动画驱动方式

二进制中确认的 Swift 调用：

```swift
// Rive 视图层
IPRiveAnimationView    // 主视图
IPRiveCharacterView    // 角色视图（云朵角色）
IPRiveViewModel        // 视图模型
IPRiveAsset            // 资产管理

// Rive 运行时
So13RiveFileAssetCSo6NSDataCSo0A7FactoryC   // 从 NSData 加载 Rive 文件
createRiveView         // 创建 Rive 视图
init:animationName:fit:alignment:autoPlay:artboardName:  // 初始化参数
riveAsset / riveAssetOverride  // 资产覆盖机制
runAnimationGroup:completionHandler:
onAnimationFinished
```

### 状态 → Rive 映射关系

```
Idle          → IPDefaultIdle.riv        (12K,  云+点)
Thinking      → IPDefaultThinking.riv     (16K,  云+眼睛)
Routing       → IPDefaultRouting.riv     (8.7K, 星球)
Listening     → IPDefaultListening.riv   (21K,  云+眼睛+手)
Outputting    → IPDefaultOutputting.riv  (9.7K, 云+手+眼睛)
Done          → IPDefaultDone.riv        (16K,  云+点)
Error         → IPDefaultError.riv       (2.4K, 云)
Typing        → IPDefaultTyping.riv      (9.9K, 云+双手+眼睛)
Authorization → IPDefaultAuthorization.riv (9.1K)
BackgroundHint→ IPDefaultBackgroundHint.riv (12K)
Recording     → IPDefaultWaveform.riv    (9.6K, 云+手+眼睛)
AgentBG       → IPDefaultSparkle.riv    (7.2K)
Acknowledge   → IPDefaultAcknowledge.riv (121K, 含 PP Neue Montreal)
Notification  → IPDefaultNotification.riv (170K, 含 Figma 元数据)
Help          → IPDefaultHelp.riv        (2.0M, 含大量 Figma 元数据)
```

---

## 二、色彩系统（从二进制提取）

### 主色板（UI 常用色）

按语义分组，从 300+ 个 hex 值中提取最可能用于 UI 的：

#### 蓝色系（最常用）
```
#3ea2ff   亮蓝（notch 强调色）
#5fb0e6   天蓝
#5fb3ff   浅天蓝
#5fd2ff   更浅蓝
#50b0e0   中蓝
#5fc8e0   青色蓝
#5fe0e0   青绿色
#5a7f96   灰蓝
#4a6276   深灰蓝
#4a5878   中灰蓝
#3f4a63   暗灰蓝
#334155   Slate 深蓝
#64748b   Slate 中灰
#667085   Slate 灰
#55607a   暗灰紫蓝
```

#### Invoko 品牌蓝（主色调）
```
#152c66   深蓝（品牌深色）
#1a2b8f   品牌蓝
#22409e   品牌中蓝
#27439f   品牌蓝
#274bb8   品牌亮蓝
#2b52d2   亮品牌蓝
#3a5ad0   更亮蓝
#3a63e2   主品牌蓝
#3258d4   亮蓝
#5078ec   主色调（最常用品牌色）
```

#### 中性灰/暗色（背景、边框）
```
#141c28   深暗蓝灰（主要背景）
#161c28   深色背景
#0f172a   最深背景（slate-900）
#0e1420   暗背景
#0b1726   暗蓝黑
#0b1120   暗蓝
#0a0f1a   几乎纯黑蓝
#1a1d2a   面板背景
#2a3346   次级背景
```

#### 强调色（橙/琥珀）
```
#c96c4a   暖橙（Voko 角色主强调）
#d47a5a   珊瑚橙
#b97a5b   陶土橙
#d46a3a   深橙
#a55c3a   暗橙
```

#### 绿色/成功
```
#4f8f88   青绿（成功/完成）
#3f8a86   薄荷绿
#4a7a78   深青绿
#5f8f8a   亮青绿
#487a86   蓝绿
```

#### 紫色（特殊状态）
```
#5a30a0   深紫（authorization 相关）
```

### 半透明遮罩层

这些出现在浮动面板背景、按钮毛玻璃等场景：

```
rgba(20,24,40,.62)   深色毛玻璃背景
rgba(255,255,255,.16)  边框高光
rgba(255,255,255,.72)  亮色毛玻璃
rgba(15,23,42,.08)    极淡遮罩
rgba(15,23,42,.14)    轻遮罩
rgba(15,23,42,.18)    中遮罩
rgba(13,16,28,.94)    深遮罩
rgba(0,0,0,.35)       标准阴影
rgba(0,0,0,.62)       深阴影
rgba(132,212,255,.24) 发光蓝
rgba(134,208,240,.09) 淡发光
```

### 面板 Actions 按钮

从 CSS 片段提取的完整按钮样式：

```css
/* 深色模式 */
background: rgba(20,24,40,.62)
color: #cdd5e6
border: 1px solid rgba(255,255,255,.16)
box-shadow: 0 4px 18px rgba(0,0,0,.35)
backdrop-filter: blur(14px) saturate(1.3)

/* 亮色模式 */
background: rgba(255,255,255,.72)
color: #2a3346
border: 1px solid rgba(0,0,0,.1)
```

---

## 三、字体系统

### 自定义字体：PP Neue Montreal

`IPDefaultAcknowledge.riv` 内嵌了完整字体：

```
PPNeueMontreal-Bold
PP Neue Montreal Bold
Version 2.600
Copyright by Pangram Pangram Foundry. All rights reserved.
Mathieu Desjardins（设计师）
Font engineering: Alphabet Type GmbH
```

这是 Invoko 的品牌字体，专门用于 Acknowledge 动画状态（确认/应答时的品牌展示）。

### 系统字体

从代码中确认的字体栈：

```swift
-apple-system              // SF Pro（系统默认）
SF Pro                    // 明确引用
SF Mono                   // 等宽字体
PingFang SC               // 中文苹果字体
Helvetica Neue            // 备选无衬线
Arial                     // 最末保底
```

从二进制 CSS 提取的字体声明：

```css
font: '700 [size]px -apple-system, sans-serif'      // 粗体（memo count 等）
font: '600 13px -apple-system, "PingFang SC", sans-serif'  // 中文正文
```

---

## 四、自定义图标与资产类

二进制中确认的自定义图标/资产类（非系统类）：

```
CloudImageStack              // 云朵图像堆叠（NotchV3CloudImageStack 对应渲染类）
NotchInlineIconButton        // 刘海行内图标按钮
NotchInlineIconTextButton   // 刘海行内图标+文字按钮
ProactiveAppIcon             // 主动态应用图标
ListeningStatusIconView      // 录音状态图标视图
RunningDotIcon              // 运行中圆点图标
ScheduleIcon                 // 定时图标
ScheduleIconTap              // 定时图标点击处理
HoverableIconButton          // 可悬停图标按钮
CircleIconButton             // 圆形图标按钮（NotchV3CircleIconButton 对应）
InvokoLogo                  // Invoko 品牌 Logo
ExternalLinkIcon             // 外部链接图标
HomeGoalConnectorIcon       // 首页目标连接线图标
HomeGoalIconButton          // 首页目标图标按钮
ConnectorIconView           // 连接图标视图
FixedIconLabelStyle          // 固定图标标签样式
HeaderIconButtonStyle       // Header 图标按钮样式
MycoIconButtonStyle        // Myco 图标按钮样式
AllImages / AllBinaryImages // 全局图像注册表
CalendarAccountSourceIcon   // 日历账户来源图标
AMSymbol / PMSymbol         // SF Symbols 包装类
AnimatedCheckmarkSymbol     // 动画勾选符号
```

---

## 五、Swift 源码文件完整清单（97 个）

这些是 Invoko 主二进制中引用的所有 Swift 源文件名（揭示了完整的模块结构）：

### 核心控制器
```
Invoko/AppController.swift
Invoko/AppController+AgentToolHandlers.swift
Invoko/desktopApp.swift
```

### 语音与 AI
```
Invoko/VoiceCaptureController.swift
Invoko/VoiceInputController.swift
Invoko/VoiceContextKeytermExtractor.swift
Invoko/VoiceHoldTrigger.swift
Invoko/DoubleTapTrigger.swift
Invoko/FnFastModeController.swift
Invoko/GeminiLiveSessionManager.swift
Invoko/GeminiLiveFastPathCoordinator.swift
Invoko/GeminiLiveTokenClient.swift
Invoko/RefineVoiceCapture.swift
Invoko/RefineLiveASR.swift
Invoko/InvokoVoiceDialogueController.swift
Invoko/InvokoVoiceBackendDialogueService.swift
Invoko/InvokoVoiceSessionStateMachine.swift
Invoko/VoiceCoreService.swift
Invoko/VoiceConversationAudioGraph.swift
Invoko/VoiceTranscriptPipeline.swift
Invoko/VoiceTurnFinalizer.swift
Invoko/VoiceTurnTelemetry.swift
Invoko/VoicePlaybackBargeInCoordinator.swift
Invoko/VoiceRealtimeBootstrapper.swift
Invoko/VoiceRealtimeConnectionManager.swift
Invoko/VoiceRealtimeASRProviderHealthMonitor.swift
Invoko/VoiceRealtimeTranscriptReducer.swift
Invoko/WebSocketTextToSpeechService.swift
Invoko/DebugTextToSpeechService.swift
Invoko/StreamingAudioHTTPStream.swift
Invoko/StreamingTextToSpeechService.swift
```

### 面板与 UI 状态
```
Invoko/PanelDisplayState.swift
Invoko/RelaylessPanelDisplayState.swift
Invoko/PanelContext.swift
Invoko/LensPanel.swift
Invoko/LensService.swift
Invoko/ReplyCandidatePanel.swift
```

### 刘海相关
```
Invoko/NotchPreviewWindow.swift
Invoko/NotchWelcomeBubble.swift
Invoko/HomingGuideOverlayWindowController.swift
Invoko/IPWidgetWindowController.swift
Invoko/IPWidgetRootView.swift
Invoko/IPPositionStore.swift
Invoko/IPNotificationBubbleSource.swift
```

### 主窗口与导航
```
Invoko/MainWindowNavigationCoordinator.swift
Invoko/MainWindowReportTitlebarAccessory.swift
Invoko/DesktopContentPages.swift
Invoko/DesktopOverviewPageView.swift
```

### Onboarding
```
Invoko/DesktopOnboardingFlowView.swift
```

### History 与 Memory
```
Invoko/HistoryRecordChatDetailView.swift
Invoko/HistoryMarkdownRendering.swift
Invoko/LocalTaskHistoryStore.swift
Invoko/ThreadDetailStore.swift
Invoko/MemoryAttachmentsStore.swift
```

### Task 系统
```
Invoko/TaskDisplayStatusCoordinatorStore.swift
Invoko/TaskFilePresentation.swift
Invoko/RecurringTaskStore.swift
Invoko/LongRecordingInputEventMonitor.swift
Invoko/LongRecordingWakePhraseMatcher.swift
```

### Reply / Agent
```
Invoko/ReplyAgentRunner.swift
Invoko/ReplyQuickActionController.swift
Invoko/ReplyDeepLinkBus.swift
Invoko/ReplyProfileBuilder.swift
Invoko/ReplyEmbeddedHostSource.swift
Invoko/ReplyDNARebuildCoordinator.swift
Invoko/ReplyDailySyncScheduler.swift
```

### 第三方集成
```
Invoko/LarkConnectionController.swift
Invoko/ComposioConnectionService.swift
Invoko/DesktopRemoteControlService.swift
Invoko/DesktopAgentDaemonRunner.swift
```

### 数据存储
```
Invoko/AuthStore.swift
Invoko/PermissionStore.swift
Invoko/ChatContextRouter.swift
Invoko/GenerationState.swift
Invoko/DailyUsageQuotaStore.swift
Invoko/DeliveryIntentStateStore.swift
Invoko/InternalUsageTracker.swift
Invoko/LaunchAtLoginStore.swift
Invoko/WorkTimeStore.swift
Invoko/StartupDiagnosticsStore.swift
Invoko/OutputSpeechAnnouncer.swift
```

### 通知与提醒
```
Invoko/IMNotificationObserver.swift
Invoko/NotificationPopupCoordinator.swift
Invoko/AppToast.swift
```

### 其他 UI/工具
```
Invoko/ImpactMenuDebugCard.swift
Invoko/CalendarPanelContent.swift
Invoko/SkillComposer.swift
Invoko/SVGPathParser.swift
Invoko/RemoteImageView.swift
Invoko/UserVoiceBuilder.swift
Invoko/PointerModel.swift
Invoko/HotkeySettings.swift
Invoko/MagicCursorSelectionController.swift
Invoko/SilentUpdatePackageServer.swift
Invoko/RelaylessSessionController.swift
Invoko/RelaylessTraceDumper.swift
Invoko/RelaylessTraceUploader.swift
```

### 生成代码
```
Invoko/GeneratedAssetSymbols.swift   // 资产符号定义（AppIcon, AllImages 等）
```

---

## 六、尺寸与间距系统

从二进制提取的 UI 尺寸常量：

### 字号层级
```
11px    Eyebrow / 极小标签
12px    辅助说明
13px    正文（小）
14px    正文（主）
15px    强调正文
16px    标题（小）
17px    标题（中）
18px    标题（大）
20px    页面标题
```

### 圆角层级
```
1px     极细分割线
2px     小组件
10px    小卡片/Chip
12px    小按钮
14-16px 普通按钮/卡片
18-20px 大卡片/Bubble
24px    大容器
999px   圆形
```

### 布局尺寸
```
220px   Bubble 小号
240px   Bubble 中号
300px   V3 compact 宽度
360px   面板宽度
480px   V3 wide result 宽度
860px   Onboarding 最小宽度
980px   Onboarding 最大宽度
```

### 间距
```
6pt     space-1
10pt    space-2
14pt    space-3
20pt    space-4
28pt    space-5
40pt    space-6
56pt    space-7
```

---

## 七、Assets.car（44MB）

主资产包，格式为 `car`（Apple 资产目录格式），包含颜色集、图片资产、SF Symbols 引用和自定义图标。

> **限制**：`assetutil` 无法识别此 .car 文件格式（可能是自定义变体），无法直接提取内容。颜色值已通过二进制 strings 提取（见第二节）。

---

## 八、对"就块"项目的资源价值

| 资源类型 | 对你最有价值的部分 |
|---------|------------------|
| **Rive 动画** | Idle/Thinking/Done 三态的云朵 + 眼睛组件结构，可以逆向研究动画节点名 |
| **PP Neue Montreal 字体** | 品牌字体，但有版权限制（只能内嵌在 .riv 里，不可直接提取商用） |
| **色彩系统** | 品牌蓝 (#5078ec)、Voko 橙 (#c96c4a)、面板灰 (#141c28) 可直接参考 |
| **Swift 源码清单** | 完整模块结构，特别是 `HomingGuideOverlayWindowController`（引导覆盖）和 `LensPanel`（Lens 浮层）最值得研究 |
| **面板 Actions CSS** | 毛玻璃按钮样式（blur 14px, saturate 1.3）可直接抄 |
| **图标资产类** | `CloudImageStack`、`CircleIconButton`、`HoverableIconButton` 等自定义图标类名揭示了完整的图标系统 |

### 最值得优先研究的文件

1. **`IPDefaultIdle.riv`（12K）** — 最简云朵 Idle 态，节点最少，容易拆解
2. **`IPDefaultListening.riv`（21K）** — 最完整的云+手+眼组合
3. **`AppToast.swift`** — Toast 通知样式
4. **`HomingGuideOverlayWindowController.swift`** — 引导覆盖层
5. **`GeneratedAssetSymbols.swift`** — 资产符号定义（可能有资产名清单）

---

## 附：可复现扒取命令

```bash
BIN=/Applications/Invoko.app/Contents/MacOS/Invoko
RES=/Applications/Invoko.app/Contents/Resources

# Swift 源文件名清单
strings "$BIN" | grep "Invoko/" | grep "\.swift" | sort -u

# Rive 文件清单
ls "$RES"/IPDefault*.riv

# 十六进制颜色值
strings "$BIN" | grep -oE "#[0-9a-fA-F]{6}" | sort -u

# 半透明遮罩
strings "$BIN" | grep -oE "rgba\([0-9,. ]+\)" | sort -u

# Rive Swift 类引用
strings "$BIN" | grep -E "IPRive|Rive" | grep -vE "^\$|^_" | sort -u

# 每个 Rive 文件的元数据（动画状态名）
for f in "$RES"/IPDefault*.riv; do echo "=== $(basename $f) ==="; strings "$f" | grep -vE "^\$[a-z]|\.frame\.|^_|^[a-z]{2,4}\s" | head -10; done

# 自定义字体
strings "$RES"/IPDefaultAcknowledge.riv | grep -i "font\|PPNeue\|Pangram" | head -5

# 图标/资产类名
strings "$BIN" | grep -oE "[A-Z][a-zA-Z]+(Icon|Image|Asset|Logo|Symbol|Picture|Glyph|IconButton|IconLabel)[A-Za-z]*" | sort -u
```
