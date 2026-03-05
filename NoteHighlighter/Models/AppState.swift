import SwiftUI
import PDFKit
import SwiftData

@Observable
final class AppState {

    // MARK: - Book state

    var currentBook: BookItem?
    var pdfDocument: PDFDocument?
    var fileName: String = ""
    var pdfFileURL: URL?
    var currentPageIndex: Int = 0
    var pageCount: Int = 0

    // MARK: - Highlight state

    var highlights: [Highlight] = []
    var selectedHighlight: Highlight?
    var currentHighlightColor: HighlightColor = .yellow

    // MARK: - UI state

    var showFileImporter = false

    // MARK: - Search state

    var searchQuery: String = ""
    var searchResults: [PDFSelection] = []
    var currentSearchResultIndex: Int = 0
    var isSearchActive: Bool = false
    var isSearching: Bool = false

    // MARK: - Dependencies

    /// Reference to the PDFView so we can navigate to highlights
    @ObservationIgnored weak var pdfView: PDFView?

    /// Handles async search notifications from PDFDocument
    @ObservationIgnored lazy var searchObserver = SearchObserver(appState: self)

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

    var searchResultPageCount: Int {
        Set(searchResults.compactMap { $0.pages.first }).count
    }

    var searchResultsByPage: [SearchResultGroup] {
        guard let document = pdfDocument else { return [] }
        var groups: [Int: [PDFSelection]] = [:]
        for selection in searchResults {
            guard let page = selection.pages.first else { continue }
            let index = document.index(for: page)
            groups[index, default: []].append(selection)
        }
        return groups.keys.sorted().compactMap { pageIndex in
            guard let selections = groups[pageIndex] else { return nil }
            let page = document.page(at: pageIndex)
            let label = page?.label ?? "\(pageIndex + 1)"
            return SearchResultGroup(pageIndex: pageIndex, pageLabel: label, selections: selections, query: searchQuery)
        }
    }

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
        clearSearch()
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
}
