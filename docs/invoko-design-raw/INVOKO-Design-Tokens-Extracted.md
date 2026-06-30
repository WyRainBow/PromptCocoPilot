# INVOKO Design System (Extracted from Binary)

> Extracted from INVOKO.app binary via `strings` analysis

## Color Palette

### Primary Brand Colors

| Token | Dark Mode | Light Mode | Usage |
|-------|-----------|------------|-------|
| `--accent` | `#5fb3ff` | `#3ea2ff` | Active states, highlights |
| `--accent-glow` | `rgba(95,179,255,.42)` | `rgba(62,162,255,.32)` | Button glow |
| `--accent-border` | `rgba(95,179,255,.32)` | `rgba(62,162,255,.3)` | Border highlights |

### Neutral Scale

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| `--bg-0` | `#01050d` | `#f8fafc` |
| `--bg-1` | `#09243a` | `#f4f8ff` |
| `--text-primary` | `#e8ecf4` | `#0b1120` |
| `--text-secondary` | `#8a93a8` | `#5a6480` |
| `--text-muted` | `#5a6276` | `#9aa0b4` |

### Panel Colors

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| `--panel-bg` | `rgba(16,19,32,.55)` | `rgba(248,250,255,.62)` |
| `--panel-border` | `rgba(255,255,255,.12)` | `rgba(0,0,0,.08)` |
| `--panel-shadow` | `rgba(0,0,0,.5)` | `rgba(15,23,42,.14)` |

### Chip/Card Colors

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| `--chip-bg` | `rgba(255,255,255,.06)` | `rgba(0,0,0,.04)` |
| `--chip-border` | `rgba(255,255,255,.16)` | `rgba(0,0,0,.1)` |
| `--card-bg` | `rgba(34,37,42,.5)` | auto |
| `--card-border` | `rgba(255,255,255,.16)` | `rgba(15,48,138,.14)` |

---

## Typography

| Token | Value | Usage |
|-------|-------|-------|
| `--font-family` | `-apple-system, "PingFang SC", sans-serif` | All text |
| `--font-title` | `18px / 650 weight / -0.02em tracking` | Panel titles |
| `--font-body` | `13-14px / normal` | Body text |
| `--font-small` | `12px` | Secondary text |
| `--font-micro` | `11px / uppercase / 1.4px tracking` | Labels |

---

## Spacing System

| Token | Value | Usage |
|-------|-------|-------|
| `--space-xs` | `3px` | Internal padding |
| `--space-sm` | `6px` | Chip gaps |
| `--space-md` | `10-12px` | Card padding |
| `--space-lg` | `16px` | Panel padding |
| `--space-xl` | `22px` | Section spacing |
| `--space-2xl` | `28px` | Outer margins |

---

## Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `--radius-sm` | `8px` | Buttons, inputs |
| `--radius-md` | `10px` | Chips, chips |
| `--radius-lg` | `14px` | Cards |
| `--radius-xl` | `18px` | Panel body |
| `--radius-2xl` | `24px` | Main panels |

---

## Shadows

### Dark Mode

```css
/* Panel */
box-shadow: 0 16px 48px rgba(0,0,0,.5);

/* Main Panel (blur bg) */
box-shadow: 0 32px 80px rgba(0,0,0,.45);

/* Button */
box-shadow: 0 4px 18px rgba(0,0,0,.35);

/* Active Card */
box-shadow: 0 4px 18px rgba(95,179,255,.22), inset 0 0 0 1px rgba(95,179,255,.32);

/* Active Chip */
box-shadow: 0 2px 14px rgba(95,179,255,.42);
```

### Light Mode

```css
/* Panel */
box-shadow: 0 32px 72px rgba(15,23,42,.14);

/* Active Card */
box-shadow: 0 4px 18px rgba(62,162,255,.18), inset 0 0 0 1px rgba(62,162,255,.3);

/* Active Chip */
box-shadow: 0 2px 14px rgba(62,162,255,.32);
```

---

## Backdrop Filter

| Element | Value |
|---------|-------|
| Panel Button | `blur(14px) saturate(1.3)` |
| Panel Body | `blur(30px) saturate(1.5)` |
| Main Panel (blur bg) | `blur(28px) saturate(1.4)` |
| Detail Popover | `blur(24px) saturate(1.45)` |

---

## Transitions

| Property | Duration | Easing |
|----------|----------|--------|
| Opacity | `.18s` | `ease` |
| Scale | `.2s` | `ease` |
| Transform | `.24s` | `cubic-bezier(.2,.7,.2,1)` |
| Background | `.15s` | auto |
| Color | `.15s` | auto |

---

## Notch Specific (CSS Variables from Binary)

