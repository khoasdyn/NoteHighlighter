# Architecture

## File structure

```
NoteHighlighter/
├── NoteHighlighterApp.swift      App entry point
├── AppState.swift                Shared state (ObservableObject)
├── ContentView.swift             Main split-view layout
├── HighlightModel.swift          Data models (Highlight, HighlightColor)
├── HighlightExtractor.swift      Reads annotations from PDFDocument
├── HighlightSidebar.swift        Left panel: search, filters, highlight list
├── PDFKitView.swift              SwiftUI ↔ AppKit bridge
├── HighlightablePDFView.swift    Custom PDFView subclass (handles, editing)
├── SelectionToolbar.swift        Floating toolbar (colors, copy, delete)
└── Assets.xcassets/              App icons and colors
```

## Layer diagram

```
┌─────────────────────────────────────────────┐
│  NoteHighlighterApp                         │
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
    (shared)       (reads PDFDocument)
```

## File responsibilities

### NoteHighlighterApp.swift
App entry point. Creates the window, injects `AppState` as environment object, registers ⌘O menu command.

### AppState.swift
Central `ObservableObject` shared across all views. Owns the `PDFDocument`, the extracted `[Highlight]` array, and the currently selected highlight color. Key methods: `loadPDF`, `addHighlightFromSelection`, `removeHighlight`, `navigateToHighlight`, `refreshHighlights`.

### ContentView.swift
`NavigationSplitView` with sidebar and detail pane. Handles file import (picker + drag-and-drop). No toolbar buttons; all interaction happens through the floating `SelectionToolbar`.

### HighlightModel.swift
Two types:

- `Highlight` — immutable value type representing one highlight entry in the sidebar. Stores text, page range, color, bounds, optional note, and `groupID` (UUID linking per-line annotations).
- `HighlightColor` — enum with 7 colors + unknown. Provides `swiftUIColor` (for sidebar), `nsColor` (35% alpha, for PDF annotations), `displayName`, and `from(nsColor:)` classifier using nearest-neighbor RGB distance.

### HighlightExtractor.swift
Static utility. Scans all pages of a `PDFDocument`, collects highlight annotations, and merges them into `[Highlight]`:

- **Grouped** (has `userName`/groupID): collected by dictionary lookup, supports cross-page spans. Created by our app.
- **Ungrouped** (no groupID): merged by vertical proximity + same color on same page. Handles highlights imported from Preview, Acrobat, etc.

### HighlightSidebar.swift
SwiftUI sidebar with three sections: header (file name, count), search + color filter chips, and a scrollable list of `HighlightRow` items. Right-click context menu for deletion. Tapping a row calls `navigateToHighlight`.

### PDFKitView.swift
`NSViewRepresentable` bridge. Creates a `HighlightablePDFView`, wires the document and `appState`, and exposes a binding for the `PDFView` reference so `AppState` can call navigation methods.

### HighlightablePDFView.swift
`PDFView` subclass (~550 lines). The most complex file. Three responsibilities:

**1. Editing with drag handles.** When a highlight is clicked, two `HandleDotView` instances appear (teardrop-style: circle + stick spanning the line height). Dragging a handle calls `rebuildAnnotations()`, which uses `PDFDocument.selection(from:at:to:at:)` to recompute the highlight across pages. Stored `editingColor` and `editingGroupID` prevent data loss during the remove-and-recreate cycle.

**2. Floating toolbar.** Shows `SelectionToolbar` on text selection (for creating highlights) or when clicking an existing highlight (for changing color / deleting). Positioned near the selection endpoint.

**3. Hit testing.** `highlightGroupAtPoint` finds which highlight group was clicked. `findConnectedGroup` uses groupID when available, falls back to proximity for imported annotations.

Also contains `HandleDotView` (inner class): custom `NSView` that draws a blue circle + vertical stick. Height is dynamic based on annotation line height.

### SelectionToolbar.swift
AppKit `NSView` with an `NSStackView` containing: Copy button, 7 color circles, and a conditionally-visible Delete button. Color circles are `NSView` containers with invisible `NSButton` overlays. Actions delegate to `HighlightablePDFView` methods.

## Key design decisions

**Per-line annotations with groupID.** PDF highlight annotations are stored one-per-line (required by PDFKit rendering), but linked by a shared UUID in the `userName` field. The extractor merges them back into single sidebar entries. This allows overlapping highlights of the same color to stay separate.

**Semi-transparent colors (35% alpha).** Overlapping highlights produce visible color stacking, making it clear where two highlights share the same text.

**Two merge strategies in the extractor.** GroupID-based (our highlights) and proximity-based (imported highlights) run as separate paths, preventing cross-contamination.

**Stored editing state.** `editingColor` and `editingGroupID` are cached when entering edit mode because the annotation objects get deleted mid-rebuild during drag operations.
