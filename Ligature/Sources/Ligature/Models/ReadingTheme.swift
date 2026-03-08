import Foundation

public enum ThemeCategory: String {
    case light
    case dark
}

public struct ReadingTheme: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let category: ThemeCategory
    public let backgroundColor: String
    public let textColor: String
    public let linkColor: String
    public let codeBackgroundColor: String

    public init(id: String, name: String, category: ThemeCategory,
                backgroundColor: String, textColor: String,
                linkColor: String, codeBackgroundColor: String) {
        self.id = id
        self.name = name
        self.category = category
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.linkColor = linkColor
        self.codeBackgroundColor = codeBackgroundColor
    }

    public static let allThemes: [ReadingTheme] = [
        // Light themes
        ReadingTheme(id: "classic", name: "theme.classic", category: .light,
                     backgroundColor: "#ffffff", textColor: "#000000",
                     linkColor: "#0066cc", codeBackgroundColor: "#f5f5f5"),
        ReadingTheme(id: "sepia", name: "theme.sepia", category: .light,
                     backgroundColor: "#fdf6e3", textColor: "#5b4636",
                     linkColor: "#8b6914", codeBackgroundColor: "#f0e8d5"),
        ReadingTheme(id: "paper", name: "theme.paper", category: .light,
                     backgroundColor: "#f5f0eb", textColor: "#2c2c2c",
                     linkColor: "#4a6fa5", codeBackgroundColor: "#e8e2db"),
        ReadingTheme(id: "ivory", name: "theme.ivory", category: .light,
                     backgroundColor: "#fffff0", textColor: "#333333",
                     linkColor: "#2e6b8a", codeBackgroundColor: "#f5f5e5"),
        ReadingTheme(id: "sage", name: "theme.sage", category: .light,
                     backgroundColor: "#f0f4ef", textColor: "#2d3b2d",
                     linkColor: "#4a7c59", codeBackgroundColor: "#e3e8e2"),

        // Dark themes
        ReadingTheme(id: "charcoal", name: "theme.charcoal", category: .dark,
                     backgroundColor: "#1e1e1e", textColor: "#e0e0e0",
                     linkColor: "#6db3f2", codeBackgroundColor: "#2d2d2d"),
        ReadingTheme(id: "midnight", name: "theme.midnight", category: .dark,
                     backgroundColor: "#0d1117", textColor: "#c9d1d9",
                     linkColor: "#58a6ff", codeBackgroundColor: "#161b22"),
        ReadingTheme(id: "solarizedDark", name: "theme.solarizedDark", category: .dark,
                     backgroundColor: "#002b36", textColor: "#839496",
                     linkColor: "#268bd2", codeBackgroundColor: "#073642"),
        ReadingTheme(id: "monokai", name: "theme.monokai", category: .dark,
                     backgroundColor: "#272822", textColor: "#f8f8f2",
                     linkColor: "#66d9ef", codeBackgroundColor: "#3e3d32"),
        ReadingTheme(id: "slate", name: "theme.slate", category: .dark,
                     backgroundColor: "#1a1d23", textColor: "#abb2bf",
                     linkColor: "#61afef", codeBackgroundColor: "#282c34"),
    ]

    public static var lightThemes: [ReadingTheme] {
        allThemes.filter { $0.category == .light }
    }

    public static var darkThemes: [ReadingTheme] {
        allThemes.filter { $0.category == .dark }
    }

    public static func theme(byId id: String) -> ReadingTheme? {
        allThemes.first { $0.id == id }
    }

    public static var defaultLight: ReadingTheme {
        theme(byId: "classic")!
    }

    public static var defaultDark: ReadingTheme {
        theme(byId: "charcoal")!
    }

    public static let availableFonts = [
        "Georgia", "Palatino", "Times New Roman",
        "Helvetica", "Arial", "Verdana",
        "Courier New", "Menlo"
    ]
}
