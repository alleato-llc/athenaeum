import Foundation
import AppKit
import Ligature

public protocol CoverExtractor {
    func extractCover(from url: URL, to destinationPath: String) throws -> Bool
}

public class EPUBCoverExtractor: CoverExtractor {
    public init() {}

    public func extractCover(from url: URL, to destinationPath: String) throws -> Bool {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Ligature-cover-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", tempDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return false }

        let containerURL = tempDir
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")
        guard let containerData = try? Data(contentsOf: containerURL) else { return false }
        let containerParser = ContainerXMLParser()
        guard let opfPath = try? containerParser.parse(data: containerData) else { return false }

        let opfURL = tempDir.appendingPathComponent(opfPath)
        let opfDirectory = opfURL.deletingLastPathComponent()
        guard let opfData = try? Data(contentsOf: opfURL) else { return false }

        let coverParser = CoverReferenceParser()
        guard let coverHref = coverParser.parse(data: opfData) else { return false }

        let coverURL = opfDirectory.appendingPathComponent(coverHref)
        guard let imageData = try? Data(contentsOf: coverURL) else { return false }

        guard let image = NSImage(data: imageData),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 0.85])
        else { return false }

        let destURL = URL(fileURLWithPath: destinationPath)
        try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try jpegData.write(to: destURL)
        return true
    }
}

/// Parses OPF to find the cover image href
class CoverReferenceParser: NSObject, XMLParserDelegate {
    private var manifest: [String: String] = [:]
    private var coverId: String?
    private var coverHrefFromProperties: String?

    func parse(data: Data) -> String? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.parse()

        if let href = coverHrefFromProperties { return href }
        if let id = coverId, let href = manifest[id] { return href }
        return nil
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        if localName == "item" {
            if let id = attributes["id"], let href = attributes["href"] {
                manifest[id] = href
                if let props = attributes["properties"], props.contains("cover-image") {
                    coverHrefFromProperties = href
                }
            }
        } else if localName == "meta" {
            if attributes["name"] == "cover", let content = attributes["content"] {
                coverId = content
            }
        }
    }
}
