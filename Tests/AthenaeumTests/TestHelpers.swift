import Foundation
@testable import Athenaeum
import Ligature

/// Shared test environment providing a temporary database directory and all repositories.
struct TestDatabase {
    let db: LibraryDatabase
    let bookRepo: BookRepository
    let chapterRepo: ChapterRepository
    let highlightRepo: HighlightRepository
    let bookmarkRepo: BookmarkRepository
    let noteRepo: NoteRepository
    let settingsRepo: SettingsRepository
    let dirPath: String

    /// Creates a fresh SQLite database in a temp directory with all repositories initialized.
    /// Caller is responsible for cleanup via `cleanup()`.
    static func create() throws -> TestDatabase {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("athenaeum-test-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("test.db").path
        let db = try LibraryDatabase(path: dbPath)
        let bookRepo = BookRepository(database: db)
        let chapterRepo = ChapterRepository(database: db)
        let highlightRepo = HighlightRepository(database: db, chapterRepository: chapterRepo)
        let bookmarkRepo = BookmarkRepository(database: db, chapterRepository: chapterRepo)
        let noteRepo = NoteRepository(database: db, chapterRepository: chapterRepo)
        let settingsRepo = SettingsRepository(database: db)
        return TestDatabase(db: db, bookRepo: bookRepo, chapterRepo: chapterRepo,
                            highlightRepo: highlightRepo, bookmarkRepo: bookmarkRepo,
                            noteRepo: noteRepo, settingsRepo: settingsRepo,
                            dirPath: tempDir.path)
    }

    /// Creates a TestDatabase with a single test book pre-inserted (for FK-dependent tests).
    static func createWithBook(id: String = "book1", title: String = "Test Book") throws -> TestDatabase {
        let env = try create()
        let book = TestData.makeBook(id: id, title: title)
        try env.bookRepo.insert(book: book, authors: [])
        return env
    }

    func cleanup() {
        try? FileManager.default.removeItem(atPath: dirPath)
    }
}

/// Shared test environment for import/scanner tests, providing an importer and library path.
struct TestImportEnvironment {
    let importer: BookImporter
    let bookRepo: BookRepository
    let libraryPath: String

    static func create() throws -> TestImportEnvironment {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("athenaeum-test-\(UUID().uuidString)")
        let libraryPath = tempDir.path
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("library.db").path
        let db = try LibraryDatabase(path: dbPath)
        let repo = BookRepository(database: db)
        let importer = BookImporter(bookRepository: repo, libraryPath: libraryPath)
        return TestImportEnvironment(importer: importer, bookRepo: repo, libraryPath: libraryPath)
    }

    func cleanup() {
        try? FileManager.default.removeItem(atPath: libraryPath)
    }

    func makeScanner() -> DirectoryScanner {
        DirectoryScanner(bookImporter: importer)
    }
}

/// Test data factories for creating model instances with sensible defaults.
enum TestData {
    static func makeBook(id: String = UUID().uuidString, title: String = "Test Book",
                          filePath: String = "/tmp/test.epub",
                          coverPath: String? = nil) -> LibraryBook {
        LibraryBook(id: id, title: title, format: .epub,
                    coverPath: coverPath, filePath: filePath)
    }

    static func makeHighlight(id: String = UUID().uuidString, text: String = "sample",
                                startPath: String = "/html/body/p[1]", startOffset: Int = 0,
                                endPath: String = "/html/body/p[1]", endOffset: Int = 10,
                                color: String = "yellow") -> Highlight {
        Highlight(id: id, text: text, startPath: startPath, startOffset: startOffset,
                  endPath: endPath, endOffset: endOffset, color: color)
    }

    static func makeInlineNote(id: String = UUID().uuidString, text: String = "selected",
                                note: String = "my note",
                                startPath: String = "/html/body/p[1]", startOffset: Int = 0,
                                endPath: String = "/html/body/p[1]", endOffset: Int = 8,
                                createdAt: Date = Date(timeIntervalSince1970: 1700000000)) -> InlineNote {
        InlineNote(id: id, text: text, note: note,
                   startPath: startPath, startOffset: startOffset,
                   endPath: endPath, endOffset: endOffset, createdAt: createdAt)
    }
}

/// EPUB fixture loading for tests using `Bundle.module` resources.
enum TestFixtures {
    static func epubURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: "epub", subdirectory: "Resources")!
    }

    /// Copy a fixture EPUB to a temp location (for import tests that consume the source file).
    static func copyToTemp(_ name: String) throws -> URL {
        let source = epubURL(name)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-\(UUID().uuidString)")
            .appendingPathComponent("\(name).epub")
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: dest)
        return dest
    }
}
