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

    // MARK: - Utilities

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}
