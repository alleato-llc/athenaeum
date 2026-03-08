import Foundation
import SQLite3

public class BookRepository {
    private let db: LibraryDatabase

    public init(database: LibraryDatabase) {
        self.db = database
    }

    public func insert(book: LibraryBook, authors: [Author]) throws {
        let identifiersJSON = try JSONSerialization.data(withJSONObject: book.identifiers)
        let identifiersString = String(data: identifiersJSON, encoding: .utf8) ?? "{}"
        let dateString = ISO8601DateFormatter().string(from: book.dateAdded)

        let stmt = try db.prepareStatement("""
            INSERT INTO books (id, title, year, genre, page_count, format, identifiers,
                             cover_path, file_path, group_id, date_added)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (book.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (book.title as NSString).utf8String, -1, nil)
        if let year = book.year { sqlite3_bind_int(stmt, 3, Int32(year)) }
        else { sqlite3_bind_null(stmt, 3) }
        if let genre = book.genre { sqlite3_bind_text(stmt, 4, (genre as NSString).utf8String, -1, nil) }
        else { sqlite3_bind_null(stmt, 4) }
        if let pages = book.pageCount { sqlite3_bind_int(stmt, 5, Int32(pages)) }
        else { sqlite3_bind_null(stmt, 5) }
        sqlite3_bind_text(stmt, 6, (book.format.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 7, (identifiersString as NSString).utf8String, -1, nil)
        if let cover = book.coverPath { sqlite3_bind_text(stmt, 8, (cover as NSString).utf8String, -1, nil) }
        else { sqlite3_bind_null(stmt, 8) }
        sqlite3_bind_text(stmt, 9, (book.filePath as NSString).utf8String, -1, nil)
        if let groupId = book.groupId { sqlite3_bind_text(stmt, 10, (groupId as NSString).utf8String, -1, nil) }
        else { sqlite3_bind_null(stmt, 10) }
        sqlite3_bind_text(stmt, 11, (dateString as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to insert book")
        }

        for author in authors {
            try insertAuthorLink(bookId: book.id, author: author)
        }
    }

    public func update(book: LibraryBook, authors: [Author]) throws {
        let identifiersJSON = try JSONSerialization.data(withJSONObject: book.identifiers)
        let identifiersString = String(data: identifiersJSON, encoding: .utf8) ?? "{}"

        let stmt = try db.prepareStatement("""
            UPDATE books SET title=?, year=?, genre=?, page_count=?, format=?,
                           identifiers=?, cover_path=?, file_path=?, group_id=?
            WHERE id=?;
            """)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (book.title as NSString).utf8String, -1, nil)
        if let year = book.year { sqlite3_bind_int(stmt, 2, Int32(year)) }
        else { sqlite3_bind_null(stmt, 2) }
        if let genre = book.genre { sqlite3_bind_text(stmt, 3, (genre as NSString).utf8String, -1, nil) }
        else { sqlite3_bind_null(stmt, 3) }
        if let pages = book.pageCount { sqlite3_bind_int(stmt, 4, Int32(pages)) }
        else { sqlite3_bind_null(stmt, 4) }
        sqlite3_bind_text(stmt, 5, (book.format.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 6, (identifiersString as NSString).utf8String, -1, nil)
        if let cover = book.coverPath { sqlite3_bind_text(stmt, 7, (cover as NSString).utf8String, -1, nil) }
        else { sqlite3_bind_null(stmt, 7) }
        sqlite3_bind_text(stmt, 8, (book.filePath as NSString).utf8String, -1, nil)
        if let groupId = book.groupId { sqlite3_bind_text(stmt, 9, (groupId as NSString).utf8String, -1, nil) }
        else { sqlite3_bind_null(stmt, 9) }
        sqlite3_bind_text(stmt, 10, (book.id as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to update book")
        }

        // Replace author links
        try db.execute("DELETE FROM book_authors WHERE book_id = '\(book.id)';")
        for author in authors {
            try insertAuthorLink(bookId: book.id, author: author)
        }
    }

    public func bookExists(title: String, authorNames: [String]) throws -> Bool {
        if authorNames.isEmpty {
            let stmt = try db.prepareStatement("""
                SELECT COUNT(*) FROM books b
                WHERE LOWER(b.title) = LOWER(?)
                AND NOT EXISTS (SELECT 1 FROM book_authors ba WHERE ba.book_id = b.id);
                """)
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (title as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return false }
            return sqlite3_column_int(stmt, 0) > 0
        }

        let placeholders = authorNames.map { _ in "LOWER(?)" }.joined(separator: ", ")
        let sql = """
            SELECT COUNT(*) FROM books b
            JOIN book_authors ba ON b.id = ba.book_id
            JOIN authors a ON ba.author_id = a.id
            WHERE LOWER(b.title) = LOWER(?)
            AND LOWER(a.name) IN (\(placeholders));
            """
        let stmt = try db.prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (title as NSString).utf8String, -1, nil)
        for (i, name) in authorNames.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 2), (name as NSString).utf8String, -1, nil)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return false }
        return sqlite3_column_int(stmt, 0) > 0
    }

    public func delete(bookId: String) throws {
        try db.execute("DELETE FROM books WHERE id = '\(bookId)';")
    }

    public func updatePaths(bookId: String, filePath: String, coverPath: String?) throws {
        let stmt = try db.prepareStatement("UPDATE books SET file_path=?, cover_path=? WHERE id=?;")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (filePath as NSString).utf8String, -1, nil)
        if let cover = coverPath { sqlite3_bind_text(stmt, 2, (cover as NSString).utf8String, -1, nil) }
        else { sqlite3_bind_null(stmt, 2) }
        sqlite3_bind_text(stmt, 3, (bookId as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to update book paths")
        }
    }

    public func fetchAll() throws -> [(book: LibraryBook, authors: [Author])] {
        let stmt = try db.prepareStatement("""
            SELECT id, title, year, genre, page_count, format, identifiers,
                   cover_path, file_path, group_id, date_added, reading_position
            FROM books ORDER BY date_added DESC;
            """)
        defer { sqlite3_finalize(stmt) }

        var results: [(book: LibraryBook, authors: [Author])] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let book = try readBook(from: stmt)
            let authors = try fetchAuthors(forBookId: book.id)
            results.append((book, authors))
        }
        return results
    }

    public func search(query: String) throws -> [(book: LibraryBook, authors: [Author])] {
        let stmt = try db.prepareStatement("""
            SELECT DISTINCT b.id, b.title, b.year, b.genre, b.page_count, b.format,
                   b.identifiers, b.cover_path, b.file_path, b.group_id, b.date_added,
                   b.reading_position
            FROM books b
            LEFT JOIN book_authors ba ON b.id = ba.book_id
            LEFT JOIN authors a ON ba.author_id = a.id
            WHERE b.title LIKE ? OR a.name LIKE ?
            ORDER BY b.date_added DESC;
            """)
        defer { sqlite3_finalize(stmt) }

        let pattern = "%\(query)%"
        sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (pattern as NSString).utf8String, -1, nil)

        var results: [(book: LibraryBook, authors: [Author])] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let book = try readBook(from: stmt)
            let authors = try fetchAuthors(forBookId: book.id)
            results.append((book, authors))
        }
        return results
    }

    public func fetchAuthors(forBookId bookId: String) throws -> [Author] {
        let stmt = try db.prepareStatement("""
            SELECT a.id, a.name FROM authors a
            JOIN book_authors ba ON a.id = ba.author_id
            WHERE ba.book_id = ?;
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (bookId as NSString).utf8String, -1, nil)

        var authors: [Author] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            authors.append(Author(id: id, name: name))
        }
        return authors
    }

    public func saveProgress(bookId: String, chapterIndex: Int, scrollPosition: Double) throws {
        let position = ReadingPosition(chapter: chapterIndex, scroll: scrollPosition)
        let jsonData = try JSONEncoder().encode(position)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let stmt = try db.prepareStatement("""
            UPDATE books SET reading_position=? WHERE id=?;
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (jsonString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (bookId as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to save reading progress")
        }
    }

    private func insertAuthorLink(bookId: String, author: Author) throws {
        let upsertStmt = try db.prepareStatement("""
            INSERT INTO authors (id, name) VALUES (?, ?)
            ON CONFLICT(name) DO UPDATE SET name=excluded.name
            RETURNING id;
            """)
        defer { sqlite3_finalize(upsertStmt) }
        sqlite3_bind_text(upsertStmt, 1, (author.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(upsertStmt, 2, (author.name as NSString).utf8String, -1, nil)

        var authorId = author.id
        if sqlite3_step(upsertStmt) == SQLITE_ROW {
            authorId = String(cString: sqlite3_column_text(upsertStmt, 0))
        }

        let linkStmt = try db.prepareStatement("""
            INSERT OR IGNORE INTO book_authors (book_id, author_id) VALUES (?, ?);
            """)
        defer { sqlite3_finalize(linkStmt) }
        sqlite3_bind_text(linkStmt, 1, (bookId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(linkStmt, 2, (authorId as NSString).utf8String, -1, nil)
        sqlite3_step(linkStmt)
    }

    private func readBook(from stmt: OpaquePointer) throws -> LibraryBook {
        let id = String(cString: sqlite3_column_text(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let year = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 2)) : nil
        let genre = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 3)) : nil
        let pageCount = sqlite3_column_type(stmt, 4) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 4)) : nil
        let formatStr = String(cString: sqlite3_column_text(stmt, 5))
        let format = BookFormat(rawValue: formatStr) ?? .epub

        var identifiers: [String: String] = [:]
        if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
            let jsonStr = String(cString: sqlite3_column_text(stmt, 6))
            if let data = jsonStr.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                identifiers = parsed
            }
        }

        let coverPath = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 7)) : nil
        let filePath = String(cString: sqlite3_column_text(stmt, 8))
        let groupId = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 9)) : nil
        let dateString = String(cString: sqlite3_column_text(stmt, 10))
        let dateAdded = ISO8601DateFormatter().date(from: dateString) ?? Date()

        var readingPosition: ReadingPosition?
        if sqlite3_column_type(stmt, 11) != SQLITE_NULL {
            let posJson = String(cString: sqlite3_column_text(stmt, 11))
            if let posData = posJson.data(using: .utf8) {
                readingPosition = try? JSONDecoder().decode(ReadingPosition.self, from: posData)
            }
        }

        return LibraryBook(id: id, title: title, year: year, genre: genre,
                          pageCount: pageCount, format: format, identifiers: identifiers,
                          coverPath: coverPath, filePath: filePath, groupId: groupId,
                          dateAdded: dateAdded, readingPosition: readingPosition)
    }
}
