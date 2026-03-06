# Word selection mode: outer gap issue

## The problem

### What happens

In NoteHighlighter's Word selection mode, text selection and highlight handle adjustment break when the mouse cursor moves outside the text area of a PDF page. There are two distinct zones where this occurs:

1. **Page margin area**: the white space on the PDF page itself, outside the text columns but still within the page boundary. For example, the area to the right of a centered line like "India" where no text exists, or below the last line of text on a page.

2. **Inter-page gap area**: the gray background between and around pages in the PDF viewer. This is the space managed by PDFKit's scroll view, not part of any page.

When the cursor enters either of these areas during a drag:

- **During initial text selection**: the blue selection highlight disappears entirely. The cursor continues to track, but no text is shown as selected. If the user releases the mouse in this state, nothing is highlighted.

- **During highlight handle adjustment**: the teardrop grab handles become detached from any text. They float on screen at the cursor position, but the underlying highlight annotations are removed (because `rebuildAnnotations()` produces an empty result). If the user scrolls while in this state, the handles drift visually while no highlight exists in the document.

### What should happen

Character mode (the default PDFKit behavior via `super.mouseDown`/`super.mouseDragged`) handles all of these zones correctly. When you drag into page margins or inter-page gaps in Character mode:

- The selection extends to the nearest text on the current line, or to the end/beginning of the line if the cursor is horizontally beyond the text.
- Moving vertically into gaps between lines extends the selection to include the nearest line above or below.
- Moving into the gray inter-page gap extends the selection to the edge of the nearest page.
- The selection never disappears. It always remains anchored to valid text.

Word mode should behave identically to Character mode in these edge cases, with the only difference being that selection boundaries snap to word edges rather than character edges.

### How to reproduce

1. Open any PDF in NoteHighlighter.
2. Switch to Word selection mode via the toolbar toggle.
3. Click on a word near the edge of a text block (e.g., the last word on a centered line).
4. Drag the mouse to the right, past the end of the text, into the white page margin.
5. Observe: the selection disappears.
6. Continue dragging into the gray area between pages.
7. Observe: the selection remains gone.
8. Release the mouse. No toolbar appears, no text is selected.

For handles:

1. Create a highlight in Word mode.
2. Click the highlight to enter editing mode (handles appear).
3. Drag the end handle to the right, past the text, into the page margin or gray area.
4. Observe: the highlight annotations disappear, handles float detached.
5. Scroll up or down. Handles drift on screen with no corresponding highlight.

## Technical analysis

### Why Character mode works

In Character mode, all three mouse events (`mouseDown`, `mouseDragged`, `mouseUp`) call `super` — that is, PDFKit's built-in `PDFView` implementation. PDFKit internally tracks the drag anchor point and the current drag point, and uses its own coordinate system and text layout knowledge to compute a valid selection between those two points. When the cursor leaves the text area, PDFKit's internal logic clamps or extends the selection to the nearest valid text boundary. This clamping logic is entirely private — it is not exposed through any public API.

The key insight: PDFKit's selection robustness comes from its internal drag state machine, not from any single API call.

### Why Word mode fails

Word mode bypasses PDFKit's drag handling entirely. Instead of calling `super.mouseDragged`, it intercepts the event and manually builds a selection using two APIs:

1. **`PDFPage.selectionForWord(at:)`**: returns the word at a given page coordinate, or `nil` if the point is not over any text.

2. **`PDFDocument.selection(from:at:to:at:)`**: returns a selection between two page-coordinate points, or `nil` / an empty selection if either point is too far from text.

Both APIs return `nil` or degenerate results when the point is in whitespace. The current code handles some `nil` cases (falling back to raw points for line-height gaps), but fails in two critical scenarios:

### Failure point 1: initial selection drag

In `mouseDragged`, the Word-mode branch does:

```swift
guard let document,
      let startPage = wordSelectionStartPage,
      let dragPage = page(for: viewPoint, nearest: true) else { return }
```

When the cursor is in the gray inter-page gap, `page(for: viewPoint, nearest: true)` may return a page, but the converted point on that page is far from any text. The subsequent `selectionForWord` calls return `nil` for both start and end, and `document.selection(from:at:to:at:)` with the raw fallback points produces `nil` or an empty selection.

