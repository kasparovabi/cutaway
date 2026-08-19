import SwiftUI

struct DiscoveryView: View {
    var project: Project
    @State private var settingsOpen = false
    @State private var libraryOpen = false

    private var selected: Sentence? {
        project.sentences.first { $0.id == project.selectedSentence }
    }

    var body: some View {
        ZStack {
            BackgroundGrid()
            content.padding(24)
            if settingsOpen {
                SettingsView(close: { settingsOpen = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(40)
            } else if libraryOpen {
                LibraryView(close: { libraryOpen = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(40)
            }
        }
        .background(Theme.Colors.background)
    }

    private var content: some View {
        VStack(spacing: 0) {
            TopBar(project: project,
                   importVideo: importVideo,
                   toggleLibrary: { libraryOpen.toggle(); settingsOpen = false },
                   toggleSettings: { settingsOpen.toggle(); libraryOpen = false })
            Divider().overlay(Theme.Colors.glassEdge)
            if project.sentences.isEmpty {
                StartCard(project: project, importVideo: importVideo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    SentenceList(project: project).frame(width: 320)
                    Divider().overlay(Theme.Colors.glassEdge)
                    if let selected {
                        CandidateList(project: project, sentence: selected)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.outerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.outerRadius, style: .continuous)
                .strokeBorder(Theme.Colors.glassEdge, lineWidth: 1)
        )
    }

    private func importVideo() {
        guard let url = VideoPicker.pick() else { return }
        Task { await project.open(url) }
    }
}

private struct TopBar: View {
    var project: Project
    let importVideo: () -> Void
    let toggleLibrary: () -> Void
    let toggleSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundButton(icon: "square.and.arrow.down", size: 32, action: importVideo)
                .help("Import Video…")

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name.isEmpty ? String(localized: "No video selected") : project.name)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.text)
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.textDim)
            }

            Spacer()

            if project.transcriptState == .ready, !project.sentences.isEmpty {
                if project.batchScan == .running {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Button("Stop") { project.stopScan() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.text)
                    }
                } else {
                    pillButton(String(localized: "Scan all sentences")) { project.scanAll() }
                }
            }

            if project.video != nil, project.transcriptState != .ready {
                pillButton(project.transcriptState == .running
                           ? String(localized: "Transcribing…")
                           : String(localized: "Transcribe speech")) {
                    project.transcribe()
                }
            }

            RoundButton(icon: "rectangle.stack", size: 32, action: toggleLibrary)
                .help("Library")
            RoundButton(icon: "gearshape", size: 32, action: toggleSettings)
                .help("Settings")
        }
        .padding(.horizontal, Theme.Metrics.panelPadding)
        .padding(.vertical, 12)
    }

    private var statusText: String {
        guard project.video != nil else { return String(localized: "Select a video to begin") }
        if case .failed(let detail) = project.transcriptState { return detail }
        if project.sentences.isEmpty {
            return "\(project.durationText) · \(project.transcriptState.text)"
        }
        return String(localized: "\(project.durationText) · \(project.sentences.count) sentences · \(project.suggestionCount) found · \(project.downloadCount) downloaded")
    }

    private func pillButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.Colors.accent, in: Capsule())
    }
}

private struct StartCard: View {
    var project: Project
    let importVideo: () -> Void

    @State private var missingTools = Doctor.missing()

    var body: some View {
        VStack(spacing: 14) {
            if project.isLoading {
                ProgressView().controlSize(.small)
                Text("Reading video")
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.text)
            } else {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Theme.Colors.text)
                Text(project.video == nil ? "Pick the video you're editing" : "Transcribe speech")
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.text)
                Text(project.video == nil
                     ? "We transcribe the speech and find a clip to cut in after every sentence."
                     : "Once sentences appear, each gets its own clip suggestions.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                if let error = project.error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.9))
                }
                if project.video == nil {
                    Button("Pick a file", action: importVideo)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Theme.Colors.accent, in: Capsule())
                }
                if !missingTools.isEmpty {
                    toolsCard
                }
            }
        }
    }

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Missing tools")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.yellow.opacity(0.9))
            ForEach(missingTools) { tool in
                HStack(spacing: 8) {
                    Text(tool.id)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(width: 60, alignment: .leading)
                    Text(tool.install)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textDim)
                        .textSelection(.enabled)
                }
            }
            Text("Cutaway runs these on your Mac for transcription, search, and downloads.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textDim)
            Button("Check again") { missingTools = Doctor.missing() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.1), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: 360, alignment: .leading)
        .background(Color.yellow.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.yellow.opacity(0.25), lineWidth: 1))
        .padding(.top, 10)
    }
}

struct BackgroundGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 44
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            ctx.stroke(path, with: .color(Theme.Colors.grid), lineWidth: 1)
        }
        .ignoresSafeArea()
    }
}
