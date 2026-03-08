import SwiftUI

enum HighlightColor: String, CaseIterable {
    case yellow, green, blue, pink, purple, orange, red, unknown

    var swiftUIColor: Color {
        switch self {
        case .yellow:  .yellow
        case .green:   .green
        case .blue:    .blue
        case .pink:    .pink
        case .purple:  .purple
        case .orange:  .orange
        case .red:     .red
        case .unknown: .gray
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    /// Translucent color for PDF annotation overlays (35% alpha)
    var nsColor: NSColor {
        switch self {
        case .yellow:  NSColor(red: 1.0, green: 0.95, blue: 0.0, alpha: 0.35)
        case .green:   NSColor(red: 0.0, green: 0.8, blue: 0.2, alpha: 0.35)
        case .blue:    NSColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 0.35)
        case .pink:    NSColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 0.35)
        case .purple:  NSColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.35)
        case .orange:  NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.35)
        case .red:     NSColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.35)
        case .unknown: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.35)
        }
    }

    /// Opaque color for toolbar display circles
    var opaqueColor: NSColor {
        switch self {
        case .yellow:  NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
        case .green:   NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        case .blue:    NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        case .pink:    NSColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0)
        case .purple:  NSColor(red: 0.65, green: 0.3, blue: 0.9, alpha: 1.0)
        case .orange:  NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
        case .red:     NSColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)
        case .unknown: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        }
    }

    /// The selectable colors shown in the toolbar (excludes `.unknown`)
    static let selectableColors: [HighlightColor] = [.yellow, .blue, .green, .pink, .purple, .orange, .red]

    /// Attempts to classify an NSColor into a named highlight color
    static func from(nsColor: NSColor?) -> HighlightColor {
        guard let color = nsColor?.usingColorSpace(.sRGB) else { return .unknown }

        let r = color.redComponent
        let g = color.greenComponent
        let b = color.blueComponent

        var bestMatch: HighlightColor = .unknown
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        let references: [(HighlightColor, CGFloat, CGFloat, CGFloat)] = [
            (.yellow,  1.0, 0.95, 0.0),
            (.green,   0.0, 0.8,  0.2),
            (.blue,    0.2, 0.4,  1.0),
            (.pink,    1.0, 0.3,  0.6),
            (.purple,  0.6, 0.2,  0.9),
            (.orange,  1.0, 0.6,  0.0),
            (.red,     1.0, 0.2,  0.2),
        ]

        for (name, rr, rg, rb) in references {
            let dist = (r - rr) * (r - rr) + (g - rg) * (g - rg) + (b - rb) * (b - rb)
            if dist < bestDistance {
                bestDistance = dist
                bestMatch = name
            }
        }

        return bestDistance > 0.5 ? .unknown : bestMatch
    }
}
