import SwiftUI

struct HighlightSidebar: View {
    @EnvironmentObject var appState: AppState
    @State private var filterColor: HighlightColor? = nil
    @State private var searchText: String = ""
    
    var filteredHighlights: [Highlight] {
        var results = appState.highlights
        
        // Filter by color
        if let color = filterColor {
            results = results.filter { $0.color == color }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            results = results.filter {
                $0.text.localizedCaseInsensitiveContains(searchText) ||
                ($0.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return results
    }
    
    /// All unique colors present in the highlights
    var availableColors: [HighlightColor] {
        let colors = Set(appState.highlights.map { $0.color })
        return HighlightColor.allCases.filter { colors.contains($0) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Search bar
            searchBar
                .padding(10)
            
            // Color filter chips
            if !availableColors.isEmpty {
                colorFilterBar
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
            
            Divider()
            
            // Highlights list
            if filteredHighlights.isEmpty {
                emptyState
            } else {
                highlightsList
            }
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.fileName.isEmpty ? "PDF Highlights" : appState.fileName)
                    .font(.headline)
                    .lineLimit(1)
                
                if !appState.highlights.isEmpty {
                    Text("\(appState.highlights.count) highlight\(appState.highlights.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            
            TextField("Search highlights...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private var colorFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" chip
                FilterChip(
                    label: "All",
                    color: nil,
                    isSelected: filterColor == nil
                ) {
                    filterColor = nil
                }
                
                ForEach(availableColors, id: \.self) { color in
                    FilterChip(
                        label: color.displayName,
                        color: color,
                        isSelected: filterColor == color
                    ) {
                        filterColor = (filterColor == color) ? nil : color
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: appState.pdfDocument == nil ? "doc.text" : "highlighter")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text(appState.pdfDocument == nil
                 ? "Open a PDF to see highlights"
                 : "No highlights found")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            if appState.pdfDocument == nil {
                Text("⌘O to open a file")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var highlightsList: some View {
        List(selection: $appState.selectedHighlight) {
            ForEach(filteredHighlights) { highlight in
                HighlightRow(highlight: highlight)
                    .tag(highlight)
                    .onTapGesture {
                        appState.navigateToHighlight(highlight)
                    }
                    .contextMenu {
                        Button("Delete Highlight", role: .destructive) {
                            appState.removeHighlight(highlight)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Highlight row

struct HighlightRow: View {
    let highlight: Highlight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Color indicator + page number
            HStack(spacing: 6) {
                Circle()
                    .fill(highlight.color.swiftUIColor)
                    .frame(width: 8, height: 8)
                
                Text(highlight.spansMultiplePages
                     ? "Pages \(highlight.pageNumber)-\(highlight.endPageIndex + 1)"
                     : "Page \(highlight.pageNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                
                Spacer()
                
                if highlight.note != nil {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Highlighted text
            Text(highlight.text)
                .font(.callout)
                .lineLimit(4)
                .foregroundStyle(.primary)
            
            // Note/comment if present
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

// MARK: - Filter chip

struct FilterChip: View {
    let label: String
    let color: HighlightColor?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color = color {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 6, height: 6)
                }
                
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
