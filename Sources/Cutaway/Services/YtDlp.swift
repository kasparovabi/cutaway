import Foundation

enum YtDlp {
    static let managedBinary = Shell.managedBin.appendingPathComponent("yt-dlp")

    private static let updatedAtKey = "cutaway.ytDlpUpdatedAt"
    private static let releaseURL =
        URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!

    /// A brew or pipx install wins when present; otherwise the official
    /// standalone build is fetched into Application Support once.
    static func ensure() async throws {
        if Shell.tool("yt-dlp") != nil {
            await refreshIfStale()
            return
        }
        let (temp, response) = try await URLSession.shared.download(from: releaseURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw BootstrapError.downloadFailed
        }
        try? FileManager.default.removeItem(at: managedBinary)
        try FileManager.default.moveItem(at: temp, to: managedBinary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: managedBinary.path)
        UserDefaults.standard.set(Date(), forKey: updatedAtKey)
    }

    /// Direct stream address for in-app preview. HLS first: googlevideo's
    /// progressive mp4 URLs 403 outside yt-dlp's own client, the HLS
    /// manifests play fine in AVPlayer.
    static func streamURL(id: String) async -> URL? {
        let watch = "https://www.youtube.com/watch?v=\(id)"
        let attempts: [[String]] = [
            ["-g", "-f", "b[protocol^=m3u8]/b", "--no-playlist", watch],
            ["-g", "-f", "b[protocol^=m3u8]/b", "--no-playlist",
             "--extractor-args", "youtube:player_client=ios", watch]
        ]
        for arguments in attempts {
            guard let output = try? await Shell.run("yt-dlp", arguments),
                  let line = output.split(separator: "\n").first,
                  let url = URL(string: String(line).trimmingCharacters(in: .whitespaces))
            else { continue }
            return url
        }
        return nil
    }

    /// YouTube breaks old yt-dlp builds regularly; the managed copy
    /// self-updates weekly so downloads keep working without user action.
    private static func refreshIfStale() async {
        guard FileManager.default.isExecutableFile(atPath: managedBinary.path) else { return }
        let last = UserDefaults.standard.object(forKey: updatedAtKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 7 * 86400 else { return }
        UserDefaults.standard.set(Date(), forKey: updatedAtKey)
        _ = try? await Shell.run("yt-dlp", ["-U"])
    }

    enum BootstrapError: LocalizedError {
        case downloadFailed

        var errorDescription: String? {
            String(localized: "couldn't download yt-dlp, check your connection")
        }
    }
}
