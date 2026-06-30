import Cocoa
import ApplicationServices
import ScreenCaptureKit

/// Invoko-style context awareness — reads what is currently on screen ONLY when triggered,
/// never passively monitors. Captures these layers (in order of privacy sensitivity):
///   1. Frontmost app name + bundle ID
///   2. Window title (AX API)
///   3. Page URL (AX API, browser tabs)
///   4. Selected text (clipboard)
///   5. Focused input field value (AX API)
///   6. Screenshot (ScreenCaptureKit, on-demand only)
enum ContextAwareness {

    // MARK: - Data Model

    struct Context: Codable {
        let appName: String
        let bundleID: String
        let windowTitle: String
        let pageURL: String
        let selectedText: String
        let focusedFieldText: String
        /// Base64-encoded PNG screenshot. Only populated when screenshotNeeded = true.
        let screenshot: String
        let timestamp: TimeInterval

        var summary: String {
            var parts: [String] = []
            if !appName.isEmpty { parts.append("App: \(appName)") }
            if !windowTitle.isEmpty { parts.append("Window: \(windowTitle)") }
            if !pageURL.isEmpty { parts.append("URL: \(pageURL)") }
            if !selectedText.isEmpty { parts.append("Selected: \(selectedText.prefix(200))") }
            if !focusedFieldText.isEmpty { parts.append("Input field: \(focusedFieldText.prefix(200))") }
            return parts.joined(separator: " | ")
        }

        var isEmpty: Bool {
            appName.isEmpty && windowTitle.isEmpty && pageURL.isEmpty
                && selectedText.isEmpty && focusedFieldText.isEmpty && screenshot.isEmpty
        }
    }

    // MARK: - Per-Layer Readers

    /// Layer 1: Frontmost app name + bundle ID.
    static func frontmostApp() -> (name: String, bundleID: String) {
        let app = NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName ?? ""
        let bid = app?.bundleIdentifier ?? ""
        return (name, bid)
    }

    /// Layer 2 + 3: Window title and page URL via AX API.
    static func windowInfo(pid: pid_t) -> (title: String, url: String) {
        let axApp = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        var title = ""
        var url = ""

        if titleResult == .success, let window = focusedWindow {
            // Window title
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef) == .success,
               let t = titleRef as? String {
                title = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Page URL — look for AXURL in window children (browser tabs)
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                url = _findURL(in: children) ?? ""
            }
        }

        return (title, url)
    }

    private static func _findURL(in elements: [AXUIElement], depth: Int = 0) -> String? {
        if depth > 8 { return nil }
        for el in elements {
            var urlRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, "AXURL" as CFString, &urlRef) == .success,
               let u = urlRef as? String, !u.isEmpty {
                return u
            }
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                if let found = _findURL(in: children, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }

    /// Layer 4: Selected text from the system clipboard.
    static func selectedText() -> String {
        let pb = NSPasteboard.general
        return pb.string(forType: .string) ?? ""
    }

    /// Layer 5: Focused text field value via AX API.
    static func focusedFieldText(pid: pid_t) -> String {
        let axApp = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused else { return "" }

        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(el as! AXUIElement, kAXValueAttribute as CFString, &valueRef) == .success,
           let v = valueRef as? String {
            return v.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    /// Layer 6: Screenshot via ScreenCaptureKit (async, macOS 12+).
    /// Requires Screen Recording permission. Returns base64 PNG.
    static func screenshot() async -> String {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let frontApp = NSWorkspace.shared.frontmostApplication,
                  let frontBundleID = frontApp.bundleIdentifier else { return "" }

            // Find on-screen windows belonging to the frontmost app
            let candidates = content.windows.filter {
                $0.owningApplication?.bundleIdentifier == frontBundleID && $0.isOnScreen
            }

            guard let targetWindow = candidates.first else { return "" }

            let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
            let config = SCStreamConfiguration()
            config.width = 1280
            config.height = 800
            config.scalesToFit = true
            config.showsCursor = false
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return "" }
            return pngData.base64EncodedString()
        } catch {
            return ""
        }
    }

    // MARK: - Main Collector

    /// Gather all context layers except screenshot (screenshot is captured async separately).
    static func gather(screenshotNeeded: Bool = false) -> Context {
        let (appName, bundleID) = frontmostApp()
        let pid = (NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0) as pid_t
        let (windowTitle, pageURL) = windowInfo(pid: pid)
        let selected = selectedText()
        let fieldText = focusedFieldText(pid: pid)

        return Context(
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle,
            pageURL: pageURL,
            selectedText: String(selected.prefix(500)),
            focusedFieldText: String(fieldText.prefix(1000)),
            screenshot: "",
            timestamp: Date().timeIntervalSince1970
        )
    }

    /// Gather all context layers including screenshot (async).
    static func gatherWithScreenshot() async -> Context {
        let base = gather()
        let screenshotBase64 = await screenshot()
        return Context(
            appName: base.appName,
            bundleID: base.bundleID,
            windowTitle: base.windowTitle,
            pageURL: base.pageURL,
            selectedText: base.selectedText,
            focusedFieldText: base.focusedFieldText,
            screenshot: screenshotBase64,
            timestamp: base.timestamp
        )
    }
}
