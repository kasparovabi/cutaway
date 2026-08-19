import AVFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class Project {
    static let shared = Project()

    var name = ""
    var video: AVURLAsset?
    var duration: Double = 0
    var language: String?
    var sourceIsVertical = false
    var isLoading = false
    var error: String?

    var sentences: [Sentence] = []
    var transcriptState: TranscriptState = .none
    var selectedSentence: Sentence.ID?

    var results: [Sentence.ID: SentenceResult] = [:]
    var batchScan: BatchScanState = .idle
    var downloadFolder: URL?

    var durationText: String { Format.minutesSeconds(duration) }
    var suggestionCount: Int { results.values.reduce(0) { $0 + $1.candidates.count } }
    var downloadCount: Int { results.values.reduce(0) { $0 + $1.downloaded.count } }

    func result(_ id: Sentence.ID) -> SentenceResult { results[id] ?? SentenceResult() }

    func open(_ url: URL) async {
        isLoading = true
        error = nil
        let asset = AVURLAsset(url: url)
        do {
            let length = try await asset.load(.duration)
            guard length.isNumeric else { throw ProjectError.durationUnreadable }

            video = asset
            duration = length.seconds
            name = url.deletingPathExtension().lastPathComponent
            sentences = []
            results = [:]
            selectedSentence = nil
            transcriptState = .none
            batchScan = .idle
            downloadFolder = url.deletingLastPathComponent()
                .appendingPathComponent("\(name)-clips", isDirectory: true)

            if let track = try await asset.loadTracks(withMediaType: .video).first {
                let natural = try await track.load(.naturalSize)
                let transformed = natural.applying(try await track.load(.preferredTransform))
                sourceIsVertical = abs(transformed.height) > abs(transformed.width)
            }
            isLoading = false
            transcribe()
            return
        } catch {
            self.error = String(localized: "Couldn't open video: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func transcribe() {
        guard let url = video?.url, transcriptState != .running else { return }
        transcriptState = .running
        sentences = []
        results = [:]
        Task {
            do {
                let output = try await Transcription.run(video: url)
                guard video?.url == url else { return }
                language = output.language
                sentences = output.sentences
                selectedSentence = output.sentences.first?.id
                transcriptState = output.sentences.isEmpty
                    ? .failed(String(localized: "no speech found in the video"))
                    : .ready
            } catch {
                guard video?.url == url else { return }
                transcriptState = .failed(error.localizedDescription)
            }
        }
    }

    func findClips(_ id: Sentence.ID) {
        guard let sentence = sentences.first(where: { $0.id == id }),
              !result(id).state.isRunning else { return }
        Task { await scan(sentence) }
    }

    func scanAll() {
        guard batchScan != .running, !sentences.isEmpty else { return }
        batchScan = .running
        Task {
            for sentence in sentences {
                if batchScan == .stopped { break }
                guard sentences.contains(where: { $0.id == sentence.id }) else { break }
                guard result(sentence.id).candidates.isEmpty else { continue }
                await scan(sentence)
            }
            batchScan = batchScan == .stopped ? .idle : .finished
        }
    }

    func stopScan() {
        if batchScan == .running { batchScan = .stopped }
    }

    private func scan(_ sentence: Sentence) async {
        let videoLanguage = language ?? "en"
        update(sentence.id) { $0.state = .intent; $0.candidates = []; $0.intent = nil }

        do {
            let intent = try await IntentEngine.makeIntent(sentence: sentence.text,
                                                           language: videoLanguage)
            update(sentence.id) { $0.intent = intent; $0.state = .searching }

            let fromLibrary = Library.shared.search(intent: intent, language: videoLanguage,
                                                    vertical: sourceIsVertical)
            let found = await ClipSearch.search(intent: intent,
                                                sources: [YouTubeSource()],
                                                vertical: sourceIsVertical)
            guard !found.isEmpty || !fromLibrary.isEmpty else {
                update(sentence.id) { $0.state = .failed(String(localized: "no candidate clips found")) }
                return
            }

            update(sentence.id) { $0.state = .measuring }
            let measured = await ClipSearch.fillDimensions(Array(found.prefix(12)))
            let oriented = measured.filter { $0.isVertical == sourceIsVertical }

            update(sentence.id) { $0.state = .scoring }
            let scored = try await IntentEngine.score(
                sentence: sentence.text, language: videoLanguage,
                candidates: oriented.isEmpty ? measured : oriented)

            let combined = fromLibrary + scored.filter { fresh in
                !fromLibrary.contains { $0.id == fresh.id }
            }
            update(sentence.id) {
                $0.candidates = Array(combined.prefix(5))
                $0.state = combined.isEmpty
                    ? .failed(String(localized: "no candidate passed the language and orientation filter"))
                    : .ready
            }
        } catch {
            update(sentence.id) { $0.state = .failed(error.localizedDescription) }
        }
    }

    func download(_ clip: CandidateClip, sentence: Sentence) {
        guard !result(sentence.id).downloading.contains(clip.id) else { return }
        update(sentence.id) { $0.downloading.insert(clip.id) }
        let folder = downloadFolder

        Task {
            do {
                let sourceFile = try await ClipDownloader.download(clip)
                let target = try ClipDownloader.copyForUser(
                    sourceFile, folder: folder, sentence: sentence, clip: clip)

                let verdict = try? await SpeechVerifier.verify(sourceFile, start: 0,
                                                               end: min(6, clip.duration))
                Library.shared.add(clip: clip, file: sourceFile,
                                   language: verdict?.language,
                                   hasSpeech: verdict?.hasSpeech ?? false,
                                   tags: tags(sentence.id))

                update(sentence.id) {
                    $0.downloading.remove(clip.id)
                    $0.downloaded[clip.id] = target
                }
            } catch {
                update(sentence.id) {
                    $0.downloading.remove(clip.id)
                    $0.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func tags(_ id: Sentence.ID) -> [String] {
        guard let intent = result(id).intent else { return [] }
        return [intent.emotion, intent.reaction] + intent.queries
    }

    private func update(_ id: Sentence.ID, _ mutate: (inout SentenceResult) -> Void) {
        var current = results[id] ?? SentenceResult()
        mutate(&current)
        results[id] = current
    }
}

enum ProjectError: LocalizedError {
    case durationUnreadable

    var errorDescription: String? { String(localized: "video duration unreadable") }
}

enum Format {
    static func minutesSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
