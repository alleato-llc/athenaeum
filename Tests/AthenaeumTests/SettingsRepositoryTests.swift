import Testing
import Foundation
@testable import Athenaeum
import Ligature

@Suite("SettingsRepository")
struct SettingsRepositoryTests {
    @Test("Get returns nil for missing key")
    func getReturnsNilForMissing() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        #expect(try env.settingsRepo.get("nonexistent") == nil)
    }

    @Test("Set and get returns value")
    func setAndGet() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.settingsRepo.set("key1", value: "value1")
        #expect(try env.settingsRepo.get("key1") == "value1")
    }

    @Test("Set overwrites previous value")
    func setOverwrites() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.settingsRepo.set("key1", value: "old")
        try env.settingsRepo.set("key1", value: "new")
        #expect(try env.settingsRepo.get("key1") == "new")
    }

    @Test("Delete removes key")
    func deleteRemovesKey() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        try env.settingsRepo.set("key1", value: "value1")
        try env.settingsRepo.delete("key1")
        #expect(try env.settingsRepo.get("key1") == nil)
    }

    @Test("Load settings returns defaults for fresh DB")
    func loadSettingsDefaults() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        let settings = try env.settingsRepo.loadSettings()
        #expect(settings.defaultFont == "Georgia")
        #expect(settings.themeMode == .system)
        #expect(settings.lightThemeId == "classic")
        #expect(settings.darkThemeId == "charcoal")
    }

    @Test("Save and load settings round-trip")
    func saveAndLoadSettingsRoundTrip() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        let custom = UserSettings(defaultFont: "Palatino", fontPairingId: "modern-serif",
                                   themeMode: .dark, lightThemeId: "paper",
                                   darkThemeId: "midnight", language: "es")
        try env.settingsRepo.saveSettings(custom)

        let loaded = try env.settingsRepo.loadSettings()
        #expect(loaded.defaultFont == "Palatino")
        #expect(loaded.fontPairingId == "modern-serif")
        #expect(loaded.themeMode == .dark)
        #expect(loaded.lightThemeId == "paper")
        #expect(loaded.darkThemeId == "midnight")
        #expect(loaded.language == "es")
    }

    @Test("Save settings with nil optionals")
    func saveSettingsWithNilOptionals() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        let settings = UserSettings(defaultFont: "Georgia", fontPairingId: nil, language: nil)
        try env.settingsRepo.saveSettings(settings)

        let loaded = try env.settingsRepo.loadSettings()
        #expect(loaded.fontPairingId == nil)
        #expect(loaded.language == nil)
    }

    @Test("Save settings with optional values")
    func saveSettingsWithOptionals() throws {
        let env = try TestDatabase.create()
        defer { env.cleanup() }

        let settings = UserSettings(defaultFont: "Helvetica", fontPairingId: "classic-serif",
                                     language: "it")
        try env.settingsRepo.saveSettings(settings)

        let loaded = try env.settingsRepo.loadSettings()
        #expect(loaded.fontPairingId == "classic-serif")
        #expect(loaded.language == "it")
    }
}
