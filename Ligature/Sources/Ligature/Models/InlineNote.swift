import Foundation

public struct InlineNote: Codable, Equatable, Identifiable {
    public let id: String
    public let text: String         // The selected/anchored text
    public let note: String         // The user's note content
    public let startPath: String    // XPath to start container
    public let startOffset: Int
    public let endPath: String      // XPath to end container
    public let endOffset: Int
    public let createdAt: Date

    public init(id: String, text: String, note: String,
                startPath: String, startOffset: Int,
                endPath: String, endOffset: Int, createdAt: Date) {
        self.id = id
        self.text = text
        self.note = note
        self.startPath = startPath
        self.startOffset = startOffset
        self.endPath = endPath
        self.endOffset = endOffset
        self.createdAt = createdAt
    }
}
