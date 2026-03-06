import Cocoa
import PDFKit

class HighlightablePDFView: PDFView {
    weak var appState: AppState?

    // MARK: - Constants

    private enum Layout {
        static let handleWidth: CGFloat = 26
        static let circleSize: CGFloat = 16
        static let stickWidth: CGFloat = 3.0
        static let handleHitRadius: CGFloat = 24
        static let circleRadius: CGFloat = 8
        static let toolbarMargin: CGFloat = 8
        static let toolbarEdgePadding: CGFloat = 4
    }

    // Editing state
    private(set) var editingAnnotations: [PDFAnnotation] = []
    private(set) var editingStartPage: PDFPage?
    private(set) var editingEndPage: PDFPage?
    private var editingColor: NSColor?
    private var editingGroupID: String?
    private var startPagePoint: CGPoint = .zero
    private var endPagePoint: CGPoint = .zero
    private var dragging: DragTarget = .none

    // Handle views
    private let startHandle = HandleDotView(isStart: true)
    private let endHandle = HandleDotView(isStart: false)

    // Selection toolbar
    private lazy var selectionToolbar: SelectionToolbar = {
        let toolbar = SelectionToolbar(frame: .zero)
        toolbar.pdfView = self
        toolbar.isHidden = true
        return toolbar
    }()

    private var highlightUnderSelection: (annotations: [PDFAnnotation], startPage: PDFPage, endPage: PDFPage)?

    var isEditing: Bool { editingStartPage != nil }

    private enum DragTarget {
        case none, start, end
    }

    // MARK: - Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        startHandle.isHidden = true
        endHandle.isHidden = true
        addSubview(startHandle)
        addSubview(endHandle)
        addSubview(selectionToolbar)

        NotificationCenter.default.addObserver(
            self, selector: #selector(viewportChanged),
            name: .PDFViewScaleChanged, object: self
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(selectionChanged),
            name: .PDFViewSelectionChanged, object: self
        )

