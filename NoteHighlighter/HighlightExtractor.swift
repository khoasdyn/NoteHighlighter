import PDFKit

struct HighlightExtractor {
    
    /// Extracts all highlight annotations from a PDFDocument
    static func extractHighlights(from document: PDFDocument) -> [Highlight] {
        var highlights: [Highlight] = []
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            let annotations = page.annotations
            
            for annotation in annotations {
                // Filter for highlight-type annotations
                guard annotation.type == "Highlight" ||
                      annotation.markupType == .highlight else { continue }
                
                // Extract the highlighted text from the page
                let bounds = annotation.bounds
                guard let selection = page.selection(for: bounds) else { continue }
                
                let text = selection.string ?? ""
                
                // Skip empty highlights
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                
                // Extract the note/comment (popup contents)
                let note = annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanNote = (note?.isEmpty == true) ? nil : note
                
                // Determine highlight color
                let color = HighlightColor.from(nsColor: annotation.color)
                
                // Page label (some PDFs use roman numerals, etc.)
                let pageLabel = page.label ?? "\(pageIndex + 1)"
                
                let highlight = Highlight(
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    pageIndex: pageIndex,
                    pageLabel: pageLabel,
                    color: color,
                    note: cleanNote,
                    bounds: bounds,
                    creationDate: annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "CreationDate")) as? Date
                )
                
                highlights.append(highlight)
            }
        }
        
        // Sort by page, then by vertical position (top to bottom)
        highlights.sort { a, b in
            if a.pageIndex != b.pageIndex {
                return a.pageIndex < b.pageIndex
            }
            // Higher Y value = higher on the page in PDF coordinates
            return a.bounds.origin.y > b.bounds.origin.y
        }
        
        return highlights
    }
}
