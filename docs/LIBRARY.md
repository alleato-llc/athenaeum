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

### Deleting a Book

Right-click a book and select **Delete from Library**. This removes:
- The copied file from the library directory
- The cover image
- The database records

The original file you imported from is **not** affected.

### Settings

Click the gear icon in the toolbar to open Settings:

- **Library Path** — Where book files and the database are stored. Default: `~/Library/Application Support/Athenaeum/`
- **Default Font** — Font family used when opening books in the reader.
- **Default Light Theme** — Named theme palette for light mode (Classic, Sepia, Paper, Ivory, Sage).
- **Default Dark Theme** — Named theme palette for dark mode (Charcoal, Midnight, Solarized Dark, Monokai, Slate).

## Relevant Files

### Source Files

**Models** (`Athenaeum/Models/`)

| File | Purpose |
|------|---------|
| `LibraryBook.swift` | Book model: metadata, format, file paths, JSON identifiers |
| `Author.swift` | Author model with unique name constraint |
| `UserSettings.swift` | Settings model: library path, font, theme mode, theme IDs |

**Shared Models** (`Ligature/Sources/Ligature/Models/`)

| File | Purpose |
|------|---------|
| `ReadingTheme.swift` | Named theme palettes (light/dark), available fonts |
| `ThemeMode.swift` | Theme mode enum (light/dark/system) |

**Import** (`Athenaeum/Import/`)

| File | Purpose |
|------|---------|
| `BookImporter.swift` | Orchestrates import: copy file, extract metadata/cover, insert |
| `MetadataExtractor.swift` | Protocol + `EPUBMetadataExtractor` + `FallbackMetadataExtractor` |
| `CoverExtractor.swift` | Protocol + `EPUBCoverExtractor` (finds cover from OPF manifest) |

**Views** (`Athenaeum/Views/`)

| File | Purpose |
|------|---------|
| `LibraryView.swift` | Main library layout: toolbar, empty state, drag-and-drop, cover zoom |
| `LibraryViewModel.swift` | Business logic: import, delete, update, search, open book |
| `BookGridView.swift` | Scrollable grid of cover thumbnails with context menus |
| `BookTableView.swift` | Table view with title, author, year, format, genre columns |
| `BookEditView.swift` | Metadata edit sheet with cover art replacement |
| `SettingsView.swift` | Settings sheet: library path, font, light/dark theme pickers with previews |

**Reader UI** (`Forma/Sources/Forma/Views/`)

| File | Purpose |
|------|---------|
| `ReaderView.swift` | Reader layout: sidebar, toolbar, navigation, zoom shortcuts |
| `ReaderViewModel.swift` | Chapter navigation, font/zoom, page counting |
| `ThemeManager.swift` | Theme resolution, CSS injection, system appearance KVO |
| `EPUBWebView.swift` | WKWebView wrapper for rendering chapters |

**App Entry** (`Athenaeum/`)

| File | Purpose |
|------|---------|
| `AthenaeumApp.swift` | App entry point, hosts LibraryView, handles book open notifications |

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
