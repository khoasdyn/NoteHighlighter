# Architecture

## File structure

```
NoteHighlighter/
├── App/
│   └── NoteHighlighterApp.swift      App entry point
├── Models/
│   ├── AppState.swift                Shared state (@Observable)
│   ├── DataModels.swift              SwiftData models (BookItem, SavedHighlight)
│   └── HighlightModel.swift          Value types (Highlight, HighlightColor) + PDFAnnotation extension
├── Views/
│   ├── ContentView.swift             Main split-view layout
│   ├── GalleryView.swift             Library grid with book cards
│   └── HighlightSidebar.swift        Left panel: search, filters, highlight list
├── Services/
│   ├── BookStorage.swift             PDF file management (copy, delete, thumbnails)
│   └── HighlightExtractor.swift      Reads annotations from PDFDocument
├── Components/
│   ├── HighlightablePDFView.swift    Custom PDFView subclass (handles, editing)
│   ├── PDFKitView.swift              SwiftUI ↔ AppKit bridge
│   └── SelectionToolbar.swift        Floating toolbar (colors, copy, delete)
└── Assets.xcassets/                  App icons and colors
```

## Layer diagram

```
┌─────────────────────────────────────────────┐
│  NoteHighlighterApp                         │
│  ├─ GalleryView          (library)          │
│  └─ ContentView (NavigationSplitView)       │
│       ├─ HighlightSidebar     (SwiftUI)     │
│       └─ PDFKitView           (bridge)      │
│            └─ HighlightablePDFView (AppKit) │
│                 ├─ HandleDotView ×2         │
│                 └─ SelectionToolbar         │
└─────────────────────────────────────────────┘
         ▲                ▲
         │                │
    AppState ◄──── HighlightExtractor
    (@Observable)  (reads PDFDocument)
```

## File responsibilities

### NoteHighlighterApp.swift
App entry point. Creates the window, injects `AppState` via `.environment()`, sets up SwiftData `ModelContainer`, and registers keyboard commands.

### AppState.swift
Central `@Observable` class shared across all views via `@Environment(AppState.self)`. Owns the `PDFDocument`, the extracted `[Highlight]` array, and the currently selected highlight color. Infrastructure references (`pdfView`, `modelContext`) are marked `@ObservationIgnored` to avoid unnecessary view invalidation. Key methods: `openBook`, `closeBook`, `addHighlightFromSelection`, `removeHighlight`, `navigateToHighlight`, `refreshHighlights`.

### ContentView.swift
`NavigationSplitView` with sidebar (`HighlightSidebar`) and detail pane (`PDFKitView`). No toolbar buttons; all interaction happens through the floating `SelectionToolbar`.

### DataModels.swift
SwiftData persistence models:

- `BookItem` — represents a PDF in the library with title, fileName, thumbnail, and a cascade-delete relationship to its highlights. `highlightCount` computes unique groups.
- `SavedHighlight` — persisted highlight data with bounds stored as individual `Double` properties (SwiftData requirement). Provides a computed `bounds: CGRect`.

### HighlightModel.swift
Three types:

- `Highlight` — immutable value type representing one highlight entry in the sidebar. Stores text, page range, color, bounds, optional note, and `groupID` (UUID linking per-line annotations).
- `HighlightColor` — enum with 7 colors + unknown. Provides `swiftUIColor` (for sidebar), `nsColor` (35% alpha, for PDF annotations), `opaqueColor` (for toolbar display), `displayName`, `selectableColors` (toolbar subset excluding `.unknown`), and `from(nsColor:)` classifier using nearest-neighbor RGB distance.
- `PDFAnnotation.isHighlightAnnotation` — extension eliminating duplicate `type == "Highlight" || markupType == .highlight` checks across the codebase.

### HighlightExtractor.swift
Static utility (enum-based, no instances). Scans all pages of a `PDFDocument`, collects highlight annotations grouped by `userName`/groupID, and merges them into `[Highlight]`. Uses a private `AnnotationEntry` struct for intermediate processing.

### HighlightSidebar.swift
SwiftUI sidebar with three sections: header (file name, count), search + color filter chips, and a scrollable list of `HighlightRow` items. Right-click context menu for deletion. Tapping a row calls `navigateToHighlight`. Contains private subview types `HighlightRow` and `FilterChip`.

### GalleryView.swift
Library grid view with `@Query`-driven `BookItem` list, file import handling, and book deletion. Contains private `BookCard` subview for thumbnail display.

### PDFKitView.swift
`NSViewRepresentable` bridge. Creates a `HighlightablePDFView`, wires the document and `appState`, and exposes a binding for the `PDFView` reference so `AppState` can call navigation methods.

### HighlightablePDFView.swift
`PDFView` subclass. The most complex file. Three responsibilities:

**1. Editing with drag handles.** When a highlight is clicked, two `HandleDotView` instances appear (teardrop-style: circle + stick spanning the line height). Dragging a handle calls `rebuildAnnotations()`, which uses `PDFDocument.selection(from:at:to:at:)` to recompute the highlight across pages. Stored `editingColor` and `editingGroupID` prevent data loss during the remove-and-recreate cycle. Layout constants are centralized in a private `Layout` enum.

**2. Floating toolbar.** Shows `SelectionToolbar` on text selection (for creating highlights) or when clicking an existing highlight (for changing color / deleting). Positioned near the selection endpoint.

**3. Hit testing.** `highlightGroupAtPoint` finds which highlight group was clicked. `findConnectedGroup` uses groupID when available, falls back to proximity for imported annotations.

Also contains `HandleDotView` (companion class): custom `NSView` that draws a blue circle + vertical stick with layout constants in its own `Layout` enum.

### SelectionToolbar.swift
AppKit `NSView` with an `NSStackView` containing: Copy button, 7 color circles (driven by `HighlightColor.selectableColors`), and a conditionally-visible Delete button. Styling constants are centralized in a private `Style` enum.

### BookStorage.swift
Singleton managing the on-disk PDF library in Application Support. Handles copying PDFs into app storage, generating JPEG thumbnails, and cleanup on deletion.

## Key design decisions

**Per-line annotations with groupID.** PDF highlight annotations are stored one-per-line (required by PDFKit rendering), but linked by a shared UUID in the `userName` field. The extractor merges them back into single sidebar entries.

**Semi-transparent colors (35% alpha).** Overlapping highlights produce visible color stacking.

**@Observable over ObservableObject.** Provides granular property-level observation, reducing unnecessary view invalidations. Infrastructure references use `@ObservationIgnored`.

**Centralized color definitions.** `HighlightColor` is the single source of truth for annotation colors (`nsColor`), toolbar display colors (`opaqueColor`), SwiftUI colors (`swiftUIColor`), and the selectable color set (`selectableColors`).

**Shared annotation type checking.** `PDFAnnotation.isHighlightAnnotation` extension eliminates duplicated type/markup checks across 5 call sites.
