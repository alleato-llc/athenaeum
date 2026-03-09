import Foundation
import GRDB

public class BookRepository {
    private let db: LibraryDatabase

    public init(database: LibraryDatabase) {
        self.db = database
    }

    public func insert(book: LibraryBook, authors: [Author]) throws {
        let identifiersJSON = try JSONSerialization.data(withJSONObject: book.identifiers)
        let identifiersString = String(data: identifiersJSON, encoding: .utf8) ?? "{}"
        let dateString = ISO8601DateFormatter().string(from: book.dateAdded)

        try db.dbPool.write { db in
            try db.execute(sql: """
                INSERT INTO books (id, title, year, genre, page_count, format, identifiers,
                                 cover_path, file_path, group_id, date_added)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """, arguments: [
                    book.id, book.title, book.year, book.genre, book.pageCount,
                    book.format.rawValue, identifiersString, book.coverPath,
                    book.filePath, book.groupId, dateString
                ])

            for (index, author) in authors.enumerated() {
                try self.insertAuthorLink(db: db, bookId: book.id, author: author,
                                          isPrimary: index == 0)
            }
        }
    }

    public func update(book: LibraryBook, authors: [Author]) throws {
        let identifiersJSON = try JSONSerialization.data(withJSONObject: book.identifiers)
        let identifiersString = String(data: identifiersJSON, encoding: .utf8) ?? "{}"

        try db.dbPool.write { db in
            try db.execute(sql: """
                UPDATE books SET title=?, year=?, genre=?, page_count=?, format=?,
                               identifiers=?, cover_path=?, file_path=?, group_id=?
                WHERE id=?;
                """, arguments: [
                    book.title, book.year, book.genre, book.pageCount,
                    book.format.rawValue, identifiersString, book.coverPath,
                    book.filePath, book.groupId, book.id
                ])

            try db.execute(sql: "DELETE FROM book_authors WHERE book_id = ?;",
                          arguments: [book.id])
            for (index, author) in authors.enumerated() {
                try self.insertAuthorLink(db: db, bookId: book.id, author: author,
                                          isPrimary: index == 0)
            }
        }
    }

    public func bookExists(title: String, authorNames: [String]) throws -> Bool {
        try db.dbPool.read { db in
            if authorNames.isEmpty {
                let count = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM books b
                    WHERE LOWER(b.title) = LOWER(?)
                    AND NOT EXISTS (SELECT 1 FROM book_authors ba WHERE ba.book_id = b.id);
                    """, arguments: [title])
                return (count ?? 0) > 0
            }

            let placeholders = authorNames.map { _ in "LOWER(?)" }.joined(separator: ", ")
            let sql = """
                SELECT COUNT(*) FROM books b
                JOIN book_authors ba ON b.id = ba.book_id
                JOIN authors a ON ba.author_id = a.id
                WHERE LOWER(b.title) = LOWER(?)
                AND LOWER(a.name) IN (\(placeholders));
                """
            var arguments: [any DatabaseValueConvertible] = [title]
            arguments.append(contentsOf: authorNames)
            let count = try Int.fetchOne(db, sql: sql,
                                         arguments: StatementArguments(arguments))
            return (count ?? 0) > 0
        }
    }

    public func delete(bookId: String) throws {
        try db.dbPool.write { db in
            try db.execute(sql: "DELETE FROM books WHERE id = ?;", arguments: [bookId])
        }
    }

    public func updatePaths(bookId: String, filePath: String, coverPath: String?) throws {
        try db.dbPool.write { db in
            try db.execute(sql: "UPDATE books SET file_path=?, cover_path=? WHERE id=?;",
                          arguments: [filePath, coverPath, bookId])
        }
    }

    public func fetchAll() throws -> [(book: LibraryBook, authors: [Author])] {
        try db.dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, title, year, genre, page_count, format, identifiers,
                       cover_path, file_path, group_id, date_added, reading_position
                FROM books ORDER BY date_added DESC;
                """)
            return try rows.map { row in
                let book = try self.readBook(from: row)
                let authors = try self.fetchAuthorsInTransaction(db: db, bookId: book.id)
                return (book, authors)
            }
        }
    }

