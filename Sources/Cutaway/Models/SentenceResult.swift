import Foundation

struct SentenceResult {
    var state: SearchState = .idle
    var intent: SearchIntent?
    var candidates: [CandidateClip] = []
    var downloading: Set<String> = []
    var downloaded: [String: URL] = [:]
}

enum BatchScanState {
    case idle
    case running
    case stopped
    case finished
}
