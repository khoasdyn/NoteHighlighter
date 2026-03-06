# Sidebar divider hard to grab in NavigationSplitView

## Problem

The sidebar divider in NoteHighlighter's `NavigationSplitView` is extremely difficult to grab when approaching from the right (PDF side). The cursor must be positioned with pixel-level precision to get the resize pointer to appear. Approaching from the left (sidebar side) is noticeably easier.

In contrast, native macOS apps using the same sidebar pattern (Preview, Notes, Music, Finder) have a much more forgiving grab area from both directions.

## Root cause

The `PDFKitView` (wrapping `HighlightablePDFView`) fills the entire detail column edge-to-edge with no leading inset. `HighlightablePDFView` overrides `mouseDown`, `mouseDragged`, and `mouseUp`, and its internal `NSScrollView` extends flush to the left edge of the detail pane. When the cursor approaches the divider from the right, the PDFView's event handlers intercept the mouse before it ever reaches the ~1pt `NSSplitView` divider hit-test zone. From the left (sidebar side), SwiftUI content doesn't capture events the same way, so the cursor can still reach the divider.

This explains the directional asymmetry: the issue is not that the divider's hit-test area is too narrow on its own, but that the PDFView's aggressive event capture blocks access to it from one side.

## Approaches tried (failed)

### 1. Remove inner `.frame()` on the sidebar VStack

The `HighlightSidebar` body had `.frame(minWidth: 280, idealWidth: 320, maxWidth: 400)` on its VStack, while `ContentView` also had `.navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)` on the `NavigationSplitView`. The theory was that the inner frame was capping the VStack width and creating a dead zone between the content edge and the real divider.

**Result:** No improvement.

### 2. Move `.navigationSplitViewColumnWidth()` from the container to the sidebar content

Apple's documentation shows `.navigationSplitViewColumnWidth()` applied to the sidebar content view, not the `NavigationSplitView` container. The theory was that misplacing this modifier caused the system to misconfigure column boundaries, misaligning the divider hit-test area.

**Result:** No improvement.

### 3. NSViewRepresentable delegate proxy to widen the effective rect

Created `SplitDividerConfigurator.swift`, an `NSViewRepresentable` that walks up the view hierarchy to find the underlying `NSSplitView`, then installs a delegate proxy that overrides `splitView(_:effectiveRect:forDrawnRect:ofDividerAt:)` to widen the hit-test area by 4pt on each side.

**Result:** No improvement. SwiftUI's internal delegate management likely overrides the proxy.

### 4. Content inset on the internal NSScrollView

Inside `HighlightablePDFView.setupScrollObserver()`, set `scrollView.contentInsets.left = 4` with `automaticallyAdjustsContentInsets = false` to shift the scroll content right without changing the PDFView's frame.

**Result:** No improvement. PDFView's internal scroll management appears to override manual content inset changes.

## Solution

Add `.padding(.leading, 4)` to the `PDFKitView` in `ContentView`, paired with `.background(Color(white: 0.95))` to match the PDFView's background color and eliminate any visible seam.

```swift
PDFKitView(document: appState.pdfDocument, pdfView: $pdfViewRef, appState: appState)
    .padding(.leading, 4)
    .background(Color(white: 0.95))
```

The 4pt SwiftUI padding creates a non-interactive gap between the divider and the PDFView's event-capturing area. The background color match makes the gap invisible.

## Status

**Resolved.**
