import Foundation
import SQLite3

public class LibraryDatabase {
    private var db: OpaquePointer?
    public let path: String

    public init(path: String) throws {
        self.path = path
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw LibraryDatabaseError.openFailed(error)
        }

        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA foreign_keys=ON;")
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    private func migrate() throws {
        let version = try getUserVersion()

        if version < 1 {
            try execute("""
                CREATE TABLE IF NOT EXISTS books (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    year INTEGER,
                    genre TEXT,
                    page_count INTEGER,
                    format TEXT NOT NULL,
                    identifiers TEXT,
                    cover_path TEXT,
                    file_path TEXT NOT NULL,
                    group_id TEXT,
                    date_added TEXT NOT NULL
                );
                """)
            try execute("""
                CREATE TABLE IF NOT EXISTS authors (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL UNIQUE
                );
                """)
            try execute("""
                CREATE TABLE IF NOT EXISTS book_authors (
                    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    author_id TEXT NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
                    PRIMARY KEY (book_id, author_id)
                );
                """)
            try execute("""
                CREATE TABLE IF NOT EXISTS settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """)
            try execute("""
                CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
                """)
            try execute("""
                CREATE INDEX IF NOT EXISTS idx_books_group_id ON books(group_id);
                """)
            try execute("""
                CREATE INDEX IF NOT EXISTS idx_authors_name ON authors(name);
                """)
            try setUserVersion(1)
        }

        if version < 2 {
            try execute("ALTER TABLE books ADD COLUMN reading_position TEXT;")
            try setUserVersion(2)
        }

        if version < 3 {
            try execute("""
                CREATE TABLE IF NOT EXISTS highlights (
                    id TEXT PRIMARY KEY,
                    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    chapter_index INTEGER NOT NULL,
                    highlight_data TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """)
            try execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS idx_highlights_book_chapter
                ON highlights(book_id, chapter_index);
                """)
            try setUserVersion(3)
        }

        if version < 4 {
            // Create chapters table
            try execute("""
                CREATE TABLE IF NOT EXISTS chapters (
                    id TEXT PRIMARY KEY,
                    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    chapter_index INTEGER NOT NULL,
                    highlight_data TEXT,
                    UNIQUE(book_id, chapter_index)
                );
                """)
            // Migrate existing highlights data into chapters
            try execute("""
                INSERT OR IGNORE INTO chapters (id, book_id, chapter_index, highlight_data)
                SELECT id, book_id, chapter_index, highlight_data FROM highlights;
                """)
            // Create bookmarks table
            try execute("""
                CREATE TABLE IF NOT EXISTS bookmarks (
                    id TEXT PRIMARY KEY,
                    chapter_id TEXT NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
                    scroll_position REAL NOT NULL,
                    label TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                """)
            try execute("""
                CREATE INDEX IF NOT EXISTS idx_bookmarks_chapter ON bookmarks(chapter_id);
                """)
            // Drop old highlights table
            try execute("DROP TABLE IF EXISTS highlights;")
            try setUserVersion(4)
        }

        if version < 5 {
            try execute("ALTER TABLE chapters ADD COLUMN notes TEXT;")
            try execute("ALTER TABLE chapters ADD COLUMN inline_notes TEXT;")
            try setUserVersion(5)
        }
    }

    private func getUserVersion() throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK else {
            throw LibraryDatabaseError.queryFailed("Failed to get user_version")
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw LibraryDatabaseError.queryFailed("No result for user_version")
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func setUserVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version);")
    }

    @discardableResult
    func execute(_ sql: String) throws -> Int {
        var errorMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMsg) == SQLITE_OK else {
            let error = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw LibraryDatabaseError.queryFailed(error)
        }
        return Int(sqlite3_changes(db))
    }

    func prepareStatement(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let statement = stmt else {
            let error = String(cString: sqlite3_errmsg(db))
            throw LibraryDatabaseError.queryFailed(error)
        }
        return statement
    }
}

public enum LibraryDatabaseError: LocalizedError {
    case openFailed(String)
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Failed to open database: \(msg)"
        case .queryFailed(let msg): return "Database query failed: \(msg)"
        }
    }
}
