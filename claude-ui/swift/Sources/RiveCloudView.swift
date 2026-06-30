import SwiftUI
import RiveRuntime

/// Renders Invoko's original cloud mascot via the Rive runtime — 1:1 with the
/// source, including its animations. Switches the .riv to follow the app's
/// MascotState (idle blink / thinking / done fireworks). Falls back to the
/// hand-drawn `CloudView` if a .riv can't be loaded.
struct RiveCloudView: View {
    @EnvironmentObject var state: AppState
    @State private var vm: RiveViewModel?
    @State private var loaded: MascotState?

    var body: some View {
        Group {
            if let vm {
                vm.view()
            } else {
                CloudView()
            }
        }
        // Let taps/drags fall through to the parent (double-click expand, drag).
        .allowsHitTesting(false)
        .onAppear { reload(state.mascot) }
        .onChange(of: state.mascot) { _, new in reload(new) }
    }

    private func reload(_ s: MascotState) {
        guard s != loaded else { return }
        loaded = s
        vm = RiveCloudView.make(s)
    }

    /// (file, artboard, animationName) per mascot state.
    /// Prefer `animationName` over `stateMachineName` for looping/idle animations;
    /// use `stateMachineName` only for artboards with no suitable looping animation.
    @MainActor
    static func make(_ s: MascotState) -> RiveViewModel? {
        let cfg: (file: String, artboard: String, anim: String?, sm: String?)
        switch s {
        // ── Core lifecycle ───────────────────────────────────────────
        // idle: play Timeline 1 (controls the blink/lid-up cycle).
        case .idle:          cfg = ("IPDefaultIdle",           "idle",           "Timeline 1", nil)
        // thinking/routing/outputting: no looping animation → fall back to SM.
        case .thinking:      cfg = ("IPDefaultThinking",        "thinking",       nil, "Thinking")
        case .routing:       cfg = ("IPDefaultRouting",        "routing",        nil, "routing")
        case .listening:     cfg = ("IPDefaultListening",      "listening",      nil, "Listen")
        case .outputting:    cfg = ("IPDefaultOutputting",     "outputting",     nil, "Outputting")
        case .done:          cfg = ("IPDefaultDone",           "task complete",  nil, "Task Complete")
        case .error:         cfg = ("IPDefaultError",          "error",         nil, "error")

        // ── Input branch ─────────────────────────────────────────────
        case .typing:        cfg = ("IPDefaultTyping",         "typing",         nil, "Typing")

        // ── Authorization branch ─────────────────────────────────────
        case .authorization: cfg = ("IPDefaultAuthorization",   "authorization",  nil, "authorization")

        // ── Notification / background ─────────────────────────────────
        case .recording:     cfg = ("IPDefaultWaveform",       "recording",      nil, "Recording")
        case .notification:  cfg = ("IPDefaultNotification",    "notification",   nil, "notification")
        case .sparkle:       cfg = ("IPDefaultSparkle",        "agent background", nil, "Agent background")

        // ── UI feedback ─────────────────────────────────────────────
        case .acknowledge:    cfg = ("IPDefaultAcknowledge",    "task done",      nil, "Task done")
        case .backgroundHint: cfg = ("IPDefaultBackgroundHint","background hint", nil, "background hint")
        case .help:          cfg = ("IPDefaultHelp",           "ask human",      nil, "Ask Human")
        }
        guard let url = rivURL(cfg.file),
              let data = try? Data(contentsOf: url),
              let file = try? RiveFile(data: data, loadCdn: false)
        else { return nil }

        // Prefer animation name (for looping/idle animations); fall back to SM.
        if let anim = cfg.anim {
            return RiveViewModel(RiveModel(riveFile: file),
                                 animationName: anim,
                                 fit: .contain,
                                 artboardName: cfg.artboard)
        } else if let sm = cfg.sm {
            return RiveViewModel(RiveModel(riveFile: file),
                                 stateMachineName: sm,
                                 fit: .contain,
                                 artboardName: cfg.artboard)
        }
        return nil
    }

    /// The .riv files sit next to the executable (copied there by build.sh).
    private static func rivURL(_ name: String) -> URL? {
        let dir = Bundle.main.executableURL?.deletingLastPathComponent()
        let u = dir?.appendingPathComponent("\(name).riv")
        if let u, FileManager.default.fileExists(atPath: u.path) { return u }
        return nil
    }
}
