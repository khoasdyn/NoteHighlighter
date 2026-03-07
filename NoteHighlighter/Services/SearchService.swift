import PDFKit

/// Encapsulates all PDF search state and logic, extracted from AppState.
@Observable
final class SearchService: PDFSearching {

    // MARK: - State

    var searchQuery: String = ""
    var searchResults: [PDFSelection] = []
    var currentSearchResultIndex: Int = 0
    var isSearchActive: Bool = false
    var isSearching: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored weak var navigator: PDFNavigating?
    @ObservationIgnored weak var document: PDFDocument?

    @ObservationIgnored lazy var searchObserver = SearchObserver(searchService: self)

    // MARK: - Computed properties

    var searchResultPageCount: Int {
        Set(searchResults.compactMap { $0.pages.first }).count
    }

    var searchResultsByPage: [SearchResultGroup] {
        guard let document else { return [] }
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

    // MARK: - Search operations

    func performSearch() {
        document?.cancelFindString()
        searchObserver.stopObserving()

        guard let document,
              !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }

        isSearchActive = true
        isSearching = true
        searchResults = []
        currentSearchResultIndex = 0
        navigator?.highlightedSelections = nil

        searchObserver.startObserving(document: document)
        document.beginFindString(searchQuery, withOptions: [.literal, .caseInsensitive, .diacriticInsensitive])
    }

    func clearSearch() {
        document?.cancelFindString()
        searchObserver.stopObserving()
        searchQuery = ""
        searchResults = []
        currentSearchResultIndex = 0
        isSearchActive = false
        isSearching = false
        navigator?.highlightedSelections = nil
        navigator?.clearSelection()
    }

    func nextResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchResultIndex = (currentSearchResultIndex + 1) % searchResults.count
        navigateToResult(at: currentSearchResultIndex)
    }

    func previousResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchResultIndex = (currentSearchResultIndex - 1 + searchResults.count) % searchResults.count
        navigateToResult(at: currentSearchResultIndex)
    }

    func navigateToResult(at index: Int) {
        guard index >= 0, index < searchResults.count,
              let navigator else { return }
        currentSearchResultIndex = index
        let selection = searchResults[index]
        navigator.setCurrentSelection(selection, animate: true)

        guard let page = selection.pages.first else {
            navigator.go(to: selection)
            return
        }

        let bounds = selection.bounds(for: page)
        let visibleHeight = navigator.visibleRect.height / navigator.scaleFactor
        let targetY = bounds.midY + visibleHeight / 2
        let destination = PDFDestination(page: page, at: CGPoint(x: 0, y: targetY))
        navigator.go(to: destination)
    }

    // MARK: - SearchObserver callbacks

    func didFindSearchMatch(_ selection: PDFSelection) {
        guard isWholeWordMatch(selection) else { return }
        searchResults.append(selection)
        navigator?.highlightedSelections = searchResults
        if searchResults.count == 1 {
            navigateToResult(at: 0)
        }
    }

    func didFinishSearch() {
        isSearching = false
        searchObserver.stopObserving()
    }
}

// MARK: - Word boundary matching

private extension SearchService {

    func isWholeWordMatch(_ selection: PDFSelection) -> Bool {
        guard let extended = selection.copy() as? PDFSelection else { return true }
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
}

// MARK: - Search observer (PDFDocumentDelegate)

final class SearchObserver: NSObject, PDFDocumentDelegate {
    private weak var searchService: SearchService?
    private weak var currentDocument: PDFDocument?

    init(searchService: SearchService) {
        self.searchService = searchService
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
        searchService?.didFindSearchMatch(instance)
    }

    func documentDidEndDocumentFind(_ notification: Notification) {
        searchService?.didFinishSearch()
    }
}
