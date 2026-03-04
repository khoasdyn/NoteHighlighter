import PDFKit

struct HighlightExtractor {
    
    static func extractHighlights(from document: PDFDocument) -> [Highlight] {
        var rawEntries: [(pageIndex: Int, pageLabel: String, color: HighlightColor, note: String?, bounds: CGRect, text: String, groupID: String?)] = []
        
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
                
                rawEntries.append((
                    pageIndex: pageIndex,
                    pageLabel: pageLabel,
                    color: color,
                    note: cleanNote,
                    bounds: bounds,
                    text: text,
                    groupID: annotation.userName
                ))
            }
        }
        
        // Sort: page first, then top-to-bottom
        rawEntries.sort { a, b in
            if a.pageIndex != b.pageIndex { return a.pageIndex < b.pageIndex }
            return a.bounds.midY > b.bounds.midY
        }
        
        // Group entries: if annotations have a groupID, group by that.
        // Otherwise fall back to proximity + color merging (for imported PDFs).
        var highlights: [Highlight] = []
        var i = 0
        
        while i < rawEntries.count {
            let current = rawEntries[i]
            var mergedBounds = current.bounds
            var mergedTexts: [String] = [current.text]
            var mergedNote = current.note
            var j = i + 1
            
            while j < rawEntries.count {
                let next = rawEntries[j]
                guard next.pageIndex == current.pageIndex,
                      next.color == current.color else { break }
                
                // If both have groupIDs, only merge if they match
                if let currentGroup = current.groupID, !currentGroup.isEmpty,
                   let nextGroup = next.groupID, !nextGroup.isEmpty {
                    guard currentGroup == nextGroup else { break }
                } else if current.groupID != nil || next.groupID != nil {
                    // One has a groupID and the other doesn't — don't merge
                    break
                } else {
                    // Neither has a groupID (imported PDF) — use proximity
                    let gap = abs(mergedBounds.minY - next.bounds.maxY)
                    let lineHeight = max(mergedBounds.height, next.bounds.height)
                    guard gap < lineHeight * 1.5 else { break }
                }
                
                mergedBounds = mergedBounds.union(next.bounds)
                mergedTexts.append(next.text)
                
                if let nextNote = next.note, !nextNote.isEmpty {
                    if let existing = mergedNote {
                        mergedNote = existing + " " + nextNote
                    } else {
                        mergedNote = nextNote
                    }
                }
                
                j += 1
            }
            
            let fullText = mergedTexts.joined(separator: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !fullText.isEmpty else {
                i = j
                continue
            }
            
            let highlight = Highlight(
                text: fullText,
                pageIndex: current.pageIndex,
                pageLabel: current.pageLabel,
                color: current.color,
                note: mergedNote,
                bounds: mergedBounds,
                creationDate: nil,
                groupID: current.groupID
            )
            
            highlights.append(highlight)
            i = j
        }
        
        return highlights
    }
}
