import Foundation
import SQLite3
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

        let stmt = try db.prepareStatement("UPDATE chapters SET notes = ? WHERE id = ?;")
        defer { sqlite3_finalize(stmt) }
        if let notes = notes, !notes.isEmpty {
            sqlite3_bind_text(stmt, 1, (notes as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 1)
        }
        sqlite3_bind_text(stmt, 2, (chapterId as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to save chapter notes")
        }
    }

    public func loadAllChapterNotes(bookId: String) throws -> [Int: String] {
        let stmt = try db.prepareStatement("""
            SELECT chapter_index, notes FROM chapters
            WHERE book_id = ? AND notes IS NOT NULL;
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (bookId as NSString).utf8String, -1, nil)

        var result: [Int: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let chapterIndex = Int(sqlite3_column_int(stmt, 0))
            let notes = String(cString: sqlite3_column_text(stmt, 1))
            if !notes.isEmpty {
                result[chapterIndex] = notes
            }
        }
        return result
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

        let stmt = try db.prepareStatement("UPDATE chapters SET inline_notes = ? WHERE id = ?;")
        defer { sqlite3_finalize(stmt) }
        if let json = jsonString {
            sqlite3_bind_text(stmt, 1, (json as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 1)
        }
        sqlite3_bind_text(stmt, 2, (chapterId as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to save inline notes")
        }
    }

    public func loadAllInlineNotes(bookId: String) throws -> [Int: [InlineNote]] {
        let stmt = try db.prepareStatement("""
            SELECT chapter_index, inline_notes FROM chapters
            WHERE book_id = ? AND inline_notes IS NOT NULL;
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (bookId as NSString).utf8String, -1, nil)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var result: [Int: [InlineNote]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let chapterIndex = Int(sqlite3_column_int(stmt, 0))
            let jsonStr = String(cString: sqlite3_column_text(stmt, 1))
            if let data = jsonStr.data(using: .utf8),
               let notes = try? decoder.decode([InlineNote].self, from: data) {
                result[chapterIndex] = notes
            }
        }
        return result
    }
}
