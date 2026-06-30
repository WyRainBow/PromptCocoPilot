import Foundation

/// Calls /generate_reply to get contextual reply suggestions.
enum ReplySuggestionClient {
    static var endpoint: URL {
        let raw = ProcessInfo.processInfo.environment["ENHANCE_ENDPOINT"]
            ?? "http://127.0.0.1:8765/generate_reply"
        return URL(string: raw)!
    }

    enum ReplyError: LocalizedError {
        case serverDown
        case server(String)
        var errorDescription: String? {
            switch self {
            case .serverDown: return "上下文感知服务未运行"
            case .server(let m): return m
            }
        }
    }

    struct Response: Codable {
        let suggestions: [String]
        let contextSummary: String

        enum CodingKeys: String, CodingKey {
            case suggestions
            case contextSummary = "context_summary"
        }
    }

    static func fetchSuggestions(
        context: ContextAwareness.Context,
        draft: String = "",
        numSuggestions: Int = 3
    ) async throws -> Response {
        let encoder = JSONEncoder()
        let contextData = try encoder.encode(context)
        let contextDict = try JSONSerialization.jsonObject(with: contextData) as? [String: Any] ?? [:]

        let body: [String: Any] = [
            "context": contextDict,
            "draft": draft,
            "num_suggestions": numSuggestions,
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw ReplyError.serverDown
        }

        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw ReplyError.server(obj["error"] as? String ?? "HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded
    }
}
