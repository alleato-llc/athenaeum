# Fonts

## Overview

The reader supports two font modes: a single unified font applied to all text, or an optional font pairing that uses separate fonts for headings and body text.

## Available Fonts

Eight system fonts are available, defined in `ReadingTheme.availableFonts`:

| Font | Category |
|------|----------|
| Georgia | Serif |
| Palatino | Serif |
| Times New Roman | Serif |
| Helvetica | Sans-serif |
| Arial | Sans-serif |
| Verdana | Sans-serif |
| Courier New | Monospace |
| Menlo | Monospace |

No custom or bundled fonts are used — all fonts ship with macOS.

## Font Modes

### Single Font (default)

One font is applied to all content. The CSS injection sets `font-family` on `body` and forces inheritance on all elements with `* { font-family: inherit !important }`.

### Font Pairing (opt-in)

When enabled, the user selects two fonts:

- **Header font** — applied to `h1` through `h6` via an explicit CSS rule
- **Body font** — applied to `body` and inherited by all other elements

This allows combining a sans-serif header (e.g., Helvetica) with a serif body (e.g., Georgia) for visual contrast.

## How It Works

### CSS Injection

`ThemeManager.applyStyles(to:fontFamily:bodyFont:)` generates JavaScript that creates or updates a `<style id="focus-theme">` element in the chapter's HTML `<head>`.

**Single font mode** (`bodyFont` is `nil`):
```css
body { font-family: 'Georgia', serif !important; }
* { font-family: inherit !important; }
```

**Font pairing mode** (`bodyFont` is set):
```css
body { font-family: 'Georgia', serif !important; }
* { font-family: inherit !important; }
h1, h2, h3, h4, h5, h6 { font-family: 'Helvetica', sans-serif !important; }
```

The heading rule comes after the universal `*` rule, so it takes precedence.

### Data Flow

1. **Athenaeum settings** — `UserSettings` stores `defaultFont`, `useFontPairing`, and `bodyFont`. Persisted via `SettingsRepository` as key-value pairs in SQLite.
2. **Opening a book** — `LibraryViewModel.openBook()` includes `fontFamily`, `useFontPairing`, and `bodyFont` in the `.openBook` notification.
3. **Reader initialization** — `ReaderView` passes font settings to `ReaderViewModel`, which stores them as `@Published` properties.
4. **Applying styles** — `ReaderViewModel.applyThemeStyles()` calls `themeManager.applyStyles(to:fontFamily:bodyFont:)`, passing `bodyFont` only when `useFontPairing` is true.
5. **Runtime changes** — The reader toolbar font menu allows toggling pairing and switching fonts on the fly. Changes are applied immediately via `applyFonts()` in `ReaderToolbarView`.

### Octavo

The standalone reader (Octavo) has no persistent settings. Font pairing can be toggled via the reader toolbar menu during a session but resets to the default (single font, Georgia) when reopened.

## Relevant Files

| File | Role |
|------|------|
| `Ligature/Sources/Ligature/Models/ReadingTheme.swift` | `availableFonts` list |
| `Forma/Sources/Forma/Views/ThemeManager.swift` | CSS generation and injection |
| `Forma/Sources/Forma/Views/ReaderViewModel.swift` | `fontFamily`, `useFontPairing`, `bodyFont` properties |
| `Forma/Sources/Forma/Views/ReaderView.swift` | Toolbar font menu with pairing toggle |
| `Athenaeum/Models/UserSettings.swift` | `defaultFont`, `useFontPairing`, `bodyFont` fields |
| `Athenaeum/Database/SettingsRepository.swift` | Persists font settings to SQLite |
| `Athenaeum/Views/SettingsView.swift` | Settings UI with font pairing toggle and pickers |
| `Athenaeum/Views/LibraryViewModel.swift` | Passes font settings when opening books |

## Adding a New Font

1. Add the font name to `ReadingTheme.availableFonts` in `ReadingTheme.swift`.
2. Ensure the font is available on the target macOS version (13.0+).
3. No other changes needed — all pickers and menus read from `availableFonts` dynamically.
