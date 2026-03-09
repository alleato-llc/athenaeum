import Foundation
import Ligature

/// Callback interface for the view layer to apply restored state to the WebView.
public protocol ReaderUndoDelegate: AnyObject {
    func applyHighlights(_ highlights: [Highlight], forChapter chapter: Int)
    func applyInlineNotes(_ notes: [InlineNote], forChapter chapter: Int)
    func applyChapterNotes(_ notes: String, forChapter chapter: Int)
}

/// Manages undo/redo state for reader annotations (highlights, inline notes, chapter notes, bookmarks).
/// Decoupled from WKWebView and UI — communicates view updates via `ReaderUndoDelegate`.
public class ReaderUndoManager {
    public let undoManager: UndoManager = {
        let um = UndoManager()
        um.groupsByEvent = false
        return um
    }()

    /// When true, incoming JS change callbacks should be ignored (we're restoring state).
    public var isRestoring = false

    /// Per-chapter caches — the source of truth for undo snapshots.
    public var highlightsCache: [Int: [Highlight]] = [:]
    public var inlineNotesCache: [Int: [InlineNote]] = [:]
    public var chapterNotesCache: [Int: String] = [:]

    public weak var delegate: ReaderUndoDelegate?

    public init() {}

    // MARK: - Highlights

    /// Record a highlight change. Call with old state captured synchronously before async JS collection.
    /// `newHighlights` is the result of collecting from JS after the change.
    public func recordHighlightChange(chapter: Int, bookId: String,
                                       old: [Highlight], new: [Highlight]) {
        guard new != old else { return }
        highlightsCache[chapter] = new
        postSaveHighlights(bookId: bookId, chapter: chapter, highlights: new)
        registerUndo { mgr in
            mgr.restoreHighlights(chapter: chapter, highlights: old, bookId: bookId)
        }
    }

    /// Erase all highlights for a chapter. Records undo to restore them.
    public func eraseAllHighlights(chapter: Int, bookId: String) {
        let old = highlightsCache[chapter] ?? []
        highlightsCache[chapter] = []
        postSaveHighlights(bookId: bookId, chapter: chapter, highlights: [])
        if !old.isEmpty {
            registerUndo { mgr in
                mgr.restoreHighlights(chapter: chapter, highlights: old, bookId: bookId)
            }
        }
    }

    private func restoreHighlights(chapter: Int, highlights: [Highlight], bookId: String) {
        let current = highlightsCache[chapter] ?? []
        highlightsCache[chapter] = highlights
        isRestoring = true
        delegate?.applyHighlights(highlights, forChapter: chapter)
        postSaveHighlights(bookId: bookId, chapter: chapter, highlights: highlights)
        registerUndo { mgr in
            mgr.restoreHighlights(chapter: chapter, highlights: current, bookId: bookId)
        }
    }

    /// Call after the delegate has finished applying state (e.g., after JS completes).
    public func clearRestoring() {
        isRestoring = false
    }

    // MARK: - Inline Notes

    /// Record an inline note change. Call with old state captured synchronously.
    public func recordInlineNoteChange(chapter: Int, bookId: String,
                                        old: [InlineNote], new: [InlineNote]) {
        guard new != old else { return }
        inlineNotesCache[chapter] = new
        postSaveInlineNotes(bookId: bookId, chapter: chapter, notes: new)
        registerUndo { mgr in
            mgr.restoreInlineNotes(chapter: chapter, notes: old, bookId: bookId)
        }
    }

    private func restoreInlineNotes(chapter: Int, notes: [InlineNote], bookId: String) {
        let current = inlineNotesCache[chapter] ?? []
        inlineNotesCache[chapter] = notes
        isRestoring = true
        delegate?.applyInlineNotes(notes, forChapter: chapter)
        postSaveInlineNotes(bookId: bookId, chapter: chapter, notes: notes)
        registerUndo { mgr in
            mgr.restoreInlineNotes(chapter: chapter, notes: current, bookId: bookId)
        }
    }

    // MARK: - Chapter Notes

    /// Record a chapter note change. Returns true if the change was recorded.
    @discardableResult
    public func recordChapterNoteChange(chapter: Int, bookId: String,
                                         old: String?, new: String?) -> Bool {
        guard new != old else { return false }
        chapterNotesCache[chapter] = new
        postSaveChapterNotes(bookId: bookId, chapter: chapter, notes: new)
        registerUndo { mgr in
            mgr.restoreChapterNotes(chapter: chapter, notes: old, bookId: bookId)
        }
        return true
    }

    private func restoreChapterNotes(chapter: Int, notes: String?, bookId: String) {
        let current = chapterNotesCache[chapter]
        chapterNotesCache[chapter] = notes
        delegate?.applyChapterNotes(notes ?? "", forChapter: chapter)
        postSaveChapterNotes(bookId: bookId, chapter: chapter, notes: notes)
        registerUndo { mgr in
            mgr.restoreChapterNotes(chapter: chapter, notes: current, bookId: bookId)
        }
    }

    // MARK: - Private

    /// Wraps each undo registration in its own group so each is a separate undo step.
    private func registerUndo(_ handler: @escaping (ReaderUndoManager) -> Void) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self, handler: handler)
        undoManager.endUndoGrouping()
    }

    private func postSaveHighlights(bookId: String, chapter: Int, highlights: [Highlight]) {
        NotificationCenter.default.post(
            name: .saveHighlights, object: nil,
            userInfo: ["bookId": bookId, "chapterIndex": chapter, "highlights": highlights]
        )
    }

    private func postSaveInlineNotes(bookId: String, chapter: Int, notes: [InlineNote]) {
        NotificationCenter.default.post(
            name: .saveInlineNotes, object: nil,
            userInfo: ["bookId": bookId, "chapterIndex": chapter, "inlineNotes": notes]
        )
    }

    private func postSaveChapterNotes(bookId: String, chapter: Int, notes: String?) {
        NotificationCenter.default.post(
            name: .saveChapterNotes, object: nil,
            userInfo: ["bookId": bookId, "chapterIndex": chapter, "notes": notes as Any]
        )
    }
}
