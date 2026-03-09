import Foundation

public struct Highlight: Codable, Equatable {
    public let id: String
    public let text: String
    public let startPath: String
    public let startOffset: Int
    public let endPath: String
    public let endOffset: Int
    public let color: String

    public init(id: String, text: String, startPath: String, startOffset: Int,
                endPath: String, endOffset: Int, color: String) {
        self.id = id
        self.text = text
        self.startPath = startPath
        self.startOffset = startOffset
        self.endPath = endPath
        self.endOffset = endOffset
        self.color = color
    }
}

public struct HighlightColor: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let cssColor: String

    public init(id: String, name: String, cssColor: String) {
        self.id = id
        self.name = name
        self.cssColor = cssColor
    }

    public static let palette: [HighlightColor] = [
        .init(id: "yellow", name: "highlight.color.yellow", cssColor: "rgba(255,255,0,0.3)"),
        .init(id: "green",  name: "highlight.color.green",  cssColor: "rgba(0,255,0,0.25)"),
        .init(id: "blue",   name: "highlight.color.blue",   cssColor: "rgba(0,150,255,0.25)"),
        .init(id: "pink",   name: "highlight.color.pink",   cssColor: "rgba(255,105,180,0.3)"),
        .init(id: "orange", name: "highlight.color.orange",  cssColor: "rgba(255,165,0,0.3)"),
    ]

    public var swiftUIColor: (red: Double, green: Double, blue: Double, opacity: Double) {
        switch id {
        case "yellow": return (1.0, 1.0, 0.0, 0.3)
        case "green":  return (0.0, 1.0, 0.0, 0.25)
        case "blue":   return (0.0, 0.588, 1.0, 0.25)
        case "pink":   return (1.0, 0.412, 0.706, 0.3)
        case "orange": return (1.0, 0.647, 0.0, 0.3)
        default:       return (1.0, 1.0, 0.0, 0.3)
        }
    }

    /// Fixed color used for inline note anchors — visually distinct from highlight palette.
    public static let noteColor = "rgba(147,130,220,0.25)"
    public static let noteSwiftUIColor: (red: Double, green: Double, blue: Double, opacity: Double) =
        (0.576, 0.510, 0.863, 0.25)
}
