import Foundation
import AppKit
import PDFKit
import Forma

public enum ExportJobStatus: Equatable {
    case pending
    case exporting(current: Int, total: Int)
    case saving
    case completed
    case failed(String)
    case cancelled
}

public struct ExportJob: Identifiable {
    public let id: String
    public let bookTitle: String
    public let destinationURL: URL
    public var status: ExportJobStatus

    public var isActive: Bool {
        switch status {
        case .pending, .exporting, .saving: return true
        default: return false
        }
    }

    public var progress: Double {
        switch status {
        case .exporting(let current, let total) where total > 0:
            return Double(current) / Double(total)
        case .completed: return 1.0
        default: return 0.0
        }
    }
}

public class ExportJobManager: ObservableObject {
    @Published public var jobs: [ExportJob] = []
    private var exportServices: [String: PDFExportService] = [:]

    public var hasActiveJobs: Bool {
        jobs.contains { $0.isActive }
    }

    public var activeJobCount: Int {
        jobs.filter(\.isActive).count
    }

    public init() {}

    public func startExport(entry: BookEntry, fontFamily: String = "Georgia") {
        guard entry.book.format == .epub else { return }

        let epubURL = URL(fileURLWithPath: entry.book.filePath)

        // Check for existing PDF beside the EPUB
        let siblingPDF = epubURL.deletingPathExtension().appendingPathExtension("pdf")
        if FileManager.default.fileExists(atPath: siblingPDF.path) {
            showSavePanelForCachedPDF(siblingPDF, title: entry.book.title)
            return
        }

        // Show save panel first (before starting async work)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(entry.book.title).pdf"

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        let jobId = UUID().uuidString
        let job = ExportJob(id: jobId, bookTitle: entry.book.title,
                            destinationURL: destinationURL, status: .pending)
        jobs.append(job)

        // Parse EPUB
        let parser = EPUBParser()
        let epubBook: EPUBBook
        do {
            epubBook = try parser.parse(at: epubURL)
        } catch {
            updateJob(id: jobId, status: .failed("Failed to parse EPUB: \(error.localizedDescription)"))
            return
        }

        let service = PDFExportService()
        exportServices[jobId] = service
        updateJob(id: jobId, status: .exporting(current: 0, total: epubBook.spine.count))

        service.exportToPDF(book: epubBook, fontFamily: fontFamily, progress: { [weak self] current, total in
            DispatchQueue.main.async {
                self?.updateJob(id: jobId, status: .exporting(current: current, total: total))
            }
        }, completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.exportServices.removeValue(forKey: jobId)

                switch result {
                case .success(let document):
                    self.updateJob(id: jobId, status: .saving)

                    // Save to user-chosen destination
                    if document.write(to: destinationURL) {
                        // Also cache beside the EPUB for future use
                        if siblingPDF != destinationURL {
                            document.write(to: siblingPDF)
                        }
                        self.updateJob(id: jobId, status: .completed)
                    } else {
                        self.updateJob(id: jobId, status: .failed("Failed to write PDF file."))
                    }

                case .failure(let error):
                    if (error as? PDFExportError) == .cancelled {
                        self.updateJob(id: jobId, status: .cancelled)
                    } else {
                        self.updateJob(id: jobId, status: .failed(error.localizedDescription))
                    }
                }

                epubBook.cleanup()
            }
        })
    }

    public func cancelJob(id: String) {
        exportServices[id]?.cancel()
        exportServices.removeValue(forKey: id)
        updateJob(id: id, status: .cancelled)
    }

    public func removeJob(id: String) {
        jobs.removeAll { $0.id == id }
    }

    public func clearCompleted() {
        jobs.removeAll { !$0.isActive }
    }

    private func updateJob(id: String, status: ExportJobStatus) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            jobs[index].status = status
        }
    }

    private func showSavePanelForCachedPDF(_ cachedURL: URL, title: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title).pdf"

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: cachedURL, to: destinationURL)
        } catch {
            // Create a transient job to show the error
            let jobId = UUID().uuidString
            jobs.append(ExportJob(id: jobId, bookTitle: title,
                                  destinationURL: destinationURL,
                                  status: .failed("Failed to copy PDF: \(error.localizedDescription)")))
        }
    }
}
