import Cocoa
import PDFKit

class HighlightablePDFView: PDFView {
    weak var appState: AppState?

    // MARK: - Constants

    enum Layout {
        static let handleWidth: CGFloat = 26
        static let circleSize: CGFloat = 16
        static let stickWidth: CGFloat = 3.0
        static let handleHitRadius: CGFloat = 24
        static let circleRadius: CGFloat = 8
        static let toolbarMargin: CGFloat = 8
        static let toolbarEdgePadding: CGFloat = 4
    }

    // MARK: - Editing state

    var editingAnnotations: [PDFAnnotation] = []
    var editingStartPage: PDFPage?
    var editingEndPage: PDFPage?
    var editingColor: NSColor?
    var editingGroupID: String?
    var startPagePoint: CGPoint = .zero
    var endPagePoint: CGPoint = .zero
    var dragging: DragTarget = .none

    enum DragTarget {
        case none, start, end
    }

    // MARK: - Handle views

    let startHandle = HandleDotView(isStart: true)
    let endHandle = HandleDotView(isStart: false)

    // MARK: - Selection toolbar

    lazy var selectionToolbar: SelectionToolbar = {
        let toolbar = SelectionToolbar(frame: .zero)
        toolbar.pdfView = self
        toolbar.isHidden = true
        return toolbar
    }()

    var highlightUnderSelection: (annotations: [PDFAnnotation], startPage: PDFPage, endPage: PDFPage)?

    var isEditing: Bool { editingStartPage != nil }

    // MARK: - Word-mode selection state

    var wordSelectionActive = false
    var wordSelectionDidDrag = false
    var wordSelectionStartPage: PDFPage?
    var wordSelectionStartPoint: CGPoint = .zero
    /// View-coordinate origin of the click, used for minimum-drag-distance check
    var wordSelectionStartViewPoint: CGPoint = .zero
    /// Minimum drag distance (in view points) before treating movement as intentional drag
    static let wordDragThreshold: CGFloat = 4.0

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

    // MARK: - Snap edge

    enum SnapEdge {
        case leading, trailing
    }

    // MARK: - Utilities

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }

    /// Attempt word-level snap in Word Mode. If the cursor is near text, snaps to the
    /// word boundary. If the cursor is outside text but on the same vertical band as a
    /// text line, snaps to that line's edge. Returns nil if completely outside text.
    func wordSnappedPoint(on page: PDFPage, at point: CGPoint, edge: SnapEdge) -> CGPoint? {
        // 1. Try word snap — accept if the word is close to the cursor
        if let wordSel = page.selectionForWord(at: point) {
            let wb = wordSel.bounds(for: page)
            let tolerance = max(wb.height, 20)
            if wb.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
                let x = edge == .leading ? wb.minX : wb.maxX
                return CGPoint(x: x, y: wb.midY)
            }
        }

        // 2. Word is too far — try snapping to the nearest line at the cursor's Y.
        //    Use a probe point at the horizontal center of the page's bounds to
        //    hit text content, then check the line's vertical overlap.
        let pageBounds = page.bounds(for: .cropBox)
        let probeX = pageBounds.midX
        let probePoint = CGPoint(x: probeX, y: point.y)
        if let lineSel = page.selectionForLine(at: probePoint) {
            let lb = lineSel.bounds(for: page)
            // Accept if the cursor's Y is within one line-height of the line
            let yTolerance = max(lb.height, 20)
            if point.y >= lb.minY - yTolerance && point.y <= lb.maxY + yTolerance {
                let x = edge == .leading ? lb.minX : lb.maxX
                return CGPoint(x: x, y: lb.midY)
            }
        }

        // 3. Completely outside text content — return nil to freeze
        return nil
    }
}
