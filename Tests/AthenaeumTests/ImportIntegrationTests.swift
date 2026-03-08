import Testing
import Foundation
@testable import Athenaeum

@Suite("Import Integration")
struct ImportIntegrationTests {
    private let fm = FileManager.default

    @Test("Import EPUB end to end")
    func importEPUBEndToEnd() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }

        let tempEPUB = try TestFixtures.copyToTemp("a-christmas-carol")
        defer { try? fm.removeItem(at: tempEPUB.deletingLastPathComponent()) }

        let book = try env.importer.importBook(from: tempEPUB)

        // Book in DB
        let all = try env.bookRepo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].book.title.contains("Christmas Carol"))

        // File at expected path
        #expect(fm.fileExists(atPath: book.filePath))

        // Metadata populated
        #expect(!book.title.isEmpty)
    }

    @Test("Import sets correct format")
    func importSetsCorrectFormat() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }

        let tempEPUB = try TestFixtures.copyToTemp("metamorphosis")
        defer { try? fm.removeItem(at: tempEPUB.deletingLastPathComponent()) }

        let book = try env.importer.importBook(from: tempEPUB)
        #expect(book.format == .epub)
    }

    @Test("Import extracts cover")
    func importExtractsCover() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }

        let tempEPUB = try TestFixtures.copyToTemp("frankenstein")
        defer { try? fm.removeItem(at: tempEPUB.deletingLastPathComponent()) }

        let book = try env.importer.importBook(from: tempEPUB)

        if let coverPath = book.coverPath {
            #expect(fm.fileExists(atPath: coverPath))
        }
    }

    @Test("Import duplicate throws")
    func importDuplicateThrows() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }

        let tempEPUB1 = try TestFixtures.copyToTemp("a-christmas-carol")
        defer { try? fm.removeItem(at: tempEPUB1.deletingLastPathComponent()) }

        _ = try env.importer.importBook(from: tempEPUB1)

        let tempEPUB2 = try TestFixtures.copyToTemp("a-christmas-carol")
        defer { try? fm.removeItem(at: tempEPUB2.deletingLastPathComponent()) }

        #expect(throws: ImportError.self) {
            _ = try env.importer.importBook(from: tempEPUB2)
        }
    }

    @Test("Import creates author directory layout")
    func importCreatesAuthorDirectoryLayout() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }

        let tempEPUB = try TestFixtures.copyToTemp("frankenstein")
        defer { try? fm.removeItem(at: tempEPUB.deletingLastPathComponent()) }

        let book = try env.importer.importBook(from: tempEPUB)

        #expect(book.filePath.contains("books/"))
    }

    @Test("Delete after import cleans up")
    func deleteAfterImportCleansUp() throws {
        let env = try TestImportEnvironment.create()
        defer { env.cleanup() }

        let tempEPUB = try TestFixtures.copyToTemp("metamorphosis")
        defer { try? fm.removeItem(at: tempEPUB.deletingLastPathComponent()) }

        let book = try env.importer.importBook(from: tempEPUB)
        let filePath = book.filePath

        try env.importer.deleteBook(book)

        #expect(!fm.fileExists(atPath: filePath))
        #expect(try env.bookRepo.fetchAll().isEmpty)
    }
}