Even when `document.selection` does return a non-nil value, PDFKit may return a zero-width or whitespace-only selection for points deep in the margin area, which effectively clears the visible selection.

### Failure point 2: handle drag

In the handle drag path, the code updates `startPagePoint` or `endPagePoint` and then calls `rebuildAnnotations()`. When the point is in the outer gap:

```swift
var pagePoint = convert(viewPoint, to: page)
if appState?.selectionMode == .word,
   let wordSel = page.selectionForWord(at: pagePoint) {
    // snaps to word — this branch is skipped when in gap
}
startPagePoint = pagePoint  // raw point far from text
```

The raw point gets passed to `rebuildAnnotations()`, which calls:

```swift
document.selection(from: startPage, at: startPagePoint, to: endPage, at: endPagePoint)
```

With one endpoint far from any text, this returns `nil`, causing all existing annotations to be removed (since they were already deleted earlier in the method). The handles remain visible but orphaned.

### Why the fallback to raw points is insufficient

The fallback strategy of using raw page-coordinate points when `selectionForWord` returns `nil` assumes that `document.selection(from:at:to:at:)` will snap to the nearest text. This assumption holds for points in inter-line gaps (small distances from text), but fails for points in page margins or inter-page areas (large distances from text). PDFKit's `selection(from:at:to:at:)` does not have the same robust clamping that its internal drag handler does.

### The fundamental constraint

PDFKit's robust edge-case handling lives inside its private drag state machine, accessible only through `super.mouseDown` / `super.mouseDragged` / `super.mouseUp`. There is no public API to get "the nearest valid selection endpoint" for an arbitrary point. The available APIs (`selectionForWord`, `selectionForLine`, `selection(from:at:to:at:)`) all fail gracefully by returning nil or empty results rather than clamping to the nearest text.

## Approaches tried

### Approach 1: fall back to raw points when selectionForWord returns nil

When `selectionForWord(at:)` returned `nil` for the drag endpoint, the code used the raw page coordinate as a fallback, hoping `document.selection(from:at:to:at:)` would snap to nearby text.

**Result**: partially worked. Fixed the line-height gap issue (small whitespace between lines of text) because the raw point was close enough to text that `document.selection` could find a valid selection. Did not fix the outer gap issue because points in page margins and inter-page areas are too far from text for `document.selection` to produce a valid result.

### Approach 2: validate selection before applying

Added a check that only applied a new selection if it contained non-empty, non-whitespace text:

```swift
if let selection = document.selection(...),
   let text = selection.string,
   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    currentSelection = selection
}
```

**Result**: prevented the selection from being cleared (since the invalid selection was discarded), but the selection froze at its last valid state rather than extending to the edge of the text. The visual effect was that dragging into the margin caused the selection to stop updating, which is better than disappearing but still incorrect compared to Character mode's behavior of extending to the line edge.

### Approach 3: keep last valid handle points

For handle drag, modified the code to only update `startPagePoint` / `endPagePoint` when `selectionForWord` succeeded, preserving the last valid word-snapped position when the cursor was in a gap:

```swift
if appState?.selectionMode == .word {
    if let wordSel = page.selectionForWord(at: pagePoint) {
        // update point
    }
    // else: don't update, keep last valid point
}
```

**Result**: same as approach 2. The handle position froze instead of tracking the cursor. Better than disappearing, but handles should continue tracking smoothly like they do in Character mode.

### Approach 4: delegate to super.mouseDragged, snap at mouseUp

Completely changed the Word-mode strategy: let PDFKit handle all drag events natively via `super.mouseDragged` (identical to Character mode), then snap the final selection to word boundaries only at `mouseUp` time.

```swift
// mouseDragged
if wordSelectionActive {
    super.mouseDragged(with: event) // PDFKit handles gaps
    return
}

// mouseUp — snap afterward
snapSelectionToWordBounds()
```

