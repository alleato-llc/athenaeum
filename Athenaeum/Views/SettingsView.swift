import SwiftUI
import Forma

private let bundle = Bundle.module

public struct SettingsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var libraryPath: String
    @State private var defaultFont: String
    @State private var useFontPairing: Bool
    @State private var bodyFont: String
    @State private var lightThemeId: String
    @State private var darkThemeId: String

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
        _libraryPath = State(initialValue: viewModel.settings.libraryPath)
        _defaultFont = State(initialValue: viewModel.settings.defaultFont)
        _useFontPairing = State(initialValue: viewModel.settings.useFontPairing)
        _bodyFont = State(initialValue: viewModel.settings.bodyFont)
        _lightThemeId = State(initialValue: viewModel.settings.lightThemeId)
        _darkThemeId = State(initialValue: viewModel.settings.darkThemeId)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString("settings.title", bundle: bundle, comment: ""))
                .font(.headline)
                .padding()

            Form {
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

                Section(NSLocalizedString("settings.reading", bundle: bundle, comment: "")) {
                    Toggle(NSLocalizedString("settings.font.pairing", bundle: bundle, comment: ""),
                           isOn: $useFontPairing)

                    if useFontPairing {
                        Picker(NSLocalizedString("settings.font.header", bundle: bundle, comment: ""),
                               selection: $defaultFont) {
                            ForEach(ReadingTheme.availableFonts, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        Picker(NSLocalizedString("settings.font.body", bundle: bundle, comment: ""),
                               selection: $bodyFont) {
                            ForEach(ReadingTheme.availableFonts, id: \.self) { font in
                                Text(font).tag(font)
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
                                         headerFont: defaultFont,
                                         bodyFont: useFontPairing ? bodyFont : defaultFont)
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
                                         headerFont: defaultFont,
                                         bodyFont: useFontPairing ? bodyFont : defaultFont)
                    }
                }
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
                    viewModel.settings.useFontPairing = useFontPairing
                    viewModel.settings.bodyFont = bodyFont
                    viewModel.settings.lightThemeId = lightThemeId
                    viewModel.settings.darkThemeId = darkThemeId
                    viewModel.saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
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
