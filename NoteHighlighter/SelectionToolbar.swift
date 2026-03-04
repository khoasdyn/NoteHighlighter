import Cocoa
import PDFKit

class SelectionToolbar: NSView {
    weak var pdfView: HighlightablePDFView?
    
    private var copyButton: NSButton!
    private var deleteButton: NSButton!
    private var deleteSeparator: NSView!
    
    private let colors: [(HighlightColor, NSColor)] = [
        (.yellow,  NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)),
        (.blue,    NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)),
        (.green,   NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)),
        (.pink,    NSColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0)),
        (.purple,  NSColor(red: 0.65, green: 0.3, blue: 0.9, alpha: 1.0)),
        (.orange,  NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)),
        (.red,     NSColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)),
    ]
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.95).cgColor
        layer?.cornerRadius = 8
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.zPosition = 2000
        
        // Build all items in a horizontal stack
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        // Padding
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
        
        // Copy
        copyButton = makeTextButton(title: "Copy", action: #selector(copyTapped))
        stack.addArrangedSubview(copyButton)
        stack.addArrangedSubview(makeSeparator())
        
        // Color circles
        for (i, (highlightColor, displayColor)) in colors.enumerated() {
            let btn = makeColorButton(color: displayColor, index: i)
            btn.toolTip = highlightColor.displayName
            stack.addArrangedSubview(btn)
        }
        
        // Delete separator + button
        deleteSeparator = makeSeparator()
        stack.addArrangedSubview(deleteSeparator)
        
        deleteButton = makeTextButton(title: "Delete", action: #selector(deleteTapped))
        deleteButton.contentTintColor = NSColor.systemRed
        // Re-style delete in red
        let redTitle = NSMutableAttributedString(string: "Delete", attributes: [
            .foregroundColor: NSColor.systemRed,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ])
        deleteButton.attributedTitle = redTitle
        stack.addArrangedSubview(deleteButton)
    }
    
    private func makeColorButton(color: NSColor, index: Int) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 11
        container.layer?.backgroundColor = color.cgColor
        container.layer?.borderWidth = 1.5
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 22),
            container.heightAnchor.constraint(equalToConstant: 22),
        ])
        
        // Invisible button on top for click handling
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
        btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let styledTitle = NSMutableAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ])
        btn.attributedTitle = styledTitle
        btn.sizeToFit()
        btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        btn.setContentHuggingPriority(.required, for: .horizontal)
        // Fix width so it never shrinks
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
            sep.heightAnchor.constraint(equalToConstant: 18),
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
        let colorInfo = colors[sender.tag]
        pdfView?.appState?.currentHighlightColor = colorInfo.0
        
        if pdfView?.isEditing == true {
            // Change color of existing highlight
            pdfView?.changeEditingHighlightColor(colorInfo.0)
        } else {
            // Create new highlight from selection
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
