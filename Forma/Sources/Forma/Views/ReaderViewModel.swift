import Foundation
import Combine
import WebKit
import Ligature

public enum NavigationMode {
    case page
    case chapter
}

public class ReaderViewModel: ObservableObject {
    public let book: EPUBBook
    public let themeManager: ThemeManager

    @Published public var currentChapterIndex: Int = 0
    @Published public var fontFamily: String = "Georgia"
    @Published public var fontPairingId: String?
    @Published public var zoom: Double = 1.0
    @Published public var goToChapter: Int = 1
    @Published public var readingProgress: Double = 0
    @Published public var isLoading: Bool = false
    @Published public var navigationMode: NavigationMode = .page
    @Published public var currentPage: Int = 1
    @Published public var totalPages: Int = 1
    @Published public var isHighlightModeActive: Bool = false
    @Published public var isEraserModeActive: Bool = false
    @Published public var highlightColor: HighlightColor = HighlightColor.palette[0]
    @Published public var bookmarks: [Bookmark] = []
    @Published public var isNoteModeActive: Bool = false
    @Published public var chapterNotes: String = ""
    @Published public var showingNoteEditor: Bool = false
    @Published public var pendingNoteId: String?
    @Published public var pendingNoteText: String = ""
    @Published public var editingInlineNote: InlineNote?

    public let undoManager = UndoManager()
    public weak var webView: WKWebView?

    private var scrollPositions: [Int: Double] = [:]
    private var scrollToBottomOnLoad: Bool = false
    private var chapterPageCounts: [Int: Int] = [:]
    private var measuringWebView: WKWebView?
    private var measureQueue: [Int] = []
    private var isMeasuring: Bool = false
    private let measureBatchSize = 5
    private let measureDelay: TimeInterval = 0.1

    private let minZoom: Double = 0.5
    private let maxZoom: Double = 3.0
    private let zoomStep: Double = 0.1

    private var measureCount = 0
    private var themeCancellable: AnyCancellable?
    private var chapterHighlightsCache: [Int: [Highlight]] = [:]
    private var chapterNotesCache: [Int: String] = [:]
    private var inlineNotesCache: [Int: [InlineNote]] = [:]

    public var libraryBookId: String?
    private var initialChapterIndex: Int?
    private var initialScrollPosition: Double?

    public var activePairing: FontPairing? {
        guard let id = fontPairingId else { return nil }
        return FontPairing.pairing(byId: id)
    }

    public var headerFont: String {
        activePairing?.headerFont ?? fontFamily
    }

    public var bodyFontResolved: String {
        activePairing?.bodyFont ?? fontFamily
    }

