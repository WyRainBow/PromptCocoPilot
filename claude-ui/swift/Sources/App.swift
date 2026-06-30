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

// MARK: - Mascot animation state (which .riv the cloud plays)
//
// Invoko's cloud mascot supports 15 animation states across the full AI interaction
// lifecycle. Each state maps to an IPDefault*.riv artboard + Rive state machine.
// Internal cloud components (cloud, eyes, blink, hand/handL/handR, planet, bulb)
// animate autonomously per the Rive state machine inside each .riv file.
//
// State transitions follow NotchStateMachine.md invariants:
//   idle → typing → listening → routing → outputting → done → idle
//   error, authorization, recording, notification, help are orthogonal branches.

enum MascotState: Equatable, CaseIterable {
    // ── Core lifecycle ──────────────────────────────────────────────────
    case idle          // blinking cloud, no activity
    case thinking      // eyes open, loading with no stream output
    case routing       // planet in motion, loading, no output yet
    case listening     // eyes + raised hand, voice capture active
    case outputting    // eyes + hand, streaming output
    case done          // firework burst, task complete
    case error         // cloud alone, something went wrong

    // ── Input branch ────────────────────────────────────────────────────
    case typing        // hands raised, input box visible

    // ── Authorization branch ───────────────────────────────────────────
    case authorization // authorization request pending

    // ── Notification / background ───────────────────────────────────────
    case recording     // waveform/mic bars, voice recording
    case notification  // notification pulse
    case sparkle       // backend agent sparkle burst

    // ── UI feedback ─────────────────────────────────────────────────────
    case acknowledge    // transient confirmation (PP Neue Montreal font)
    case backgroundHint // idle background hint
    case help           // help/debug artboard
}

// MARK: - Shared state

@MainActor
final class AppState: ObservableObject {
    /// Cloud presence: floating on the desktop, docked into the notch, or the
    /// expanded optimize card. (Invoko-style.)
    enum Presence { case floating, docked, expanded }
    @Published var presence: Presence = .floating
    /// Fold-cue: while dragging a floating cloud into the notch zone, the island
    /// previews docking (snapped to the notch + blue glow). Release commits, drag
    /// away cancels. Presence stays .floating until committed.
    @Published var dockPreview = false
    /// Hovering the docked notch expands it into the wider rounded box.
    @Published var notchHovered = false
    /// Whether the card was opened from the docked (notch) anchor vs the floating cloud.
    var expandedFromDock = false
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

    // ── Context-aware reply suggestions (Invoko-style) ────────────────────
    @Published var suggestions: [String] = []
    @Published var contextSummary: String = ""
    @Published var suggestionsLoading = false
    @Published var suggestionsOpen = false

    /// Drives which cloud .riv plays — backed by the state machine.
    @Published private(set) var mascot: MascotState = .idle

    /// Full 15-state lifecycle machine. `mascot` mirrors `mascotSM.state`.
    let mascotSM = MascotStateMachine()

    private var mascotCancellable: AnyCancellable?
    private var draftCancellables = Set<AnyCancellable>()

    init() {
        // Mirror mascotSM state → published mascot so SwiftUI views observe changes.
        mascotCancellable = mascotSM.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in self?.mascot = s }

