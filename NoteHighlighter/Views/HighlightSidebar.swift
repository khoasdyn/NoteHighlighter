import SwiftUI
import PDFKit

struct HighlightSidebar: View {
    @Environment(AppState.self) private var appState
    @State private var filterColor: HighlightColor?
    @State private var searchText: String = ""

    private var search: SearchService { appState.searchService }
    private var hlm: HighlightManager { appState.highlightManager }

    private var filteredHighlights: [Highlight] {
        var results = hlm.highlights

        if let filterColor {
            results = results.filter { $0.color == filterColor }
        }

        if !searchText.isEmpty {
            results = results.filter {
                $0.text.localizedStandardContains(searchText) ||
                ($0.note?.localizedStandardContains(searchText) ?? false)
            }
        }

        return results
    }

    private var availableColors: [HighlightColor] {
        let colors = Set(hlm.highlights.map(\.color))
        return HighlightColor.allCases.filter { colors.contains($0) }
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            if search.isSearchActive {
                searchResultsView
            } else {
                switch appState.sidebarMode {
                case .highlights:
                    highlightsView(selectedHighlight: $appState.selectedHighlight)
                case .tableOfContents:
                    TOCSidebarView()
                }
            }
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(SidebarMode.allCases, id: \.self) { mode in
                        Button {
                            appState.sidebarMode = mode
                        } label: {
                            Label(mode.label, systemImage: mode.icon)
                        }
                    }
                } label: {
                    Label("Sidebar", systemImage: "sidebar.left")
                } primaryAction: {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
            }
        }
    }

    // MARK: - Highlights mode

    private func highlightsView(selectedHighlight: Binding<Highlight?>) -> some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            searchBar
                .padding(10)

            if !availableColors.isEmpty {
                colorFilterBar
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }

            Divider()

            if filteredHighlights.isEmpty {
                highlightsEmptyState
            } else {
                highlightsList(selection: selectedHighlight)
            }
        }
    }

    // MARK: - Search results mode

    private var searchResultsView: some View {
        VStack(spacing: 0) {
            searchResultsHeader

            Divider()

            if search.isSearching && search.searchResults.isEmpty {
                searchingState
            } else if search.searchResults.isEmpty {
                ContentUnavailableView {
                    Label("No results", systemImage: "magnifyingglass")
                } description: {
                    Text("No results for \"\(search.searchQuery)\"")
                }
            } else {
                searchResultsList
            }
        }
    }

    private var searchResultsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Search Results")
                    .font(.headline)
                    .lineLimit(1)

                if !search.searchResults.isEmpty {
                    let pageCount = search.searchResultPageCount
                    let totalCount = search.searchResults.count
                    Text("\(totalCount) match\(totalCount == 1 ? "" : "es") on \(pageCount) page\(pageCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchingState: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("Searching...")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var searchResultsList: some View {
        List {
            ForEach(search.searchResultsByPage) { group in
                Section {
                    ForEach(Array(group.snippets.enumerated()), id: \.offset) { _, snippet in
                        let globalIndex = globalSearchIndex(group: group, selectionIndex: snippet.selectionIndex)
                        let isActive = globalIndex == search.currentSearchResultIndex

                        Button {
                            search.navigateToResult(at: globalIndex)
                        } label: {
                            SearchResultRow(
                                snippet: snippet.text,
                                matchRange: snippet.range,
                                isActive: isActive
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Page \(group.pageLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .bold()

                        Spacer()

                        Text("\(group.matchCount) match\(group.matchCount == 1 ? "" : "es")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func globalSearchIndex(group: SearchResultGroup, selectionIndex: Int) -> Int {
        var index = 0
        for pageGroup in search.searchResultsByPage {
            if pageGroup.pageIndex == group.pageIndex {
                return index + selectionIndex
            }
            index += pageGroup.selections.count
        }
        return index + selectionIndex
    }

    // MARK: - Highlights subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Highlights and Notes")
                    .font(.headline)
                    .lineLimit(1)

                if !hlm.highlights.isEmpty {
                    Text("\(hlm.highlights.count) highlight\(hlm.highlights.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("Search highlights...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 6))
    }

    private var colorFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                FilterChip(
                    label: "All",
                    color: nil,
                    isSelected: filterColor == nil
                ) {
                    filterColor = nil
                }

                ForEach(availableColors, id: \.self) { color in
                    FilterChip(
                        label: color.displayName,
                        color: color,
                        isSelected: filterColor == color
                    ) {
                        filterColor = (filterColor == color) ? nil : color
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var highlightsEmptyState: some View {
        Group {
            if appState.pdfDocument == nil {
                ContentUnavailableView {
                    Label("Open a PDF to see highlights", systemImage: "doc.text")
                } description: {
                    Text("⌘O to open a file")
                }
            } else {
                ContentUnavailableView {
                    Label("No highlights found", systemImage: "highlighter")
                }
            }
        }
    }

    private func highlightsList(selection: Binding<Highlight?>) -> some View {
        List(selection: selection) {
            ForEach(filteredHighlights) { highlight in
                Button {
                    appState.navigateToHighlight(highlight)
                } label: {
                    HighlightRow(highlight: highlight)
                }
                .buttonStyle(.plain)
                .tag(highlight)
                .contextMenu {
                    Button("Delete Highlight", systemImage: "trash", role: .destructive) {
                        hlm.removeHighlight(highlight)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}
