import Cocoa
import PDFKit

class HighlightablePDFView: PDFView {
    weak var appState: AppState?
    
    // Editing state
    private(set) var editingAnnotations: [PDFAnnotation] = []
    private(set) var editingStartPage: PDFPage?
    private(set) var editingEndPage: PDFPage?
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
    
    // Track if there's a highlight under the current selection point
    private var highlightUnderSelection: (annotations: [PDFAnnotation], startPage: PDFPage, endPage: PDFPage)?
    
    var isEditing: Bool { editingStartPage != nil }
    
    enum DragTarget {
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
        // Hide toolbar when selection changes (user is still dragging)
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
        
        // Check if there's an existing highlight under the selection
        highlightUnderSelection = highlightGroupAtPoint(viewPoint)
        selectionToolbar.showForExistingHighlight(highlightUnderSelection != nil)
        
        // Size to fit
        selectionToolbar.setFrameSize(selectionToolbar.fittingSize)
        
        // Position above the selection end point
        let toolbarW = selectionToolbar.frame.width
        let toolbarH = selectionToolbar.frame.height
        let margin: CGFloat = 8
        
        var x = viewPoint.x - toolbarW / 2
        var y = viewPoint.y + margin
        
        // Keep within view bounds
        x = max(4, min(x, bounds.width - toolbarW - 4))
        
