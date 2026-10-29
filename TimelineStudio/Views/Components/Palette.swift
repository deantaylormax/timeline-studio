import SwiftUI
import AppKit

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    /// A color that resolves differently in light and dark appearances.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    init(lightHex: UInt32, darkHex: UInt32) {
        self.init(light: NSColor(hex: lightHex), dark: NSColor(hex: darkHex))
    }
}

enum Palette {
    static let cardFill = Color(lightHex: 0xFFFFFF, darkHex: 0x2B2B2E)
    static let cardStroke = Color(light: NSColor.black.withAlphaComponent(0.06),
                                  dark: NSColor.white.withAlphaComponent(0.09))
    static let spine = Color(light: NSColor.black.withAlphaComponent(0.11),
                             dark: NSColor.white.withAlphaComponent(0.15))
    static let dayDot = Color(light: NSColor.black.withAlphaComponent(0.30),
                              dark: NSColor.white.withAlphaComponent(0.42))
}

enum TimelineMetrics {
    static let timeColumn: CGFloat = 80
    static let nodeColumn: CGFloat = 54
    static let nodeSize: CGFloat = 30
    static let maxContentWidth: CGFloat = 800
    static let cardCornerRadius: CGFloat = 14
    static var spineX: CGFloat { timeColumn + nodeColumn / 2 }
}

extension View {
    /// A floating surface: material while live, solid when rendering for export (materials don't render offscreen).
    func surface<S: InsettableShape>(_ shape: S, exporting: Bool) -> some View {
        background {
            if exporting {
                shape.fill(Palette.cardFill)
            } else {
                shape.fill(.regularMaterial)
            }
        }
        .overlay(shape.strokeBorder(Palette.cardStroke, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.07), radius: 6, y: 2)
    }
}