    public func search(query: String) throws -> [(book: LibraryBook, authors: [Author])] {
        try db.dbPool.read { db in
            let pattern = "%\(query)%"
            let rows = try Row.fetchAll(db, sql: """
                SELECT DISTINCT b.id, b.title, b.year, b.genre, b.page_count, b.format,
                       b.identifiers, b.cover_path, b.file_path, b.group_id, b.date_added,
                       b.reading_position
                FROM books b
                LEFT JOIN book_authors ba ON b.id = ba.book_id
                LEFT JOIN authors a ON ba.author_id = a.id
                WHERE b.title LIKE ? OR a.name LIKE ?
                ORDER BY b.date_added DESC;
                """, arguments: [pattern, pattern])
            return try rows.map { row in
                let book = try self.readBook(from: row)
                let authors = try self.fetchAuthorsInTransaction(db: db, bookId: book.id)
                return (book, authors)
            }
        }
    }

    public func fetchAuthors(forBookId bookId: String) throws -> [Author] {
        try db.dbPool.read { db in
            try self.fetchAuthorsInTransaction(db: db, bookId: bookId)
        }
    }

    public func saveProgress(bookId: String, chapterIndex: Int, scrollPosition: Double) throws {
        let position = ReadingPosition(chapter: chapterIndex, scroll: scrollPosition)
        let jsonData = try JSONEncoder().encode(position)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        try db.dbPool.write { db in
            try db.execute(sql: "UPDATE books SET reading_position=? WHERE id=?;",
                          arguments: [jsonString, bookId])
        }
    }

    // MARK: - Private

    private func insertAuthorLink(db: Database, bookId: String, author: Author,
                                  isPrimary: Bool = false) throws {
        let authorId = try String.fetchOne(db, sql: """
            INSERT INTO authors (id, name) VALUES (?, ?)
            ON CONFLICT(name) DO UPDATE SET name=excluded.name
            RETURNING id;
            """, arguments: [author.id, author.name]) ?? author.id

        try db.execute(sql: """
            INSERT OR IGNORE INTO book_authors (book_id, author_id, is_primary) VALUES (?, ?, ?);
            """, arguments: [bookId, authorId, isPrimary ? 1 : 0])
    }

    private func fetchAuthorsInTransaction(db: Database, bookId: String) throws -> [Author] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT a.id, a.name FROM authors a
            JOIN book_authors ba ON a.id = ba.author_id
            WHERE ba.book_id = ?
            ORDER BY ba.is_primary DESC, a.name;
            """, arguments: [bookId])
        return rows.map { Author(id: $0["id"], name: $0["name"]) }
    }

    private func readBook(from row: Row) throws -> LibraryBook {
        let id: String = row["id"]
        let title: String = row["title"]
        let year: Int? = row["year"]
        let genre: String? = row["genre"]
        let pageCount: Int? = row["page_count"]
        let formatStr: String = row["format"]
        let format = BookFormat(rawValue: formatStr) ?? .epub

        var identifiers: [String: String] = [:]
        if let jsonStr: String = row["identifiers"],
           let data = jsonStr.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            identifiers = parsed
        }

        let coverPath: String? = row["cover_path"]
        let filePath: String = row["file_path"]
        let groupId: String? = row["group_id"]
        let dateString: String = row["date_added"]
        let dateAdded = ISO8601DateFormatter().date(from: dateString) ?? Date()

        var readingPosition: ReadingPosition?
        if let posJson: String = row["reading_position"],
           let posData = posJson.data(using: .utf8) {
            readingPosition = try? JSONDecoder().decode(ReadingPosition.self, from: posData)
        }

        return LibraryBook(id: id, title: title, year: year, genre: genre,
                          pageCount: pageCount, format: format, identifiers: identifiers,
                          coverPath: coverPath, filePath: filePath, groupId: groupId,
                          dateAdded: dateAdded, readingPosition: readingPosition)
    }
}
