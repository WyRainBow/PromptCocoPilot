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

    /// (file, artboard, stateMachine) per mascot state — extracted from the actual
    /// .riv files via `riv_diag`. Some files contain multiple artboards (e.g. idle
    /// + task complete), and the SM name does NOT always equal the artboard name.
    @MainActor
    static func make(_ s: MascotState) -> RiveViewModel? {
        let cfg: (file: String, artboard: String, sm: String)
        switch s {
        // ── Core lifecycle ───────────────────────────────────────────
        case .idle:          cfg = ("IPDefaultIdle",          "idle",           "State Machine 1")
        case .thinking:      cfg = ("IPDefaultThinking",       "thinking",        "Thinking")
        case .routing:      cfg = ("IPDefaultRouting",        "routing",        "routing")
        case .listening:     cfg = ("IPDefaultListening",     "listening",      "Listen")
        case .outputting:    cfg = ("IPDefaultOutputting",     "outputting",     "Outputting")
        case .done:          cfg = ("IPDefaultDone",          "task complete",  "Task Complete")
        case .error:         cfg = ("IPDefaultError",        "error",          "error")

        // ── Input branch ─────────────────────────────────────────────
        case .typing:        cfg = ("IPDefaultTyping",         "typing",         "Typing")

        // ── Authorization branch ─────────────────────────────────────
        case .authorization: cfg = ("IPDefaultAuthorization",  "authorization",  "authorization")

        // ── Notification / background ────────────────────────────────
        case .recording:     cfg = ("IPDefaultWaveform",      "recording",      "Recording")
        case .notification: cfg = ("IPDefaultNotification",   "notification",   "notification")
        case .sparkle:      cfg = ("IPDefaultSparkle",       "agent background","Agent background")

        // ── UI feedback ──────────────────────────────────────────────
        case .acknowledge:   cfg = ("IPDefaultAcknowledge",    "task done",      "Task done")
        case .backgroundHint: cfg = ("IPDefaultBackgroundHint","background hint","background hint")
        case .help:         cfg = ("IPDefaultHelp",           "ask human",      "Ask Human")
        }
        guard let url = rivURL(cfg.file),
              let data = try? Data(contentsOf: url),
              let file = try? RiveFile(data: data, loadCdn: false)
        else { return nil }
        return RiveViewModel(RiveModel(riveFile: file),
                             stateMachineName: cfg.sm,
                             fit: .contain,
                             artboardName: cfg.artboard)
    }

    /// The .riv files sit next to the executable (copied there by build.sh).
    private static func rivURL(_ name: String) -> URL? {
        let dir = Bundle.main.executableURL?.deletingLastPathComponent()
        let u = dir?.appendingPathComponent("\(name).riv")
        if let u, FileManager.default.fileExists(atPath: u.path) { return u }
        return nil
    }
}