**Result**: broken. Calling `super.mouseDown` in Word mode initiated PDFKit's internal drag state machine, but the preceding code in `mouseDown` (highlight group detection, editing checks) had already consumed the event in some cases. Additionally, mutating `currentSelection` in `snapSelectionToWordBounds()` conflicted with PDFKit's internal state, causing subsequent drags to break entirely. Highlighting stopped working.

### Approach 5: delegate to super.mouseDragged, snap in real-time

Same as approach 4, but called `snapSelectionToWordBounds()` during each `mouseDragged` event instead of only at `mouseUp`.

**Result**: worse than approach 4. Setting `currentSelection` during drag corrupted PDFKit's internal drag tracking. On the next `super.mouseDragged` call, PDFKit saw a mismatched selection state and produced garbage or empty selections. The selection flickered and disappeared.

### Current state

Reverted to the manual word-boundary approach (not delegating to `super`) with fallback to raw points for inter-line gaps. The line-height gap issue is fixed. The outer gap issue (page margins and inter-page areas) remains unresolved.

## Possible future solutions

### Solution 1: custom NSTrackingArea with edge clamping

Add an `NSTrackingArea` to the `HighlightablePDFView` that detects when the cursor exits the page's text bounds. When the cursor leaves the text area, clamp the drag point to the nearest edge of the page's text content rect (available via `PDFPage.bounds(for: .cropBox)` or by computing text bounds from annotations/selections).

For example, if the cursor is to the right of the text, clamp `x` to the page's right text edge. If the cursor is below the text, clamp `y` to the bottom of the last line. Pass the clamped point to `selectionForWord(at:)` and `document.selection(from:at:to:at:)`.

This would require computing or caching the text content rect for each page, which could be done lazily on first drag. The challenge is accurately determining where text ends on each page, since PDFKit does not expose a "text bounding box" API directly.

### Solution 2: binary search for nearest valid word

When `selectionForWord(at:)` returns `nil`, perform a binary search between the last known good point and the current point to find the boundary where `selectionForWord` transitions from non-nil to nil. Use the last non-nil point as the effective drag endpoint.

This would give smooth selection extension to the edge of text, since the binary search converges to the exact point where text ends. The cost is multiple `selectionForWord` calls per drag event (approximately 10-15 for binary search convergence), which may introduce latency on complex pages.

### Solution 3: pre-compute text line rects per page

On document load (or lazily per page), extract all text line rects by iterating through `PDFPage.numberOfCharacters` and `PDFPage.characterBounds(at:)`, or by using `PDFPage.selectionForRange()` for the full page and decomposing via `selectionsByLine()`. Cache these rects per page.

During drag, when the cursor is outside all cached line rects, find the nearest line rect and clamp the point to its edge. This gives precise clamping without binary search, but requires upfront computation per page and memory for the cache.

### Solution 4: replace NavigationSplitView with NSSplitViewController and custom PDFView hosting

The most invasive but most robust solution. Replace the SwiftUI `NavigationSplitView` with a fully AppKit-based `NSSplitViewController` hosting both the sidebar and the `PDFView`. This gives full access to PDFKit's drag handling without the SwiftUI bridge layer, and allows subclassing or swizzling internal methods to intercept the selection at the right point in the event chain.

Within this architecture, Word mode could override `PDFView.setCurrentSelection(_:animate:)` to snap incoming selections to word boundaries, rather than intercepting mouse events. This is how the selection is ultimately set regardless of where the drag occurs, so it would work for all edge cases including gaps.

This approach would require significant refactoring of the view layer and is better suited as a long-term architectural change rather than a targeted fix.

### Solution 5: accept the current behavior as a minor limitation

The outer gap issue only manifests when the cursor leaves the text area entirely. For typical reading and highlighting workflows, users drag across text within the page content area. The line-height gap fix (approach 1) covers the most common edge case. The remaining outer gap issue could be documented as a known limitation of Word mode, with Character mode available as a fallback for edge cases.

### Recommended next step

Solution 2 (binary search for nearest valid word) offers the best balance of correctness, implementation complexity, and risk. It does not require pre-computation, does not touch the view architecture, and converges quickly. The main unknown is whether the `selectionForWord` calls introduce noticeable latency during drag — this should be profiled before committing to the approach.
