# Architecture

## File structure

```
NoteHighlighter/
├── App/
│   └── NoteHighlighterApp.swift       App entry point, scene routing
├── Models/
│   ├── AppState.swift                 Shared state (@Observable), book lifecycle, TOC navigation
│   ├── AppState+Highlights.swift      Highlight persistence, CRUD, navigation
│   ├── AppState+Search.swift          PDF text search, word-boundary matching, SearchObserver
│   ├── DataModels.swift               SwiftData models (BookItem, SavedHighlight)
│   └── HighlightModel.swift           Value types (Highlight, HighlightColor, SearchResultGroup)
├── Views/
│   ├── ContentView.swift              Reader split-view (sidebar + PDF detail)
│   ├── GalleryView.swift              Library home with sidebar tabs + book grid
│   ├── HighlightSidebar.swift         Reader sidebar: highlights, search results, filters
│   ├── SearchResultBar.swift          Floating search nav bar over the PDF
│   └── TOCSidebarView.swift           Table of contents sidebar with recursive outline
├── Services/
│   ├── BookStorage.swift              PDF file management (copy, delete, thumbnails)
│   └── HighlightExtractor.swift       Reads annotations from PDFDocument → [Highlight]
├── Components/
│   ├── HighlightablePDFView.swift     Custom PDFView subclass (handles, editing, toolbar)
│   ├── PDFKitView.swift               SwiftUI ↔ AppKit bridge (NSViewRepresentable)
│   └── SelectionToolbar.swift         Floating AppKit toolbar (colors, copy, delete)
└── Assets.xcassets/                   App icons and colors
```

## Layer diagram

```
┌──────────────────────────────────────────────────────┐
│  NoteHighlighterApp                                  │
│  ├─ GalleryView (NavigationSplitView)                │
│  │    ├─ SidebarTab list  (Library, Notes, ...)      │
│  │    └─ Book grid / placeholder detail              │
│  └─ ContentView (NavigationSplitView)                │
│       ├─ HighlightSidebar     (SwiftUI)              │
│       │    ├─ Highlights + filters                   │
│       │    ├─ Search results                         │
│       │    └─ TOCSidebarView                         │
│       ├─ SearchResultBar      (overlay)              │
│       └─ PDFKitView           (bridge)               │
│            └─ HighlightablePDFView (AppKit)          │
│                 ├─ HandleDotView ×2                  │
│                 └─ SelectionToolbar                  │
└──────────────────────────────────────────────────────┘
         ▲                ▲
         │                │
    AppState ◄──── HighlightExtractor
    (@Observable)  (reads PDFDocument)
         │
    SwiftData (BookItem, SavedHighlight)
```

## Navigation flow

The app has two top-level screens, swapped in `NoteHighlighterApp` based on `appState.currentBook`:

1. **Library** (`GalleryView`): a `NavigationSplitView` with a sidebar listing tabs (Library, Notes, Journal, Settings). Only Library is functional; others show a "Coming soon" placeholder. The detail pane displays a `LazyVGrid` of `BookCard` thumbnails. Tapping a card calls `appState.openBook()`.

2. **Reader** (`ContentView`): a `NavigationSplitView` with `HighlightSidebar` and a `PDFKitView` detail pane. The sidebar toggles between highlight mode, search results mode, and table of contents mode via `appState.sidebarMode`. Closing the book returns to the library.

## File responsibilities

### NoteHighlighterApp.swift

App entry point. Creates the `ModelContainer` for SwiftData, injects `AppState` via `.environment()`, and conditionally shows either `GalleryView` or `ContentView` based on whether a book is open. Registers ⌘O (import) and ⌘W (close) keyboard commands.

### AppState.swift

Central `@Observable` class shared across all views. Owns the current `PDFDocument`, extracted highlights, UI mode state, and search state. Infrastructure references (`pdfView`, `modelContext`, `searchObserver`) are marked `@ObservationIgnored` to avoid unnecessary view invalidation.

The class is split across three files by responsibility: core state and book lifecycle live here, highlight operations in `AppState+Highlights.swift`, and search logic in `AppState+Search.swift`.

Key methods: `openBook(_:)`, `closeBook()`, `navigateToOutline(_:)`.

Computed properties: `currentPageLabel` (respects PDF page labels), `hasTableOfContents`, `searchResultsByPage` (groups search matches by page for sidebar display).

### AppState+Highlights.swift

Highlight persistence and operations. `loadHighlights()` reads `SavedHighlight` records from SwiftData, recreates `PDFAnnotation` objects on the document, then runs `HighlightExtractor` to rebuild the sidebar list. `saveHighlights()` does the reverse: deletes existing records, walks all pages for annotations with a `userName` groupID, and persists them.

