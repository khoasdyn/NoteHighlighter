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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.showFileImporter = true
                } label: {
                    Label("Open PDF", systemImage: "doc.badge.plus")
                }
                
                if appState.pdfDocument != nil {
                    // Color picker for highlight color
                    Menu {
                        ForEach(HighlightColor.allCases.filter { $0 != .unknown }, id: \.self) { color in
                            Button {
                                appState.currentHighlightColor = color
                            } label: {
                                HStack {
                                    Image(systemName: appState.currentHighlightColor == color ? "checkmark.circle.fill" : "circle.fill")
                                        .foregroundStyle(color.swiftUIColor)
                                    Text(color.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "highlighter")
                            Circle()
                                .fill(appState.currentHighlightColor.swiftUIColor)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .help("Highlight color")
                    
                    // Add highlight button
                    Button {
                        appState.addHighlightFromSelection()
                    } label: {
                        Label("Highlight Selection", systemImage: "plus.circle")
                    }
                    .help("Highlight selected text (⌘⇧H)")
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                    
                    // Save button
                    Button {
                        appState.savePDF()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .help("Save PDF (⌘S)")
                    .keyboardShortcut("s", modifiers: .command)
                    
                }
            }
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
            
            // Need to start accessing the security-scoped resource
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
