import PDFKit

struct HighlightExtractor {
    
    static func extractHighlights(from document: PDFDocument) -> [Highlight] {
        var grouped: [String: [(pageIndex: Int, pageLabel: String, color: HighlightColor, note: String?, bounds: CGRect, text: String)]] = [:]

        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            for annotation in page.annotations {
                guard annotation.type == "Highlight" ||
                      annotation.markupType == .highlight else { continue }
                
                let bounds = annotation.bounds
                let text = page.selection(for: bounds)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !text.isEmpty else { continue }
                
                let color = HighlightColor.from(nsColor: annotation.color)
                let note = annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanNote = (note?.isEmpty == true) ? nil : note
                let pageLabel = page.label ?? "\(pageIndex + 1)"
                
                let entry = (pageIndex: pageIndex, pageLabel: pageLabel, color: color, note: cleanNote, bounds: bounds, text: text)
                
                if let groupID = annotation.userName, !groupID.isEmpty {
                    grouped[groupID, default: []].append(entry)
                }
                // Skip ungrouped annotations — these are pre-existing highlights
                // from other PDF readers, not created by NoteHighlighter
            }
        }
        
        var highlights: [Highlight] = []
        
        // Process grouped annotations (may span multiple pages)
        for (groupID, entries) in grouped {
            let sorted = entries.sorted { a, b in
                if a.pageIndex != b.pageIndex { return a.pageIndex < b.pageIndex }
                return a.bounds.midY > b.bounds.midY
            }
            
            guard let first = sorted.first, let last = sorted.last else { continue }
            
            var mergedBounds = first.bounds
            var mergedTexts: [String] = []
            var mergedNote: String? = nil
            let startPage = sorted.min(by: { $0.pageIndex < $1.pageIndex })!.pageIndex
            let endPage = sorted.max(by: { $0.pageIndex < $1.pageIndex })!.pageIndex
            
            for entry in sorted {
                // Only union bounds for same-page entries (cross-page bounds are meaningless)
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
