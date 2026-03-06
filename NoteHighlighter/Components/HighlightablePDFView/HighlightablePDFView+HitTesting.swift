import Cocoa
import PDFKit

// MARK: - Hit testing and group finding

extension HighlightablePDFView {

    func highlightGroupAtPoint(_ viewPoint: CGPoint) -> (annotations: [PDFAnnotation], startPage: PDFPage, endPage: PDFPage)? {
        guard let document,
              let page = page(for: viewPoint, nearest: false) else { return nil }
        let pagePoint = convert(viewPoint, to: page)

        guard let hit = page.annotations.first(where: {
            $0.isHighlightAnnotation && $0.bounds.contains(pagePoint)
        }) else { return nil }

        let group = findConnectedGroup(containing: hit)
        guard !group.isEmpty else { return nil }

        let pages = group.compactMap(\.page)
        guard let startPage = pages.min(by: { document.index(for: $0) < document.index(for: $1) }),
              let endPage = pages.max(by: { document.index(for: $0) < document.index(for: $1) }) else { return nil }

        return (group, startPage, endPage)
    }

    func switchToGroup(_ group: (annotations: [PDFAnnotation], startPage: PDFPage, endPage: PDFPage)) {
        editingAnnotations = group.annotations
        editingStartPage = group.startPage
        editingEndPage = group.endPage

        let startAnnotations = group.annotations.filter { $0.page == group.startPage }
            .sorted { $0.bounds.midY > $1.bounds.midY }
        let endAnnotations = group.annotations.filter { $0.page == group.endPage }
            .sorted { $0.bounds.midY > $1.bounds.midY }

        if let first = startAnnotations.first {
            startPagePoint = CGPoint(x: first.bounds.minX, y: first.bounds.midY)
        }
        if let last = endAnnotations.last {
            endPagePoint = CGPoint(x: last.bounds.maxX, y: last.bounds.midY)
        }

        editingColor = group.annotations.first?.color
        editingGroupID = group.annotations.first?.userName

        startHandle.isHidden = false
        endHandle.isHidden = false
        repositionHandles()

        // Show toolbar for existing highlight — anchor to start handle (top of highlight)
        highlightUnderSelection = group
        selectionToolbar.showForExistingHighlight(true)
        selectionToolbar.setFrameSize(selectionToolbar.fittingSize)

        let startPt = CGPoint(x: startHandle.frame.midX, y: startHandle.frame.maxY)
        let toolbarW = selectionToolbar.frame.width
        let toolbarH = selectionToolbar.frame.height
        var x = startPt.x - toolbarW / 2
        let y: CGFloat
        x = max(Layout.toolbarEdgePadding, min(x, bounds.width - toolbarW - Layout.toolbarEdgePadding))

        let proposedY = startPt.y + Layout.toolbarMargin
        y = proposedY + toolbarH > bounds.height ? startHandle.frame.minY - toolbarH - Layout.toolbarMargin : proposedY

        selectionToolbar.frame.origin = CGPoint(x: x, y: y)
        selectionToolbar.isHidden = false
    }

    // MARK: - Group discovery

    private func findConnectedGroup(containing target: PDFAnnotation) -> [PDFAnnotation] {
        guard let document else { return [target] }
        let targetGroupID = target.userName

        if let groupID = targetGroupID, !groupID.isEmpty {
            var group: [PDFAnnotation] = []
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                let matching = page.annotations.filter {
                    $0.isHighlightAnnotation && $0.userName == groupID
                }
                group.append(contentsOf: matching)
            }
            return group.sorted { a, b in
                guard let aPage = a.page, let bPage = b.page else { return false }
                let aIdx = document.index(for: aPage)
                let bIdx = document.index(for: bPage)
                if aIdx != bIdx { return aIdx < bIdx }
                return a.bounds.midY > b.bounds.midY
            }
        }

        guard let page = target.page else { return [target] }
        let targetColor = HighlightColor.from(nsColor: target.color)

        let candidates = page.annotations.filter {
            $0.isHighlightAnnotation &&
            HighlightColor.from(nsColor: $0.color) == targetColor &&
            ($0.userName == nil || $0.userName?.isEmpty == true)
        }

        var group: Set<ObjectIdentifier> = [ObjectIdentifier(target)]
        var groupAnnotations: [PDFAnnotation] = [target]
        var changed = true

        while changed {
            changed = false
            for candidate in candidates where !group.contains(ObjectIdentifier(candidate)) {
                for member in groupAnnotations {
                    if areVerticallyAdjacent(member.bounds, candidate.bounds) {
                        group.insert(ObjectIdentifier(candidate))
                        groupAnnotations.append(candidate)
                        changed = true
                        break
                    }
                }
            }
        }

        return groupAnnotations.sorted { $0.bounds.midY > $1.bounds.midY }
    }

    private func areVerticallyAdjacent(_ a: CGRect, _ b: CGRect) -> Bool {
        if a.intersects(b) { return true }
        let gap = min(abs(a.minY - b.maxY), abs(b.minY - a.maxY))
        let lineHeight = max(a.height, b.height)
        return gap < lineHeight * 1.5
    }
}
