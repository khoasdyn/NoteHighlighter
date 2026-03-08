import SwiftUI
import PDFKit

struct Highlight: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let pageIndex: Int
    let endPageIndex: Int
    let pageLabel: String
    let color: HighlightColor
    let note: String?
    let bounds: CGRect
    let creationDate: Date?
    let groupID: String?

    var spansMultiplePages: Bool { pageIndex != endPageIndex }

    var pageNumber: Int { pageIndex + 1 }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Highlight, rhs: Highlight) -> Bool {
        lhs.id == rhs.id
    }
}
