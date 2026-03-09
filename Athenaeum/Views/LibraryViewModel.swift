import Foundation
import AppKit
import SwiftUI
import Forma
import ZIPFoundation

public enum LibraryViewMode {
    case grid
    case table
}

public struct BookEntry: Identifiable {
    public let id: String
    public var book: LibraryBook
    public var authors: [Author]

    public var authorNames: String {
        authors.map(\.name).joined(separator: ", ")
    }
}

public class LibraryViewModel: ObservableObject {
    @Published public var books: [BookEntry] = []
    @Published public var viewMode: LibraryViewMode = .grid
    @Published public var searchQuery: String = ""
    @Published public var errorMessage: String?
    @Published public var settings: UserSettings
    @Published public var editingBook: BookEntry?
    @Published public var selectedBookId: String?
    @Published public var coverScale: Double = 1.0
    @Published public var isImportingDirectory = false
    @Published public var directoryImportProgress: (current: Int, total: Int)?
    @Published public var directoryImportResult: DirectoryImportResult?
    public let exportJobManager = ExportJobManager()
    public weak var window: NSWindow?

    private let bookRepository: BookRepository
    private let settingsRepository: SettingsRepository
    private let bookImporter: BookImporter
    private let chapterRepository: ChapterRepository
    private let highlightRepository: HighlightRepository
    private let bookmarkRepository: BookmarkRepository
    private let noteRepository: NoteRepository
    private let database: LibraryDatabase

    public init() {
        let libraryPath = UserSettings.defaultLibraryPath
        let dbPath = (libraryPath as NSString).appendingPathComponent("library.db")

        do {
            let db = try LibraryDatabase(path: dbPath)
            self.database = db
            self.bookRepository = BookRepository(database: db)
            self.settingsRepository = SettingsRepository(database: db)
            let chapterRepo = ChapterRepository(database: db)
            self.chapterRepository = chapterRepo
            self.highlightRepository = HighlightRepository(database: db, chapterRepository: chapterRepo)
            self.bookmarkRepository = BookmarkRepository(database: db, chapterRepository: chapterRepo)
            self.noteRepository = NoteRepository(database: db, chapterRepository: chapterRepo)
            let loadedSettings = (try? settingsRepository.loadSettings()) ?? UserSettings()
            self.settings = loadedSettings
            self.bookImporter = BookImporter(bookRepository: bookRepository,
                                             libraryPath: loadedSettings.libraryPath)
        } catch {
            fatalError("Failed to initialize library database: \(error.localizedDescription)")
        }

        loadBooks()
        migrateStorageIfNeeded()

        NotificationCenter.default.addObserver(forName: .saveReadingProgress, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let info = notification.userInfo,
                  let bookId = info["bookId"] as? String,
                  let chapterIndex = info["chapterIndex"] as? Int,
                  let scrollPosition = info["scrollPosition"] as? Double else { return }
            try? self.bookRepository.saveProgress(bookId: bookId, chapterIndex: chapterIndex,
                                                   scrollPosition: scrollPosition)
            if let index = self.books.firstIndex(where: { $0.id == bookId }) {
                self.books[index].book.readingPosition = ReadingPosition(chapter: chapterIndex, scroll: scrollPosition)
            }
        }

        NotificationCenter.default.addObserver(forName: .saveHighlights, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let info = notification.userInfo,
                  let bookId = info["bookId"] as? String,
                  let chapterIndex = info["chapterIndex"] as? Int,
                  let highlights = info["highlights"] as? [Highlight] else { return }
            try? self.highlightRepository.saveHighlights(bookId: bookId, chapterIndex: chapterIndex,
                                                          highlights: highlights)
        }

        NotificationCenter.default.addObserver(forName: .addBookmark, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let info = notification.userInfo,
                  let bookId = info["bookId"] as? String,
                  let chapterIndex = info["chapterIndex"] as? Int,
                  let scrollPosition = info["scrollPosition"] as? Double,
                  let label = info["label"] as? String,
                  let callback = info["callback"] as? (Bookmark) -> Void else { return }
            if let bookmark = try? self.bookmarkRepository.addBookmark(
                bookId: bookId, chapterIndex: chapterIndex,
                scrollPosition: scrollPosition, label: label) {
                callback(bookmark)
            }
        }

        NotificationCenter.default.addObserver(forName: .deleteBookmark, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let info = notification.userInfo,
                  let bookmarkId = info["bookmarkId"] as? String else { return }
            try? self.bookmarkRepository.deleteBookmark(id: bookmarkId)
        }

        NotificationCenter.default.addObserver(forName: .saveChapterNotes, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let info = notification.userInfo,
                  let bookId = info["bookId"] as? String,
                  let chapterIndex = info["chapterIndex"] as? Int else { return }
            let notes = info["notes"] as? String
            try? self.noteRepository.saveChapterNotes(bookId: bookId, chapterIndex: chapterIndex,
                                                       notes: notes)
        }

        NotificationCenter.default.addObserver(forName: .saveInlineNotes, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let info = notification.userInfo,
                  let bookId = info["bookId"] as? String,
                  let chapterIndex = info["chapterIndex"] as? Int,
                  let inlineNotes = info["inlineNotes"] as? [InlineNote] else { return }
            try? self.noteRepository.saveInlineNotes(bookId: bookId, chapterIndex: chapterIndex,
                                                      notes: inlineNotes)
        }
    }

