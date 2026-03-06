# NoteHighlighter

A native macOS app for reading PDFs and organizing text highlights. Built with SwiftUI + PDFKit.

## What it does

Open a PDF, select text, and highlight it with one of 7 colors. All highlights appear in a searchable, filterable sidebar. Click a highlight to jump to its location. Drag handles to adjust highlight boundaries. Navigate PDFs using a table of contents sidebar. Search for text across the entire document with word-boundary-aware matching and page-grouped results.

The library home screen displays imported PDFs in a thumbnail grid with a macOS-native sidebar for future expansion (Notes, Journal, Settings).

## Quick start

1. Open in Xcode 15+ (macOS 14+ target)
2. In Signing & Capabilities > App Sandbox, enable **User Selected File** (Read Only)
3. Build and run (⌘R)

## How to use

- **Import**: click the + button or use ⌘O to import a PDF, or drag-and-drop onto the library
- **Highlight**: select text → floating toolbar appears → tap a color to highlight
- **Edit**: click a highlight → handles + toolbar appear → drag handles to resize, tap a color to change, or delete
- **Navigate**: use the sidebar toggle to switch between Highlights and Table of Contents
- **Search**: use the toolbar search field to find text across the document; results appear in the sidebar grouped by page
- **Delete**: right-click a sidebar highlight to delete it
- **Filter**: use color chips in the sidebar to filter highlights by color

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for file-by-file breakdown and design decisions.
