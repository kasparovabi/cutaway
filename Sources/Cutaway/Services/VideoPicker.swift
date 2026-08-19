import AppKit
import UniformTypeIdentifiers

enum VideoPicker {
    static func pick() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = String(localized: "Import")
        panel.message = String(localized: "Pick the main video you're editing")
        return panel.runModal() == .OK ? panel.url : nil
    }
}
