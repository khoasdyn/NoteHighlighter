import Foundation

enum SidebarMode: String, CaseIterable {
    case highlights
    case tableOfContents

    var label: String {
        switch self {
        case .highlights: "Highlights and Notes"
        case .tableOfContents: "Table of Contents"
        }
    }

    var icon: String {
        switch self {
        case .highlights: "highlighter"
        case .tableOfContents: "list.bullet.indent"
        }
    }
}
