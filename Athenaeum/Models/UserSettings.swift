import Foundation
import Ligature

public struct UserSettings {
    public var libraryPath: String
    public var defaultFont: String
    public var useFontPairing: Bool
    public var bodyFont: String
    public var themeMode: ThemeMode
    public var lightThemeId: String
    public var darkThemeId: String

    public static var defaultLibraryPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Athenaeum").path
    }

    public init(libraryPath: String? = nil, defaultFont: String = "Georgia",
                useFontPairing: Bool = false, bodyFont: String = "Georgia",
                themeMode: ThemeMode = .system, lightThemeId: String = "classic",
                darkThemeId: String = "charcoal") {
        self.libraryPath = libraryPath ?? Self.defaultLibraryPath
        self.defaultFont = defaultFont
        self.useFontPairing = useFontPairing
        self.bodyFont = bodyFont
        self.themeMode = themeMode
        self.lightThemeId = lightThemeId
        self.darkThemeId = darkThemeId
    }
}
