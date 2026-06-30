import SwiftUI
import RiveRuntime

/// Renders Invoko's original cloud mascot via the Rive runtime — 1:1 with the
/// source, including its animations. Switches the .riv to follow the app's
/// MascotState (idle blink / thinking / done fireworks). Falls back to the
/// hand-drawn `CloudView` if a .riv can't be loaded.
///
/// Key insight from riv_diag:
///   Every .riv file has a `blink` boolean SM input. Default is false (no blink).
///   Setting it to true enables the blink/lid animation cycle. This is why
///   hover worked: something was setting it. We set it unconditionally on
///   VM creation so blinking always works regardless of state machine entry.
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
    /// Artboard/SM names extracted from .riv files via `riv_check`.
    /// Use animationName for looping/idle animations (blink baked in).
    /// Use stateMachineName only for complex multi-state animations.
    @MainActor
    static func make(_ s: MascotState) -> RiveViewModel? {
        let cfg: (file: String, artboard: String?, anim: String?, sm: String?)
        switch s {
        // ── Core lifecycle ───────────────────────────────────────────
        // idle: Timeline 1 is a looping animation with baked-in blink cycle.
        // Do NOT use the SM — the SM requires the `blink` boolean input to be
        // driven externally and does not auto-blink on its own.
        case .idle:          cfg = ("IPDefaultIdle",           "idle",           "Timeline 1", nil)
        // thinking/routing/outputting/listening: SM controls multi-phase animation.
        case .thinking:      cfg = ("IPDefaultThinking",        nil,             nil, "Thinking")
        case .routing:       cfg = ("IPDefaultRouting",         nil,             nil, "routing")
        case .listening:     cfg = ("IPDefaultListening",      nil,             nil, "Listen")
        case .outputting:    cfg = ("IPDefaultOutputting",     nil,             nil, "Outputting")
        case .done:          cfg = ("IPDefaultDone",           "task complete",   nil, "Task Complete")
        case .error:         cfg = ("IPDefaultError",          nil,             nil, "error")

        // ── Input branch ─────────────────────────────────────────────
        case .typing:        cfg = ("IPDefaultTyping",         nil,             nil, "Typing")

        // ── Authorization branch ─────────────────────────────────────
        case .authorization: cfg = ("IPDefaultAuthorization",  nil,             nil, "authorization")

        // ── Notification / background ─────────────────────────────────
        case .recording:     cfg = ("IPDefaultWaveform",       nil,             nil, "Recording")
        case .notification:  cfg = ("IPDefaultNotification",   nil,             nil, "notification")
        case .sparkle:       cfg = ("IPDefaultSparkle",        nil,             nil, "Agent background")

        // ── UI feedback ─────────────────────────────────────────────
        case .acknowledge:    cfg = ("IPDefaultAcknowledge",   nil,             nil, "Task done")
        case .backgroundHint: cfg = ("IPDefaultBackgroundHint", nil,           nil, "background hint")
        case .help:          cfg = ("IPDefaultHelp",          nil,             nil, "Ask Human")
        }
        guard let url = rivURL(cfg.file),
              let data = try? Data(contentsOf: url),
              let file = try? RiveFile(data: data, loadCdn: false)
        else { return nil }

        let model = RiveModel(riveFile: file)
        if let anim = cfg.anim {
            // Loop an animation directly — use this for idle/blink where the
            // animation itself contains the blink cycle (no SM input needed).
            return RiveViewModel(model,
                                 animationName: anim,
                                 fit: .contain,
                                 artboardName: cfg.artboard)
        } else if let sm = cfg.sm {
            // State machine: also enable blinking via the `blink` boolean input.
            let vm = RiveViewModel(model,
                                   stateMachineName: sm,
                                   fit: .contain,
                                   artboardName: cfg.artboard)
            vm.setInput("blink", value: true)
            return vm
        }
        return nil
    }

    private static func rivURL(_ name: String) -> URL? {
        let dir = Bundle.main.executableURL?.deletingLastPathComponent()
        let u = dir?.appendingPathComponent("\(name).riv")
        if let u, FileManager.default.fileExists(atPath: u.path) { return u }
        return nil
    }
}
