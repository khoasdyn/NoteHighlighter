import PDFKit

/// Defines the highlight CRUD interface.
protocol HighlightManaging: AnyObject {
    var highlights: [Highlight] { get }

    func loadHighlights()
    func saveHighlights()
    func addHighlightFromSelection(color: HighlightColor)
    func removeHighlight(_ highlight: Highlight)
    func refreshHighlights()
}
