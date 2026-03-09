import Foundation
import GRDB

public class LibraryDatabase {
    let dbPool: DatabasePool
    public let path: String

    public init(path: String) throws {
        self.path = path
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        var config = Configuration()
        config.foreignKeysEnabled = true
        dbPool = try DatabasePool(path: path, configuration: config)

        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "books", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("year", .integer)
                t.column("genre", .text)
                t.column("page_count", .integer)
                t.column("format", .text).notNull()
                t.column("identifiers", .text)
                t.column("cover_path", .text)
                t.column("file_path", .text).notNull()
                t.column("group_id", .text)
                t.column("date_added", .text).notNull()
            }
            try db.create(table: "authors", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull().unique()
            }
            try db.create(table: "book_authors", ifNotExists: true) { t in
                t.column("book_id", .text).notNull()
                    .references("books", onDelete: .cascade)
                t.column("author_id", .text).notNull()
                    .references("authors", onDelete: .cascade)
                t.primaryKey(["book_id", "author_id"])
            }
            try db.create(table: "settings", ifNotExists: true) { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }
            try db.create(index: "idx_books_title", on: "books", columns: ["title"],
                         ifNotExists: true)
            try db.create(index: "idx_books_group_id", on: "books", columns: ["group_id"],
                         ifNotExists: true)
            try db.create(index: "idx_authors_name", on: "authors", columns: ["name"],
                         ifNotExists: true)
        }

        migrator.registerMigration("v2") { db in
            try db.alter(table: "books") { t in
                t.add(column: "reading_position", .text)
            }
        }

        migrator.registerMigration("v3") { db in
            try db.create(table: "highlights", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("book_id", .text).notNull()
                    .references("books", onDelete: .cascade)
                t.column("chapter_index", .integer).notNull()
                t.column("highlight_data", .text).notNull()
                t.column("updated_at", .text).notNull()
            }
            try db.create(index: "idx_highlights_book_chapter",
                         on: "highlights", columns: ["book_id", "chapter_index"],
                         unique: true, ifNotExists: true)
        }

        migrator.registerMigration("v4") { db in
            try db.create(table: "chapters", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("book_id", .text).notNull()
                    .references("books", onDelete: .cascade)
                t.column("chapter_index", .integer).notNull()
                t.column("highlight_data", .text)
                t.uniqueKey(["book_id", "chapter_index"])
            }
            try db.execute(sql: """
                INSERT OR IGNORE INTO chapters (id, book_id, chapter_index, highlight_data)
                SELECT id, book_id, chapter_index, highlight_data FROM highlights;
                """)
            try db.create(table: "bookmarks", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("chapter_id", .text).notNull()
                    .references("chapters", onDelete: .cascade)
                t.column("scroll_position", .double).notNull()
                t.column("label", .text).notNull()
                t.column("created_at", .text).notNull()
            }
            try db.create(index: "idx_bookmarks_chapter", on: "bookmarks",
                         columns: ["chapter_id"], ifNotExists: true)
            try db.drop(table: "highlights")
        }

        migrator.registerMigration("v5") { db in
            try db.alter(table: "chapters") { t in
                t.add(column: "notes", .text)
                t.add(column: "inline_notes", .text)
            }
        }

        migrator.registerMigration("v6") { db in
            try db.alter(table: "book_authors") { t in
                t.add(column: "is_primary", .integer).notNull().defaults(to: 0)
            }
        }

        try migrator.migrate(dbPool)
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
