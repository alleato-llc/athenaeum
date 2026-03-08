import Foundation
import SQLite3
import Ligature

public class HighlightRepository {
    private let db: LibraryDatabase
    private let chapterRepository: ChapterRepository

    public init(database: LibraryDatabase, chapterRepository: ChapterRepository) {
        self.db = database
        self.chapterRepository = chapterRepository
    }

    public func saveHighlights(bookId: String, chapterIndex: Int, highlights: [Highlight]) throws {
        let chapterId = try chapterRepository.ensureChapter(bookId: bookId, chapterIndex: chapterIndex)

        let jsonString: String?
        if highlights.isEmpty {
            jsonString = nil
        } else {
            let jsonData = try JSONEncoder().encode(highlights)
            jsonString = String(data: jsonData, encoding: .utf8)
        }

        let stmt = try db.prepareStatement("""
            UPDATE chapters SET highlight_data = ? WHERE id = ?;
            """)
        defer { sqlite3_finalize(stmt) }
        if let json = jsonString {
            sqlite3_bind_text(stmt, 1, (json as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 1)
        }
        sqlite3_bind_text(stmt, 2, (chapterId as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to save highlights")
        }
    }

    public func loadHighlights(bookId: String, chapterIndex: Int) throws -> [Highlight] {
        let stmt = try db.prepareStatement("""
            SELECT highlight_data FROM chapters
            WHERE book_id = ? AND chapter_index = ?;
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (bookId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(chapterIndex))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return [] }
        guard sqlite3_column_type(stmt, 0) != SQLITE_NULL else { return [] }
        let jsonStr = String(cString: sqlite3_column_text(stmt, 0))
        guard let data = jsonStr.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Highlight].self, from: data)) ?? []
    }

    public func loadAllHighlights(bookId: String) throws -> [Int: [Highlight]] {
        let stmt = try db.prepareStatement("""
            SELECT chapter_index, highlight_data FROM chapters
            WHERE book_id = ? AND highlight_data IS NOT NULL;
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (bookId as NSString).utf8String, -1, nil)

        var result: [Int: [Highlight]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let chapterIndex = Int(sqlite3_column_int(stmt, 0))
            let jsonStr = String(cString: sqlite3_column_text(stmt, 1))
            if let data = jsonStr.data(using: .utf8),
               let highlights = try? JSONDecoder().decode([Highlight].self, from: data) {
                result[chapterIndex] = highlights
            }
        }
        return result
    }
}
