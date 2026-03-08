import SwiftData
import Foundation

@Model
final class BookItem {
    var title: String
    var fileName: String
    var dateAdded: Date
    @Attribute(.externalStorage) var thumbnailData: Data?

    @Relationship(deleteRule: .cascade, inverse: \SavedHighlight.book)
    var highlights: [SavedHighlight] = []

    var highlightCount: Int {
        Set(highlights.map(\.groupID)).count
    }

    init(title: String, fileName: String, dateAdded: Date = .now, thumbnailData: Data? = nil) {
        self.title = title
        self.fileName = fileName
        self.dateAdded = dateAdded
        self.thumbnailData = thumbnailData
    }
}
