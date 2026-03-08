import SwiftUI

struct HighlightRow: View {
    let highlight: Highlight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(highlight.color.swiftUIColor)
                    .frame(width: 8, height: 8)

                Text(highlight.spansMultiplePages
                     ? "Pages \(highlight.pageNumber)-\(highlight.endPageIndex + 1)"
                     : "Page \(highlight.pageNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .bold()

                Spacer()

                if highlight.note != nil {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(highlight.text)
                .font(.callout)
                .lineLimit(4)
                .foregroundStyle(.primary)

            if let note = highlight.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
