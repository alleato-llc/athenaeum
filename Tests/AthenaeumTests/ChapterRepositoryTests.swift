import Testing
import Foundation
@testable import Athenaeum

@Suite("ChapterRepository")
struct ChapterRepositoryTests {
    @Test("ensureChapter creates row and returns deterministic ID")
    func ensureChapterCreatesRow() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let chapterId = try env.chapterRepo.ensureChapter(bookId: "book1", chapterIndex: 0)
        #expect(chapterId == "book1-0")
    }

    @Test("ensureChapter is idempotent")
    func ensureChapterIsIdempotent() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let id1 = try env.chapterRepo.ensureChapter(bookId: "book1", chapterIndex: 0)
        let id2 = try env.chapterRepo.ensureChapter(bookId: "book1", chapterIndex: 0)
        #expect(id1 == id2)
    }

    @Test("ensureChapter creates multiple chapters")
    func ensureChapterMultipleChapters() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let id0 = try env.chapterRepo.ensureChapter(bookId: "book1", chapterIndex: 0)
        let id1 = try env.chapterRepo.ensureChapter(bookId: "book1", chapterIndex: 1)
        let id2 = try env.chapterRepo.ensureChapter(bookId: "book1", chapterIndex: 2)

        #expect(id0 == "book1-0")
        #expect(id1 == "book1-1")
        #expect(id2 == "book1-2")
    }

    @Test("chapterId generation matches expected format")
    func chapterIdGeneration() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        #expect(env.chapterRepo.chapterId(bookId: "book1", chapterIndex: 5) == "book1-5")
        #expect(env.chapterRepo.chapterId(bookId: "abc", chapterIndex: 99) == "abc-99")
    }

    @Test("ensureChapter for different books creates separate rows")
    func ensureChapterDifferentBooks() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        // Insert a second book
        let book2 = TestData.makeBook(id: "book2", title: "Second Book")
        try env.bookRepo.insert(book: book2, authors: [])

        let id1 = try env.chapterRepo.ensureChapter(bookId: "book1", chapterIndex: 0)
        let id2 = try env.chapterRepo.ensureChapter(bookId: "book2", chapterIndex: 0)

        #expect(id1 == "book1-0")
        #expect(id2 == "book2-0")
        #expect(id1 != id2)
    }
}
