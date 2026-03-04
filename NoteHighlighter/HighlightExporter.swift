import Foundation

struct HighlightExporter {
    
    static func toMarkdown(highlights: [Highlight], title: String) -> String {
        var lines: [String] = []
        
        lines.append("# \(title)")
        lines.append("")
        lines.append("**\(highlights.count) highlights**")
        lines.append("")
        
        // Group by page
        let grouped = Dictionary(grouping: highlights) { $0.pageNumber }
        let sortedPages = grouped.keys.sorted()
        
        for page in sortedPages {
            guard let pageHighlights = grouped[page] else { continue }
            
            lines.append("## Page \(page)")
            lines.append("")
            
            for highlight in pageHighlights {
                let colorTag = highlight.color != .unknown ? " `\(highlight.color.displayName)`" : ""
                lines.append("> \(highlight.text)\(colorTag)")
                
                if let note = highlight.note {
                    lines.append(">")
                    lines.append("> **Note:** \(note)")
                }
                
                lines.append("")
            }
        }
        
        return lines.joined(separator: "\n")
    }
}
