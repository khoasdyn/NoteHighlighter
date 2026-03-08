import SwiftUI

struct BookCard: View {
    let book: BookItem

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let data = book.thumbnailData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay {
                            Image(systemName: "doc.richtext")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 160, height: 220)
            .clipShape(.rect(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Text(book.title)
                .font(.callout.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 160)

            let count = book.highlightCount
            Text("\(count) highlight\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
