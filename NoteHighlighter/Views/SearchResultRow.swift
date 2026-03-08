import SwiftUI

struct SearchResultRow: View {
    let snippet: String
    let matchRange: Range<String.Index>
    let isActive: Bool

    var body: some View {
        Text(attributedSnippet)
            .lineLimit(2)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(isActive ? .white : .primary)
    }

    private var attributedSnippet: AttributedString {
        var result = AttributedString(snippet)
        result.font = .callout
        result.foregroundColor = isActive ? .white : .secondary

        let nsRange = NSRange(matchRange, in: snippet)
        if let attrRange = Range(nsRange, in: result) {
            result[attrRange].font = .callout.weight(.semibold)
            result[attrRange].foregroundColor = isActive ? .white : .primary
        }

        return result
    }
}
