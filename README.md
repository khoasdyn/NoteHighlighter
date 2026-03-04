# NoteHighlighter

A native macOS app for reading PDFs and organizing text highlights. Built with SwiftUI + PDFKit.

## What it does

Open a PDF, select text, and highlight it with one of 7 colors. All highlights appear in a searchable sidebar. Click a highlight to jump to its location. Drag handles to adjust boundaries. Works with both highlights created in-app and imported from other PDF readers.

## Quick start

1. Open in Xcode 15+ (macOS 14+ target)
2. In Signing & Capabilities > App Sandbox, enable **User Selected File** (Read Only)
3. Build and run (⌘R)

## How to use

- **⌘O** to open a PDF, or drag-and-drop
- **Select text** → floating toolbar appears → tap a color to highlight
- **Click a highlight** → handles + toolbar appear → drag handles to resize, tap a color to change, or delete
- **Right-click** a sidebar item to delete
- **Search** and **filter by color** in the sidebar

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for file-by-file breakdown and design decisions.
