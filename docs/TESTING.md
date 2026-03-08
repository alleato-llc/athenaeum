# Testing

## Overview

The project uses **Swift Testing** (`@Suite`, `@Test`, `#expect()`) for all tests. Tests run against real SQLite databases in temp directories and real EPUB fixtures from Project Gutenberg — no mocks or stubs.

## Running Tests

```sh
swift test                    # All AthenaeumTests (root package)
cd Ligature && swift test     # LigatureTests (Ligature package)
```

## Test Structure

```
Tests/AthenaeumTests/
├── TestHelpers.swift                  # Shared setup: TestDatabase, TestImportEnvironment, TestData, TestFixtures
├── Resources/                         # EPUB fixtures (copied into bundle)
│   ├── a-christmas-carol.epub
│   ├── metamorphosis.epub
│   ├── the-yellow-wallpaper.epub
│   └── frankenstein.epub
├── BookRepositoryTests.swift          # Book CRUD, search, duplicate detection
├── ChapterRepositoryTests.swift       # Chapter row creation, idempotency
├── HighlightRepositoryTests.swift     # Highlight save/load, JSON round-trip
├── BookmarkRepositoryTests.swift      # Bookmark add/delete/load
├── NoteRepositoryTests.swift          # Chapter notes + inline notes
├── SettingsRepositoryTests.swift      # Key-value store, UserSettings round-trip
├── BookImporterTests.swift            # Delete cleanup, migration, import validation
├── ImportIntegrationTests.swift       # End-to-end: EPUB → import → DB + filesystem
├── DirectoryScannerTests.swift        # Bulk directory scan and import
├── EPUBMetadataExtractorTests.swift   # Metadata extraction from real EPUBs
├── EPUBCoverExtractorTests.swift      # Cover extraction, JPEG validation
└── BookPathBuilderTests.swift         # Path sanitization and directory layout

Ligature/Tests/LigatureTests/
├── Resources/                         # Same EPUB fixtures (separate package)
│   └── *.epub
└── EPUBParserTests.swift              # Core EPUB parser: parse, spine, TOC, cleanup
```

## Shared Test Helpers

All shared setup lives in `Tests/AthenaeumTests/TestHelpers.swift`:

### `TestDatabase`

Creates a fresh SQLite database in a temp directory with all repositories pre-initialized.

```swift
let env = try TestDatabase.create()       // Fresh DB
let env = try TestDatabase.createWithBook() // DB with a pre-inserted book (for FK-dependent tests)
defer { env.cleanup() }

// Access repos via named properties:
env.bookRepo, env.chapterRepo, env.highlightRepo,
env.bookmarkRepo, env.noteRepo, env.settingsRepo
```

### `TestImportEnvironment`

Creates a temp library directory with a `BookImporter` and `BookRepository`.

```swift
let env = try TestImportEnvironment.create()
defer { env.cleanup() }

env.importer    // BookImporter
env.bookRepo    // BookRepository
env.libraryPath // Temp library directory
env.makeScanner() // DirectoryScanner using this env's importer
```

### `TestData`

Factory methods for creating model instances with sensible defaults:

```swift
TestData.makeBook(id: "b1", title: "My Book")
TestData.makeHighlight(id: "h1", text: "selected text", color: "blue")
TestData.makeInlineNote(id: "n1", text: "anchor", note: "my note")
```

### `TestFixtures`

EPUB fixture loading via `Bundle.module`:

```swift
TestFixtures.epubURL("frankenstein")       // URL to fixture in bundle
TestFixtures.copyToTemp("frankenstein")    // Copy to temp dir (for import tests)
```

## Test Fixtures

Four public-domain EPUBs from Project Gutenberg serve as integration test fixtures:

| Fixture | Book | Why |
|---------|------|-----|
| `a-christmas-carol.epub` | A Christmas Carol (Dickens) | Standard EPUB3 with TOC |
| `metamorphosis.epub` | Metamorphosis (Kafka) | Short, minimal metadata |
| `the-yellow-wallpaper.epub` | The Yellow Wallpaper (Gilman) | Very short EPUB |
| `frankenstein.epub` | Frankenstein (Shelley) | Multi-chapter, >10 spine items |

Fixtures are stored in both `Tests/AthenaeumTests/Resources/` and `Ligature/Tests/LigatureTests/Resources/` because separate Swift packages cannot share test resources. Both `Package.swift` files declare `.copy("Resources")` to include them in the test bundle.

## Conventions

- **No mocks.** Tests use real SQLite databases in temp directories and real EPUB files.
- **Each test is self-contained.** No shared mutable state between tests. Each test creates its own `TestDatabase` or `TestImportEnvironment`.
- **Cleanup via `defer`.** Every test cleans up its temp directory: `defer { env.cleanup() }`.
- **FK constraints.** Repository tests that depend on a book row (chapters, highlights, bookmarks, notes) use `TestDatabase.createWithBook()` to satisfy foreign key constraints.

## Adding Tests

1. Create a new file in `Tests/AthenaeumTests/` (or `Ligature/Tests/LigatureTests/` for parser/model tests).
2. Use `@Suite("Name")` and `@Test("description")` annotations.
3. Use the shared helpers from `TestHelpers.swift` for setup.
4. For new EPUB fixtures, add them to both `Resources/` directories and access via `TestFixtures.epubURL(_:)`.
