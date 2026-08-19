import AVFoundation
import Foundation

enum ClipDownloader {
    static let folder: URL = {
        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cutaway/clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }()

    static func download(_ clip: CandidateClip) async throws -> URL {
        if clip.url.isFileURL {
            guard FileManager.default.fileExists(atPath: clip.url.path) else {
                throw ClipError.downloadFailed
            }
            return clip.url
        }

        let target = folder.appendingPathComponent("YouTube-\(clip.id).mp4")
        if FileManager.default.fileExists(atPath: target.path) { return target }

        for attempt in attempts {
            try? FileManager.default.removeItem(at: target)
            if (try? await Shell.run("yt-dlp", arguments(clip, target, attempt: attempt))) != nil,
               FileManager.default.fileExists(atPath: target.path) {
                return target
            }
        }
        try? FileManager.default.removeItem(at: target)
        throw ClipError.downloadFailed
    }

    private struct Attempt {
        let selector: String?
        let client: String?
    }

    /// YouTube's separate video+audio streams 403 on some videos; a single-file
    /// format and a different player client rescue those.
    private static let attempts = [
        Attempt(selector: singleFile, client: nil),
        Attempt(selector: singleFile, client: "android"),
        Attempt(selector: nil, client: "android"),
        Attempt(selector: nil, client: nil)
    ]

    private static let singleFile =
        "best[ext=mp4][height<=1080]/best[height<=1080]/best[ext=mp4]/best"

    /// The copy the editor drops into their NLE: next to the source video,
    /// named by the sentence's timestamp.
    static func copyForUser(_ file: URL, folder: URL?,
                            sentence: Sentence, clip: CandidateClip) throws -> URL {
        let targetFolder = folder ?? FileManager.default
            .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)

        let stamp = String(format: "%02dm%02ds", Int(sentence.start) / 60, Int(sentence.start) % 60)
        let base = sanitized(clip.title)
        let target = targetFolder.appendingPathComponent("\(stamp)-\(base.isEmpty ? clip.id : base).mp4")
        if FileManager.default.fileExists(atPath: target.path) { return target }
        try FileManager.default.copyItem(at: file, to: target)
        return target
    }

    private static func sanitized(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        let filtered = text.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
            .prefix(48)
            .description
    }

    private static func arguments(_ clip: CandidateClip, _ target: URL,
                                  attempt: Attempt) -> [String] {
        var list = [clip.url.absoluteString]
        if let selector = attempt.selector { list += ["-f", selector] }
        if let client = attempt.client {
            list += ["--extractor-args", "youtube:player_client=\(client)"]
        }
        list += [
            "--merge-output-format", "mp4",
            "--no-playlist",
            "--no-warnings",
            "--socket-timeout", "30",
            "--retries", "3",
            "-o", target.path
        ]
        return list
    }
}

enum SpeechVerifier {
    struct Verdict {
        let language: String?
        let hasSpeech: Bool
    }

    static func verify(_ file: URL, start: Double, end: Double) async throws -> Verdict {
        let audio = try await extractAudio(file, start: start, duration: max(0.2, end - start))
        defer { try? FileManager.default.removeItem(at: audio) }
        let output = try await Transcription.run(video: audio, model: "base")
        let text = output.sentences.map(\.text).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSpeech = text.count >= 8
        return Verdict(language: hasSpeech ? output.language : nil, hasSpeech: hasSpeech)
    }

    private static func extractAudio(_ file: URL, start: Double, duration: Double) async throws -> URL {
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("cutaway-\(UUID().uuidString).wav")
        _ = try await Shell.run("ffmpeg", [
            "-y", "-loglevel", "error",
            "-ss", String(format: "%.3f", start),
            "-t", String(format: "%.3f", duration),
            "-i", file.path,
            "-vn", "-ac", "1", "-ar", "16000",
            target.path
        ])
        return target
    }
}

enum ClipError: LocalizedError {
    case downloadFailed

    var errorDescription: String? {
        String(localized: "couldn't download this clip, try another one (if every clip fails, update yt-dlp)")
    }
}
