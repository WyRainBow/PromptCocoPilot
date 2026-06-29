import Foundation

/// A single conversation turn, mirroring the Python session_reader payload
/// ({role, content, ts}) so the enhance server receives an identical shape.
struct Turn: Codable {
    let role: String      // "user" | "assistant"
    let content: String
    let ts: String
}

/// A selectable Claude Code session, mirroring Python list_sessions().
struct SessionInfo: Identifiable {
    let cwd: String
    let name: String
    let pathTail: String   // last two path components — disambiguates 同名项目
    let ago: String
    let messageCount: Int
    let status: String
    let sid: String        // first 8 chars of sessionId

    var id: String { cwd }
    var menuLabel: String {
        let busy = status == "busy" ? "🔴 " : ""
        return "\(busy)\(name) · \(pathTail) · \(ago) · \(messageCount)条"
    }
}

/// One compressed-context row shown in the disclosure list.
struct PreviewItem: Identifiable {
    let id = UUID()
    let role: String       // "user" | "assistant"
    let snippet: String
    let ts: String
}

/// Native port of claude-ui/src/session_reader.py — reads Claude Code sessions
/// straight from ~/.claude without shelling out to Python.
enum SessionReader {
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static var claudeDir: URL { home.appendingPathComponent(".claude") }
    private static var sessionsDir: URL { claudeDir.appendingPathComponent("sessions") }
    private static var projectsDir: URL { claudeDir.appendingPathComponent("projects") }

    /// Claude Code replaces every non-[A-Za-z0-9._-] char with '-'. Must be
    /// ASCII-only: Swift's isLetter/isNumber are Unicode-aware and would keep
    /// CJK chars (e.g. 开源工具), producing the wrong project-folder slug.
    private static func slug(_ cwd: String) -> String {
        String(cwd.map { c in
            (c.isASCII && (c.isLetter || c.isNumber)) || c == "." || c == "_" || c == "-"
                ? c : "-"
        })
    }

    private struct SessionMeta {
        let cwd: String
        let sessionId: String
        let status: String
        let updatedAt: Double   // ms; falls back to file mtime
    }

    private static func loadSessions() -> [SessionMeta] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        var metas: [SessionMeta] = []
        for f in files where f.pathExtension == "json" {
            guard
                let data = try? Data(contentsOf: f),
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let mtime = ((try? f.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000
            metas.append(SessionMeta(
                cwd: obj["cwd"] as? String ?? "",
                sessionId: obj["sessionId"] as? String ?? "",
                status: obj["status"] as? String ?? "",
                updatedAt: (obj["updatedAt"] as? Double) ?? mtime
            ))
        }
        // Rank by the most-recently-written conversation log — that's the session
        // the user is actually in (busy-first picked background sessions instead).
        metas.sort { lastActivity($0) > lastActivity($1) }
        return metas
    }

    /// When the session's JSONL was last written (falls back to the session JSON
    /// timestamp). The active terminal's log is touched on every message.
    private static func lastActivity(_ m: SessionMeta) -> Double {
        if let url = jsonlURL(cwd: m.cwd, sessionId: m.sessionId),
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.modificationDate] as? Date {
            return date.timeIntervalSince1970 * 1000
        }
        return m.updatedAt
    }

    private static func jsonlURL(cwd: String, sessionId: String) -> URL? {
        guard !cwd.isEmpty, !sessionId.isEmpty else { return nil }
        let p = projectsDir
            .appendingPathComponent(slug(cwd))
            .appendingPathComponent("\(sessionId).jsonl")
        return FileManager.default.fileExists(atPath: p.path) ? p : nil
    }

    /// Read only the last `maxBytes` of a file — recent turns are at the end, so
    /// we avoid loading multi-MB logs in full (the old code read the whole file).
    private static func tailData(_ url: URL, maxBytes: Int) -> Data? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? h.seek(toOffset: start)
        return try? h.readToEnd()
    }

    private static func parse(_ url: URL, max: Int) -> [Turn] {
        let cap = 1_000_000   // 1MB tail comfortably covers the last ~20 turns
        guard let data = tailData(url, maxBytes: cap) else { return [] }
        let text = String(decoding: data, as: UTF8.self)   // lossy, never nil
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        // If the file was truncated, the first line is likely partial — drop it.
        if data.count >= cap, !lines.isEmpty { lines.removeFirst() }
        var turns: [Turn] = []
        for line in lines {
            guard
                let obj = try? JSONSerialization.jsonObject(
                    with: Data(line.utf8)) as? [String: Any],
                let type = obj["type"] as? String,
                type == "user" || type == "assistant"
            else { continue }

            let content = (obj["message"] as? [String: Any])?["content"]
            var bodyText = ""
            if let s = content as? String {
                bodyText = s
            } else if let parts = content as? [[String: Any]] {
                bodyText = parts
                    .filter { ($0["type"] as? String) == "text" }
                    .compactMap { $0["text"] as? String }
                    .joined(separator: "\n")
            }
            bodyText = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bodyText.isEmpty else { continue }
            turns.append(Turn(role: type, content: bodyText,
                              ts: obj["timestamp"] as? String ?? ""))
        }
        return Array(turns.suffix(max))
    }

    private static func relativeTime(_ ms: Double) -> String {
        guard ms > 0 else { return "" }
        let diff = max(0, Date().timeIntervalSince1970 - ms / 1000)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60))分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600))小时前" }
        return "\(Int(diff / 86400))天前"
    }

    // MARK: - Public API

    /// Active sessions with disambiguation info, mirroring Python list_sessions().
    static func list(max: Int = 10) -> [SessionInfo] {
        var out: [SessionInfo] = []
        for m in loadSessions().prefix(max) {
            guard let url = jsonlURL(cwd: m.cwd, sessionId: m.sessionId) else { continue }
            let count = parse(url, max: 20).count
            let parts = m.cwd.split(separator: "/").map(String.init)
            let tail = parts.count >= 2 ? parts.suffix(2).joined(separator: "/") : m.cwd
            out.append(SessionInfo(
                cwd: m.cwd,
                name: parts.last ?? "未知项目",
                pathTail: tail,
                ago: relativeTime(lastActivity(m)),   // consistent with the sort
                messageCount: count,
                status: m.status,
                sid: String(m.sessionId.prefix(8))
            ))
        }
        return out
    }

    /// Conversation + compressed preview for a specific session cwd.
    static func context(cwd: String, max: Int = 20) -> (turns: [Turn], preview: [PreviewItem]) {
        for m in loadSessions() where m.cwd == cwd {
            guard let url = jsonlURL(cwd: m.cwd, sessionId: m.sessionId) else { continue }
            let turns = parse(url, max: max)   // chronological — sent to enhance as-is
            // Preview is newest-first for display only.
            let preview = turns.reversed().map {
                PreviewItem(role: $0.role,
                            snippet: String($0.content.prefix(60))
                                .replacingOccurrences(of: "\n", with: " "),
                            ts: $0.ts)
            }
            return (turns, preview)
        }
        return ([], [])
    }
}