    public init(book: EPUBBook, libraryBookId: String? = nil,
                lastChapterIndex: Int? = nil, lastScrollPosition: Double? = nil,
                fontFamily: String = "Georgia", fontPairingId: String? = nil,
                themeMode: ThemeMode = .system, lightThemeId: String = "classic",
                darkThemeId: String = "charcoal",
                highlights: [Int: [Highlight]] = [:],
                bookmarks: [Bookmark] = [],
                chapterNotes: [Int: String] = [:],
                inlineNotes: [Int: [InlineNote]] = [:]) {
        self.book = book
        self.libraryBookId = libraryBookId
        self.initialChapterIndex = lastChapterIndex
        self.initialScrollPosition = lastScrollPosition
        self.chapterHighlightsCache = highlights
        self.bookmarks = bookmarks
        self.chapterNotesCache = chapterNotes
        self.inlineNotesCache = inlineNotes
        self.fontFamily = fontFamily
        self.fontPairingId = fontPairingId
        self.themeManager = ThemeManager(themeMode: themeMode, lightThemeId: lightThemeId,
                                         darkThemeId: darkThemeId)

        if let chapter = lastChapterIndex, chapter < book.spine.count {
            self.currentChapterIndex = chapter
            self.goToChapter = chapter + 1
            self.chapterNotes = chapterNotes[chapter] ?? ""
        }

        themeCancellable = themeManager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.applyThemeStyles()
            }
        }
    }

    deinit {
        saveProgressToLibrary()
        cancelMeasurement()
        book.cleanup()
    }

    public func saveProgressToLibrary() {
        guard let bookId = libraryBookId else { return }
        NotificationCenter.default.post(
            name: .saveReadingProgress,
            object: nil,
            userInfo: [
                "bookId": bookId,
                "chapterIndex": currentChapterIndex,
                "scrollPosition": scrollPositions[currentChapterIndex] ?? 0.0
            ]
        )
        saveHighlightsToLibrary()
        saveChapterNotesToLibrary()
        saveInlineNotesToLibrary()
    }

    public func saveHighlightsToLibrary() {
        guard let bookId = libraryBookId else { return }
        collectHighlightsFromJS { [weak self] highlights in
            guard let self = self else { return }
            let chapter = self.currentChapterIndex
            self.chapterHighlightsCache[chapter] = highlights
            NotificationCenter.default.post(
                name: .saveHighlights,
                object: nil,
                userInfo: [
                    "bookId": bookId,
                    "chapterIndex": chapter,
                    "highlights": highlights
                ]
            )
        }
    }

    public func saveChapterNotesToLibrary() {
        guard let bookId = libraryBookId else { return }
        let chapter = currentChapterIndex
        let notes = chapterNotes.isEmpty ? nil : chapterNotes
        chapterNotesCache[chapter] = notes
        NotificationCenter.default.post(
            name: .saveChapterNotes,
            object: nil,
            userInfo: [
                "bookId": bookId,
                "chapterIndex": chapter,
                "notes": notes as Any
            ]
        )
    }

    public func saveInlineNotesToLibrary() {
        guard let bookId = libraryBookId else { return }
        collectInlineNotesFromJS { [weak self] notes in
            guard let self = self else { return }
            let chapter = self.currentChapterIndex
            self.inlineNotesCache[chapter] = notes
            NotificationCenter.default.post(
                name: .saveInlineNotes,
                object: nil,
                userInfo: [
                    "bookId": bookId,
                    "chapterIndex": chapter,
                    "inlineNotes": notes
                ]
            )
        }
    }

    public func toggleHighlightMode() {
        if isHighlightModeActive {
            isHighlightModeActive = false
            webView?.evaluateJavaScript("athSetHighlightMode('off');")
            saveHighlightsToLibrary()
        } else {
            isEraserModeActive = false
            isNoteModeActive = false
            isHighlightModeActive = true
            webView?.evaluateJavaScript("athSetNoteMode('off');")
            webView?.evaluateJavaScript("athSetHighlightMode('highlight');")
            webView?.evaluateJavaScript("athSetHighlightColor('\(highlightColor.cssColor)');")
        }
    }

    public func toggleEraserMode() {
        if isEraserModeActive {
            isEraserModeActive = false
            webView?.evaluateJavaScript("athSetHighlightMode('off');")
        } else {
            isHighlightModeActive = false
            isNoteModeActive = false
            isEraserModeActive = true
            webView?.evaluateJavaScript("athSetNoteMode('off');")
            webView?.evaluateJavaScript("athSetHighlightMode('eraser');")
        }
    }

    public func setHighlightColor(_ color: HighlightColor) {
        highlightColor = color
        webView?.evaluateJavaScript("athSetHighlightColor('\(color.cssColor)');")
    }

    public func eraseAllHighlightsOnPage() {
        guard let bookId = libraryBookId else { return }
        let chapter = currentChapterIndex
        let old = chapterHighlightsCache[chapter] ?? []
        webView?.evaluateJavaScript("athEraseAllHighlights();")
        chapterHighlightsCache[chapter] = []
        NotificationCenter.default.post(
            name: .saveHighlights, object: nil,
            userInfo: ["bookId": bookId, "chapterIndex": chapter, "highlights": [] as [Highlight]]
        )
        if !old.isEmpty {
            undoManager.registerUndo(withTarget: self) { vm in
                vm.restoreHighlights(chapter: chapter, highlights: old, bookId: bookId)
            }
        }
    }

    public func toggleNoteMode() {
        if isNoteModeActive {
            isNoteModeActive = false
            webView?.evaluateJavaScript("athSetNoteMode('off');")
            saveInlineNotesToLibrary()
        } else {
            isHighlightModeActive = false
            isEraserModeActive = false
            isNoteModeActive = true
            webView?.evaluateJavaScript("athSetHighlightMode('off');")
            webView?.evaluateJavaScript("athSetNoteMode('on');")
        }
    }

    public func confirmPendingNote() {
        guard let noteId = pendingNoteId, !pendingNoteText.isEmpty else {
            cancelPendingNote()
            return
        }
        let js = "athConfirmNote('\(noteId)', \(jsEscape(pendingNoteText)));"
        webView?.evaluateJavaScript(js)
        pendingNoteId = nil
        pendingNoteText = ""
        showingNoteEditor = false
        saveInlineNotesWithUndo()
    }

    public func cancelPendingNote() {
        if let noteId = pendingNoteId {
            webView?.evaluateJavaScript("athCancelNote('\(noteId)');")
        }
        pendingNoteId = nil
        pendingNoteText = ""
        showingNoteEditor = false
    }

    public func deleteInlineNote(_ note: InlineNote) {
        webView?.evaluateJavaScript("athDeleteNote('\(note.id)');")
        editingInlineNote = nil
        saveInlineNotesWithUndo()
    }

    public func updateInlineNote(_ note: InlineNote, newText: String) {
        let js = "athUpdateNoteText('\(note.id)', \(jsEscape(newText)));"
        webView?.evaluateJavaScript(js)
        editingInlineNote = nil
        saveInlineNotesWithUndo()
    }

    public func handleNoteMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let action = dict["action"] as? String else { return }
        switch action {
        case "requestNote":
            if let noteId = dict["noteId"] as? String {
                pendingNoteId = noteId
                pendingNoteText = ""
                showingNoteEditor = true
            }
        case "showNote":
            if let noteId = dict["noteId"] as? String,
               let noteText = dict["noteText"] as? String,
               let selectedText = dict["selectedText"] as? String {
                let note = InlineNote(id: noteId, text: selectedText, note: noteText,
                                      startPath: "", startOffset: 0,
                                      endPath: "", endOffset: 0, createdAt: Date())
                editingInlineNote = note
            }
        default:
            break
        }
    }

    private func jsEscape(_ str: String) -> String {
        let escaped = str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "'\(escaped)'"
    }

    // MARK: - Undo/Redo

    public func handleHighlightMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let action = dict["action"] as? String,
              action == "changed" else { return }
        saveHighlightsWithUndo()
    }

    private func saveHighlightsWithUndo() {
        guard let bookId = libraryBookId else { return }
        let chapter = currentChapterIndex
        collectHighlightsFromJS { [weak self] highlights in
            guard let self = self else { return }
            let old = self.chapterHighlightsCache[chapter] ?? []
            guard highlights != old else { return }
            self.chapterHighlightsCache[chapter] = highlights
            NotificationCenter.default.post(
                name: .saveHighlights, object: nil,
                userInfo: ["bookId": bookId, "chapterIndex": chapter, "highlights": highlights]
            )
            self.undoManager.registerUndo(withTarget: self) { vm in
                vm.restoreHighlights(chapter: chapter, highlights: old, bookId: bookId)
            }
        }
    }

    private func saveInlineNotesWithUndo() {
        guard let bookId = libraryBookId else { return }
        let chapter = currentChapterIndex
        collectInlineNotesFromJS { [weak self] notes in
            guard let self = self else { return }
            let old = self.inlineNotesCache[chapter] ?? []
            guard notes != old else { return }
            self.inlineNotesCache[chapter] = notes
            NotificationCenter.default.post(
                name: .saveInlineNotes, object: nil,
                userInfo: ["bookId": bookId, "chapterIndex": chapter, "inlineNotes": notes]
            )
            self.undoManager.registerUndo(withTarget: self) { vm in
                vm.restoreInlineNotes(chapter: chapter, notes: old, bookId: bookId)
            }
        }
    }

    private func restoreHighlights(chapter: Int, highlights: [Highlight], bookId: String) {
        let current = chapterHighlightsCache[chapter] ?? []
        chapterHighlightsCache[chapter] = highlights
        if chapter == currentChapterIndex {
            let json = encodeHighlightsJSON(highlights)
            let mode = isHighlightModeActive ? "highlight" : (isEraserModeActive ? "eraser" : "off")
            webView?.evaluateJavaScript(
                "athEraseAllHighlights(); athHighlightInit(\(json), '\(mode)', '\(highlightColor.cssColor)');"
            )
        }
        NotificationCenter.default.post(
            name: .saveHighlights, object: nil,
            userInfo: ["bookId": bookId, "chapterIndex": chapter, "highlights": highlights]
        )
        undoManager.registerUndo(withTarget: self) { vm in
            vm.restoreHighlights(chapter: chapter, highlights: current, bookId: bookId)
        }
    }

    private func restoreInlineNotes(chapter: Int, notes: [InlineNote], bookId: String) {
        let current = inlineNotesCache[chapter] ?? []
        inlineNotesCache[chapter] = notes
        if chapter == currentChapterIndex {
            let json = encodeInlineNotesJSON(notes)
            let mode = isNoteModeActive ? "on" : "off"
            webView?.evaluateJavaScript("athEraseAllNotes(); athNoteInit(\(json), '\(mode)');")
        }
        NotificationCenter.default.post(
            name: .saveInlineNotes, object: nil,
            userInfo: ["bookId": bookId, "chapterIndex": chapter, "inlineNotes": notes]
        )
        undoManager.registerUndo(withTarget: self) { vm in
            vm.restoreInlineNotes(chapter: chapter, notes: current, bookId: bookId)
        }
    }

    private func undoAddBookmark(_ bookmark: Bookmark, bookId: String) {
        bookmarks.removeAll { $0.id == bookmark.id }
        NotificationCenter.default.post(
            name: .deleteBookmark, object: nil,
            userInfo: ["bookmarkId": bookmark.id]
        )
        undoManager.registerUndo(withTarget: self) { vm in
            vm.redoAddBookmark(bookmark, bookId: bookId)
        }
    }

    private func redoAddBookmark(_ bookmark: Bookmark, bookId: String) {
        NotificationCenter.default.post(
            name: .addBookmark, object: nil,
            userInfo: [
                "bookId": bookId,
                "chapterIndex": bookmark.chapterIndex,
                "scrollPosition": bookmark.scrollPosition,
                "label": bookmark.label,
                "callback": { [weak self] (newBookmark: Bookmark) in
                    DispatchQueue.main.async {
                        self?.bookmarks.append(newBookmark)
                        self?.undoManager.registerUndo(withTarget: self!) { vm in
                            vm.undoAddBookmark(newBookmark, bookId: bookId)
                        }
                    }
                } as (Bookmark) -> Void
            ]
        )
    }

    private func undoDeleteBookmark(_ bookmark: Bookmark, bookId: String) {
        NotificationCenter.default.post(
            name: .addBookmark, object: nil,
            userInfo: [
                "bookId": bookId,
                "chapterIndex": bookmark.chapterIndex,
                "scrollPosition": bookmark.scrollPosition,
                "label": bookmark.label,
                "callback": { [weak self] (newBookmark: Bookmark) in
                    DispatchQueue.main.async {
                        self?.bookmarks.append(newBookmark)
                        self?.undoManager.registerUndo(withTarget: self!) { vm in
                            vm.bookmarks.removeAll { $0.id == newBookmark.id }
                            NotificationCenter.default.post(
                                name: .deleteBookmark, object: nil,
                                userInfo: ["bookmarkId": newBookmark.id]
                            )
                            vm.undoDeleteBookmark(newBookmark, bookId: bookId)
                        }
                    }
                } as (Bookmark) -> Void
            ]
        )
    }

    private func encodeHighlightsJSON(_ highlights: [Highlight]) -> String {
        guard !highlights.isEmpty,
              let data = try? JSONEncoder().encode(highlights),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private func encodeInlineNotesJSON(_ notes: [InlineNote]) -> String {
        guard !notes.isEmpty else { return "[]" }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(notes),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    public func addBookmark() {
        guard let bookId = libraryBookId else { return }
        let chapterIndex = currentChapterIndex
        let scrollPosition = scrollPositions[chapterIndex] ?? 0.0
        let label = chapterTitle(for: chapterIndex)

        NotificationCenter.default.post(
            name: .addBookmark,
            object: nil,
            userInfo: [
                "bookId": bookId,
                "chapterIndex": chapterIndex,
                "scrollPosition": scrollPosition,
                "label": label,
                "callback": { [weak self] (bookmark: Bookmark) in
                    DispatchQueue.main.async {
                        self?.bookmarks.append(bookmark)
                        self?.undoManager.registerUndo(withTarget: self!) { vm in
                            vm.undoAddBookmark(bookmark, bookId: bookId)
                        }
                    }
                } as (Bookmark) -> Void
            ]
        )
    }

    public func deleteBookmark(_ bookmark: Bookmark) {
        guard let bookId = libraryBookId else { return }
        bookmarks.removeAll { $0.id == bookmark.id }
        NotificationCenter.default.post(
            name: .deleteBookmark,
            object: nil,
            userInfo: ["bookmarkId": bookmark.id]
        )
        undoManager.registerUndo(withTarget: self) { vm in
            vm.undoDeleteBookmark(bookmark, bookId: bookId)
        }
    }

    public func navigateToBookmark(_ bookmark: Bookmark) {
        saveScrollPosition()
        collectAndCacheHighlights()
        currentChapterIndex = bookmark.chapterIndex
        goToChapter = bookmark.chapterIndex + 1
        scrollPositions[bookmark.chapterIndex] = bookmark.scrollPosition
        loadCurrentChapter()
    }

    public func chapterTitle(for chapterIndex: Int) -> String {
        guard chapterIndex >= 0, chapterIndex < book.spine.count else {
            return "Chapter \(chapterIndex + 1)"
        }
        let href = book.spine[chapterIndex].href
        if let entry = findTOCEntry(href: href, in: book.tableOfContents) {
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

    private func collectHighlightsFromJS(completion: @escaping ([Highlight]) -> Void) {
        guard let webView = webView else {
            completion([])
            return
        }
        webView.evaluateJavaScript("athCollectHighlights();") { result, _ in
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let highlights = try? JSONDecoder().decode([Highlight].self, from: data) else {
                completion([])
                return
            }
            completion(highlights)
        }
    }

    private func collectInlineNotesFromJS(completion: @escaping ([InlineNote]) -> Void) {
        guard let webView = webView else {
            completion([])
            return
        }
        webView.evaluateJavaScript("athCollectNotes();") { result, _ in
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8) else {
                completion([])
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let notes = try? decoder.decode([InlineNote].self, from: data) else {
                completion([])
                return
            }
            completion(notes)
        }
    }

    private func injectHighlightEngine() {
        guard let webView = webView else { return }
        let highlightsJSON: String
        if let cached = chapterHighlightsCache[currentChapterIndex],
           !cached.isEmpty,
           let data = try? JSONEncoder().encode(cached),
           let str = String(data: data, encoding: .utf8) {
            highlightsJSON = str
        } else {
            highlightsJSON = "[]"
        }

        let inlineNotesJSON: String
        if let cached = inlineNotesCache[currentChapterIndex],
           !cached.isEmpty {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(cached),
               let str = String(data: data, encoding: .utf8) {
                inlineNotesJSON = str
            } else {
                inlineNotesJSON = "[]"
            }
        } else {
            inlineNotesJSON = "[]"
        }

        let mode: String
        if isHighlightModeActive { mode = "highlight" }
        else if isEraserModeActive { mode = "eraser" }
        else { mode = "off" }

        let noteMode = isNoteModeActive ? "on" : "off"

        let js = Self.highlightEngineJS + Self.noteEngineJS + """
        athHighlightInit(\(highlightsJSON), '\(mode)', '\(highlightColor.cssColor)');
        athNoteInit(\(inlineNotesJSON), '\(noteMode)');
        """
        webView.evaluateJavaScript(js)

        // Load current chapter notes
        chapterNotes = chapterNotesCache[currentChapterIndex] ?? ""
    }

    public var currentChapterURL: URL? {
        guard currentChapterIndex >= 0, currentChapterIndex < book.spine.count else { return nil }
        let href = book.spine[currentChapterIndex].href
        return book.baseURL.appendingPathComponent(href)
    }

    public func loadCurrentChapter() {
        guard let url = currentChapterURL else { return }
        isLoading = true
        webView?.loadFileURL(url, allowingReadAccessTo: book.extractedURL)
    }

    public func nextChapter() {
        guard currentChapterIndex < book.spine.count - 1 else { return }
        saveScrollPosition()
        collectAndCacheHighlights()
        currentChapterIndex += 1
        goToChapter = currentChapterIndex + 1
        loadCurrentChapter()
    }

    public func previousChapter() {
        guard currentChapterIndex > 0 else { return }
        saveScrollPosition()
        collectAndCacheHighlights()
        currentChapterIndex -= 1
        goToChapter = currentChapterIndex + 1
        loadCurrentChapter()
    }

    public func navigateToChapter() {
        let index = goToChapter - 1
        guard index >= 0, index < book.spine.count else {
            goToChapter = currentChapterIndex + 1
            return
        }
        saveScrollPosition()
        collectAndCacheHighlights()
        currentChapterIndex = index
        loadCurrentChapter()
    }

    private func collectAndCacheHighlights() {
        guard libraryBookId != nil else { return }
        let chapter = currentChapterIndex
        collectHighlightsFromJS { [weak self] highlights in
            self?.chapterHighlightsCache[chapter] = highlights
            if let bookId = self?.libraryBookId {
                NotificationCenter.default.post(
                    name: .saveHighlights,
                    object: nil,
                    userInfo: [
                        "bookId": bookId,
                        "chapterIndex": chapter,
                        "highlights": highlights
                    ]
                )
            }
        }
        collectInlineNotesFromJS { [weak self] notes in
            self?.inlineNotesCache[chapter] = notes
            if let bookId = self?.libraryBookId {
                NotificationCenter.default.post(
                    name: .saveInlineNotes,
                    object: nil,
                    userInfo: [
                        "bookId": bookId,
                        "chapterIndex": chapter,
                        "inlineNotes": notes
                    ]
                )
            }
        }
        // Cache chapter notes
        chapterNotesCache[chapter] = chapterNotes.isEmpty ? nil : chapterNotes
        if let bookId = libraryBookId {
            NotificationCenter.default.post(
                name: .saveChapterNotes,
                object: nil,
                userInfo: [
                    "bookId": bookId,
                    "chapterIndex": chapter,
                    "notes": chapterNotes.isEmpty ? nil as String? as Any : chapterNotes as Any
                ]
            )
        }
    }

    public func navigateTo(href: String) {
        let cleanHref = href.components(separatedBy: "#").first ?? href

        if let index = book.spine.firstIndex(where: { $0.href == cleanHref }) {
            saveScrollPosition()
            currentChapterIndex = index
            goToChapter = index + 1

            if href.contains("#") {
                loadCurrentChapter()
                let fragment = href.components(separatedBy: "#").last ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.webView?.evaluateJavaScript(
                        "document.getElementById('\(fragment)')?.scrollIntoView(true);"
                    )
                }
            } else {
                loadCurrentChapter()
            }
        }
    }

    public func navigateForward() {
        if navigationMode == .chapter {
            nextChapter()
        } else {
            nextPage()
        }
    }

    public func navigateBackward() {
        if navigationMode == .chapter {
            previousChapter()
        } else {
            previousPage()
        }
    }

    public func nextPage() {
        let js = """
        (function() {
            var viewportHeight = window.innerHeight;
            var maxScroll = document.documentElement.scrollHeight - viewportHeight;
            var atBottom = (window.scrollY >= maxScroll - 2);
            return JSON.stringify({ atBottom: atBottom });
        })();
        """
        webView?.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self, let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let atBottom = info["atBottom"] as? Bool else { return }

            if atBottom {
                self.nextChapter()
            } else {
                self.webView?.evaluateJavaScript("window.scrollBy(0, window.innerHeight - 40);")
                self.updatePageInfo()
            }
        }
    }

    public func previousPage() {
        let js = """
        (function() {
            var atTop = (window.scrollY <= 2);
            return JSON.stringify({ atTop: atTop });
        })();
        """
        webView?.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self, let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let atTop = info["atTop"] as? Bool else { return }

            if atTop {
                if self.currentChapterIndex > 0 {
                    self.saveScrollPosition()
                    self.currentChapterIndex -= 1
                    self.goToChapter = self.currentChapterIndex + 1
                    self.loadCurrentChapter()
                    self.scrollToBottomOnLoad = true
                }
            } else {
                self.webView?.evaluateJavaScript("window.scrollBy(0, -(window.innerHeight - 40));")
                self.updatePageInfo()
            }
        }
    }

    public func updatePageInfo() {
        let js = """
        (function() {
            var viewportHeight = window.innerHeight;
            var docHeight = document.documentElement.scrollHeight;
            var chapterPages = Math.max(1, Math.ceil(docHeight / viewportHeight));
            var pageInChapter = Math.min(chapterPages, Math.floor(window.scrollY / viewportHeight) + 1);
            return JSON.stringify({ pageInChapter: pageInChapter, chapterPages: chapterPages, scrollY: window.scrollY });
        })();
        """
        webView?.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self, let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pageInChapter = info["pageInChapter"] as? Int,
                  let chapterPages = info["chapterPages"] as? Int else { return }
            DispatchQueue.main.async {
                if let scrollY = info["scrollY"] as? Double {
                    self.scrollPositions[self.currentChapterIndex] = scrollY
                }

                self.chapterPageCounts[self.currentChapterIndex] = chapterPages

                var pagesBeforeCurrent = 0
                for i in 0..<self.currentChapterIndex {
                    pagesBeforeCurrent += self.chapterPageCounts[i] ?? 1
                }

                self.currentPage = pagesBeforeCurrent + pageInChapter

                var total = 0
                for i in 0..<self.book.spine.count {
                    total += self.chapterPageCounts[i] ?? 1
                }
                self.totalPages = total
                self.updateProgress()
            }
        }
    }

    public func toggleNavigationMode() {
        navigationMode = navigationMode == .page ? .chapter : .page
    }

    public func startMeasuringAllChapters() {
        guard !isMeasuring, let mainWebView = webView else { return }

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let hidden = WKWebView(frame: mainWebView.bounds, configuration: config)
        hidden.isHidden = true
        mainWebView.superview?.addSubview(hidden)
        measuringWebView = hidden

        measureQueue = Array(0..<book.spine.count)
        measureCount = 0
        isMeasuring = true
        measureNextChapter()
    }

    private func cancelMeasurement() {
        measureQueue.removeAll()
        measuringWebView?.stopLoading()
        measuringWebView?.removeFromSuperview()
        measuringWebView = nil
        isMeasuring = false
    }

    private func measureNextChapter() {
        guard let hidden = measuringWebView, !measureQueue.isEmpty else {
            measuringWebView?.removeFromSuperview()
            measuringWebView = nil
            isMeasuring = false
            updatePageInfo()
            return
        }

        let index = measureQueue.removeFirst()
        let href = book.spine[index].href
        let url = book.baseURL.appendingPathComponent(href)

        let delegate = MeasureDelegate { [weak self] pageCount in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.chapterPageCounts[index] = pageCount
                self.measureCount += 1

                // Update totals every batch
                if self.measureCount % self.measureBatchSize == 0 || self.measureQueue.isEmpty {
                    self.updatePageInfo()
                }

                // Throttle: delay before next measurement
                DispatchQueue.main.asyncAfter(deadline: .now() + self.measureDelay) { [weak self] in
                    self?.measureNextChapter()
                }
            }
        }
        objc_setAssociatedObject(hidden, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        hidden.navigationDelegate = delegate
        hidden.loadFileURL(url, allowingReadAccessTo: book.extractedURL)
    }

    public func zoomIn() {
        zoom = min(zoom + zoomStep, maxZoom)
        webView?.pageZoom = zoom
    }

    public func zoomOut() {
        zoom = max(zoom - zoomStep, minZoom)
        webView?.pageZoom = zoom
    }

    public func onChapterLoaded() {
        isLoading = false
        applyThemeStyles()
        injectHighlightEngine()
        if scrollToBottomOnLoad {
            scrollToBottomOnLoad = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.webView?.evaluateJavaScript("window.scrollTo(0, document.documentElement.scrollHeight);")
                self?.updatePageInfo()
            }
        } else if let initialScroll = initialScrollPosition, initialScroll > 0 {
            initialScrollPosition = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.webView?.evaluateJavaScript("window.scrollTo(0, \(initialScroll));")
                self?.updatePageInfo()
            }
        } else {
            restoreScrollPosition()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.updatePageInfo()
            if self?.chapterPageCounts.isEmpty == true {
                self?.startMeasuringAllChapters()
            }
        }
    }

    private func applyThemeStyles() {
        guard let webView = webView else { return }
        let bodyFont: String? = fontPairingId != nil ? bodyFontResolved : nil
        themeManager.applyStyles(to: webView, fontFamily: headerFont,
                                  bodyFont: bodyFont)
    }

    private func updateProgress() {
        guard totalPages > 0 else { return }
        readingProgress = Double(currentPage) / Double(totalPages)
    }

    public func saveScrollPosition() {
        webView?.evaluateJavaScript("window.scrollY") { [weak self] result, _ in
            if let y = result as? Double {
                self?.scrollPositions[self?.currentChapterIndex ?? 0] = y
            }
        }
    }

    private func restoreScrollPosition() {
        if let y = scrollPositions[currentChapterIndex], y > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.webView?.evaluateJavaScript("window.scrollTo(0, \(y));")
            }
        }
    }
}