        // Detect typing in the draft field → cloud raises hands.
        $draft
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else { return }
                if !text.isEmpty && !self.busy && self.mascot != .typing {
                    self.mascotSM.startTyping()
                } else if text.isEmpty && !self.busy && self.mascot == .typing {
                    self.mascotSM.goIdle()
                }
            }
            .store(in: &draftCancellables)
    }

    private var conversation: [Turn] = []

    enum StatusKind { case neutral, ok, error }

    /// Called after `expanded` changes so the window can resize + re-dock.
    var onResize: (() -> Void)?
    /// SwiftUI reports its measured content height so the window can hug it.
    var onHeight: ((CGFloat) -> Void)?
    func reportHeight(_ h: CGFloat) { onHeight?(h) }
    /// Refocus the app the user was in before the island, so ⌘V lands there.
    var activatePrevApp: (() -> Void)?
    /// Bring focus back to the island after a paste (keep editing).
    var refocusIsland: (() -> Void)?
    /// Suppresses collapse-on-deactivate during the apply focus dance.
    var isApplying = false

    var isFloating: Bool { presence == .floating }
    var isDocked: Bool { presence == .docked }
    var isExpanded: Bool { presence == .expanded }

    var canApply: Bool { !result.isEmpty }
    var contextCount: Int { preview.count }
    var sessionLabel: String {
        sessions.first(where: { $0.id == selectedId })?.name ?? "优化输入"
    }
    var selectedSession: SessionInfo? { sessions.first(where: { $0.id == selectedId }) }

    /// Double-click: cloud → card; card → back to cloud/notch.
    func toggleExpand() {
        switch presence {
        case .floating: expand(fromDock: false)
        case .docked:   expand(fromDock: true)
        case .expanded: collapse()
        }
    }

    /// Grow the card out (downward) from the cloud's current anchor. Loads
    /// sessions off the main thread so the panel opens instantly.
    func expand(fromDock: Bool) {
        expandedFromDock = fromDock
        presence = .expanded
        onResize?()
        let sel = Selection.current().trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.isEmpty, !sel.isEmpty, sel.count < 500 { draft = sel }
        refreshSessions()
    }

    /// Collapse the card back to wherever it grew from (cloud or notch).
    func collapse() {
        sessionListOpen = false
        presence = expandedFromDock ? .docked : .floating
        onResize?()
    }

    /// Cloud absorbed into the notch (released after dragging up to it).
    func dock() {
        sessionListOpen = false
        presence = .docked
        onResize?()
    }

    /// Cloud pulled back out to the desktop (dragged down from the notch).
    func undock() {
        notchHovered = false
        presence = .floating
        onResize?()
    }

    /// Hovering the docked notch expands the box; leaving collapses it.
    func setNotchHover(_ hovering: Bool) {
        guard isDocked, notchHovered != hovering else { return }
        notchHovered = hovering
        onResize?()
    }

    /// Toggle the context list and resize the card to fit it.
    func toggleContext() { contextOpen.toggle(); onResize?() }

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
        mascotSM.startThinking()
        setStatus("", .neutral)
        Task {
            do {
                let out = try await EnhanceClient.enhance(
                    draft: text, conversation: conversation)
                result = out
                setStatus("✓ 增强完成", .ok)
                mascotSM.finishOutput()
            } catch {
                setStatus("⚠ \(error.localizedDescription)", .error)
                mascotSM.showError()
            }
            busy = false
        }
    }

    // MARK: - Context-aware reply suggestions (Invoko-style)

    /// Gather screen context and fetch reply suggestions.
    func gatherSuggestions() {
        guard !suggestionsLoading else { return }
        suggestionsLoading = true
        suggestionsOpen = true

        // Step 1: immediately collect the non-screenshot layers (sync, fast)
        let ctx = ContextAwareness.gather()

        Task {
            // Step 2: fetch suggestions from the API (sync context only, no screenshot for speed)
            do {
                let resp = try await ReplySuggestionClient.fetchSuggestions(
                    context: ctx,
                    draft: draft,
                    numSuggestions: 3
                )
                await MainActor.run {
                    self.suggestions = resp.suggestions
                    self.contextSummary = resp.contextSummary
                    self.suggestionsLoading = false
                }
            } catch {
                await MainActor.run {
                    self.suggestions = []
                    self.suggestionsLoading = false
                    self.setStatus("⚠ 上下文感知失败: \(error.localizedDescription)", .error)
                }
            }
        }
    }

    /// Apply a suggestion: paste it into the draft and close suggestions.
    func applySuggestion(_ text: String) {
        draft = text
        suggestionsOpen = false
        onResize?()
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
    private var dragStartMouseY: CGFloat?
    private var dragStartOrigin: CGPoint?
    private var isDraggingPanel = false
    private enum DragKind { case none, floatingMove, dockedPull, cardMove }
    private var dragKind: DragKind = .none
    /// The floating cloud's desktop position (preserved across expand/collapse).
    private var floatingOrigin: CGPoint = .zero

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
        state.onHeight = { [weak self] h in self?.applyMeasuredHeight(h) }
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

        // Click outside the card → collapse (nonactivating panels get no
        // didResignActive).
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.isExpanded, !self.state.isApplying else { return }
                if self.panel.frame.contains(NSEvent.mouseLocation) { return }
                self.state.collapse()
            }
        }

        // Drag via absolute mouse position. Floating: move freely + dock into the
        // notch when released near the top. Docked: drag down to pop the cloud out.
        dragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.handleDrag(event) }
            return event
        }
    }

    private func handleDrag(_ event: NSEvent) {
        let threshold: CGFloat = 4
        let m = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown:
            if event.window === panel {
                dragStartMouseX = m.x; dragStartMouseY = m.y
                dragStartOrigin = panel.frame.origin
                isDraggingPanel = false
                dragKind = dragKindAtMouseDown(m)
            }
        case .leftMouseDragged:
            guard let sx = dragStartMouseX, let sy = dragStartMouseY,
                  let so = dragStartOrigin, dragKind != .none else { return }
            let dx = m.x - sx, dy = m.y - sy
            let sf = notchScreen().frame

            switch dragKind {
            case .dockedPull:
                // Drag down from the notch → pop the cloud out under the cursor.
                guard dy < -threshold else { return }
                floatingOrigin = clampOrigin(
                    CGPoint(x: m.x - cloudSize.width / 2, y: m.y - cloudSize.height / 2),
                    size: cloudSize, sf: sf)
                state.undock()
                dragStartMouseX = m.x; dragStartMouseY = m.y
                dragStartOrigin = floatingOrigin
                dragKind = .floatingMove
                isDraggingPanel = true

            case .floatingMove:
                if !isDraggingPanel {
                    guard abs(dx) > threshold || abs(dy) > threshold else { return }
                    isDraggingPanel = true
                }
                let prospective = clampOrigin(CGPoint(x: so.x + dx, y: so.y + dy),
                                              size: cloudSize, sf: sf)
                let cloudFrame = CGRect(origin: prospective, size: cloudSize)
                if inDockZone(cloudFrame) {
                    // Near the notch → snap into a fold-cue preview (glow), don't follow cursor.
                    if !state.dockPreview { state.dockPreview = true; applyFrame(animated: true) }
                } else {
                    // Outside the zone → cancel any preview, resume following the cursor.
                    floatingOrigin = prospective
                    if state.dockPreview { state.dockPreview = false; applyFrame(animated: true) }
                    else { panel.setFrameOrigin(prospective) }
                }

            case .cardMove:
                if !isDraggingPanel {
                    guard abs(dx) > threshold || abs(dy) > threshold else { return }
                    isDraggingPanel = true
                }
                let size = panel.frame.size
                let origin = clampOrigin(CGPoint(x: so.x + dx, y: so.y + dy), size: size, sf: sf)
                panel.setFrameOrigin(origin)
                // Free-floating card now; remember where the cloud should reappear.
                state.expandedFromDock = false
                floatingOrigin = CGPoint(x: origin.x + size.width / 2 - cloudSize.width / 2,
                                         y: origin.y + size.height - cloudSize.height)

            case .none:
                break
            }
        case .leftMouseUp:
            let commitDock = dragKind == .floatingMove && state.dockPreview
            // Clear drag state first so the dock transition animates (bouncy).
            dragStartMouseX = nil; dragStartMouseY = nil; dragStartOrigin = nil
            isDraggingPanel = false; dragKind = .none
            if commitDock {
                state.dockPreview = false
                state.dock()          // commit: absorbed into the notch (animated)
            }
        default:
            break
        }
    }

    /// Decide what a mouse-down begins to drag. In the expanded card only the
    /// header band drags (so text fields / buttons stay interactive).
    private func dragKindAtMouseDown(_ m: CGPoint) -> DragKind {
        switch state.presence {
        case .floating: return .floatingMove
        case .docked:   return .dockedPull
        case .expanded:
            let headerH: CGFloat = state.expandedFromDock ? max(28, state.notch.height) : 32
            return (panel.frame.maxY - m.y) <= headerH ? .cardMove : .none
        }
    }

    func show() {
        floatingOrigin = defaultFloatingOrigin(notchScreen().frame)
        applyFrame()
        panel.orderFrontRegardless()
    }

    /// Hotkey summon — open the card from the current anchor and focus it.
    func summon() {
        if !state.isExpanded { state.expand(fromDock: state.isDocked) }
        applyFrame()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    /// Re-dock the cloud into the notch.
    func resetToNotch() { state.dock() }

    /// Card height tracks the content's real rendered height (reported via onHeight).
    private var measuredExpandedHeight: CGFloat = 440
    private let cloudSize = NSSize(width: 140, height: 96)

    private func modeSize() -> NSSize {
        if state.isExpanded { return NSSize(width: 380, height: measuredExpandedHeight) }
        let nh = max(24, state.notch.height)
        // Preview is taller than the resident box to fit the glow halo below the notch.
        if state.dockPreview { return NSSize(width: 300, height: nh + 78) }
        if state.isDocked {
            // Flush menu-bar-height handle (Invoko resident notch / CodeIsland):
            // cloud in the wing beside the camera, NOTHING below the menu bar.
            // Must match IslandView dockWidth / dockHang (hang = 0).
            let w = state.notch.width + (state.notchHovered ? 145 : 105)
            return NSSize(width: w, height: nh)
        }
        return cloudSize
    }

    /// Position per presence: floating = free origin; docked = notch top-center;
    /// expanded = grow down from the cloud's anchor (notch when docked, else cloud).
    private func applyFrame(animated: Bool = false) {
        let screen = notchScreen()
        state.notch = NotchInfo.detect(screen)
        let sf = screen.frame
        let size = modeSize()
        let origin: CGPoint
        if state.isExpanded {
            if state.expandedFromDock {
                origin = CGPoint(x: sf.midX - size.width / 2, y: sf.maxY - size.height)
            } else {
                if floatingOrigin == .zero { floatingOrigin = defaultFloatingOrigin(sf) }
                let cloudTop = floatingOrigin.y + cloudSize.height   // grow down from cloud top
                let cx = floatingOrigin.x + cloudSize.width / 2
                origin = clampOrigin(CGPoint(x: cx - size.width / 2, y: cloudTop - size.height),
                                     size: size, sf: sf)
            }
        } else if state.dockPreview || state.isDocked {
            origin = CGPoint(x: sf.midX - size.width / 2, y: sf.maxY - size.height)   // notch top-center
        } else {  // floating
            if floatingOrigin == .zero { floatingOrigin = defaultFloatingOrigin(sf) }
            origin = clampOrigin(floatingOrigin, size: size, sf: sf)
            floatingOrigin = origin
        }
        let frame = NSRect(origin: origin, size: size)
        if animated {
            // Springy overshoot — the cloud gets "sucked" into the notch / pops out.
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.42
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.2, 1.06)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    func applySize() {
        // Animate state transitions (dock/undock/expand/collapse); never while
        // the user is actively dragging the cloud.
        applyFrame(animated: !isDraggingPanel)
        if state.isExpanded { panel.makeKey() }
    }

    /// SwiftUI reports its rendered content height; resize the card to match.
    private func applyMeasuredHeight(_ h: CGFloat) {
        guard state.isExpanded else { return }
        let clamped = max(200, h.rounded(.up))
        guard abs(clamped - measuredExpandedHeight) > 0.5 else { return }
        measuredExpandedHeight = clamped
        applyFrame()
    }

    // MARK: geometry helpers

    private func defaultFloatingOrigin(_ sf: NSRect) -> CGPoint {
        CGPoint(x: sf.midX - cloudSize.width / 2, y: sf.maxY - 90 - cloudSize.height)
    }

    private func clampOrigin(_ o: CGPoint, size: NSSize, sf: NSRect) -> CGPoint {
        CGPoint(x: min(max(o.x, sf.minX), sf.maxX - size.width),
                y: min(max(o.y, sf.minY), sf.maxY - size.height))
    }

    /// True when the floating cloud is dragged up near the notch (a dock target).
    private func inDockZone(_ frame: NSRect) -> Bool {
        let sf = notchScreen().frame
        return frame.maxY >= sf.maxY - 44 && abs(frame.midX - sf.midX) < max(190, state.notch.width)
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
