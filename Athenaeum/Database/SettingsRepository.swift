import Foundation
import GRDB
import Ligature

public class SettingsRepository {
    private let db: LibraryDatabase

    public init(database: LibraryDatabase) {
        self.db = database
    }

    public func get(_ key: String) throws -> String? {
        try db.dbPool.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?;",
                               arguments: [key])
        }
    }

    public func set(_ key: String, value: String) throws {
        try db.dbPool.write { db in
            try db.execute(sql: """
                INSERT INTO settings (key, value) VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value=excluded.value;
                """, arguments: [key, value])
        }
    }

    public func delete(_ key: String) throws {
        try db.dbPool.write { db in
            try db.execute(sql: "DELETE FROM settings WHERE key = ?;", arguments: [key])
        }
    }

    public func loadSettings() throws -> UserSettings {
        let libraryPath = try get("libraryPath") ?? UserSettings.defaultLibraryPath
        let defaultFont = try get("defaultFont") ?? "Georgia"
        let fontPairingId = try get("fontPairingId")

        let themeMode: ThemeMode
        if let themeModeStr = try get("themeMode") {
            themeMode = ThemeMode(rawValue: themeModeStr) ?? .system
        } else if let oldTheme = try get("defaultTheme") {
            themeMode = oldTheme == "dark" ? .dark : .light
        } else {
            themeMode = .system
        }

        let lightThemeId = try get("lightThemeId") ?? "classic"
        let darkThemeId = try get("darkThemeId") ?? "charcoal"
        let language = try get("language")

        return UserSettings(libraryPath: libraryPath, defaultFont: defaultFont,
                           fontPairingId: fontPairingId,
                           themeMode: themeMode, lightThemeId: lightThemeId,
                           darkThemeId: darkThemeId, language: language)
    }

    public func saveSettings(_ settings: UserSettings) throws {
        try set("libraryPath", value: settings.libraryPath)
        try set("defaultFont", value: settings.defaultFont)
        if let pairingId = settings.fontPairingId {
            try set("fontPairingId", value: pairingId)
        } else {
            try delete("fontPairingId")
        }
        try set("themeMode", value: settings.themeMode.rawValue)
        try set("lightThemeId", value: settings.lightThemeId)
        try set("darkThemeId", value: settings.darkThemeId)
        if let language = settings.language {
            try set("language", value: language)
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        } else {
            try delete("language")
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}
