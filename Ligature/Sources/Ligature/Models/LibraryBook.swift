import Foundation

public struct ReadingPosition: Codable, Equatable {
    public var chapter: Int
    public var scroll: Double

    public init(chapter: Int, scroll: Double) {
        self.chapter = chapter
        self.scroll = scroll
    }
}

public struct LibraryBook: Identifiable {
    public let id: String
    public var title: String
    public var year: Int?
    public var genre: String?
    public var pageCount: Int?
    public var format: BookFormat
    public var identifiers: [String: String]
    public var coverPath: String?
    public var filePath: String
    public var groupId: String?
    public var dateAdded: Date
    public var readingPosition: ReadingPosition?

    public init(id: String = UUID().uuidString, title: String, year: Int? = nil,
                genre: String? = nil, pageCount: Int? = nil, format: BookFormat,
                identifiers: [String: String] = [:], coverPath: String? = nil,
                filePath: String, groupId: String? = nil, dateAdded: Date = Date(),
                readingPosition: ReadingPosition? = nil) {
        self.id = id
        self.title = title
        self.year = year
        self.genre = genre
        self.pageCount = pageCount
        self.format = format
        self.identifiers = identifiers
        self.coverPath = coverPath
        self.filePath = filePath
        self.groupId = groupId
        self.dateAdded = dateAdded
        self.readingPosition = readingPosition
    }
}

public enum BookFormat: String {
    case epub
    case pdf
    case txt

    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "epub": self = .epub
        case "pdf": self = .pdf
        case "txt": self = .txt
        default: return nil
        }
    }
}
