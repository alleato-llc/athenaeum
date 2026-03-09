import SwiftUI
import AppKit
import Forma

@main
struct AthenaeumApp: App {
    @Environment(\.openWindow) private var openWindow

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .onReceive(NotificationCenter.default.publisher(for: .openBook)) { notification in
                    guard let info = notification.userInfo,
                          let book = info["book"] as? EPUBBook else { return }
                    let libraryBookId = info["libraryBookId"] as? String
                    let lastChapterIndex = info["lastChapterIndex"] as? Int
                    let lastScrollPosition = info["lastScrollPosition"] as? Double
                    let fontFamily = info["fontFamily"] as? String ?? "Georgia"
                    let fontPairingId = info["fontPairingId"] as? String
                    let themeMode = info["themeMode"] as? ThemeMode ?? .system
                    let lightThemeId = info["lightThemeId"] as? String ?? "classic"
                    let darkThemeId = info["darkThemeId"] as? String ?? "charcoal"
                    let highlights = info["highlights"] as? [Int: [Highlight]] ?? [:]
                    let bookmarks = info["bookmarks"] as? [Bookmark] ?? []
                    let chapterNotes = info["chapterNotes"] as? [Int: String] ?? [:]
                    let inlineNotes = info["inlineNotes"] as? [Int: [InlineNote]] ?? [:]
                    BookWindowStore.shared.store(book, libraryBookId: libraryBookId,
                                                 lastChapterIndex: lastChapterIndex,
                                                 lastScrollPosition: lastScrollPosition,
                                                 fontFamily: fontFamily,
                                                 fontPairingId: fontPairingId,
                                                 themeMode: themeMode,
                                                 lightThemeId: lightThemeId,
                                                 darkThemeId: darkThemeId,
                                                 highlights: highlights,
                                                 bookmarks: bookmarks,
                                                 chapterNotes: chapterNotes,
                                                 inlineNotes: inlineNotes)
                    openWindow(id: "reader", value: book.id)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openNotesReview)) { notification in
                    guard let info = notification.userInfo,
                          let bookId = info["bookId"] as? String else { return }
                    openWindow(id: "notes", value: bookId)
                }
        }

        .commands {
            CommandGroup(after: .newItem) {
                Button(NSLocalizedString("library.add", bundle: .main, comment: "")) {
                    NotificationCenter.default.post(name: .addBooks, object: nil)
                }
                .keyboardShortcut("o")
            }
        }

        WindowGroup("Reader", id: "reader", for: String.self) { $bookId in
            if let bookId, let entry = BookWindowStore.shared.retrieve(bookId) {
                ReaderView(book: entry.book, libraryBookId: entry.libraryBookId,
                           lastChapterIndex: entry.lastChapterIndex,
                           lastScrollPosition: entry.lastScrollPosition,
                           fontFamily: entry.fontFamily,
                           fontPairingId: entry.fontPairingId,
                           themeMode: entry.themeMode,
                           lightThemeId: entry.lightThemeId,
                           darkThemeId: entry.darkThemeId,
                           highlights: entry.highlights,
                           bookmarks: entry.bookmarks,
                           chapterNotes: entry.chapterNotes,
                           inlineNotes: entry.inlineNotes)
                    .frame(minWidth: 800, minHeight: 600)
            } else {
                WindowCloseView()
            }
        }
        .defaultSize(width: 900, height: 700)

        WindowGroup("Notes", id: "notes", for: String.self) { $bookId in
            if let bookId, let entry = NotesWindowStore.shared.retrieve(bookId) {
                ChapterNotesReviewView(entry: entry)
                    .frame(minWidth: 600, minHeight: 400)
            } else {
                WindowCloseView()
            }
        }
        .defaultSize(width: 700, height: 500)
    }
}

/// Auto-closes windows restored by macOS state restoration when no data is available.
private struct WindowCloseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { dismiss() }
    }
}

extension EPUBBook: @retroactive Identifiable {
    public var id: String { title + author }
}

/// Temporary store to pass EPUBBook values between scenes since EPUBBook isn't Codable.
class BookWindowStore {
    static let shared = BookWindowStore()

    struct Entry {
        let book: EPUBBook
        let libraryBookId: String?
        let lastChapterIndex: Int?
        let lastScrollPosition: Double?
        let fontFamily: String
        let fontPairingId: String?
        let themeMode: ThemeMode
        let lightThemeId: String
        let darkThemeId: String
        let highlights: [Int: [Highlight]]
        let bookmarks: [Bookmark]
        let chapterNotes: [Int: String]
        let inlineNotes: [Int: [InlineNote]]
    }

    private var entries: [String: Entry] = [:]

    func store(_ book: EPUBBook, libraryBookId: String? = nil,
               lastChapterIndex: Int? = nil, lastScrollPosition: Double? = nil,
               fontFamily: String = "Georgia", fontPairingId: String? = nil,
               themeMode: ThemeMode = .system, lightThemeId: String = "classic",
               darkThemeId: String = "charcoal",
               highlights: [Int: [Highlight]] = [:],
               bookmarks: [Bookmark] = [],
               chapterNotes: [Int: String] = [:],
               inlineNotes: [Int: [InlineNote]] = [:]) {
        entries[book.id] = Entry(book: book, libraryBookId: libraryBookId,
                                  lastChapterIndex: lastChapterIndex,
                                  lastScrollPosition: lastScrollPosition,
                                  fontFamily: fontFamily,
                                  fontPairingId: fontPairingId,
                                  themeMode: themeMode,
                                  lightThemeId: lightThemeId,
                                  darkThemeId: darkThemeId,
                                  highlights: highlights,
                                  bookmarks: bookmarks,
                                  chapterNotes: chapterNotes,
                                  inlineNotes: inlineNotes)
    }

    func retrieve(_ id: String) -> Entry? {
        entries[id]
    }
}

class NotesWindowStore {
    static let shared = NotesWindowStore()

    struct Entry {
        let bookTitle: String
        let chapters: [(index: Int, title: String)]
        let chapterNotes: [Int: String]
        let inlineNotes: [Int: [InlineNote]]
    }

    private var entries: [String: Entry] = [:]

    func store(bookId: String, entry: Entry) {
        entries[bookId] = entry
    }

    func retrieve(_ id: String) -> Entry? {
        entries[id]
    }
}
