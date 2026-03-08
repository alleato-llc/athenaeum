# Architecture

## Overview

Athenaeum is structured as a Swift Package with two executable targets and two shared libraries:

```
┌──────────────┐     ┌──────────────┐
│  Athenaeum   │     │    Octavo    │
│  (library)   │     │   (reader)   │
└──────┬───────┘     └──────┬───────┘
       │                    │
       └────────┬───────────┘
                │
       ┌────────▼────────┐
       │      Forma       │
       │  (shared UI)     │
       └────────┬─────────┘
                │
       ┌────────▼────────┐
       │    Ligature      │
       │   (backend)      │
       └─────────────────┘
```

Both apps depend on **Forma** (shared UI: reader views, theme management), which depends on **Ligature** (backend: EPUB parsing, core models). Forma re-exports Ligature via `@_exported import`, so consumers only need `import Forma`.

SQLite is linked only by the **Athenaeum** target, which contains all library-specific code (database, import pipeline, library views).

## Ligature

Backend library containing EPUB parsing and core models. No UI dependencies.

### Models

**`EPUBBook`** — The core model representing a parsed EPUB file.
- `title`, `author`, `language` — Book metadata
- `spine: [SpineItem]` — Ordered list of content documents (chapters) as defined by the EPUB spine
- `tableOfContents: [TOCEntry]` — Hierarchical table of contents with nested children
- `baseURL: URL` — Path to the extracted EPUB content on disk

**`EPUBMetadata`** — Extended metadata parsed from the OPF file, including publisher, description, identifier, and EPUB version (2.0 or 3.0).

**`ReadingTheme`** — Named theme palettes (5 light, 5 dark) with colors for background, text, links, and code blocks. Also defines available font families.

**`ThemeMode`** — Enum (`light`, `dark`, `system`) used by both apps for theme selection.

### Parsing Pipeline

EPUB files are ZIP archives with a defined structure. The parsing pipeline processes them in stages:

```
.epub file
    │
    ▼
EPUBParser.extractEPUB()     Unzips to a temp directory using /usr/bin/unzip
    │
    ▼
ContainerXMLParser            Parses META-INF/container.xml to locate the OPF file
    │
    ▼
OPFParser                     Parses the OPF file to extract:
    │                          - Metadata (title, author, language, version)
    │                          - Manifest (all files in the EPUB)
    │                          - Spine (reading order)
    │                          - TOC file reference
    │
    ▼
TOCParser                     Parses the table of contents:
    ├─ EPUB2TOCParser          NCX format (navPoint elements)
    └─ EPUB3TOCParser          Navigation document (nav > ol > li > a)
                               Falls back to NCX if EPUB3 nav yields no entries
```

All XML parsing uses Foundation's `XMLParser` (SAX-style). No third-party XML libraries are used.

### Notifications

Shared `Notification.Name` extensions (`Notifications.swift`) for cross-module communication:
- `.openBook` — Athenaeum posts when a user opens a book from the library
- `.addBooks` — Menu command triggers the file picker
- `.saveReadingProgress` — Reader posts to persist chapter/scroll position
- `.saveHighlights` — Reader posts to persist highlights for a chapter
- `.addBookmark` — Reader posts to add a bookmark at current position
- `.deleteBookmark` — Reader posts to remove a bookmark
- `.saveChapterNotes` — Reader posts to persist chapter-level notes
- `.saveInlineNotes` — Reader posts to persist inline notes for a chapter
- `.openNotesReview` — Athenaeum posts to open the notes review window for a book

## Forma

Shared UI library containing the reader interface and theme management. Depends on Ligature.

### Views

**`ReaderView`** — Main reader layout. Composes all sub-views:
- Progress bar at the top
- Collapsible TOC sidebar (left) with full-width click targets
- Content area with auto-hiding toolbar and navigation bar overlays
- Cmd+/- keyboard shortcuts for page zoom

**`ReaderToolbarView`** — Top toolbar (auto-hides). Controls:
- Sidebar toggle
- Book title display
- Font family selector
- Page zoom controls
- Highlighter popover (Athenaeum only — requires `libraryBookId`)
- Bookmark popover (Athenaeum only)
- Inline note mode popover (Athenaeum only)
- Chapter notes popover (Athenaeum only)
- Three-mode theme toggle (light / dark / system)

**`ReaderNavigationBar`** — Bottom navigation (auto-hides). Controls:
- Previous/next chapter buttons
- Direct chapter number input

**`EPUBWebView`** — `NSViewRepresentable` wrapper around `WKWebView`. Renders EPUB chapter HTML with local file access enabled. Handles:
- Navigation delegate for internal link interception
- Page zoom application on load
- `noteHandler` message handler for inline note creation/viewing
- `highlightHandler` message handler for highlight/erase undo tracking

