import Foundation

/// Which agent a session belongs to (shown as a badge; lets one island switch
/// between Claude Code / Codex / … conversations, like CodeIsland).
enum AgentKind: String { case claude = "Claude", codex = "Codex" }

/// A single conversation turn, mirroring the Python session_reader payload
/// ({role, content, ts}) so the enhance server receives an identical shape.
struct Turn: Codable {
    let role: String      // "user" | "assistant"
    let content: String
    let ts: String
}

/// A selectable session from any agent.
struct SessionInfo: Identifiable {
    let id: String          // unique across agents (agent + session id)
    let agent: AgentKind
    let cwd: String
    let name: String
    let pathTail: String    // last two path components — disambiguates 同名项目
    let ago: String
    let messageCount: Int
    let status: String      // "busy" for Claude; "" otherwise
    let logPath: String     // conversation log to read for context

    var menuLabel: String {
        let busy = status == "busy" ? "🔴 " : ""
        return "\(busy)\(name) · \(pathTail) · \(ago) · \(messageCount)条"
    }
}

/// One compressed-context row shown in the disclosure list.
struct PreviewItem: Identifiable {
    let id = UUID()
    let role: String
    let snippet: String
    let ts: String
}

/// Multi-agent session reader. Aggregates Claude Code (~/.claude) and Codex
/// (~/.codex) conversations into one switchable list.
enum SessionReader {
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static var claudeDir: URL { home.appendingPathComponent(".claude") }
    private static var codexDir: URL { home.appendingPathComponent(".codex") }

    // MARK: - Shared helpers

    /// Claude Code replaces every non-[A-Za-z0-9._-] char with '-'. ASCII-only:
    /// Swift's isLetter/isNumber are Unicode-aware and would keep CJK chars.
    private static func slug(_ cwd: String) -> String {
        String(cwd.map { c in
            (c.isASCII && (c.isLetter || c.isNumber)) || c == "." || c == "_" || c == "-"
                ? c : "-"
        })
    }

