import SwiftUI

struct SentenceList: View {
    var project: Project

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(project.sentences) { sentence in
                    Row(sentence: sentence,
                        result: project.result(sentence.id),
                        selected: project.selectedSentence == sentence.id)
                        .contentShape(Rectangle())
                        .onTapGesture { project.selectedSentence = sentence.id }
                }
            }
            .padding(10)
        }
    }
}

private struct Row: View {
    let sentence: Sentence
    let result: SentenceResult
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(Format.minutesSeconds(sentence.start))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textDim)
                Spacer()
                badge
            }
            Text(sentence.text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(selected ? 0.12 : 0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? Theme.Colors.accent.opacity(0.8) : Theme.Colors.glassEdge,
                              lineWidth: 1)
        )
    }

    @ViewBuilder
    private var badge: some View {
        if !result.downloaded.isEmpty {
            tag(String(localized: "\(result.downloaded.count) downloaded"),
                color: .green.opacity(0.85))
        } else if result.state.isRunning {
            ProgressView().controlSize(.mini)
        } else if !result.candidates.isEmpty {
            tag(String(localized: "\(result.candidates.count) found"),
                color: Theme.Colors.accent.opacity(0.85))
        } else if case .failed = result.state {
            tag(String(localized: "none found"), color: .red.opacity(0.8))
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color, in: Capsule())
    }
}
