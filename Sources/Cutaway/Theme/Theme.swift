import SwiftUI

enum Theme {
    enum Colors {
        static let background = Color(red: 0.055, green: 0.055, blue: 0.063)
        static let grid = Color.white.opacity(0.035)
        static let glassEdge = Color.white.opacity(0.08)
        static let glassFill = Color.black.opacity(0.34)
        static let buttonFill = Color.black.opacity(0.42)
        static let text = Color.white.opacity(0.92)
        static let textDim = Color.white.opacity(0.55)
        static let accent = Color.white
    }

    enum Metrics {
        static let outerRadius: CGFloat = 28
        static let panelRadius: CGFloat = 20
        static let roundButton: CGFloat = 36
        static let panelPadding: CGFloat = 16
    }

    enum Fonts {
        static let title = Font.system(size: 13, weight: .medium)
    }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = Theme.Metrics.panelRadius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(Theme.Colors.glassFill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Colors.glassEdge, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }
}

extension View {
    func glassSurface(radius: CGFloat = Theme.Metrics.panelRadius) -> some View {
        modifier(GlassSurface(radius: radius))
    }
}
