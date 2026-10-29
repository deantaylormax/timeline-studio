import Foundation

struct AIConnection: Equatable {
    var baseURL: String
    var model: String
    var apiKey: String
    var anthropic: Bool
}

enum AIClientError: LocalizedError {
    case locked
    case modelMissing
    case privateAIUnconfigured
    case badAddress
    case rejected(Int, String)
    case empty
    case unreadable

    var errorDescription: String? {
        switch self {
        case .locked:
            "AI tools turn on with a Pro or Private AI subscription."
        case .modelMissing:
            "Save the model name and API key for your provider first."
        case .privateAIUnconfigured:
            "Private AI is included with this subscription. This copy of the app does not have the Assured Workloads address yet, so the request cannot be sent."
        case .badAddress:
            "The model address is not a valid URL."
        case .rejected(let status, let detail):
            detail.isEmpty ? "The model returned status \(status)." : detail
        case .empty:
            "The model returned an empty response."
        case .unreadable:
            "The model response could not be read."
        }
    }
}

enum AIClient {
    static func complete(system: String, user: String, connection: AIConnection) async throws -> String {
        if connection.anthropic {
            return try await anthropic(system: system, user: user, connection: connection)
        }
        return try await openAI(system: system, user: user, connection: connection)
    }

    private static func openAI(system: String, user: String, connection: AIConnection) async throws -> String {
        let url = try endpoint(connection.baseURL, path: "/chat/completions")
        let body: [String: Any] = [
            "model": connection.model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !connection.apiKey.isEmpty {
            request.setValue("Bearer \(connection.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, status) = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIClientError.unreadable
        }
        if status >= 300 { throw AIClientError.rejected(status, errorMessage(object)) }
        guard let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw AIClientError.empty
        }
        if let text = message["content"] as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw AIClientError.empty }
            return trimmed
        }
        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { $0["text"] as? String }.joined()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw AIClientError.empty }
            return trimmed
        }
        throw AIClientError.empty
    }

    private static func anthropic(system: String, user: String, connection: AIConnection) async throws -> String {
        let url = try endpoint(connection.baseURL, path: "/messages")
        let body: [String: Any] = [
            "model": connection.model,
            "max_tokens": 4096,
            "temperature": 0.2,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(connection.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, status) = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIClientError.unreadable
        }
        if status >= 300 { throw AIClientError.rejected(status, errorMessage(object)) }
        guard let parts = object["content"] as? [[String: Any]] else { throw AIClientError.empty }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIClientError.empty }
        return trimmed
    }

    private static func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }

    private static func endpoint(_ base: String, path: String) throws -> URL {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        let absolute = trimmed.hasSuffix(path) ? trimmed : trimmed + path
        guard let url = URL(string: absolute), url.scheme == "https" || url.scheme == "http" else {
            throw AIClientError.badAddress
        }
        return url
    }

    private static func errorMessage(_ object: [String: Any]) -> String {
        if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        if let message = object["message"] as? String { return message }
        return ""
    }
}
