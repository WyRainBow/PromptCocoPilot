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
        VStack(spacing: 0) {
            headerBar
            if state.expanded { expandedBody }
        }
        .background(background)
        .clipShape(islandShape)
        .ignoresSafeArea(.all)   // draw under the notch, not below it
        .animation(.easeOut(duration: 0.16), value: state.contextOpen)
    }

    /// Square top (flush with the notch / screen edge), rounded bottom, squircle.
    private var islandShape: UnevenRoundedRectangle {
        let r: CGFloat = state.expanded ? 18 : 11
        return UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: r,
            bottomTrailingRadius: r, topTrailingRadius: 0,
            style: .continuous)
    }

    /// Pure black at the very top so it disappears into the notch, easing into a
    /// dark navy below — keeps the "blue系" feel without breaking the merge.
    private var background: some View {
        islandShape.fill(
            LinearGradient(colors: [.black, .black, Theme.bodyTint],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: header — lives in the menu-bar band, flanking the camera

    private var headerBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("✨").font(.system(size: 13))
                Text(state.expanded ? state.sessionLabel : "优化输入")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Transparent gap exactly the width of the physical notch / camera.
            Color.clear.frame(width: state.notch.width)

            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 6, height: 6)
                    .shadow(color: Theme.accent, radius: 3)
                Image(systemName: state.expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.muted)
            }
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: max(28, state.notch.height))
        .contentShape(Rectangle())
        // Double-click toggles. Dragging is handled by a controller-level NSEvent
        // monitor (absolute mouse position) — a SwiftUI DragGesture jitters here
        // because its translation is relative to the window that's being moved.
        .onTapGesture(count: 2) { state.toggle() }
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
        VStack(alignment: .leading, spacing: 9) {
            sessionPicker
            contextViewer

            editor(text: $state.draft,
                   placeholder: "输入想发送给 Claude 的草稿，或按 ⌃⌥⌘P 抓取选中…",
                   minHeight: 58, color: Theme.text)

            Button(action: state.enhance) {
                HStack(spacing: 6) {
                    if state.busy { ProgressView().controlSize(.small).tint(.white) }
                    Text(state.busy ? "增强中…" : "▶ 增强")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButton(kind: .primary))
            .disabled(state.busy)

            if !state.status.isEmpty {
                Text(state.status)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Result is editable — tweak the enhanced text before / between applies.
            editor(text: $state.result,
                   placeholder: "增强结果会显示在这里（可编辑）…",
                   minHeight: 80, color: Theme.result)

            Button(action: state.apply) {
                Text("✓ 应用").frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButton(kind: .secondary))
            .disabled(!state.canApply)
        }
        .padding(.horizontal, 13)
        .padding(.bottom, 13)
        .padding(.top, 4)
    }

    // MARK: session picker

    private var sessionPicker: some View {
        HStack(spacing: 6) {
            Button { state.sessionListOpen.toggle() } label: {
                HStack(spacing: 6) {
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
        state.sessions.first(where: { $0.cwd == state.selectedCwd })?.menuLabel
            ?? (state.sessions.isEmpty ? "无活跃会话" : "选择会话")
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
        let selected = s.cwd == state.selectedCwd
        return Button { state.selectSession(s.cwd) } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(s.status == "busy" ? Color.red : Theme.muted.opacity(0.4))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Text("\(s.pathTail) · \(s.ago) · \(s.messageCount)条")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
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
            Button { state.contextOpen.toggle() } label: {
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
                        minHeight: CGFloat, color: Color,
                        readOnly: Bool = false) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
            }
            TextEditor(text: text)
                .font(.system(size: 11))
                .foregroundColor(color)
                .scrollContentBackgroundCompat()
                .disabled(readOnly)
                .frame(minHeight: minHeight)
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
        }
        .background(fieldBg)
    }
}

// MARK: - Button style

private struct PillButton: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(kind == .primary ? .white : Theme.text)
            .padding(.vertical, 9)
            .background(background(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .opacity(enabled ? 1 : 0.4)
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
            Theme.accent.opacity(pressed ? 0.22 : 0.12)
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
