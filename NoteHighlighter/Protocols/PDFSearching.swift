import PDFKit

/// Defines the search subsystem interface.
protocol PDFSearching: AnyObject {
    var searchQuery: String { get set }
    var searchResults: [PDFSelection] { get }
    var currentSearchResultIndex: Int { get }
    var isSearchActive: Bool { get }
    var isSearching: Bool { get }
    var searchResultPageCount: Int { get }
    var searchResultsByPage: [SearchResultGroup] { get }

    func performSearch()
    func clearSearch()
    func nextResult()
    func previousResult()
    func navigateToResult(at index: Int)
}
