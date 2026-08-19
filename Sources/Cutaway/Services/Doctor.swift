import Foundation

enum Doctor {
    struct Tool: Identifiable {
        let id: String
        let install: String
    }

    static let required = [
        Tool(id: "whisper", install: "brew install openai-whisper"),
        Tool(id: "yt-dlp", install: "brew install yt-dlp"),
        Tool(id: "ffmpeg", install: "brew install ffmpeg")
    ]

    static func missing() -> [Tool] {
        required.filter { Shell.tool($0.id) == nil }
    }
}
