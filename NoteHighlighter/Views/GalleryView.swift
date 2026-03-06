import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Sidebar tabs

enum SidebarTab: String, CaseIterable, Identifiable {
    case library = "Library"
    case notes = "Notes"
    case journal = "Journal"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library: return "books.vertical"
        case .notes: return "note.text"
        case .journal: return "book.closed"
        case .settings: return "gearshape"
        }
    }
}

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
                    Button {
                        appState.showFileImporter = true
                    } label: {
                        Label("Import PDF", systemImage: "plus")
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
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(books) { book in
                            BookCard(book: book)
                                .onTapGesture { openBook(book) }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteBook(book)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Placeholder for future tabs

    private var placeholderContent: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedTab.icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(selectedTab.rawValue)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Coming soon")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No books yet")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Import a PDF to get started")
                .font(.callout)
                .foregroundStyle(.tertiary)

            Button("Import PDF...") {
                appState.showFileImporter = true
            }
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let fileName = try BookStorage.shared.copyPDF(from: url)
            let title = url.deletingPathExtension().lastPathComponent
            let storedURL = BookStorage.shared.pdfURL(for: fileName)
            let thumbnail = BookStorage.shared.generateThumbnail(for: storedURL)

            let book = BookItem(title: title, fileName: fileName, thumbnailData: thumbnail)
            modelContext.insert(book)
            try modelContext.save()
        } catch {
            print("Import error: \(error)")
        }
    }

    private func openBook(_ book: BookItem) {
        appState.openBook(book)
    }

    private func deleteBook(_ book: BookItem) {
        BookStorage.shared.deletePDF(fileName: book.fileName)
        modelContext.delete(book)
        try? modelContext.save()
    }
}

// MARK: - Book card

private struct BookCard: View {
    let book: BookItem

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let data = book.thumbnailData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay {
                            Image(systemName: "doc.richtext")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 160, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Text(book.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 160)

            let count = book.highlightCount
            Text("\(count) highlight\(count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
