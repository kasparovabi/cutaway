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
