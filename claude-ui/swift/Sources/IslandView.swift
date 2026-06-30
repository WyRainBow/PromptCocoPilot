import SwiftUI

// MARK: - Palette
// The notch is physically black, so the island background must be black to merge
// into it (codex-island fills .black). Blue is used only as the accent.

private enum Theme {
    static let accent     = Color(red: 0.30, green: 0.56, blue: 1.0)    // clean blue #4d8eff
    static let accentDeep = Color(red: 0.18, green: 0.42, blue: 0.95)
    // Near-black neutral so it merges with the notch and looks premium, not a
    // saturated navy slab. Blue is the accent only.
    static let bodyTint   = Color(red: 0.055, green: 0.06, blue: 0.075)
    static let surface    = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let surfaceHi  = Color(red: 0.14, green: 0.15, blue: 0.17)
    static let stroke     = Color.white.opacity(0.08)
    static let text       = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let muted      = Color(red: 0.55, green: 0.58, blue: 0.64)
    static let result     = Color(red: 0.62, green: 0.78, blue: 1.0)
}

struct IslandRoot: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        content
            .frame(width: frameWidth)
            .fixedSize(horizontal: false, vertical: true)
            .background(cardBackground)
            .clipShape(clipShape)
            .ignoresSafeArea(.all)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
            })
            .onPreferenceChange(HeightKey.self) { state.reportHeight($0) }
            // Absorb feel: content scales toward the notch + fades as it docks,
            // coordinated with the window's bouncy frame animation.
            .animation(.spring(response: 0.34, dampingFraction: 0.74), value: state.presence)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.dockPreview)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: state.notchHovered)
    }

    @ViewBuilder
    private var content: some View {
        if state.dockPreview {
            dockingPreview.transition(absorbTransition)
        } else {
            switch state.presence {
            case .floating: cloudFloating.transition(absorbTransition)
            case .docked:   residentDocked.transition(absorbTransition)
            case .expanded: VStack(spacing: 0) { cardHeader; expandedBody }.transition(.opacity)
            }
        }
    }

    /// Shrink-toward-the-notch + fade — the "sucked into the notch" transition.
    private var absorbTransition: AnyTransition {
        .scale(scale: 0.35, anchor: .top).combined(with: .opacity)
    }

    private var frameWidth: CGFloat {
        if state.dockPreview { return 320 }
        switch state.presence {
        case .floating: return 140
        case .docked:   return state.notchHovered ? 330 : 290
        case .expanded: return 380
        }
    }

    // MARK: fold-cue preview — cloud snapped to the notch with a soft blue glow

    private var dockingPreview: some View {
        let nh = max(24, state.notch.height)
        return ZStack(alignment: .top) {
            // Wide soft halo …
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.55, green: 0.78, blue: 1.0).opacity(0.5),
                    Color(red: 0.55, green: 0.78, blue: 1.0).opacity(0.0),
                ]),
                center: .center, startRadius: 0, endRadius: 120)
                .frame(width: 290, height: 165)
                .blur(radius: 20)
                .offset(y: nh)

            // … plus a brighter white-blue core for a luminous "absorb" feel.
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.82, green: 0.91, blue: 1.0).opacity(0.75),
                    Color(red: 0.82, green: 0.91, blue: 1.0).opacity(0.0),
                ]),
                center: .center, startRadius: 0, endRadius: 56)
                .frame(width: 150, height: 100)
                .blur(radius: 9)
                .offset(y: nh + 6)

            // Cloud sitting in the notch band, centered.
            RiveCloudView()
                .frame(width: 46, height: 32)
                .frame(maxWidth: .infinity)
                .frame(height: nh)
        }
        .frame(maxWidth: .infinity)
        .frame(height: nh + 78)
    }

    // MARK: floating cloud (free on the desktop) — double-click to expand

    private var cloudFloating: some View {
        RiveCloudView()
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .frame(width: 140, height: 96)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { state.toggleExpand() }
    }

    // MARK: resident cloud (docked in the notch) — drag down to pull out

    private var residentDocked: some View {
        let nh = max(24, state.notch.height)
        let hovered = state.notchHovered
        // Wide thin bar: cloud flanks the camera on the left, dot on the right.
        return HStack(spacing: 0) {
            RiveCloudView()
                .frame(width: hovered ? 46 : 38, height: hovered ? 30 : 25)
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: state.notch.width)   // clear the camera

            Circle()
                .fill(Theme.accent.opacity(0.85))
                .frame(width: 6, height: 6)
                .shadow(color: Theme.accent.opacity(0.7), radius: 3)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: nh + (hovered ? 12 : 6))
        .contentShape(Rectangle())
        .onHover { state.setNotchHover($0) }       // hover → expand the box
        .onTapGesture(count: 2) { state.toggleExpand() }
    }

    // MARK: shape + background per presence
    // Floating cloud = no card chrome (transparent, cloud floats). Docked /
    // docked-expanded = square top to merge with the notch. Floating-expanded =
    // a rounded floating card with a shadow.

    private var floatingCard: Bool { state.isExpanded && !state.expandedFromDock }

    private var islandShape: UnevenRoundedRectangle {
        let topRounded = floatingCard
        let r: CGFloat = state.isExpanded ? 18 : 14
        return UnevenRoundedRectangle(
            topLeadingRadius: topRounded ? r : 0, bottomLeadingRadius: r,
            bottomTrailingRadius: r, topTrailingRadius: topRounded ? r : 0,
            style: .continuous)
    }

    private var clipShape: AnyShape {
        state.isFloating ? AnyShape(Rectangle()) : AnyShape(islandShape)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if state.isFloating {
            Color.clear
        } else {
            islandShape
                .fill(LinearGradient(colors: [.black, .black, Theme.bodyTint],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: floatingCard ? .black.opacity(0.5) : .clear,
                        radius: floatingCard ? 22 : 0, y: floatingCard ? 8 : 0)
        }
    }

    // MARK: card header (top of the expanded card)

    private var cardHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                RiveCloudView().frame(width: 38, height: 26)
                Text(state.sessionLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Reserve the camera only when the card grows from the notch.
            if state.expandedFromDock {
                Color.clear.frame(width: state.notch.width)
            }

            Button { state.collapse() } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.muted)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: state.expandedFromDock ? max(28, state.notch.height) : 32)
        .contentShape(Rectangle())
    }

    // MARK: expanded card body (below the notch)

    private var expandedBody: some View {
        ZStack(alignment: .top) {
            cardContent
            if state.sessionListOpen {
                sessionDropdown
                    .padding(.horizontal, 13)
                    .padding(.top, 36)   // just below the picker row
                    .zIndex(10)
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            sessionPicker
            contextViewer

            fieldLabel("草稿")
            editor(text: $state.draft,
                   placeholder: "输入想发送给 Claude 的草稿，或按 ⌃⌥⌘P 抓取选中…",
                   height: 76, color: Theme.text)

            Button(action: state.enhance) {
                HStack(spacing: 6) {
                    if state.busy {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                    }
                    Text(state.busy ? "增强中…" : "增强")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButton(kind: .primary))
            .disabled(state.busy)

            Text(state.status.isEmpty ? " " : state.status)
                .font(.system(size: 10))
                .foregroundColor(statusColor)
                .frame(maxWidth: .infinity, minHeight: 12, alignment: .center)

            // Result is editable — tweak the enhanced text before / between applies.
            fieldLabel("结果")
            editor(text: $state.result,
                   placeholder: "增强结果会显示在这里（可编辑）…",
                   height: 100, color: Theme.result)

            Button(action: state.apply) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                    Text("应用")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButton(kind: .secondary))
            .disabled(!state.canApply)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 6)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(Theme.muted.opacity(0.8))
            .padding(.leading, 2)
            .padding(.bottom, -4)
    }

    // MARK: session picker

    private var sessionPicker: some View {
        HStack(spacing: 6) {
            Button { state.sessionListOpen.toggle() } label: {
                HStack(spacing: 6) {
                    if let s = state.selectedSession { agentBadge(s.agent) }
                    Text(currentSessionLabel)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .rotationEffect(.degrees(state.sessionListOpen ? 180 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(fieldBg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: state.refreshSessions) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 26, height: 26)
                    .background(fieldBg)
            }
            .buttonStyle(.plain)
        }
    }

    private var currentSessionLabel: String {
        state.selectedSession?.menuLabel
            ?? (state.sessions.isEmpty ? "无活跃会话" : "选择会话")
    }

    /// Small colored tag showing which agent a session belongs to.
    private func agentBadge(_ agent: AgentKind) -> some View {
        let tint: Color
        switch agent {
        case .claude: tint = Color(red: 1.0, green: 0.72, blue: 0.38)   // orange
        case .codex:  tint = Color(red: 0.40, green: 0.85, blue: 0.60)  // green
        case .qoder:  tint = Color(red: 0.70, green: 0.58, blue: 1.0)   // purple
        }
        return Text(agent.rawValue)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.16)))
    }

    // MARK: custom dark dropdown (replaces the light native Menu)

    private var sessionDropdown: some View {
        ScrollView {
            VStack(spacing: 2) {
                if state.sessions.isEmpty {
                    Text("无活跃会话")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                ForEach(state.sessions) { s in sessionRow(s) }
            }
            .padding(5)
        }
        .frame(maxHeight: 230)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.surfaceHi)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
        )
    }

    private func sessionRow(_ s: SessionInfo) -> some View {
        let selected = s.id == state.selectedId
        return Button { state.selectSession(s.id) } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(s.status == "busy" ? Color.red : Theme.muted.opacity(0.4))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        agentBadge(s.agent)
                        Text(s.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Text("\(s.pathTail) · \(s.ago) · \(s.messageCount)条")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                        Text(s.sid)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundColor(Theme.muted.opacity(0.6))
                    }
                }
                Spacer(minLength: 4)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(selected ? Theme.accent.opacity(0.18) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: compressed-context viewer

    private var contextViewer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { state.toggleContext() } label: {
                HStack(spacing: 5) {
                    Text("📂 压缩的上下文")
                    Spacer()
                    Text("\(state.contextCount) 条已压缩")
                    Image(systemName: state.contextOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 10))
                .foregroundColor(Theme.muted)
            }
            .buttonStyle(.plain)

            if state.contextOpen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(state.preview) { item in
                            HStack(alignment: .top, spacing: 5) {
                                Text(item.role == "user" ? "👤" : "🤖")
                                    .font(.system(size: 9))
                                Text(item.snippet)
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.muted)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(formatTs(item.ts))
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.muted.opacity(0.6))
                            }
                            .padding(.vertical, 2)
                            Divider().background(Color.white.opacity(0.05))
                        }
                        if state.preview.isEmpty {
                            Text("无上下文")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 92)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.35)))
            }
        }
    }

    private func formatTs(_ ts: String) -> String {
        guard !ts.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = iso.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
        else { return "" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    // MARK: shared bits

    private var statusColor: Color {
        switch state.statusKind {
        case .ok: return Theme.accent
        case .error: return Color(red: 0.96, green: 0.45, blue: 0.45)
        case .neutral: return Theme.muted
        }
    }

    private var fieldBg: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private func editor(text: Binding<String>, placeholder: String,
                        height: CGFloat, color: Color,
                        readOnly: Bool = false) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted.opacity(0.65))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 9)
            }
            TextEditor(text: text)
                .font(.system(size: 11.5))
                .foregroundColor(color)
                .scrollContentBackgroundCompat()
                .disabled(readOnly)
                .frame(height: height)
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
        }
        .background(fieldBg)
        .overlay(alignment: .topTrailing) {
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.muted.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("清空")
                .padding(6)
            }
        }
    }
}

// MARK: - Content height reporting

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Button style

private struct PillButton: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundColor(kind == .primary ? .white : Theme.accent)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(background(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(kind == .secondary ? Theme.accent.opacity(0.35) : Color.clear,
                            lineWidth: 1)
            )
            .shadow(color: kind == .primary ? Theme.accent.opacity(enabled ? 0.35 : 0) : .clear,
                    radius: 8, y: 3)
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch kind {
        case .primary:
            LinearGradient(
                colors: pressed ? [Theme.accentDeep, Theme.accentDeep]
                                : [Theme.accent, Theme.accentDeep],
                startPoint: .top, endPoint: .bottom)
        case .secondary:
            Theme.accent.opacity(pressed ? 0.20 : 0.10)
        }
    }
}

// MARK: - Compat: hide TextEditor's default background pre-macOS 14

private extension View {
    @ViewBuilder
    func scrollContentBackgroundCompat() -> some View {
        if #available(macOS 14.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
