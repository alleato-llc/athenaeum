import Testing
import Foundation
@testable import Athenaeum

@Suite("BookImporter")
struct BookImporterTests {
    private let fm = FileManager.default

    private func makeTestEnv() throws -> (BookImporter, BookRepository, String) {
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("athenaeum-test-\(UUID().uuidString)")
        let libraryPath = tempDir.path
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dbPath = tempDir.appendingPathComponent("library.db").path
        let db = try LibraryDatabase(path: dbPath)
        let repo = BookRepository(database: db)
        let importer = BookImporter(bookRepository: repo, libraryPath: libraryPath)
        return (importer, repo, libraryPath)
    }

    /// Creates a book file on disk in the new directory layout and inserts it into the database.
    @discardableResult
    private func createBookOnDisk(repo: BookRepository, libraryPath: String,
                                   id: String, title: String, authorName: String,
                                   withCover: Bool = false) throws -> (LibraryBook, String, String?) {
        let pathBuilder = BookPathBuilder(libraryPath: libraryPath)
        let bookDir = pathBuilder.bookDirectory(authorName: authorName, title: title)
        try fm.createDirectory(atPath: bookDir, withIntermediateDirectories: true)

        let bookPath = pathBuilder.bookFilePath(authorName: authorName, title: title,
                                                bookId: id, fileExtension: "epub")
        try "fake epub content".write(toFile: bookPath, atomically: true, encoding: .utf8)

        var coverPath: String?
        if withCover {
            let cp = pathBuilder.coverFilePath(authorName: authorName, title: title, bookId: id)
            try "fake cover".write(toFile: cp, atomically: true, encoding: .utf8)
            coverPath = cp
        }

        let book = LibraryBook(id: id, title: title, format: .epub,
                               coverPath: coverPath, filePath: bookPath)
        try repo.insert(book: book, authors: [Author(name: authorName)])
        return (book, bookPath, coverPath)
    }

    // MARK: - Delete removes files from filesystem

