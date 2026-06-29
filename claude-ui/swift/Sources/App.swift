import Cocoa
import SwiftUI
import Combine
import Carbon.HIToolbox

// MARK: - Entry point (accessory app, no Dock icon)

@main
enum PromptCocoApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // LSUIElement equivalent: no Dock icon
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: IslandWindowController?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let c = IslandWindowController()
        c.show()
        controller = c

        // Global ⌃⌥⌘P — pull the card out of the notch from anywhere.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_P),
                        modifiers: UInt32(controlKey | optionKey | cmdKey)) { [weak c] in
            MainActor.assumeIsolated { c?.summon() }
        }
    }
}

// MARK: - Notch geometry

/// Physical notch dimensions of the active screen, so the island can flank the
/// camera instead of hiding content behind it (codex-island reads this too).
struct NotchInfo: Equatable {
    var width: CGFloat
    var height: CGFloat

    static let fallback = NotchInfo(width: 185, height: 32)

    static func detect(_ screen: NSScreen) -> NotchInfo {
        let h = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 32
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let w = screen.frame.width - left.width - right.width
            return NotchInfo(width: max(120, w), height: h)
        }
        return NotchInfo(width: 185, height: h)
    }
}

// MARK: - Shared state

@MainActor
final class AppState: ObservableObject {
    @Published var expanded = false
    @Published var notch = NotchInfo.fallback
    @Published var sessions: [SessionInfo] = []
    @Published var selectedCwd = ""
    @Published var preview: [PreviewItem] = []
    @Published var contextOpen = false
    @Published var draft = ""
    @Published var result = ""
    @Published var status = ""
    @Published var statusKind: StatusKind = .neutral
    @Published var busy = false

    private var conversation: [Turn] = []

    enum StatusKind { case neutral, ok, error }

    /// Called after `expanded` changes so the window can resize + re-dock.
    var onResize: (() -> Void)?
    /// Window-origin accessors so the header can drag the card (Invoko-style).
    var getOrigin: (() -> CGPoint)?
    var setOrigin: ((CGPoint) -> Void)?
    private var dragAnchor: CGPoint?

    /// Move the window by a SwiftUI drag translation (y is flipped vs Cocoa).
    func dragBy(_ t: CGSize) {
        if dragAnchor == nil { dragAnchor = getOrigin?() }
        guard let a = dragAnchor else { return }
        setOrigin?(CGPoint(x: a.x + t.width, y: a.y - t.height))
    }
    func dragEnd() { dragAnchor = nil }

    var canApply: Bool { !result.isEmpty }
    var contextCount: Int { preview.count }
    var sessionLabel: String {
        sessions.first(where: { $0.cwd == selectedCwd })?.name ?? "优化输入"
    }

    func collapse() {
        expanded = false
        onResize?()
    }

    /// Expand, refresh sessions, and seed draft from the clipboard selection.
    func expand() {
        expanded = true
        onResize?()
        refreshSessions()
        let sel = Selection.current().trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.isEmpty, !sel.isEmpty, sel.count < 500 { draft = sel }
    }

    func toggle() { expanded ? collapse() : expand() }

    func refreshSessions() {
        sessions = SessionReader.list()
        if sessions.first(where: { $0.cwd == selectedCwd }) == nil {
            selectedCwd = sessions.first?.cwd ?? ""
        }
        loadContext()
    }

    /// Called when the picker changes.
    func selectSession(_ cwd: String) {
        selectedCwd = cwd
        loadContext()
    }

    private func loadContext() {
        guard !selectedCwd.isEmpty else { conversation = []; preview = []; return }
        let ctx = SessionReader.context(cwd: selectedCwd)
        conversation = ctx.turns
        preview = ctx.preview
    }

    func enhance() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return setStatus("请先输入草稿", .error) }
        busy = true
        setStatus("", .neutral)
        Task {
            do {
                let out = try await EnhanceClient.enhance(
                    draft: text, conversation: conversation)
                result = out
                setStatus("✓ 增强完成", .ok)
            } catch {
                setStatus("⚠ \(error.localizedDescription)", .error)
            }
            busy = false
        }
    }

    func applyAndClose() {
        guard canApply else { return }
        let out = result
        collapse()
        Selection.replace(with: out)
    }

    func setStatus(_ msg: String, _ kind: StatusKind) {
        status = msg
        statusKind = kind
    }
}

