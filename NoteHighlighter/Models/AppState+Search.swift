import PDFKit

// MARK: - PDF search

extension AppState {

    func performSearch() {
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
        guard isWholeWordMatch(selection) else { return }

        searchResults.append(selection)
        pdfView?.highlightedSelections = searchResults

        if searchResults.count == 1 {
            navigateToSearchResult(at: 0)
        }
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
        guard index >= 0, index < searchResults.count,
              let pdfView else { return }
        currentSearchResultIndex = index
        let selection = searchResults[index]
        pdfView.setCurrentSelection(selection, animate: true)

        guard let page = selection.pages.first else {
            pdfView.go(to: selection)
            return
        }

        let bounds = selection.bounds(for: page)
        let visibleHeight = pdfView.visibleRect.height / pdfView.scaleFactor
        let targetY = bounds.midY + visibleHeight / 2
        let destination = PDFDestination(page: page, at: CGPoint(x: 0, y: targetY))
        pdfView.go(to: destination)
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
}

// MARK: - Word boundary matching

private extension AppState {

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
    private weak var appState: AppState?
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
