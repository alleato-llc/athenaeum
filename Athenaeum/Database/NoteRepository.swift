import Foundation
import GRDB
import Ligature

public class NoteRepository {
    private let db: LibraryDatabase
    private let chapterRepository: ChapterRepository

    public init(database: LibraryDatabase, chapterRepository: ChapterRepository) {
        self.db = database
        self.chapterRepository = chapterRepository
    }

    // MARK: - Chapter Notes

    public func saveChapterNotes(bookId: String, chapterIndex: Int, notes: String?) throws {
        let chapterId = try chapterRepository.ensureChapter(bookId: bookId, chapterIndex: chapterIndex)

        try db.dbPool.write { db in
            let value = (notes?.isEmpty == false) ? notes : nil
            try db.execute(sql: "UPDATE chapters SET notes = ? WHERE id = ?;",
                          arguments: [value, chapterId])
        }
    }

    public func loadAllChapterNotes(bookId: String) throws -> [Int: String] {
        try db.dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT chapter_index, notes FROM chapters
                WHERE book_id = ? AND notes IS NOT NULL;
                """, arguments: [bookId])
            var result: [Int: String] = [:]
            for row in rows {
                let chapterIndex: Int = row["chapter_index"]
                let notes: String = row["notes"]
                if !notes.isEmpty {
                    result[chapterIndex] = notes
                }
            }
            return result
        }
    }

    // MARK: - Inline Notes

    public func saveInlineNotes(bookId: String, chapterIndex: Int, notes: [InlineNote]) throws {
        let chapterId = try chapterRepository.ensureChapter(bookId: bookId, chapterIndex: chapterIndex)

        let jsonString: String?
        if notes.isEmpty {
            jsonString = nil
        } else {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(notes)
            jsonString = String(data: jsonData, encoding: .utf8)
        }

        try db.dbPool.write { db in
            try db.execute(sql: "UPDATE chapters SET inline_notes = ? WHERE id = ?;",
                          arguments: [jsonString, chapterId])
        }
    }

    public func loadAllInlineNotes(bookId: String) throws -> [Int: [InlineNote]] {
        try db.dbPool.read { db in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let rows = try Row.fetchAll(db, sql: """
                SELECT chapter_index, inline_notes FROM chapters
                WHERE book_id = ? AND inline_notes IS NOT NULL;
                """, arguments: [bookId])
            var result: [Int: [InlineNote]] = [:]
            for row in rows {
                let chapterIndex: Int = row["chapter_index"]
                let jsonStr: String = row["inline_notes"]
                if let data = jsonStr.data(using: .utf8),
                   let notes = try? decoder.decode([InlineNote].self, from: data) {
                    result[chapterIndex] = notes
                }
            }
            return result
        }
    }
}
