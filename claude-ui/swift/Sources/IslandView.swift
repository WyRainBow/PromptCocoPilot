import SwiftUI

// MARK: - Palette
// The notch is physically black, so the island background must be black to merge
// into it (codex-island fills .black). Blue is used only as the accent.

private enum Theme {
    static let accent     = Color(red: 0.23, green: 0.51, blue: 0.96)   // #3b82f6
    static let accentDeep = Color(red: 0.15, green: 0.39, blue: 0.92)   // #2563eb
    static let bodyTint   = Color(red: 0.04, green: 0.06, blue: 0.13)   // dark navy (below the notch)
    static let surface    = Color(red: 0.08, green: 0.11, blue: 0.19)
    static let stroke     = Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.30)
    static let text       = Color(red: 0.90, green: 0.93, blue: 0.99)
    static let muted      = Color(red: 0.52, green: 0.58, blue: 0.70)
    static let result     = Color(red: 0.55, green: 0.80, blue: 1.0)
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
        .animation(.easeInOut(duration: 0.18), value: state.expanded)
        .animation(.easeInOut(duration: 0.15), value: state.contextOpen)
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
        // Small movement = tap (toggle); larger = drag the card out of the notch.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if abs(v.translation.width) > 4 || abs(v.translation.height) > 4 {
                        state.dragBy(v.translation)
                    }
                }
                .onEnded { v in
                    if abs(v.translation.width) < 5 && abs(v.translation.height) < 5 {
                        state.toggle()
                    } else {
                        state.dragEnd()
                    }
                }
        )
    }

    // MARK: expanded card body (below the notch)

    private var expandedBody: some View {
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

            editor(text: $state.result,
                   placeholder: "增强结果会显示在这里…",
                   minHeight: 80, color: Theme.result, readOnly: true)

            Button(action: state.applyAndClose) {
                Text("✓ 应用并关闭").frame(maxWidth: .infinity)
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
            Menu {
                ForEach(state.sessions) { s in
                    Button(s.menuLabel) { state.selectSession(s.cwd) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentSessionLabel)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.muted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(fieldBg)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

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