extension ReaderViewModel {
    static let highlightEngineJS: String = """
    (function() {
        if (window._athHighlightInited) return;
        window._athHighlightInited = true;

        var _mode = 'off';
        var _color = 'rgba(255,255,0,0.3)';

        function getXPath(node) {
            if (node === document.documentElement) return '/html[1]';
            if (node === document.body) return '/html[1]/body[1]';
            var parent = node.parentNode;
            if (!parent) return '';
            var siblings = parent.childNodes;
            var sameTag = [];
            for (var i = 0; i < siblings.length; i++) {
                if (siblings[i].nodeType === node.nodeType) {
                    if (node.nodeType === 1) {
                        if (siblings[i].nodeName === node.nodeName) sameTag.push(siblings[i]);
                    } else {
                        sameTag.push(siblings[i]);
                    }
                }
            }
            var idx = sameTag.indexOf(node) + 1;
            var tag = node.nodeType === 1 ? node.nodeName.toLowerCase() : 'text()';
            return getXPath(parent) + '/' + tag + '[' + idx + ']';
        }

        function resolveXPath(xpath) {
            try {
                var result = document.evaluate(xpath, document, null,
                    XPathResult.FIRST_ORDERED_NODE_TYPE, null);
                return result.singleNodeValue;
            } catch(e) { return null; }
        }

        function wrapTextNode(textNode, startOff, endOff, id, color) {
            var text = textNode.textContent;
            var before = text.substring(0, startOff);
            var selected = text.substring(startOff, endOff);
            var after = text.substring(endOff);
            var parent = textNode.parentNode;
            var frag = document.createDocumentFragment();
            if (before) frag.appendChild(document.createTextNode(before));
            var mark = document.createElement('mark');
            mark.setAttribute('data-ath-highlight', id);
            mark.style.setProperty('--ath-hl-color', color);
            mark.appendChild(document.createTextNode(selected));
            frag.appendChild(mark);
            if (after) frag.appendChild(document.createTextNode(after));
            parent.replaceChild(frag, textNode);
        }

        function getTextNodesIn(range) {
            var nodes = [];
            var walker = document.createTreeWalker(
                range.commonAncestorContainer.nodeType === 1
                    ? range.commonAncestorContainer : range.commonAncestorContainer.parentNode,
                NodeFilter.SHOW_TEXT, null, false);
            var node;
            while (node = walker.nextNode()) {
                if (range.intersectsNode(node)) nodes.push(node);
            }
            return nodes;
        }

        function applyHighlight(range, color) {
            if (range.collapsed) return;
            var id = crypto.randomUUID ? crypto.randomUUID() :
                'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                    var r = Math.random()*16|0; return (c==='x'?r:(r&0x3|0x8)).toString(16);
                });
            var textNodes = getTextNodesIn(range);
            for (var i = 0; i < textNodes.length; i++) {
                var tn = textNodes[i];
                var s = (tn === range.startContainer) ? range.startOffset : 0;
                var e = (tn === range.endContainer) ? range.endOffset : tn.textContent.length;
                if (s >= e) continue;
                wrapTextNode(tn, s, e, id, color);
                // After wrapping, the walker's reference changes, so re-fetch text nodes
                if (i < textNodes.length - 1) {
                    var newRange = document.createRange();
                    // Find the next unprocessed text node
                    textNodes = getTextNodesIn(range);
                }
            }
        }

        function onMouseUp(e) {
            if (_mode !== 'highlight') return;
            var sel = window.getSelection();
            if (!sel || sel.isCollapsed || !sel.rangeCount) return;
            var range = sel.getRangeAt(0);
            applyHighlight(range, _color);
            sel.removeAllRanges();
            if (window.webkit && window.webkit.messageHandlers.highlightHandler) {
                window.webkit.messageHandlers.highlightHandler.postMessage({action: 'changed'});
            }
        }

        function onClick(e) {
            if (_mode !== 'eraser') return;
            var target = e.target;
            while (target && target !== document.body) {
                if (target.nodeName === 'MARK' && target.hasAttribute('data-ath-highlight')) {
                    var parent = target.parentNode;
                    while (target.firstChild) parent.insertBefore(target.firstChild, target);
                    parent.removeChild(target);
                    parent.normalize();
                    if (window.webkit && window.webkit.messageHandlers.highlightHandler) {
                        window.webkit.messageHandlers.highlightHandler.postMessage({action: 'changed'});
                    }
                    return;
                }
                target = target.parentNode;
            }
        }

        function updateCursorStyle() {
            var styleId = 'ath-cursor-style';
            var existing = document.getElementById(styleId);
            if (existing) existing.remove();
            if (_mode === 'off') return;
            var style = document.createElement('style');
            style.id = styleId;
            if (_mode === 'highlight') {
                style.textContent = 'body { cursor: text !important; }';
            } else if (_mode === 'eraser') {
                style.textContent = 'mark[data-ath-highlight] { cursor: pointer !important; }';
            }
            document.head.appendChild(style);
        }

        document.addEventListener('mouseup', onMouseUp, true);
        document.addEventListener('click', onClick, true);

        window.athSetHighlightMode = function(mode) {
            _mode = mode;
            updateCursorStyle();
        };

        window.athSetHighlightColor = function(cssColor) {
            _color = cssColor;
        };

        window.athEraseAllHighlights = function() {
            var marks = document.querySelectorAll('mark[data-ath-highlight]');
            marks.forEach(function(mark) {
                var parent = mark.parentNode;
                while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
                parent.removeChild(mark);
                parent.normalize();
            });
        };

        window.athCollectHighlights = function() {
            var marks = document.querySelectorAll('mark[data-ath-highlight]');
            var seen = {};
            var highlights = [];
            marks.forEach(function(mark) {
                var id = mark.getAttribute('data-ath-highlight');
                if (seen[id]) return;
                // Collect all marks with same id
                var allMarks = document.querySelectorAll('mark[data-ath-highlight="' + id + '"]');
                var text = '';
                allMarks.forEach(function(m) { text += m.textContent; });
                var first = allMarks[0];
                var last = allMarks[allMarks.length - 1];
                var startNode = first.firstChild || first;
                var endNode = last.lastChild || last;
                var color = first.style.getPropertyValue('--ath-hl-color') || _color;
                highlights.push({
                    id: id,
                    text: text,
                    startPath: getXPath(first),
                    startOffset: 0,
                    endPath: getXPath(last),
                    endOffset: (last.textContent || '').length,
                    color: color
                });
                seen[id] = true;
            });
            return JSON.stringify(highlights);
        };

        window.athHighlightInit = function(highlights, mode, color) {
            _color = color;
            _mode = mode;
            updateCursorStyle();
            if (!highlights || !highlights.length) return;
            for (var i = 0; i < highlights.length; i++) {
                var h = highlights[i];
                var startNode = resolveXPath(h.startPath);
                var endNode = resolveXPath(h.endPath);
                if (!startNode || !endNode) continue;
                // For restored highlights, wrap the resolved node's text content
                if (startNode === endNode) {
                    // Single node highlight
                    if (startNode.nodeType === 1) {
                        // It's an element, wrap its text children
                        var walker = document.createTreeWalker(startNode, NodeFilter.SHOW_TEXT, null, false);
                        var textNode = walker.nextNode();
                        if (textNode) {
                            var s = Math.min(h.startOffset, textNode.textContent.length);
                            var e = Math.min(h.endOffset, textNode.textContent.length);
                            if (s < e) wrapTextNode(textNode, s, e, h.id, h.color);
                        }
                    } else {
                        var s = Math.min(h.startOffset, startNode.textContent.length);
                        var e = Math.min(h.endOffset, startNode.textContent.length);
                        if (s < e) wrapTextNode(startNode, s, e, h.id, h.color);
                    }
                } else {
                    // Multi-node: create a range and apply
                    try {
                        var range = document.createRange();
                        if (startNode.nodeType === 1 && startNode.firstChild) {
                            range.setStart(startNode.firstChild, h.startOffset);
                        } else if (startNode.nodeType === 3) {
                            range.setStart(startNode, Math.min(h.startOffset, startNode.textContent.length));
                        } else {
                            range.setStartBefore(startNode);
                        }
                        if (endNode.nodeType === 1 && endNode.lastChild) {
                            range.setEnd(endNode.lastChild, Math.min(h.endOffset, (endNode.lastChild.textContent || '').length));
                        } else if (endNode.nodeType === 3) {
                            range.setEnd(endNode, Math.min(h.endOffset, endNode.textContent.length));
                        } else {
                            range.setEndAfter(endNode);
                        }
                        applyHighlight(range, h.color);
                    } catch(e) {}
                }
            }
        };
    })();
    """

