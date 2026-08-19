import Foundation

enum Transcription {
    struct Output {
        let language: String
        let sentences: [Sentence]
    }

    static func run(video: URL, model: String = "large-v3-turbo") async throws -> Output {
        guard let whisper = Shell.tool("whisper") else { throw TranscriptError.whisperMissing }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("cutaway-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let process = Process()
        process.executableURL = whisper
        process.arguments = [
            video.path,
            "--model", model,
            "--output_format", "json",
            "--output_dir", folder.path,
            "--word_timestamps", "True",
            "--verbose", "False"
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(Shell.toolPath):\(environment["PATH"] ?? "")"
        process.environment = environment
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let text = String(data: errorOutput, encoding: .utf8) ?? ""
            throw TranscriptError.failed(text.suffix(300).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let json = folder.appendingPathComponent(video.deletingPathExtension().lastPathComponent + ".json")
        let data = try Data(contentsOf: json)
        let decoded = try JSONDecoder().decode(WhisperOutput.self, from: data)
        return Output(language: decoded.language, sentences: splitSentences(decoded))
    }

    private static let sentenceEnders: Set<Character> = [".", "!", "?", "…", ":", ";"]

    static func splitSentences(_ output: WhisperOutput) -> [Sentence] {
        let words = output.segments.flatMap { $0.words ?? [] }
        guard !words.isEmpty else {
            return output.segments.compactMap { segment in
                let text = segment.text.trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : Sentence(start: segment.start, end: segment.end, text: text)
            }
        }

        var sentences: [Sentence] = []
        var pending: [WhisperOutput.Word] = []

        for word in words {
            pending.append(word)
            guard let lastCharacter = word.word.trimmingCharacters(in: .whitespaces).last,
                  sentenceEnders.contains(lastCharacter) else { continue }
            sentences.append(assemble(pending))
            pending.removeAll()
        }
        if !pending.isEmpty { sentences.append(assemble(pending)) }
        return sentences.filter { !$0.text.isEmpty }
    }

    private static func assemble(_ words: [WhisperOutput.Word]) -> Sentence {
        Sentence(start: words.first?.start ?? 0,
                 end: words.last?.end ?? 0,
                 text: words.map(\.word).joined().trimmingCharacters(in: .whitespaces))
    }
}

struct WhisperOutput: Decodable {
    let language: String
    let segments: [Segment]

    struct Segment: Decodable {
        let start: Double
        let end: Double
        let text: String
        let words: [Word]?
    }

    struct Word: Decodable {
        let word: String
        let start: Double
        let end: Double
    }
}

enum TranscriptError: LocalizedError {
    case whisperMissing
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .whisperMissing: String(localized: "whisper not found (brew install openai-whisper)")
        case .failed(let detail): detail.isEmpty ? String(localized: "whisper failed") : detail
        }
    }
}
