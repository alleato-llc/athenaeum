import Testing
import Foundation
@testable import Athenaeum

@Suite("BookRepository")
struct BookRepositoryTests {
    // MARK: - Insert & Fetch

    @Test("Insert and fetch a book with one author")
    func insertAndFetch() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Don Quixote"),
                         authors: [Author(name: "Cervantes")])

        let results = try env.bookRepo.fetchAll()
        #expect(results.count == 1)
        #expect(results[0].book.title == "Don Quixote")
        #expect(results[0].authors.count == 1)
        #expect(results[0].authors[0].name == "Cervantes")
    }

    @Test("Insert book with multiple authors")
    func multipleAuthors() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Good Omens"),
                         authors: [Author(name: "Terry Pratchett"), Author(name: "Neil Gaiman")])

        let authors = try env.bookRepo.fetchAuthors(forBookId: "b1")
        #expect(authors.count == 2)
        let names = Set(authors.map(\.name))
        #expect(names.contains("Terry Pratchett"))
        #expect(names.contains("Neil Gaiman"))
    }

    @Test("Insert book with no authors")
    func noAuthors() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Anonymous"), authors: [])

        let results = try env.bookRepo.fetchAll()
        #expect(results.count == 1)
        #expect(results[0].authors.isEmpty)
    }

    // MARK: - Search

    @Test("Search by title")
    func searchByTitle() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])
        try env.bookRepo.insert(book: TestData.makeBook(id: "b2", title: "Moby Dick"), authors: [Author(name: "Melville")])

        let results = try env.bookRepo.search(query: "Quixote")
        #expect(results.count == 1)
        #expect(results[0].book.title == "Don Quixote")
    }

    @Test("Search by author")
    func searchByAuthor() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])
        try env.bookRepo.insert(book: TestData.makeBook(id: "b2", title: "Moby Dick"), authors: [Author(name: "Melville")])

        let results = try env.bookRepo.search(query: "Melville")
        #expect(results.count == 1)
        #expect(results[0].book.title == "Moby Dick")
    }

    @Test("Search returns empty for no match")
    func searchNoResults() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])

        let results = try env.bookRepo.search(query: "nonexistent")
        #expect(results.isEmpty)
    }

    // MARK: - Duplicate Detection

    @Test("Detects duplicate by title and author")
    func duplicateDetection() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])

        #expect(try env.bookRepo.bookExists(title: "Don Quixote", authorNames: ["Cervantes"]) == true)
    }

    @Test("Duplicate detection is case insensitive")
    func duplicateCaseInsensitive() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])

        #expect(try env.bookRepo.bookExists(title: "don quixote", authorNames: ["cervantes"]) == true)
    }

    @Test("No false positive for different book")
    func noDuplicateForDifferentBook() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Don Quixote"), authors: [Author(name: "Cervantes")])

        #expect(try env.bookRepo.bookExists(title: "Moby Dick", authorNames: ["Melville"]) == false)
    }

    @Test("Duplicate detection works with no authors")
    func duplicateNoAuthors() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Anonymous"), authors: [])

        #expect(try env.bookRepo.bookExists(title: "Anonymous", authorNames: []) == true)
    }

    // MARK: - Update

    @Test("Update book title and authors")
    func updateBook() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        let book = TestData.makeBook(id: "b1", title: "Old Title")
        try env.bookRepo.insert(book: book, authors: [Author(name: "Author")])

        var updated = book
        updated.title = "New Title"
        try env.bookRepo.update(book: updated, authors: [Author(name: "New Author")])

        let results = try env.bookRepo.fetchAll()
        #expect(results.count == 1)
        #expect(results[0].book.title == "New Title")
        #expect(results[0].authors[0].name == "New Author")
    }

    @Test("Update file and cover paths")
    func updatePaths() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Book",
                                        filePath: "/old/path.epub", coverPath: "/old/cover.jpg"),
                         authors: [])

        try env.bookRepo.updatePaths(bookId: "b1", filePath: "/new/path.epub", coverPath: "/new/cover.jpg")

        let results = try env.bookRepo.fetchAll()
        #expect(results[0].book.filePath == "/new/path.epub")
        #expect(results[0].book.coverPath == "/new/cover.jpg")
    }

    // MARK: - Delete

    @Test("Delete removes book from database")
    func deleteBook() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Book"), authors: [Author(name: "Author")])
        #expect(try env.bookRepo.fetchAll().count == 1)

        try env.bookRepo.delete(bookId: "b1")
        #expect(try env.bookRepo.fetchAll().isEmpty)
    }

    @Test("Delete cascades to book_authors links")
    func deleteCascades() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Book"), authors: [Author(name: "Author")])
        try env.bookRepo.delete(bookId: "b1")

        let authors = try env.bookRepo.fetchAuthors(forBookId: "b1")
        #expect(authors.isEmpty)
    }

    // MARK: - Reading Progress

    @Test("Save and load reading progress")
    func readingProgress() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.bookRepo.insert(book: TestData.makeBook(id: "b1", title: "Book"), authors: [])
        try env.bookRepo.saveProgress(bookId: "b1", chapterIndex: 5, scrollPosition: 0.75)

        let results = try env.bookRepo.fetchAll()
        #expect(results[0].book.readingPosition?.chapter == 5)
        #expect(results[0].book.readingPosition?.scroll == 0.75)
    }
}
