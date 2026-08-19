import Foundation

enum Doctor {
    struct Tool: Identifiable {
        let id: String
        let install: String
    }

    static let required = [
        Tool(id: "whisper", install: "brew install openai-whisper"),
        Tool(id: "ffmpeg", install: "brew install ffmpeg")
    ]

    static func missing() -> [Tool] {
        required.filter { tool in
            if tool.id == "whisper", GroqTranscriber.available { return false }
            return Shell.tool(tool.id) == nil
        }
    }
}
