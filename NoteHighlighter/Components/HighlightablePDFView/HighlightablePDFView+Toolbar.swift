import Cocoa
import PDFKit

// MARK: - Selection toolbar management

extension HighlightablePDFView {

    func showSelectionToolbar(at viewPoint: CGPoint) {
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
}
