import Cocoa

/// Clipboard + paste helpers, mirroring the Python card's get_selection /
/// replace_selection. Reading uses the clipboard (the reliable cross-app path);
/// writing copies the enhanced text and synthesizes ⌘V into the frontmost app.
enum Selection {
    /// Best-effort current selection. We read the clipboard rather than poke at
    /// the AX API, matching the Python pbpaste fallback. Capped to 500 chars so
    /// stray large clipboards don't flood the draft.
    static func current() -> String {
        let s = NSPasteboard.general.string(forType: .string) ?? ""
        return String(s.prefix(500))
    }

    /// Copy `text` and paste it into whichever app is frontmost. Requires the
    /// Accessibility permission for the synthesized keystroke to land.
    static func replace(with text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        // Give the previous app a moment to regain focus before pasting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { pressCmdV() }
    }

    private static func pressCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 0x09   // 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
