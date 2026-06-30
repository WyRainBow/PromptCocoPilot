# INVOKO Design Research - Complete Index

> All materials extracted from INVOKO.app for reference and learning

## 📁 Directory Structure

```
docs/invoko-design-raw/
├── ExplorationVokoSalaDesign.md     # Voko/Sala 双界面完整设计规范
├── InvokoOnboardingFlow.md          # Onboarding 流程和用户旅程
├── InvokoOnboardingUIDesign.md      # Onboarding UI 组件和动效
├── NotchStateMachine.md             # Notch 状态机、几何尺寸
├── INVOKO-Design-Tokens-Extracted.md # 从二进制提取的设计 Token
└── INVOKO-Research-Index.md        # 本文档 - 综合索引
```

---

## 🎨 Design System Summary

### Colors

| Token | Dark | Light | Usage |
|-------|------|-------|-------|
| Accent | `#5fb3ff` | `#3ea2ff` | Active states |
| Accent Glow | `rgba(95,179,255,.42)` | `rgba(62,162,255,.32)` | Button glow |
| Background | `#01050d` | `#f8fafc` | Base |
| Text Primary | `#e8ecf4` | `#0b1120` | Main text |
| Panel BG | `rgba(16,19,32,.55)` | `rgba(248,250,255,.62)` | Panels |

### Visual Effects

- **Backdrop Blur**: `blur(28-30px) saturate(1.4-1.5)`
- **Panel Shadow**: `0 32px 80px rgba(0,0,0,.45)`
- **Active Glow**: `box-shadow: 0 0 42px rgba(58,182,255,.18)`
- **Transitions**: `.18s ease`, `.24s cubic-bezier(.2,.7,.2,1)`

### Notch Dimensions

| State | Size |
|-------|------|
| V3 Compact | `290 x 38` |
| V3 Horizontal | `300 x 38` |
| V3 Wide Result | `480 x 38 + 内容高度` |

---

## 🔑 Key Product Concepts

### Voko
- 桌面上的小舞台
- 人物感 + 近身陪伴
- 语音优先 + 记忆回溯
- 中央圆 + 气泡环绕

### Sala
- 工作年鉴 / 日报摘要
- 总结 + 比例 + memory
- 冷静、编辑性、统计感

### Notch
- 核心入口不是聊天窗口
- 全局快捷键 Fn 语音
- 状态：idle/listening/thinking/routing/outputting/done

### Core Interactions
- **Fn**: 按住说话，松开提交
- **Option**: 打字输入
- **memo it**: double Shift 保存屏幕
- **long record**: 长时间录制
- **Ask Human**: 主动呼叫用户

---

## 📊 Resources

### Rive Animations (in .app bundle)
- `IPDefaultIdle.riv`
- `IPDefaultListening.riv`
- `IPDefaultThinking.riv`
- `IPDefaultRouting.riv`
- `IPDefaultOutputting.riv`
- `IPDefaultDone.riv`
- + 8 more states

### Assets
- Logo variants
- IP Widget assets
- Connector icons
- Weather icons

---

## 🏗️ Architecture (from binary)

### SwiftUI Views
- `FloatingPanelController`
- `FloatingPanel`
- `CompactBarView`
- `FastModeNotchView`
- `ImpactFortuneFloatingPanel`

### State Keys
- `notchEventQueue`
- `expandedPresentation`
- `visualState`
- `_ipNotchTransitionGlowVisible`

---

## 📝 Design Principles

1. **Not SaaS dashboard** - 不是通用模板
2. **Not cyberpunk** - 避免霓虹紫蓝
3. **Paper & object feel** - 纸张质感
4. **Breathing space** - 大量留白
5. **Role-centered** - Voko 是角色，Sala 是总结

---

## 🔗 Original Source Files

| File | Location in .app |
|------|------------------|
| Design Docs | `/Applications/Invoko.app/Contents/Resources/*.md` |
| Rive Animations | `/Applications/Invoko.app/Contents/Resources/*.riv` |
| Assets | `/Applications/Invoko.app/Contents/Resources/Assets.car` |
| Binary | `/Applications/Invoko.app/Contents/MacOS/Invoko` |

---

*Research completed: 2026-06-30*
