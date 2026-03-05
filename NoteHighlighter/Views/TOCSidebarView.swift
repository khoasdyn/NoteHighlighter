import SwiftUI
import PDFKit

struct TOCSidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if let root = appState.pdfDocument?.outlineRoot, root.numberOfChildren > 0 {
                outlineList(root: root)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Table of Contents")
                    .font(.headline)
                    .lineLimit(1)

                if let root = appState.pdfDocument?.outlineRoot, root.numberOfChildren > 0 {
                    Text("\(countEntries(root)) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Outline list

    private func outlineList(root: PDFOutline) -> some View {
        List {
            ForEach(0..<root.numberOfChildren, id: \.self) { index in
                if let child = root.child(at: index) {
                    OutlineItemView(outline: child, depth: 0)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No table of contents")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("This PDF doesn't have a table of contents")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func countEntries(_ outline: PDFOutline) -> Int {
        var count = 0
        for i in 0..<outline.numberOfChildren {
            count += 1
            if let child = outline.child(at: i) {
                count += countEntries(child)
            }
        }
        return count
    }
}

// MARK: - Outline item (recursive)

private struct OutlineItemView: View {
    @Environment(AppState.self) private var appState
    let outline: PDFOutline
    let depth: Int

    @State private var isExpanded: Bool = true

    private var hasChildren: Bool {
        outline.numberOfChildren > 0
    }

    private var pageLabel: String? {
        guard let destination = outline.destination,
              let page = destination.page,
              let document = appState.pdfDocument else { return nil }
        let index = document.index(for: page)
        return page.label ?? "\(index + 1)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                appState.navigateToOutline(outline)
            } label: {
                HStack(spacing: 6) {
                    if hasChildren {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 12)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            }
                    } else {
                        Spacer()
                            .frame(width: 12)
                    }

                    Text(outline.label ?? "Untitled")
                        .font(depth == 0 ? .callout.weight(.medium) : .callout)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer()

                    if let pageLabel {
                        Text(pageLabel)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
                .padding(.leading, CGFloat(depth) * 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hasChildren && isExpanded {
                ForEach(0..<outline.numberOfChildren, id: \.self) { index in
                    if let child = outline.child(at: index) {
                        OutlineItemView(outline: child, depth: depth + 1)
                    }
                }
            }
        }
    }
}
