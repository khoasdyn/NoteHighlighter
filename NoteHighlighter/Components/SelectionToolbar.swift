import Cocoa
import PDFKit

class SelectionToolbar: NSView {
    weak var pdfView: HighlightablePDFView?

    private var copyButton: NSButton!
    private var deleteButton: NSButton!
    private var deleteSeparator: NSView!

    private enum Style {
        static let cornerRadius: CGFloat = 8
        static let shadowOpacity: Float = 0.3
        static let shadowRadius: CGFloat = 8
        static let colorCircleSize: CGFloat = 22
        static let separatorHeight: CGFloat = 18
        static let fontSize: CGFloat = 12
        static let zPosition: CGFloat = 2000
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
        setFrameSize(fittingSize)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setFrameSize(fittingSize)
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.95).cgColor
        layer?.cornerRadius = Style.cornerRadius
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = Style.shadowOpacity
        layer?.shadowRadius = Style.shadowRadius
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.zPosition = Style.zPosition

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])

        copyButton = makeTextButton(title: "Copy", action: #selector(copyTapped))
        stack.addArrangedSubview(copyButton)
        stack.addArrangedSubview(makeSeparator())

        for (index, color) in HighlightColor.selectableColors.enumerated() {
            let btn = makeColorButton(color: color.opaqueColor, index: index)
            btn.toolTip = color.displayName
            stack.addArrangedSubview(btn)
        }

        deleteSeparator = makeSeparator()
        stack.addArrangedSubview(deleteSeparator)

        deleteButton = makeTextButton(title: "Delete", action: #selector(deleteTapped))
        deleteButton.contentTintColor = NSColor.systemRed
        let redTitle = NSMutableAttributedString(string: "Delete", attributes: [
            .foregroundColor: NSColor.systemRed,
            .font: NSFont.systemFont(ofSize: Style.fontSize, weight: .medium)
        ])
        deleteButton.attributedTitle = redTitle
        stack.addArrangedSubview(deleteButton)
    }

    private func makeColorButton(color: NSColor, index: Int) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = Style.colorCircleSize / 2
        container.layer?.backgroundColor = color.cgColor
        container.layer?.borderWidth = 1.5
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: Style.colorCircleSize),
            container.heightAnchor.constraint(equalToConstant: Style.colorCircleSize),
        ])

        let btn = NSButton(frame: .zero)
        btn.title = ""
        btn.isBordered = false
        btn.isTransparent = true
        btn.target = self
        btn.action = #selector(colorTapped(_:))
        btn.tag = index
        btn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            btn.topAnchor.constraint(equalTo: container.topAnchor),
            btn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func makeTextButton(title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: Style.fontSize, weight: .medium)
        let styledTitle = NSMutableAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: Style.fontSize, weight: .medium)
        ])
        btn.attributedTitle = styledTitle
        btn.sizeToFit()
        btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        btn.setContentHuggingPriority(.required, for: .horizontal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        let width = btn.fittingSize.width + 8
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(greaterThanOrEqualToConstant: width),
        ])
        return btn
    }

    private func makeSeparator() -> NSView {
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sep.widthAnchor.constraint(equalToConstant: 1),
            sep.heightAnchor.constraint(equalToConstant: Style.separatorHeight),
        ])
        return sep
    }

    func showForExistingHighlight(_ isExisting: Bool) {
        deleteButton.isHidden = !isExisting
        deleteSeparator.isHidden = !isExisting
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    // MARK: - Actions

    @objc private func copyTapped() {
        pdfView?.copySelectionToPasteboard()
        pdfView?.hideSelectionToolbar()
    }

    @objc private func colorTapped(_ sender: NSButton) {
        let selectedColor = HighlightColor.selectableColors[sender.tag]
        pdfView?.appState?.currentHighlightColor = selectedColor

        if pdfView?.isEditing == true {
            pdfView?.changeEditingHighlightColor(selectedColor)
        } else {
            pdfView?.appState?.addHighlightFromSelection()
        }
        pdfView?.hideSelectionToolbar()
    }

    @objc private func deleteTapped() {
        pdfView?.deleteHighlightUnderSelection()
        pdfView?.hideSelectionToolbar()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let converted = convert(point, from: superview)
        if bounds.contains(converted) {
            return super.hitTest(point)
        }
        return nil
    }
}
