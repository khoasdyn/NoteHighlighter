import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct GalleryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookItem.dateAdded, order: .reverse) private var books: [BookItem]
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]
    
    var body: some View {
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
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.showFileImporter = true
                } label: {
                    Label("Import PDF", systemImage: "plus")
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

struct BookCard: View {
    let book: BookItem
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail
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
            
            // Title
            Text(book.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 160)
            
            // Highlight count
            let count = book.highlightCount
            Text("\(count) highlight\(count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
