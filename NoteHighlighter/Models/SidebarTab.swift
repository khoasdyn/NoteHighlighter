import Foundation

enum SidebarTab: String, CaseIterable, Identifiable {
    case library = "Library"
    case notes = "Notes"
    case journal = "Journal"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library: "books.vertical"
        case .notes: "note.text"
        case .journal: "book.closed"
        case .settings: "gearshape"
        }
    }
}
