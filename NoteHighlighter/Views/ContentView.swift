import SwiftUI
import PDFKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var pdfViewRef: PDFView?

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            HighlightSidebar()
        } detail: {
            if appState.pdfDocument != nil {
                PDFKitView(document: appState.pdfDocument, pdfView: $pdfViewRef, appState: appState)
                    .padding(.leading, 4) // Prevent PDFView from capturing mouse events at the divider edge
                    .onChange(of: pdfViewRef) { _, newView in
                        appState.pdfView = newView
                    }
                    .overlay(alignment: .top) {
                        if appState.isSearchActive && !appState.searchResults.isEmpty {
                            SearchResultBar()
                                .environment(appState)
                        }
                    }
            }
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        .navigationTitle(appState.fileName)
        .navigationSubtitle(appState.pageCount > 0 ? appState.currentPageLabel : "")
        .searchable(text: $appState.searchQuery, placement: .toolbar, prompt: "Search")
        .onSubmit(of: .search) {
            appState.performSearch()
        }
        .onChange(of: appState.searchQuery) { _, newValue in
            if newValue.isEmpty && appState.isSearchActive {
                appState.clearSearch()
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
        }
    }
}
