import PDFKit

/// Abstracts PDFView navigation so the model layer doesn't depend on the concrete view.
protocol PDFNavigating: AnyObject {
    func go(to destination: PDFDestination)
    func go(to selection: PDFSelection)
    func setCurrentSelection(_ selection: PDFSelection?, animate: Bool)
    func clearSelection()
    var highlightedSelections: [PDFSelection]? { get set }
    var currentPage: PDFPage? { get }
    var currentSelection: PDFSelection? { get set }
    var visibleRect: CGRect { get }
    var scaleFactor: CGFloat { get }
}

// PDFView already has all these members — conformance is free.
extension PDFView: PDFNavigating {}
