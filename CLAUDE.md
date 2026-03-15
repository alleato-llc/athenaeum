# Athenaeum

A macOS EPUB reader and library manager built with Swift and SwiftUI. External dependencies: GRDB (database) and ZIPFoundation (zip/unzip).

## Project Structure

Swift Package (swift-tools-version 5.9, macOS 13+) with two app targets and two shared libraries:

- **Athenaeum** (`Athenaeum/`) — Library/catalog app. Import, browse, and manage books. Bundle ID: `com.alleato.athenaeum`.
- **Octavo** (`Octavo/OctavoApp.swift`) — EPUB reader app. Opens `.epub` files via file picker or drag-and-drop. Bundle ID: `com.alleato.octavo`.
- **Forma** (`Forma/`) — Shared UI library: reader views, theme management. Depends on Ligature.
- **Ligature** (`Ligature/`) — Shared backend library: EPUB parsing, core models. No UI dependencies.

### Dependency Graph

```
Athenaeum ──▶ Forma ──▶ Ligature
Octavo   ──▶ Forma ──▶ Ligature
```

### Xcode Project

The Xcode project is generated from `project.yml` using [xcodegen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate        # Generate Athenaeum.xcodeproj
open Athenaeum.xcodeproj # Open in Xcode
```

The `.xcodeproj` is gitignored — always regenerate from `project.yml`. Both app targets use automatic code signing and include App Sandbox entitlements with user-selected file read-write access.

### Ligature Layout

Common backend — no UI frameworks, no SQLite.

```
Ligature/Sources/Ligature/
├── Models/
│   ├── EPUBBook.swift          # Runtime model for reader (title, author, spine, TOC)
│   ├── EPUBMetadata.swift      # Metadata with EPUB 2/3 version enum
│   ├── ReadingTheme.swift      # Named theme palettes (light/dark), available fonts
│   ├── ThemeMode.swift         # Light/dark/system enum
│   └── Highlight.swift         # Highlight, HighlightColor, Bookmark, and InlineNote models
├── Parser/
│   ├── EPUBParser.swift        # Top-level: extract zip, parse OPF, build EPUBBook
│   ├── ContainerXMLParser.swift
│   ├── OPFParser.swift
│   └── TOCParser.swift         # EPUB2 (NCX) and EPUB3 (nav) parsers
└── Notifications.swift         # Shared notification names (progress, highlights, bookmarks, notes)
```

### Forma Layout

Common UI — reader views shared by both apps.

```
Forma/Sources/Forma/
├── Views/
│   ├── ReaderView.swift        # Reader: sidebar, auto-hiding toolbar/nav bar, undo/redo
│   ├── ReaderViewModel.swift   # Chapter nav, font/zoom, page counting, highlight/note engines, undo
│   ├── HighlightPopoverView.swift # Highlight/eraser controls, color palette
│   ├── BookmarkPopoverView.swift  # Bookmark list and add/delete controls
│   ├── NotePopoverView.swift      # Inline note mode toggle, editor/detail sheets
│   ├── ChapterNotesView.swift     # Chapter-level notes editor popover
│   ├── ThemeManager.swift      # Theme resolution, CSS injection, system appearance KVO
│   └── EPUBWebView.swift       # WKWebView wrapper, highlight/note message handlers
├── Export/
│   └── PDFExportService.swift  # Renders EPUB chapters to PDF via hidden WKWebView
├── Exports.swift               # @_exported import Ligature
└── Resources/
    └── {en,es,it}.lproj/       # Reader localized strings
```

### Athenaeum Layout

Library app — database, import pipeline, library UI. Uses GRDB for SQLite access.

```
Athenaeum/
├── AthenaeumApp.swift          # App entry point, window management
├── Database/
│   ├── LibraryDatabase.swift   # SQLite connection, migrations
│   ├── BookRepository.swift    # CRUD for books + authors, search
│   ├── HighlightRepository.swift # CRUD for text highlights (JSON per chapter)
│   ├── BookmarkRepository.swift  # CRUD for bookmarks
│   ├── NoteRepository.swift       # CRUD for chapter notes and inline notes
│   ├── ChapterRepository.swift   # Chapter row management (ensure exists)
│   └── SettingsRepository.swift # Key-value settings store (incl. language)
├── Export/
│   └── ExportJobManager.swift  # Manages PDF export jobs: start, cancel, track progress
├── Import/
│   ├── BookImporter.swift      # Orchestrates: copy file, extract metadata/cover, insert
│   ├── BookPathBuilder.swift   # Author/title directory path construction + sanitization
│   ├── MetadataExtractor.swift # Protocol + EPUB extractor + fallback
│   ├── CoverExtractor.swift    # Protocol + EPUB cover extractor
│   ├── DirectoryScanner.swift  # Bulk scan + import from directory
│   └── DirectoryImportResult.swift # Result models: SkippedFile, FailedImport
├── Models/
│   ├── LibraryBook.swift       # Persistent model (metadata, format, identifiers JSON)
│   ├── Author.swift            # Author model (many-to-many with books)
│   └── UserSettings.swift      # Settings: library path, font, theme mode, theme IDs, language
├── Views/
│   ├── LibraryView.swift       # Library: toolbar, empty state, drag-and-drop
│   ├── LibraryViewModel.swift  # Library business logic: import, delete, search, highlights, notes
│   ├── ExportJobsButton.swift  # Toolbar export jobs indicator with progress popover
│   ├── BookGridView.swift      # Scrollable grid of cover thumbnails
│   ├── BookTableView.swift     # Table: title, author, year, format, genre
│   ├── BookEditView.swift      # Metadata edit sheet with cover replacement
│   ├── ChapterNotesReviewView.swift # Review all notes for a book (sidebar + detail)
│   ├── DirectoryImportSummaryView.swift # Summary sheet for bulk directory import
│   └── SettingsView.swift      # Tabbed settings: General, Reading, Library Data
└── Resources/
    └── {en,es,it}.lproj/       # Library localized strings
```

## Build & Run

### Xcode (recommended for development)

```sh
xcodegen generate        # Generate .xcodeproj from project.yml
open Athenaeum.xcodeproj # Open in Xcode, select Athenaeum or Octavo scheme
```

### Command line

```sh
swift build            # Build all targets via SwiftPM
swift test             # Run AthenaeumTests
swift run Octavo       # Run the standalone EPUB reader
swift run Athenaeum    # Run the library app
cd Ligature && swift test  # Run LigatureTests
```

## Key Technical Details

- EPUB extraction uses [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (no shell-outs).
- Chapter content rendered in `WKWebView` with local file access enabled.
- Styling injected via JavaScript: font family forced with `* { font-family: inherit !important }`.
- Page zoom via `WKWebView.pageZoom` (single unified zoom, no separate font size control).
- Keyboard zoom: Cmd+/- adjusts reader zoom (Octavo) or cover size (Athenaeum library).
- EPUB 2 (NCX) and EPUB 3 (nav) TOC supported, with EPUB 3 falling back to NCX.
- Toolbar and navigation bar auto-hide, revealed on hover at top/bottom edges.
- Keyboard navigation: left/right arrow keys navigate by page or chapter depending on mode.
- Page/chapter navigation mode toggled by double-clicking the mode label in the nav bar.
- Global page count computed via background `WKWebView` measurement of all chapters.
- Window title bar shows reading progress percentage (e.g., "Octavo | 42% Complete").
- All XML parsing uses Foundation `XMLParser` (SAX-style).
- SQLite via [GRDB](https://github.com/groue/GRDB.swift), used for all database access.
- Library data stored at `~/Library/Application Support/Athenaeum/` (library.db, books/, covers/).
- No business logic in views — views delegate to view models and services.
- No `Process` shell-outs — all file operations use native Swift or library APIs.

## Architectural Rules

These rules must be followed in all code changes:

1. **No business logic in UI.** Views must not contain domain logic, data transformations, or service calls. Views delegate to view models and services. Domain data (e.g., font lists, theme definitions) belongs on models or services, not view models.

2. **Single responsibility.** Each class/struct handles one concern and composes with others for cross-cutting behavior. For example, `ThemeManager` owns theme resolution and CSS injection; `ReaderViewModel` composes with it rather than owning theme logic directly.

3. **Minimal external dependencies.** Use Foundation, AppKit, SwiftUI, WebKit, GRDB for database access, and ZIPFoundation for zip operations. No `Process` shell-outs — never use `/usr/bin/unzip`, `/usr/bin/tar`, or similar. Avoid adding other external dependencies without justification.

4. **Format-agnostic models.** Library models (e.g., `LibraryBook`, `BookFormat`) support multiple formats. Reader-specific logic is separate.

5. **Service-layer validation.** Input validation and duplicate checks happen in service/repository layers, not in views or view models.

6. **Module boundaries.** Ligature contains only backend code (parser, models) with no UI dependencies. Forma contains shared UI (reader). Library-specific code (database, import, library views) lives in Athenaeum.

## Testing

Tests use Swift Testing (`@Suite`, `@Test`, `#expect()`) with real SQLite databases and real EPUB fixtures (Project Gutenberg). No mocks. Shared helpers in `Tests/AthenaeumTests/TestHelpers.swift` provide `TestDatabase`, `TestImportEnvironment`, `TestData`, and `TestFixtures`.

See [docs/TESTING.md](docs/TESTING.md) for conventions, fixtures, and adding tests.

## Localization

The app is localized for English, Spanish, and Italian using `.strings` files. Each target (Forma, Octavo, Athenaeum) has its own localization resources under a `Resources/` directory.

See [docs/LOCALIZATION.md](docs/LOCALIZATION.md) for details on adding languages and strings.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Detailed architecture and component documentation
- [docs/DATABASE.md](docs/DATABASE.md) — Database: technology choices, schema, storage layout, migrations
- [docs/LIBRARY.md](docs/LIBRARY.md) — Library feature: usage, relevant files, maintenance guide
- [docs/FONTS.md](docs/FONTS.md) — Font system: available fonts, font pairing, CSS injection
- [docs/IMPORT_EXPORT.md](docs/IMPORT_EXPORT.md) — Import & export: library backup/restore, directory import
- [docs/PDF_EXPORT.md](docs/PDF_EXPORT.md) — PDF export: headless WKWebView rendering, job management, caching
- [docs/NAVIGATION.md](docs/NAVIGATION.md) — Reader navigation: chapter transitions, scroll behavior, async safety
- [docs/LOCALIZATION.md](docs/LOCALIZATION.md) — Localization guide: supported languages, adding translations
- [docs/TESTING.md](docs/TESTING.md) — Testing: conventions, shared helpers, fixtures, adding tests
- [CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guidelines
- [LICENSE](LICENSE) — MIT License
