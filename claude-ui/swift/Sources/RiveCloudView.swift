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

    /// (file, artboard, stateMachine) per mascot state.
    /// Artboard/SM names extracted from .riv files via `riv_diag`.
    @MainActor
    static func make(_ s: MascotState) -> RiveViewModel? {
        let cfg: (file: String, artboard: String?, sm: String?)
        switch s {
        case .idle:          cfg = ("IPDefaultIdle",           "idle",          "State Machine 1")
        case .thinking:      cfg = ("IPDefaultThinking",        nil,             "Thinking")
        case .routing:      cfg = ("IPDefaultRouting",         nil,             "routing")
        case .listening:     cfg = ("IPDefaultListening",      nil,             "Listen")
        case .outputting:    cfg = ("IPDefaultOutputting",     nil,             "Outputting")
        case .done:          cfg = ("IPDefaultDone",           "task complete",  "Task Complete")
        case .error:         cfg = ("IPDefaultError",          nil,             "error")
        case .typing:        cfg = ("IPDefaultTyping",         nil,             "Typing")
        case .authorization: cfg = ("IPDefaultAuthorization",   nil,             "authorization")
        case .recording:     cfg = ("IPDefaultWaveform",       nil,             "Recording")
        case .notification:  cfg = ("IPDefaultNotification",   nil,             "notification")
        case .sparkle:       cfg = ("IPDefaultSparkle",        nil,             "Agent background")
        case .acknowledge:    cfg = ("IPDefaultAcknowledge",    nil,             "Task done")
        case .backgroundHint: cfg = ("IPDefaultBackgroundHint", nil,             "background hint")
        case .help:          cfg = ("IPDefaultHelp",          nil,             "Ask Human")
        }
        guard let url = rivURL(cfg.file),
              let data = try? Data(contentsOf: url),
              let file = try? RiveFile(data: data, loadCdn: false)
        else { return nil }

        let vm: RiveViewModel?
        if let ab = cfg.artboard {
            vm = RiveViewModel(RiveModel(riveFile: file),
                               stateMachineName: cfg.sm,
                               fit: .contain,
                               artboardName: ab)
        } else {
            vm = RiveViewModel(RiveModel(riveFile: file),
                               stateMachineName: cfg.sm,
                               fit: .contain)
        }
        // Enable blinking on every state that has a `blink` boolean input.
        // Without this, the SM entry state defaults to `no blink` (false).
        vm?.setInput("blink", value: true)
        return vm
    }

    private static func rivURL(_ name: String) -> URL? {
        let dir = Bundle.main.executableURL?.deletingLastPathComponent()
        let u = dir?.appendingPathComponent("\(name).riv")
        if let u, FileManager.default.fileExists(atPath: u.path) { return u }
        return nil
    }
}
