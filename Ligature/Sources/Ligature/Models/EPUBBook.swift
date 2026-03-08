import Foundation

public struct EPUBBook {
    public let title: String
    public let author: String
    public let language: String
    public let spine: [SpineItem]
    public let tableOfContents: [TOCEntry]
    public let baseURL: URL
    public let extractedURL: URL

    public init(title: String, author: String, language: String,
                spine: [SpineItem], tableOfContents: [TOCEntry], baseURL: URL,
                extractedURL: URL) {
        self.title = title
        self.author = author
        self.language = language
        self.spine = spine
        self.tableOfContents = tableOfContents
        self.baseURL = baseURL
        self.extractedURL = extractedURL
    }

    public func cleanup() {
        try? FileManager.default.removeItem(at: extractedURL)
    }

    public struct SpineItem {
        public let id: String
        public let href: String
        public let mediaType: String

        public init(id: String, href: String, mediaType: String) {
            self.id = id
            self.href = href
            self.mediaType = mediaType
        }
    }

    public struct TOCEntry {
        public let title: String
        public let href: String
        public let children: [TOCEntry]

        public init(title: String, href: String, children: [TOCEntry]) {
            self.title = title
            self.href = href
            self.children = children
        }
    }
}