    public func loadBooks() {
        do {
            let results: [(book: LibraryBook, authors: [Author])]
            if searchQuery.isEmpty {
                results = try bookRepository.fetchAll()
            } else {
                results = try bookRepository.search(query: searchQuery)
            }
            books = results.map { BookEntry(id: $0.book.id, book: $0.book, authors: $0.authors) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func importBooks(from urls: [URL]) {
        for url in urls {
            do {
                _ = try bookImporter.importBook(from: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        loadBooks()
    }

    public func deleteBook(_ entry: BookEntry) {
        do {
            try bookImporter.deleteBook(entry.book)
            loadBooks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateBook(_ entry: BookEntry) {
        do {
            try bookRepository.update(book: entry.book, authors: entry.authors)
            loadBooks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateCover(bookId: String, from imageURL: URL) {
        do {
            guard let entry = books.first(where: { $0.id == bookId }) else { return }
            let newPath = try bookImporter.updateCover(bookId: bookId, bookFilePath: entry.book.filePath, from: imageURL)
            if let index = books.firstIndex(where: { $0.id == bookId }) {
                books[index].book.coverPath = newPath
            }
            if let entry = books.first(where: { $0.id == bookId }) {
                try bookRepository.update(book: entry.book, authors: entry.authors)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveSettings() {
        do {
            try settingsRepository.saveSettings(settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func performSearch() {
        loadBooks()
    }

    public func exportLibrary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "athenaeumlib")!]
        panel.nameFieldStringValue = "Library.athenaeumlib"
        panel.title = NSLocalizedString("settings.data.export", bundle: .main, comment: "")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: tempDir) }

            let libraryURL = URL(fileURLWithPath: settings.libraryPath)
            let dbSource = libraryURL.appendingPathComponent("library.db")
            let booksSource = libraryURL.appendingPathComponent("books")
            let coversSource = libraryURL.appendingPathComponent("covers")

            try fm.copyItem(at: dbSource, to: tempDir.appendingPathComponent("library.db"))
            if fm.fileExists(atPath: booksSource.path) {
                try fm.copyItem(at: booksSource, to: tempDir.appendingPathComponent("books"))
            }
            if fm.fileExists(atPath: coversSource.path) {
                try fm.copyItem(at: coversSource, to: tempDir.appendingPathComponent("covers"))
            }

            try FileManager.default.zipItem(at: tempDir, to: url)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    public func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "athenaeumlib")!]
        panel.allowsMultipleSelection = false
        panel.title = NSLocalizedString("settings.data.import", bundle: .main, comment: "")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: tempDir) }

            try FileManager.default.unzipItem(at: url, to: tempDir)

            let extractedDir = tempDir

            let libraryURL = URL(fileURLWithPath: settings.libraryPath)

            // Replace database
            let dbDest = libraryURL.appendingPathComponent("library.db")
            let dbSource = extractedDir.appendingPathComponent("library.db")
            guard fm.fileExists(atPath: dbSource.path) else {
                errorMessage = "Import failed: no database found in archive."
                return
            }
            if fm.fileExists(atPath: dbDest.path) {
                try fm.removeItem(at: dbDest)
            }
            try fm.copyItem(at: dbSource, to: dbDest)

            // Replace books directory
            let booksDest = libraryURL.appendingPathComponent("books")
            let booksSource = extractedDir.appendingPathComponent("books")
            if fm.fileExists(atPath: booksSource.path) {
                if fm.fileExists(atPath: booksDest.path) {
                    try fm.removeItem(at: booksDest)
                }
                try fm.copyItem(at: booksSource, to: booksDest)
            }

            // Replace covers directory
            let coversDest = libraryURL.appendingPathComponent("covers")
            let coversSource = extractedDir.appendingPathComponent("covers")
            if fm.fileExists(atPath: coversSource.path) {
                if fm.fileExists(atPath: coversDest.path) {
                    try fm.removeItem(at: coversDest)
                }
                try fm.copyItem(at: coversSource, to: coversDest)
            }

            // Re-initialize database and reload
            let db = try LibraryDatabase(path: dbDest.path)
            let newBookRepo = BookRepository(database: db)
            let results = try newBookRepo.fetchAll()
            books = results.map { BookEntry(id: $0.book.id, book: $0.book, authors: $0.authors) }
            errorMessage = nil
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    public func importFromDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = NSLocalizedString("import.directory.title", bundle: .main, comment: "")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isImportingDirectory = true
        directoryImportProgress = nil

        let scanner = DirectoryScanner(bookImporter: bookImporter)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = scanner.scanAndImport(directory: url) { current, total in
                DispatchQueue.main.async {
                    self?.directoryImportProgress = (current: current, total: total)
                }
            }
            DispatchQueue.main.async {
                self?.isImportingDirectory = false
                self?.directoryImportProgress = nil
                self?.directoryImportResult = result
                self?.loadBooks()
            }
        }
    }

    private func migrateStorageIfNeeded() {
        let key = "storage_layout_version"
        let current = (try? settingsRepository.get(key)) ?? "0"
        guard current == "0" else { return }
        do {
            let allBooks = try bookRepository.fetchAll()
            bookImporter.migrateStorageLayout(books: allBooks)
            try settingsRepository.set(key, value: "1")
            loadBooks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func copyBookToClipboard(_ entry: BookEntry) {
        let url = URL(fileURLWithPath: entry.book.filePath)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
    }

    public func showInFinder(_ entry: BookEntry) {
        let url = URL(fileURLWithPath: entry.book.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func exportBookAsPDF(_ entry: BookEntry) {
        exportJobManager.startExport(entry: entry, fontFamily: settings.bodyFont)
    }

    public func reviewNotes(_ entry: BookEntry) {
        guard entry.book.format == .epub else { return }
        let url = URL(fileURLWithPath: entry.book.filePath)
        do {
            let parser = EPUBParser()
            let epubBook = try parser.parse(at: url)

            let chapters: [(index: Int, title: String)] = epubBook.spine.enumerated().map { (i, item) in
                let title = chapterTitle(for: i, spine: epubBook.spine, toc: epubBook.tableOfContents)
                return (index: i, title: title)
            }

            let chapterNotes = (try? noteRepository.loadAllChapterNotes(bookId: entry.book.id)) ?? [:]
            let inlineNotes = (try? noteRepository.loadAllInlineNotes(bookId: entry.book.id)) ?? [:]

            let storeEntry = NotesWindowStore.Entry(
                bookTitle: entry.book.title,
                chapters: chapters,
                chapterNotes: chapterNotes,
                inlineNotes: inlineNotes
            )
            NotesWindowStore.shared.store(bookId: entry.book.id, entry: storeEntry)
            NotificationCenter.default.post(name: .openNotesReview, object: nil,
                                            userInfo: ["bookId": entry.book.id])
            epubBook.cleanup()
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }
    }

    private func chapterTitle(for chapterIndex: Int, spine: [EPUBBook.SpineItem],
                              toc: [EPUBBook.TOCEntry]) -> String {
        guard chapterIndex >= 0, chapterIndex < spine.count else {
            return "Chapter \(chapterIndex + 1)"
        }
        let href = spine[chapterIndex].href
        if let entry = findTOCEntry(href: href, in: toc) {
            return entry.title
        }
        return "Chapter \(chapterIndex + 1)"
    }

    private func findTOCEntry(href: String, in entries: [EPUBBook.TOCEntry]) -> EPUBBook.TOCEntry? {
        for entry in entries {
            let cleanEntryHref = entry.href.components(separatedBy: "#").first ?? entry.href
            if cleanEntryHref == href { return entry }
            if let found = findTOCEntry(href: href, in: entry.children) { return found }
        }
        return nil
    }

    public func openBook(_ entry: BookEntry) {
        guard entry.book.format == .epub else {
            errorMessage = "Only EPUB reading is supported currently."
            return
        }
        let url = URL(fileURLWithPath: entry.book.filePath)
        do {
            let parser = EPUBParser()
            let epubBook = try parser.parse(at: url)
            var userInfo: [String: Any] = [
                "book": epubBook,
                "libraryBookId": entry.book.id,
                "fontFamily": settings.defaultFont,
                "themeMode": settings.themeMode,
                "lightThemeId": settings.lightThemeId,
                "darkThemeId": settings.darkThemeId
            ]
            if let pairingId = settings.fontPairingId {
                userInfo["fontPairingId"] = pairingId
            }
            if let highlights = try? highlightRepository.loadAllHighlights(bookId: entry.book.id), !highlights.isEmpty {
                userInfo["highlights"] = highlights
            }
            if let bookmarks = try? bookmarkRepository.loadAllBookmarks(bookId: entry.book.id), !bookmarks.isEmpty {
                userInfo["bookmarks"] = bookmarks
            }
            if let chapterNotes = try? noteRepository.loadAllChapterNotes(bookId: entry.book.id), !chapterNotes.isEmpty {
                userInfo["chapterNotes"] = chapterNotes
            }
            if let inlineNotes = try? noteRepository.loadAllInlineNotes(bookId: entry.book.id), !inlineNotes.isEmpty {
                userInfo["inlineNotes"] = inlineNotes
            }
            if let position = entry.book.readingPosition {
                userInfo["lastChapterIndex"] = position.chapter
                userInfo["lastScrollPosition"] = position.scroll
            }
            NotificationCenter.default.post(
                name: .openBook,
                object: nil,
                userInfo: userInfo
            )
        } catch {
            errorMessage = "Failed to open: \(error.localizedDescription)"
        }
    }
}
