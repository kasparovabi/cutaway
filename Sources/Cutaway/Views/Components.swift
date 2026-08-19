import SwiftUI

struct RoundButton: View {
    let icon: String
    var size: CGFloat = Theme.Metrics.roundButton
    var filled = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(filled ? Color.black : Theme.Colors.text)
                .frame(width: size, height: size)
                .background {
                    if filled {
                        Circle().fill(Theme.Colors.accent)
                    } else {
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().fill(Theme.Colors.buttonFill))
                            .overlay(Circle().strokeBorder(Theme.Colors.glassEdge, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
