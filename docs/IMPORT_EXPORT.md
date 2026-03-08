# Import & Export

## Overview

Athenaeum provides three data transfer features, all accessible from **Settings > Library Data**:

1. **Export Library** — Back up the entire library to a single archive file
2. **Import Library** — Restore a library from a previously exported archive
3. **Import from Directory** — Bulk-import EPUB files from an arbitrary directory

## Export Library

Exports the entire library (database, book files, and covers) into a single `.athenaeumlib` file for backup or transfer to another machine.

### How It Works

1. User clicks **Export…** in Settings > Library Data
2. An `NSSavePanel` prompts for the destination filename (default: `Library.athenaeumlib`)
3. The app copies three items into a temp directory:
   - `library.db` — the SQLite database
   - `books/` — all book files (organized by author/title subdirectories)
   - `covers/` — legacy covers directory (if it exists from pre-migration data)
4. The temp directory is bundled into a tar archive using `/usr/bin/tar -cf`
5. The resulting `.athenaeumlib` file is written to the chosen destination

No compression is applied — EPUBs are already zip archives internally, and cover images (JPEG) are already compressed, so re-compressing yields negligible size savings while adding CPU overhead.

### File Format

The `.athenaeumlib` format is a tar archive containing:

```
./
├── library.db     # SQLite database with all book/author/settings records
├── books/         # Book files in author/title directory structure
│   └── Author Name/
│       └── Book Title/
│           ├── {uuid}.epub
│           └── {uuid}.jpg   # Cover image
└── covers/        # (optional) Legacy flat cover directory
```

### Relevant Files

| File | Role |
|------|------|
| `Athenaeum/Views/LibraryViewModel.swift` | `exportLibrary()` — orchestrates the export |
| `Athenaeum/Views/SettingsView.swift` | UI entry point in Library Data tab |

## Import Library

Restores a library from a previously exported `.athenaeumlib` archive. This is a **destructive operation** — it fully replaces the current library.

### How It Works

1. User clicks **Import…** in Settings > Library Data
2. An `NSOpenPanel` filters for `.athenaeumlib` files
3. The app extracts the tar archive using `/usr/bin/tar -xf` to a temp directory
4. The extracted contents replace the current library data:
   - `library.db` is deleted and replaced
   - `books/` directory is deleted and replaced
   - `covers/` directory is deleted and replaced (if present in archive)
5. A new database connection is established from the imported `library.db`
6. The book list is reloaded from the new database

### Important Notes

- The current library is **completely overwritten** — there is no merge
- The operation runs synchronously on the main thread
- If the archive does not contain a `library.db`, the import fails with an error message
- The app does not restart after import; it re-reads the database and updates the book list in place

### Relevant Files

| File | Role |
|------|------|
| `Athenaeum/Views/LibraryViewModel.swift` | `importLibrary()` — orchestrates the import |
| `Athenaeum/Views/SettingsView.swift` | UI entry point in Library Data tab |

## Import from Directory

Bulk-imports EPUB files from an arbitrary directory (e.g., a Calibre library, downloads folder, or external drive). Non-EPUB book formats are skipped and reported in a summary.

### How It Works

1. User clicks **Import from Directory…** in Settings > Library Data
2. The settings sheet dismisses, then an `NSOpenPanel` (directories only) appears
3. The app performs a two-phase process on a background thread:

**Phase 1 — Scan**: Recursively enumerates all files in the selected directory (skipping hidden files and package contents). Files are categorized as:
- `.epub` files → queued for import
- Known non-EPUB book formats → recorded as skipped (see list below)
- All other files → ignored

**Phase 2 — Import**: Each EPUB is imported via `BookImporter.importBook(from:)`. Failures (duplicates, parse errors) are recorded rather than stopping the process. Progress is reported to the UI after each file.

4. A progress overlay shows "Importing X of Y…" during the import phase
5. On completion, a summary sheet displays:
   - Count of successfully imported EPUBs and skipped files
   - Failed imports table (if any) with filename and reason
   - Skipped files table (if any) with filename, format, and path

### Skipped File Extensions

The following non-EPUB book formats are recognized and reported as skipped:

`pdf`, `mobi`, `txt`, `azw`, `azw3`, `djvu`, `cbz`, `cbr`, `fb2`, `doc`, `docx`, `rtf`

Files with extensions not in this list and not `.epub` are silently ignored (e.g., `.jpg`, `.xml`, `.opf`).

### Failure Handling

When an individual EPUB fails to import, the error is captured and the scanner continues with the remaining files. Common failure reasons:

- **Duplicate book** — A book with the same title and author(s) already exists
- **Unsupported format** — The file has an `.epub` extension but cannot be parsed
- **File access errors** — Permission denied or corrupted file

### Relevant Files

| File | Role |
|------|------|
| `Athenaeum/Import/DirectoryImportResult.swift` | Result models: `SkippedFile`, `FailedImport`, `DirectoryImportResult` |
| `Athenaeum/Import/DirectoryScanner.swift` | `DirectoryScanner` — recursive scan and import service |
| `Athenaeum/Views/DirectoryImportSummaryView.swift` | Summary sheet with tables for failed/skipped files |
| `Athenaeum/Views/LibraryViewModel.swift` | `importFromDirectory()` — presents picker, runs scanner, shows results |
| `Athenaeum/Views/LibraryView.swift` | Progress overlay and summary sheet binding |
| `Athenaeum/Views/SettingsView.swift` | UI entry point in Library Data tab |
