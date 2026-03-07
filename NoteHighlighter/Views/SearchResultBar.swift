import SwiftUI

struct SearchResultBar: View {
    @Environment(AppState.self) private var appState

    private var search: SearchService { appState.searchService }

    var body: some View {
        HStack(spacing: 6) {
            Text("Found on \(search.searchResultPageCount) page\(search.searchResultPageCount == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                search.previousResult()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                search.nextResult()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
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
