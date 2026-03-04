import SwiftUI
import SwiftData

@main
struct NoteHighlighterApp: App {
    @StateObject private var appState = AppState()
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: BookItem.self, SavedHighlight.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.currentBook != nil {
                    ContentView()
                } else {
                    NavigationStack {
                        GalleryView()
                    }
                }
            }
            .environmentObject(appState)
            .onAppear {
                appState.modelContext = modelContainer.mainContext
            }
            .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                if appState.currentBook != nil {
                    Button("Close Book") {
                        appState.closeBook()
                    }
                    .keyboardShortcut("w", modifiers: .command)
                } else {
                    Button("Import PDF...") {
                        appState.showFileImporter = true
                    }
                    .keyboardShortcut("o", modifiers: .command)
                }
            }
        }
    }
}
