import Foundation

public struct EPUBMetadata {
    public var title: String = ""
    public var author: String = ""
    public var language: String = "en"
    public var identifier: String = ""
    public var publisher: String = ""
    public var description: String = ""
    public var version: EPUBVersion = .epub2

    public enum EPUBVersion: String {
        case epub2 = "2.0"
        case epub3 = "3.0"
        case unknown
    }

    public init() {}
}