**`ThemeManager`** — `ObservableObject` service managing theme state:
- Three-mode theme cycling: light → dark → system → light
- Resolves the active `ReadingTheme` based on mode and system appearance
- Observes `NSApp.effectiveAppearance` via KVO for automatic system theme changes
- Generates and injects CSS into `WKWebView` for styling

**`ReaderViewModel`** — `ObservableObject` managing reader state:
- Current chapter index and navigation
- Font family and page zoom level
- Composes with `ThemeManager` for theme resolution and styling
- Scroll position save/restore across chapters
- Highlight mode, eraser mode, and color selection
- Injects a JavaScript highlight engine into WKWebView for creating, erasing, serializing, and restoring highlights
- Injects a JavaScript note engine into WKWebView for inline note creation, editing, deletion, and restoration
- Chapter notes management (per-chapter text notes)
- Bookmark management: add, delete, navigate to bookmarks
- Undo/redo management via `UndoManager` for highlights, notes, and bookmarks

**`HighlightPopoverView`** — Popover UI for the highlighter feature:
- Toggle for highlight mode (select text to highlight)
- Color palette (5 semi-transparent colors)
- Toggle for eraser mode (click highlights to remove)
- "Erase All on Page" with confirmation alert

**`BookmarkPopoverView`** — Popover UI for bookmark management:
- Add bookmark at current position
- List all bookmarks with chapter name and date
- Click to navigate, delete individual bookmarks

**`NotePopoverView`** — Contains three note-related views:
- `NoteToolbarPopover` — Toggle for inline note mode with color indicator
- `NoteEditorSheet` — Sheet for entering text when creating a new inline note
- `NoteDetailSheet` — Sheet for viewing, editing, or deleting an existing inline note

**`ChapterNotesView`** — Popover for chapter-level notes:
- Shows chapter title and a text editor for free-form notes
- Save button persists notes to the database via notification

### Styling

Chapter content is styled by `ThemeManager`, which injects a `<style>` element into the loaded HTML via JavaScript. The injected CSS:
- Sets font family on `body` and forces inheritance on all elements with `* { font-family: inherit !important }`
- Applies background, text, link, and code background colors from the active `ReadingTheme`
- Constrains content width to `45em` for readability
- Overrides inline styles from EPUB content using `!important`

Page zoom is handled separately via `WKWebView.pageZoom`, which uniformly scales all content.

### Highlighting

The reader supports text highlighting when a book is opened from Athenaeum (where a database is available). Highlights are:
- Created by selecting text while highlight mode is active
- Rendered as `<mark data-ath-highlight="uuid">` elements with CSS custom properties for color
- Serialized using XPath node paths and character offsets so they survive chapter reloads
- Stored as JSON arrays per chapter in the database (one row per book/chapter pair)
- Protected from ThemeManager's `background-color: transparent !important` override via a CSS exception for `mark[data-ath-highlight]`

The JavaScript engine is injected as an IIFE on each chapter load. It supports three modes: highlight (mouseup wraps selection), eraser (click unwraps marks), and off. Cross-element selections produce one `<mark>` per text node to avoid DOM corruption.

When a highlight is created or erased, the JS engine posts a message to the `highlightHandler` message handler, triggering an undo-aware save in Swift.

### Notes

The reader supports two types of notes when a book is opened from Athenaeum:

**Chapter Notes** — Free-form text notes per chapter. Edited via a `TextEditor` in the `ChapterNotesView` popover. Stored as plain text in the `chapters.notes` column.

**Inline Notes** — Anchored to selected text in the chapter. Created by:
1. Activating note mode (Shift+Cmd+N or toolbar toggle)
2. Selecting text — the JS note engine creates `<mark data-ath-note="uuid">` elements (purple highlight)
3. A sheet appears for the user to enter their note text
4. On confirm, the note text is stored as a `data-note-text` attribute on the marks

Inline notes use XPath serialization (same approach as highlights) and are stored as JSON arrays per chapter in the `chapters.inline_notes` column. Clicking an existing note opens it for viewing, editing, or deletion.

The JavaScript note engine is injected alongside the highlight engine. It includes functions for creating, confirming, cancelling, deleting, updating, and collecting notes. Notes can also be bulk-cleared via `athEraseAllNotes()` for undo/redo restoration.

### Undo/Redo

Annotation actions support undo (Cmd+Z) and redo (Shift+Cmd+Z). The `ReaderViewModel` maintains an `UndoManager` that tracks:

- **Highlights**: Each individual highlight creation or erasure registers an undo action. The JS engine notifies Swift after each mouseup (highlight mode) or click (eraser mode) via the `highlightHandler` message handler. "Erase All" registers a single undo for the entire batch.
- **Inline Notes**: Each note creation (`confirmPendingNote`), deletion (`deleteInlineNote`), and text update (`updateInlineNote`) registers an undo action.
- **Bookmarks**: Each `addBookmark` and `deleteBookmark` registers an undo action.