// MARK: - Keyable borderless window
// Borderless windows can't become key by default, so TextEditor would never
// receive keystrokes. Override to allow focus + first responder.

final class IslandWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// AppKit normally pushes windows down so they don't overlap the menu bar /
    /// notch. Returning the rect unchanged lets us sit flush over the notch.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// NSHostingView reserves the notch's safe area by default, which pushes the
/// SwiftUI content one notch-height below the top — making the island look like
/// it floats *below* the notch. Forcing zero insets lets the black background
/// draw all the way under the notch so it merges into it.
final class NoInsetHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
}

// MARK: - Window controller (notch-native, frameless, on-top)

@MainActor
final class IslandWindowController {
    let window: IslandWindow
    let state = AppState()

    init() {
        let frame = NSRect(x: 0, y: 0, width: 200, height: 36)
        let w = IslandWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .popUpMenu          // codex-island uses this — above the menu bar / notch
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.hasShadow = false           // the IslandShape defines the silhouette itself
        // codex-island keeps isMovable = false so AppKit never pushes the window
        // down below the menu bar. We drag manually instead (see state.drag*).
        w.isMovable = false
        w.isReleasedWhenClosed = false
        let host = NoInsetHostingView(rootView: IslandRoot().environmentObject(state))
        if #available(macOS 14.0, *) { host.safeAreaRegions = [] }
        w.contentView = host
        window = w
        state.onResize = { [weak self] in self?.applySize() }
        // Manual-drag hooks — let the SwiftUI header pull the card out of the notch.
        state.getOrigin = { [weak w] in w?.frame.origin ?? .zero }
        state.setOrigin = { [weak w] p in w?.setFrameOrigin(p) }
    }

    /// Island is a fixed width; only the height changes between states. Collapsed
    /// height equals the notch height so the bar lives inside the menu-bar band.
    private func sizeFor(_ expanded: Bool) -> (CGFloat, CGFloat) {
        expanded ? (380, 470) : (380, max(28, state.notch.height))
    }

    func show() {
        dockToNotch()
        window.orderFront(nil)
    }

    /// Initial placement: top-center of the notched screen.
    /// Cocoa origin is bottom-left, so y = screen_top - h sits flush with the top.
    private func dockToNotch() {
        guard let screen = notchScreen() else { return }
        state.notch = NotchInfo.detect(screen)   // measure before sizing
        let sf = screen.frame
        let (w, h) = sizeFor(state.expanded)
        let x = sf.origin.x + (sf.width - w) / 2
        let y = sf.origin.y + sf.height - h
        window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    /// Re-dock the card back into the notch (used by the hotkey / double-purpose).
    func resetToNotch() { dockToNotch() }

    /// Bring the card forward, expand it, and focus for typing.
    func summon() {
        NSApp.activate(ignoringOtherApps: true)
        if !state.expanded { state.expand() }
        window.makeKeyAndOrderFront(nil)
    }

    /// Resize *in place* — keep the card anchored where the user dragged it
    /// (top edge + horizontal center fixed), growing downward when expanded.
    func applySize() {
        let (w, h) = sizeFor(state.expanded)
        let cur = window.frame
        let x = cur.midX - w / 2
        let y = cur.maxY - h
        window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: true)
        if state.expanded {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
        }
    }

    /// Prefer the first screen whose safe-area inset indicates a physical notch.
    private func notchScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: {
            $0.auxiliaryTopLeftArea != nil || $0.safeAreaInsets.top > 0
        }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

// MARK: - Global hotkey (Carbon RegisterEventHotKey — works without AX permission)

final class HotKey {
    private var ref: EventHotKeyRef?
    private let handler: () -> Void
    private static var registry: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1
    private let id: UInt32

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        self.id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.registry[id] = self

        HotKey.installHandlerOnce()
        let hotKeyID = EventHotKeyID(signature: OSType(0x50434f49), id: id) // 'PCOI'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(),
                            0, &ref)
    }

    deinit { if let ref { UnregisterEventHotKey(ref) } }

    fileprivate static func fire(_ id: UInt32) { registry[id]?.handler() }

    private static var handlerInstalled = false
    private static func installHandlerOnce() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            DispatchQueue.main.async { HotKey.fire(hkID.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
