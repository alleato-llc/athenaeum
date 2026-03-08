import Foundation

public extension Notification.Name {
    static let openBook = Notification.Name("com.athenaeum.openBook")
    static let addBooks = Notification.Name("com.athenaeum.addBooks")
    static let saveReadingProgress = Notification.Name("com.athenaeum.saveReadingProgress")
    static let saveHighlights = Notification.Name("com.athenaeum.saveHighlights")
    static let addBookmark = Notification.Name("com.athenaeum.addBookmark")
    static let deleteBookmark = Notification.Name("com.athenaeum.deleteBookmark")
    static let saveChapterNotes = Notification.Name("com.athenaeum.saveChapterNotes")
    static let saveInlineNotes = Notification.Name("com.athenaeum.saveInlineNotes")
    static let openNotesReview = Notification.Name("com.athenaeum.openNotesReview")
}
