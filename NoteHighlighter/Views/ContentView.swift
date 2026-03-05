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
                    .onChange(of: pdfViewRef) { _, newView in
                        appState.pdfView = newView
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

            if appState.isSearchActive && !appState.searchResults.isEmpty {
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 4) {
                        Text("Found on \(appState.searchResultPageCount) page\(appState.searchResultPageCount == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Button {
                            appState.previousSearchResult()
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Button {
                            appState.nextSearchResult()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
        }
    }
}