Operations: `addHighlightFromSelection()` creates per-line annotations with a shared UUID groupID, `removeHighlight(_:)` finds and removes matching annotations, `refreshHighlights()` re-extracts and saves, `navigateToHighlight(_:)` scrolls the PDFView to center the highlight.

### AppState+Search.swift

Async PDF search using `PDFDocument.beginFindString()` with a `SearchObserver` (NSObject conforming to `PDFDocumentDelegate`). The observer forwards `didMatchString` and `documentDidEndDocumentFind` callbacks to `AppState`.

Includes word-boundary filtering: `isWholeWordMatch(_:)` extends the selection by 1 character on each side and checks that the match isn't mid-word.

Navigation: `nextSearchResult()`, `previousSearchResult()`, `navigateToSearchResult(at:)` with Y-offset centering, and `clearSearch()`.

### DataModels.swift

SwiftData persistence models:

- **BookItem**: represents a PDF in the library. Stores title, fileName (UUID-based), dateAdded, and optional JPEG thumbnail data (`.externalStorage`). Has a cascade-delete `@Relationship` to `[SavedHighlight]`. `highlightCount` counts unique groupIDs.

- **SavedHighlight**: persisted highlight with text, pageIndex, pageLabel, colorName, optional note, bounds as individual Doubles (SwiftData requirement), groupID, and dateCreated. Provides a computed `bounds: CGRect`.

### HighlightModel.swift

Three main types:

- **Highlight**: immutable value type for sidebar display. Stores text, page range, color, bounds, optional note, and groupID. `spansMultiplePages` computed property.

- **HighlightColor**: enum with 7 named colors + `.unknown`. Provides three color variants: `nsColor` (35% alpha for PDF overlays), `opaqueColor` (for toolbar circles), `swiftUIColor` (for sidebar). `from(nsColor:)` classifies arbitrary colors via nearest-neighbor RGB distance. `selectableColors` excludes `.unknown`.

- **SearchResultGroup**: groups search matches by page for sidebar display. Generates snippet text with surrounding context via word-boundary extraction. Each snippet tracks its global selection index for navigation.

Also extends `PDFAnnotation` with `isHighlightAnnotation` to eliminate repeated `type == "Highlight"` checks.

### HighlightExtractor.swift

Static utility (enum-based, no instances). Scans all pages of a `PDFDocument`, collects highlight annotations grouped by `userName`/groupID, merges per-line annotations into single `Highlight` entries with combined text and union bounds. Returns highlights sorted by page index then vertical position. Uses a private `AnnotationEntry` struct for intermediate processing.

### GalleryView.swift

Library home screen. Contains a `SidebarTab` enum (Library, Notes, Journal, Settings) with SF Symbol icons. The view is a `NavigationSplitView` with a `List` sidebar and a detail pane that switches between the book grid (`libraryContent`) and a placeholder for unimplemented tabs.

The library grid uses `@Query` to fetch `BookItem` records sorted by date. File import handling copies the PDF via `BookStorage`, generates a thumbnail, and inserts a `BookItem` into SwiftData. Context menu supports deletion.

Private subview `BookCard` displays the thumbnail, title, and highlight count.

### ContentView.swift

Reader screen. `NavigationSplitView` with `HighlightSidebar` and `PDFKitView`. The PDFKitView has `.padding(.leading, 4)` to prevent its event handlers from blocking the split view divider grab zone (see "Known workarounds" below).

Overlays `SearchResultBar` when search is active. The toolbar contains a back-to-library button. Search is integrated via `.searchable()`.

### HighlightSidebar.swift

The reader's left panel, which switches between three modes:

1. **Highlights mode** (`appState.sidebarMode == .highlights`): header with count, local search field, color filter chips, and a scrollable `List` of `HighlightRow` items. Tapping navigates, right-click to delete.

2. **Search results mode** (`appState.isSearchActive`): shows search match counts, page-grouped results with highlighted snippets via `SearchResultRow`, and active-result tracking.

3. **Table of contents mode** (`appState.sidebarMode == .tableOfContents`): delegates to `TOCSidebarView`.

Sidebar mode is toggled via a toolbar `Menu` button that also serves as a toggle for the sidebar visibility.

Private subviews: `HighlightRow`, `FilterChip`, `SearchResultRow`.

### TOCSidebarView.swift

Displays the PDF's outline hierarchy using recursive `OutlineItemView` components. Each item shows the section label, page number, and an expand/collapse chevron for entries with children. Tapping navigates via `appState.navigateToOutline(_:)`. Shows an empty state when the PDF has no outline.

