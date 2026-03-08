import Foundation
import SQLite3
import Ligature

public class SettingsRepository {
    private let db: LibraryDatabase

    public init(database: LibraryDatabase) {
        self.db = database
    }

    public func get(_ key: String) throws -> String? {
        let stmt = try db.prepareStatement("SELECT value FROM settings WHERE key = ?;")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return String(cString: sqlite3_column_text(stmt, 0))
    }

    public func set(_ key: String, value: String) throws {
        let stmt = try db.prepareStatement("""
            INSERT INTO settings (key, value) VALUES (?, ?)
            ON CONFLICT(key) DO UPDATE SET value=excluded.value;
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (value as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LibraryDatabaseError.queryFailed("Failed to set setting")
        }
    }

    public func loadSettings() throws -> UserSettings {
        let libraryPath = try get("libraryPath") ?? UserSettings.defaultLibraryPath
        let defaultFont = try get("defaultFont") ?? "Georgia"

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

        return UserSettings(libraryPath: libraryPath, defaultFont: defaultFont,
                           themeMode: themeMode, lightThemeId: lightThemeId,
                           darkThemeId: darkThemeId)
    }

    public func saveSettings(_ settings: UserSettings) throws {
        try set("libraryPath", value: settings.libraryPath)
        try set("defaultFont", value: settings.defaultFont)
        try set("themeMode", value: settings.themeMode.rawValue)
        try set("lightThemeId", value: settings.lightThemeId)
        try set("darkThemeId", value: settings.darkThemeId)
    }
}
