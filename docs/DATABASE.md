# Database

## Technology Choices

The library uses **SQLite** via the C API (`libsqlite3`), linked in the root `Package.swift` for the Athenaeum target. There is no ORM or third-party wrapper — all queries are written as raw SQL and executed through a thin `LibraryDatabase` class that manages the connection and migrations.

Key configuration:
- **WAL mode** (`PRAGMA journal_mode=WAL`) — Allows concurrent reads during writes, improving responsiveness.
- **Foreign keys** (`PRAGMA foreign_keys=ON`) — Enforces referential integrity (e.g., deleting a book cascades to `book_authors`).
- **Versioned migrations** (`PRAGMA user_version`) — Schema changes are tracked by an integer version and applied automatically on launch.

SQLite was chosen to maintain the project's zero-external-dependency constraint. The `libsqlite3` library ships with macOS, so no additional packages are needed.

## Data Storage

All library data lives under a single configurable directory (default: `~/Library/Application Support/Athenaeum/`). The user can change this path in Settings.

```
~/Library/Application Support/Athenaeum/
├── library.db          # SQLite database (WAL mode)
├── books/              # Imported book files (named by UUID)
│   └── <uuid>.epub
└── covers/             # Extracted cover images
    └── <uuid>.jpg
```

- **`library.db`** — The SQLite database containing all book metadata, author records, and user settings. WAL journal files (`library.db-wal`, `library.db-shm`) may appear alongside it during normal operation.
- **`books/`** — When a book is imported, the original file is copied here with a UUID filename. The original file is never modified or moved.
- **`covers/`** — Cover art extracted during import (or replaced via Edit Metadata) is stored as JPEG files, also named by the book's UUID.

Deleting a book from the library removes its file from `books/`, its cover from `covers/`, and its records from the database. The original source file is unaffected.

## Relevant Files

| File | Purpose |
|------|---------|
| `Athenaeum/Database/LibraryDatabase.swift` | SQLite connection, WAL/FK pragmas, schema migrations, query execution |
| `Athenaeum/Database/BookRepository.swift` | CRUD for books and author relationships, search by title/author |
| `Athenaeum/Database/SettingsRepository.swift` | Read/write user settings as key-value pairs |

## Schema

### `books`

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT | Primary key (UUID) |
| `title` | TEXT | NOT NULL |
| `year` | INTEGER | Publication year (nullable) |
| `genre` | TEXT | Genre/category (nullable) |
| `page_count` | INTEGER | (nullable) |
| `format` | TEXT | NOT NULL — `epub`, `pdf`, or `txt` |
| `identifiers` | TEXT | JSON object (e.g., `{"isbn": "978-..."}`) |
| `cover_path` | TEXT | Absolute path to cover JPEG in `covers/` |
| `file_path` | TEXT | NOT NULL — Absolute path to file in `books/` |
| `group_id` | TEXT | Links the same book across formats (not yet exposed in UI) |
| `date_added` | TEXT | ISO 8601 timestamp |

Indexes: `idx_books_title` on `title`, `idx_books_group_id` on `group_id`.

### `authors`

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT | Primary key (UUID) |
| `name` | TEXT | NOT NULL, UNIQUE |

Index: `idx_authors_name` on `name`.

### `book_authors`

Many-to-many junction table.

| Column | Type | Notes |
|--------|------|-------|
| `book_id` | TEXT | FK to `books(id)` ON DELETE CASCADE |
| `author_id` | TEXT | FK to `authors(id)` ON DELETE CASCADE |

Composite primary key: `(book_id, author_id)`.

### `settings`

Simple key-value store for user preferences.

| Column | Type | Notes |
|--------|------|-------|
| `key` | TEXT | Primary key |
| `value` | TEXT | NOT NULL |

## How to Maintain

### Adding a Migration

The database uses `PRAGMA user_version` to track schema versions. To add a migration:

1. Open `LibraryDatabase.swift`
2. In the `migrate()` method, add a new version block after the existing ones:
   ```swift
   if version < 2 {
       try execute("ALTER TABLE books ADD COLUMN new_field TEXT;")
       try setUserVersion(2)
   }
   ```
3. Migrations run automatically on app launch. Each block only runs once — the version check ensures idempotency.

### Adding New Metadata Fields

1. Add the field to `LibraryBook` in `LibraryBook.swift`
2. Write a database migration (see above) to add the column
3. Update `BookRepository` insert/update/read methods to include the new column
4. Add a field to `BookEditView` for user editing
5. Update `ExtractedMetadata` and the relevant `MetadataExtractor` if the field can be auto-extracted from the file format

### Debugging

The database file can be inspected directly with any SQLite client:

```sh
sqlite3 ~/Library/Application\ Support/Athenaeum/library.db
.tables
.schema books
SELECT * FROM books LIMIT 5;
```
