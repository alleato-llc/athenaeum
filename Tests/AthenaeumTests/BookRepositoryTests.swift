import Testing
import Foundation
@testable import Athenaeum

@Suite("BookRepository")
struct BookRepositoryTests {
    private let fm = FileManager.default

    private func makeTempDB() throws -> (LibraryDatabase, BookRepository, String) {
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("athenaeum-test-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("test.db").path
        let db = try LibraryDatabase(path: dbPath)
        return (db, BookRepository(database: db), tempDir.path)
    }

    private func makeBook(id: String = UUID().uuidString, title: String,
                           filePath: String = "/tmp/test.epub",
                           coverPath: String? = nil) -> LibraryBook {
        LibraryBook(id: id, title: title, format: .epub,
                    coverPath: coverPath, filePath: filePath)
    }

    // MARK: - Insert & Fetch

    @Test("Insert and fetch a book with one author")
    func insertAndFetch() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Don Quixote"),
                         authors: [Author(name: "Cervantes")])

        let results = try repo.fetchAll()
        #expect(results.count == 1)
        #expect(results[0].book.title == "Don Quixote")
        #expect(results[0].authors.count == 1)
        #expect(results[0].authors[0].name == "Cervantes")
    }

    @Test("Insert book with multiple authors")
    func multipleAuthors() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Good Omens"),
                         authors: [Author(name: "Terry Pratchett"), Author(name: "Neil Gaiman")])

        let authors = try repo.fetchAuthors(forBookId: "b1")
        #expect(authors.count == 2)
        let names = Set(authors.map(\.name))
        #expect(names.contains("Terry Pratchett"))
        #expect(names.contains("Neil Gaiman"))
    }

    @Test("Insert book with no authors")
    func noAuthors() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Anonymous"), authors: [])

        let results = try repo.fetchAll()
        #expect(results.count == 1)
        #expect(results[0].authors.isEmpty)
    }

    // MARK: - Search

    @Test("Search by title")
    func searchByTitle() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])
        try repo.insert(book: makeBook(id: "b2", title: "Moby Dick"), authors: [Author(name: "Melville")])

        let results = try repo.search(query: "Quixote")
        #expect(results.count == 1)
        #expect(results[0].book.title == "Don Quixote")
    }

    @Test("Search by author")
    func searchByAuthor() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])
        try repo.insert(book: makeBook(id: "b2", title: "Moby Dick"), authors: [Author(name: "Melville")])

        let results = try repo.search(query: "Melville")
        #expect(results.count == 1)
        #expect(results[0].book.title == "Moby Dick")
    }

    @Test("Search returns empty for no match")
    func searchNoResults() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])

        let results = try repo.search(query: "nonexistent")
        #expect(results.isEmpty)
    }

    // MARK: - Duplicate Detection

    @Test("Detects duplicate by title and author")
    func duplicateDetection() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])

        #expect(try repo.bookExists(title: "Don Quixote", authorNames: ["Cervantes"]) == true)
    }

    @Test("Duplicate detection is case insensitive")
    func duplicateCaseInsensitive() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])

        #expect(try repo.bookExists(title: "don quixote", authorNames: ["cervantes"]) == true)
    }

    @Test("No false positive for different book")
    func noDuplicateForDifferentBook() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])

        #expect(try repo.bookExists(title: "Moby Dick", authorNames: ["Melville"]) == false)
    }

    @Test("Duplicate detection works with no authors")
    func duplicateNoAuthors() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Anonymous"), authors: [])

        #expect(try repo.bookExists(title: "Anonymous", authorNames: []) == true)
    }

    // MARK: - Update

    @Test("Update book title and authors")
    func updateBook() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        let book = makeBook(id: "b1", title: "Old Title")
        try repo.insert(book: book, authors: [Author(name: "Author")])

        var updated = book
        updated.title = "New Title"
        try repo.update(book: updated, authors: [Author(name: "New Author")])

        let results = try repo.fetchAll()
        #expect(results.count == 1)
        #expect(results[0].book.title == "New Title")
        #expect(results[0].authors[0].name == "New Author")
    }

    @Test("Update file and cover paths")
    func updatePaths() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Book",
                                        filePath: "/old/path.epub", coverPath: "/old/cover.jpg"),
                         authors: [])

        try repo.updatePaths(bookId: "b1", filePath: "/new/path.epub", coverPath: "/new/cover.jpg")

        let results = try repo.fetchAll()
        #expect(results[0].book.filePath == "/new/path.epub")
        #expect(results[0].book.coverPath == "/new/cover.jpg")
    }

    // MARK: - Delete

    @Test("Delete removes book from database")
    func deleteBook() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Book"), authors: [Author(name: "Author")])
        #expect(try repo.fetchAll().count == 1)

        try repo.delete(bookId: "b1")
        #expect(try repo.fetchAll().isEmpty)
    }

    @Test("Delete cascades to book_authors links")
    func deleteCascades() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Book"), authors: [Author(name: "Author")])
        try repo.delete(bookId: "b1")

        let authors = try repo.fetchAuthors(forBookId: "b1")
        #expect(authors.isEmpty)
    }

    // MARK: - Reading Progress

    @Test("Save and load reading progress")
    func readingProgress() throws {
        let (_, repo, dir) = try makeTempDB()
        defer { try? fm.removeItem(atPath: dir) }

        try repo.insert(book: makeBook(id: "b1", title: "Book"), authors: [])
        try repo.saveProgress(bookId: "b1", chapterIndex: 5, scrollPosition: 0.75)

        let results = try repo.fetchAll()
        #expect(results[0].book.readingPosition?.chapter == 5)
        #expect(results[0].book.readingPosition?.scroll == 0.75)
    }
}
