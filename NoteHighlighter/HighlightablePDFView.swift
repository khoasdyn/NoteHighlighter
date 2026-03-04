import Cocoa
import PDFKit

class HighlightablePDFView: PDFView {
    weak var appState: AppState?
    
    // Editing state
    private(set) var editingAnnotations: [PDFAnnotation] = []
    private(set) var editingPage: PDFPage?
    private var startPagePoint: CGPoint = .zero
    private var endPagePoint: CGPoint = .zero
    private var dragging: DragTarget = .none
    
    // Handle views
    private let startHandle = HandleDotView(isStart: true)
    private let endHandle = HandleDotView(isStart: false)
    
    var isEditing: Bool { editingPage != nil }
    
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
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(viewportChanged),
            name: .PDFViewScaleChanged, object: self
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
    }
    
    // MARK: - Editing lifecycle
    
    func startEditing(highlight: Highlight) {
        guard let document = self.document,
              let page = document.page(at: highlight.pageIndex) else { return }
        
        editingAnnotations = page.annotations.filter { annotation in
            guard annotation.type == "Highlight" || annotation.markupType == .highlight else { return false }
            guard HighlightColor.from(nsColor: annotation.color) == highlight.color else { return false }
            return highlight.bounds.contains(annotation.bounds) || annotation.bounds.intersects(highlight.bounds)
        }
        
        guard !editingAnnotations.isEmpty else { return }
        editingPage = page
        
        let sorted = editingAnnotations.sorted { $0.bounds.midY > $1.bounds.midY }
        
        // Start = left edge of topmost line, end = right edge of bottommost line
        startPagePoint = CGPoint(x: sorted.first!.bounds.minX, y: sorted.first!.bounds.midY)
        endPagePoint = CGPoint(x: sorted.last!.bounds.maxX, y: sorted.last!.bounds.midY)
        
        startHandle.isHidden = false
        endHandle.isHidden = false
        repositionHandles()
    }
    
    func stopEditing() {
        editingAnnotations = []
        editingPage = nil
        dragging = .none
        startHandle.isHidden = true
        endHandle.isHidden = true
    }
    
    private func repositionHandles() {
        guard let page = editingPage else { return }
        
        let sorted = editingAnnotations.sorted { $0.bounds.midY > $1.bounds.midY }
        guard let topAnnotation = sorted.first, let bottomAnnotation = sorted.last else { return }
        
        // Start handle: left of top line, positioned at top edge
        let startPt = convert(
            CGPoint(x: topAnnotation.bounds.minX, y: topAnnotation.bounds.maxY),
            from: page
        )
        // End handle: right of bottom line, positioned at bottom edge
        let endPt = convert(
            CGPoint(x: bottomAnnotation.bounds.maxX, y: bottomAnnotation.bounds.minY),
            from: page
        )
        
        let handleW: CGFloat = 20
        let handleH: CGFloat = 32
        
        // Start handle sits above the start point
        startHandle.frame = CGRect(
            x: startPt.x - handleW / 2,
            y: startPt.y,
            width: handleW, height: handleH
        )
        // End handle hangs below the end point
        endHandle.frame = CGRect(
            x: endPt.x - handleW / 2,
            y: endPt.y - handleH,
            width: handleW, height: handleH
        )
    }
    
    // MARK: - Mouse events
    
    override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        
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
        guard dragging != .none, let page = editingPage else {
            super.mouseDragged(with: event)
            return
        }
        
        let viewPoint = convert(event.locationInWindow, from: nil)
        let pagePoint = convert(viewPoint, to: page)
        
        switch dragging {
        case .start: startPagePoint = pagePoint
        case .end:   endPagePoint = pagePoint
        case .none:  break
        }
        
        rebuildAnnotations()
        repositionHandles()
    }
    
    override func mouseUp(with event: NSEvent) {
        guard dragging != .none else {
            super.mouseUp(with: event)
            return
        }
        
        dragging = .none
        
        // Snap handles to actual annotation edges
        let sorted = editingAnnotations.sorted { $0.bounds.midY > $1.bounds.midY }
        if let first = sorted.first {
            startPagePoint = CGPoint(x: first.bounds.minX, y: first.bounds.midY)
        }
        if let last = sorted.last {
            endPagePoint = CGPoint(x: last.bounds.maxX, y: last.bounds.midY)
        }
        repositionHandles()
        
        appState?.refreshHighlights()
    }
    
    // MARK: - Annotation rebuilding
    
    private func rebuildAnnotations() {
        guard let page = editingPage,
              let selection = page.selection(from: startPagePoint, to: endPagePoint) else { return }
        
        let color = editingAnnotations.first?.color ?? NSColor.yellow
        let groupID = editingAnnotations.first?.userName
        
        for annotation in editingAnnotations {
            page.removeAnnotation(annotation)
        }
        
        var newAnnotations: [PDFAnnotation] = []
        for lineSelection in selection.selectionsByLine() {
            let bounds = lineSelection.bounds(for: page)
            guard bounds.width > 0 && bounds.height > 0 else { continue }
            
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = color
            annotation.userName = groupID
            page.addAnnotation(annotation)
            newAnnotations.append(annotation)
        }
        
        editingAnnotations = newAnnotations
    }
    
    // MARK: - Hit testing
    
    private func highlightGroupAtPoint(_ viewPoint: CGPoint) -> (page: PDFPage, annotations: [PDFAnnotation])? {
        guard let page = page(for: viewPoint, nearest: false) else { return nil }
        let pagePoint = convert(viewPoint, to: page)
        
        guard let hit = page.annotations.first(where: { annotation in
            (annotation.type == "Highlight" || annotation.markupType == .highlight) &&
            annotation.bounds.contains(pagePoint)
        }) else { return nil }
        
        let group = findConnectedGroup(containing: hit, on: page)
        return (page, group)
    }
    
    private func findConnectedGroup(containing target: PDFAnnotation, on page: PDFPage) -> [PDFAnnotation] {
        let targetColor = HighlightColor.from(nsColor: target.color)
        let targetGroupID = target.userName
        
        // If the target has a groupID, just find all annotations with the same groupID
        if let groupID = targetGroupID, !groupID.isEmpty {
            let group = page.annotations.filter { a in
                (a.type == "Highlight" || a.markupType == .highlight) &&
                a.userName == groupID
            }
            return group.sorted { $0.bounds.midY > $1.bounds.midY }
        }
        
        // Fallback for imported PDFs without groupID: proximity-based merging
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
    
    private func switchToGroup(_ group: (page: PDFPage, annotations: [PDFAnnotation])) {
        editingAnnotations = group.annotations
        editingPage = group.page
        
        let sorted = group.annotations.sorted { $0.bounds.midY > $1.bounds.midY }
        startPagePoint = CGPoint(x: sorted.first!.bounds.minX, y: sorted.first!.bounds.midY)
        endPagePoint = CGPoint(x: sorted.last!.bounds.maxX, y: sorted.last!.bounds.midY)
        
        startHandle.isHidden = false
        endHandle.isHidden = false
        repositionHandles()
    }
    
    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// MARK: - Handle view (teardrop-style, like iOS text selection)

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
            // Circle at top, stick going down
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
            // Stick going up, circle at bottom
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
