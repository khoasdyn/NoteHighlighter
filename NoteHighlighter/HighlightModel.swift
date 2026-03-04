import SwiftUI
import PDFKit

struct Highlight: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let pageIndex: Int
    let endPageIndex: Int
    let pageLabel: String
    let color: HighlightColor
    let note: String?
    let bounds: CGRect
    let creationDate: Date?
    let groupID: String?
    
    var spansMultiplePages: Bool { pageIndex != endPageIndex }
    
    /// The display-friendly page number (1-indexed)
    var pageNumber: Int {
        pageIndex + 1
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Highlight, rhs: Highlight) -> Bool {
        lhs.id == rhs.id
    }
}

enum HighlightColor: String, CaseIterable {
    case yellow
    case green
    case blue
    case pink
    case purple
    case orange
    case red
    case unknown
    
    var swiftUIColor: Color {
        switch self {
        case .yellow:  return Color.yellow
        case .green:   return Color.green
        case .blue:    return Color.blue
        case .pink:    return Color.pink
        case .purple:  return Color.purple
        case .orange:  return Color.orange
        case .red:     return Color.red
        case .unknown: return Color.gray
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var nsColor: NSColor {
        switch self {
        case .yellow:  return NSColor(red: 1.0, green: 0.95, blue: 0.0, alpha: 0.35)
        case .green:   return NSColor(red: 0.0, green: 0.8, blue: 0.2, alpha: 0.35)
        case .blue:    return NSColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 0.35)
        case .pink:    return NSColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 0.35)
        case .purple:  return NSColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.35)
        case .orange:  return NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.35)
        case .red:     return NSColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.35)
        case .unknown: return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.35)
        }
    }
    
    /// Attempts to classify an NSColor into a named highlight color
    static func from(nsColor: NSColor?) -> HighlightColor {
        guard let color = nsColor?.usingColorSpace(.sRGB) else { return .unknown }
        
        let r = color.redComponent
        let g = color.greenComponent
        let b = color.blueComponent
        
        // Find the closest match by comparing RGB (ignoring alpha)
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
        
        // Threshold: if too far from any known color, return unknown
        if bestDistance > 0.5 { return .unknown }
        
        return bestMatch
    }
}
