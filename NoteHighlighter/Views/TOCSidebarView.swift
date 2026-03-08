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
                ContentUnavailableView {
                    Label("No table of contents", systemImage: "list.bullet.indent")
                } description: {
                    Text("This PDF doesn't have a table of contents")
                }
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

    private var isSelected: Bool {
        appState.selectedOutline === outline
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
            HStack(spacing: 6) {
                if hasChildren {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary.opacity(0.5))
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 12)
                }

                Button {
                    appState.navigateToOutline(outline)
                } label: {
                    HStack {
                        Text(outline.label ?? "Untitled")
                            .font(depth == 0 ? .callout.weight(.medium) : .callout)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .lineLimit(2)

                        Spacer()

                        if let pageLabel {
                            Text(pageLabel)
                                .font(.caption)
                                .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary.opacity(0.5))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .padding(.leading, CGFloat(depth) * 14)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())

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
