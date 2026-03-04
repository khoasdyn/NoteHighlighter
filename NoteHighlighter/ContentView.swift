import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var pdfViewRef: PDFView?
    
    var body: some View {
        NavigationSplitView {
            HighlightSidebar()
                .environmentObject(appState)
        } detail: {
            ZStack {
                if appState.pdfDocument != nil {
                    PDFKitView(document: appState.pdfDocument, pdfView: $pdfViewRef, appState: appState)
                        .onChange(of: pdfViewRef) { _, newView in
                            appState.pdfView = newView
                        }
                } else {
                    welcomeView
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        .fileImporter(
            isPresented: $appState.showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onDrop(of: [.pdf, .fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - Welcome view
    
    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Open a PDF to get started")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Drag and drop a file here, or press ⌘O")
                .font(.callout)
                .foregroundStyle(.tertiary)
            
            Button("Open PDF...") {
                appState.showFileImporter = true
            }
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - File handling
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            
            appState.loadPDF(from: url)
            
        case .failure(let error):
            print("File import error: \(error.localizedDescription)")
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, error in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "pdf" else { return }
            
            DispatchQueue.main.async {
                appState.loadPDF(from: url)
            }
        }
        return true
    }
}
