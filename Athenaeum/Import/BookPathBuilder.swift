import Foundation

/// Constructs filesystem paths for the book storage layout:
/// `books/{prefix}/{author}/{title}/{bookId}.{ext}`
///
/// Cover images are stored alongside the book file in the same directory.
public struct BookPathBuilder {
    public let libraryPath: String

    public init(libraryPath: String) {
        self.libraryPath = libraryPath
    }

    /// Directory for a book: `{libraryPath}/books/{prefix}/{author}/{title}/`
    public func bookDirectory(authorName: String, title: String) -> String {
        let author = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveAuthor = author.isEmpty ? "Unknown" : author
        let prefix = Self.authorPrefix(effectiveAuthor)
        let sanitizedAuthor = Self.sanitizePathComponent(effectiveAuthor)
        let sanitizedTitle = Self.sanitizePathComponent(title.isEmpty ? "Untitled" : title)

        return URL(fileURLWithPath: libraryPath)
            .appendingPathComponent("books")
            .appendingPathComponent(prefix)
            .appendingPathComponent(sanitizedAuthor)
            .appendingPathComponent(sanitizedTitle)
            .path
    }

    /// Full path for a book file: `{bookDirectory}/{bookId}.{ext}`
    public func bookFilePath(authorName: String, title: String, bookId: String, fileExtension: String) -> String {
        let dir = bookDirectory(authorName: authorName, title: title)
        return (dir as NSString).appendingPathComponent("\(bookId).\(fileExtension)")
    }

    /// Full path for a cover image: `{bookDirectory}/{bookId}.jpg`
    public func coverFilePath(authorName: String, title: String, bookId: String) -> String {
        let dir = bookDirectory(authorName: authorName, title: title)
        return (dir as NSString).appendingPathComponent("\(bookId).jpg")
    }

    /// First two characters of the author name, uppercased. Falls back to "UN" for empty names.
    public static func authorPrefix(_ authorName: String) -> String {
        let name = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "UN" }
        let prefix = String(name.prefix(2))
        return prefix.uppercased()
    }

    /// Replaces filesystem-unsafe characters and trims to a reasonable length.
    public static func sanitizePathComponent(_ name: String) -> String {
        var cleaned = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        if cleaned.isEmpty { return "Unknown" }
        if cleaned.count > 100 { cleaned = String(cleaned.prefix(100)) }
        return cleaned
    }
}
