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
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.closeBook()
                } label: {
                    Label("Back to Library", systemImage: "chevron.left")
                }
            }

            ToolbarItem(placement: .automatic) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))

                        TextField("Search", text: $appState.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .onSubmit {
                                appState.performSearch()
                            }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                    .frame(width: 160)

                    if appState.isSearchActive {
                        if appState.isSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else if appState.searchResults.isEmpty {
                            Text("Not found")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Found on \(appState.searchResultPageCount) page\(appState.searchResultPageCount == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            appState.previousSearchResult()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(appState.searchResults.isEmpty)

                        Button {
                            appState.nextSearchResult()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(appState.searchResults.isEmpty)

                        Button("Done") {
                            appState.clearSearch()
                        }
                    }
                }
            }
        }
    }
}
