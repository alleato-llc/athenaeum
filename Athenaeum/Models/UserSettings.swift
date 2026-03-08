import Foundation
import Ligature

public struct UserSettings {
    public var libraryPath: String
    public var defaultFont: String
    public var fontPairingId: String?
    public var themeMode: ThemeMode
    public var lightThemeId: String
    public var darkThemeId: String
    public var language: String?

    public static let supportedLanguages: [(code: String?, name: String)] = [
        (nil, "System Default"),
        ("en", "English"),
        ("es", "Español"),
        ("it", "Italiano"),
    ]

    public static var defaultLibraryPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Athenaeum").path
    }

    public init(libraryPath: String? = nil, defaultFont: String = "Georgia",
                fontPairingId: String? = nil,
                themeMode: ThemeMode = .system, lightThemeId: String = "classic",
                darkThemeId: String = "charcoal", language: String? = nil) {
        self.libraryPath = libraryPath ?? Self.defaultLibraryPath
        self.defaultFont = defaultFont
        self.fontPairingId = fontPairingId
        self.themeMode = themeMode
        self.lightThemeId = lightThemeId
        self.darkThemeId = darkThemeId
        self.language = language
    }

    public var useFontPairing: Bool {
        fontPairingId != nil
    }

    public var activePairing: FontPairing? {
        guard let id = fontPairingId else { return nil }
        return FontPairing.pairing(byId: id)
    }

    /// The font used for headings — pairing header font or defaultFont
    public var headerFont: String {
        activePairing?.headerFont ?? defaultFont
    }

    /// The font used for body text — pairing body font or defaultFont
    public var bodyFont: String {
        activePairing?.bodyFont ?? defaultFont
    }
}
