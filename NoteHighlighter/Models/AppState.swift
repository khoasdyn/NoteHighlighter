import SwiftUI
import PDFKit
import SwiftData
import Observation

@Observable
final class AppState {
    var currentBook: BookItem?
    var pdfDocument: PDFDocument?
    var highlights: [Highlight] = []
    var selectedHighlight: Highlight?
    var showFileImporter = false
    var fileName: String = ""
    var currentHighlightColor: HighlightColor = .yellow
    var pdfFileURL: URL?
    var currentPageIndex: Int = 0
    var pageCount: Int = 0

    var currentPageLabel: String {
        guard let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else {
            return "Page \(currentPageIndex + 1) of \(pageCount)"
        }
        let label = page.label ?? "\(currentPageIndex + 1)"
        return "Page \(label) of \(pageCount)"
    }

    /// Reference to the PDFView so we can navigate to highlights
    @ObservationIgnored weak var pdfView: PDFView?

    /// SwiftData model context for persistence
    @ObservationIgnored var modelContext: ModelContext?

    // MARK: - Book lifecycle

    func openBook(_ book: BookItem) {
        let url = BookStorage.shared.pdfURL(for: book.fileName)
        guard let document = PDFDocument(url: url) else {
            print("Failed to load PDF for book: \(book.title)")
            return
        }

        currentBook = book
        pdfDocument = document
        pdfFileURL = url
        fileName = book.title
        pageCount = document.pageCount
        currentPageIndex = 0
        selectedHighlight = nil
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
        currentPageIndex = 0
        pageCount = 0
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

        highlights = HighlightExtractor.extractHighlights(from: document)
    }

    func saveHighlights() {
        guard let context = modelContext,
              let book = currentBook,
              let document = pdfDocument else { return }

        let existing = Array(book.highlights)
        for h in existing {
            context.delete(h)
        }

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            for annotation in page.annotations {
                guard annotation.isHighlightAnnotation,
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
        highlights = HighlightExtractor.extractHighlights(from: document)
        saveHighlights()
    }

    func addHighlightFromSelection() {
        guard let pdfView,
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
                guard annotation.isHighlightAnnotation else { return false }
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

        guard let pdfView,
              let document = pdfDocument,
              let page = document.page(at: highlight.pageIndex) else { return }

        let visibleHeight = pdfView.visibleRect.height / pdfView.scaleFactor
        let targetY = highlight.bounds.midY + visibleHeight / 2

        let destination = PDFDestination(page: page, at: CGPoint(x: 0, y: targetY))
        pdfView.go(to: destination)
    }
}
