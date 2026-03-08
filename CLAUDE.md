# Athenaeum

A macOS EPUB reader and library manager built with Swift and SwiftUI. Zero external dependencies.

## Project Structure

Swift Package (swift-tools-version 5.9, macOS 13+) with two app targets and one shared library:

- **Athenaeum** (`Athenaeum/AthenaeumApp.swift`) — Library/catalog app. Import, browse, and manage books. Bundle ID: `com.alleato.athenaeum`.
- **Octavo** (`Octavo/OctavoApp.swift`) — EPUB reader app. Opens `.epub` files via file picker or drag-and-drop. Bundle ID: `com.alleato.octavo`.
- **Ligature** (`Ligature/`) — Shared library: EPUB parsing, reader UI, and view models.

### Xcode Project

The Xcode project is generated from `project.yml` using [xcodegen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate        # Generate Athenaeum.xcodeproj
open Athenaeum.xcodeproj # Open in Xcode
```

The `.xcodeproj` is gitignored — always regenerate from `project.yml`. Both app targets use automatic code signing and include App Sandbox entitlements with user-selected file read-write access.

### Ligature Layout

```
Ligature/Sources/Ligature/
├── Models/
│   ├── EPUBBook.swift          # Runtime model for reader (title, author, spine, TOC)
│   ├── EPUBMetadata.swift      # Metadata with EPUB 2/3 version enum
│   ├── LibraryBook.swift       # Persistent model (metadata, format, identifiers JSON)
│   ├── Author.swift            # Author model (many-to-many with books)
│   ├── UserSettings.swift      # Settings: library path, font, theme mode, theme IDs
│   └── ReadingTheme.swift      # Named theme palettes (light/dark), available fonts
├── Database/
│   ├── LibraryDatabase.swift   # SQLite connection, migrations
│   ├── BookRepository.swift    # CRUD for books + authors, search
│   └── SettingsRepository.swift # Key-value settings store
├── Import/
│   ├── BookImporter.swift      # Orchestrates: copy file, extract metadata/cover, insert
│   ├── MetadataExtractor.swift # Protocol + EPUB extractor + fallback
│   └── CoverExtractor.swift    # Protocol + EPUB cover extractor
├── Parser/
│   ├── EPUBParser.swift        # Top-level: extract zip, parse OPF, build EPUBBook
│   ├── ContainerXMLParser.swift
│   ├── OPFParser.swift
│   └── TOCParser.swift         # EPUB2 (NCX) and EPUB3 (nav) parsers
├── Views/
│   ├── ReaderView.swift        # Reader: sidebar, auto-hiding toolbar/nav bar
│   ├── ReaderViewModel.swift   # Chapter nav, font/zoom, page counting
│   ├── ThemeManager.swift      # Theme resolution, CSS injection, system appearance KVO
│   ├── EPUBWebView.swift       # WKWebView wrapper for rendering chapters
│   ├── LibraryView.swift       # Library: toolbar, empty state, drag-and-drop
│   ├── LibraryViewModel.swift  # Library business logic: import, delete, search
│   ├── BookGridView.swift      # Scrollable grid of cover thumbnails
│   ├── BookTableView.swift     # Table: title, author, year, format, genre
│   ├── BookEditView.swift      # Metadata edit sheet with cover replacement
│   └── SettingsView.swift      # Settings: library path, font, theme
└── Resources/
    └── {en,es,it}.lproj/       # Localized strings
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
swift run Octavo       # Run the standalone EPUB reader
swift run Athenaeum    # Run the library app
```

## Key Technical Details

- EPUB extraction uses `/usr/bin/unzip` via `Process` to a temp directory.
- Chapter content rendered in `WKWebView` with local file access enabled.
- Styling injected via JavaScript: font family forced with `* { font-family: inherit !important }`.
- Page zoom via `WKWebView.pageZoom` (single unified zoom, no separate font size control).
- EPUB 2 (NCX) and EPUB 3 (nav) TOC supported, with EPUB 3 falling back to NCX.
- Toolbar and navigation bar auto-hide, revealed on hover at top/bottom edges.
- Keyboard navigation: left/right arrow keys navigate by page or chapter depending on mode.
- Page/chapter navigation mode toggled by double-clicking the mode label in the nav bar.
- Global page count computed via background `WKWebView` measurement of all chapters.
- Window title bar shows reading progress percentage (e.g., "Octavo | 42% Complete").
- All XML parsing uses Foundation `XMLParser` (SAX-style).
- SQLite via C API (`libsqlite3`), linked in Ligature's Package.swift. No ORM.
- Library data stored at `~/Library/Application Support/Athenaeum/` (library.db, books/, covers/).
- No business logic in views — views delegate to view models and services.
- Zero external dependencies.

## Architectural Rules

These rules must be followed in all code changes:

1. **No business logic in UI.** Views must not contain domain logic, data transformations, or service calls. Views delegate to view models and services. Domain data (e.g., font lists, theme definitions) belongs on models or services, not view models.

2. **Single responsibility.** Each class/struct handles one concern and composes with others for cross-cutting behavior. For example, `ThemeManager` owns theme resolution and CSS injection; `ReaderViewModel` composes with it rather than owning theme logic directly.

3. **No external dependencies.** All functionality must use Foundation, AppKit, SwiftUI, WebKit, and the system SQLite C API only.

4. **Format-agnostic models.** Library models (e.g., `LibraryBook`, `BookFormat`) support multiple formats. Reader-specific logic is separate.

5. **Service-layer validation.** Input validation and duplicate checks happen in service/repository layers, not in views or view models.

## Localization

The app is localized for English, Spanish, and Italian using `.strings` files. Each target (Ligature, Octavo, Athenaeum) has its own localization resources under a `Resources/` directory.

See [docs/LOCALIZATION.md](docs/LOCALIZATION.md) for details on adding languages and strings.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Detailed architecture and component documentation
- [docs/DATABASE.md](docs/DATABASE.md) — Database: technology choices, schema, storage layout, migrations
- [docs/LIBRARY.md](docs/LIBRARY.md) — Library feature: usage, relevant files, maintenance guide
- [docs/LOCALIZATION.md](docs/LOCALIZATION.md) — Localization guide: supported languages, adding translations
- [CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guidelines
- [LICENSE](LICENSE) — MIT License
