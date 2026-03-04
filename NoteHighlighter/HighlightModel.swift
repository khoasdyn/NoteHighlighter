import SwiftUI
import PDFKit

struct Highlight: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let pageIndex: Int
    let pageLabel: String
    let color: HighlightColor
    let note: String?
    let bounds: CGRect
    let creationDate: Date?
    
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
        case .yellow:  return NSColor.yellow
        case .green:   return NSColor.green
        case .blue:    return NSColor.blue
        case .pink:    return NSColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0)
        case .purple:  return NSColor.purple
        case .orange:  return NSColor.orange
        case .red:     return NSColor.red
        case .unknown: return NSColor.gray
        }
    }
    
    /// Attempts to classify an NSColor into a named highlight color
    static func from(nsColor: NSColor?) -> HighlightColor {
        guard let color = nsColor?.usingColorSpace(.sRGB) else { return .unknown }
        
        let r = color.redComponent
        let g = color.greenComponent
        let b = color.blueComponent
        
        // Classify based on RGB dominance
        if r > 0.8 && g > 0.8 && b < 0.5 { return .yellow }
        if r < 0.5 && g > 0.6 && b < 0.5 { return .green }
        if r < 0.5 && g < 0.5 && b > 0.6 { return .blue }
        if r > 0.8 && g < 0.5 && b > 0.5 { return .pink }
        if r > 0.4 && g < 0.3 && b > 0.6 { return .purple }
        if r > 0.8 && g > 0.5 && b < 0.3 { return .orange }
        if r > 0.7 && g < 0.3 && b < 0.3 { return .red }
        if r > 0.7 && g > 0.7 && b < 0.4 { return .yellow } // Broader yellow match
        
        return .unknown
    }
}
