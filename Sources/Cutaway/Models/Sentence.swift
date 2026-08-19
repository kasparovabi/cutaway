import Foundation

struct Sentence: Identifiable, Hashable {
    let id = UUID()
    let start: Double
    let end: Double
    let text: String
}

enum TranscriptState: Equatable {
    case none
    case running
    case ready
    case failed(String)

    var text: String {
        switch self {
        case .none: String(localized: "No transcript")
        case .running: String(localized: "Transcribing…")
        case .ready: String(localized: "Transcript ready")
        case .failed: String(localized: "Transcription failed")
        }
    }
}
