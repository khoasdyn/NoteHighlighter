import Cocoa
import PDFKit

// MARK: - Editing lifecycle

extension HighlightablePDFView {

    func startEditing(highlight: Highlight) {
        guard let document else { return }

        editingAnnotations = []
        for pageIndex in highlight.pageIndex...highlight.endPageIndex {
            guard let page = document.page(at: pageIndex) else { continue }
            let matching = page.annotations.filter { annotation in
                guard annotation.isHighlightAnnotation else { return false }
                guard HighlightColor.from(nsColor: annotation.color) == highlight.color else { return false }
                if let groupID = highlight.groupID, !groupID.isEmpty {
                    return annotation.userName == groupID
                }
                return highlight.bounds.contains(annotation.bounds) || annotation.bounds.intersects(annotation.bounds)
            }
            editingAnnotations.append(contentsOf: matching)
        }

        guard !editingAnnotations.isEmpty else { return }

        let pageAnnotationPairs = editingAnnotations.compactMap { annotation -> (PDFPage, PDFAnnotation)? in
            guard let page = annotation.page else { return nil }
            return (page, annotation)
        }
        guard !pageAnnotationPairs.isEmpty else { return }

        let sorted = pageAnnotationPairs.sorted { a, b in
            let aIdx = document.index(for: a.0)
            let bIdx = document.index(for: b.0)
            if aIdx != bIdx { return aIdx < bIdx }
            return a.1.bounds.midY > b.1.bounds.midY
        }

        guard let first = sorted.first, let last = sorted.last else { return }

        editingStartPage = first.0
        editingEndPage = last.0
        editingColor = editingAnnotations.first?.color
        editingGroupID = editingAnnotations.first?.userName

        startPagePoint = CGPoint(x: first.1.bounds.minX, y: first.1.bounds.midY)
        endPagePoint = CGPoint(x: last.1.bounds.maxX, y: last.1.bounds.midY)

        startHandle.isHidden = false
        endHandle.isHidden = false
        repositionHandles()
    }

    func stopEditing() {
        editingAnnotations = []
        editingStartPage = nil
        editingEndPage = nil
        editingColor = nil
        editingGroupID = nil
        dragging = .none
        startHandle.isHidden = true
        endHandle.isHidden = true
    }

    func repositionHandles() {
        guard let startPage = editingStartPage, let endPage = editingEndPage else { return }

        let startAnnotations = editingAnnotations.filter { $0.page == startPage }
            .sorted { $0.bounds.midY > $1.bounds.midY }
        let endAnnotations = editingAnnotations.filter { $0.page == endPage }
            .sorted { $0.bounds.midY > $1.bounds.midY }

        guard let topAnnotation = startAnnotations.first,
              let bottomAnnotation = endAnnotations.last else { return }

        let startTop = convert(CGPoint(x: topAnnotation.bounds.minX, y: topAnnotation.bounds.maxY), from: startPage)
        let startBottom = convert(CGPoint(x: topAnnotation.bounds.minX, y: topAnnotation.bounds.minY), from: startPage)
        let endTop = convert(CGPoint(x: bottomAnnotation.bounds.maxX, y: bottomAnnotation.bounds.maxY), from: endPage)
        let endBottom = convert(CGPoint(x: bottomAnnotation.bounds.maxX, y: bottomAnnotation.bounds.minY), from: endPage)

        let startLineH = abs(startTop.y - startBottom.y)
        let endLineH = abs(endTop.y - endBottom.y)

        let startHandleH = startLineH + Layout.circleSize
        let endHandleH = endLineH + Layout.circleSize

        let startMinY = min(startTop.y, startBottom.y)
        let endMinY = min(endTop.y, endBottom.y)

        startHandle.frame = CGRect(
            x: startTop.x - Layout.handleWidth / 2,
            y: startMinY,
            width: Layout.handleWidth, height: startHandleH
        )
        endHandle.frame = CGRect(
            x: endBottom.x - Layout.handleWidth / 2,
            y: endMinY - Layout.circleSize,
            width: Layout.handleWidth, height: endHandleH
        )
    }

    func changeEditingHighlightColor(_ highlightColor: HighlightColor) {
        guard !editingAnnotations.isEmpty else { return }

        let newColor = highlightColor.nsColor
        editingColor = newColor
        for annotation in editingAnnotations {
            annotation.color = newColor
        }

        // Force redraw by re-adding annotations
        for annotation in editingAnnotations {
            if let page = annotation.page {
                page.removeAnnotation(annotation)
                page.addAnnotation(annotation)
            }
        }

        stopEditing()
        appState?.highlightManager.refreshHighlights()
    }

    func deleteHighlightUnderSelection() {
        guard let group = highlightUnderSelection else { return }
        for annotation in group.annotations {
            annotation.page?.removeAnnotation(annotation)
        }
        clearSelection()
        stopEditing()
        appState?.highlightManager.refreshHighlights()
    }

    // MARK: - Annotation rebuilding

    func rebuildAnnotations() {
        guard let document,
              let startPage = editingStartPage,
              let endPage = editingEndPage else { return }

        let color = editingColor ?? editingAnnotations.first?.color ?? HighlightColor.yellow.nsColor
        let groupID = editingGroupID ?? editingAnnotations.first?.userName

        for annotation in editingAnnotations {
            annotation.page?.removeAnnotation(annotation)
        }

        guard let selection = document.selection(from: startPage, at: startPagePoint,
                                                  to: endPage, at: endPagePoint) else {
            editingAnnotations = []
            return
        }

        var newAnnotations: [PDFAnnotation] = []
        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 0 && bounds.height > 0 else { continue }

                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = color
                annotation.userName = groupID
                page.addAnnotation(annotation)
                newAnnotations.append(annotation)
            }
        }

        editingAnnotations = newAnnotations
    }
}