    private static func relativeTime(_ ms: Double) -> String {
        guard ms > 0 else { return "" }
        let diff = max(0, Date().timeIntervalSince1970 - ms / 1000)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60))分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600))小时前" }
        return "\(Int(diff / 86400))天前"
    }

    private static func mtimeMs(_ url: URL) -> Double {
        let d = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        return (d?.timeIntervalSince1970 ?? 0) * 1000
    }

    /// Read only the last `maxBytes` of a file — recent turns are at the end.
    private static func tailData(_ url: URL, maxBytes: Int) -> Data? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? h.seek(toOffset: start)
        return try? h.readToEnd()
    }

    private static func pathTail(_ cwd: String) -> String {
        let parts = cwd.split(separator: "/").map(String.init)
        return parts.count >= 2 ? parts.suffix(2).joined(separator: "/") : cwd
    }

    private static func tailLines(_ url: URL, cap: Int = 1_000_000) -> [Substring] {
        guard let data = tailData(url, maxBytes: cap) else { return [] }
        let text = String(decoding: data, as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if data.count >= cap, !lines.isEmpty { lines.removeFirst() }   // drop partial first line
        return lines
    }

    // MARK: - Claude Code source

    private struct ClaudeMeta { let cwd, sessionId, status: String; let updatedAt: Double }

    private static func claudeJsonl(cwd: String, sessionId: String) -> URL? {
        guard !cwd.isEmpty, !sessionId.isEmpty else { return nil }
        let p = claudeDir.appendingPathComponent("projects")
            .appendingPathComponent(slug(cwd))
            .appendingPathComponent("\(sessionId).jsonl")
        return FileManager.default.fileExists(atPath: p.path) ? p : nil
    }

    private static func parseClaude(_ url: URL, max: Int) -> [Turn] {
        var turns: [Turn] = []
        for line in tailLines(url) {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let type = obj["type"] as? String, type == "user" || type == "assistant"
            else { continue }
            let content = (obj["message"] as? [String: Any])?["content"]
            var body = ""
            if let s = content as? String { body = s }
            else if let parts = content as? [[String: Any]] {
                body = parts.filter { ($0["type"] as? String) == "text" }
                    .compactMap { $0["text"] as? String }.joined(separator: "\n")
            }
            body = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            turns.append(Turn(role: type, content: body, ts: obj["timestamp"] as? String ?? ""))
        }
        return Array(turns.suffix(max))
    }

    private static func claudeCandidates() -> [(SessionInfo, Double)] {
        let dir = claudeDir.appendingPathComponent("sessions")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return [] }
        var out: [(SessionInfo, Double)] = []
        for f in files where f.pathExtension == "json" {
            guard let data = try? Data(contentsOf: f),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let cwd = obj["cwd"] as? String ?? ""
            let sid = obj["sessionId"] as? String ?? ""
            guard let url = claudeJsonl(cwd: cwd, sessionId: sid) else { continue }
            let activity = mtimeMs(url)
            let info = SessionInfo(
                id: "claude:\(sid)", agent: .claude, cwd: cwd,
                name: (cwd as NSString).lastPathComponent.isEmpty ? "未知项目" : (cwd as NSString).lastPathComponent,
                pathTail: pathTail(cwd), ago: relativeTime(activity),
                messageCount: parseClaude(url, max: 20).count,
                status: obj["status"] as? String ?? "", logPath: url.path)
            out.append((info, activity))
        }
        return out
    }

    // MARK: - Codex source

    /// First JSON object in a file (the session_meta line). Reads a bounded head.
    private static func firstJSONLine(_ url: URL, cap: Int = 512_000) -> [String: Any]? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        guard let data = try? h.read(upToCount: cap) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        guard let line = text.split(separator: "\n", maxSplits: 1).first else { return nil }
        return try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
    }

    private static func parseCodex(_ url: URL, max: Int) -> [Turn] {
        var turns: [Turn] = []
        for line in tailLines(url) {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  (obj["type"] as? String) == "response_item",
                  let p = obj["payload"] as? [String: Any],
                  (p["type"] as? String) == "message",
                  let role = p["role"] as? String, role == "user" || role == "assistant",
                  let content = p["content"] as? [[String: Any]]
            else { continue }
            let body = content.compactMap { $0["text"] as? String }
                .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            turns.append(Turn(role: role, content: body, ts: obj["timestamp"] as? String ?? ""))
        }
        return Array(turns.suffix(max))
    }

    /// id → thread_name from ~/.codex/session_index.jsonl (nicer display names).
    private static func codexThreadNames() -> [String: String] {
        let idx = codexDir.appendingPathComponent("session_index.jsonl")
        guard let text = try? String(contentsOf: idx, encoding: .utf8) else { return [:] }
        var map: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
               let id = o["id"] as? String, let name = o["thread_name"] as? String {
                map[id] = name
            }
        }
        return map
    }

    private static func codexCandidates(limit: Int = 8) -> [(SessionInfo, Double)] {
        let base = codexDir.appendingPathComponent("sessions")
        guard let en = FileManager.default.enumerator(
            at: base, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return [] }
        var files: [(URL, Double)] = []
        for case let url as URL in en where url.pathExtension == "jsonl" {
            files.append((url, mtimeMs(url)))
        }
        files.sort { $0.1 > $1.1 }
        files = Array(files.prefix(limit))

        let names = codexThreadNames()
        var out: [(SessionInfo, Double)] = []
        for (url, activity) in files {
            guard let meta = firstJSONLine(url),
                  (meta["type"] as? String) == "session_meta",
                  let p = meta["payload"] as? [String: Any] else { continue }
            let cwd = p["cwd"] as? String ?? ""
            let sid = (p["session_id"] as? String) ?? (p["id"] as? String) ?? url.lastPathComponent
            let name = names[sid] ?? ((cwd as NSString).lastPathComponent)
            let info = SessionInfo(
                id: "codex:\(sid)", agent: .codex, cwd: cwd,
                name: name.isEmpty ? "Codex 会话" : name,
                pathTail: pathTail(cwd), ago: relativeTime(activity),
                messageCount: parseCodex(url, max: 20).count,
                status: "", logPath: url.path)
            out.append((info, activity))
        }
        return out
    }

    // MARK: - Public API

    /// Merged, most-recently-active-first list across all agents.
    static func list(max: Int = 12) -> [SessionInfo] {
        let merged = claudeCandidates() + codexCandidates()
        return merged.sorted { $0.1 > $1.1 }.prefix(max).map { $0.0 }
    }

    /// Conversation + newest-first preview for a session log.
    static func context(logPath: String, agent: AgentKind, max: Int = 20)
        -> (turns: [Turn], preview: [PreviewItem]) {
        let url = URL(fileURLWithPath: logPath)
        let turns = agent == .codex ? parseCodex(url, max: max) : parseClaude(url, max: max)
        let preview = turns.reversed().map {
            PreviewItem(role: $0.role,
                        snippet: String($0.content.prefix(60)).replacingOccurrences(of: "\n", with: " "),
                        ts: $0.ts)
        }
        return (turns, preview)
    }
}
