import Foundation

// MARK: - Optional string helpers

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        switch self {
        case .none: return true
        case .some(let str): return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
