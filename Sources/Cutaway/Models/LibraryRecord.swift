import Foundation

struct LibraryRecord: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var fileName: String
    var duration: Double
    var language: String?
    var hasSpeech: Bool
    var width: Int?
    var height: Int?
    var tags: [String]
    var addedAt: Date
    var useCount: Int

    var isVertical: Bool? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return height > width
    }

    func candidate(file: URL) -> CandidateClip {
        CandidateClip(id: id,
                      title: title,
                      duration: duration,
                      source: Library.sourceName,
                      url: file,
                      language: language,
                      score: 0,
                      reason: String(localized: "from library"),
                      width: width,
                      height: height)
    }
}
