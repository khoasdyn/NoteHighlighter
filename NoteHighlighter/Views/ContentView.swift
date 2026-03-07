import SwiftUI
import PDFKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var pdfViewRef: PDFView?

    var body: some View {
        @Bindable var appState = appState
        @Bindable var search = appState.searchService

        NavigationSplitView {
            HighlightSidebar()
        } detail: {
            if appState.pdfDocument != nil {
                PDFKitView(document: appState.pdfDocument, pdfView: $pdfViewRef, appState: appState)
                    .padding(.leading, 4) // Prevent PDFView from capturing mouse events at the divider edge
                    .onChange(of: pdfViewRef) { _, newView in
                        appState.navigator = newView
                        appState.searchService.navigator = newView
                        appState.highlightManager.navigator = newView
                    }
                    .overlay(alignment: .top) {
                        if search.isSearchActive && !search.searchResults.isEmpty {
                            SearchResultBar()
                                .environment(appState)
                        }
                    }
            }
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        .navigationTitle(appState.fileName)
        .navigationSubtitle(appState.pageCount > 0 ? appState.currentPageLabel : "")
        .searchable(text: $search.searchQuery, placement: .toolbar, prompt: "Search")
        .onSubmit(of: .search) {
            appState.searchService.performSearch()
        }
        .onChange(of: search.searchQuery) { _, newValue in
            if newValue.isEmpty && search.isSearchActive {
                appState.searchService.clearSearch()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.closeBook()
                } label: {
                    Label("Back to Library", systemImage: "chevron.left")
                }
            }

            ToolbarItem(placement: .automatic) {
                Picker("Selection Mode", selection: $appState.selectionMode) {
                    ForEach(SelectionMode.allCases, id: \.self) { mode in
                        Label(mode.label, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help(appState.selectionMode == .word ? "Word selection mode" : "Character selection mode")
            }
        }
    }
}
