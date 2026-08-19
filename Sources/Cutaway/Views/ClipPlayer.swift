import AVKit
import AppKit
import Combine
import SwiftUI

struct ClipPlayerSheet: View {
    let clip: CandidateClip
    var close: () -> Void

    private enum StreamState {
        case loading
        case ready(URL)
        case failed
    }

    @State private var stream: StreamState = .loading

    private var playerSize: CGSize {
        clip.isVertical == true ? CGSize(width: 304, height: 540) : CGSize(width: 620, height: 349)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(clip.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.text)
                }
                .buttonStyle(.plain)
            }

            Group {
                switch stream {
                case .loading:
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Preparing preview")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready(let url):
                    ClipVideoPlayer(url: url, start: clip.cutStart, end: clip.cutEnd,
                                    onFail: { stream = .failed })
                case .failed:
                    VStack(spacing: 10) {
                        Text("Preview unavailable for this video")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textDim)
                        Button("Open on YouTube") { NSWorkspace.shared.open(clip.url) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: playerSize.width, height: playerSize.height)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 8) {
                if let cut = clip.cutRangeText {
                    TagCapsule(text: String(localized: "suggested cut \(cut)"))
                }
                Spacer()
                if !clip.url.isFileURL {
                    Button("Open on YouTube") { NSWorkspace.shared.open(clip.url) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.textDim)
                }
            }
        }
        .padding(16)
        .frame(width: playerSize.width + 32)
        .background(Theme.Colors.background)
        .task { await load() }
    }

    private func load() async {
        if clip.url.isFileURL {
            stream = .ready(clip.url)
            return
        }
        try? await YtDlp.ensure()
        if let url = await YtDlp.streamURL(id: clip.id) {
            stream = .ready(url)
        } else {
            stream = .failed
        }
    }
}

private struct ClipVideoPlayer: View {
    let url: URL
    let start: Double?
    let end: Double?
    var onFail: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let fresh = AVPlayer(url: url)
                if let start {
                    fresh.seek(to: CMTime(seconds: start, preferredTimescale: 600),
                               toleranceBefore: .zero, toleranceAfter: .positiveInfinity)
                }
                if let end {
                    let stop = NSValue(time: CMTime(seconds: end, preferredTimescale: 600))
                    fresh.addBoundaryTimeObserver(forTimes: [stop], queue: .main) { [weak fresh] in
                        fresh?.pause()
                    }
                }
                fresh.play()
                player = fresh
            }
            .onDisappear { player?.pause() }
            .onReceive(player?.currentItem?.publisher(for: \.status).eraseToAnyPublisher()
                       ?? Empty().eraseToAnyPublisher()) { status in
                if status == .failed { onFail() }
            }
    }
}
