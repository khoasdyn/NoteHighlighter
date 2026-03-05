import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var pdfView: PDFView?
    var appState: AppState?

    func makeNSView(context: Context) -> HighlightablePDFView {
        let view = HighlightablePDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(white: 0.95, alpha: 1.0)
        view.displaysPageBreaks = true
        view.appState = appState

        DispatchQueue.main.async {
            self.pdfView = view
        }

        return view
    }

    func updateNSView(_ nsView: HighlightablePDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
            nsView.stopEditing()
        }
        nsView.appState = appState
    }
}
