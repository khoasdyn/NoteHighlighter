import Foundation
import PDFKit
import AppKit

final class BookStorage {
    static let shared = BookStorage()

    private init() {}

    private var booksDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport
            .appendingPathComponent("NoteHighlighter", isDirectory: true)
            .appendingPathComponent("Books", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func copyPDF(from sourceURL: URL) throws -> String {
        let fileName = UUID().uuidString + ".pdf"
        let destination = booksDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return fileName
    }

    func pdfURL(for fileName: String) -> URL {
        booksDirectory.appendingPathComponent(fileName)
    }

    func deletePDF(fileName: String) {
        let url = pdfURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func generateThumbnail(for url: URL, size: CGSize = CGSize(width: 200, height: 280)) -> Data? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }

        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}
