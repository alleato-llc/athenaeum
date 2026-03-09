import Foundation
import GRDB
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

        try db.dbPool.write { db in
            try db.execute(sql: "UPDATE chapters SET highlight_data = ? WHERE id = ?;",
                          arguments: [jsonString, chapterId])
        }
    }

    public func loadHighlights(bookId: String, chapterIndex: Int) throws -> [Highlight] {
        try db.dbPool.read { db in
            guard let jsonStr = try String?.fetchOne(db, sql: """
                SELECT highlight_data FROM chapters
                WHERE book_id = ? AND chapter_index = ?;
                """, arguments: [bookId, chapterIndex]) else { return [] }
            guard let json = jsonStr,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([Highlight].self, from: data)) ?? []
        }
    }

    public func loadAllHighlights(bookId: String) throws -> [Int: [Highlight]] {
        try db.dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT chapter_index, highlight_data FROM chapters
                WHERE book_id = ? AND highlight_data IS NOT NULL;
                """, arguments: [bookId])
            var result: [Int: [Highlight]] = [:]
            for row in rows {
                let chapterIndex: Int = row["chapter_index"]
                let jsonStr: String = row["highlight_data"]
                if let data = jsonStr.data(using: .utf8),
                   let highlights = try? JSONDecoder().decode([Highlight].self, from: data) {
                    result[chapterIndex] = highlights
                }
            }
            return result
        }
    }
}
