import SwiftUI

/// An SF Symbol inside a soft circle or rounded square, in the style of Apple's system apps.
struct IconTile: View {
    enum Style { case solid, soft }

    let symbol: String
    let color: Color
    var size: CGFloat = 28
    var style: Style = .solid
    var rounded = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: rounded ? size * 0.28 : size / 2, style: .continuous)
        ZStack {
            switch style {
            case .solid:
                shape.fill(color.gradient)
                shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            case .soft:
                shape.fill(color.opacity(0.15))
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(style == .solid ? Color.white : color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CategoryBadge: View {
    let category: EventCategory
    var size: CGFloat = 28
    var style: IconTile.Style = .solid
    var rounded = false

    var body: some View {
        IconTile(symbol: category.symbol, color: category.color, size: size, style: style, rounded: rounded)
    }
}

/// A category badge sitting on the timeline spine, ringed with the canvas color so the line appears to pass behind it.
struct TimelineNode: View {
    let category: EventCategory
    var size: CGFloat = TimelineMetrics.nodeSize
    @Environment(\.canvasBaseColor) private var baseColor

    var body: some View {
        CategoryBadge(category: category, size: size)
            .shadow(color: category.color.opacity(0.35), radius: 5, y: 2)
            .padding(3)
            .background(Circle().fill(baseColor))
    }
}
