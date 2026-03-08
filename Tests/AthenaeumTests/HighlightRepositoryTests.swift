import Testing
import Foundation
@testable import Athenaeum
import Ligature

@Suite("HighlightRepository")
struct HighlightRepositoryTests {
    @Test("Save and load highlights round-trip")
    func saveAndLoadHighlights() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let highlights = [TestData.makeHighlight(id: "h1", text: "first"),
                          TestData.makeHighlight(id: "h2", text: "second")]
        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 0, highlights: highlights)

        let loaded = try env.highlightRepo.loadHighlights(bookId: "book1", chapterIndex: 0)
        #expect(loaded.count == 2)
        #expect(loaded[0].text == "first")
        #expect(loaded[1].text == "second")
    }

    @Test("Load highlights for empty chapter returns empty array")
    func loadHighlightsEmptyChapter() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 0, highlights: [TestData.makeHighlight()])
        let loaded = try env.highlightRepo.loadHighlights(bookId: "book1", chapterIndex: 1)
        #expect(loaded.isEmpty)
    }

    @Test("Load highlights for nonexistent chapter returns empty array")
    func loadHighlightsNonexistentChapter() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let loaded = try env.highlightRepo.loadHighlights(bookId: "book1", chapterIndex: 99)
        #expect(loaded.isEmpty)
    }

    @Test("Save empty highlights clears data")
    func saveEmptyHighlightsClearsData() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 0, highlights: [TestData.makeHighlight()])
        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 0, highlights: [])

        let loaded = try env.highlightRepo.loadHighlights(bookId: "book1", chapterIndex: 0)
        #expect(loaded.isEmpty)
    }

    @Test("Overwrite highlights replaces previous")
    func overwriteHighlights() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 0,
                                              highlights: [TestData.makeHighlight(id: "h1", text: "old")])
        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 0,
                                              highlights: [TestData.makeHighlight(id: "h2", text: "new")])

        let loaded = try env.highlightRepo.loadHighlights(bookId: "book1", chapterIndex: 0)
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "h2")
        #expect(loaded[0].text == "new")
    }

    @Test("Load all highlights across multiple chapters")
    func loadAllHighlightsMultipleChapters() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 0,
                                              highlights: [TestData.makeHighlight(id: "h0")])
        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 2,
                                              highlights: [TestData.makeHighlight(id: "h2a"),
                                                           TestData.makeHighlight(id: "h2b")])
        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 5,
                                              highlights: [TestData.makeHighlight(id: "h5")])

        let all = try env.highlightRepo.loadAllHighlights(bookId: "book1")
        #expect(all.count == 3)
        #expect(all[0]?.count == 1)
        #expect(all[2]?.count == 2)
        #expect(all[5]?.count == 1)
    }

    @Test("Highlight fields round-trip correctly")
    func highlightFieldsRoundTrip() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let original = TestData.makeHighlight(id: "test-id", text: "highlighted text",
                                               startPath: "/html/body/div[2]/p[3]", startOffset: 5,
                                               endPath: "/html/body/div[2]/p[4]", endOffset: 12,
                                               color: "blue")
        try env.highlightRepo.saveHighlights(bookId: "book1", chapterIndex: 0, highlights: [original])

        let loaded = try env.highlightRepo.loadHighlights(bookId: "book1", chapterIndex: 0)
        #expect(loaded.count == 1)
        #expect(loaded[0] == original)
    }
}