        // If would go above the view, show below instead
        if y + toolbarH > bounds.height {
            y = viewPoint.y - toolbarH - margin
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
        guard let document = self.document else { return }
        
        editingAnnotations = []
        for pageIndex in highlight.pageIndex...highlight.endPageIndex {
            guard let page = document.page(at: pageIndex) else { continue }
            let matching = page.annotations.filter { annotation in
                guard annotation.type == "Highlight" || annotation.markupType == .highlight else { return false }
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
        
        editingStartPage = sorted.first!.0
        editingEndPage = sorted.last!.0
        
        let firstAnnotation = sorted.first!.1
        startPagePoint = CGPoint(x: firstAnnotation.bounds.minX, y: firstAnnotation.bounds.midY)
        
        let lastAnnotation = sorted.last!.1
        endPagePoint = CGPoint(x: lastAnnotation.bounds.maxX, y: lastAnnotation.bounds.midY)
        
        startHandle.isHidden = false
        endHandle.isHidden = false
        repositionHandles()
    }
    
    func stopEditing() {
        editingAnnotations = []
        editingStartPage = nil
        editingEndPage = nil
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
        
        let startPt = convert(
            CGPoint(x: topAnnotation.bounds.minX, y: topAnnotation.bounds.maxY),
            from: startPage
        )
        let endPt = convert(
            CGPoint(x: bottomAnnotation.bounds.maxX, y: bottomAnnotation.bounds.minY),
            from: endPage
        )
        
        let handleW: CGFloat = 20
        let handleH: CGFloat = 32
        
        startHandle.frame = CGRect(
            x: startPt.x - handleW / 2,
            y: startPt.y,
            width: handleW, height: handleH
        )
        endHandle.frame = CGRect(
            x: endPt.x - handleW / 2,
            y: endPt.y - handleH,
            width: handleW, height: handleH
        )
    }
    
    // MARK: - Mouse events
    
    override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        
        // If clicking on the toolbar, let it handle it
        let toolbarPoint = selectionToolbar.convert(event.locationInWindow, from: nil)
        if !selectionToolbar.isHidden && selectionToolbar.bounds.contains(toolbarPoint) {
            return
        }
        
        hideSelectionToolbar()
        
        if isEditing {
            let hitRadius: CGFloat = 20
            let startCenter = CGPoint(x: startHandle.frame.midX, y: startHandle.frame.midY)
            let endCenter = CGPoint(x: endHandle.frame.midX, y: endHandle.frame.midY)
            
            if dist(viewPoint, startCenter) < hitRadius {
                dragging = .start
                return
            } else if dist(viewPoint, endCenter) < hitRadius {
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
        
        // After mouse up, check if there's a text selection to show toolbar
        let viewPoint = convert(event.locationInWindow, from: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self,
                  let selection = self.currentSelection,
                  let text = selection.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            
            self.showSelectionToolbar(at: viewPoint)
        }
    }
    
    // MARK: - Annotation rebuilding
    
    private func rebuildAnnotations() {
        guard let document = self.document,
              let startPage = editingStartPage,
              let endPage = editingEndPage else { return }
        
        let color = editingAnnotations.first?.color ?? NSColor.yellow
        let groupID = editingAnnotations.first?.userName
        
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
        guard let page = page(for: viewPoint, nearest: false) else { return nil }
        let pagePoint = convert(viewPoint, to: page)
        
        guard let hit = page.annotations.first(where: { annotation in
            (annotation.type == "Highlight" || annotation.markupType == .highlight) &&
            annotation.bounds.contains(pagePoint)
        }) else { return nil }
        
        let group = findConnectedGroup(containing: hit)
        guard !group.isEmpty else { return nil }
        
        let pages = group.compactMap { $0.page }
        guard let startPage = pages.min(by: { document!.index(for: $0) < document!.index(for: $1) }),
              let endPage = pages.max(by: { document!.index(for: $0) < document!.index(for: $1) }) else { return nil }
        
        return (group, startPage, endPage)
    }
    
    private func findConnectedGroup(containing target: PDFAnnotation) -> [PDFAnnotation] {
        guard let document = self.document else { return [target] }
        let targetGroupID = target.userName
        
        if let groupID = targetGroupID, !groupID.isEmpty {
            var group: [PDFAnnotation] = []
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                let matching = page.annotations.filter { a in
                    (a.type == "Highlight" || a.markupType == .highlight) &&
                    a.userName == groupID
                }
                group.append(contentsOf: matching)
            }
            return group.sorted { a, b in
                let aIdx = document.index(for: a.page!)
                let bIdx = document.index(for: b.page!)
                if aIdx != bIdx { return aIdx < bIdx }
                return a.bounds.midY > b.bounds.midY
            }
        }
        
        guard let page = target.page else { return [target] }
        let targetColor = HighlightColor.from(nsColor: target.color)
        
        let candidates = page.annotations.filter { a in
            (a.type == "Highlight" || a.markupType == .highlight) &&
            HighlightColor.from(nsColor: a.color) == targetColor &&
            (a.userName == nil || a.userName?.isEmpty == true)
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
        
        startHandle.isHidden = false
        endHandle.isHidden = false
        repositionHandles()
        
        // Show toolbar for existing highlight
        highlightUnderSelection = group
        selectionToolbar.showForExistingHighlight(true)
        selectionToolbar.setFrameSize(selectionToolbar.fittingSize)
        
        // Position toolbar near the end handle
        let endPt = CGPoint(x: endHandle.frame.midX, y: endHandle.frame.minY)
        let toolbarW = selectionToolbar.frame.width
        let toolbarH = selectionToolbar.frame.height
        var x = endPt.x - toolbarW / 2
        var y = endPt.y - toolbarH - 8
        x = max(4, min(x, bounds.width - toolbarW - 4))
        if y < 4 { y = endHandle.frame.maxY + 8 }
        selectionToolbar.frame.origin = CGPoint(x: x, y: y)
        selectionToolbar.isHidden = false
    }
    
    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
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
    let isStart: Bool
    
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
        let circleSize: CGFloat = 12
        let stickWidth: CGFloat = 2.5
        
        if isStart {
            let circleRect = CGRect(
                x: (bounds.width - circleSize) / 2,
                y: bounds.height - circleSize,
                width: circleSize, height: circleSize
            )
            let stickRect = CGRect(
                x: (bounds.width - stickWidth) / 2,
                y: 0,
                width: stickWidth,
                height: bounds.height - circleSize + 2
            )
            color.setFill()
            NSBezierPath(rect: stickRect).fill()
            NSBezierPath(ovalIn: circleRect).fill()
        } else {
            let circleRect = CGRect(
                x: (bounds.width - circleSize) / 2,
                y: 0,
                width: circleSize, height: circleSize
            )
            let stickRect = CGRect(
                x: (bounds.width - stickWidth) / 2,
                y: circleSize - 2,
                width: stickWidth,
                height: bounds.height - circleSize + 2
            )
            color.setFill()
            NSBezierPath(rect: stickRect).fill()
            NSBezierPath(ovalIn: circleRect).fill()
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
