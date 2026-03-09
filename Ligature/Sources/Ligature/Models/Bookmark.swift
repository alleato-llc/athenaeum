import Foundation

public struct Bookmark: Codable, Equatable, Identifiable {
    public let id: String
    public let chapterIndex: Int
    public let scrollPosition: Double
    public let label: String
    public let createdAt: Date

    public init(id: String, chapterIndex: Int, scrollPosition: Double,
                label: String, createdAt: Date) {
        self.id = id
        self.chapterIndex = chapterIndex
        self.scrollPosition = scrollPosition
        self.label = label
        self.createdAt = createdAt
    }
}
