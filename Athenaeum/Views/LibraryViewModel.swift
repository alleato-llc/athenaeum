import Foundation
import AppKit
import SwiftUI
import Forma

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
    public weak var window: NSWindow?

    private let bookRepository: BookRepository
    private let settingsRepository: SettingsRepository
    private let bookImporter: BookImporter
    private let database: LibraryDatabase

    public init() {
        let libraryPath = UserSettings.defaultLibraryPath
        let dbPath = (libraryPath as NSString).appendingPathComponent("library.db")

        do {
            let db = try LibraryDatabase(path: dbPath)
            self.database = db
            self.bookRepository = BookRepository(database: db)
            self.settingsRepository = SettingsRepository(database: db)
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
                "themeMode": settings.themeMode,
                "lightThemeId": settings.lightThemeId,
                "darkThemeId": settings.darkThemeId
            ]
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
