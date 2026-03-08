import Foundation
import AppKit

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

        // Copy file to library
        let booksDir = (libraryPath as NSString).appendingPathComponent("books")
        try FileManager.default.createDirectory(atPath: booksDir, withIntermediateDirectories: true)
        let destFileName = "\(bookId).\(fileExtension)"
        let destPath = (booksDir as NSString).appendingPathComponent(destFileName)
        try FileManager.default.copyItem(atPath: sourceURL.path, toPath: destPath)

        // Extract cover
        var coverPath: String?
        let coverExtractor = self.coverExtractor(for: format)
        if let coverExt = coverExtractor {
            let coversDir = (libraryPath as NSString).appendingPathComponent("covers")
            let coverDest = (coversDir as NSString).appendingPathComponent("\(bookId).jpg")
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
        // Delete file from library
        try? FileManager.default.removeItem(atPath: book.filePath)
        // Delete cover
        if let coverPath = book.coverPath {
            try? FileManager.default.removeItem(atPath: coverPath)
        }
        // Delete from database
        try bookRepository.delete(bookId: book.id)
    }

    public func updateCover(bookId: String, from imageURL: URL) throws -> String {
        let coversDir = (libraryPath as NSString).appendingPathComponent("covers")
        try FileManager.default.createDirectory(atPath: coversDir, withIntermediateDirectories: true)
        let destPath = (coversDir as NSString).appendingPathComponent("\(bookId).jpg")

        // Remove old cover if it exists
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
            return String(format: NSLocalizedString("import.error.duplicate", bundle: Bundle.module, comment: ""), title)
        }
    }
}
