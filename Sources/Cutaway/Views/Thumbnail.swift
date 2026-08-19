import SwiftUI

@Observable
final class ImageCache {
    static let shared = ImageCache()
    private var images: [URL: NSImage] = [:]
    private var loading: Set<URL> = []

    func image(_ url: URL) -> NSImage? {
        if let ready = images[url] { return ready }
        guard !loading.contains(url) else { return nil }
        loading.insert(url)
        Task { @MainActor in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data) else { return }
            images[url] = image
        }
        return nil
    }
}

struct Thumbnail: View {
    let url: URL?
    let vertical: Bool

    private var cache = ImageCache.shared

    init(url: URL?, vertical: Bool) {
        self.url = url
        self.vertical = vertical
    }

    var body: some View {
        Group {
            if let url, let image = cache.image(url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [.orange.opacity(0.5), .red.opacity(0.3)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: vertical ? 26 : 46, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Theme.Colors.glassEdge, lineWidth: 1))
    }
}
