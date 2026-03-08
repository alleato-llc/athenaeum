import Testing
import Foundation
@testable import Athenaeum
import Ligature

@Suite("NoteRepository")
struct NoteRepositoryTests {
    // MARK: - Chapter Notes

    @Test("Save and load chapter notes")
    func saveAndLoadChapterNotes() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.noteRepo.saveChapterNotes(bookId: "book1", chapterIndex: 0, notes: "Chapter 1 notes here")

        let all = try env.noteRepo.loadAllChapterNotes(bookId: "book1")
        #expect(all[0] == "Chapter 1 notes here")
    }

    @Test("Save nil clears chapter notes")
    func saveNilClearsNotes() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.noteRepo.saveChapterNotes(bookId: "book1", chapterIndex: 0, notes: "Some notes")
        try env.noteRepo.saveChapterNotes(bookId: "book1", chapterIndex: 0, notes: nil)

        let all = try env.noteRepo.loadAllChapterNotes(bookId: "book1")
        #expect(all[0] == nil)
    }

    @Test("Save empty string clears chapter notes")
    func saveEmptyStringClearsNotes() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.noteRepo.saveChapterNotes(bookId: "book1", chapterIndex: 0, notes: "Some notes")
        try env.noteRepo.saveChapterNotes(bookId: "book1", chapterIndex: 0, notes: "")

        let all = try env.noteRepo.loadAllChapterNotes(bookId: "book1")
        #expect(all[0] == nil)
    }

    @Test("Load all chapter notes for multiple chapters")
    func loadAllChapterNotesMultipleChapters() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.noteRepo.saveChapterNotes(bookId: "book1", chapterIndex: 0, notes: "Note A")
        try env.noteRepo.saveChapterNotes(bookId: "book1", chapterIndex: 3, notes: "Note B")
        try env.noteRepo.saveChapterNotes(bookId: "book1", chapterIndex: 7, notes: "Note C")

        let all = try env.noteRepo.loadAllChapterNotes(bookId: "book1")
        #expect(all.count == 3)
        #expect(all[0] == "Note A")
        #expect(all[3] == "Note B")
        #expect(all[7] == "Note C")
    }

    // MARK: - Inline Notes

    @Test("Save and load inline notes")
    func saveAndLoadInlineNotes() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let notes = [TestData.makeInlineNote(id: "n1", text: "first"),
                     TestData.makeInlineNote(id: "n2", text: "second")]
        try env.noteRepo.saveInlineNotes(bookId: "book1", chapterIndex: 0, notes: notes)

        let all = try env.noteRepo.loadAllInlineNotes(bookId: "book1")
        #expect(all[0]?.count == 2)
        #expect(all[0]?[0].text == "first")
        #expect(all[0]?[1].text == "second")
    }

    @Test("Save empty inline notes clears data")
    func saveEmptyInlineNotesClearsData() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.noteRepo.saveInlineNotes(bookId: "book1", chapterIndex: 0, notes: [TestData.makeInlineNote()])
        try env.noteRepo.saveInlineNotes(bookId: "book1", chapterIndex: 0, notes: [])

        let all = try env.noteRepo.loadAllInlineNotes(bookId: "book1")
        #expect(all[0] == nil)
    }

    @Test("Load all inline notes across multiple chapters")
    func loadAllInlineNotesMultipleChapters() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        try env.noteRepo.saveInlineNotes(bookId: "book1", chapterIndex: 0,
                                          notes: [TestData.makeInlineNote(id: "n0")])
        try env.noteRepo.saveInlineNotes(bookId: "book1", chapterIndex: 3,
                                          notes: [TestData.makeInlineNote(id: "n3a"),
                                                  TestData.makeInlineNote(id: "n3b")])

        let all = try env.noteRepo.loadAllInlineNotes(bookId: "book1")
        #expect(all.count == 2)
        #expect(all[0]?.count == 1)
        #expect(all[3]?.count == 2)
    }

    @Test("Inline note preserves all fields")
    func inlineNotePreservesAllFields() throws {
        let env = try TestDatabase.createWithBook()
        defer { env.cleanup() }

        let original = TestData.makeInlineNote(id: "note-id", text: "selected text", note: "my annotation",
                                                startPath: "/html/body/div[2]/p[3]", startOffset: 5,
                                                endPath: "/html/body/div[2]/p[4]", endOffset: 12)
        try env.noteRepo.saveInlineNotes(bookId: "book1", chapterIndex: 0, notes: [original])

        let all = try env.noteRepo.loadAllInlineNotes(bookId: "book1")
        let loaded = try #require(all[0]?.first)
        #expect(loaded.id == "note-id")
        #expect(loaded.text == "selected text")
        #expect(loaded.note == "my annotation")
        #expect(loaded.startPath == "/html/body/div[2]/p[3]")
        #expect(loaded.startOffset == 5)
        #expect(loaded.endPath == "/html/body/div[2]/p[4]")
        #expect(loaded.endOffset == 12)
        #expect(loaded.createdAt.timeIntervalSince1970 == 1700000000)
    }
}
