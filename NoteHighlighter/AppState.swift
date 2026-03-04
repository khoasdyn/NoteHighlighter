import SwiftUI
import PDFKit
import Combine

class AppState: ObservableObject {
    @Published var pdfDocument: PDFDocument?
    @Published var highlights: [Highlight] = []
    @Published var selectedHighlight: Highlight?
    @Published var showFileImporter = false
    @Published var fileName: String = ""
    @Published var currentHighlightColor: HighlightColor = .yellow
    @Published var pdfFileURL: URL?
    
    /// Reference to the PDFView so we can navigate to highlights
    weak var pdfView: PDFView?
    
    func loadPDF(from url: URL) {
        guard let document = PDFDocument(url: url) else {
            print("Failed to load PDF from \(url)")
            return
        }
        
        self.pdfDocument = document
        self.pdfFileURL = url
        self.fileName = url.deletingPathExtension().lastPathComponent
        self.highlights = HighlightExtractor.extractHighlights(from: document)
        self.selectedHighlight = nil
    }
    
    func refreshHighlights() {
        guard let document = pdfDocument else { return }
        self.highlights = HighlightExtractor.extractHighlights(from: document)
    }
    
    func addHighlightFromSelection() {
        guard let pdfView = pdfView,
              let selection = pdfView.currentSelection else { return }
        
        let color = currentHighlightColor.nsColor
        
        // Break selection into individual lines for proper per-line highlight rects
        let lineSelections = selection.selectionsByLine()
        guard !lineSelections.isEmpty else { return }
        
        for lineSelection in lineSelections {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 0 && bounds.height > 0 else { continue }
                
                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = color
                page.addAnnotation(annotation)
            }
        }
        
        pdfView.clearSelection()
        refreshHighlights()
    }
    
    func removeHighlight(_ highlight: Highlight) {
        guard let document = pdfDocument,
              let page = document.page(at: highlight.pageIndex) else { return }
        
        // Find the matching annotation on the page
        for annotation in page.annotations {
            if annotation.type == "Highlight" && annotation.bounds == highlight.bounds {
                page.removeAnnotation(annotation)
                break
            }
        }
        
        refreshHighlights()
    }
    
    func savePDF() {
        guard let document = pdfDocument, let url = pdfFileURL else { return }
        document.write(to: url)
    }
    
    func navigateToHighlight(_ highlight: Highlight) {
        selectedHighlight = highlight
        
        guard let pdfView = pdfView,
              let document = pdfDocument,
              let page = document.page(at: highlight.pageIndex) else { return }
        
        let destination = PDFDestination(page: page, at: highlight.bounds.origin)
        pdfView.go(to: destination)
        
        if let selection = document.findString(highlight.text, withOptions: .caseInsensitive).first {
            pdfView.setCurrentSelection(selection, animate: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                pdfView.clearSelection()
            }
        }
    }
}
