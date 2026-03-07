import Cocoa
import PDFKit

// MARK: - Mouse event handling

extension HighlightablePDFView {

    override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)

        let toolbarPoint = selectionToolbar.convert(event.locationInWindow, from: nil)
        if !selectionToolbar.isHidden && selectionToolbar.bounds.contains(toolbarPoint) {
            return
        }

        hideSelectionToolbar()

        if isEditing {
            let startCenter = CGPoint(x: startHandle.frame.midX, y: startHandle.frame.maxY - Layout.circleRadius)
            let endCenter = CGPoint(x: endHandle.frame.midX, y: endHandle.frame.minY + Layout.circleRadius)

            if distance(viewPoint, startCenter) < Layout.handleHitRadius {
                dragging = .start
                return
            } else if distance(viewPoint, endCenter) < Layout.handleHitRadius {
                dragging = .end
                return
            } else {
                if let group = highlightGroupAtPoint(viewPoint) {
                    switchToGroup(group)
                    return
                }
                stopEditing()
                appState?.highlightManager.refreshHighlights()
            }
        } else {
            if let group = highlightGroupAtPoint(viewPoint) {
                switchToGroup(group)
                return
            }
        }

        // Word-mode: record start point but don't select yet (only drag triggers selection)
        if appState?.selectionMode == .word,
           let clickPage = page(for: viewPoint, nearest: true) {
            let pagePoint = convert(viewPoint, to: clickPage)
            wordSelectionActive = true
            wordSelectionDidDrag = false
            wordSelectionStartPage = clickPage
            wordSelectionStartPoint = pagePoint
            currentSelection = nil
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        // Word-mode drag: build selection from start word to current word
        if wordSelectionActive {
            wordSelectionDidDrag = true
            let viewPoint = convert(event.locationInWindow, from: nil)
            guard let document,
                  let startPage = wordSelectionStartPage,
                  let dragPage = page(for: viewPoint, nearest: true) else { return }

            let dragPagePoint = convert(viewPoint, to: dragPage)

            // Get word boundaries; fall back to raw points in whitespace
            let startWord = startPage.selectionForWord(at: wordSelectionStartPoint)
            let endWord = dragPage.selectionForWord(at: dragPagePoint)

            let startIdx = document.index(for: startPage)
            let endIdx = document.index(for: dragPage)
            let isForward: Bool
            if startIdx != endIdx {
                isForward = startIdx < endIdx
            } else {
                isForward = dragPagePoint.y < wordSelectionStartPoint.y ||
                    (abs(dragPagePoint.y - wordSelectionStartPoint.y) < 5 && dragPagePoint.x >= wordSelectionStartPoint.x)
            }

            let fromPage: PDFPage, fromPoint: CGPoint, toPage: PDFPage, toPoint: CGPoint
            if isForward {
                let startPt: CGPoint
                if let startWord {
                    let b = startWord.bounds(for: startPage)
                    startPt = CGPoint(x: b.minX, y: b.midY)
                } else {
                    startPt = wordSelectionStartPoint
                }
                let endPt: CGPoint
                if let endWord {
                    let b = endWord.bounds(for: dragPage)
                    endPt = CGPoint(x: b.maxX, y: b.midY)
                } else {
                    endPt = dragPagePoint
                }
                fromPage = startPage
                fromPoint = startPt
                toPage = dragPage
                toPoint = endPt
            } else {
                let startPt: CGPoint
                if let startWord {
                    let b = startWord.bounds(for: startPage)
                    startPt = CGPoint(x: b.maxX, y: b.midY)
                } else {
                    startPt = wordSelectionStartPoint
                }
                let endPt: CGPoint
                if let endWord {
                    let b = endWord.bounds(for: dragPage)
                    endPt = CGPoint(x: b.minX, y: b.midY)
                } else {
                    endPt = dragPagePoint
                }
                fromPage = dragPage
                fromPoint = endPt
                toPage = startPage
                toPoint = startPt
            }

            if let selection = document.selection(from: fromPage, at: fromPoint, to: toPage, at: toPoint) {
                currentSelection = selection
            }
            return
        }

        guard dragging != .none else {
            super.mouseDragged(with: event)
            return
        }

        let viewPoint = convert(event.locationInWindow, from: nil)

        switch dragging {
        case .start:
            if let page = page(for: viewPoint, nearest: true) {
                var pagePoint = convert(viewPoint, to: page)
                // In Word mode, snap to word boundary when possible
                if appState?.selectionMode == .word,
                   let wordSel = page.selectionForWord(at: pagePoint) {
                    let wordBounds = wordSel.bounds(for: page)
                    pagePoint = CGPoint(x: wordBounds.minX, y: wordBounds.midY)
                }
                startPagePoint = pagePoint
                editingStartPage = page
            }
        case .end:
            if let page = page(for: viewPoint, nearest: true) {
                var pagePoint = convert(viewPoint, to: page)
                // In Word mode, snap to word boundary when possible
                if appState?.selectionMode == .word,
                   let wordSel = page.selectionForWord(at: pagePoint) {
                    let wordBounds = wordSel.bounds(for: page)
                    pagePoint = CGPoint(x: wordBounds.maxX, y: wordBounds.midY)
                }
                endPagePoint = pagePoint
                editingEndPage = page
            }
        case .none: break
        }

        rebuildAnnotations()
        repositionHandles()
    }

    override func mouseUp(with event: NSEvent) {
        // Word-mode: only show toolbar if an actual drag occurred
        if wordSelectionActive {
            let didDrag = wordSelectionDidDrag
            wordSelectionActive = false
            wordSelectionDidDrag = false
            wordSelectionStartPage = nil

            if didDrag {
                let viewPoint = convert(event.locationInWindow, from: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self,
                          let selection = self.currentSelection,
                          let text = selection.string,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    self.showSelectionToolbar(at: viewPoint)
                }
            } else {
                currentSelection = nil
            }
            return
        }

        if dragging != .none {
            dragging = .none

            guard let startPage = editingStartPage, let endPage = editingEndPage else { return }

            let startAnnotations = editingAnnotations.filter { $0.page == startPage }
                .sorted { $0.bounds.midY > $1.bounds.midY }
            let endAnnotations = editingAnnotations.filter { $0.page == endPage }
                .sorted { $0.bounds.midY > $1.bounds.midY }

            if let first = startAnnotations.first {
                startPagePoint = CGPoint(x: first.bounds.minX, y: first.bounds.midY)
            }
            if let last = endAnnotations.last {
                endPagePoint = CGPoint(x: last.bounds.maxX, y: last.bounds.midY)
            }
            repositionHandles()
            appState?.highlightManager.refreshHighlights()
            return
        }

        super.mouseUp(with: event)

        let viewPoint = convert(event.locationInWindow, from: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self,
                  let selection = self.currentSelection,
                  let text = selection.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            self.showSelectionToolbar(at: viewPoint)
        }
    }
}