### SearchResultBar.swift

Minimal floating bar overlaid at the top-right of the PDF view during active search. Shows the count of pages with matches and previous/next navigation buttons. Uses `.glassEffect()` for a translucent capsule appearance.

### PDFKitView.swift

`NSViewRepresentable` bridge. Creates a `HighlightablePDFView` configured for single-page continuous vertical scrolling with auto-scaling. Exposes a `pdfView` binding so `AppState` can call navigation methods. The `Coordinator` observes `PDFViewPageChanged` notifications to keep `appState.currentPageIndex` in sync.

### HighlightablePDFView.swift

`PDFView` subclass and the most complex file. Three responsibilities:

**1. Editing with drag handles.** When a highlight is tapped or selected from the sidebar, two `HandleDotView` instances appear (teardrop-style: circle + stick spanning the line height). Dragging a handle calls `rebuildAnnotations()`, which deletes old annotations, computes a new selection via `PDFDocument.selection(from:at:to:at:)`, and creates new per-line annotations preserving the original `editingColor` and `editingGroupID`. This prevents color/group data loss during the remove-and-recreate cycle.

**2. Floating toolbar.** Shows `SelectionToolbar` after text selection (for creating highlights) or when clicking an existing highlight (for color change / deletion). Positioned near the selection endpoint with edge clamping.

**3. Hit testing and group detection.** `highlightGroupAtPoint(_:)` finds which highlight group was clicked. `findConnectedGroup(containing:)` uses groupID lookup when available, and falls back to vertical adjacency proximity for legacy annotations without groupIDs.

Also contains `HandleDotView`: custom `NSView` that draws a blue circle + vertical stick. Returns `nil` from `hitTest` so clicks pass through to the PDFView.

### SelectionToolbar.swift

AppKit `NSView` with an `NSStackView` containing: a Copy button, 7 color circles (driven by `HighlightColor.selectableColors`), a separator, and a conditionally-visible Delete button (red). Dark translucent background with shadow. Buttons call back to `HighlightablePDFView` methods.

### BookStorage.swift

Singleton managing the on-disk PDF library at `~/Library/Application Support/NoteHighlighter/Books/`. Copies imported PDFs with UUID-based filenames, generates JPEG thumbnails from the first page, and handles deletion.

## Key design decisions

**Per-line annotations with groupID.** PDF highlight annotations are stored one-per-line (required by PDFKit's rendering). Annotations belonging to the same highlight share a UUID in the `userName` field. `HighlightExtractor` merges them back into single sidebar entries. This also enables cross-page highlights.

**Semi-transparent colors (35% alpha).** Overlapping highlights produce visible color stacking, making it clear when multiple highlights cover the same text.

**@Observable over ObservableObject.** Provides granular property-level observation, reducing unnecessary view invalidations. Infrastructure references (`pdfView`, `modelContext`, `searchObserver`) use `@ObservationIgnored`.

**AppState split across extensions.** Core state in `AppState.swift`, highlight CRUD in `AppState+Highlights.swift`, search logic in `AppState+Search.swift`. Keeps each file focused while maintaining a single shared object.

**Centralized color definitions.** `HighlightColor` is the single source of truth for annotation colors, toolbar display colors, SwiftUI colors, and the selectable color set. The `from(nsColor:)` classifier uses nearest-neighbor RGB distance with a 0.5 threshold.

**Two-level navigation split.** The library uses its own `NavigationSplitView` (gallery sidebar tabs + book grid), and the reader uses a separate `NavigationSplitView` (highlight sidebar + PDF detail). They never coexist because `NoteHighlighterApp` swaps between them based on `appState.currentBook`.

**Async search with delegate.** PDF search uses `beginFindString` with `PDFDocumentDelegate` callbacks rather than the synchronous `findString` API, avoiding UI freezes on large documents. Word-boundary filtering runs on each match to prevent partial-word hits.

## Known workarounds

**Sidebar divider grab zone.** The `PDFKitView` in `ContentView` has `.padding(.leading, 4)` to create a non-interactive gap between the PDFView's event handlers and the `NSSplitView` divider. Without this, the PDFView's `mouseDown`/`mouseDragged` overrides intercept mouse events before they reach the divider when approaching from the right side. See `sidebar-divider-grab-issue.md` for the full investigation.

**AccessibilityNodePage warnings.** PDFKit logs `AccessibilityNodePage` warnings in the console. Setting `annotation.contents` to silence them causes visible duplicate text in the sidebar, so the warnings are left alone.

**First-navigation performance.** Highlight navigation uses `page.selection(for: bounds)` instead of `document.findString()` to avoid triggering full document text indexing on first call.
