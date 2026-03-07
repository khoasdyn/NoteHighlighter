import Foundation
import CoreGraphics

/// Abstracts PDF file storage operations for testability and future extensibility.
protocol BookStoring {
    func copyPDF(from sourceURL: URL) throws -> String
    func pdfURL(for fileName: String) -> URL
    func deletePDF(fileName: String)
    func generateThumbnail(for url: URL, size: CGSize) -> Data?
}
