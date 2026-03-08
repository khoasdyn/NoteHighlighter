import PDFKit

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
        text.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces)
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
