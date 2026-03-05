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

    // MARK: - Search state

    var searchQuery: String = ""
    var searchResults: [PDFSelection] = []
    var currentSearchResultIndex: Int = 0
    var isSearchActive: Bool = false
    var isSearching: Bool = false

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
        return groups.keys.sorted().map { pageIndex in
            let selections = groups[pageIndex]!
            let page = document.page(at: pageIndex)
            let label = page?.label ?? "\(pageIndex + 1)"
            return SearchResultGroup(pageIndex: pageIndex, pageLabel: label, selections: selections, query: searchQuery)
        }
    }

    /// Reference to the PDFView so we can navigate to highlights
    @ObservationIgnored weak var pdfView: PDFView?

    /// Handles async search notifications from PDFDocument
    @ObservationIgnored private lazy var searchObserver = SearchObserver(appState: self)

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

    // MARK: - PDF search

    func performSearch() {
        // Cancel any in-progress search
        pdfDocument?.cancelFindString()
        searchObserver.stopObserving()

        guard let document = pdfDocument,
              !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }

        isSearchActive = true
        isSearching = true
        searchResults = []
        currentSearchResultIndex = 0
        pdfView?.highlightedSelections = nil

        searchObserver.startObserving(document: document)
        document.beginFindString(searchQuery, withOptions: [.literal, .caseInsensitive, .diacriticInsensitive])
    }

    /// Called by SearchObserver when a match is found
    func didFindSearchMatch(_ selection: PDFSelection) {
        // Check word boundaries to skip matches inside other words (e.g. "love" in "gloves")
        guard isWholeWordMatch(selection) else { return }

        searchResults.append(selection)
        pdfView?.highlightedSelections = searchResults

        if searchResults.count == 1 {
            pdfView?.setCurrentSelection(selection, animate: true)
            pdfView?.go(to: selection)
        }
    }

    private func isWholeWordMatch(_ selection: PDFSelection) -> Bool {
        let extended = selection.copy() as! PDFSelection
        extended.extend(atStart: 1)
        extended.extend(atEnd: 1)
        guard let extendedText = extended.string,
              let matchText = selection.string else { return true }

        guard let range = extendedText.range(of: matchText, options: .caseInsensitive) else { return true }

        let charBefore = range.lowerBound > extendedText.startIndex
            ? extendedText[extendedText.index(before: range.lowerBound)]
            : nil
        let charAfter = range.upperBound < extendedText.endIndex
            ? extendedText[range.upperBound]
            : nil

        let isWordChar: (Character?) -> Bool = { c in
            guard let c else { return false }
            return c.isLetter || c.isNumber
        }

        return !isWordChar(charBefore) && !isWordChar(charAfter)
    }

    /// Called by SearchObserver when search completes
    func didFinishSearch() {
        isSearching = false
        searchObserver.stopObserving()
    }

    func nextSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchResultIndex = (currentSearchResultIndex + 1) % searchResults.count
        navigateToSearchResult(at: currentSearchResultIndex)
    }

    func previousSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchResultIndex = (currentSearchResultIndex - 1 + searchResults.count) % searchResults.count
        navigateToSearchResult(at: currentSearchResultIndex)
    }

    func navigateToSearchResult(at index: Int) {
        guard index >= 0, index < searchResults.count else { return }
        currentSearchResultIndex = index
        let selection = searchResults[index]
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.go(to: selection)
    }

    func clearSearch() {
        pdfDocument?.cancelFindString()
        searchObserver.stopObserving()
        searchQuery = ""
        searchResults = []
        currentSearchResultIndex = 0
        isSearchActive = false
        isSearching = false
        pdfView?.highlightedSelections = nil
        pdfView?.clearSelection()
    }

    // MARK: - Highlight navigation

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

// MARK: - Search observer (PDFDocumentDelegate)

private class SearchObserver: NSObject, PDFDocumentDelegate {
    weak var appState: AppState?
    private weak var currentDocument: PDFDocument?

    init(appState: AppState) {
        self.appState = appState
    }

    func startObserving(document: PDFDocument) {
        currentDocument = document
        document.delegate = self
    }

    func stopObserving() {
        currentDocument?.delegate = nil
        currentDocument = nil
    }

    func didMatchString(_ instance: PDFSelection) {
        appState?.didFindSearchMatch(instance)
    }

    func documentDidEndDocumentFind(_ notification: Notification) {
        appState?.didFinishSearch()
    }
}