    @Test("Delete removes book file from disk")
    func deleteRemovesFile() throws {
        let (importer, repo, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let (book, bookPath, _) = try createBookOnDisk(repo: repo, libraryPath: libraryPath,
                                                        id: "b1", title: "Test Book",
                                                        authorName: "Test Author")

        #expect(fm.fileExists(atPath: bookPath), "Book file should exist before delete")

        try importer.deleteBook(book)

        #expect(!fm.fileExists(atPath: bookPath), "Book file should be removed after delete")
    }

    @Test("Delete removes cover file from disk")
    func deleteRemovesCover() throws {
        let (importer, repo, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let (book, _, coverPath) = try createBookOnDisk(repo: repo, libraryPath: libraryPath,
                                                         id: "b1", title: "Test Book",
                                                         authorName: "Test Author",
                                                         withCover: true)

        #expect(fm.fileExists(atPath: coverPath!), "Cover should exist before delete")

        try importer.deleteBook(book)

        #expect(!fm.fileExists(atPath: coverPath!), "Cover should be removed after delete")
    }

    @Test("Delete cleans up empty parent directories")
    func deleteRemovesEmptyDirectories() throws {
        let (importer, repo, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let (book, _, _) = try createBookOnDisk(repo: repo, libraryPath: libraryPath,
                                                 id: "b1", title: "Test Book",
                                                 authorName: "Test Author")

        let pathBuilder = BookPathBuilder(libraryPath: libraryPath)
        let bookDir = pathBuilder.bookDirectory(authorName: "Test Author", title: "Test Book")

        try importer.deleteBook(book)

        // Title, author, and prefix directories should all be cleaned up
        #expect(!fm.fileExists(atPath: bookDir), "Empty title directory should be removed")

        let authorDir = (bookDir as NSString).deletingLastPathComponent
        #expect(!fm.fileExists(atPath: authorDir), "Empty author directory should be removed")

        let prefixDir = (authorDir as NSString).deletingLastPathComponent
        #expect(!fm.fileExists(atPath: prefixDir), "Empty prefix directory should be removed")
    }

    @Test("Delete preserves directories when other books remain")
    func deletePreservesSharedDirectories() throws {
        let (importer, repo, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let (book1, _, _) = try createBookOnDisk(repo: repo, libraryPath: libraryPath,
                                                  id: "b1", title: "Book One",
                                                  authorName: "Shared Author")
        let (_, bookPath2, _) = try createBookOnDisk(repo: repo, libraryPath: libraryPath,
                                                      id: "b2", title: "Book Two",
                                                      authorName: "Shared Author")

        try importer.deleteBook(book1)

        #expect(fm.fileExists(atPath: bookPath2), "Other book file should be preserved")

        let pathBuilder = BookPathBuilder(libraryPath: libraryPath)
        let authorDir = (pathBuilder.bookDirectory(authorName: "Shared Author", title: "Book Two") as NSString)
            .deletingLastPathComponent
        #expect(fm.fileExists(atPath: authorDir), "Author directory should be preserved")
    }

    @Test("Delete removes book from database")
    func deleteRemovesFromDatabase() throws {
        let (importer, repo, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let (book, _, _) = try createBookOnDisk(repo: repo, libraryPath: libraryPath,
                                                 id: "b1", title: "Test Book",
                                                 authorName: "Test Author")

        try importer.deleteBook(book)

        #expect(try repo.fetchAll().isEmpty, "Book should be removed from database")
    }

    @Test("Delete tolerates missing files on disk")
    func deleteHandlesMissingFile() throws {
        let (importer, repo, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let book = LibraryBook(id: "b1", title: "Ghost Book", format: .epub,
                               filePath: "/nonexistent/path.epub")
        try repo.insert(book: book, authors: [])

        // Should not throw
        try importer.deleteBook(book)

        #expect(try repo.fetchAll().isEmpty)
    }

    // MARK: - Import validation

    @Test("Import rejects unsupported file format")
    func importRejectsUnsupported() throws {
        let (importer, _, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let tempFile = fm.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).docx")
        fm.createFile(atPath: tempFile.path, contents: "test".data(using: .utf8))
        defer { try? fm.removeItem(at: tempFile) }

        #expect(throws: ImportError.self) {
            try importer.importBook(from: tempFile)
        }
    }

    // MARK: - Storage layout migration

    @Test("Migration moves files from flat layout to author/title structure")
    func migrateMovesFiles() throws {
        let (importer, repo, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        // Simulate old flat layout
        let bookId = "old-book-id"
        let oldBooksDir = (libraryPath as NSString).appendingPathComponent("books")
        let oldCoversDir = (libraryPath as NSString).appendingPathComponent("covers")
        try fm.createDirectory(atPath: oldBooksDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: oldCoversDir, withIntermediateDirectories: true)

        let oldBookPath = (oldBooksDir as NSString).appendingPathComponent("\(bookId).epub")
        let oldCoverPath = (oldCoversDir as NSString).appendingPathComponent("\(bookId).jpg")
        try "fake epub".write(toFile: oldBookPath, atomically: true, encoding: .utf8)
        try "fake cover".write(toFile: oldCoverPath, atomically: true, encoding: .utf8)

        let book = LibraryBook(id: bookId, title: "Old Book", format: .epub,
                               coverPath: oldCoverPath, filePath: oldBookPath)
        try repo.insert(book: book, authors: [Author(name: "Old Author")])

        // Run migration
        importer.migrateStorageLayout(books: try repo.fetchAll())

        // Verify new paths
        let pathBuilder = BookPathBuilder(libraryPath: libraryPath)
        let newBookPath = pathBuilder.bookFilePath(authorName: "Old Author", title: "Old Book",
                                                    bookId: bookId, fileExtension: "epub")
        let newCoverPath = pathBuilder.coverFilePath(authorName: "Old Author", title: "Old Book",
                                                      bookId: bookId)

        #expect(fm.fileExists(atPath: newBookPath), "Book should be at new path")
        #expect(fm.fileExists(atPath: newCoverPath), "Cover should be at new path")
        #expect(!fm.fileExists(atPath: oldBookPath), "Old book path should be gone")
        #expect(!fm.fileExists(atPath: oldCoverPath), "Old cover path should be gone")

        // Verify database updated
        let updated = try repo.fetchAll()
        #expect(updated[0].book.filePath == newBookPath)
        #expect(updated[0].book.coverPath == newCoverPath)
    }

    @Test("Migration skips books already at new path")
    func migrateSkipsAlreadyMigrated() throws {
        let (importer, repo, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let (_, bookPath, _) = try createBookOnDisk(repo: repo, libraryPath: libraryPath,
                                                     id: "b1", title: "Already New",
                                                     authorName: "Author")

        importer.migrateStorageLayout(books: try repo.fetchAll())

        #expect(fm.fileExists(atPath: bookPath))
        #expect(try repo.fetchAll()[0].book.filePath == bookPath)
    }

    @Test("Migration cleans up empty covers directory")
    func migrateCleansUpCoversDir() throws {
        let (importer, _, libraryPath) = try makeTestEnv()
        defer { try? fm.removeItem(atPath: libraryPath) }

        let oldCoversDir = (libraryPath as NSString).appendingPathComponent("covers")
        try fm.createDirectory(atPath: oldCoversDir, withIntermediateDirectories: true)

        importer.migrateStorageLayout(books: [])

        #expect(!fm.fileExists(atPath: oldCoversDir), "Empty covers/ should be cleaned up")
    }
}
