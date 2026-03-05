import SwiftUI
import PDFKit

// MARK: - Highlight

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

    var pageNumber: Int { pageIndex + 1 }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Highlight, rhs: Highlight) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - HighlightColor

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

    /// Translucent color for PDF annotation overlays (35% alpha)
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

    /// Opaque color for toolbar display circles
    var opaqueColor: NSColor {
        switch self {
        case .yellow:  return NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
        case .green:   return NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        case .blue:    return NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        case .pink:    return NSColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0)
        case .purple:  return NSColor(red: 0.65, green: 0.3, blue: 0.9, alpha: 1.0)
        case .orange:  return NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
        case .red:     return NSColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)
        case .unknown: return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
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

        if bestDistance > 0.5 { return .unknown }

        return bestMatch
    }
}

// MARK: - Search result grouping

struct SearchResultGroup: Identifiable {
    let id = UUID()
    let pageIndex: Int
    let pageLabel: String
    let selections: [PDFSelection]
    let query: String

    var matchCount: Int { selections.count }

    /// Snippet text with surrounding context for each match, including the original selection index
    var snippets: [(text: String, range: Range<String.Index>, selectionIndex: Int)] {
        selections.enumerated().compactMap { index, selection in
            guard let text = selection.string, !text.isEmpty else { return nil }
            guard let extended = selection.copy() as? PDFSelection else { return nil }
            extended.extend(atStart: 60)
            extended.extend(atEnd: 60)
            guard let rawText = extended.string else { return nil }

            let cleaned = Self.collapseWhitespace(rawText)
            guard !cleaned.isEmpty else { return nil }

            // Find the occurrence closest to center (the actual match, not a neighbor)
            let center = cleaned.count / 2
            var bestRange: Range<String.Index>?
            var bestDistance = Int.max
            var searchStart = cleaned.startIndex
            while let range = cleaned.range(of: query, options: .caseInsensitive, range: searchStart..<cleaned.endIndex) {
                let matchCenter = cleaned.distance(from: cleaned.startIndex, to: range.lowerBound) + query.count / 2
                let distance = abs(matchCenter - center)
                if distance < bestDistance {
                    bestDistance = distance
                    bestRange = range
                }
                searchStart = range.upperBound
            }
            guard let matchRange = bestRange else { return nil }

            let snippet = Self.extractCleanSnippet(from: cleaned, matchRange: matchRange, wordsBefore: 5, wordsAfter: 6)
            guard let snippetMatchRange = snippet.range(of: query, options: .caseInsensitive) else { return nil }

            return (snippet, snippetMatchRange, index)
        }
    }

    /// Collapses newlines and multiple spaces into single spaces
    private static func collapseWhitespace(_ text: String) -> String {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Extracts a word-boundary-trimmed snippet around the match
    private static func extractCleanSnippet(from text: String, matchRange: Range<String.Index>, wordsBefore: Int, wordsAfter: Int) -> String {
        let beforeText = String(text[text.startIndex..<matchRange.lowerBound])
        let matchText = String(text[matchRange])
        let afterText = String(text[matchRange.upperBound..<text.endIndex])

        // Take N words before the match
        let wordsBefore = beforeText
            .split(separator: " ", omittingEmptySubsequences: true)
            .suffix(wordsBefore)
            .joined(separator: " ")

        // Take N words after the match
        let wordsAfter = afterText
            .split(separator: " ", omittingEmptySubsequences: true)
            .prefix(wordsAfter)
            .joined(separator: " ")

        var result = ""
        if !wordsBefore.isEmpty { result += wordsBefore + " " }
        result += matchText
        if !wordsAfter.isEmpty { result += " " + wordsAfter }

        return result
    }
}

// MARK: - PDFAnnotation helpers

extension PDFAnnotation {
    /// Whether this annotation is a highlight (covers both string-typed and markup-typed checks)
    var isHighlightAnnotation: Bool {
        type == "Highlight" || markupType == .highlight
    }
}
