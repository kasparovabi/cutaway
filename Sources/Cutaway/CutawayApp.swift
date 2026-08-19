import AppKit
import SwiftUI

@main
struct CutawayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            DiscoveryView(project: Project.shared)
                .frame(minWidth: 1024, minHeight: 768)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Video…") {
                    if let url = VideoPicker.pick() {
                        Task { await Project.shared.open(url) }
                    }
                }
                .keyboardShortcut("o")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task.detached { try? await YtDlp.ensure() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in await Project.shared.open(url) }
    }
}