        DispatchQueue.main.async { [weak self] in
            self?.setupScrollObserver()
        }
    }

    private func setupScrollObserver() {
        guard let scrollView = findInternalScrollView() else { return }
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(viewportChanged),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )

    }

    private func findInternalScrollView() -> NSScrollView? {
        func search(_ view: NSView) -> NSScrollView? {
            if let sv = view as? NSScrollView { return sv }
            for sub in view.subviews {
                if let found = search(sub) { return found }
            }
            return nil
        }
        return search(self)
    }

    @objc private func viewportChanged() {
        if isEditing { repositionHandles() }
        if !selectionToolbar.isHidden { hideSelectionToolbar() }
    }

    @objc private func selectionChanged() {
        if !selectionToolbar.isHidden {
            hideSelectionToolbar()
        }
    }

    // MARK: - Selection toolbar

    private func showSelectionToolbar(at viewPoint: CGPoint) {
        guard let selection = currentSelection,
              !selection.string.isNilOrEmpty else {
            hideSelectionToolbar()
            return
        }

        highlightUnderSelection = highlightGroupAtPoint(viewPoint)
        selectionToolbar.showForExistingHighlight(highlightUnderSelection != nil)
        selectionToolbar.setFrameSize(selectionToolbar.fittingSize)

        let toolbarW = selectionToolbar.frame.width
        let toolbarH = selectionToolbar.frame.height

        var x = viewPoint.x - toolbarW / 2
        var y = viewPoint.y + Layout.toolbarMargin

        x = max(Layout.toolbarEdgePadding, min(x, bounds.width - toolbarW - Layout.toolbarEdgePadding))

        if y + toolbarH > bounds.height {
            y = viewPoint.y - toolbarH - Layout.toolbarMargin
        }

        selectionToolbar.frame.origin = CGPoint(x: x, y: y)
        selectionToolbar.isHidden = false
    }

    func hideSelectionToolbar() {
        selectionToolbar.isHidden = true
        highlightUnderSelection = nil
    }

    func copySelectionToPasteboard() {
        guard let text = currentSelection?.string else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        clearSelection()
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
        appState?.refreshHighlights()
    }

    func deleteHighlightUnderSelection() {
        guard let group = highlightUnderSelection else { return }
        for annotation in group.annotations {
            annotation.page?.removeAnnotation(annotation)
        }
        clearSelection()
        stopEditing()
        appState?.refreshHighlights()
    }

    // MARK: - Editing lifecycle

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

    private func repositionHandles() {
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

    // MARK: - Mouse events

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
                appState?.refreshHighlights()
            }
        } else {
            if let group = highlightGroupAtPoint(viewPoint) {
                switchToGroup(group)
                return
            }
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging != .none else {
            super.mouseDragged(with: event)
            return
        }

        let viewPoint = convert(event.locationInWindow, from: nil)

        switch dragging {
        case .start:
            if let page = page(for: viewPoint, nearest: true) {
                startPagePoint = convert(viewPoint, to: page)
                editingStartPage = page
            }
        case .end:
            if let page = page(for: viewPoint, nearest: true) {
                endPagePoint = convert(viewPoint, to: page)
                editingEndPage = page
            }
        case .none: break
        }

        rebuildAnnotations()
        repositionHandles()
    }

    override func mouseUp(with event: NSEvent) {
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
            appState?.refreshHighlights()
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

    // MARK: - Annotation rebuilding

    private func rebuildAnnotations() {
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

    // MARK: - Hit testing

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

    private func switchToGroup(_ group: (annotations: [PDFAnnotation], startPage: PDFPage, endPage: PDFPage)) {
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

        // Show toolbar for existing highlight
        highlightUnderSelection = group
        selectionToolbar.showForExistingHighlight(true)
        selectionToolbar.setFrameSize(selectionToolbar.fittingSize)

        let endPt = CGPoint(x: endHandle.frame.midX, y: endHandle.frame.minY)
        let toolbarW = selectionToolbar.frame.width
        let toolbarH = selectionToolbar.frame.height
        var x = endPt.x - toolbarW / 2
        let y: CGFloat
        x = max(Layout.toolbarEdgePadding, min(x, bounds.width - toolbarW - Layout.toolbarEdgePadding))

        let proposedY = endPt.y - toolbarH - Layout.toolbarMargin
        y = proposedY < Layout.toolbarEdgePadding ? endHandle.frame.maxY + Layout.toolbarMargin : proposedY

        selectionToolbar.frame.origin = CGPoint(x: x, y: y)
        selectionToolbar.isHidden = false
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// MARK: - Optional string helper

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        switch self {
        case .none: return true
        case .some(let str): return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - Handle view (teardrop-style)

class HandleDotView: NSView {
    private let isStart: Bool

    private enum Layout {
        static let circleSize: CGFloat = 16
        static let stickWidth: CGFloat = 3.0
        static let stickOverlap: CGFloat = 3.0
    }

    init(isStart: Bool) {
        self.isStart = isStart
        super.init(frame: .zero)
        wantsLayer = true
        layer?.zPosition = 1000
    }

    required init?(coder: NSCoder) {
        self.isStart = true
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let color = NSColor.systemBlue

        if isStart {
            let circleRect = CGRect(
                x: (bounds.width - Layout.circleSize) / 2,
                y: bounds.height - Layout.circleSize,
                width: Layout.circleSize, height: Layout.circleSize
            )
            let stickRect = CGRect(
                x: (bounds.width - Layout.stickWidth) / 2,
                y: 0,
                width: Layout.stickWidth,
                height: bounds.height - Layout.circleSize + Layout.stickOverlap
            )
            color.setFill()
            NSBezierPath(rect: stickRect).fill()
            NSBezierPath(ovalIn: circleRect).fill()
        } else {
            let circleRect = CGRect(
                x: (bounds.width - Layout.circleSize) / 2,
                y: 0,
                width: Layout.circleSize, height: Layout.circleSize
            )
            let stickRect = CGRect(
                x: (bounds.width - Layout.stickWidth) / 2,
                y: Layout.circleSize - Layout.stickOverlap,
                width: Layout.stickWidth,
                height: bounds.height - Layout.circleSize + Layout.stickOverlap
            )
            color.setFill()
            NSBezierPath(rect: stickRect).fill()
            NSBezierPath(ovalIn: circleRect).fill()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
