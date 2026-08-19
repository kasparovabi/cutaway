import Foundation

enum GroqTranscriber {
    static var apiKey: String? { Credentials.groqKey }
    static var available: Bool { apiKey != nil }

    static func transcribe(media: URL) async throws -> Transcription.Output {
        guard let key = apiKey else { throw GroqError.invalidKey }
        let audio = try await extractAudio(media)
        defer { try? FileManager.default.removeItem(at: audio) }

        let boundary = "cutaway-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("model", "whisper-large-v3-turbo")
        field("response_format", "verbose_json")
        field("timestamp_granularities[]", "word")
        field("timestamp_granularities[]", "segment")
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n".utf8))
        body.append(try Data(contentsOf: audio))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else { throw GroqError.status(0, "") }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw GroqError.invalidKey
        case 413: throw GroqError.tooLarge
        default: throw GroqError.status(http.statusCode, errorMessage(data))
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let words = (decoded.words ?? []).map {
            WhisperOutput.Word(word: $0.word, start: $0.start, end: $0.end)
        }
        let segments: [WhisperOutput.Segment]
        if words.isEmpty {
            segments = (decoded.segments ?? []).map {
                WhisperOutput.Segment(start: $0.start, end: $0.end, text: $0.text, words: nil)
            }
        } else {
            segments = [WhisperOutput.Segment(start: words.first?.start ?? 0,
                                              end: words.last?.end ?? 0,
                                              text: decoded.text,
                                              words: words)]
        }
        let output = WhisperOutput(language: normalize(decoded.language ?? "en"),
                                   segments: segments)
        return Transcription.Output(language: output.language,
                                    sentences: Transcription.splitSentences(output))
    }

    private static func extractAudio(_ media: URL) async throws -> URL {
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("cutaway-groq-\(UUID().uuidString).m4a")
        _ = try await Shell.run("ffmpeg", [
            "-y", "-loglevel", "error",
            "-i", media.path,
            "-vn", "-ac", "1", "-ar", "16000",
            "-c:a", "aac", "-b:a", "48k",
            target.path
        ])
        return target
    }

    /// verbose_json reports the language as a full name ("english"); the rest
    /// of the pipeline speaks ISO codes like the local whisper CLI does.
    private static let languageCodes: [String: String] = [
        "english": "en", "turkish": "tr", "spanish": "es", "german": "de",
        "french": "fr", "italian": "it", "portuguese": "pt", "russian": "ru",
        "arabic": "ar", "japanese": "ja", "korean": "ko", "chinese": "zh",
        "hindi": "hi", "dutch": "nl", "polish": "pl", "indonesian": "id",
        "azerbaijani": "az", "ukrainian": "uk", "persian": "fa", "urdu": "ur"
    ]

    private static func normalize(_ language: String) -> String {
        let lowered = language.lowercased()
        return languageCodes[lowered] ?? lowered
    }

    private static func errorMessage(_ data: Data) -> String {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = dict["error"] as? [String: Any],
              let message = error["message"] as? String else { return "" }
        return message
    }

    private struct Response: Decodable {
        let text: String
        let language: String?
        let segments: [Segment]?
        let words: [Word]?

        struct Segment: Decodable {
            let start: Double
            let end: Double
            let text: String
        }

        struct Word: Decodable {
            let word: String
            let start: Double
            let end: Double
        }
    }
}

enum GroqError: LocalizedError {
    case invalidKey
    case tooLarge
    case status(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidKey: String(localized: "Groq key invalid or expired")
        case .tooLarge: String(localized: "audio too large for Groq, install whisper for local transcription")
        case .status(let code, let message):
            message.isEmpty
                ? String(localized: "Groq error \(code)")
                : String(localized: "Groq error \(code): \(message)")
        }
    }
}
