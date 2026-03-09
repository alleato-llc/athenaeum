import Foundation
import GRDB
import Ligature

public class BookmarkRepository {
    private let db: LibraryDatabase
    private let chapterRepository: ChapterRepository

    public init(database: LibraryDatabase, chapterRepository: ChapterRepository) {
        self.db = database
        self.chapterRepository = chapterRepository
    }

    public func addBookmark(bookId: String, chapterIndex: Int, scrollPosition: Double, label: String) throws -> Bookmark {
        let chapterId = try chapterRepository.ensureChapter(bookId: bookId, chapterIndex: chapterIndex)
        let bookmarkId = UUID().uuidString
        let now = Date()
        let createdAt = ISO8601DateFormatter().string(from: now)

        try db.dbPool.write { db in
            try db.execute(sql: """
                INSERT INTO bookmarks (id, chapter_id, scroll_position, label, created_at)
                VALUES (?, ?, ?, ?, ?);
                """, arguments: [bookmarkId, chapterId, scrollPosition, label, createdAt])
        }

        return Bookmark(id: bookmarkId, chapterIndex: chapterIndex,
                        scrollPosition: scrollPosition, label: label, createdAt: now)
    }

    public func loadAllBookmarks(bookId: String) throws -> [Bookmark] {
        try db.dbPool.read { db in
            let formatter = ISO8601DateFormatter()
            let rows = try Row.fetchAll(db, sql: """
                SELECT b.id, c.chapter_index, b.scroll_position, b.label, b.created_at
                FROM bookmarks b
                JOIN chapters c ON b.chapter_id = c.id
                WHERE c.book_id = ?
                ORDER BY b.created_at ASC;
                """, arguments: [bookId])
            return rows.map { row in
                let dateStr: String = row["created_at"]
                return Bookmark(
                    id: row["id"],
                    chapterIndex: row["chapter_index"],
                    scrollPosition: row["scroll_position"],
                    label: row["label"],
                    createdAt: formatter.date(from: dateStr) ?? Date()
                )
            }
        }
    }

    public func deleteBookmark(id: String) throws {
        try db.dbPool.write { db in
            try db.execute(sql: "DELETE FROM bookmarks WHERE id = ?;", arguments: [id])
        }
    }
}
