import SwiftUI
import AppKit
import Ligature

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
                    let themeMode = info["themeMode"] as? ThemeMode ?? .system
                    let lightThemeId = info["lightThemeId"] as? String ?? "classic"
                    let darkThemeId = info["darkThemeId"] as? String ?? "charcoal"
                    BookWindowStore.shared.store(book, libraryBookId: libraryBookId,
                                                 lastChapterIndex: lastChapterIndex,
                                                 lastScrollPosition: lastScrollPosition,
                                                 themeMode: themeMode,
                                                 lightThemeId: lightThemeId,
                                                 darkThemeId: darkThemeId)
                    openWindow(id: "reader", value: book.id)
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
                           themeMode: entry.themeMode,
                           lightThemeId: entry.lightThemeId,
                           darkThemeId: entry.darkThemeId)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .defaultSize(width: 900, height: 700)
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
        let themeMode: ThemeMode
        let lightThemeId: String
        let darkThemeId: String
    }

    private var entries: [String: Entry] = [:]

    func store(_ book: EPUBBook, libraryBookId: String? = nil,
               lastChapterIndex: Int? = nil, lastScrollPosition: Double? = nil,
               themeMode: ThemeMode = .system, lightThemeId: String = "classic",
               darkThemeId: String = "charcoal") {
        entries[book.id] = Entry(book: book, libraryBookId: libraryBookId,
                                  lastChapterIndex: lastChapterIndex,
                                  lastScrollPosition: lastScrollPosition,
                                  themeMode: themeMode,
                                  lightThemeId: lightThemeId,
                                  darkThemeId: darkThemeId)
    }

    func retrieve(_ id: String) -> Entry? {
        entries[id]
    }
}
