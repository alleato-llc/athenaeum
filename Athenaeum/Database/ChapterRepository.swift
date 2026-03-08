import Foundation
import SQLite3

public class ChapterRepository {
    private let db: LibraryDatabase

    public init(database: LibraryDatabase) {
        self.db = database
    }

    /// Returns the chapter row id, creating it if it doesn't exist.
    @discardableResult
    public func ensureChapter(bookId: String, chapterIndex: Int) throws -> String {
        let chapterId = "\(bookId)-\(chapterIndex)"
        let stmt = try db.prepareStatement("""
            INSERT OR IGNORE INTO chapters (id, book_id, chapter_index)
            VALUES (?, ?, ?);
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (chapterId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (bookId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 3, Int32(chapterIndex))
        sqlite3_step(stmt)
        return chapterId
    }

    public func chapterId(bookId: String, chapterIndex: Int) -> String {
        "\(bookId)-\(chapterIndex)"
    }
}
