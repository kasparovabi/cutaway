import AppKit
import SwiftUI

struct LibraryView: View {
    var close: () -> Void

    @State private var library = Library.shared
    @State private var query = ""

    private var filtered: [LibraryRecord] {
        let needle = query.lowercased().trimmingCharacters(in: .whitespaces)
        let everything = library.records.sorted { $0.addedAt > $1.addedAt }
        guard !needle.isEmpty else { return everything }
        return everything.filter {
            $0.title.lowercased().contains(needle)
                || $0.tags.contains { $0.contains(needle) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 12, weight: .medium))
                Text("Library")
                    .font(Theme.Fonts.title)
                Text("\(library.records.count) clips")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.textDim)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Theme.Colors.text)

            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())

            if filtered.isEmpty {
                Text(library.records.isEmpty
                     ? String(localized: "The library is empty. Every clip you download is kept here for reuse.")
                     : String(localized: "No matching clips."))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filtered) { record in
                            Row(record: record,
                                reveal: { reveal(record) },
                                remove: { library.remove(record) })
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(Theme.Metrics.panelPadding)
        .frame(width: 360)
        .glassSurface()
    }

    private func reveal(_ record: LibraryRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([library.file(record)])
    }
}

private struct Row: View {
    let record: LibraryRecord
    let reveal: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(String(format: "%.0fs", record.duration))
                    Text("·")
                    Text(record.hasSpeech
                         ? (record.language ?? String(localized: "with speech"))
                         : String(localized: "speechless"))
                    if let vertical = record.isVertical {
                        Text("·")
                        Text(vertical ? String(localized: "vertical") : String(localized: "horizontal"))
                    }
                    if record.useCount > 1 {
                        Text("·")
                        Text("×\(record.useCount)")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textDim)
            }
            Spacer(minLength: 0)
            Button(action: remove) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textDim)
            }
            .buttonStyle(.plain)
            RoundButton(icon: "folder", size: 26, action: reveal)
        }
        .padding(8)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Theme.Colors.glassEdge, lineWidth: 1))
    }
}
