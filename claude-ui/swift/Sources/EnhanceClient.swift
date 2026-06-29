import Foundation

/// Talks to the PromptCocoPilot Optimize Input API (mcp-server/http_server.py),
/// same contract as the Python card: POST /enhance {draft, conversation?}.
enum EnhanceClient {
    static var endpoint: URL {
        let raw = ProcessInfo.processInfo.environment["ENHANCE_ENDPOINT"]
            ?? "http://127.0.0.1:8765/enhance"
        return URL(string: raw)!
    }

    enum EnhanceError: LocalizedError {
        case serverDown
        case server(String)
        var errorDescription: String? {
            switch self {
            case .serverDown: return "增强服务未运行"
            case .server(let m): return m
            }
        }
    }

    /// POST the draft (+ conversation) and return the enhanced text.
    static func enhance(draft: String, conversation: [Turn]) async throws -> String {
        var body: [String: Any] = ["draft": draft]
        if !conversation.isEmpty {
            body["conversation"] = conversation.map {
                ["role": $0.role, "content": $0.content, "ts": $0.ts]
            }
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw EnhanceError.serverDown
        }

        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw EnhanceError.server(obj["error"] as? String ?? "HTTP \(http.statusCode)")
        }
        return (obj["enhanced"] as? String) ?? ""
    }
}
