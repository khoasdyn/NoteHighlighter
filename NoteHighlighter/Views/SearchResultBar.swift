import SwiftUI

struct SearchResultBar: View {
    @Environment(AppState.self) private var appState

    private var search: SearchService { appState.searchService }

    var body: some View {
        HStack(spacing: 6) {
            Text("Found on \(search.searchResultPageCount) page\(search.searchResultPageCount == 1 ? "" : "s")")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Button("Previous Result", systemImage: "chevron.left") {
                search.previousResult()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Next Result", systemImage: "chevron.right") {
                search.nextResult()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, 6)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
