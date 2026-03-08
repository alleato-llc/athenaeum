import Foundation
import Ligature

public struct ExtractedMetadata {
    public var title: String
    public var authors: [String]
    public var year: Int?
    public var genre: String?
    public var pageCount: Int?
    public var identifiers: [String: String]
    public var language: String?

    public init(title: String, authors: [String] = [], year: Int? = nil,
                genre: String? = nil, pageCount: Int? = nil,
                identifiers: [String: String] = [:], language: String? = nil) {
        self.title = title
        self.authors = authors
        self.year = year
        self.genre = genre
        self.pageCount = pageCount
        self.identifiers = identifiers
        self.language = language
    }
}

public protocol MetadataExtractor {
    func extract(from url: URL) throws -> ExtractedMetadata
}

public class EPUBMetadataExtractor: MetadataExtractor {
    public init() {}

    public func extract(from url: URL) throws -> ExtractedMetadata {
        let parser = EPUBParser()
        let book = try parser.parse(at: url)

        var identifiers: [String: String] = [:]

        let extractedURL = book.extractedURL
        defer { book.cleanup() }

        let opfPath = try findOPFPath(in: extractedURL)
        let opfURL = extractedURL.appendingPathComponent(opfPath)
        let opfData = try Data(contentsOf: opfURL)
        let opfParser = OPFMetadataParser()
        let detailedMeta = opfParser.parse(data: opfData)

        if !detailedMeta.identifier.isEmpty {
            let id = detailedMeta.identifier
            if id.hasPrefix("urn:isbn:") {
                identifiers["isbn"] = String(id.dropFirst("urn:isbn:".count))
            } else if id.count == 13, id.allSatisfy(\.isNumber) {
                identifiers["isbn13"] = id
            } else if id.count == 10, id.allSatisfy({ $0.isNumber || $0 == "X" }) {
                identifiers["isbn"] = id
            } else {
                identifiers["identifier"] = id
            }
        }

        var year: Int?
        if let dateStr = detailedMeta.date {
            let components = dateStr.components(separatedBy: CharacterSet(charactersIn: "- /"))
            if let first = components.first, let y = Int(first), y > 1000, y < 3000 {
                year = y
            }
        }

        return ExtractedMetadata(
            title: book.title,
            authors: book.author.isEmpty ? [] : [book.author],
            year: year,
            genre: detailedMeta.subject,
            pageCount: nil,
            identifiers: identifiers,
            language: book.language
        )
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

/// Extracts additional metadata fields not captured by the main OPFParser
class OPFMetadataParser: NSObject, XMLParserDelegate {
    var identifier = ""
    var date: String?
    var subject: String?
    private var currentElement = ""
    private var currentText = ""
    private var inMetadata = false

    func parse(data: Data) -> OPFMetadataParser {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.parse()
        return self
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        if localName == "metadata" { inMetadata = true }
        currentElement = localName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inMetadata { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inMetadata && !trimmed.isEmpty {
            switch localName {
            case "identifier":
                if identifier.isEmpty { identifier = trimmed }
            case "date":
                if date == nil { date = trimmed }
            case "subject":
                if subject == nil { subject = trimmed }
            default:
                break
            }
        }

        if localName == "metadata" { inMetadata = false }
    }
}
