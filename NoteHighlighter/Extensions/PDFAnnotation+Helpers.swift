import PDFKit

extension PDFAnnotation {
    /// Whether this annotation is a highlight created by NoteHighlighter
    var isHighlightAnnotation: Bool {
        type == "Highlight"
    }
}
