import Testing
import Foundation
@testable import Athenaeum
import Ligature

@Suite("BookmarkRepository")
struct BookmarkRepositoryTests {
    @Test("Add and load bookmark")
    func addAndLoadBookmark() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let bookmark = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 3,
                                                         scrollPosition: 0.5, label: "Page 42")

        let loaded = try env.bookmarkRepo.loadAllBookmarks(bookId: "book1")
        #expect(loaded.count == 1)
        #expect(loaded[0].id == bookmark.id)
        #expect(loaded[0].label == "Page 42")
        #expect(loaded[0].scrollPosition == 0.5)
        #expect(loaded[0].chapterIndex == 3)
    }

    @Test("Add multiple bookmarks across chapters")
    func addMultipleBookmarks() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        _ = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 0, scrollPosition: 0.0, label: "Start")
        _ = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 3, scrollPosition: 0.5, label: "Middle")
        _ = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 9, scrollPosition: 1.0, label: "End")

        let loaded = try env.bookmarkRepo.loadAllBookmarks(bookId: "book1")
        #expect(loaded.count == 3)
    }

    @Test("Bookmarks ordered by creation")
    func bookmarksOrderedByCreation() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        _ = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 0, scrollPosition: 0.0, label: "First")
        _ = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 1, scrollPosition: 0.5, label: "Second")
        _ = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 2, scrollPosition: 1.0, label: "Third")

        let loaded = try env.bookmarkRepo.loadAllBookmarks(bookId: "book1")
        #expect(loaded[0].label == "First")
        #expect(loaded[1].label == "Second")
        #expect(loaded[2].label == "Third")
    }

    @Test("Delete bookmark")
    func deleteBookmark() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let bm1 = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 0, scrollPosition: 0.0, label: "Keep")
        let bm2 = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 1, scrollPosition: 0.5, label: "Delete")

        try env.bookmarkRepo.deleteBookmark(id: bm2.id)

        let loaded = try env.bookmarkRepo.loadAllBookmarks(bookId: "book1")
        #expect(loaded.count == 1)
        #expect(loaded[0].id == bm1.id)
        #expect(loaded[0].label == "Keep")
    }

    @Test("Load bookmarks for empty book returns empty array")
    func loadBookmarksEmptyBook() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let loaded = try env.bookmarkRepo.loadAllBookmarks(bookId: "book1")
        #expect(loaded.isEmpty)
    }

    @Test("Bookmark fields round-trip correctly")
    func bookmarkFieldsRoundTrip() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let bookmark = try env.bookmarkRepo.addBookmark(bookId: "book1", chapterIndex: 7,
                                                         scrollPosition: 0.333, label: "Important passage")

        let loaded = try env.bookmarkRepo.loadAllBookmarks(bookId: "book1")
        #expect(loaded.count == 1)
        #expect(loaded[0].id == bookmark.id)
        #expect(loaded[0].chapterIndex == 7)
        #expect(loaded[0].scrollPosition == 0.333)
        #expect(loaded[0].label == "Important passage")
        #expect(loaded[0].createdAt.timeIntervalSince1970 > 0)
    }
}