```css
/* Notch Button */
#panelbtn {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: rgba(20,24,40,.62);
  border: 1px solid rgba(255,255,255,.16);
  backdrop-filter: blur(14px) saturate(1.3);
  box-shadow: 0 4px 18px rgba(0,0,0,.35);
  transition: opacity .18s ease, transform .18s ease;
}

/* Notch Panel */
#panelbody {
  width: 284px;
  padding: 16px;
  border-radius: 18px;
  background: rgba(16,19,32,.55);
  border: 1px solid rgba(255,255,255,.12);
  backdrop-filter: blur(30px) saturate(1.5);
  box-shadow: 0 16px 48px rgba(0,0,0,.5);
  opacity: 0;
  transform: scale(.9);
  transition: opacity .2s ease, transform .24s cubic-bezier(.2,.7,.2,1), visibility 0s linear .24s;
}

/* Notch Main Panel */
#logicStack {
  border-radius: 24px;
  border: 1px solid rgba(255,255,255,.2);
  background: rgba(0,0,0,.55);
  backdrop-filter: blur(28px) saturate(1.4);
  box-shadow: 0 32px 80px rgba(0,0,0,.45);
}

/* Detail Popover */
#detailPopover {
  max-width: min(360px, calc(100vw - 36px));
  padding: 16px 17px 15px;
  border-radius: 18px;
  background: rgba(7,13,27,.74);
  border: 1px solid rgba(132,212,255,.24);
  box-shadow: 0 24px 70px rgba(0,0,0,.54), 0 0 42px rgba(58,182,255,.18);
  backdrop-filter: blur(24px) saturate(1.45);
}
```

---

## Glow Effects

### Active State Glow

```css
/* Chip Active - Blue Glow */
.treeChipL1.active {
  background: #5fb3ff;
  color: #07101d;
  border-color: #5fb3ff;
  box-shadow: 0 2px 14px rgba(95,179,255,.42);
}

/* Card Active - Gradient Glow */
.treeCardL2.active {
  border-color: #5fb3ff;
  background: linear-gradient(135deg, rgba(95,179,255,.18), rgba(95,179,255,.06));
  box-shadow: 0 4px 18px rgba(95,179,255,.22), inset 0 0 0 1px rgba(95,179,255,.32);
}

/* Universe State - Star Glow */
#universeState {
  text-shadow: 0 0 18px rgba(62,183,255,.32);
}
```

### Light Mode Glow Adjustments

```css
.treeChipL1.active {
  background: #3ea2ff;
  color: #0b1120;
  border-color: #3ea2ff;
  box-shadow: 0 2px 14px rgba(62,162,255,.32);
}

.treeCardL2.active {
  border-color: #3ea2ff;
  background: linear-gradient(135deg, rgba(62,162,255,.16), rgba(62,162,255,.04));
  box-shadow: 0 4px 18px rgba(62,162,255,.18), inset 0 0 0 1px rgba(62,162,255,.3);
}
```

---

## Dimension Tokens

| Element | Width | Height |
|---------|-------|--------|
| Panel Button | `40px` | `40px` |
| Panel Body | `284px` | auto |
| Logic Stack | flex (100%) | flex |
| Detail Popover | `min(360px, calc(100vw - 36px))` | auto |
| View Switcher Gap | `6px` | - |

---

## SwiftUI View Names (from binary)

- `FloatingPanelController`
- `FloatingPanel`
- `CompactBarView`
- `FastModeNotchView`
- `ImpactFortuneFloatingPanel`

---

## Notch State Machine Keys (from binary)

```
_isIPWidgetResidentNotchVisible
_isIPNotchWelcomeVisible
_ipNotchSuppressesOutputPresentation
_ipNotchTransitionGlowVisible
_ipNotchTransitionAppearing
_ipNotchTransitionFadingOut
_ipNotchBounceToken
_isNotchToolsVisible
notchWelcomeBubbleController
ipWidgetFoldedToNotch
ipResidentNotchAnchorPoint
foldedNotchAnchorPoint
ipFoldCueNotchPreviewActive
ipToNotchGlowBounceDurationNs
ipNotchBounceDelayNs
```

---

## Dynamic Island / Notch Dimensions (from NotchStateMachine.md)

| State | Dimensions |
|-------|------------|
| legacy normal | `179 x 32` |
| legacy horizontal normal | `263 x 34` |
| legacy expanded | `273 x 36` |
| V3 compact | `290 x 38` |
| V3 horizontal / small expanded | `300 x 38` |
| V3 wide result / notification | `480 x 38 + 内容高度` |

---

## Rive Animations

Located at: `/Applications/Invoko.app/Contents/Resources/`

| Animation | Purpose |
|-----------|---------|
| `IPDefaultIdle.riv` | Idle state |
| `IPDefaultListening.riv` | Listening state |
| `IPDefaultThinking.riv` | Thinking state |
| `IPDefaultRouting.riv` | Routing state |
| `IPDefaultOutputting.riv` | Outputting state |
| `IPDefaultDone.riv` | Done state |
| `IPDefaultError.riv` | Error state |
| `IPDefaultAuthorization.riv` | Authorization state |
| `IPDefaultNotification.riv` | Notification state |
| `IPDefaultBackgroundHint.riv` | Background hint |
| `IPDefaultAcknowledge.riv` | Acknowledge |
| `IPDefaultTyping.riv` | Typing state |
| `IPDefaultWaveform.riv` | Waveform |
| `IPDefaultSparkle.riv` | Sparkle effect |
| `IPDefaultHelp.riv` | Help state |

---

*Extracted via `strings` analysis of INVOKO.app binary*