    static let noteEngineJS: String = """
    (function() {
        if (window._athNoteInited) return;
        window._athNoteInited = true;

        var _noteMode = 'off';
        var _noteColor = 'rgba(147,130,220,0.25)';
        var _pendingNotes = {};

        function getXPath(node) {
            if (node === document.documentElement) return '/html[1]';
            if (node === document.body) return '/html[1]/body[1]';
            var parent = node.parentNode;
            if (!parent) return '';
            var siblings = parent.childNodes;
            var sameTag = [];
            for (var i = 0; i < siblings.length; i++) {
                if (siblings[i].nodeType === node.nodeType) {
                    if (node.nodeType === 1) {
                        if (siblings[i].nodeName === node.nodeName) sameTag.push(siblings[i]);
                    } else {
                        sameTag.push(siblings[i]);
                    }
                }
            }
            var idx = sameTag.indexOf(node) + 1;
            var tag = node.nodeType === 1 ? node.nodeName.toLowerCase() : 'text()';
            return getXPath(parent) + '/' + tag + '[' + idx + ']';
        }

        function resolveXPath(xpath) {
            try {
                var result = document.evaluate(xpath, document, null,
                    XPathResult.FIRST_ORDERED_NODE_TYPE, null);
                return result.singleNodeValue;
            } catch(e) { return null; }
        }

        function wrapNoteTextNode(textNode, startOff, endOff, id) {
            var text = textNode.textContent;
            var before = text.substring(0, startOff);
            var selected = text.substring(startOff, endOff);
            var after = text.substring(endOff);
            var parent = textNode.parentNode;
            var frag = document.createDocumentFragment();
            if (before) frag.appendChild(document.createTextNode(before));
            var mark = document.createElement('mark');
            mark.setAttribute('data-ath-note', id);
            mark.style.setProperty('--ath-note-color', _noteColor);
            mark.appendChild(document.createTextNode(selected));
            frag.appendChild(mark);
            if (after) frag.appendChild(document.createTextNode(after));
            parent.replaceChild(frag, textNode);
        }

        function getNoteTextNodesIn(range) {
            var nodes = [];
            var walker = document.createTreeWalker(
                range.commonAncestorContainer.nodeType === 1
                    ? range.commonAncestorContainer : range.commonAncestorContainer.parentNode,
                NodeFilter.SHOW_TEXT, null, false);
            var node;
            while (node = walker.nextNode()) {
                if (range.intersectsNode(node)) nodes.push(node);
            }
            return nodes;
        }

        function applyNoteMarks(range) {
            if (range.collapsed) return null;
            var id = crypto.randomUUID ? crypto.randomUUID() :
                'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                    var r = Math.random()*16|0; return (c==='x'?r:(r&0x3|0x8)).toString(16);
                });
            var textNodes = getNoteTextNodesIn(range);
            var selectedText = '';
            for (var i = 0; i < textNodes.length; i++) {
                var tn = textNodes[i];
                var s = (tn === range.startContainer) ? range.startOffset : 0;
                var e = (tn === range.endContainer) ? range.endOffset : tn.textContent.length;
                if (s >= e) continue;
                selectedText += tn.textContent.substring(s, e);
                wrapNoteTextNode(tn, s, e, id);
                if (i < textNodes.length - 1) {
                    textNodes = getNoteTextNodesIn(range);
                }
            }
            return { id: id, text: selectedText };
        }

        function onNoteMouseUp(e) {
            if (_noteMode !== 'on') return;
            var sel = window.getSelection();
            if (!sel || sel.isCollapsed || !sel.rangeCount) return;
            var range = sel.getRangeAt(0);
            var result = applyNoteMarks(range);
            sel.removeAllRanges();
            if (result) {
                _pendingNotes[result.id] = '';
                window.webkit.messageHandlers.noteHandler.postMessage({
                    action: 'requestNote',
                    noteId: result.id,
                    selectedText: result.text
                });
            }
        }

        function onNoteClick(e) {
            if (_noteMode === 'on') return;
            var target = e.target;
            while (target && target !== document.body) {
                if (target.nodeName === 'MARK' && target.hasAttribute('data-ath-note')) {
                    var noteId = target.getAttribute('data-ath-note');
                    var allMarks = document.querySelectorAll('mark[data-ath-note="' + noteId + '"]');
                    var selectedText = '';
                    allMarks.forEach(function(m) { selectedText += m.textContent; });
                    var noteText = target.getAttribute('data-note-text') || '';
                    window.webkit.messageHandlers.noteHandler.postMessage({
                        action: 'showNote',
                        noteId: noteId,
                        selectedText: selectedText,
                        noteText: noteText
                    });
                    e.preventDefault();
                    e.stopPropagation();
                    return;
                }
                target = target.parentNode;
            }
        }

        document.addEventListener('mouseup', onNoteMouseUp, true);
        document.addEventListener('click', onNoteClick, true);

        window.athSetNoteMode = function(mode) {
            _noteMode = mode;
            var styleId = 'ath-note-cursor-style';
            var existing = document.getElementById(styleId);
            if (existing) existing.remove();
            if (mode === 'on') {
                var style = document.createElement('style');
                style.id = styleId;
                style.textContent = 'body { cursor: text !important; }';
                document.head.appendChild(style);
            }
        };

        window.athConfirmNote = function(noteId, noteText) {
            var marks = document.querySelectorAll('mark[data-ath-note="' + noteId + '"]');
            marks.forEach(function(m) {
                m.setAttribute('data-note-text', noteText);
            });
            delete _pendingNotes[noteId];
        };

        window.athCancelNote = function(noteId) {
            var marks = document.querySelectorAll('mark[data-ath-note="' + noteId + '"]');
            marks.forEach(function(mark) {
                var parent = mark.parentNode;
                while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
                parent.removeChild(mark);
                parent.normalize();
            });
            delete _pendingNotes[noteId];
        };

        window.athDeleteNote = function(noteId) {
            var marks = document.querySelectorAll('mark[data-ath-note="' + noteId + '"]');
            marks.forEach(function(mark) {
                var parent = mark.parentNode;
                while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
                parent.removeChild(mark);
                parent.normalize();
            });
        };

        window.athUpdateNoteText = function(noteId, newText) {
            var marks = document.querySelectorAll('mark[data-ath-note="' + noteId + '"]');
            marks.forEach(function(m) {
                m.setAttribute('data-note-text', newText);
            });
        };

        window.athEraseAllNotes = function() {
            var marks = document.querySelectorAll('mark[data-ath-note]');
            marks.forEach(function(mark) {
                var parent = mark.parentNode;
                while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
                parent.removeChild(mark);
                parent.normalize();
            });
        };

        window.athCollectNotes = function() {
            var marks = document.querySelectorAll('mark[data-ath-note]');
            var seen = {};
            var notes = [];
            marks.forEach(function(mark) {
                var id = mark.getAttribute('data-ath-note');
                if (seen[id]) return;
                if (_pendingNotes.hasOwnProperty(id)) return;
                var noteText = mark.getAttribute('data-note-text') || '';
                if (!noteText) return;
                var allMarks = document.querySelectorAll('mark[data-ath-note="' + id + '"]');
                var text = '';
                allMarks.forEach(function(m) { text += m.textContent; });
                var first = allMarks[0];
                var last = allMarks[allMarks.length - 1];
                notes.push({
                    id: id,
                    text: text,
                    note: noteText,
                    startPath: getXPath(first),
                    startOffset: 0,
                    endPath: getXPath(last),
                    endOffset: (last.textContent || '').length,
                    createdAt: new Date().toISOString()
                });
                seen[id] = true;
            });
            return JSON.stringify(notes);
        };

        window.athNoteInit = function(notes, mode) {
            _noteMode = mode;
            var styleId = 'ath-note-cursor-style';
            var existing = document.getElementById(styleId);
            if (existing) existing.remove();
            if (mode === 'on') {
                var style = document.createElement('style');
                style.id = styleId;
                style.textContent = 'body { cursor: text !important; }';
                document.head.appendChild(style);
            }
            if (!notes || !notes.length) return;
            for (var i = 0; i < notes.length; i++) {
                var n = notes[i];
                var startNode = resolveXPath(n.startPath);
                var endNode = resolveXPath(n.endPath);
                if (!startNode || !endNode) continue;
                if (startNode === endNode) {
                    if (startNode.nodeType === 1) {
                        var walker = document.createTreeWalker(startNode, NodeFilter.SHOW_TEXT, null, false);
                        var textNode = walker.nextNode();
                        if (textNode) {
                            var s = Math.min(n.startOffset, textNode.textContent.length);
                            var e = Math.min(n.endOffset, textNode.textContent.length);
                            if (s < e) wrapNoteTextNode(textNode, s, e, n.id);
                        }
                    } else {
                        var s = Math.min(n.startOffset, startNode.textContent.length);
                        var e = Math.min(n.endOffset, startNode.textContent.length);
                        if (s < e) wrapNoteTextNode(startNode, s, e, n.id);
                    }
                } else {
                    try {
                        var range = document.createRange();
                        if (startNode.nodeType === 1 && startNode.firstChild) {
                            range.setStart(startNode.firstChild, n.startOffset);
                        } else if (startNode.nodeType === 3) {
                            range.setStart(startNode, Math.min(n.startOffset, startNode.textContent.length));
                        } else {
                            range.setStartBefore(startNode);
                        }
                        if (endNode.nodeType === 1 && endNode.lastChild) {
                            range.setEnd(endNode.lastChild, Math.min(n.endOffset, (endNode.lastChild.textContent || '').length));
                        } else if (endNode.nodeType === 3) {
                            range.setEnd(endNode, Math.min(n.endOffset, endNode.textContent.length));
                        } else {
                            range.setEndAfter(endNode);
                        }
                        var result = applyNoteMarks(range);
                        if (result) {
                            var restoredMarks = document.querySelectorAll('mark[data-ath-note="' + result.id + '"]');
                            // Replace generated id with stored id and set note text
                            restoredMarks.forEach(function(m) {
                                m.setAttribute('data-ath-note', n.id);
                                m.setAttribute('data-note-text', n.note || '');
                            });
                        }
                    } catch(e) {}
                }
                // Set note text on restored marks
                var restoredMarks = document.querySelectorAll('mark[data-ath-note="' + n.id + '"]');
                restoredMarks.forEach(function(m) {
                    m.setAttribute('data-note-text', n.note || '');
                });
            }
        };
    })();
    """
}

private class MeasureDelegate: NSObject, WKNavigationDelegate {
    let completion: (Int) -> Void

    init(completion: @escaping (Int) -> Void) {
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let js = """
        (function() {
            var viewportHeight = window.innerHeight;
            var docHeight = document.documentElement.scrollHeight;
            return Math.max(1, Math.ceil(docHeight / viewportHeight));
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            let pages = result as? Int ?? 1
            self?.completion(pages)
        }
    }
}
