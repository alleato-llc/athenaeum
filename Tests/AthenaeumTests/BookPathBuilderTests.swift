import Testing
@testable import Athenaeum

@Suite("BookPathBuilder")
struct BookPathBuilderTests {
    @Test("Author prefix uses first two characters uppercased")
    func authorPrefix() {
        #expect(BookPathBuilder.authorPrefix("Miguel de Cervantes") == "MI")
        #expect(BookPathBuilder.authorPrefix("J") == "J")
        #expect(BookPathBuilder.authorPrefix("") == "UN")
        #expect(BookPathBuilder.authorPrefix("  ") == "UN")
    }

    @Test("Sanitize replaces unsafe characters and trims")
    func sanitizePathComponent() {
        #expect(BookPathBuilder.sanitizePathComponent("Hello/World") == "Hello_World")
        #expect(BookPathBuilder.sanitizePathComponent("Book: A Story") == "Book_ A Story")
        #expect(BookPathBuilder.sanitizePathComponent("...leading dots") == "leading dots")
        #expect(BookPathBuilder.sanitizePathComponent("") == "Unknown")
        #expect(BookPathBuilder.sanitizePathComponent(String(repeating: "a", count: 200)) ==
                String(repeating: "a", count: 100))
    }

    @Test("Book directory follows prefix/author/title structure")
    func bookDirectoryStructure() {
        let builder = BookPathBuilder(libraryPath: "/tmp/library")
        let dir = builder.bookDirectory(authorName: "Miguel de Cervantes", title: "Don Quixote")
        #expect(dir == "/tmp/library/books/MI/Miguel de Cervantes/Don Quixote")
    }

    @Test("Empty author falls back to Unknown")
    func bookDirectoryEmptyAuthor() {
        let builder = BookPathBuilder(libraryPath: "/tmp/library")
        let dir = builder.bookDirectory(authorName: "", title: "Orphan Book")
        #expect(dir == "/tmp/library/books/UN/Unknown/Orphan Book")
    }

    @Test("Empty title falls back to Untitled")
    func bookDirectoryEmptyTitle() {
        let builder = BookPathBuilder(libraryPath: "/tmp/library")
        let dir = builder.bookDirectory(authorName: "Author", title: "")
        #expect(dir == "/tmp/library/books/AU/Author/Untitled")
    }

    @Test("Book file path ends with bookId.ext")
    func bookFilePath() {
        let builder = BookPathBuilder(libraryPath: "/tmp/library")
        let path = builder.bookFilePath(authorName: "Author", title: "Title",
                                        bookId: "abc123", fileExtension: "epub")
        #expect(path.hasSuffix("/abc123.epub"))
        #expect(path.contains("/AU/Author/Title/"))
    }

    @Test("Cover file path ends with bookId.jpg")
    func coverFilePath() {
        let builder = BookPathBuilder(libraryPath: "/tmp/library")
        let path = builder.coverFilePath(authorName: "Author", title: "Title", bookId: "abc123")
        #expect(path.hasSuffix("/abc123.jpg"))
        #expect(path.contains("/AU/Author/Title/"))
    }
}
