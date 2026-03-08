import Foundation
import AppKit
import Ligature

public class BookImporter {
    private let bookRepository: BookRepository
    private let libraryPath: String

    public init(bookRepository: BookRepository, libraryPath: String) {
        self.bookRepository = bookRepository
        self.libraryPath = libraryPath
    }

    public func importBook(from sourceURL: URL) throws -> LibraryBook {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard let format = BookFormat(fileExtension: fileExtension) else {
            throw ImportError.unsupportedFormat(fileExtension)
        }

        // Extract metadata
        let extractor = metadataExtractor(for: format)
        let metadata = try extractor.extract(from: sourceURL)

        // Check for duplicate
        if try bookRepository.bookExists(title: metadata.title, authorNames: metadata.authors) {
            throw ImportError.duplicateBook(metadata.title)
        }

        let bookId = UUID().uuidString
        let primaryAuthor = metadata.authors.first ?? ""
        let pathBuilder = BookPathBuilder(libraryPath: libraryPath)

        // Create book directory
        let bookDir = pathBuilder.bookDirectory(authorName: primaryAuthor, title: metadata.title)
        try FileManager.default.createDirectory(atPath: bookDir, withIntermediateDirectories: true)

        // Copy file to library
        let destPath = pathBuilder.bookFilePath(authorName: primaryAuthor, title: metadata.title,
                                                bookId: bookId, fileExtension: fileExtension)
        try FileManager.default.copyItem(atPath: sourceURL.path, toPath: destPath)

        // Extract cover to the same directory
        var coverPath: String?
        let coverExtractor = self.coverExtractor(for: format)
        if let coverExt = coverExtractor {
            let coverDest = pathBuilder.coverFilePath(authorName: primaryAuthor, title: metadata.title,
                                                      bookId: bookId)
            if (try? coverExt.extractCover(from: sourceURL, to: coverDest)) == true {
                coverPath = coverDest
            }
        }

        // Build model
        let authors = metadata.authors.map { Author(name: $0) }
        let book = LibraryBook(
            id: bookId,
            title: metadata.title,
            year: metadata.year,
            genre: metadata.genre,
            pageCount: metadata.pageCount,
            format: format,
            identifiers: metadata.identifiers,
            coverPath: coverPath,
            filePath: destPath,
            dateAdded: Date()
        )

        try bookRepository.insert(book: book, authors: authors)
        return book
    }

    public func deleteBook(_ book: LibraryBook) throws {
        let bookDir = (book.filePath as NSString).deletingLastPathComponent

        try? FileManager.default.removeItem(atPath: book.filePath)
        if let coverPath = book.coverPath {
            try? FileManager.default.removeItem(atPath: coverPath)
        }

        // Clean up empty directories up to the books/ root
        cleanupEmptyDirectories(from: bookDir)

        try bookRepository.delete(bookId: book.id)
    }

    public func updateCover(bookId: String, bookFilePath: String, from imageURL: URL) throws -> String {
        let bookDir = (bookFilePath as NSString).deletingLastPathComponent
        let destPath = (bookDir as NSString).appendingPathComponent("\(bookId).jpg")

        try? FileManager.default.removeItem(atPath: destPath)

        let imageData = try Data(contentsOf: imageURL)
        guard let image = NSImage(data: imageData),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else {
            throw ImportError.coverConversionFailed
        }

        try jpegData.write(to: URL(fileURLWithPath: destPath))
        return destPath
    }

    /// Migrates books from the old flat layout (`books/{uuid}.epub`, `covers/{uuid}.jpg`)
    /// to the new author/title directory structure.
    public func migrateStorageLayout(books: [(book: LibraryBook, authors: [Author])]) {
        let pathBuilder = BookPathBuilder(libraryPath: libraryPath)
        let fm = FileManager.default

        for (book, authors) in books {
            let primaryAuthor = authors.first?.name ?? ""
            let newFilePath = pathBuilder.bookFilePath(authorName: primaryAuthor, title: book.title,
                                                       bookId: book.id, fileExtension: book.format.rawValue)

            // Skip if already at the new path
            if book.filePath == newFilePath { continue }

            // Skip if old file doesn't exist
            guard fm.fileExists(atPath: book.filePath) else { continue }

            let newBookDir = pathBuilder.bookDirectory(authorName: primaryAuthor, title: book.title)
            try? fm.createDirectory(atPath: newBookDir, withIntermediateDirectories: true)

            // Move book file
            try? fm.moveItem(atPath: book.filePath, toPath: newFilePath)

            // Move cover
            var newCoverPath: String?
            if let coverPath = book.coverPath, fm.fileExists(atPath: coverPath) {
                let dest = pathBuilder.coverFilePath(authorName: primaryAuthor, title: book.title, bookId: book.id)
                try? fm.moveItem(atPath: coverPath, toPath: dest)
                newCoverPath = dest
            }

            // Update database paths
            try? bookRepository.updatePaths(bookId: book.id, filePath: newFilePath,
                                            coverPath: newCoverPath ?? book.coverPath)
        }

        // Clean up old empty covers/ directory
        let oldCoversDir = (libraryPath as NSString).appendingPathComponent("covers")
        if let contents = try? fm.contentsOfDirectory(atPath: oldCoversDir), contents.isEmpty {
            try? fm.removeItem(atPath: oldCoversDir)
        }
    }

    private func cleanupEmptyDirectories(from path: String) {
        let booksDir = (libraryPath as NSString).appendingPathComponent("books")
        var current = path
        while current != booksDir && current.hasPrefix(booksDir) {
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: current)) ?? []
            if contents.isEmpty {
                try? FileManager.default.removeItem(atPath: current)
                current = (current as NSString).deletingLastPathComponent
            } else {
                break
            }
        }
    }

    private func metadataExtractor(for format: BookFormat) -> MetadataExtractor {
        switch format {
        case .epub:
            return EPUBMetadataExtractor()
        case .pdf, .txt:
            return FallbackMetadataExtractor()
        }
    }

    private func coverExtractor(for format: BookFormat) -> CoverExtractor? {
        switch format {
        case .epub:
            return EPUBCoverExtractor()
        case .pdf, .txt:
            return nil
        }
    }
}

/// Fallback for formats without metadata extraction (yet)
class FallbackMetadataExtractor: MetadataExtractor {
    func extract(from url: URL) throws -> ExtractedMetadata {
        let filename = url.deletingPathExtension().lastPathComponent
        return ExtractedMetadata(title: filename)
    }
}

public enum ImportError: LocalizedError {
    case unsupportedFormat(String)
    case coverConversionFailed
    case duplicateBook(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext): return "Unsupported file format: .\(ext)"
        case .coverConversionFailed: return "Failed to convert cover image"
        case .duplicateBook(let title):
            return String(format: NSLocalizedString("import.error.duplicate", bundle: .module, comment: ""), title)
        }
    }
}
