# Library

## What Is It?

The Library is the Athenaeum app's core feature — a personal book catalog that lets you organize, browse, and read your EPUB collection from one place. Books are imported by copying them into a local library directory, and their metadata (title, author, year, genre, ISBN, cover art) is stored in a SQLite database. The original files are never modified or moved.

The library currently supports EPUB files, with PDF and plain text support planned for the future. The data model is format-agnostic, so adding new formats requires only a new `MetadataExtractor` and `CoverExtractor` conformance.

## How to Use

### Adding Books

There are two ways to add books:

- **Drag and drop** — Drag one or more `.epub` files onto the library window.
- **Add button** — Click the `+` button in the toolbar and select files from the file picker.

On import, the app:
1. Extracts metadata (title, author, year, genre, ISBN) from the EPUB
2. Checks for duplicates — if a book with the same title and author(s) already exists, the import is rejected
3. Copies the file into the library's `books/` directory
4. Extracts the cover image and saves it as a JPEG in the `covers/` directory
5. Inserts the book and author records into the database

### Browsing

Toggle between two view modes using the segmented control in the toolbar:

- **Grid view** — Scrollable grid of book covers with title and author beneath each cover.
- **Table view** — Sortable table with columns for title, author, year, format, and genre.

### Searching

Click the search field in the toolbar and type a query. Search matches against book titles and author names. Clear the search with the `×` button to return to the full library.

### Opening a Book

Double-click a book cover (grid view) or row (table view) to open it in the reader. Only EPUB files can be read currently.

### Editing Metadata

Right-click a book and select **Edit Metadata** to open the edit sheet. You can change:

- Title, author(s), year, genre, page count, ISBN
- Cover art — click the cover image to pick a new one, or drag and drop an image onto it

Multiple authors are entered as a comma-separated list. Changes are saved to the database when you click Save.

### Exporting as PDF

Right-click a book and select **Export as PDF**. A save dialog appears, and the book is rendered chapter-by-chapter into a single PDF file with:
- Table of contents outline matching the EPUB's TOC
- Print-optimized styling (white background, black text, page breaks between chapters)
- Title and author metadata embedded in the PDF

Export progress is shown in the toolbar via a download icon with a badge. Jobs can be cancelled mid-export. Once exported, the PDF is cached beside the original EPUB file — subsequent exports of the same book skip rendering and copy the cached file instantly.

### Highlighting

When reading a book opened from the library, a highlighter icon appears in the reader toolbar (or toggle with Shift+Cmd+H). The highlighter popover provides:
- **Highlight mode** — Select text to mark it with a colored highlight
- **Color palette** — 5 colors: yellow, green, blue, pink, orange
- **Eraser mode** — Click a highlight to remove it
- **Erase All** — Remove all highlights on the current page (with confirmation)

Highlights persist across sessions — they are saved to the database when navigating between chapters, closing the reader, or toggling highlight mode off. Highlights are not available in Octavo (standalone reader) since it has no database.

### Bookmarks

When reading a book opened from the library, a bookmark icon appears in the reader toolbar (or press Cmd+B). The bookmark popover provides:
- **Add Bookmark** — Saves the current chapter and scroll position with the chapter title as label
- **Bookmark list** — Shows all bookmarks for the book, sorted by creation date
- **Navigate** — Click a bookmark to jump to that position
- **Delete** — Remove individual bookmarks

Bookmarks persist across sessions in the database. They are not available in Octavo (standalone reader) since it has no database.

### Notes

The reader supports two types of notes when reading a book opened from the library:

**Chapter Notes** — Free-form text notes attached to each chapter. Click the document icon in the reader toolbar to open the chapter notes popover. Type your notes and click Save (or Cmd+Return). Notes are saved to the database and persist across sessions.

**Inline Notes** — Notes anchored to specific text in the chapter. Toggle inline note mode via the note icon in the toolbar (or Shift+Cmd+N):
1. Select text to annotate — it is highlighted in purple
2. A sheet appears to enter your note
3. Click Save to confirm, or Cancel to discard
4. Click an existing inline note to view, edit, or delete it

Notes are not available in Octavo (standalone reader) since it has no database.

### Review Chapter Notes

Right-click a book in the library and select **Review Chapter Notes** to browse all notes for a book without opening the reader. A dedicated window shows:
- A sidebar listing all chapters (chapters with notes are marked with an icon)
- A detail pane showing chapter notes and inline notes for the selected chapter
- An empty state if the book has no notes

This is only available for EPUB books.

### Undo/Redo

While reading, Cmd+Z undoes and Shift+Cmd+Z redoes annotation actions:
- **Highlights**: Each highlight creation or erasure is individually undoable
- **Inline Notes**: Each note creation, deletion, or text edit is undoable
- **Bookmarks**: Each bookmark add or delete is undoable
- **Erase All Highlights**: Undoes the entire bulk erase in one step

### Deleting a Book

Right-click a book and select **Delete from Library**. This removes:
- The copied file from the library directory
- The cover image
- The database records

The original file you imported from is **not** affected.

### Settings

Click the gear icon in the toolbar to open Settings. Settings are organized into three tabs:

**General**
- **Language** — App display language. Choose from System Default, English, Spanish, or Italian. Changes take effect after restarting the app.
- **Library Path** — Where book files and the database are stored. Default: `~/Library/Application Support/Athenaeum/`

