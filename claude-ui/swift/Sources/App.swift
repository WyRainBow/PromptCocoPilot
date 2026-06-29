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
        installMainMenu()   // gives text fields Cmd+A/C/V/X/Z shortcuts

        let c = IslandWindowController()
        c.show()
        controller = c

        // Global ⌃⌥⌘P — pull the card out of the notch from anywhere.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_P),
                        modifiers: UInt32(controlKey | optionKey | cmdKey)) { [weak c] in
            MainActor.assumeIsolated { c?.summon() }
        }
    }

    /// Standard Edit-menu key equivalents so the text fields support
    /// Cmd+A/C/V/X/Z. Accessory apps show no menu bar, but the key equivalents
    /// still route to the first responder (the focused TextEditor).
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出优化输入",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
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
    @Published var selectedId = ""
    @Published var preview: [PreviewItem] = []
    @Published var contextOpen = false
    @Published var sessionListOpen = false
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
    /// Refocus the app the user was in before the island, so ⌘V lands there.
    var activatePrevApp: (() -> Void)?
    /// Bring focus back to the island after a paste (keep editing).
    var refocusIsland: (() -> Void)?
    /// Suppresses collapse-on-deactivate during the apply focus dance.
    var isApplying = false

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
        sessions.first(where: { $0.id == selectedId })?.name ?? "优化输入"
    }
    var selectedSession: SessionInfo? { sessions.first(where: { $0.id == selectedId }) }

    func collapse() {
        expanded = false
        sessionListOpen = false
        onResize?()
    }

    /// Expand instantly: flip state + resize now, then load sessions off the main
    /// thread so reading large session JSONLs never blocks the panel opening.
    func expand() {
        expanded = true
        onResize?()
        let sel = Selection.current().trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.isEmpty, !sel.isEmpty, sel.count < 500 { draft = sel }
        refreshSessions()
    }

    func toggle() { expanded ? collapse() : expand() }

    func refreshSessions() {
        Task { [weak self] in
            let list = await Task.detached { SessionReader.list() }.value
            guard let self else { return }
            self.sessions = list
            if self.sessions.first(where: { $0.id == self.selectedId }) == nil {
                self.selectedId = self.sessions.first?.id ?? ""
            }
            self.loadContext()
        }
    }

    /// Called when the picker changes.
    func selectSession(_ id: String) {
        selectedId = id
        sessionListOpen = false
        loadContext()
    }

    private func loadContext() {
        guard let s = selectedSession else { conversation = []; preview = []; return }
        let logPath = s.logPath, agent = s.agent, id = s.id
        Task { [weak self] in
            let ctx = await Task.detached {
                SessionReader.context(logPath: logPath, agent: agent)
            }.value
            guard let self, self.selectedId == id else { return }
            self.conversation = ctx.turns
            self.preview = ctx.preview
        }
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

    /// Paste the (possibly edited) result into the app the user came from, but
    /// keep the island open so they can tweak and apply again.
    func apply() {
        guard canApply else { return }
        isApplying = true                  // don't let the focus switch collapse us
        activatePrevApp?()                 // give focus back so ⌘V lands there
        Selection.replace(with: result)
        setStatus("✓ 已应用（可继续修改后再次应用）", .ok)
        // After the paste lands, take focus back so the user can keep editing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            MainActor.assumeIsolated {
                self?.refocusIsland?()
                self?.isApplying = false
            }
        }
    }

    func setStatus(_ msg: String, _ kind: StatusKind) {
        status = msg
        statusKind = kind
    }
}

// MARK: - Keyable nonactivating panel (CodeIsland pattern)
// An NSPanel with .nonactivatingPanel sits on top WITHOUT stealing focus from
// the user's terminal. A regular NSWindow activates the app on every click —
// the source of the click-delay and focus problems. canBecomeKey still lets the
// text fields receive typing once the user clicks into them.

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Hosting view tuned for the notch:
/// - zero safe-area insets so the black background draws *under* the notch
///   (otherwise SwiftUI reserves the notch and the island floats below it),
/// - acceptsFirstMouse + mouseDown→makeKey so the first click registers without
///   first activating the app,
/// - deferred needsUpdateConstraints / needsLayout to dodge an AppKit display-
///   cycle re-entrancy crash (lifted from CodeIsland's NotchHostingView).
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    private var applyingDeferred = false

    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }

    override var needsUpdateConstraints: Bool {
        get { super.needsUpdateConstraints }
        set {
            if applyingDeferred { super.needsUpdateConstraints = newValue; return }
            DispatchQueue.main.async { [weak self] in self?.applyConstraints(newValue) }
        }
    }
    private func applyConstraints(_ v: Bool) {
        applyingDeferred = true; super.needsUpdateConstraints = v; applyingDeferred = false
    }

    override var needsLayout: Bool {
        get { super.needsLayout }
        set {
            if applyingDeferred { super.needsLayout = newValue; return }
            DispatchQueue.main.async { [weak self] in self?.applyLayout(newValue) }
        }
    }
    private func applyLayout(_ v: Bool) {
        applyingDeferred = true; super.needsLayout = v; applyingDeferred = false
    }
}