Undo restores the previous state by clearing all marks from the DOM and re-applying the snapshot via `athHighlightInit`/`athNoteInit`. The restore functions register the reverse operation as a redo, creating a proper undo/redo chain.

Keyboard shortcuts are intercepted in `ReaderView`'s `NSEvent` local monitor (keyCode 6 = Z key).

### Review Chapter Notes

From the Athenaeum library, users can right-click a book and select "Review Chapter Notes" to open a dedicated window showing all notes for that book without entering the reader. The window uses a `NavigationSplitView` with:
- **Sidebar**: Lists all chapters; chapters with notes show a `note.text` icon
- **Detail pane**: Shows chapter notes and/or inline notes for the selected chapter
- **Empty state**: Shown when the book has no notes

The data is loaded by `LibraryViewModel.reviewNotes()`, which parses the EPUB (for TOC/spine), loads notes from the database, stores them in `NotesWindowStore`, and opens a new window via the `.openNotesReview` notification.

### PDF Export

Books can be exported to PDF from the library context menu. The export pipeline:
1. Parses the EPUB and renders each chapter sequentially in a hidden `WKWebView`
2. Uses `WKWebView.createPDF()` to capture each chapter with print-optimized CSS
3. Merges chapter PDFs into a single `PDFDocument` with table of contents outline
4. Caches the generated PDF beside the EPUB file for instant re-export

Export jobs are tracked by `ExportJobManager` (Athenaeum) with progress UI via `ExportJobsButton`. The rendering service (`PDFExportService`) lives in Forma. Jobs can be cancelled mid-export.

### Themes

The app ships with 10 named theme palettes (5 light, 5 dark) defined in `ReadingTheme`. Users select a default light and dark theme in Settings. The reader toolbar cycles between three modes:
- **Light** — uses the selected light theme
- **Dark** — uses the selected dark theme
- **System** — follows macOS appearance, switching automatically via KVO on `NSApp.effectiveAppearance`

## Athenaeum-Specific Components

The Athenaeum target contains all library-specific code that is not shared with Octavo.

### Database

SQLite via the C API (`libsqlite3`), linked in the root `Package.swift` for the Athenaeum target only. See [DATABASE.md](DATABASE.md) for schema and storage details.

### Import Pipeline

`BookImporter` checks for duplicate books before copying files to the library. A book is considered a duplicate if another book with the same title and author(s) already exists (case-insensitive match via `BookRepository.bookExists`). Duplicate detection happens at the service layer — no UI changes are needed since `LibraryViewModel` already surfaces import errors.

Books are stored in an author/title directory layout under `books/`, constructed by `BookPathBuilder`. The builder sanitizes author and title names for safe filesystem use and organizes files as `books/<prefix>/<author>/<title>/<uuid>.epub`.

`DirectoryScanner` provides bulk import from an arbitrary directory. It recursively scans for EPUB files, imports each via `BookImporter`, and tracks skipped non-EPUB formats, failed imports, and progress. Results are presented in a summary sheet via `DirectoryImportSummaryView`.

### Library Views

Library-specific views (`LibraryView`, `BookGridView`, `BookTableView`, `BookEditView`, `ChapterNotesReviewView`, `SettingsView`) and their view model (`LibraryViewModel`) live in the Athenaeum target. These handle import, search, metadata editing, cover zoom, PDF export, notes review, library export/import, and settings.

Settings are presented as a tabbed sheet with three tabs: **General** (language, library path), **Reading** (font, themes), and **Library Data** (export/import).

### Export

`ExportJobManager` manages PDF export jobs, tracking status (pending, exporting, saving, completed, failed, cancelled). `ExportJobsButton` provides a toolbar indicator with a popover showing job progress. The rendering is delegated to `PDFExportService` in Forma.

## Xcode Project

The Xcode project is generated from `project.yml` at the repo root using [xcodegen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is gitignored; run `xcodegen generate` to recreate it.

Both app targets are configured for App Store distribution:
- Automatic code signing
- App Sandbox with user-selected read-write file access
- EPUB document type and UTI declarations in Info.plist
- Bundle IDs: `com.alleato.athenaeum` and `com.alleato.octavo`

## Apps

### Octavo (Reader)

Entry point: `Octavo/OctavoApp.swift`

Presents a landing screen with a file picker button and drag-and-drop support. When an EPUB file is opened, it uses `EPUBParser` from Ligature to parse the file and presents `ReaderView` from Forma.

### Athenaeum (Library)

Entry point: `Athenaeum/AthenaeumApp.swift`

Personal book catalog. Import, browse, search, and manage EPUB books. Opens books in the reader via `NotificationCenter`. Uses SQLite for persistent storage — see [DATABASE.md](DATABASE.md) for schema and storage details, and [LIBRARY.md](LIBRARY.md) for the full feature guide.