**Reading**
- **Default Font** — Font family used when opening books in the reader.
- **Font Pairing** — Optionally use separate header and body fonts from curated pairings.
- **Default Light Theme** — Named theme palette for light mode (Classic, Sepia, Paper, Ivory, Sage).
- **Default Dark Theme** — Named theme palette for dark mode (Charcoal, Midnight, Solarized Dark, Monokai, Slate).

**Library Data**
- **Export Library** — Export your entire library (books, covers, and database) to a single `.athenaeumlib` file for backup or transfer to another machine.
- **Import Library** — Import a previously exported `.athenaeumlib` file. This replaces the current library with the imported data.

## Relevant Files

### Source Files

**Models** (`Athenaeum/Models/`)

| File | Purpose |
|------|---------|
| `LibraryBook.swift` | Book model: metadata, format, file paths, JSON identifiers |
| `Author.swift` | Author model with unique name constraint |
| `UserSettings.swift` | Settings model: library path, font, theme mode, theme IDs, language |

**Shared Models** (`Ligature/Sources/Ligature/Models/`)

| File | Purpose |
|------|---------|
| `ReadingTheme.swift` | Named theme palettes (light/dark), available fonts |
| `ThemeMode.swift` | Theme mode enum (light/dark/system) |
| `Highlight.swift` | Highlight, HighlightColor, Bookmark, and InlineNote models |

**Export** (`Athenaeum/Export/`, `Forma/Sources/Forma/Export/`)

| File | Purpose |
|------|---------|
| `ExportJobManager.swift` | Manages export jobs: start, cancel, track progress |
| `PDFExportService.swift` | Renders EPUB chapters to PDF via hidden WKWebView |
| `ExportJobsButton.swift` | Toolbar button with popover showing export job status |

**Import** (`Athenaeum/Import/`)

| File | Purpose |
|------|---------|
| `BookImporter.swift` | Orchestrates import: copy file, extract metadata/cover, insert |
| `BookPathBuilder.swift` | Author/title directory path construction and sanitization |
| `MetadataExtractor.swift` | Protocol + `EPUBMetadataExtractor` + `FallbackMetadataExtractor` |
| `CoverExtractor.swift` | Protocol + `EPUBCoverExtractor` (finds cover from OPF manifest) |
| `DirectoryScanner.swift` | Bulk scan and import from directory |
| `DirectoryImportResult.swift` | Result models: `SkippedFile`, `FailedImport`, `DirectoryImportResult` |

**Views** (`Athenaeum/Views/`)

| File | Purpose |
|------|---------|
| `LibraryView.swift` | Main library layout: toolbar, empty state, drag-and-drop, cover zoom |
| `LibraryViewModel.swift` | Business logic: import, delete, update, search, open book, notes review |
| `ExportJobsButton.swift` | Toolbar export jobs indicator with progress popover |
| `BookGridView.swift` | Scrollable grid of cover thumbnails with context menus |
| `BookTableView.swift` | Table view with title, author, year, format, genre columns |
| `BookEditView.swift` | Metadata edit sheet with cover art replacement |
| `ChapterNotesReviewView.swift` | Review all notes for a book (sidebar + detail window) |
| `DirectoryImportSummaryView.swift` | Summary sheet for bulk directory import results |
| `SettingsView.swift` | Tabbed settings sheet: General, Reading, Library Data |

**Reader UI** (`Forma/Sources/Forma/Views/`)

| File | Purpose |
|------|---------|
| `ReaderView.swift` | Reader layout: sidebar, toolbar, navigation, zoom/undo shortcuts |
| `ReaderViewModel.swift` | Chapter navigation, font/zoom, page counting, highlight/note engines, undo |
| `HighlightPopoverView.swift` | Highlight/eraser controls, color palette popover |
| `BookmarkPopoverView.swift` | Bookmark list, add/delete popover |
| `NotePopoverView.swift` | Inline note mode toggle, editor/detail sheets |
| `ChapterNotesView.swift` | Chapter-level notes editor popover |
| `ThemeManager.swift` | Theme resolution, CSS injection, system appearance KVO |
| `EPUBWebView.swift` | WKWebView wrapper, highlight/note message handlers |

**App Entry** (`Athenaeum/`)

| File | Purpose |
|------|---------|
| `AthenaeumApp.swift` | App entry point, reader/notes window management, BookWindowStore/NotesWindowStore |

For database files, schema, and storage layout, see [DATABASE.md](DATABASE.md).

## How to Maintain

### Adding a New File Format

1. Add a case to `BookFormat` in `LibraryBook.swift`
2. Create a new `MetadataExtractor` conformance (e.g., `PDFMetadataExtractor`)
3. Optionally create a new `CoverExtractor` conformance
4. Register them in `BookImporter.metadataExtractor(for:)` and `coverExtractor(for:)`
5. Add the file extension to `BookFormat.init(fileExtension:)`
6. Add the content type to the file picker in `LibraryView.swift`

### Adding New Metadata Fields

See the [database maintenance guide](DATABASE.md#adding-new-metadata-fields) for the full steps, which span the model, database, repository, view, and extractor layers.

### Book Grouping

The `group_id` field on `LibraryBook` supports linking the same book across formats (e.g., an EPUB and a PDF of the same title). This field is stored but not yet exposed in the UI. When implementing grouping:

1. Add a way to assign/create groups (e.g., a "Link to existing book" option in the context menu)
2. Query grouped books via `SELECT * FROM books WHERE group_id = ?`
3. Display grouped formats together in the grid/table views
