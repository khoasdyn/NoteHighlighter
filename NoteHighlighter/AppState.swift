import SwiftUI
import PDFKit
import SwiftData
import Combine

class AppState: ObservableObject {
    @Published var currentBook: BookItem?
    @Published var pdfDocument: PDFDocument?
    @Published var highlights: [Highlight] = []
    @Published var selectedHighlight: Highlight?
    @Published var showFileImporter = false
    @Published var fileName: String = ""
    @Published var currentHighlightColor: HighlightColor = .yellow
    @Published var pdfFileURL: URL?
    
    /// Reference to the PDFView so we can navigate to highlights
    weak var pdfView: PDFView?
    
    /// SwiftData model context for persistence
    var modelContext: ModelContext?
    
    // MARK: - Book lifecycle
    
    func openBook(_ book: BookItem) {
        let url = BookStorage.shared.pdfURL(for: book.fileName)
        guard let document = PDFDocument(url: url) else {
            print("Failed to load PDF for book: \(book.title)")
            return
        }
        
        self.currentBook = book
        self.pdfDocument = document
        self.pdfFileURL = url
        self.fileName = book.title
        self.selectedHighlight = nil
        
        loadHighlights()
    }
    
    func closeBook() {
        saveHighlights()
        currentBook = nil
        pdfDocument = nil
        pdfFileURL = nil
        highlights = []
        selectedHighlight = nil
        fileName = ""
        pdfView = nil
    }
    
    // MARK: - Highlight persistence
    
    func loadHighlights() {
        guard let book = currentBook, let document = pdfDocument else { return }
        
        for saved in book.highlights {
            guard let page = document.page(at: saved.pageIndex) else { continue }
            
            let annotation = PDFAnnotation(bounds: saved.bounds, forType: .highlight, withProperties: nil)
            let color = HighlightColor(rawValue: saved.colorName) ?? .yellow
            annotation.color = color.nsColor
            annotation.userName = saved.groupID
            page.addAnnotation(annotation)
        }
        
        self.highlights = HighlightExtractor.extractHighlights(from: document)
    }
    
    func saveHighlights() {
        guard let context = modelContext,
              let book = currentBook,
              let document = pdfDocument else { return }
        
        // Delete existing saved highlights
        let existing = Array(book.highlights)
        for h in existing {
            context.delete(h)
        }
        
        // Save all app-created annotations (those with a groupID)
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            for annotation in page.annotations {
                guard annotation.type == "Highlight" || annotation.markupType == .highlight,
                      let groupID = annotation.userName, !groupID.isEmpty else { continue }
                
                let text = page.selection(for: annotation.bounds)?
                    .string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let colorName = HighlightColor.from(nsColor: annotation.color).rawValue
                let pageLabel = page.label ?? "\(pageIndex + 1)"
                
                let saved = SavedHighlight(
                    text: text,
                    pageIndex: pageIndex,
                    pageLabel: pageLabel,
                    colorName: colorName,
                    boundsX: annotation.bounds.origin.x,
                    boundsY: annotation.bounds.origin.y,
                    boundsWidth: annotation.bounds.width,
                    boundsHeight: annotation.bounds.height,
                    groupID: groupID
                )
                saved.book = book
                context.insert(saved)
            }
        }
        
        try? context.save()
    }
    
    // MARK: - Highlight operations
    
    func refreshHighlights() {
        guard let document = pdfDocument else { return }
        self.highlights = HighlightExtractor.extractHighlights(from: document)
        saveHighlights()
    }
    
    func addHighlightFromSelection() {
        guard let pdfView = pdfView,
              let selection = pdfView.currentSelection else { return }
        
        let color = currentHighlightColor.nsColor
        let groupID = UUID().uuidString
        
        let lineSelections = selection.selectionsByLine()
        guard !lineSelections.isEmpty else { return }
        
        for lineSelection in lineSelections {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 0 && bounds.height > 0 else { continue }
                
                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = color
                annotation.userName = groupID
                page.addAnnotation(annotation)
            }
        }
        
        pdfView.clearSelection()
        refreshHighlights()
    }
    
    func removeHighlight(_ highlight: Highlight) {
        guard let document = pdfDocument else { return }
        
        for pageIndex in highlight.pageIndex...highlight.endPageIndex {
            guard let page = document.page(at: pageIndex) else { continue }
            
            let annotationsToRemove = page.annotations.filter { annotation in
                guard annotation.type == "Highlight" || annotation.markupType == .highlight else { return false }
                guard HighlightColor.from(nsColor: annotation.color) == highlight.color else { return false }
                
                if let groupID = highlight.groupID, !groupID.isEmpty,
                   let annotationGroup = annotation.userName, !annotationGroup.isEmpty {
                    return groupID == annotationGroup
                }
                
                return highlight.bounds.contains(annotation.bounds) || annotation.bounds.intersects(highlight.bounds)
            }
            
            for annotation in annotationsToRemove {
                page.removeAnnotation(annotation)
            }
        }
        
        refreshHighlights()
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
