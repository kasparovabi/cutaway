import Foundation

@MainActor
@Observable
final class Library {
    static let shared = Library()
    nonisolated static var sourceName: String { String(localized: "Library") }

    private(set) var records: [LibraryRecord] = []

    private let indexFile: URL = ClipDownloader.folder
        .deletingLastPathComponent()
        .appendingPathComponent("library.json")

    init() { load() }

    func file(_ record: LibraryRecord) -> URL {
        ClipDownloader.folder.appendingPathComponent(record.fileName)
    }

    func add(clip: CandidateClip, file: URL, language: String?, hasSpeech: Bool, tags: [String]) {
        let adopted = adopt(file)
        let cleaned = tags
            .flatMap { $0.lowercased().split(separator: " ").map(String.init) }
            .filter { $0.count > 2 }
        let record = LibraryRecord(id: clip.id,
                                   title: clip.title,
                                   fileName: adopted.lastPathComponent,
                                   duration: clip.duration,
                                   language: language,
                                   hasSpeech: hasSpeech,
                                   width: clip.width,
                                   height: clip.height,
                                   tags: Array(Set(cleaned)),
                                   addedAt: Date(),
                                   useCount: 1)

        if let i = records.firstIndex(where: { $0.id == record.id }) {
            records[i].useCount += 1
            records[i].tags = Array(Set(records[i].tags + record.tags))
            records[i].language = language
            records[i].hasSpeech = hasSpeech
        } else {
            records.append(record)
        }
        save()
    }

    func remove(_ record: LibraryRecord) {
        try? FileManager.default.removeItem(at: file(record))
        records.removeAll { $0.id == record.id }
        save()
    }

    /// Language rule: a clip with speech only matches its own language,
    /// a speechless clip matches any.
    func search(intent: SearchIntent, language: String, vertical: Bool,
                limit: Int = 3) -> [CandidateClip] {
        let keywords = Set(
            ([intent.emotion, intent.reaction] + intent.queries)
                .flatMap { $0.lowercased().split(separator: " ").map(String.init) }
                .filter { $0.count > 2 }
        )

        return records
            .filter { FileManager.default.fileExists(atPath: file($0).path) }
            .filter { !$0.hasSpeech || $0.language == language }
            .filter { $0.isVertical == nil || $0.isVertical == vertical }
            .map { record -> (LibraryRecord, Int) in
                let shared = Set(record.tags).intersection(keywords).count
                let inTitle = keywords.filter { record.title.lowercased().contains($0) }.count
                return (record, shared * 2 + inTitle)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { record, weight in
                var clip = record.candidate(file: file(record))
                clip.score = min(10, 6 + weight)
                return clip
            }
    }

    /// The library must own its files; a record pointing outside the folder
    /// goes stale as soon as the source file disappears.
    private func adopt(_ file: URL) -> URL {
        let folder = ClipDownloader.folder
        guard file.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL
        else { return file }

        let target = folder.appendingPathComponent(file.lastPathComponent)
        if !FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.copyItem(at: file, to: target)
        }
        return FileManager.default.fileExists(atPath: target.path) ? target : file
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexFile),
              let decoded = try? JSONDecoder().decode([LibraryRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: indexFile, options: .atomic)
    }
}
