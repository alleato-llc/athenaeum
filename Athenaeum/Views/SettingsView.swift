import SwiftUI
import Forma

#if SWIFT_PACKAGE
private let bundle = Bundle.module
#else
private let bundle = Bundle.main
#endif

public struct SettingsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: SettingsTab = .general
    @State private var libraryPath: String
    @State private var defaultFont: String
    @State private var useFontPairing: Bool
    @State private var fontPairingId: String
    @State private var lightThemeId: String
    @State private var darkThemeId: String
    @State private var language: String

    enum SettingsTab: Hashable {
        case general
        case reading
        case libraryData
    }

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
        _libraryPath = State(initialValue: viewModel.settings.libraryPath)
        _defaultFont = State(initialValue: viewModel.settings.defaultFont)
        _useFontPairing = State(initialValue: viewModel.settings.fontPairingId != nil)
        _fontPairingId = State(initialValue: viewModel.settings.fontPairingId ?? FontPairing.defaultPairing.id)
        _lightThemeId = State(initialValue: viewModel.settings.lightThemeId)
        _darkThemeId = State(initialValue: viewModel.settings.darkThemeId)
        _language = State(initialValue: viewModel.settings.language ?? "system")
    }

    private var activePairing: FontPairing? {
        guard useFontPairing else { return nil }
        return FontPairing.pairing(byId: fontPairingId)
    }

    private var previewHeaderFont: String {
        activePairing?.headerFont ?? defaultFont
    }

    private var previewBodyFont: String {
        activePairing?.bodyFont ?? defaultFont
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString("settings.title", bundle: bundle, comment: ""))
                .font(.headline)
                .padding()

            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem {
                        Label(NSLocalizedString("settings.tab.general", bundle: bundle, comment: ""),
                              systemImage: "gearshape")
                    }
                    .tag(SettingsTab.general)

                readingTab
                    .tabItem {
                        Label(NSLocalizedString("settings.tab.reading", bundle: bundle, comment: ""),
                              systemImage: "book")
                    }
                    .tag(SettingsTab.reading)

                libraryDataTab
                    .tabItem {
                        Label(NSLocalizedString("settings.tab.library_data", bundle: bundle, comment: ""),
                              systemImage: "archivebox")
                    }
                    .tag(SettingsTab.libraryData)
            }
            .padding()

            Divider()

            HStack {
                Button(NSLocalizedString("edit.cancel", bundle: bundle, comment: "")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(NSLocalizedString("edit.save", bundle: bundle, comment: "")) {
                    viewModel.settings.libraryPath = libraryPath
                    viewModel.settings.defaultFont = defaultFont
                    viewModel.settings.fontPairingId = useFontPairing ? fontPairingId : nil
                    viewModel.settings.lightThemeId = lightThemeId
                    viewModel.settings.darkThemeId = darkThemeId
                    viewModel.settings.language = language == "system" ? nil : language
                    viewModel.saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 520, height: 520)
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section(NSLocalizedString("settings.language", bundle: bundle, comment: "")) {
                Picker(NSLocalizedString("settings.language", bundle: bundle, comment: ""),
                       selection: $language) {
                    ForEach(UserSettings.supportedLanguages, id: \.name) { lang in
                        Text(lang.name).tag(lang.code ?? "system")
                    }
                }

                if language != (viewModel.settings.language ?? "system") {
                    Text(NSLocalizedString("settings.language.restart", bundle: bundle, comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(NSLocalizedString("settings.library", bundle: bundle, comment: "")) {
                HStack {
                    TextField(NSLocalizedString("settings.library.path", bundle: bundle, comment: ""),
                             text: $libraryPath)
                        .textFieldStyle(.roundedBorder)
                    Button(NSLocalizedString("settings.library.browse", bundle: bundle, comment: "")) {
                        browseLibraryPath()
                    }
                }
            }
        }
    }

    // MARK: - Reading Tab

    @ViewBuilder
    private var readingTab: some View {
        Form {
            Section(NSLocalizedString("settings.reading", bundle: bundle, comment: "")) {
                Toggle(NSLocalizedString("settings.font.pairing", bundle: bundle, comment: ""),
                       isOn: $useFontPairing)

                if useFontPairing {
                    Picker(NSLocalizedString("settings.font.pairing.label", bundle: bundle, comment: ""),
                           selection: $fontPairingId) {
                        ForEach(FontPairing.pairings) { pairing in
                            Text(NSLocalizedString(pairing.name, bundle: bundle, comment: ""))
                                .tag(pairing.id)
                        }
                    }
                } else {
                    Picker(NSLocalizedString("settings.font", bundle: bundle, comment: ""),
                           selection: $defaultFont) {
                        ForEach(ReadingTheme.availableFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                }

                Picker(NSLocalizedString("settings.theme.lightTheme", bundle: bundle, comment: ""),
                       selection: $lightThemeId) {
                    ForEach(ReadingTheme.lightThemes) { theme in
                        Text(NSLocalizedString(theme.name, bundle: bundle, comment: ""))
                            .tag(theme.id)
                    }
                }

                if let lightTheme = ReadingTheme.lightThemes.first(where: { $0.id == lightThemeId }) {
                    ThemePreviewCard(theme: lightTheme,
                                     headerFont: previewHeaderFont,
                                     bodyFont: previewBodyFont)
                }

                Picker(NSLocalizedString("settings.theme.darkTheme", bundle: bundle, comment: ""),
                       selection: $darkThemeId) {
                    ForEach(ReadingTheme.darkThemes) { theme in
                        Text(NSLocalizedString(theme.name, bundle: bundle, comment: ""))
                            .tag(theme.id)
                    }
                }

                if let darkTheme = ReadingTheme.darkThemes.first(where: { $0.id == darkThemeId }) {
                    ThemePreviewCard(theme: darkTheme,
                                     headerFont: previewHeaderFont,
                                     bodyFont: previewBodyFont)
                }
            }
        }
    }

    // MARK: - Library Data Tab

    @ViewBuilder
    private var libraryDataTab: some View {
        Form {
            Section(NSLocalizedString("settings.data.export", bundle: bundle, comment: "")) {
                Text(NSLocalizedString("settings.data.export.description", bundle: bundle, comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(NSLocalizedString("settings.data.export.button", bundle: bundle, comment: "")) {
                    viewModel.exportLibrary()
                }
            }

            Section(NSLocalizedString("settings.data.import", bundle: bundle, comment: "")) {
                Text(NSLocalizedString("settings.data.import.description", bundle: bundle, comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(NSLocalizedString("settings.data.import.button", bundle: bundle, comment: "")) {
                    viewModel.importLibrary()
                }
            }

            Section(NSLocalizedString("settings.data.import_directory", bundle: bundle, comment: "")) {
                Text(NSLocalizedString("settings.data.import_directory.description", bundle: bundle, comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(NSLocalizedString("settings.data.import_directory.button", bundle: bundle, comment: "")) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.importFromDirectory()
                    }
                }
            }
        }
    }

    private func browseLibraryPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            libraryPath = url.path
        }
    }
}

private struct ThemePreviewCard: View {
    let theme: ReadingTheme
    var headerFont: String = "Georgia"
    var bodyFont: String = "Georgia"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString(theme.name, bundle: bundle, comment: ""))
                .font(.custom(headerFont, size: 13))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: theme.textColor))

            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation.")
                .font(.custom(bodyFont, size: 11))
                .foregroundColor(Color(hex: theme.textColor))

            Text("Read more")
                .font(.custom(bodyFont, size: 11))
                .foregroundColor(Color(hex: theme.linkColor))

            Text("let x = 42")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: theme.textColor))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: theme.codeBackgroundColor))
                )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: theme.backgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
