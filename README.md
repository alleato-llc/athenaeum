# Athenaeum

A macOS EPUB reader and library manager built with Swift and SwiftUI. Zero external dependencies.

![Library](./docs/photos/library.png)

## Apps

- **Athenaeum** — Personal book library. Import, browse, search, and manage your EPUB collection. Grid and table views, metadata editing, cover art, and configurable theme palettes.
- **Octavo** — Standalone EPUB reader. Open files via file picker or drag-and-drop, navigate chapters, customize fonts and zoom, and cycle between light, dark, and system themes.

## Features

### Reader
- EPUB 2 (NCX) and EPUB 3 (nav) table of contents support
- Chapter and page navigation with keyboard shortcuts (left/right arrow keys)
- Customizable font family and page zoom
- Font pairing — curated header/body font combinations for improved typography
- 10 named theme palettes (5 light, 5 dark) with three-mode toggle: light / dark / system
- Collapsible table of contents sidebar
- Auto-hiding toolbar and navigation bar for distraction-free reading
- Reading progress indicator with per-chapter page counting
- Scroll position memory across chapters

![Reader](./docs/photos/reader.png)

### Annotations (Athenaeum only)

When reading a book opened from the library, the full annotation toolkit is available:

- **Highlighting** — Select text to highlight in 5 colors (yellow, green, blue, pink, orange). Eraser mode to remove individual highlights or erase all on the current page.
- **Bookmarks** — Save chapter position with label, browse all bookmarks, click to navigate.
- **Chapter notes** — Free-form text notes per chapter.
- **Inline notes** — Notes anchored to selected text, highlighted in purple. View, edit, or delete by clicking.
- **Undo/redo** — Cmd+Z / Shift+Cmd+Z for all annotation actions (highlights, notes, bookmarks).

All annotations persist across sessions in the database.

### Library
- Import EPUBs with automatic metadata and cover extraction
- Import from directory — bulk-import all EPUBs from a folder with progress and summary
- Duplicate import prevention (same title + author)
- Grid view with cover thumbnails or table view with sortable columns
- Search by title or author
- Edit metadata and replace cover art
- Export as PDF — render EPUB to PDF with table of contents outline and caching
- Review chapter notes — browse all notes for a book without opening the reader
- Library export/import — back up or restore your entire library as a single `.athenaeumlib` file
- Configurable default light and dark themes with color previews
- Author/title directory layout for organized book storage
- Localized for English, Spanish, and Italian

![Settings](./docs/photos/settings.png)

## Requirements

- macOS 13.0+
- Swift 5.9+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (for generating the Xcode project)

## Build & Run

### Xcode (recommended)

```sh
xcodegen generate        # Generate Athenaeum.xcodeproj from project.yml
open Athenaeum.xcodeproj # Open in Xcode, select Athenaeum or Octavo scheme
```

### Command line

```sh
swift build            # Build all targets
swift run Octavo       # Run the EPUB reader
swift run Athenaeum    # Run the library app
swift test             # Run tests
```

## Project Structure

```
Athenaeum/       # Library app (com.alleato.athenaeum)
Octavo/          # EPUB reader app (com.alleato.octavo)
Forma/           # Shared UI library: reader views, theme management
Ligature/        # Shared backend library: EPUB parsing, core models
Tests/           # Test suites
docs/            # Documentation
project.yml      # Xcode project spec (xcodegen)
```

Both app targets depend on **Forma**, which depends on **Ligature**. SQLite is linked only by the Athenaeum target.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Architecture and component documentation
- [docs/DATABASE.md](docs/DATABASE.md) — Database schema, storage layout, migrations
- [docs/LIBRARY.md](docs/LIBRARY.md) — Library feature guide
- [docs/FONTS.md](docs/FONTS.md) — Font system and font pairing
- [docs/IMPORT_EXPORT.md](docs/IMPORT_EXPORT.md) — Library backup/restore, directory import
- [docs/LOCALIZATION.md](docs/LOCALIZATION.md) — Localization guide
- [docs/TESTING.md](docs/TESTING.md) — Testing conventions and fixtures

## Naming

- **Athenaeum** — from the Latin *athenaeum*, a place for reading and scholarly pursuit. The library/catalog app.
- **Octavo** — a traditional book size format where pages are folded into eighths. The standalone EPUB reader.
- **Forma** — Latin for form or shape. The shared UI layer giving visual form to the reading experience.
- **Ligature** — a typographic term for joined characters. The shared backend library connecting both apps.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