// MARK: - Panel controller (notch-attached, nonactivating, on-top)

@MainActor
final class IslandWindowController {
    let panel: KeyablePanel
    let state = AppState()
    private var lastApp: NSRunningApplication?
    private var globalClickMonitor: Any?
    private var dragMonitor: Any?
    private var dragStartMouseX: CGFloat?
    private var dragStartPanelX: CGFloat?
    private var isDraggingPanel = false

    init() {
        let size = NSSize(width: 380, height: 32)
        let p = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        // Above the menu bar / notch, like CodeIsland.
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NotchHostingView(rootView: IslandRoot().environmentObject(state))
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = true
        if #available(macOS 14.0, *) { host.safeAreaRegions = [] }
        p.contentView = host
        panel = p

        state.onResize = { [weak self] in self?.applySize() }
        state.getOrigin = { [weak p] in p?.frame.origin ?? .zero }
        state.setOrigin = { [weak self] pt in self?.moveHorizontally(to: pt.x) }
        state.refocusIsland = { [weak p] in p?.makeKey() }

        // Track the last external app so "应用" can refocus it before ⌘V.
        let selfPID = ProcessInfo.processInfo.processIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication, app.processIdentifier != selfPID else { return }
            MainActor.assumeIsolated { self?.lastApp = app }
        }
        state.activatePrevApp = { [weak self] in
            guard let app = self?.lastApp else { return }
            if #available(macOS 14.0, *) { app.activate() }
            else { app.activate(options: [.activateIgnoringOtherApps]) }
        }

        // A nonactivating panel never gets didResignActive, so watch global
        // clicks: click outside the panel while expanded → collapse.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.expanded, !self.state.isApplying else { return }
                if self.panel.frame.contains(NSEvent.mouseLocation) { return }
                self.state.collapse()
            }
        }

        // Horizontal drag via absolute mouse position (smooth — a SwiftUI
        // DragGesture jitters because its translation re-references the moving
        // window). Lifted from CodeIsland's setupHorizontalDragMonitor.
        dragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.handleDrag(event) }
            return event
        }
    }

    private func handleDrag(_ event: NSEvent) {
        let threshold: CGFloat = 5
        switch event.type {
        case .leftMouseDown:
            if event.window === panel {
                dragStartMouseX = NSEvent.mouseLocation.x
                dragStartPanelX = panel.frame.origin.x
                isDraggingPanel = false
            }
        case .leftMouseDragged:
            guard let startMouseX = dragStartMouseX, let startPanelX = dragStartPanelX else { return }
            let deltaX = NSEvent.mouseLocation.x - startMouseX
            if !isDraggingPanel {
                guard abs(deltaX) > threshold else { return }
                isDraggingPanel = true
            }
            moveHorizontally(to: startPanelX + deltaX)
        case .leftMouseUp:
            dragStartMouseX = nil
            dragStartPanelX = nil
            isDraggingPanel = false
        default:
            break
        }
    }

    func show() {
        applyFrame(center: true)
        panel.orderFrontRegardless()
    }

    /// Hotkey summon — show, expand, focus for typing.
    func summon() {
        if !state.expanded { state.expand() }
        applyFrame(center: false)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func resetToNotch() { applyFrame(center: true) }

    private func sizeFor(_ expanded: Bool) -> NSSize {
        NSSize(width: 380, height: expanded ? 470 : max(28, state.notch.height))
    }

    /// Keep the panel attached to the very top of the notch screen. `center`
    /// re-centers horizontally; otherwise the current x (dragged) is preserved.
    private func applyFrame(center: Bool) {
        let screen = notchScreen()
        state.notch = NotchInfo.detect(screen)
        let size = sizeFor(state.expanded)
        let sf = screen.frame
        let midX = center ? sf.midX : panel.frame.midX
        let x = min(max(midX - size.width / 2, sf.minX), sf.maxX - size.width)
        let y = sf.maxY - size.height          // flush with the top
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height),
                       display: true)
    }

    func applySize() {
        applyFrame(center: false)
        if state.expanded { panel.makeKey() }
    }

    /// Horizontal-only drag — the island stays glued to the top edge.
    private func moveHorizontally(to x: CGFloat) {
        let sf = notchScreen().frame
        let w = panel.frame.width
        let clampedX = min(max(x, sf.minX), sf.maxX - w)
        let y = sf.maxY - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: clampedX, y: y))
    }

    /// Prefer the screen with a physical notch; else main.
    private func notchScreen() -> NSScreen {
        if let notched = NSScreen.screens.first(where: {
            $0.auxiliaryTopLeftArea != nil || $0.safeAreaInsets.top > 0
        }) { return notched }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
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
