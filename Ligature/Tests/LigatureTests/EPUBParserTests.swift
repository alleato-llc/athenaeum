import Testing
import Foundation
@testable import Ligature

@Suite("EPUBParser")
struct EPUBParserTests {
    private let parser = EPUBParser()

    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: "epub", subdirectory: "Resources")!
    }

    @Test("Parse A Christmas Carol")
    func parseChristmasCarol() throws {
        let book = try parser.parse(at: fixtureURL("a-christmas-carol"))
        defer { book.cleanup() }

        #expect(book.title.contains("Christmas Carol"))
        #expect(book.author.contains("Dickens"))
        #expect(!book.spine.isEmpty)
        #expect(!book.tableOfContents.isEmpty)
    }

    @Test("Parse Metamorphosis")
    func parseMetamorphosis() throws {
        let book = try parser.parse(at: fixtureURL("metamorphosis"))
        defer { book.cleanup() }

        #expect(book.title.contains("Metamorphosis"))
        #expect(book.author.contains("Kafka"))
        #expect(!book.spine.isEmpty)
    }

    @Test("Parse Frankenstein has many spine items")
    func parseFrankenstein() throws {
        let book = try parser.parse(at: fixtureURL("frankenstein"))
        defer { book.cleanup() }

        #expect(book.title.contains("Frankenstein"))
        #expect(book.author.contains("Shelley"))
        #expect(book.spine.count > 10)
    }

    @Test("Parse The Yellow Wallpaper")
    func parseYellowWallpaper() throws {
        let book = try parser.parse(at: fixtureURL("the-yellow-wallpaper"))
        defer { book.cleanup() }

        #expect(!book.title.isEmpty)
        #expect(!book.spine.isEmpty)
    }

    @Test("Spine items have valid hrefs")
    func spineItemsHaveValidHrefs() throws {
        let book = try parser.parse(at: fixtureURL("a-christmas-carol"))
        defer { book.cleanup() }

        for item in book.spine {
            #expect(!item.href.isEmpty)
            #expect(item.mediaType.contains("xhtml") || item.mediaType.contains("xml"),
                    "mediaType '\(item.mediaType)' should contain xhtml or xml")
        }
    }

    @Test("TOC entries have labels")
    func tocEntriesHaveLabels() throws {
        let book = try parser.parse(at: fixtureURL("frankenstein"))
        defer { book.cleanup() }

        func checkEntries(_ entries: [EPUBBook.TOCEntry]) {
            for entry in entries {
                #expect(!entry.title.isEmpty)
                #expect(!entry.href.isEmpty)
                checkEntries(entry.children)
            }
        }
        checkEntries(book.tableOfContents)
    }

    @Test("baseURL points to valid directory")
    func baseURLPointsToValidDirectory() throws {
        let book = try parser.parse(at: fixtureURL("a-christmas-carol"))
        defer { book.cleanup() }

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: book.baseURL.path, isDirectory: &isDir)
        #expect(exists)
        #expect(isDir.boolValue)
        #expect(book.baseURL.path.hasPrefix(book.extractedURL.path))
    }

    @Test("Cleanup removes extracted files")
    func cleanupRemovesExtractedFiles() throws {
        let book = try parser.parse(at: fixtureURL("metamorphosis"))
        let extractedPath = book.extractedURL.path

        #expect(FileManager.default.fileExists(atPath: extractedPath))
        book.cleanup()
        #expect(!FileManager.default.fileExists(atPath: extractedPath))
    }

    @Test("Parse invalid file throws")
    func parseInvalidFileThrows() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid-\(UUID().uuidString).epub")
        try "not an epub".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        #expect(throws: EPUBError.self) {
            _ = try parser.parse(at: tempFile)
        }
    }

    @Test("Parsed language is populated")
    func parsedLanguageIsPopulated() throws {
        let book = try parser.parse(at: fixtureURL("a-christmas-carol"))
        defer { book.cleanup() }

        #expect(!book.language.isEmpty)
    }
}
