# PDF Highlights

A native macOS app that extracts and organizes highlight annotations from PDF files.

## Features

- Import PDF files via file picker, drag-and-drop, or ⌘O
- Automatically extracts all highlight annotations with their text, page number, color, and notes
- Sidebar with searchable, filterable highlight list
- Click a highlight to navigate to its location in the PDF
- Filter highlights by color
- Export all highlights as Markdown

## Setup in Xcode

1. Open Xcode and create a new project:
   - Choose **macOS > App**
   - Product Name: `PDFHighlights`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests"

2. Delete the default `ContentView.swift` that Xcode generates.

3. Copy all `.swift` files from this folder into your Xcode project's `PDFHighlights` group:
   - `PDFHighlightsApp.swift` (replace the generated one)
   - `AppState.swift`
   - `ContentView.swift`
   - `HighlightModel.swift`
   - `HighlightExtractor.swift`
   - `HighlightSidebar.swift`
   - `PDFKitView.swift`
   - `HighlightExporter.swift`

4. In your project's **Signing & Capabilities**:
   - Under **App Sandbox**, enable **User Selected File** (Read Only is sufficient)
   - This allows the file importer and drag-and-drop to work

5. Build and run (⌘R).

## Architecture

| File | Purpose |
|------|---------|
| `PDFHighlightsApp.swift` | App entry point, window config, menu commands |
| `AppState.swift` | Shared state: loaded document, highlights, navigation |
| `ContentView.swift` | Main split layout, file import, drag-and-drop, export |
| `HighlightSidebar.swift` | Left sidebar with search, color filters, highlight list |
| `HighlightModel.swift` | Data model for highlights and color classification |
| `HighlightExtractor.swift` | Reads PDF annotations and extracts highlight data |
| `PDFKitView.swift` | NSViewRepresentable wrapper around PDFView |
| `HighlightExporter.swift` | Converts highlights to Markdown format |

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
