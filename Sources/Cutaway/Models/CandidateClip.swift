import Foundation

struct SearchIntent: Decodable {
    let emotion: String
    let reaction: String
    let queries: [String]
    let speechlessOk: Bool
}

struct CandidateClip: Identifiable, Hashable {
    let id: String
    let title: String
    let duration: Double
    let source: String
    let url: URL
    var language: String?
    var score: Int = 0
    var reason: String = ""
    var width: Int?
    var height: Int?

    var languageBadge: String { language ?? String(localized: "language unknown") }
    var durationText: String { String(format: "%.0fs", duration) }

    var isVertical: Bool? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return height > width
    }

    var thumbnail: URL? {
        source == "YouTube" ? URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg") : nil
    }
}

enum SearchState: Equatable {
    case idle
    case intent
    case searching
    case measuring
    case scoring
    case ready
    case failed(String)

    var text: String {
        switch self {
        case .idle, .ready: ""
        case .intent: String(localized: "Reading the sentence's intent")
        case .searching: String(localized: "Searching clips")
        case .measuring: String(localized: "Measuring orientation")
        case .scoring: String(localized: "Scoring candidates")
        case .failed(let detail): detail
        }
    }

    var isRunning: Bool {
        switch self {
        case .intent, .searching, .measuring, .scoring: true
        default: false
        }
    }
}
