import Foundation

class DirectoryScanner {
    static let skippedExtensions: Set<String> = [
        "pdf", "mobi", "txt", "azw", "azw3", "djvu",
        "cbz", "cbr", "fb2", "doc", "docx", "rtf"
    ]

    private let bookImporter: BookImporter

    init(bookImporter: BookImporter) {
        self.bookImporter = bookImporter
    }

    func scanAndImport(
        directory: URL,
        progress: @escaping (Int, Int) -> Void
    ) -> DirectoryImportResult {
        // Phase 1: Scan
        var epubURLs: [URL] = []
        var skippedFiles: [SkippedFile] = []

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return DirectoryImportResult(importedCount: 0, skippedFiles: [], failedImports: [])
        }

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "epub" {
                epubURLs.append(fileURL)
            } else if Self.skippedExtensions.contains(ext) {
                skippedFiles.append(SkippedFile(
                    filename: fileURL.lastPathComponent,
                    fileExtension: ext,
                    path: fileURL.path
                ))
            }
        }

        // Phase 2: Import
        let total = epubURLs.count
        var importedCount = 0
        var failedImports: [FailedImport] = []

        for (index, url) in epubURLs.enumerated() {
            do {
                _ = try bookImporter.importBook(from: url)
                importedCount += 1
            } catch let error as ImportError {
                let reason: String
                switch error {
                case .duplicateBook(let title):
                    reason = "Duplicate: \(title)"
                default:
                    reason = error.localizedDescription
                }
                failedImports.append(FailedImport(
                    filename: url.lastPathComponent,
                    reason: reason
                ))
            } catch {
                failedImports.append(FailedImport(
                    filename: url.lastPathComponent,
                    reason: error.localizedDescription
                ))
            }
            progress(index + 1, total)
        }

        return DirectoryImportResult(
            importedCount: importedCount,
            skippedFiles: skippedFiles,
            failedImports: failedImports
        )
    }
}
