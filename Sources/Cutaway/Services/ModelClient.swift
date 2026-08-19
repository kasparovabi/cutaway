import Foundation

enum ModelClient {
    static let model = UserDefaults.standard.string(forKey: "cutaway.model") ?? "claude-opus-5"

    private static let claudeCodeIdentity =
        "You are Claude Code, Anthropic's official CLI for Claude."

    /// Returns JSON matching the schema. Credentials are tried in order: any
    /// that is rate limited (429) or invalid is skipped for the next one.
    static func json(prompt: String, schema: [String: Any]) async throws -> Data {
        let credentials = Credentials.ordered()
        guard !credentials.isEmpty else { throw ModelError.noCredentials }

        var exhausted = 0
        var lastError: Error?

        for credential in credentials {
            do {
                let data = try await call(prompt: prompt, schema: schema, credential: credential)
                Credentials.markWorking(credential)
                return data
            } catch ModelError.rateLimited {
                exhausted += 1
            } catch ModelError.invalidCredential {
                lastError = ModelError.invalidCredential
            } catch {
                throw error
            }
        }

        if exhausted > 0 { throw ModelError.allExhausted(exhausted) }
        throw lastError ?? ModelError.noCredentials
    }

    private static func call(prompt: String, schema: [String: Any],
                             credential: Credential) async throws -> Data {
        do {
            return try await request(prompt: prompt, schema: schema, credential: credential)
        } catch ModelError.schemaRejected {
            // Some credential kinds reject structured output; retry without the
            // schema and extract the JSON from plain text.
            let data = try await request(prompt: prompt + "\n\n" + schemaInstruction(schema),
                                         schema: nil, credential: credential)
            guard let extracted = extractJSON(data) else { throw ModelError.emptyResponse }
            return extracted
        }
    }

    private static func request(prompt: String, schema: [String: Any]?,
                                credential: Credential) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 180

        if credential.isOAuth {
            request.setValue("Bearer \(credential.value)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        } else {
            request.setValue(credential.value, forHTTPHeaderField: "x-api-key")
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [["role": "user", "content": prompt]]
        ]
        // Setup tokens expect the Claude Code identity as the first system block;
        // without it the server answers with a 429 unrelated to quota.
        if credential.isOAuth {
            body["system"] = [["type": "text", "text": Self.claudeCodeIdentity]]
        }
        if let schema {
            body["output_config"] = [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": schema]
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ModelError.badResponse }

        switch http.statusCode {
        case 200: break
        case 429: throw ModelError.rateLimited
        case 401, 403: throw ModelError.invalidCredential
        case 400 where schema != nil && errorMessage(data).lowercased().contains("output_config"):
            throw ModelError.schemaRejected
        default: throw ModelError.status(http.statusCode, errorMessage(data))
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        if decoded.stop_reason == "refusal" { throw ModelError.refused }
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              let payload = text.data(using: .utf8) else { throw ModelError.emptyResponse }
        return payload
    }

    private static func schemaInstruction(_ schema: [String: Any]) -> String {
        let text = (try? JSONSerialization.data(withJSONObject: schema))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "Return only JSON matching this JSON schema, no code fences or prose:\n\(text)"
    }

    private static func extractJSON(_ data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for (open, close) in [("{", "}"), ("[", "]")] {
            guard let first = text.firstIndex(of: Character(open)),
                  let last = text.lastIndex(of: Character(close)), first < last else { continue }
            let slice = Data(text[first...last].utf8)
            if (try? JSONSerialization.jsonObject(with: slice)) != nil { return slice }
        }
        return nil
    }

    private static func errorMessage(_ data: Data) -> String {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = dict["error"] as? [String: Any],
              let message = error["message"] as? String else { return "" }
        return message
    }

    private struct Response: Decodable {
        let content: [Block]
        let stop_reason: String?

        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }
}

enum ModelError: LocalizedError {
    case noCredentials
    case badResponse
    case emptyResponse
    case refused
    case rateLimited
    case invalidCredential
    case schemaRejected
    case allExhausted(Int)
    case status(Int, String)

    var errorDescription: String? {
        switch self {
        case .noCredentials: String(localized: "no credential available, add one in Settings")
        case .badResponse: String(localized: "unreadable server response")
        case .emptyResponse: String(localized: "the model returned an empty response")
        case .refused: String(localized: "the model refused this request")
        case .rateLimited: String(localized: "rate limit reached")
        case .invalidCredential: String(localized: "credential invalid or expired")
        case .schemaRejected: String(localized: "schema rejected")
        case .allExhausted(let count):
            String(localized: "all \(count) credentials are rate limited, try again later")
        case .status(let code, let message):
            message.isEmpty
                ? String(localized: "API error \(code)")
                : String(localized: "API error \(code): \(message)")
        }
    }
}
