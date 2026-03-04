import PDFKit

enum HighlightExtractor {

    static func extractHighlights(from document: PDFDocument) -> [Highlight] {
        var grouped: [String: [AnnotationEntry]] = [:]

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            for annotation in page.annotations {
                guard annotation.isHighlightAnnotation else { continue }

                let bounds = annotation.bounds
                let text = page.selection(for: bounds)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !text.isEmpty else { continue }

                let color = HighlightColor.from(nsColor: annotation.color)
                let rawNote = annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines)
                let note = (rawNote?.isEmpty == true) ? nil : rawNote
                let pageLabel = page.label ?? "\(pageIndex + 1)"

                let entry = AnnotationEntry(
                    pageIndex: pageIndex, pageLabel: pageLabel,
                    color: color, note: note, bounds: bounds, text: text
                )

                if let groupID = annotation.userName, !groupID.isEmpty {
                    grouped[groupID, default: []].append(entry)
                }
            }
        }

        var highlights: [Highlight] = []

        for (groupID, entries) in grouped {
            let sorted = entries.sorted { a, b in
                if a.pageIndex != b.pageIndex { return a.pageIndex < b.pageIndex }
                return a.bounds.midY > b.bounds.midY
            }

            guard let first = sorted.first else { continue }

            let startPage = sorted.min(by: { $0.pageIndex < $1.pageIndex })!.pageIndex
            let endPage = sorted.max(by: { $0.pageIndex < $1.pageIndex })!.pageIndex

            var mergedBounds = first.bounds
            var mergedTexts: [String] = []
            var mergedNote: String?

            for entry in sorted {
                if entry.pageIndex == first.pageIndex {
                    mergedBounds = mergedBounds.union(entry.bounds)
                }
                mergedTexts.append(entry.text)
                if let note = entry.note, !note.isEmpty {
                    if let existing = mergedNote {
                        mergedNote = existing + " " + note
                    } else {
                        mergedNote = note
                    }
                }
            }

            let fullText = mergedTexts.joined(separator: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !fullText.isEmpty else { continue }

            highlights.append(Highlight(
                text: fullText,
                pageIndex: startPage,
                endPageIndex: endPage,
                pageLabel: first.pageLabel,
                color: first.color,
                note: mergedNote,
                bounds: mergedBounds,
                creationDate: nil,
                groupID: groupID
            ))
        }

        highlights.sort { a, b in
            if a.pageIndex != b.pageIndex { return a.pageIndex < b.pageIndex }
            return a.bounds.midY > b.bounds.midY
        }

        return highlights
    }
}

// MARK: - Internal types

private extension HighlightExtractor {
    struct AnnotationEntry {
        let pageIndex: Int
        let pageLabel: String
        let color: HighlightColor
        let note: String?
        let bounds: CGRect
        let text: String
    }
}
