import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var pdfView: PDFView?
    var appState: AppState?

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeNSView(context: Context) -> HighlightablePDFView {
        let view = HighlightablePDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(white: 0.95, alpha: 1.0)
        view.displaysPageBreaks = true
        view.appState = appState

        context.coordinator.observe(view)

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
        context.coordinator.appState = appState
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var appState: AppState?
        private var pageChangeObserver: NSObjectProtocol?

        init(appState: AppState?) {
            self.appState = appState
        }

        func observe(_ pdfView: PDFView) {
            pageChangeObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                guard let self, let pdfView,
                      let currentPage = pdfView.currentPage,
                      let document = pdfView.document else { return }
                self.appState?.currentPageIndex = document.index(for: currentPage)
            }
        }

        deinit {
            if let observer = pageChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
