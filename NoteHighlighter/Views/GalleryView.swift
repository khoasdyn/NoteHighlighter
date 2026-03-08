import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct GalleryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookItem.dateAdded, order: .reverse) private var books: [BookItem]
    @State private var selectedTab: SidebarTab = .library

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(SidebarTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch selectedTab {
            case .library:
                libraryContent
            default:
                placeholderContent
            }
        }
        .navigationTitle(selectedTab.rawValue)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if selectedTab == .library {
                    Button("Import PDF", systemImage: "plus") {
                        appState.showFileImporter = true
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $appState.showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    // MARK: - Library content

    private var libraryContent: some View {
        Group {
            if books.isEmpty {
                ContentUnavailableView {
                    Label("No books yet", systemImage: "books.vertical")
                } description: {
                    Text("Import a PDF to get started")
                } actions: {
                    Button("Import PDF...") {
                        appState.showFileImporter = true
                    }
                    .controlSize(.large)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(books) { book in
                            Button { openBook(book) } label: {
                                BookCard(book: book)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleteBook(book)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    // MARK: - Placeholder for future tabs

    private var placeholderContent: some View {
        ContentUnavailableView {
            Label(selectedTab.rawValue, systemImage: selectedTab.icon)
        } description: {
            Text("Coming soon")
        }
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let fileName = try appState.bookStorage.copyPDF(from: url)
            let title = url.deletingPathExtension().lastPathComponent
            let storedURL = appState.bookStorage.pdfURL(for: fileName)
            let thumbnail = appState.bookStorage.generateThumbnail(for: storedURL, size: CGSize(width: 200, height: 280))

            let book = BookItem(title: title, fileName: fileName, thumbnailData: thumbnail)
            modelContext.insert(book)
            try modelContext.save()
        } catch {
            appState.errorMessage = "Failed to import PDF: \(error.localizedDescription)"
        }
    }

    private func openBook(_ book: BookItem) {
        appState.openBook(book)
    }

    private func deleteBook(_ book: BookItem) {
        appState.bookStorage.deletePDF(fileName: book.fileName)
        modelContext.delete(book)
        try? modelContext.save()
    }
}
