import Foundation

protocol ClipSource {
    var name: String { get }
    func search(query: String, maxDuration: Double) async throws -> [CandidateClip]
}

struct YouTubeSource: ClipSource {
    let name = "YouTube"
    /// Search pages are dominated by long videos; the 90-second cap keeps only
    /// a few per page, so fetch deep to leave a real pool after filtering.
    var perQuery = 25

    func search(query: String, maxDuration: Double) async throws -> [CandidateClip] {
        let output = try await Shell.run("yt-dlp", [
            "ytsearch\(perQuery):\(query)",
            "--flat-playlist",
            "--no-warnings",
            "--socket-timeout", "20",
            "--print", "%(duration)s\u{1F}%(id)s\u{1F}%(view_count)s\u{1F}%(title)s"
        ])

        return output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\u{1F}", maxSplits: 3,
                                    omittingEmptySubsequences: false)
            guard fields.count == 4,
                  let duration = Double(fields[0]), duration > 0, duration <= maxDuration,
                  let url = URL(string: "https://www.youtube.com/watch?v=\(fields[1])")
            else { return nil }
            return CandidateClip(id: String(fields[1]),
                                 title: String(fields[3]),
                                 duration: duration,
                                 source: name,
                                 url: url,
                                 views: Int(fields[2]))
        }
    }
}

enum ClipSearch {
    static func search(intent: SearchIntent, sources: [ClipSource],
                       vertical: Bool) async -> [CandidateClip] {
        var collected: [String: CandidateClip] = [:]
        await withTaskGroup(of: [CandidateClip].self) { group in
            for source in sources {
                for query in intent.queries {
                    let oriented = vertical ? "\(query) shorts" : query
                    group.addTask {
                        (try? await source.search(query: oriented, maxDuration: 90)) ?? []
                    }
                }
            }
            for await batch in group {
                for clip in batch { collected[clip.id] = clip }
            }
        }
        return Array(collected.values).sorted { $0.duration < $1.duration }
    }

    /// Flat search results carry no dimensions; a second metadata pass fills them.
    static func fillDimensions(_ clips: [CandidateClip]) async -> [CandidateClip] {
        await withTaskGroup(of: CandidateClip.self) { group in
            for clip in clips {
                group.addTask { await fetchDimensions(clip) }
            }
            var filled: [CandidateClip] = []
            for await clip in group { filled.append(clip) }
            return filled
        }
    }

    private static func fetchDimensions(_ clip: CandidateClip) async -> CandidateClip {
        guard let output = try? await Shell.run("yt-dlp", [
            clip.url.absoluteString,
            "--skip-download", "--no-warnings", "--no-playlist",
            "--socket-timeout", "20",
            "--print", "%(width)s\u{1F}%(height)s\u{1F}%(view_count)s"
        ]) else { return clip }

        let fields = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\u{1F}", omittingEmptySubsequences: false)
        guard fields.count >= 2, let width = Int(fields[0]), let height = Int(fields[1]) else {
            return clip
        }
        var updated = clip
        updated.width = width
        updated.height = height
        if fields.count >= 3, let views = Int(fields[2]) { updated.views = views }
        return updated
    }
}
