import Foundation

enum SelectionMode: String, CaseIterable {
    case character
    case word

    var label: String {
        switch self {
        case .character: "Character"
        case .word: "Word"
        }
    }

    var icon: String {
        switch self {
        case .character: "character.cursor.ibeam"
        case .word: "text.word.spacing"
        }
    }
}
