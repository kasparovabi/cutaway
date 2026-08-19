import AVFoundation
import AppKit
import SwiftUI

struct CandidateList: View {
    var project: Project
    let sentence: Sentence

    private var result: SentenceResult { project.result(sentence.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if result.state.isRunning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(result.state.text)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textDim)
                    }
                } else if case .failed(let detail) = result.state {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(result.candidates) { clip in
                    CandidateCard(clip: clip,
                                  isDownloading: result.downloading.contains(clip.id),
                                  downloadedPath: result.downloaded[clip.id],
                                  download: { project.download(clip, sentence: sentence) })
                }

                if result.candidates.isEmpty, !result.state.isRunning {
                    Text("No search yet for this sentence.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textDim)
                }
            }
            .padding(Theme.Metrics.panelPadding)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("“\(sentence.text)”")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                TagCapsule(text: Format.minutesSeconds(sentence.start))
                if let language = project.language { TagCapsule(text: language) }
                if let intent = result.intent {
                    TagCapsule(text: intent.emotion)
                    TagCapsule(text: intent.reaction)
                }
                Spacer()
                Button(result.candidates.isEmpty
                       ? String(localized: "Search clips")
                       : String(localized: "Search again")) {
                    project.findClips(sentence.id)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Theme.Colors.accent, in: Capsule())
                .disabled(result.state.isRunning)
            }
        }
    }
}

struct TagCapsule: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.Colors.text)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Colors.glassEdge, lineWidth: 1))
    }
}

private struct CandidateCard: View {
    let clip: CandidateClip
    let isDownloading: Bool
    let downloadedPath: URL?
    let download: () -> Void

    @State private var playing = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Thumbnail(url: clip.thumbnail, vertical: clip.isVertical == true)

            VStack(alignment: .leading, spacing: 5) {
                Text(clip.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(clip.durationText)
                    Text("·")
                    Text(clip.source)
                    Text("·")
                    Text(clip.languageBadge)
                    if let vertical = clip.isVertical {
                        Text("·")
                        Text(vertical ? String(localized: "vertical") : String(localized: "horizontal"))
                    }
                    if let views = clip.viewsCompact {
                        Text("·")
                        Text("\(views) views")
                    }
                    if let cut = clip.cutRangeText {
                        Text("·")
                        Text("cut \(cut)")
                            .foregroundStyle(Theme.Colors.accent.opacity(0.9))
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textDim)

                if !clip.reason.isEmpty {
                    Text(clip.reason)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.textDim)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Text("\(clip.score)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(clip.score >= 8 ? Theme.Colors.accent : Theme.Colors.textDim)

                HStack(spacing: 8) {
                    Button { playing = true } label: {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Colors.text)
                    }
                    .buttonStyle(.plain)
                    .help("Watch in app")
                    .sheet(isPresented: $playing) {
                        ClipPlayerSheet(clip: clip) { playing = false }
                    }

                    if let downloadedPath {
                        Button { NSWorkspace.shared.activateFileViewerSelecting([downloadedPath]) } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.green.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                        .help("Show in Finder")
                    } else if isDownloading {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(action: download) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Download")
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(downloadedPath != nil ? Color.green.opacity(0.5) : Theme.Colors.glassEdge,
                              lineWidth: 1)
        )
    }
}
