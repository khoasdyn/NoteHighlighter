import SwiftUI
import PDFKit
import SwiftData

@MainActor @Observable
final class AppState {

    // MARK: - Book state

    var currentBook: BookItem?
    var pdfDocument: PDFDocument?
    var fileName: String = ""
    var pdfFileURL: URL?
    var currentPageIndex: Int = 0
    var pageCount: Int = 0

    // MARK: - Highlight state

    var selectedHighlight: Highlight?
    var currentHighlightColor: HighlightColor = .yellow

    // MARK: - UI state

    var showFileImporter = false
    var errorMessage: String?
    var sidebarMode: SidebarMode = .highlights
    var selectedOutline: PDFOutline?

    var selectionMode: SelectionMode {
        didSet { UserDefaults.standard.set(selectionMode.rawValue, forKey: "selectionMode") }
    }

    // MARK: - Init

    init() {
        let stored = UserDefaults.standard.string(forKey: "selectionMode") ?? SelectionMode.word.rawValue
        self.selectionMode = SelectionMode(rawValue: stored) ?? .word
    }

    // MARK: - Dependencies

    /// Abstracted navigation interface (concrete type is PDFView)
    @ObservationIgnored weak var navigator: PDFNavigating?

    /// Search subsystem (owns all search state and logic)
    let searchService = SearchService()

    /// Highlight subsystem (owns highlight CRUD and persistence)
    let highlightManager = HighlightManager()

    /// File storage for PDF books
    @ObservationIgnored var bookStorage: BookStoring = BookStorage.shared

    /// SwiftData model context for persistence
    @ObservationIgnored var modelContext: ModelContext?

    // MARK: - Computed properties

    var currentPageLabel: String {
        guard let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else {
            return "Page \(currentPageIndex + 1) of \(pageCount)"
        }
        let label = page.label ?? "\(currentPageIndex + 1)"
        return "Page \(label) of \(pageCount)"
    }

    // MARK: - Book lifecycle

    func openBook(_ book: BookItem) {
        let url = bookStorage.pdfURL(for: book.fileName)
        guard let document = PDFDocument(url: url) else {
            errorMessage = "Could not open \"\(book.title)\". The file may be corrupted."
            return
        }

        currentBook = book
        pdfDocument = document
        pdfFileURL = url
        fileName = book.title
        pageCount = document.pageCount
        currentPageIndex = 0
        selectedHighlight = nil

        searchService.document = document

        highlightManager.document = document
        highlightManager.currentBook = book
        highlightManager.modelContext = modelContext
        highlightManager.navigator = navigator
        highlightManager.loadHighlights()
    }

    func closeBook() {
        highlightManager.saveHighlights()
        searchService.clearSearch()
        searchService.document = nil
        highlightManager.document = nil
        highlightManager.currentBook = nil
        currentBook = nil
        pdfDocument = nil
        pdfFileURL = nil
        selectedHighlight = nil
        fileName = ""
        currentPageIndex = 0
        pageCount = 0
        navigator = nil
        sidebarMode = .highlights
    }

    // MARK: - Table of Contents

    var hasTableOfContents: Bool {
        guard let root = pdfDocument?.outlineRoot else { return false }
        return root.numberOfChildren > 0
    }

    func navigateToOutline(_ outline: PDFOutline) {
        selectedOutline = outline

        guard let navigator,
              let destination = outline.destination,
              let page = destination.page else { return }

        let pointY = destination.point.y
        let visibleHeight = navigator.visibleRect.height / navigator.scaleFactor
        let targetY = pointY + visibleHeight / 2

        let centeredDestination = PDFDestination(page: page, at: CGPoint(x: 0, y: targetY))
        navigator.go(to: centeredDestination)

        if let document = pdfDocument {
            currentPageIndex = document.index(for: page)
        }
    }
}
