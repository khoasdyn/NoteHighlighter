import Cocoa

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
