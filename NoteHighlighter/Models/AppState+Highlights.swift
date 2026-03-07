import PDFKit

// MARK: - Highlight navigation (stays on AppState — UI coordination)

extension AppState {

    func navigateToHighlight(_ highlight: Highlight) {
        selectedHighlight = highlight

        guard let navigator,
              let document = pdfDocument,
              let page = document.page(at: highlight.pageIndex) else { return }

        let visibleHeight = navigator.visibleRect.height / navigator.scaleFactor
        let targetY = highlight.bounds.midY + visibleHeight / 2

        let destination = PDFDestination(page: page, at: CGPoint(x: 0, y: targetY))
        navigator.go(to: destination)
    }
}
