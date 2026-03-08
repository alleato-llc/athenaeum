import SwiftUI

private let bundle = Bundle.module

public struct SettingsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var libraryPath: String
    @State private var defaultFont: String
    @State private var lightThemeId: String
    @State private var darkThemeId: String

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
        _libraryPath = State(initialValue: viewModel.settings.libraryPath)
        _defaultFont = State(initialValue: viewModel.settings.defaultFont)
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
                    Picker(NSLocalizedString("settings.font", bundle: bundle, comment: ""),
                           selection: $defaultFont) {
                        ForEach(ReadingTheme.availableFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }

                    Picker(NSLocalizedString("settings.theme.lightTheme", bundle: bundle, comment: ""),
                           selection: $lightThemeId) {
                        ForEach(ReadingTheme.lightThemes) { theme in
                            HStack {
                                ThemePreviewSwatch(theme: theme)
                                Text(NSLocalizedString(theme.name, bundle: bundle, comment: ""))
                            }
                            .tag(theme.id)
                        }
                    }

                    Picker(NSLocalizedString("settings.theme.darkTheme", bundle: bundle, comment: ""),
                           selection: $darkThemeId) {
                        ForEach(ReadingTheme.darkThemes) { theme in
                            HStack {
                                ThemePreviewSwatch(theme: theme)
                                Text(NSLocalizedString(theme.name, bundle: bundle, comment: ""))
                            }
                            .tag(theme.id)
                        }
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
                    viewModel.settings.lightThemeId = lightThemeId
                    viewModel.settings.darkThemeId = darkThemeId
                    viewModel.saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 450)
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

private struct ThemePreviewSwatch: View {
    let theme: ReadingTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: theme.backgroundColor))
                .frame(width: 40, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
                )

            HStack(spacing: 2) {
                Text("Aa")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: theme.textColor))
                Circle()
                    .fill(Color(hex: theme.linkColor))
                    .frame(width: 5, height: 5)
            }
        }
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
