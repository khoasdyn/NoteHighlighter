//
//  NoteHighlighterApp.swift
//  NoteHighlighter
//
//  Created by khoasdyn on 4/3/26.
//

import SwiftUI

@main
struct NoteHighlighterApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF...") {
                    appState.showFileImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
