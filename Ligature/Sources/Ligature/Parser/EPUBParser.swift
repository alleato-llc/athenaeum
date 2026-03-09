import Foundation
import ZIPFoundation

public struct EPUBParser {
    public init() {}

    public func parse(at url: URL) throws -> EPUBBook {
        let extractedURL = try extractEPUB(at: url)
        let opfPath = try findOPFPath(in: extractedURL)
        let opfURL = extractedURL.appendingPathComponent(opfPath)
        let opfDirectory = opfURL.deletingLastPathComponent()

        let opfData = try Data(contentsOf: opfURL)
        let opfParser = OPFParser()
        let opfResult = try opfParser.parse(data: opfData)

        let tocParser: TOCParser = opfResult.metadata.version == .epub3
            ? EPUB3TOCParser()
            : EPUB2TOCParser()

        var toc: [EPUBBook.TOCEntry] = []
        if let tocHref = opfResult.tocHref {
            let tocURL = opfDirectory.appendingPathComponent(tocHref)
            if let tocData = try? Data(contentsOf: tocURL) {
                toc = try tocParser.parse(data: tocData)
            }
        }

        // If EPUB3 TOC parsing fails or is empty, fall back to NCX
        if toc.isEmpty, opfResult.metadata.version == .epub3, let ncxHref = opfResult.ncxHref {
            let ncxURL = opfDirectory.appendingPathComponent(ncxHref)
            if let ncxData = try? Data(contentsOf: ncxURL) {
                toc = try EPUB2TOCParser().parse(data: ncxData)
            }
        }

        let spine = opfResult.spine.compactMap { spineRef -> EPUBBook.SpineItem? in
            guard let manifest = opfResult.manifest[spineRef.idref] else { return nil }
            return EPUBBook.SpineItem(
                id: manifest.id,
                href: manifest.href,
                mediaType: manifest.mediaType
            )
        }

        return EPUBBook(
            title: opfResult.metadata.title,
            author: opfResult.metadata.author,
            language: opfResult.metadata.language,
            spine: spine,
            tableOfContents: toc,
            baseURL: opfDirectory,
            extractedURL: extractedURL
        )
    }

    private func extractEPUB(at url: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Ligature-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try FileManager.default.unzipItem(at: url, to: tempDir)
        return tempDir
    }

    private func findOPFPath(in directory: URL) throws -> String {
        let containerURL = directory
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")
        let containerData = try Data(contentsOf: containerURL)
        let parser = ContainerXMLParser()
        return try parser.parse(data: containerData)
    }
}

public enum EPUBError: LocalizedError {
    case extractionFailed
    case containerNotFound
    case opfNotFound
    case invalidFormat

    public var errorDescription: String? {
        switch self {
        case .extractionFailed: return "Failed to extract EPUB file"
        case .containerNotFound: return "container.xml not found"
        case .opfNotFound: return "OPF file not found"
        case .invalidFormat: return "Invalid EPUB format"
        }
    }
}
