import Foundation

// MARK: - MascotStateMachine
//
// Drives the 15-state Rive cloud through the full AI interaction lifecycle,
// following Invoko's NotchStateMachine.md rules.
//
// Core lifecycle (priority order, per NotchStateMachine invariant #1):
//   idle → typing → listening → routing → outputting → done → idle
//
// Orthogonal branches (do not interrupt the core lifecycle):
//   error      — any state may transition to error
//   recording  — sub-state of listening (waveform active)
//   sparkle    — backend task completion sparkle burst
//   notification / authorize / help / backgroundHint / acknowledge
//     — transient overlays that return to the interrupted state
//
// Priority (per NotchStateMachine § "主视觉态"):
//   typing > listening > error > outputting > routing > thinking > done
//            > screenReading > idle > agentBackgroundTask
//
// Auto-dismiss durations:
//   acknowledge → idle    : 2 s
//   sparkle     → idle    : 3.5 s
//   notification → idle  : 5 s
//   error       → idle   : 6 s (after user reads)
//   backgroundHint → idle: 8 s

@MainActor
final class MascotStateMachine: ObservableObject {
    @Published private(set) var state: MascotState = .idle
    @Published private(set) var isRecording = false

    private var pendingReturn: MascotState = .idle
    private var autoTimers: [UUID: DispatchWorkItem] = [:]

    // ── Input lifecycle ───────────────────────────────────────────────────────

    func startTyping() {
        guard canInterrupt(to: .typing) else { return }
        transition(to: .typing)
    }

    func startListening() {
        guard canInterrupt(to: .listening) else { return }
        isRecording = false
        transition(to: .listening)
    }

    func startRecording() {
        guard state == .listening || state == .recording else { return }
        pendingReturn = state == .recording ? pendingReturn : state
        transition(to: .recording)
        isRecording = true
    }

    func stopRecording() {
        guard state == .recording else { return }
        transition(to: pendingReturn == .idle ? .listening : pendingReturn)
        isRecording = false
    }

    // ── AI lifecycle ─────────────────────────────────────────────────────────

    func startThinking() {
        guard canInterrupt(to: .thinking) else { return }
        transition(to: .thinking)
    }

    func startRouting() {
        guard canInterrupt(to: .routing) else { return }
        transition(to: .routing)
    }

    func startOutputting() {
        guard canInterrupt(to: .outputting) else { return }
        transition(to: .outputting)
    }

    func finishOutput() {
        guard state == .outputting || state == .routing || state == .thinking else { return }
        transition(to: .done, autoReturn: .idle, after: 3.5)
    }

    // ── Error branch ─────────────────────────────────────────────────────────

    func showError() {
        pendingReturn = state == .outputting ? .done : state
        transition(to: .error, autoReturn: pendingReturn == .idle ? .idle : pendingReturn, after: 6)
    }

    // ── Authorization branch ───────────────────────────────────────────────────

    func showAuthorization() {
        pendingReturn = state
        transition(to: .authorization)
    }

    func dismissAuthorization() {
        guard state == .authorization else { return }
        transition(to: pendingReturn)
    }

    // ── Notification / background branch ───────────────────────────────────────

    func showNotification() {
        pendingReturn = state
        transition(to: .notification, autoReturn: pendingReturn, after: 5)
    }

    func showSparkle() {
        guard canInterrupt(to: .sparkle) else { return }
        transition(to: .sparkle, autoReturn: .idle, after: 3.5)
    }

    func showBackgroundHint() {
        guard canInterrupt(to: .backgroundHint) else { return }
        transition(to: .backgroundHint, autoReturn: .idle, after: 8)
    }

    // ── UI feedback ───────────────────────────────────────────────────────────

    func showAcknowledge() {
        pendingReturn = state == .idle ? .idle : state
        transition(to: .acknowledge, autoReturn: pendingReturn, after: 2)
    }

    func showHelp() {
        pendingReturn = state
        transition(to: .help)
    }

    func dismissHelp() {
        guard state == .help else { return }
        transition(to: pendingReturn)
    }

    // ── Explicit idle ─────────────────────────────────────────────────────────

    func goIdle() {
        cancelTimers()
        state = .idle
        isRecording = false
    }

    // ── Implementation ───────────────────────────────────────────────────────

    private func transition(to new: MascotState, autoReturn: MascotState? = nil, after sec: TimeInterval = 0) {
        cancelTimers()
        state = new
        if let ret = autoReturn, sec > 0 {
            let task = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.transition(to: ret)
                }
            }
            let id = UUID()
            autoTimers[id] = task
            DispatchQueue.main.asyncAfter(deadline: .now() + sec, execute: task)
        }
    }

    /// Returns true if `target` can interrupt the current state per priority rules.
    private func canInterrupt(to target: MascotState) -> Bool {
        let priority: [MascotState: Int] = [
            .error: 100,
            .authorization: 95,
            .help: 90,
            .typing: 80,
            .recording: 75,
            .listening: 70,
            .outputting: 60,
            .routing: 55,
            .thinking: 50,
            .done: 40,
            .notification: 35,
            .acknowledge: 30,
            .sparkle: 25,
            .backgroundHint: 20,
            .idle: 10,
        ]
        return (priority[state] ?? 0) <= (priority[target] ?? 0)
    }

    private func cancelTimers() {
        autoTimers.values.forEach { $0.cancel() }
        autoTimers.removeAll()
    }
}
