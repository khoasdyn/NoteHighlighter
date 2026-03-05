import SwiftUI
import PDFKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var pdfViewRef: PDFView?

    var body: some View {
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
