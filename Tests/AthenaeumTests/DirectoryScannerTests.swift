import Testing
import Foundation
@testable import Athenaeum

@Suite("DirectoryScanner")
struct DirectoryScannerTests {
    private let fm = FileManager.default

    @Test("Scan empty directory")
    func scanEmptyDirectory() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }
        let scanner = env.makeScanner()

        let scanDir = fm.temporaryDirectory.appendingPathComponent("scan-empty-\(UUID().uuidString)")
        try fm.createDirectory(at: scanDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scanDir) }

        let result = scanner.scanAndImport(directory: scanDir) { _, _ in }

        #expect(result.importedCount == 0)
        #expect(result.skippedFiles.isEmpty)
        #expect(result.failedImports.isEmpty)
    }

    @Test("Scan directory with EPUBs")
    func scanDirectoryWithEPUBs() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }
        let scanner = env.makeScanner()

        let scanDir = fm.temporaryDirectory.appendingPathComponent("scan-epubs-\(UUID().uuidString)")
        try fm.createDirectory(at: scanDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scanDir) }

        try fm.copyItem(at: TestFixtures.epubURL("a-christmas-carol"),
                        to: scanDir.appendingPathComponent("a-christmas-carol.epub"))
        try fm.copyItem(at: TestFixtures.epubURL("metamorphosis"),
                        to: scanDir.appendingPathComponent("metamorphosis.epub"))

        let result = scanner.scanAndImport(directory: scanDir) { _, _ in }

        #expect(result.importedCount == 2)
    }

    @Test("Scan skips non-EPUB files")
    func scanSkipsNonEPUBFiles() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }
        let scanner = env.makeScanner()

        let scanDir = fm.temporaryDirectory.appendingPathComponent("scan-skip-\(UUID().uuidString)")
        try fm.createDirectory(at: scanDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scanDir) }

        try "fake".write(to: scanDir.appendingPathComponent("book.pdf"), atomically: true, encoding: .utf8)
        try "fake".write(to: scanDir.appendingPathComponent("book.mobi"), atomically: true, encoding: .utf8)

        let result = scanner.scanAndImport(directory: scanDir) { _, _ in }

        #expect(result.importedCount == 0)
        #expect(result.skippedFiles.count == 2)

        let extensions = Set(result.skippedFiles.map(\.fileExtension))
        #expect(extensions.contains("pdf"))
        #expect(extensions.contains("mobi"))
    }

    @Test("Scan reports progress")
    func scanReportsProgress() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }
        let scanner = env.makeScanner()

        let scanDir = fm.temporaryDirectory.appendingPathComponent("scan-progress-\(UUID().uuidString)")
        try fm.createDirectory(at: scanDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scanDir) }

        try fm.copyItem(at: TestFixtures.epubURL("a-christmas-carol"),
                        to: scanDir.appendingPathComponent("a-christmas-carol.epub"))
        try fm.copyItem(at: TestFixtures.epubURL("metamorphosis"),
                        to: scanDir.appendingPathComponent("metamorphosis.epub"))

        var progressUpdates: [(current: Int, total: Int)] = []
        let result = scanner.scanAndImport(directory: scanDir) { current, total in
            progressUpdates.append((current, total))
        }

        #expect(result.importedCount == 2)
        #expect(progressUpdates.count == 2)
        for update in progressUpdates {
            #expect(update.total == 2)
        }
        #expect(progressUpdates[0].current == 1)
        #expect(progressUpdates[1].current == 2)
    }

    @Test("Scan handles duplicates")
    func scanHandlesDuplicates() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }
        let scanner = env.makeScanner()

        let scanDir = fm.temporaryDirectory.appendingPathComponent("scan-dup-\(UUID().uuidString)")
        try fm.createDirectory(at: scanDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scanDir) }

        try fm.copyItem(at: TestFixtures.epubURL("a-christmas-carol"),
                        to: scanDir.appendingPathComponent("carol1.epub"))
        try fm.copyItem(at: TestFixtures.epubURL("a-christmas-carol"),
                        to: scanDir.appendingPathComponent("carol2.epub"))

        let result = scanner.scanAndImport(directory: scanDir) { _, _ in }

        #expect(result.importedCount == 1)
        #expect(result.failedImports.count == 1)
        #expect(result.failedImports[0].reason.contains("Duplicate"))
    }
}
