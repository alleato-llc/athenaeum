import Foundation
import GRDB

public class ChapterRepository {
    private let db: LibraryDatabase

    public init(database: LibraryDatabase) {
        self.db = database
    }

    /// Returns the chapter row id, creating it if it doesn't exist.
    @discardableResult
    public func ensureChapter(bookId: String, chapterIndex: Int) throws -> String {
        let chapterId = "\(bookId)-\(chapterIndex)"
        try db.dbPool.write { db in
            try db.execute(sql: """
                INSERT OR IGNORE INTO chapters (id, book_id, chapter_index)
                VALUES (?, ?, ?);
                """, arguments: [chapterId, bookId, chapterIndex])
        }
        return chapterId
    }

    public func chapterId(bookId: String, chapterIndex: Int) -> String {
        "\(bookId)-\(chapterIndex)"
    }
}
