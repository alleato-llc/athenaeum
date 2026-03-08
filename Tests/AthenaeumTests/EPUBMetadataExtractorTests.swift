import Testing
import Foundation
@testable import Athenaeum

@Suite("EPUBMetadataExtractor")
struct EPUBMetadataExtractorTests {
    private let extractor = EPUBMetadataExtractor()

    @Test("Extract A Christmas Carol metadata")
    func extractChristmasCarolMetadata() throws {
        let metadata = try extractor.extract(from: TestFixtures.epubURL("a-christmas-carol"))

        #expect(metadata.title.contains("Christmas Carol"))
        #expect(metadata.authors.contains { $0.contains("Dickens") })
    }

    @Test("Extract Metamorphosis metadata")
    func extractMetamorphosisMetadata() throws {
        let metadata = try extractor.extract(from: TestFixtures.epubURL("metamorphosis"))

        #expect(metadata.title.contains("Metamorphosis"))
        #expect(metadata.authors.contains { $0.contains("Kafka") })
    }

    @Test("Extract Frankenstein metadata")
    func extractFrankensteinMetadata() throws {
        let metadata = try extractor.extract(from: TestFixtures.epubURL("frankenstein"))

        #expect(metadata.title.contains("Frankenstein"))
        #expect(metadata.authors.contains { $0.contains("Shelley") })
    }

    @Test("All fixtures extract without error")
    func allFixturesExtractWithoutError() throws {
        let fixtures = ["a-christmas-carol", "metamorphosis", "frankenstein", "the-yellow-wallpaper"]
        for name in fixtures {
            let metadata = try extractor.extract(from: TestFixtures.epubURL(name))
            #expect(!metadata.title.isEmpty, "Title should be non-empty for \(name)")
        }
    }

    @Test("Extracted metadata has language")
    func extractedMetadataHasLanguage() throws {
        let metadata = try extractor.extract(from: TestFixtures.epubURL("a-christmas-carol"))
        #expect(metadata.language != nil)
        #expect(!(metadata.language?.isEmpty ?? true))
    }
}
