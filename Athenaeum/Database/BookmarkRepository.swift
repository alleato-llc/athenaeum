import Foundation
import SQLite3
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

        let stmt = try db.prepareStatement("""
            INSERT INTO bookmarks (id, chapter_id, scroll_position, label, created_at)
            VALUES (?, ?, ?, ?, ?);
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (bookmarkId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (chapterId as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 3, scrollPosition)
        sqlite3_bind_text(stmt, 4, (label as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 5, (createdAt as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to add bookmark")
        }

        return Bookmark(id: bookmarkId, chapterIndex: chapterIndex,
                        scrollPosition: scrollPosition, label: label, createdAt: now)
    }

    public func loadAllBookmarks(bookId: String) throws -> [Bookmark] {
        let stmt = try db.prepareStatement("""
            SELECT b.id, c.chapter_index, b.scroll_position, b.label, b.created_at
            FROM bookmarks b
            JOIN chapters c ON b.chapter_id = c.id
            WHERE c.book_id = ?
            ORDER BY b.created_at ASC;
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (bookId as NSString).utf8String, -1, nil)

        let formatter = ISO8601DateFormatter()
        var bookmarks: [Bookmark] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let chapterIndex = Int(sqlite3_column_int(stmt, 1))
            let scrollPosition = sqlite3_column_double(stmt, 2)
            let label = String(cString: sqlite3_column_text(stmt, 3))
            let dateStr = String(cString: sqlite3_column_text(stmt, 4))
            let createdAt = formatter.date(from: dateStr) ?? Date()
            bookmarks.append(Bookmark(id: id, chapterIndex: chapterIndex,
                                       scrollPosition: scrollPosition,
                                       label: label, createdAt: createdAt))
        }
        return bookmarks
    }

    public func deleteBookmark(id: String) throws {
        let stmt = try db.prepareStatement("DELETE FROM bookmarks WHERE id = ?;")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }
}
