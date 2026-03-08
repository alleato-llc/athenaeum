import Foundation
import AppKit
import WebKit
import Ligature

public class ThemeManager: ObservableObject {
    @Published public var themeMode: ThemeMode
    @Published public private(set) var activeTheme: ReadingTheme

    public var lightTheme: ReadingTheme
    public var darkTheme: ReadingTheme

    private var appearanceObservation: NSKeyValueObservation?

    public init(themeMode: ThemeMode, lightThemeId: String, darkThemeId: String) {
        self.themeMode = themeMode
        self.lightTheme = ReadingTheme.theme(byId: lightThemeId) ?? ReadingTheme.defaultLight
        self.darkTheme = ReadingTheme.theme(byId: darkThemeId) ?? ReadingTheme.defaultDark
        self.activeTheme = Self.resolveTheme(mode: themeMode, light: self.lightTheme, dark: self.darkTheme)

        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.resolveActiveTheme()
            }
        }
    }

    deinit {
        appearanceObservation?.invalidate()
        appearanceObservation = nil
    }

    public func cycleThemeMode() {
        switch themeMode {
        case .light:
            themeMode = .dark
        case .dark:
            themeMode = .system
        case .system:
            themeMode = .light
        }
        resolveActiveTheme()
    }

    public func resolveActiveTheme() {
        activeTheme = Self.resolveTheme(mode: themeMode, light: lightTheme, dark: darkTheme)
    }

    public func applyStyles(to webView: WKWebView, fontFamily: String, bodyFont: String? = nil) {
        let theme = activeTheme
        let headingCSS: String
        if let bodyFont = bodyFont {
            // Font pairing: fontFamily for headings, bodyFont for body
            headingCSS = """
                h1, h2, h3, h4, h5, h6 {
                    font-family: '\(fontFamily)', sans-serif !important;
                }
            """
            let bodyFontFamily = bodyFont
            let js = """
            (function() {
                var style = document.getElementById('focus-theme');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'focus-theme';
                    document.head.appendChild(style);
                }
                style.textContent = `
                    body {
                        font-family: '\(bodyFontFamily)', serif !important;
                        background-color: \(theme.backgroundColor) !important;
                        color: \(theme.textColor) !important;
                        line-height: 1.6 !important;
                        max-width: 45em !important;
                        margin: 0 auto !important;
                        padding: 20px !important;
                        transition: background-color 0.3s ease, color 0.3s ease !important;
                    }
                    * {
                        font-family: inherit !important;
                        color: inherit !important;
                        background-color: transparent !important;
                    }
                    mark[data-ath-highlight] {
                        background-color: var(--ath-hl-color) !important;
                        color: inherit !important;
                    }
                    mark[data-ath-note] {
                        background-color: var(--ath-note-color) !important;
                        color: inherit !important;
                        border-bottom: 1px dashed rgba(147,130,220,0.6);
                        cursor: pointer;
                    }
                    \(headingCSS)
                    body { background-color: \(theme.backgroundColor) !important; }
                    a, a:visited { color: \(theme.linkColor) !important; }
                    img { max-width: 100% !important; height: auto !important; }
                    pre, code {
                        background-color: \(theme.codeBackgroundColor) !important;
                    }
                `;
            })();
            """
            webView.evaluateJavaScript(js)
        } else {
            // Single font: current behavior
            let js = """
            (function() {
                var style = document.getElementById('focus-theme');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'focus-theme';
                    document.head.appendChild(style);
                }
                style.textContent = `
                    body {
                        font-family: '\(fontFamily)', serif !important;
                        background-color: \(theme.backgroundColor) !important;
                        color: \(theme.textColor) !important;
                        line-height: 1.6 !important;
                        max-width: 45em !important;
                        margin: 0 auto !important;
                        padding: 20px !important;
                        transition: background-color 0.3s ease, color 0.3s ease !important;
                    }
                    * {
                        font-family: inherit !important;
                        color: inherit !important;
                        background-color: transparent !important;
                    }
                    mark[data-ath-highlight] {
                        background-color: var(--ath-hl-color) !important;
                        color: inherit !important;
                    }
                    mark[data-ath-note] {
                        background-color: var(--ath-note-color) !important;
                        color: inherit !important;
                        border-bottom: 1px dashed rgba(147,130,220,0.6);
                        cursor: pointer;
                    }
                    body { background-color: \(theme.backgroundColor) !important; }
                    a, a:visited { color: \(theme.linkColor) !important; }
                    img { max-width: 100% !important; height: auto !important; }
                    pre, code {
                        background-color: \(theme.codeBackgroundColor) !important;
                    }
                `;
            })();
            """
            webView.evaluateJavaScript(js)
        }
    }

    private static func resolveTheme(mode: ThemeMode, light: ReadingTheme, dark: ReadingTheme) -> ReadingTheme {
        switch mode {
        case .light:
            return light
        case .dark:
            return dark
        case .system:
            let appearance = NSApp.effectiveAppearance
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        }
    }
}
