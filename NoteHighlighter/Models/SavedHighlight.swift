import SwiftData
import Foundation
import CoreGraphics

@Model
final class SavedHighlight {
    var text: String
    var pageIndex: Int
    var pageLabel: String
    var colorName: String
    var note: String?
    var boundsX: Double
    var boundsY: Double
    var boundsWidth: Double
    var boundsHeight: Double
    var groupID: String
    var dateCreated: Date

    var book: BookItem?

    init(text: String, pageIndex: Int, pageLabel: String, colorName: String, note: String? = nil,
         boundsX: Double, boundsY: Double, boundsWidth: Double, boundsHeight: Double,
         groupID: String, dateCreated: Date = .now) {
        self.text = text
        self.pageIndex = pageIndex
        self.pageLabel = pageLabel
        self.colorName = colorName
        self.note = note
        self.boundsX = boundsX
        self.boundsY = boundsY
        self.boundsWidth = boundsWidth
        self.boundsHeight = boundsHeight
        self.groupID = groupID
        self.dateCreated = dateCreated
    }

    var bounds: CGRect {
        CGRect(x: boundsX, y: boundsY, width: boundsWidth, height: boundsHeight)
    }
}
