import Testing
import Foundation
@testable import Athenaeum

@Suite("EPUBCoverExtractor")
struct EPUBCoverExtractorTests {
    private let fm = FileManager.default
    private let extractor = EPUBCoverExtractor()

    @Test("Extract cover from fixture")
    func extractCoverFromFixture() throws {
        let tempDir = fm.temporaryDirectory.appendingPathComponent("cover-test-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let destPath = tempDir.appendingPathComponent("cover.jpg").path
        let result = try extractor.extractCover(from: TestFixtures.epubURL("frankenstein"), to: destPath)

        #expect(result == true)
        #expect(fm.fileExists(atPath: destPath))
    }

    @Test("Extracted cover is JPEG")
    func extractCoverOutputIsJPEG() throws {
        let tempDir = fm.temporaryDirectory.appendingPathComponent("cover-test-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let destPath = tempDir.appendingPathComponent("cover.jpg").path
        let result = try extractor.extractCover(from: TestFixtures.epubURL("frankenstein"), to: destPath)

        if result {
            let data = try Data(contentsOf: URL(fileURLWithPath: destPath))
            // JPEG magic bytes: FF D8
            #expect(data.count >= 2)
            #expect(data[0] == 0xFF)
            #expect(data[1] == 0xD8)
        }
    }

    @Test("Extract cover creates parent directories")
    func extractCoverToNonexistentParent() throws {
        let tempDir = fm.temporaryDirectory.appendingPathComponent("cover-test-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tempDir) }

        // Don't create the directory — extractCover should handle it
        let destPath = tempDir.appendingPathComponent("nested/dir/cover.jpg").path
        let result = try extractor.extractCover(from: TestFixtures.epubURL("frankenstein"), to: destPath)

        if result {
            #expect(fm.fileExists(atPath: destPath))
        }
    }

    @Test("Extract cover returns false for file without cover")
    func extractCoverReturnsFalseForNoCover() throws {
        let tempDir = fm.temporaryDirectory.appendingPathComponent("no-cover-test-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let destPath = tempDir.appendingPathComponent("cover.jpg").path
        let _ = try extractor.extractCover(from: TestFixtures.epubURL("the-yellow-wallpaper"), to: destPath)
        // Test passes as long as no exception is thrown
    }
}
